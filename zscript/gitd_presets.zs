// GlowInTheDark 2.0 -- presets.
//
// Nobody tunes ninety sliders. The presets are the mod; the sliders are for
// afterwards. Each one is built around a DIFFERENT mechanism rather than a
// different palette -- if two of these read the same on screen, that is a bug
// in the preset, because the levers they pull do not overlap.
//
// Every preset starts from Base(), which zeroes the whole per-pixel layer.
// Without that, switching presets would leave the previous one's cells or
// flow running underneath the new one's colours.

class GITD_Presets
{
	// ---- writers -----------------------------------------------------------

	static void Lane(String p, bool on, int policy, int r, int g, int b,
		double reach, int falloff, double inten, int farMode = 1,
		int farR = 0, int farG = 0, int farB = 0)
	{
		GITD_Util.SetB(p .. "_on", on);
		GITD_Util.SetI(p .. "_policy", policy);
		GITD_Util.SetC(p .. "_color", r, g, b);
		GITD_Util.SetF(p .. "_reach", reach);
		GITD_Util.SetI(p .. "_falloff", falloff);
		GITD_Util.SetF(p .. "_intensity", inten);
		GITD_Util.SetI(p .. "_far", farMode);
		GITD_Util.SetC(p .. "_farcolor", farR, farG, farB);
	}

	static void Window(double hMin, double hMax, double sMin, double sMax,
		double vMin, double vMax)
	{
		GITD_Util.SetF("gitd_hue_min", hMin);
		GITD_Util.SetF("gitd_hue_max", hMax);
		GITD_Util.SetF("gitd_sat_min", sMin);
		GITD_Util.SetF("gitd_sat_max", sMax);
		GITD_Util.SetF("gitd_val_min", vMin);
		GITD_Util.SetF("gitd_val_max", vMax);
	}

	static void LightDir(bool darkGlowsMore)
	{
		GITD_Util.SetB("gitd_light_invert", darkGlowsMore);
	}

	static void Wave(double len, double speed, double sharp, int shape,
		double reach, double bright, double colour,
		double detune = 0.0, double seed = 0.0)
	{
		GITD_Util.SetF("gitd_wave_len", len);
		GITD_Util.SetF("gitd_wave_speed", speed);
		GITD_Util.SetF("gitd_wave_sharp", sharp);
		GITD_Util.SetI("gitd_wave_shape", shape);
		GITD_Util.SetF("gitd_wave_reach", reach);
		GITD_Util.SetF("gitd_wave_bright", bright);
		GITD_Util.SetF("gitd_wave_colour", colour);
		GITD_Util.SetF("gitd_wave_detune", detune);
		GITD_Util.SetF("gitd_wave_seed", seed);
	}

	static void Phase(double wTop, double wBot, double fl, double ce)
	{
		GITD_Util.SetF("gitd_wave_ph_wtop", wTop);
		GITD_Util.SetF("gitd_wave_ph_wbot", wBot);
		GITD_Util.SetF("gitd_wave_ph_floor", fl);
		GITD_Util.SetF("gitd_wave_ph_ceil", ce);
	}

	static void Tex(double noise, double scale, double drift, double contrast)
	{
		GITD_Util.SetF("gitd_tex_noise", noise);
		GITD_Util.SetF("gitd_tex_scale", scale);
		GITD_Util.SetF("gitd_tex_drift", drift);
		GITD_Util.SetF("gitd_tex_contrast", contrast);
	}

	static void Flow(double amount, double spacing, double speed, double sharp)
	{
		GITD_Util.SetF("gitd_flow", amount);
		GITD_Util.SetF("gitd_flow_spacing", spacing);
		GITD_Util.SetF("gitd_flow_speed", speed);
		GITD_Util.SetF("gitd_flow_sharp", sharp);
	}

	static void Cells(double amount, double scale, double speed, double width)
	{
		GITD_Util.SetF("gitd_cell", amount);
		GITD_Util.SetF("gitd_cell_scale", scale);
		GITD_Util.SetF("gitd_cell_speed", speed);
		GITD_Util.SetF("gitd_cell_width", width);
	}

