# Elite for the TRS-80 Color Computer (CoCo 1/2)

A from-scratch 6809 rewrite of BBC Elite. Each routine is rebuilt from what the
original does mathematically (not translated instruction by instruction), but the
data, rules and behaviour stay the original's. Reference: the commented 6502
source in the external BBC Elite repository (see [setup and credits](../README.md)).

## Playing

Title: LEFT/RIGHT browse the ships, T shows or hides their names, C shows or hides the credits, SPACE pauses, ENTER or N starts a
game with the default commander (Jameson, docked at Lave), Y loads a commander from the disk first.

| key | in flight | docked |
| --- | --- | --- |
| arrows | roll and pitch | move the crosshairs on the charts (SHIFT: 4 times as far) |
| SPACE, `/` | faster, slower | |
| 0-3 | front, rear, left, right view | 0 launches |
| 4-9 | long chart, short chart, data on system, market prices, status, inventory (the game waits) | the same, and 1 buy, 2 sell, 3 equip ship |
| A | fire laser | |
| T, U, M | arm missile (target), unarm, fire | |
| E | E.C.M. | |
| B | energy bomb | |
| BREAK | escape pod | |
| C, P | docking computer on, off | |
| H | hyperspace to the system the crosshairs of a chart chose (open a chart with 4 or 5, move the crosshairs, press H) | |
| G | galactic hyperdrive | |
| Q | sound off and on | |
| @ | | the disk menu: load, save, catalogue, delete a commander (disk only) |
| O, D, F | | on a chart: the crosshairs to our system; name the nearest system; find a system by name |

Commanders are saved in the 18 sectors of `ELITE.SAV` on the disk (`flight/cmdr.asm`, `docked/disk.asm`);
the cartridge has no room for them.

## Build and run

Run `build.bat` from the repository root after following [the build setup](../README.md). Build options (`mk.ps1 -Skip n -Define A,B`):

