// RS_GlowLanes -- RECONSTRUCTED 2026-09-02.
//
// The original folder was deleted by mistake the same day, with no git and no
// other copy. This file is rebuilt from a full read of the original taken
// minutes earlier: every line of CODE is verbatim, including the one fix made
// that day (the far colour is written every time, alpha 0 = off). The
// original's COMMENTS are gone; this header and the notes below are new.

class GL_Handler : EventHandler
{
	int setIndex;
	double phase;

	color chaosCurWB, chaosNxtWB;
	color chaosCurWT, chaosNxtWT;
	color chaosCurFG, chaosNxtFG;
	color chaosCurCG, chaosNxtCG;

	color lastWB, lastWBFar;
	color lastWT, lastWTFar;
	color lastFG, lastFGFar;
	color lastCG, lastCGFar;

	static const int RED_ALARM[]    = { 0xC81414, 0xE66E0A, 0xB43C14, 0xE6C81E };
	static const int COLD_WAR[]     = { 0x1E50C8, 0x6E28B4, 0x3268A0, 0x461E78 };
	static const int NEON_UNISON[]  = { 0xFF1493, 0x1E90FF, 0x9632DC, 0x14C8B4 };
	static const int TOXIC[]        = { 0x6B8E23, 0x9ACD32, 0x39FF14, 0x4A5D23 };
	static const int DEEP_SEA[]     = { 0x0A4B4B, 0x0B2A4A, 0x1EFAC8, 0x081830 };

	override void WorldLoaded(WorldEvent e)
	{
		setIndex = 0;
		phase = 0;
		chaosCurWB = RollChaos(); chaosNxtWB = RollChaos();
		chaosCurWT = RollChaos(); chaosNxtWT = RollChaos();
		chaosCurFG = RollChaos(); chaosNxtFG = RollChaos();
		chaosCurCG = RollChaos(); chaosNxtCG = RollChaos();
		Advance();
		Push();
	}

	// The two halves, and why they are two.
	//
	// WorldTick ADVANCES the breathing (phase, setIndex, the chaos colours) and
	// then pushes the result. UiTick only pushes. So while the options menu is
	// up the picture updates live under it -- drag a slider or pick a preset and
	// the room re-tints while you watch -- but the colour cycle holds still,
	// which is what you want when you are trying to judge a colour anyway.
	//
	// This replaces DontPause on the menu. That kept WorldTick running by simply
	// never pausing the game, which worked, but meant monsters carried on
	// attacking while you picked colours.
	override void WorldTick()
	{
		Advance();
		Push();
	}

	// UI context: may READ play data but never write it. Push touches no field
	// of this handler and rolls no dice, which is exactly what makes it legal
	// from here -- see the note on Advance.
	override void UiTick()
	{
		Push();
	}

	override void NetworkProcess(ConsoleEvent e)
	{
		if (e.Name == "GL_Reroll") Reroll();
		else if (e.Name == "GL_Keep") KeepThis();
	}

	clearscope double PhaseStep()
	{
		return 1.0 / (35.0 * max(vgl_speed, 0.5));
	}

	// EVERYTHING THAT MUTATES, and nothing else. Play scope, WorldTick only.
	//
	// It owns the animation state -- phase, setIndex, the chaos colours -- and
	// therefore owns every RollChaos call, which is the part that actually
	// matters for netplay: frandom advances the RNG, the RNG seed sum IS in the
	// consistency checksum (d_net.cpp CalculateConsistency), and a client
	// rolling a colour from unsynchronised menu code would desync the game.
	// Keeping every roll on this side means the menu cannot reach one.
	void Advance()
	{
		if (!vgl_enabled) return;

		int preset = vgl_preset;
		bool advanced = false;
		if (preset > 0 && !vgl_frozen)
		{
			phase += PhaseStep();
			if (phase >= 1.0)
			{
				phase -= 1.0;
				setIndex = (setIndex + 1) % 4;
				advanced = true;
			}
		}
		if (preset == 4 && advanced)
		{
			chaosCurWB = chaosNxtWB; chaosNxtWB = RollChaos();
			chaosCurWT = chaosNxtWT; chaosNxtWT = RollChaos();
			chaosCurFG = chaosNxtFG; chaosNxtFG = RollChaos();
			chaosCurCG = chaosNxtCG; chaosNxtCG = RollChaos();
		}

		// The Keep button needs to know what is on screen right now. Recorded
		// here rather than in Push because these are play fields and Push, being
		// reachable from UI, may not write them.
		color a, b, c, d, e, f, g, h;
		bool o1, o2, o3, o4;
		Resolve(a, b, c, d, e, f, g, h, o1, o2, o3, o4);
		lastWB = a; lastWBFar = o1 ? b : a;
		lastWT = c; lastWTFar = o2 ? d : c;
		lastFG = e; lastFGFar = o3 ? f : e;
		lastCG = g; lastCGFar = o4 ? h : g;
	}

