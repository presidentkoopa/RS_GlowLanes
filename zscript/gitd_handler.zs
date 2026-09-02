// GlowInTheDark 2.0 -- the engine.
//
// Replaces the 1.1 ACS script entirely. What changed and why:
//
//   1.1 walked sector TAGS 0..99998 calling ACS SetSectorGlow. Tag 0 matches
//   every UNTAGGED sector at once (p_tags.cpp:419), and random() is evaluated
//   once per call, so the whole map received a single shared colour -- the
//   per-sector randomisation it advertised never happened. Everything after
//   tag 0 hit only doors and lifts, arriving one per tic over ~47 minutes
//   because its throttle test was inverted.
//
//   This iterates Level.Sectors by index. Every sector is reached, each gets
//   its own colour, and the whole map is done in one or two tics.
//
// Lane enable/disable is carried by COLOUR ALPHA, not by a separate flag:
// the renderer gates on `.a > 0` for wall glow (hw_walls.cpp:61) and on
// `FlatGlowColor.a > 0 && FlatGlowHeight > 0` for flat glow
// (hw_flats.cpp:439). Alpha 0 is off. This is why GITD_Util always builds
// colours with alpha 255 -- a colour that loses its alpha silently kills the
// lane with no error anywhere.

// One lane's settings, read once per apply rather than per sector.
class GITD_Lane
{
	bool on;
	int policy;
	Color fixedCol;
	double reach;
	int falloff;
	double intensity;
	int farMode;        // 0 off, 1 auto-derived, 2 explicit
	Color farCol;

	// Refill in place rather than returning a fresh object. The apply chain now
	// runs from UiTick so the menu can re-tint the map while the game is
	// paused, and `new` is not something to be doing from there -- once per
	// slider-drag per lane, every drag, for the whole time the menu is open.
	// The handler allocates these five once and hands them back here.
	clearscope void Fill(String p)
	{
		on        = GITD_Util.GetB(p .. "_on", true);
		policy    = GITD_Util.GetI(p .. "_policy", 0);
		fixedCol  = GITD_Util.GetC(p .. "_color");
		reach     = GITD_Util.GetF(p .. "_reach", 64.0);
		falloff   = GITD_Util.GetI(p .. "_falloff", 0);
		intensity = GITD_Util.GetF(p .. "_intensity", 1.0);
		farMode   = GITD_Util.GetI(p .. "_far", 1);
		farCol    = GITD_Util.GetC(p .. "_farcolor");
	}

	static GITD_Lane FromCVars(String p)
	{
		GITD_Lane l = GITD_Lane(new("GITD_Lane"));
		l.Fill(p);
		return l;
	}

	// The colour this lane fades toward. Auto-derivation is the default
	// because a hand-picked far colour is the single most tedious thing to
	// tune and the derived one is right nearly always.
	//
	// Seamless corners override this afterwards: the lane's own colour becomes
	// its far end and the junction colour takes the near slot. See the
	// seamless block in ApplySector.
	clearscope Color FarFor(Color nearCol)
	{
		if (farMode == 0) return Color(0, 0, 0, 0);
		if (farMode == 2) return farCol;
		return GITD_Util.AutoFar(nearCol);
	}
}

class GITD_Handler : EventHandler
{
	// Sectors per tic during a re-apply. A 5000-sector map finishes in three
	// tics with no visible hitch. 1.1's equivalent constant was 2500 but its
	// modulo test was inverted, so it actually managed about one.
	const APPLY_CHUNK = 2000;

	// How often to check whether any lane setting moved. Five tics is about
	// 1/7th of a second -- fast enough that dragging a slider feels live,
	// slow enough that the check itself is free.
	const POLL_TICS = 5;

	const PRESET_COUNT = 18;

	// Per-lane hash salts, so a sector's four lanes do not all land on the
	// same colour under the hashed policies.
	const SALT_WF = 1;
	const SALT_WC = 2;
	const SALT_FG = 3;
	const SALT_CG = 4;

	private ui bool applying;
	private ui int applyCursor;
	private ui uint lastHash;
	private ui int pollTimer;
	private ui bool wasEnabled;

	private ui GITD_Range range;
	private ui GITD_Lane laneWF, laneWC, laneFG, laneCG, laneLiq;
	private ui bool liqOn, liqWalls;
	private ui bool seamless;

