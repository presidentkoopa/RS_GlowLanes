GlowInTheDark 2.0
=================

A ZScript rewrite of GlowInTheDark 1.1 (PresidentKoopa, 2021) for UZDXREMA.
Same name, almost nothing else in common -- the original was ACS and could only
reach a fifth of the engine's glow stack.


WHY IT WAS REWRITTEN
--------------------

Tracing 1.1 through the engine turned up three things:

* It only ever lit WALLS. ACS SetSectorGlow writes planes[].GlowColor and
  nothing else (p_acs.cpp:6714). Floor and ceiling faces were never touched,
  so the engine's entire flat-glow system was invisible to it.

* Its randomisation never happened. The first argument is a sector TAG, not an
  index, and tag 0 matches every UNTAGGED sector at once (p_tags.cpp:419).
  random() is evaluated once per call, so the whole map got a single shared
  colour. Everything after tag 0 hit only doors and lifts.

* Its throttle test was inverted, so those doors and lifts arrived at about one
  per tic -- roughly 47 minutes to finish a sweep.

Colours were also read once before the loop, which is why 1.1's menu says
changes need a map restart.


WHAT THIS DOES INSTEAD
----------------------

Four lanes, each independently configured:

  wf   wall above the floor seam       (reach is VERTICAL, up the wall)
  wc   wall below the ceiling seam     (reach is VERTICAL, down the wall)
  fg   the floor's own face            (reach is HORIZONTAL, inward from edges)
  cg   the ceiling's own face          (reach is HORIZONTAL, inward from edges)

Both systems call their reach "height" in the engine, and they mean different
axes. The menu labels which is which.

Four colour sources, selectable per lane:

  Fixed              one colour everywhere
  Random per sector  stable-hashed, so sliders re-tint without reshuffling
  Texture/material   same flat, same colour, map-wide, no texture table
  Light level        keyed to the sector's own brightness, direction switchable

All of them land in the same HSV window, so the Randomiser page's hue,
saturation and value ranges bound every source except Fixed.

Liquids are detected via the map's terrain definitions (TerrainDef.IsLiquid),
not a texture list. They override the floor lane and get their own config.
This is what replaces 1.1's gldefs.bm, and it lights the liquid's own surface,
which GLDEFS-based glow never did.

Eighteen presets, each built around a different mechanism rather than a
different palette -- if two of them look alike, that is a bug.

Sector iteration is by index over Level.Sectors, chunked at 2000 per tic. A
5000-sector map completes in three tics.


NOTHING NEEDS A MAP RESTART
---------------------------

Lane changes re-apply within about five tics. Wave and Surface Detail push
every tic.

The per-pixel layer -- Wave, Surface Detail, the alarm -- is pushed from
UiTick as well as WorldTick, so it keeps moving while the game is PAUSED and
while the menu is open. Drag a wave or cells slider with the menu up and the
picture moves under it. That is what the engine's clearscope declarations on
those functions are for.

Known limit: the four LANE pages cannot do that. Sector.SetGlowColor and its
siblings are play scope, not clearscope, so a paused playsim genuinely cannot
re-tint sectors -- no mod can work around it. Lane edits apply the instant you
unpause. Making those four setters clearscope would fix it, but that is an
engine change, not a mod one.

RANDOMIZE ON DEATH
------------------

Options > GlowInTheDark > Randomize on death.

  New colours   same preset, new seed -- the look you tuned holds, the map
                re-tints
  New preset    a different look entirely each time you die

Rolls skip preset 0 (Vanilla+), because landing on the deliberately restrained
one reads as the mod having switched itself off. Same rule as map shuffle.


TESTING IT
----------

Load it alone first, with the old Environmental_Lighting03_GlowInTheDark.pk3
UNLOADED -- both write GlowColor and they will fight.

1. Prove the flat lanes. Options > GlowInTheDark > Floor Face. Turn off the two
   wall lanes, set Floor Face to a saturated fixed colour with reach ~200.
   The FLOOR SURFACE should light up, not just the wall beside it. This is the
   thing 1.1 could not do at all; if it does not work, nothing else matters.

2. Prove liveness. Drag any lane slider while playing. It should re-tint within
   a fifth of a second with no hitch.

3. Prove stability. Drag a Randomiser slider. Sector colours should shift as a
   group, never reshuffle.

4. Prove liquids. Any map with lava or slime, Liquids page enabled.

5. Walk all eighteen presets on one map.

6. Big map, 5000+ sectors, watch for a spike when a setting changes.


THINGS I COULD NOT VERIFY WITHOUT RUNNING IT
--------------------------------------------

Being explicit about these rather than letting you find them:

* Nothing here has been compiled. The ZScript is written against the engine's
  actual declarations and every CVar name is cross-checked against cvarinfo,
  but a syntax error is entirely possible on first load.

* Wave "shape" is exposed as 0-4 because the API takes an int and the engine
  does not document the range for this call. Some values may do nothing.

* "Disturbance reach" on the Surface Detail page is inert on its own. The
  engine's react parameter only scales the fog-disturbance array, which this
  mod never populates (vmthunks.cpp:4125). It is exposed for other mods that
  do. The throb in Red Alert and elsewhere comes from pulse/level, which are
  self-contained.

* Flat glow uses at most 64 of a sector's edges (hw_flats.cpp:462, count is
  clamped). Very large or very complex sectors may glow from only part of
  their perimeter. Nothing to do about it mod-side.

* All preset values are chosen from the parameter semantics, not from looking
  at them. Expect to want to tune them.


FILES
-----

  cvarinfo              82 CVars, archived so settings persist
  menudef               main page plus eight submenus
  mapinfo               registers the event handler (without this: nothing)
  zscript.txt           version guard and includes
  zscript/gitd_util.zs      hashing, HSV, far-colour derivation, CVar helpers
  zscript/gitd_policy.zs    the four colour sources
  zscript/gitd_presets.zs   the eighteen looks
  zscript/gitd_handler.zs   applies lanes, drives the per-pixel layer

No engine changes. Everything used here was already exported.