	// PURE. Works out what the four lanes should look like from the state as it
	// stands, without touching any of it. Both ticks go through here.
	clearscope void Resolve(out color wbC, out color wbF, out color wtC, out color wtF,
		out color fgC, out color fgF, out color cgC, out color cgF,
		out bool wbFarOn, out bool wtFarOn, out bool fgFarOn, out bool cgFarOn)
	{
		int preset = vgl_preset;
		if (preset > 0)
		{
			GetPresetColor(preset, 0, chaosCurWB, chaosNxtWB, wbC, wbF);
			GetPresetColor(preset, 1, chaosCurWT, chaosNxtWT, wtC, wtF);
			GetPresetColor(preset, 2, chaosCurFG, chaosNxtFG, fgC, fgF);
			GetPresetColor(preset, 3, chaosCurCG, chaosNxtCG, cgC, cgF);
			wbFarOn = true; wtFarOn = true; fgFarOn = true; cgFarOn = true;
		}
		else
		{
			wbC = Color(255, vgl_wb_r, vgl_wb_g, vgl_wb_b);
			wbF = Color(255, vgl_wb_far_r, vgl_wb_far_g, vgl_wb_far_b);
			wbFarOn = vgl_wb_far_on;
			wtC = Color(255, vgl_wt_r, vgl_wt_g, vgl_wt_b);
			wtF = Color(255, vgl_wt_far_r, vgl_wt_far_g, vgl_wt_far_b);
			wtFarOn = vgl_wt_far_on;
			fgC = Color(255, vgl_fg_r, vgl_fg_g, vgl_fg_b);
			fgF = Color(255, vgl_fg_far_r, vgl_fg_far_g, vgl_fg_far_b);
			fgFarOn = vgl_fg_far_on;
			cgC = Color(255, vgl_cg_r, vgl_cg_g, vgl_cg_b);
			cgF = Color(255, vgl_cg_far_r, vgl_cg_far_g, vgl_cg_far_b);
			cgFarOn = vgl_cg_far_on;
		}

		if (vgl_seamless)
		{
			color floorJoin = LerpColor(wbC, fgC, 0.5);
			wbF = wbC; wbC = floorJoin; wbFarOn = true;
			fgF = fgC; fgC = floorJoin; fgFarOn = true;
			color ceilJoin = LerpColor(wtC, cgC, 0.5);
			wtF = wtC; wtC = ceilJoin; wtFarOn = true;
			cgF = cgC; cgC = ceilJoin; cgFarOn = true;
		}
	}

	// EVERYTHING THAT DRAWS, and nothing that mutates. clearscope, so UiTick can
	// reach it: it reads this handler's fields (UI may read play data) and writes
	// only to sectors and to the level's wave, all of which take clearscope
	// setters. It rolls no dice and stores nothing, so calling it from the menu
	// changes no state that any other client could disagree about.
	clearscope void Push()
	{
		if (!vgl_enabled)
		{
			ClearAllLanes();
			Level.ClearGlowWave();
			return;
		}

		color wbC, wbF, wtC, wtF, fgC, fgF, cgC, cgF;
		bool wbFarOn, wtFarOn, fgFarOn, cgFarOn;
		Resolve(wbC, wbF, wtC, wtF, fgC, fgF, cgC, cgF,
			wbFarOn, wtFarOn, fgFarOn, cgFarOn);

		// The far colour is written EVERY time, alpha 0 meaning "no far colour"
		// (the engine gates on .a). It used to be skipped when far was off, so
		// switching from a preset (far always on) to a custom lane with "Use
		// far color" off left the preset's far colour behind, and the custom
		// colour graded toward it instead of staying flat.
		for (int i = 0; i < level.Sectors.Size(); i++)
		{
			Sector sec = level.Sectors[i];

			sec.SetGlowColor(Sector.floor, wbC);
			sec.SetGlowColorFar(Sector.floor,   wbFarOn ? wbF : Color(0, 0, 0, 0));
			sec.SetGlowHeight(Sector.floor, vgl_wb_cov);
			sec.SetGlowFalloff(Sector.floor, vgl_wb_fall);
			sec.SetGlowIntensity(Sector.floor, vgl_wb_inten);

			sec.SetGlowColor(Sector.ceiling, wtC);
			sec.SetGlowColorFar(Sector.ceiling, wtFarOn ? wtF : Color(0, 0, 0, 0));
			sec.SetGlowHeight(Sector.ceiling, vgl_wt_cov);
			sec.SetGlowFalloff(Sector.ceiling, vgl_wt_fall);
			sec.SetGlowIntensity(Sector.ceiling, vgl_wt_inten);

			sec.SetFlatGlowColor(Sector.floor, fgC);
			sec.SetFlatGlowColorFar(Sector.floor,   fgFarOn ? fgF : Color(0, 0, 0, 0));
			sec.SetFlatGlowHeight(Sector.floor, vgl_fg_cov);
			sec.SetFlatGlowFalloff(Sector.floor, vgl_fg_fall);
			sec.SetFlatGlowIntensity(Sector.floor, vgl_fg_inten);

			sec.SetFlatGlowColor(Sector.ceiling, cgC);
			sec.SetFlatGlowColorFar(Sector.ceiling, cgFarOn ? cgF : Color(0, 0, 0, 0));
			sec.SetFlatGlowHeight(Sector.ceiling, vgl_cg_cov);
			sec.SetFlatGlowFalloff(Sector.ceiling, vgl_cg_fall);
			sec.SetFlatGlowIntensity(Sector.ceiling, vgl_cg_inten);
		}

		ApplyWave();
	}