	// SEAMLESS WALLS.
	//
	// Corners fix the join inside one sector. This fixes the join BETWEEN
	// sectors -- the hard vertical line down a wall where a red room meets a
	// blue one, and the hard edge across a floor where two sectors of the same
	// room carry different colours. A Doom "room" is nearly always several
	// sectors, so without this every step, ledge and doorway is a colour break.
	//
	// Each sector's colour is pulled toward the average of the sectors it
	// shares a line with, so colour flows across the map instead of switching
	// at every boundary.
	//
	// This needs every sector's OWN colour resolved before any of them can be
	// blended -- a sector cannot average against neighbours that have not been
	// worked out yet. Hence two passes, both chunked: resolve, then blend and
	// write. The resolve pass touches no engine state at all.
	private ui bool wallSeam;
	private ui double wallBlend;
	private ui Array<int> baseWF, baseWC, baseFG, baseCG;
	private ui int phase;      // 0 idle, 1 resolving, 2 applying

	// Which map the ui side last applied to. See UiTick.
	private ui String mapSig;

	// The UI side's own preset tracker. See UiTick for why it cannot share
	// lastPreset. uiPresetSeen exists because 0 is a real preset (Vanilla+), so
	// a zero uiLastPreset cannot be told apart from "not looked yet".

	// ---- lifecycle ---------------------------------------------------------

	// A PRESET APPLIES WHEN IT CHANGES, NOT ON EVERY MAP. Apply is a batch of
	// CVar writes; running it on every WorldLoaded (and again from UiTick's
	// first tic) wiped whatever had been tuned on the sliders since the
	// preset was picked, every level. The last-applied index lives in a CVar
	// (gitd_preset_applied) because this handler is rebuilt per map. Shuffle
	// still rolls a new preset per map: it writes gitd_preset, and the sync
	// sees the change.
	override void WorldLoaded(WorldEvent e)
	{
		if (GITD_Util.GetB("gitd_shuffle", false))
			GITD_Util.SetI("gitd_preset", random(1, PRESET_COUNT - 1));
		SyncPreset();
		PushGlobals();
	}

	override void WorldTick()
	{
		if (!GITD_Util.GetB("gitd_enabled", true)) return;
		PushGlobals();
		PushWaveOrigin();
		SyncPreset();
	}

	clearscope static void SyncPreset()
	{
		int want = GITD_Util.GetI("gitd_preset", 1);
		if (want == GITD_Util.GetI("gitd_preset_applied", -1)) return;
		GITD_Presets.Apply(want);
		GITD_Util.SetI("gitd_preset_applied", want);
	}

	override void WorldThingDied(WorldEvent e)
	{
		int mode = GITD_Util.GetI("gitd_ondeath", 0);
		if (mode == 0) return;
		if (!e || !e.Thing || !e.Thing.player) return;

		// Only the player whose screen this is. In co-op every death would
		// otherwise restyle the map for everyone.
		if (e.Thing.player != players[consoleplayer]) return;

		if (mode == 2)
		{
			GITD_Util.SetI("gitd_preset", random(1, PRESET_COUNT - 1));
		}
		else
		{
			GITD_Util.SetI("gitd_seed", random(0, 9999));
		}

		// Either path changes the settings hash, so the next poll re-applies
		// on its own.
	}

	// ---- the per-pixel layer -----------------------------------------------