| option | effect |
| --- | --- |
| `-Skip n` | fast-forward n title ticks first (`SKIPTICKS`) |
| `FREEZE` | draw one frame and hold it |
| `FULLAPPROACH` | title ship starts at the original z_hi = 96 instead of where it stops being a dot |
| `DEBUG` | hex dump of the engine state over the top of the screen |
| `SHIPSEL=n` | start on SHIPLIST entry n (0-based) instead of the Cobra |
| `FLYTEST` | run the flight test scene (ship movement, player controls) instead of the title |
| `VIEWH=n` | height of the 3D view in rows (default 144: the original's 192-line view and 64-line dashboard at 3/4, as its 256 lines are shown on 192); the rows below get the dashboard (`flight/dash.asm`) |
| `FLYVIEW=n` | with FLYTEST: start in view n (0 front, 1 rear, 2 left, 3 right); keys 1-4 switch the view while flying |
| `FLYSTILL`, `FLYROLL`, `FLYPITCH` | with FLYTEST: freeze the ships; simulate RIGHT / UP held |
| `FLYBOOM`, `FLYMIN` | with FLYTEST: a Cobra repeatedly blows up; only the planet, sun and that Cobra |
| `SKIPPLAN`, `SKIPSTARS` | with FLYTEST: leave the planet/sun or the stars out (profiling) |
| `BENCH` | run the micro-benchmarks and show the results as bars (`flight/bench.asm`); with `BFLY` only the whole-frame item, with `PROFLOOP` that frame forever (for profiling), with `LNTEST` a few test lines |
| `AUTOGAME`, `DOCKAUTO` | leave the title by itself; the docked screens' key wait returns `0` (launch) after a while |
| `DOCKKEY=n`, `DOCKKEY2=n` | the first screen key typed in the bay (ASCII, e.g. 55 for 7), and a second one after it |
| `KEYSEQ` | with the environment variable `KEYSEQ="text"` (`~` is ENTER) the docked screens read their keys from it, one every 20 ticks: `KEYSEQ='13~~~~'` buys 3 t of food |
| `FLYSCR=key`, `FLYSCRAT=n` | open the screen for that key (ASCII) at loop n |
| `FLYJUMP=n`, `FLYGHY=n`, `FLYBOMB=n`, `FLYESC=n`, `FLYAUTO=n` | at loop n: hyperspace to the system n light years east, the galactic hyperdrive, the energy bomb, the escape pod, the docking computer |
| `MISS1`, `MISS2` | a new commander who is ready for mission 1 / 2 |
| `DSKTEST`, `FINDTEST` | the disk menu with the commander TESTER (load him, or make him rich and save him); the find-system name DISO |
| `WEAKPERSP` | experimental, inexact perspective for distant ships; off by default |

## Media: disk and cartridge

`mk.ps1` builds both from the same sources:

* `build\elite.dsk` (`build.bat`): `ELITE.DAT` (the overlay blob, written first so its
  granules are known) and `ELITE.BIN` (the resident program and the title background,
  started with `LOADM`/`EXEC`). The loader reads the blob with Disk BASIC's `DSKCON`
  (the `[$C004]` vector), so it works with whatever sits behind it: floppy, DriveWire,
  SD controllers.
* `build\elite.rom` (`run-cart.bat`): a 64K Super Program Pak style banked ROM (the
  Rainbow, June 1990): 16K pages at `$C000-$FEFF`, page number written to `$FF40`
  (63 usable sectors a page, the top 256 bytes are behind the I/O area). Page 0 starts at
  `$C000`: `boot/cartboot.asm` copies its copier to RAM and then the program to RAM. XRoar
  runs it as `-cart-type gmc`. On a real CoCo it needs such a cartridge.

`engine/loader.asm` is the run-time side: `LOADSEG` brings a segment (`seg/*.asm`,
packed by `tools/segs.py`) into RAM above `$8000` sector by sector (medium driver reads
a sector into `STAGE` in ROM mode, then the all-RAM mode is switched on and the sector is
copied). Today one segment: `SHIPS`, the blueprints (8.9K; they used to take that much
of the 22K that `LOADM` can load). New overlays: add an entry to `SEGS` in `tools/segs.py`
and a `seg/<name>.asm`. Test switches: `SEGTEST` wipes the segment and reloads it at run
time (`SEGBAD` also skips the reload, to prove the wipe happened); `gdbmem.py` reads
RAM through XRoar's `-gdb` stub.

Known limits (not tested on real hardware): the disk path assumes Disk BASIC 1.0/1.1
(`$C004` vector, DOS variables around `$0900` left alone); the drive motor is not
switched off after loading (Disk BASIC's own timer is in its IRQ, which the game
replaces); the first read of a cold drive waits for spin-up inside `DSKCON`.

## Layout

```
main.asm            start-up and title loop (temporary driver)
engine/vars.inc     memory map and conventions
engine/math.asm     16x16->32 multiply, 32/16 divide, signed helpers
engine/line.asm     16-bit Cohen-Sutherland clip, Bresenham line
engine/ll9.asm      ship drawing (LL9): cone test, distance dot, detail level,
                    face culling, vertex projection, edges
engine/screen.asm   two-page flip through the SAM, vsync IRQ clock, hardware init
engine/keys.asm     keyboard matrix scan (IRQ), key presses
engine/mveit.asm    ship movement: MVEIT, MVS4/MVS5 rotations, TIDY, 24-bit helpers
engine/slots.asm    ship slot records (12 x 40 bytes at $F000), NEWSHIP
engine/loader.asm   LOADSEG: overlay segments from the disk or the cartridge
seg/ships.asm       overlay segment SHIPS (the blueprints), loaded at $C000
boot/cartboot.asm   cartridge boot code (page 0 of the ROM image)
engine/rand.asm     the original DORND generator
engine/stars.asm    stardust (front view)
engine/views.asm    rear/left/right stardust, view switch (SETVIEW) and the axes flip for ships (PUVIEW)
engine/planet.asm   planets (disc, equator/meridian, crater) and suns
engine/explode.asm  explosion clouds (DOEXP)
flight/flight.asm   player roll/pitch/speed, ship loop, flight test scene
flight/player.asm   player ship: lasers (A fires), sight, energy/shields, view banner, altitude, cabin temperature
flight/dash.asm     dashboard: art blit, scanner (SCAN), compass, gauges
seg/dash.asm        the DASH overlay segment: the dashboard art (tools/dash.py)
engine/text.asm     run-time text (centred string in 8x8 cells)
engine/debug.asm    hex dump aid
title/title.asm     TITLE / TLL2 / MVEIT rotation
tools/ships.py      original blueprints -> gen/ships.inc (original byte layout)
tools/assets.py     perspective tables, font, title background, sign-mask builder -> gen/assets.inc, gen/mkmask.inc
tools/linegen.py    the unrolled line loops -> gen/linefast.inc
tools/segs.py       overlay blob + segment tables; diskinfo.py (granules of ELITE.DAT); mkcart.py (ROM image)
tools/banktest      the bank-switching test ROM
flight/bench.asm    micro-benchmarks (BENCH)
```

## Design notes


* Ship coordinates are 24-bit, orientation vectors 16-bit with unity `$6000` as in
  the original; the renderer reduces them to 16-bit arithmetic with a per-ship
  scale shift and does perspective by normalising z and a reciprocal table.
* The original's 256-line screen is shown on 192 lines, so every vertical size is 3/4 of
  the original's (planets and suns are ellipses, ships are 3/4 as tall): the view is
  144 rows, the dashboard 48. The projection's y multiplier, the planet's vertical radius,
  the sun's rows and the stars apply the 3/4.
* Scanner contacts pulse between the normal dot and a larger marker for 1.5 seconds after
  firing at the player, including attackers outside the current 3D view. The 3D ship's
  appearance is unchanged.
* Everything is drawn with EOR like the original (crossings and overlaps invert,
  e.g. a ship over the sun shows dark lines).
* Face culling is the original rule `n . (P + n/2^scale) < 0`; edges and vertices
  honour the original distance-based detail levels.
* Speed: the engine is written for the 6809's strengths (hardware `MUL`, `LEAX D,X`,
  `PULS/PSHU` block moves, computed jumps into unrolled code); performance depends on scene complexity.