	// react is inert here by design -- it only scales the engine's
	// fog-disturbance array, which this mod never populates. The throb comes
	// from pulse/level. See vmthunks.cpp:4125.
	static void Throb(double pulse, double level)
	{
		GITD_Util.SetF("gitd_react", 0.0);
		GITD_Util.SetF("gitd_pulse", pulse);
		GITD_Util.SetF("gitd_pulse_level", level);
	}

	static void Liquid(bool on, int policy, int r, int g, int b,
		double reach, int falloff, double inten, bool walls)
	{
		Lane("gitd_liq", on, policy, r, g, b, reach, falloff, inten, 1);
		GITD_Util.SetB("gitd_liq_on", on);
		GITD_Util.SetB("gitd_liq_walls", walls);
	}

	static void Origin(int mode)
	{
		GITD_Util.SetI("gitd_wave_origin", mode);
	}

	// Neutral ground. Every preset starts here so none of them inherit the
	// last one's leftovers.
	static void Base()
	{
		Window(0, 360, 0.5, 0.85, 0.45, 0.9);
		LightDir(true);
		Wave(0, 1, 1, 0, 0, 0, 0, 0, 0);
		Phase(0, 0, 0, 0);
		Tex(0, 1, 0, 1);
		Flow(0, 1, 1, 1);
		Cells(0, 1, 1, 0.5);
		Throb(0, 0);
		Origin(0);
		GITD_Util.SetB("gitd_lock_planes", false);
		Liquid(true, 0, 60, 220, 70, 150, 2, 1.2, true);
	}

	// ---- the eighteen ------------------------------------------------------

	static void Apply(int idx)
	{
		Base();

		switch (idx)
		{
		case 0:  VanillaPlus();     break;
		case 1:  Bioluminescent();  break;
		case 2:  Reactor();         break;
		case 3:  Neon();            break;
		case 4:  Ember();           break;
		case 5:  Frostbite();       break;
		case 6:  Blacklight();      break;
		case 7:  Cathedral();       break;
		case 8:  PulseWave();       break;
		case 9:  Hazard();          break;
		case 10: Circuitry();       break;
		case 11: DeepWater();       break;
		case 12: Furnace();         break;
		case 13: Hellscape();       break;
		case 14: RedAlert();        break;
		case 15: Spore();           break;
		case 16: Signal();          break;
		case 17: Prism();           break;
		default: VanillaPlus();     break;
		}
	}

	// 0 -- signature: deliberately none. The restrained one.
	static void VanillaPlus()
	{
		Lane("gitd_wf", true,  0, 255, 170,  90,  56, 0, 0.60);
		Lane("gitd_wc", true,  0, 150, 140, 120,  48, 0, 0.45);
		Lane("gitd_fg", false, 0, 128, 128, 128,   0, 0, 0.00);
		Lane("gitd_cg", false, 0, 128, 128, 128,   0, 0, 0.00);
		Liquid(true, 0, 70, 210, 80, 120, 2, 1.0, true);
	}

	// 1 -- signature: cells, and the flat lanes carrying the look.
	static void Bioluminescent()
	{
		Window(150, 200, 0.55, 0.90, 0.40, 0.80);
		Lane("gitd_wf", true,  2, 0, 0, 0,  40, 2, 0.50);
		Lane("gitd_wc", false, 2, 0, 0, 0,   0, 0, 0.00);
		Lane("gitd_fg", true,  2, 0, 0, 0, 140, 2, 1.20);
		Lane("gitd_cg", true,  2, 0, 0, 0,  90, 2, 0.70);
		Cells(0.70, 1.6, 0.25, 0.45);
		Wave(220, 0.35, 0.6, 0, 0.30, 0.40, 0.20);
		Liquid(true, 0, 40, 255, 190, 180, 2, 1.5, true);
	}