	// Pushed every tic from BOTH WorldTick and UiTick.
	//
	// UiTick is the one that matters: the playsim stops while the menu is up,
	// so WorldTick alone would freeze the picture exactly while you are
	// dragging the slider that is meant to change it. UiTick keeps running.
	// This is why the whole call chain here is clearscope -- a ui-scope caller
	// cannot reach a play-scope helper, and every glow function below is
	// declared clearscope by the engine precisely so a menu can drive it
	// (doombase.zs:1124).
	//
	// Both callers are kept rather than UiTick alone: pushing twice a tic
	// costs about thirty CVar lookups and guarantees the feature works even if
	// UiTick is gated somewhere unexpected.
	clearscope void PushGlobals()
	{
		if (!Level) return;

		Level.SetGlowWave(
			GITD_Util.GetF("gitd_wave_len"),
			GITD_Util.GetF("gitd_wave_speed", 1.0),
			GITD_Util.GetF("gitd_wave_sharp", 1.0),
			GITD_Util.GetI("gitd_wave_shape"));

		Level.SetGlowWaveDepth(
			GITD_Util.GetF("gitd_wave_reach"),
			GITD_Util.GetF("gitd_wave_bright"),
			GITD_Util.GetF("gitd_wave_colour"),
			GITD_Util.GetF("gitd_wave_detune"),
			GITD_Util.GetF("gitd_wave_seed"));

		Level.SetGlowWavePhase(
			GITD_Util.GetF("gitd_wave_ph_wtop"),
			GITD_Util.GetF("gitd_wave_ph_wbot"),
			GITD_Util.GetF("gitd_wave_ph_floor"),
			GITD_Util.GetF("gitd_wave_ph_ceil"));

		Level.SetGlowTexture(
			GITD_Util.GetF("gitd_tex_noise"),
			GITD_Util.GetF("gitd_tex_scale", 1.0),
			GITD_Util.GetF("gitd_tex_drift"),
			GITD_Util.GetF("gitd_tex_contrast", 1.0));

		Level.SetGlowFlow(
			GITD_Util.GetF("gitd_flow"),
			GITD_Util.GetF("gitd_flow_spacing", 1.0),
			GITD_Util.GetF("gitd_flow_speed", 1.0),
			GITD_Util.GetF("gitd_flow_sharp", 1.0));

		Level.SetGlowCells(
			GITD_Util.GetF("gitd_cell"),
			GITD_Util.GetF("gitd_cell_scale", 1.0),
			GITD_Util.GetF("gitd_cell_speed", 1.0),
			GITD_Util.GetF("gitd_cell_width", 0.5));

		// react only scales the engine's fog-disturbance array, which this mod
		// does not populate -- it is exposed for completeness and for other
		// mods that do. pulse/level are self-contained and are what the
		// throbbing presets actually use. (vmthunks.cpp:4125)
		Level.SetGlowReact(
			GITD_Util.GetF("gitd_react"),
			GITD_Util.GetF("gitd_pulse"),
			GITD_Util.GetF("gitd_pulse_level"));
	}

	// Runs while the game is paused and while the menu is open, which
	// WorldTick does not. Everything the mod can change moves as you drag its
	// slider -- wave, noise, flow, cells, the alarm, AND the four lanes.
	//
	// The lanes used to be excluded here: Sector.SetGlowColor and friends were
	// play scope, so a paused game could not re-tint sectors and every lane
	// edit sat dead until you closed the menu -- you could not see the change
	// you were dragging for. Those twelve setters are clearscope now
	// (mapdata.zs, Sector and Side), because glow is render state that merely
	// lives on a play struct: nothing in the simulation reads any of it. So the
	// whole apply chain runs from here, and the map re-tints under the menu.
	//
	// Same poll as WorldTick rather than applying every frame: dragging a
	// slider changes the settings hash, the hash starts an apply, the apply
	// walks the map in chunks. Idle menus cost one hash.
	override void UiTick()
	{
		PushGlobals();

		bool enabled = GITD_Util.GetB("gitd_enabled", true);

		if (!enabled)
		{
			// Turning the mod off has to actively clear what it wrote -- sector
			// glow is persistent state, not something re-established each
			// frame. Clear once, then stay quiet.
			if (wasEnabled)
			{
				ClearAll();
				wasEnabled = false;
			}
			return;
		}

		if (!Level) return;
		EnsureLanes();

		// The preset has to be resolved here as well as in WorldTick. A preset
		// is not a value the apply reads -- it is a batch of CVar writes, and
		// those only happened on the play side. So while the menu was up,
		// dragging a slider would eventually have moved the picture but picking
		// a preset could not, because the CVars it sets were never written.
		// Tracked separately from WorldTick's lastPreset: that is play state and
		// UI may not write it. Both sides applying is harmless -- Apply only
		// writes CVars, and each fires once per change it has not seen.
		SyncPreset();

		// A fresh level starts with its glow unset, so a new map has to be
		// re-applied even when not one setting moved and the hash therefore
		// matches. WorldLoaded used to kick that off; it cannot reach ui state,
		// so the map is identified from here instead. Name plus sector count
		// separates a real map change from a mid-level reload of the same one.
		String sig = Level.MapName .. ":" .. Level.Sectors.Size();
		if (sig != mapSig)
		{
			mapSig = sig;
			lastHash = 0;          // force the poll below to fire
			pollTimer = 0;
		}

		if (!wasEnabled)
		{
			wasEnabled = true;
			lastHash = 0;
			pollTimer = 0;
		}

		if (--pollTimer <= 0)
		{
			pollTimer = POLL_TICS;
			uint h = SettingsHash();
			if (h != lastHash)
			{
				lastHash = h;
				BeginApply();
			}
		}

		if (applying) StepApply();
	}