* Tick speed follows the work done, as in the original (no frame limiter there):
  `<work` counts pixels drawn plus a cost per projected vertex, and `FLIP` waits
  that many 1/60s frames (`engine/screen.asm`: `WORKBASE`, `VERTCOST`). The
  distant dot phase is therefore fast and the close Cobra runs at ~7 ticks/s.
* Glyphs are our own 5x7 font in 8x8 cells (the BBC MOS font is not
  redistributable). On the title screen LEFT/RIGHT arrows browse all ships (next/previous), SPACE pauses (development aids).
* Disk BASIC's LOADM cannot load at or above `$8000`, so the resident program lives in
  `$2800-$7EFF` plus low code at `$0E00-$25FF` (started with
  `CLEAR 200,&H2800:LOADM"ELITE":EXEC`). The sector buffer occupies `$7F00-$7FFF`.
  SHIPS and DOCK share `$C000-$EDFF`; DASH contains the dashboard art at `$F300`.
  PERF is loaded once at `$EE00-$EFFF` and retains the performance helpers and
  gauge tables across SHIPS/DOCK swaps. GEOM at `$B600-$B7FF` holds planar
  vertex transforms and the four view banners. Shaded scalar state lives at
  `$7EB0-$7EF1`, shaded span arrays at `$B800-$B97F`; optional roll logging
  uses `$7E00-$7EAF`. The resident program stays below `$7E00`. Assembly rejects either resident segment
  overflowing its safe range; overlay packing checks every padded segment.