	// 2 -- signature: flow, plus a floor/ceiling phase offset so the light
	// visibly climbs the room.
	static void Reactor()
	{
		Lane("gitd_wf", true, 0, 255, 140,  30,  80, 1, 1.30);
		Lane("gitd_wc", true, 0, 255,  90,  20,  70, 1, 1.00);
		Lane("gitd_fg", true, 0, 255, 120,  25, 110, 1, 1.10);
		Lane("gitd_cg", true, 0, 200,  70,  15,  80, 1, 0.80);
		Flow(0.80, 0.6, 1.6, 1.4);
		Wave(160, 1.2, 1.0, 1, 0.35, 0.60, 0.15);
		Phase(0.0, 0.5, 0.0, 0.5);
		Liquid(true, 0, 255, 110, 20, 200, 1, 1.8, true);
	}

	// 3 -- signature: exponential falloff and near-max saturation. Hard edges.
	static void Neon()
	{
		Window(0, 360, 0.95, 1.00, 0.75, 1.00);
		Lane("gitd_wf", true, 1, 0, 0, 0,  70, 3, 1.40);
		Lane("gitd_wc", true, 1, 0, 0, 0,  70, 3, 1.40);
		Lane("gitd_fg", true, 1, 0, 0, 0,  80, 3, 1.40);
		Lane("gitd_cg", true, 1, 0, 0, 0,  70, 3, 1.40);
		Tex(0.15, 2.0, 0.0, 1.6);
	}

	// 4 -- signature: light-keyed inverted, so the darkest rooms burn warmest.
	static void Ember()
	{
		Window(10, 40, 0.70, 1.00, 0.25, 0.75);
		LightDir(true);
		Lane("gitd_wf", true,  3, 0, 0, 0,  60, 1, 1.00);
		Lane("gitd_wc", true,  3, 0, 0, 0,  45, 1, 0.50);
		Lane("gitd_fg", true,  3, 0, 0, 0, 120, 1, 0.90);
		Lane("gitd_cg", false, 3, 0, 0, 0,   0, 0, 0.00);
		Tex(0.35, 1.2, 0.15, 1.2);
		Throb(0.25, 0.50);
		Liquid(true, 0, 255, 90, 20, 180, 1, 1.5, true);
	}

	// 5 -- signature: sqrt falloff over a very long flat reach. Spreads wide
	// and dies slowly, rather than hugging the wall.
	static void Frostbite()
	{
		Window(185, 215, 0.30, 0.60, 0.60, 1.00);
		Lane("gitd_wf", true, 2, 0, 0, 0,  90, 2, 0.50);
		Lane("gitd_wc", true, 2, 0, 0, 0,  90, 2, 0.50);
		Lane("gitd_fg", true, 2, 0, 0, 0, 220, 2, 0.80);
		Lane("gitd_cg", true, 2, 0, 0, 0, 160, 2, 0.60);
		Cells(0.35, 3.0, 0.08, 0.70);
		Liquid(true, 0, 150, 220, 255, 200, 2, 0.9, true);
	}

	// 6 -- signature: glow-texture contrast cranked, so lit detail pops and
	// everything between it drops away.
	static void Blacklight()
	{
		Window(275, 300, 0.85, 1.00, 0.35, 0.85);
		Lane("gitd_wf", true, 2, 0, 0, 0,  70, 3, 1.10);
		Lane("gitd_wc", true, 2, 0, 0, 0,  70, 3, 1.10);
		Lane("gitd_fg", true, 2, 0, 0, 0, 110, 3, 1.20);
		Lane("gitd_cg", true, 2, 0, 0, 0,  90, 3, 0.90);
		Tex(0.80, 2.5, 0.05, 3.0);
		Liquid(true, 0, 190, 90, 255, 170, 3, 1.6, true);
	}

	// 7 -- signature: vertical asymmetry. Ceiling lanes only, tall reach,
	// explicit deep-blue far colour. Light arrives from above.
	static void Cathedral()
	{
		Lane("gitd_wf", false, 0, 0, 0, 0,     0, 0, 0.00);
		Lane("gitd_fg", false, 0, 0, 0, 0,     0, 0, 0.00);
		Lane("gitd_wc", true,  0, 255, 205, 120, 200, 2, 1.10, 2, 12, 18, 60);
		Lane("gitd_cg", true,  0, 255, 190, 110, 180, 2, 0.90, 2, 12, 18, 60);
		Wave(400, 0.15, 0.5, 0, 0.20, 0.30, 0.10);
		Liquid(true, 0, 120, 150, 255, 140, 2, 0.8, false);
	}