	// Play scope: resolving "where the player is" reads the world.
	void PushWaveOrigin()
	{
		if (!Level) return;
		if (GITD_Util.GetI("gitd_wave_origin") != 1) return;

		let pmo = players[consoleplayer].mo;
		if (pmo) Level.SetGlowWaveOrigin(pmo.Pos);
	}

	// ---- applying the lanes ------------------------------------------------

	// Allocate the six config objects, once. UI scope like the rest of the
	// apply chain: WorldLoaded used to do this, but play cannot reach ui state,
	// so the first UiTick that finds a level does it instead.
	ui void EnsureLanes()
	{
		if (!range)   range   = GITD_Range.FromCVars();
		if (!laneWF)  laneWF  = GITD_Lane.FromCVars("gitd_wf");
		if (!laneWC)  laneWC  = GITD_Lane.FromCVars("gitd_wc");
		if (!laneFG)  laneFG  = GITD_Lane.FromCVars("gitd_fg");
		if (!laneCG)  laneCG  = GITD_Lane.FromCVars("gitd_cg");
		if (!laneLiq) laneLiq = GITD_Lane.FromCVars("gitd_liq");
	}

	ui void BeginApply()
	{
		// Nothing to apply into yet. UiTick fires before a level has ever
		// loaded -- the title screen is a menu like any other -- and that is the
		// one path that reaches here before EnsureLanes has run.
		if (!range || !laneWF) return;

		range.Fill();
		laneWF.Fill("gitd_wf");
		laneWC.Fill("gitd_wc");
		laneFG.Fill("gitd_fg");
		laneCG.Fill("gitd_cg");
		laneLiq.Fill("gitd_liq");

		liqOn    = GITD_Util.GetB("gitd_liq_on", true);
		liqWalls = GITD_Util.GetB("gitd_liq_walls", true);
		// Seamless corners and glow waves are mutually exclusive, and the
		// exclusion is enforced here rather than left to the user.
		//
		// The corner works by matching reach across the junction. A wave moves
		// reach per pixel, so undulating one side of a corner reopens the seam
		// it just closed -- and worse, the seam then travels. Either the room
		// is bounded by continuous colour with no edge, or the edge moves;
		// it cannot be both. Six of the presets run waves, so silently
		// dropping seamless while one is live is the only safe reading.
		seamless = GITD_Util.GetB("gitd_seamless", true)
			&& GITD_Util.GetF("gitd_wave_len") <= 0.0;

		wallSeam  = GITD_Util.GetB("gitd_seamless_walls", true);
		wallBlend = clamp(GITD_Util.GetF("gitd_wall_blend", 0.5), 0.0, 1.0);

		int n = Level ? Level.Sectors.Size() : 0;
		baseWF.Resize(n); baseWC.Resize(n);
		baseFG.Resize(n); baseCG.Resize(n);

		applyCursor = 0;
		phase = 1;              // resolve first, then blend and write
		applying = true;
	}

	ui void StepApply()
	{
		if (!Level) { applying = false; phase = 0; return; }

		int n = Level.Sectors.Size();
		int end = min(applyCursor + APPLY_CHUNK, n);

		if (phase == 1)
		{
			for (int i = applyCursor; i < end; i++)
			{
				ResolveSector(Level.Sectors[i], i);
			}
			applyCursor = end;
			if (applyCursor >= n) { applyCursor = 0; phase = 2; }
			return;
		}

		for (int i = applyCursor; i < end; i++)
		{
			ApplySector(Level.Sectors[i], i);
		}

		applyCursor = end;
		if (applyCursor >= n) { applying = false; phase = 0; }
	}