	clearscope void ApplyWave()
	{
		if (!vgl_wave_on)
		{
			Level.ClearGlowWave();
			return;
		}
		Level.SetGlowWave(vgl_wave_length, vgl_wave_speed, 1.0, vgl_wave_shape);
		Level.SetGlowWaveOrigin((0, 0, 0));
		Level.SetGlowWaveDepth(1.0, 0.0, 0.0, 0.13, 17);
		Level.SetGlowWavePhase(0, 0, 0, 0);
	}

	clearscope void ClearAllLanes()
	{
		for (int i = 0; i < level.Sectors.Size(); i++)
		{
			Sector sec = level.Sectors[i];
			sec.SetGlowHeight(Sector.floor, 0);
			sec.SetGlowHeight(Sector.ceiling, 0);
			sec.SetFlatGlowHeight(Sector.floor, 0);
			sec.SetFlatGlowHeight(Sector.ceiling, 0);
		}
	}

	clearscope void GetPresetColor(int preset, int laneOffset, color chaosCur, color chaosNxt, out color cur, out color nxt)
	{
		if (preset == 4)
		{
			cur = LerpColor(chaosCur, chaosNxt, phase);
			nxt = chaosNxt;
			return;
		}
		int idx = (setIndex + laneOffset) % 4;
		int nidx = (idx + 1) % 4;
		color raw0 = Color(PresetList(preset, idx));
		color raw1 = Color(PresetList(preset, nidx));
		color c0 = Color(255, raw0.r, raw0.g, raw0.b);
		color c1 = Color(255, raw1.r, raw1.g, raw1.b);
		cur = LerpColor(c0, c1, phase);
		nxt = c1;
	}

	clearscope int PresetList(int preset, int idx)
	{
		if (preset == 1) return RED_ALARM[idx];
		if (preset == 2) return COLD_WAR[idx];
		if (preset == 3) return NEON_UNISON[idx];
		if (preset == 5) return TOXIC[idx];
		return DEEP_SEA[idx];
	}

	color RollChaos()
	{
		return HSVtoRGB(frandom(0.0, 360.0), frandom(0.6, 1.0), frandom(0.7, 1.0));
	}

	clearscope static color LerpColor(color a, color b, double t)
	{
		int r = int(a.r + (b.r - a.r) * t);
		int g = int(a.g + (b.g - a.g) * t);
		int bl = int(a.b + (b.b - a.b) * t);
		return Color(255, r, g, bl);
	}

	clearscope static color HSVtoRGB(double h, double s, double v)
	{
		while (h < 0) h += 360.0;
		while (h >= 360.0) h -= 360.0;
		double c = v * s;
		double hp = h / 60.0;
		double x = c * (1.0 - abs(hp - 2.0 * floor(hp / 2.0) - 1.0));
		double m = v - c;
		double r, g, b;
		if (hp < 1) { r = c; g = x; b = 0; }
		else if (hp < 2) { r = x; g = c; b = 0; }
		else if (hp < 3) { r = 0; g = c; b = x; }
		else if (hp < 4) { r = 0; g = x; b = c; }
		else if (hp < 5) { r = x; g = 0; b = c; }
		else { r = c; g = 0; b = x; }
		return Color(255, int(clamp((r + m) * 255, 0, 255)), int(clamp((g + m) * 255, 0, 255)), int(clamp((b + m) * 255, 0, 255)));
	}

	static double StyleHue(int style, double baseHue)
	{
		if (style == 1) return frandom(-40.0, 70.0);
		if (style == 2) return frandom(150.0, 280.0);
		if (style == 3) return baseHue + frandom(-20.0, 20.0);
		return frandom(0.0, 360.0);
	}