	// 8 -- signature: the wave origin tracks the player, so glow ripples
	// outward from wherever you are standing. The one to show people in VR.
	static void PulseWave()
	{
		Window(190, 230, 0.60, 0.90, 0.50, 1.00);
		Lane("gitd_wf", true, 0, 170, 220, 255,  70, 0, 1.00);
		Lane("gitd_wc", true, 0, 170, 220, 255,  70, 0, 0.80);
		Lane("gitd_fg", true, 0, 190, 235, 255, 130, 0, 1.10);
		Lane("gitd_cg", true, 0, 150, 200, 255, 100, 0, 0.80);
		Wave(120, 2.0, 1.8, 0, 0.50, 0.90, 0.40);
		Origin(1);
	}

	// 9 -- signature: the liquid lane carries everything; the architecture is
	// near-monochrome. Only what can hurt you glows.
	static void Hazard()
	{
		Lane("gitd_wf", true, 0, 70, 70, 72,  50, 0, 0.35);
		Lane("gitd_wc", true, 0, 70, 70, 72,  50, 0, 0.30);
		Lane("gitd_fg", true, 0, 64, 64, 66,  70, 0, 0.30);
		Lane("gitd_cg", true, 0, 64, 64, 66,  60, 0, 0.25);
		Liquid(true, 0, 90, 255, 60, 220, 3, 2.00, true);
		Throb(0.20, 0.40);
	}

	// 10 -- signature: flow at very tight spacing and high sharpness, so it
	// reads as traces rather than as a gradient.
	static void Circuitry()
	{
		Window(165, 195, 0.70, 1.00, 0.50, 0.90);
		Lane("gitd_wf", true, 2, 0, 0, 0,  60, 3, 1.10);
		Lane("gitd_wc", true, 2, 0, 0, 0,  60, 3, 1.10);
		Lane("gitd_fg", true, 2, 0, 0, 0,  90, 3, 1.20);
		Lane("gitd_cg", true, 2, 0, 0, 0,  80, 3, 1.00);
		Flow(1.00, 0.18, 0.9, 3.0);
		Tex(0.10, 1.0, 0.0, 1.4);
	}

	// 11 -- signature: wave detune with a seed, so the bands lose phase with
	// each other instead of marching in step. Light through moving water.
	static void DeepWater()
	{
		Window(195, 240, 0.50, 0.85, 0.35, 0.80);
		Lane("gitd_wf", true, 1, 0, 0, 0,  80, 1, 0.80);
		Lane("gitd_wc", true, 1, 0, 0, 0,  80, 1, 0.70);
		Lane("gitd_fg", true, 1, 0, 0, 0, 200, 1, 1.00);
		Lane("gitd_cg", true, 1, 0, 0, 0, 140, 1, 0.80);
		Wave(300, 0.40, 0.7, 2, 0.60, 0.50, 0.50, 0.70, 12.0);
		Cells(0.20, 4.0, 0.12, 0.80);
	}

	// 12 -- signature: light-keyed FORWARD (the opposite of Ember) plus a fast
	// throb. Bright rooms run hottest.
	static void Furnace()
	{
		Window(0, 30, 0.85, 1.00, 0.40, 1.00);
		LightDir(false);
		Lane("gitd_wf", true, 3, 0, 0, 0,  75, 1, 1.30);
		Lane("gitd_wc", true, 3, 0, 0, 0,  65, 1, 1.00);
		Lane("gitd_fg", true, 3, 0, 0, 0, 130, 1, 1.20);
		Lane("gitd_cg", true, 3, 0, 0, 0, 100, 1, 0.90);
		Tex(0.25, 0.8, 0.30, 1.5);
		Throb(0.50, 0.70);
		Liquid(true, 0, 255, 70, 15, 210, 1, 1.9, true);
	}