	// Pass one: each sector's own colour per lane, before any neighbour
	// blending. Touches no engine state.
	ui void ResolveSector(Sector sec, int idx)
	{
		if (!sec) return;

		bool liquid = IsLiquid(sec);
		let floorLane  = (liquid) ? laneLiq : laneFG;
		let wallLoLane = (liquid && liqWalls) ? laneLiq : laneWF;

		baseWF[idx] = GITD_Util.Pack(Pick(wallLoLane, sec, idx, Sector.floor,   SALT_WF));
		baseWC[idx] = GITD_Util.Pack(Pick(laneWC,     sec, idx, Sector.ceiling, SALT_WC));
		baseFG[idx] = GITD_Util.Pack(Pick(floorLane,  sec, idx, Sector.floor,   SALT_FG));
		baseCG[idx] = GITD_Util.Pack(Pick(laneCG,     sec, idx, Sector.ceiling, SALT_CG));
	}

	ui bool IsLiquid(Sector sec)
	{
		if (!liqOn) return false;
		let td = sec.GetFloorTerrain(Sector.floor);
		return td && td.IsLiquid;
	}

	// Pull one sector's colour toward the average of the sectors it shares a
	// line with. Self-references and one-sided lines are skipped -- a map edge
	// has no neighbour to agree with, and pulling toward yourself is a no-op
	// that would still drag the average.
	ui Color Neighbourly(Sector sec, Array<int> store, int idx)
	{
		Color own = GITD_Util.Unpack(store[idx]);
		if (!wallSeam || wallBlend <= 0.0) return own;

		int r = 0, g = 0, b = 0, cnt = 0;
		for (int i = 0; i < sec.lines.Size(); i++)
		{
			let ln = sec.lines[i];
			if (!ln) continue;

			Sector other = (ln.frontsector == sec) ? ln.backsector : ln.frontsector;
			if (!other || other == sec) continue;

			int oi = other.Index();
			if (oi < 0 || oi >= store.Size()) continue;

			Color oc = GITD_Util.Unpack(store[oi]);
			r += oc.r; g += oc.g; b += oc.b; cnt++;
		}

		if (cnt == 0) return own;
		return GITD_Util.LerpCol(own, Color(255, r / cnt, g / cnt, b / cnt), wallBlend);
	}