	void Reroll()
	{
		int style = vgl_rand_style;
		double baseHue = frandom(0.0, 360.0);
		if (!vgl_lock_wb) RerollLane("vgl_wb_r", "vgl_wb_g", "vgl_wb_b", "vgl_wb_far_r", "vgl_wb_far_g", "vgl_wb_far_b", style, baseHue);
		if (!vgl_lock_wt) RerollLane("vgl_wt_r", "vgl_wt_g", "vgl_wt_b", "vgl_wt_far_r", "vgl_wt_far_g", "vgl_wt_far_b", style, baseHue);
		if (!vgl_lock_fg) RerollLane("vgl_fg_r", "vgl_fg_g", "vgl_fg_b", "vgl_fg_far_r", "vgl_fg_far_g", "vgl_fg_far_b", style, baseHue);
		if (!vgl_lock_cg) RerollLane("vgl_cg_r", "vgl_cg_g", "vgl_cg_b", "vgl_cg_far_r", "vgl_cg_far_g", "vgl_cg_far_b", style, baseHue);
	}

	void RerollLane(String rName, String gName, String bName, String farRName, String farGName, String farBName, int style, double baseHue)
	{
		color c = HSVtoRGB(StyleHue(style, baseHue), frandom(0.6, 1.0), frandom(0.7, 1.0));
		color f = HSVtoRGB(StyleHue(style, baseHue), frandom(0.5, 0.9), frandom(0.6, 0.9));
		CVar.FindCVar(rName).SetInt(c.r);
		CVar.FindCVar(gName).SetInt(c.g);
		CVar.FindCVar(bName).SetInt(c.b);
		CVar.FindCVar(farRName).SetInt(f.r);
		CVar.FindCVar(farGName).SetInt(f.g);
		CVar.FindCVar(farBName).SetInt(f.b);
	}

	void KeepThis()
	{
		if (vgl_preset <= 0) return;
		CVar.FindCVar("vgl_wb_r").SetInt(lastWB.r); CVar.FindCVar("vgl_wb_g").SetInt(lastWB.g); CVar.FindCVar("vgl_wb_b").SetInt(lastWB.b);
		CVar.FindCVar("vgl_wb_far_r").SetInt(lastWBFar.r); CVar.FindCVar("vgl_wb_far_g").SetInt(lastWBFar.g); CVar.FindCVar("vgl_wb_far_b").SetInt(lastWBFar.b);
		CVar.FindCVar("vgl_wb_far_on").SetInt(1);
		CVar.FindCVar("vgl_wt_r").SetInt(lastWT.r); CVar.FindCVar("vgl_wt_g").SetInt(lastWT.g); CVar.FindCVar("vgl_wt_b").SetInt(lastWT.b);
		CVar.FindCVar("vgl_wt_far_r").SetInt(lastWTFar.r); CVar.FindCVar("vgl_wt_far_g").SetInt(lastWTFar.g); CVar.FindCVar("vgl_wt_far_b").SetInt(lastWTFar.b);
		CVar.FindCVar("vgl_wt_far_on").SetInt(1);
		CVar.FindCVar("vgl_fg_r").SetInt(lastFG.r); CVar.FindCVar("vgl_fg_g").SetInt(lastFG.g); CVar.FindCVar("vgl_fg_b").SetInt(lastFG.b);
		CVar.FindCVar("vgl_fg_far_r").SetInt(lastFGFar.r); CVar.FindCVar("vgl_fg_far_g").SetInt(lastFGFar.g); CVar.FindCVar("vgl_fg_far_b").SetInt(lastFGFar.b);
		CVar.FindCVar("vgl_fg_far_on").SetInt(1);
		CVar.FindCVar("vgl_cg_r").SetInt(lastCG.r); CVar.FindCVar("vgl_cg_g").SetInt(lastCG.g); CVar.FindCVar("vgl_cg_b").SetInt(lastCG.b);
		CVar.FindCVar("vgl_cg_far_r").SetInt(lastCGFar.r); CVar.FindCVar("vgl_cg_far_g").SetInt(lastCGFar.g); CVar.FindCVar("vgl_cg_far_b").SetInt(lastCGFar.b);
		CVar.FindCVar("vgl_cg_far_on").SetInt(1);
		CVar.FindCVar("vgl_preset").SetInt(0);
		CVar.FindCVar("vgl_frozen").SetInt(0);
	}
}

class GL_OptionMenu : OptionMenu
{
	override void Init(Menu parent, OptionMenuDescriptor desc)
	{
		super.Init(parent, desc);
		DontDim = true;
		DontBlur = true;

		// DontPause is deliberately NOT set. It used to be, as the way to keep
		// the picture live under the menu: never pause, so WorldTick keeps
		// running. That worked, at the price of monsters carrying on attacking
		// while you picked colours. The handler pushes from UiTick now, so the
		// room re-tints under a properly paused game.
	}
}