	// 13 -- signature: the far-colour ramp is the whole effect. Bright crimson
	// at every seam bleeding out to near-black oxblood, mottled organic by
	// cells and noise, with a long flat reach so floors look soaked rather
	// than outlined. Nothing else in the set leans on the two-colour ramp.
	static void Hellscape()
	{
		Window(348, 8, 0.75, 1.00, 0.30, 0.80);
		Lane("gitd_wf", true, 1, 0, 0, 0,  90, 1, 1.20, 2, 26,  4,  6);
		Lane("gitd_wc", true, 1, 0, 0, 0,  70, 1, 0.90, 2, 20,  3,  5);
		Lane("gitd_fg", true, 1, 0, 0, 0, 200, 1, 1.30, 2, 30,  5,  7);
		Lane("gitd_cg", true, 1, 0, 0, 0, 120, 1, 0.90, 2, 18,  3,  5);
		Cells(0.45, 2.2, 0.15, 0.55);
		Tex(0.50, 1.4, 0.08, 1.8);
		Liquid(true, 0, 200, 20, 25, 240, 1, 1.60, true);
	}

	// 14 -- signature: the throb IS the effect. No wave, no flow, no cells --
	// nothing else moving, so the pulse has the room to itself. Exponential
	// falloff on all four lanes hits hard and dies fast at the edges.
	static void RedAlert()
	{
		Lane("gitd_wf", true, 0, 255, 20, 25,  80, 3, 1.50);
		Lane("gitd_wc", true, 0, 255, 20, 25,  80, 3, 1.50);
		Lane("gitd_fg", true, 0, 255, 25, 30, 100, 3, 1.50);
		Lane("gitd_cg", true, 0, 255, 20, 25,  90, 3, 1.40);
		Throb(0.85, 0.90);
		Liquid(true, 0, 255, 40, 40, 160, 3, 1.7, true);
	}

	// 15 -- signature: cells dense, small and slow. Flat lanes only, low
	// value. Grows on the ground rather than lighting the room.
	static void Spore()
	{
		Window(55, 85, 0.50, 0.80, 0.20, 0.50);
		Lane("gitd_wf", false, 2, 0, 0, 0,   0, 0, 0.00);
		Lane("gitd_wc", false, 2, 0, 0, 0,   0, 0, 0.00);
		Lane("gitd_fg", true,  2, 0, 0, 0, 130, 2, 0.70);
		Lane("gitd_cg", true,  2, 0, 0, 0,  90, 2, 0.45);
		Cells(0.90, 6.0, 0.05, 0.25);
		Liquid(true, 0, 140, 190, 60, 150, 2, 0.9, false);
	}

	// 16 -- signature: hard-banded wave with the wall's top and bottom half a
	// cycle apart, so the band sweeps rather than pulses flat.
	static void Signal()
	{
		Lane("gitd_wf", true, 0, 255, 180, 40,  75, 3, 1.30);
		Lane("gitd_wc", true, 0, 255, 180, 40,  75, 3, 1.30);
		Lane("gitd_fg", true, 0, 255, 190, 60, 110, 3, 1.20);
		Lane("gitd_cg", true, 0, 255, 170, 30,  90, 3, 1.00);
		Wave(180, 1.4, 4.0, 1, 0.70, 1.00, 0.00);
		Phase(0.0, 0.5, 0.25, 0.75);
	}

	// 17 -- signature: the full hue circle, but pulled right down in
	// saturation and up in value. 1.1's "colourful maps" idea as pastel
	// instead of as a rainbow assault -- and unlike 1.1, actually per sector.
	static void Prism()
	{
		Window(0, 360, 0.18, 0.35, 0.85, 1.00);
		Lane("gitd_wf", true, 1, 0, 0, 0,  90, 0, 0.90);
		Lane("gitd_wc", true, 1, 0, 0, 0,  90, 0, 0.90);
		Lane("gitd_fg", true, 1, 0, 0, 0, 150, 0, 1.00);
		Lane("gitd_cg", true, 1, 0, 0, 0, 120, 0, 0.85);
	}
}