	ui void ApplySector(Sector sec, int idx)
	{
		if (!sec) return;

		// Liquid floors take their own config instead of the general floor
		// policy. This is what replaces 1.1's gldefs.bm, and it does the thing
		// GLDEFS never could: light the liquid's own surface, not just the
		// wall beside it.
		bool liquid = IsLiquid(sec);

		let floorLane  = (liquid) ? laneLiq : laneFG;
		let wallLoLane = (liquid && liqWalls) ? laneLiq : laneWF;

		// SEAMLESS WALLS -- each lane pulled toward its neighbours across
		// shared lines, so the boundary between two sectors stops being a hard
		// line. Resolved in pass one; this reads the finished table.
		Color cWF = Neighbourly(sec, baseWF, idx);
		Color cWC = Neighbourly(sec, baseWC, idx);
		Color cFG = Neighbourly(sec, baseFG, idx);
		Color cCG = Neighbourly(sec, baseCG, idx);

		// Each lane's own far colour, before any corner work.
		Color fWF = (wallLoLane) ? wallLoLane.FarFor(cWF) : Color(0, 0, 0, 0);
		Color fWC = (laneWC)     ? laneWC.FarFor(cWC)     : Color(0, 0, 0, 0);
		Color fFG = (floorLane)  ? floorLane.FarFor(cFG)  : Color(0, 0, 0, 0);
		Color fCG = (laneCG)     ? laneCG.FarFor(cCG)     : Color(0, 0, 0, 0);

		// Effective shape per lane. Seamless has to match these across a
		// junction too -- a ramp that changes width, curve or brightness
		// halfway across a corner reads as a seam even when the colour is
		// continuous.
		double rWF = LaneReach(wallLoLane), rWC = LaneReach(laneWC);
		double rFG = LaneReach(floorLane),  rCG = LaneReach(laneCG);
		int    kWF = LaneFall(wallLoLane),  kWC = LaneFall(laneWC);
		int    kFG = LaneFall(floorLane),   kCG = LaneFall(laneCG);
		double iWF = LaneInten(wallLoLane), iWC = LaneInten(laneWC);
		double iFG = LaneInten(floorLane),  iCG = LaneInten(laneCG);

		bool wfOn = wallLoLane && wallLoLane.on;
		bool wcOn = laneWC     && laneWC.on;
		bool fgOn = floorLane  && floorLane.on;
		bool cgOn = laneCG     && laneCG.on;

		// SEAMLESS CORNERS.
		//
		// The gradient at a corner was never missing. The wall's glow fades
		// UPWARD from the floor line; the floor's edge glow fades INWARD from
		// that same line. Two ramps meeting nose to nose, both at FULL
		// strength exactly where they touch. The hard cut is the two sides
		// disagreeing about what colour to be AT the line they share.
		//
		// So it is the NEAR colours that have to agree -- they are the ones
		// that meet. Both lanes take the junction colour at the line and their
		// own original colour becomes the far end, which is what lets a corner
		// still read floor-purple into wall-blue instead of collapsing to one
		// flat wash of the average.
		//
		// A corner needs BOTH surfaces drawn before there is anything to agree
		// with. With one side off the other keeps its own colour, exactly as
		// it looked before seamless existed.
		if (seamless)
		{
			if (wfOn && fgOn)
			{
				Color join = GITD_Util.Blend(cWF, cFG);
				fWF = cWF; cWF = join;
				fFG = cFG; cFG = join;
				rFG = rWF; kFG = kWF; iFG = iWF;   // flat takes the wall's shape
			}
			if (wcOn && cgOn)
			{
				Color join = GITD_Util.Blend(cWC, cCG);
				fWC = cWC; cWC = join;
				fCG = cCG; cCG = join;
				rCG = rWC; kCG = kWC; iCG = iWC;
			}
		}

		ApplyWallLane(sec, Sector.floor,   wfOn, cWF, fWF, rWF, kWF, iWF);
		ApplyWallLane(sec, Sector.ceiling, wcOn, cWC, fWC, rWC, kWC, iWC);
		ApplyFlatLane(sec, Sector.floor,   fgOn, cFG, fFG, rFG, kFG, iFG);
		ApplyFlatLane(sec, Sector.ceiling, cgOn, cCG, fCG, rCG, kCG, iCG);
	}

	ui double LaneReach(GITD_Lane ln) { return ln ? ln.reach : 0.0; }
	ui int    LaneFall(GITD_Lane ln)  { return ln ? ln.falloff : 0; }
	ui double LaneInten(GITD_Lane ln) { return ln ? ln.intensity : 1.0; }

	// One lane's colour. Disabled lanes return black, which nothing
	// downstream reads.
	ui Color Pick(GITD_Lane ln, Sector sec, int idx, int planePos, uint salt)
	{
		if (!ln || !ln.on) return Color(255, 0, 0, 0);
		return GITD_Policy.Resolve(sec, idx, planePos, ln.policy,
			ln.fixedCol, salt, range);
	}

	ui void ApplyWallLane(Sector sec, int planePos, bool on,
		Color nearCol, Color farCol, double reach, int falloff, double inten)
	{
		if (!on)
		{
			sec.SetGlowColor(planePos, Color(0, 0, 0, 0));
			sec.SetGlowColorFar(planePos, Color(0, 0, 0, 0));
			sec.SetGlowHeight(planePos, 0.0);
			return;
		}

		sec.SetGlowColor(planePos, nearCol);
		sec.SetGlowColorFar(planePos, farCol);
		sec.SetGlowHeight(planePos, reach);      // VERTICAL, up the wall
		sec.SetGlowFalloff(planePos, falloff);
		sec.SetGlowIntensity(planePos, inten);   // scales colour, not reach
	}

	ui void ApplyFlatLane(Sector sec, int planePos, bool on,
		Color nearCol, Color farCol, double reach, int falloff, double inten)
	{
		if (!on)
		{
			sec.SetFlatGlowColor(planePos, Color(0, 0, 0, 0));
			sec.SetFlatGlowColorFar(planePos, Color(0, 0, 0, 0));
			sec.SetFlatGlowHeight(planePos, 0.0);
			return;
		}

		sec.SetFlatGlowColor(planePos, nearCol);
		sec.SetFlatGlowColorFar(planePos, farCol);
		sec.SetFlatGlowHeight(planePos, reach);  // HORIZONTAL, inward from edge
		sec.SetFlatGlowFalloff(planePos, falloff);
		sec.SetFlatGlowIntensity(planePos, inten);
	}

	ui void ClearAll()
	{
		if (!Level) return;

		for (int i = 0; i < Level.Sectors.Size(); i++)
		{
			let sec = Level.Sectors[i];
			if (!sec) continue;

			for (int p = 0; p <= 1; p++)
			{
				sec.SetGlowColor(p, Color(0, 0, 0, 0));
				sec.SetGlowColorFar(p, Color(0, 0, 0, 0));
				sec.SetGlowHeight(p, 0.0);
				sec.SetFlatGlowColor(p, Color(0, 0, 0, 0));
				sec.SetFlatGlowColorFar(p, Color(0, 0, 0, 0));
				sec.SetFlatGlowHeight(p, 0.0);
			}
		}

		Level.ClearGlowWave();
		Level.SetGlowTexture(0, 1, 0, 1);
		Level.SetGlowFlow(0, 1, 1, 1);
		Level.SetGlowCells(0, 1, 1, 0.5);
		Level.SetGlowReact(0, 0, 0);

		applying = false;
	}

	// ---- change detection --------------------------------------------------

	// Only the per-sector settings belong here. The per-pixel layer is pushed
	// unconditionally every tic and needs no detection.
	ui uint SettingsHash()
	{
		uint h = 2166136261;
		h = AccLane(h, "gitd_wf");
		h = AccLane(h, "gitd_wc");
		h = AccLane(h, "gitd_fg");
		h = AccLane(h, "gitd_cg");
		h = AccLane(h, "gitd_liq");

		h = Acc(h, GITD_Util.GetB("gitd_liq_on", true) ? 1 : 0);
		h = Acc(h, GITD_Util.GetB("gitd_liq_walls", true) ? 1 : 0);
		h = Acc(h, GITD_Util.GetB("gitd_seamless", true) ? 1 : 0);
		h = Acc(h, GITD_Util.GetB("gitd_seamless_walls", true) ? 1 : 0);
		h = Acc(h, int(GITD_Util.GetF("gitd_wall_blend", 0.5) * 1000.0));
		// Wavelength belongs in the per-sector hash even though the wave
		// itself is a per-pixel setting: it gates seamless above, so crossing
		// zero changes what the lanes get written.
		h = Acc(h, int(GITD_Util.GetF("gitd_wave_len") * 10.0));
		h = Acc(h, GITD_Util.GetI("gitd_seed", 1337));
		h = Acc(h, int(GITD_Util.GetF("gitd_hue_min") * 100.0));
		h = Acc(h, int(GITD_Util.GetF("gitd_hue_max") * 100.0));
		h = Acc(h, int(GITD_Util.GetF("gitd_sat_min") * 1000.0));
		h = Acc(h, int(GITD_Util.GetF("gitd_sat_max") * 1000.0));
		h = Acc(h, int(GITD_Util.GetF("gitd_val_min") * 1000.0));
		h = Acc(h, int(GITD_Util.GetF("gitd_val_max") * 1000.0));
		h = Acc(h, GITD_Util.GetB("gitd_lock_planes") ? 1 : 0);
		h = Acc(h, GITD_Util.GetB("gitd_light_invert", true) ? 1 : 0);
		return h;
	}

	ui uint AccLane(uint h, String p)
	{
		h = Acc(h, GITD_Util.GetB(p .. "_on", true) ? 1 : 0);
		h = Acc(h, GITD_Util.GetI(p .. "_policy"));
		h = Acc(h, GITD_Util.GetI(p .. "_color"));
		h = Acc(h, int(GITD_Util.GetF(p .. "_reach") * 100.0));
		h = Acc(h, GITD_Util.GetI(p .. "_falloff"));
		h = Acc(h, int(GITD_Util.GetF(p .. "_intensity") * 1000.0));
		h = Acc(h, GITD_Util.GetI(p .. "_far"));
		h = Acc(h, GITD_Util.GetI(p .. "_farcolor"));
		return h;
	}

	ui uint Acc(uint h, int v)
	{
		h ^= uint(v);
		h *= 16777619;
		return h;
	}
}
