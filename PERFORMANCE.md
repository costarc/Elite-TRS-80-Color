# Making Elite run well on the TRS-80 Color Computer

## A measured rewrite of a 2 MHz game for a slower 6809

Elite's BBC Micro edition runs on a 2 MHz 6502. This rewrite targets a stock CoCo 1/2, whose 6809 runs at about 0.895 MHz. The machine also has different video and sound hardware. A direct cycle-count comparison therefore says little about how a frame feels: the renderer has to finish before a 60 Hz screen refresh, and a synchronous sound effect can hold up the entire game. The goal of the work described here was to make a complete, playable game responsive on that hardware while preserving its rules and visual character.

This paper records three stages of work: the first renderer performance pass; two independent audits of the playable port and their consolidated roadmap; and the measured implementation pass that followed. It distinguishes measured results from estimates and keeps unlike test scenes separate. All frame rates below are emulator measurements, not a claim about every point in ordinary play.

## First pass: find and remove the expensive work

The initial performance work used XRoar's instruction trace with cycle timing, per-routine benchmarks and a deliberately crowded flight scene: six ships, planet, sun and stars. It focused on the actual hot paths, especially ship projection, line drawing and celestial rendering. The early claim of **1.3–1.9 frames/s before** this work came from a roadmap estimate and costs of component routines; that version was **not timed end to end**. A later version of the crowded scene measured about **4.2 frames/s** in the original pass. Subsequent audits found that this was a particular stationary fixture, not a general heavy-flight baseline.

Several changes exploited the 6809 rather than translating the 6502 routine by routine:

| Work | Change | Historical routine measurement |
| --- | --- | ---: |
| Ship projection (`LL9`) | Inline 8×8 `MUL`, sign masks, reciprocal lookup and computed-entry shifts instead of repeated general division and helper calls | Cobra at z=3000: 49k → 28k cycles; at z=400: 74k → 57k |
| Vertex transform | Precompute signs per ship, use 6-bit matrix units and avoid repeated shifts | 24.6k → 12.7k cycles for the sampled Cobra |
| Line rasterization | Unroll the pixel loop and use a two-ended path only when the line is long enough to repay its setup | 32 roughly 60-pixel lines: 97k → 58k cycles |
| Planet and sun | Replace repeated division and trigonometry with reciprocal/sine tables, incremental square root and cached sun row widths | Planet K=20: 66k → 33k; sun K=35: 46k → 25k |
| View clearing | Stack-based row writes with border bytes folded into the pass | 18.7k → 12.9k cycles in the early benchmark |

These are *routine* comparisons from the first pass, not additive frame savings. A ship renderer includes line drawing, and the exact scene, image and code revision matter. The initial pass also moved hot planet and sun scratch data into the 6809 direct page, reducing extended-address accesses. A two-ended line algorithm for *every* short line was rejected after it made the crowded scene about 2% slower; most lines there were too short to amortize setup. A distant-ship weak-perspective shortcut introduced visible shear and stayed experimental.

## The audits: measure whole frames and challenge the baseline

The playable game had gained a dashboard, overlays, combat, sound and time-based simulation. That changed the cost of a frame. Two later audits used XRoar instruction traces to measure complete flight frames and compare selected routines with the original BBC implementation. They identified flaws in the old test setup: direct `FLYTEST` startup could read uninitialized message state, and an artificial close planet could kill the player after a few frames. A trace that includes death or unintended text is not a valid steady-flight result. The audit fixtures used controlled RAM and a narrowly scoped death bypass, counted only complete live frames, and recorded the scene and build defines.

The consolidated pre-implementation measurements were:

| Controlled scene | Complete frames sampled | Mean cycles/frame, including wait | Frames/s |
| --- | ---: | ---: | ---: |
| Six moving ships, planet and visible sun; clear RAM | 11 | 225,081 | 3.98 |
| Six still ships, planet and sun; clear RAM | 12 | 213,808 | 4.19 |
| Three hostile ships, distant planet, no sun | 24 | 113,714 | 7.87 |
| Immediate launch, planet ahead and station behind | 12 | 44,745 | 20.00 |
| Independent longer six-ship fixture, still ships with repeated message work | 110 | 244,603 | 3.66 |

The two six-ship figures do not contradict one another. Their movement, message state, visible sun, RAM initialization, window length and test defines differ. Likewise, a default-RAM moving fixture reached only 3.51 frames/s partly because of unintended text; removing that text from a test is a **fixture correction**, not a demonstrated normal-game optimization. Normal launch already initialized that message state.

In the 225k-cycle moving fixture, active work concentrated in ship drawing (**95.9k cycles**, including transform, face tests and edges), planet/sun (**53.1k**), movement (**16.0k**), dashboard (**12.8k**) and view clearing (**9.7k**). The original BBC and CoCo routine studies explained why an apparently efficient 6809 port could still feel slower: the CoCo has less than half the CPU clock rate, short-line setup and normalization can dominate, and double buffering requires explicit clearing and dashboard restoration. One matched 32-line endpoint test took **97,615 BBC cycles at 2 MHz** versus **57,240 CoCo cycles at 0.895 MHz**: fewer CoCo cycles, but **48.8 ms versus 64.0 ms**. These are selected rendering jobs, not a whole-game BBC-versus-CoCo FPS comparison.

The audits found a second issue independent of raw frame rate. The launch scene could draw about 20 frames each second while advancing the 10 Hz reference simulation on only alternating frames. That meant roughly ten distinct positions per second. Faster rendering alone would not smooth motion. The audit also measured synchronous sound as a substantial event cost: approximately **39,907 cycles for the player laser**, **93,340 for a hit/kill effect** and **247,319 for death** in an isolated playback fixture. Those are event costs, not a sustained-combat FPS prediction.

Finally, memory was a hard engineering limit. At the audit revision, the resident program had **737 bytes** before the `$7E00` staging boundary, and the low segment had **60 bytes** left. Proposed lookup tables, caches, dirty tracking and audio buffers could not all be accepted by adding their projected savings on paper. Every change had to fit the build map, preserve disk and cartridge loading, and win in a measured scene.

## From recommendations to shipped code

The consolidated roadmap numbered proposals O01–O24. The subsequent performance pass implemented a selected set. It used a **12-emulated-second**, clear-RAM, alive-frame XRoar cartridge fixture for the heavy scene. “Active cycles” below exclude the `FLIP` wait for vsync; the first row's total **223,254 cycles/frame including wait** was about **4.01 frames/s**. Each row is the state *after* that change, in the same pass, not a saving to add to the previous rows.

| Step | Implementation | Heavy-scene active cycles/frame |
| --- | --- | ---: |
| Baseline (`06c6bcf`) | Starting build for this implementation pass | 216,551 |
| O03 | Compile the weak-perspective experiment only when requested | 215,981 |
| O05 | Specialized exact normalization/division and startup tables | 208,031 |
| O04 | Fixed word copies for slot updates | 206,122 |
| O06 | Batch each ship's already-rounded forward increment | 203,650 |
| O15 | Reject hulls wholly outside the view before projection | 198,272 |
| O11, viewport half | Track marks per display page and clear only drawn regions, with full-clear fallback | 200,446 |

O15's fixture was reported at **4.33 frames/s**. O11 added about **2.1k active cycles** in that crowded scene but improved the sparse launch path from **38.9k to 33.4k active cycles**. Keeping the fallback and a net win in sparse views was more useful than claiming dirty clearing always wins. The implementation report recorded **zero failures across roughly 700 partial clears** in its dirty-region check. A culling check exercised **203 rejected hulls** under roll, pitch, AI and spawning without observing a line that should have been drawn. The arithmetic helpers were exhaustively checked over their bounded inputs against the prior results.

Other changes were conditional or addressed responsiveness rather than the no-message heavy benchmark:

- **Messages (O08):** Set text once into a buffer and OR its pixels into subsequent frames. With a real `ENERGY LOW` message, average `MSGDRAW` cost fell from **7,722 to 1,646 cycles/frame** in the reported fixture. The silent six-ship scene had no such gain.
- **Sound (O09):** The Q key now cycles through full sound, short combat sound and off. In a firing scene, the reported rate rose from **1.77 to 2.33 frames/s** with short effects. Shorter audio changes the sound deliberately; it is not presented as a free or exact CPU optimization.
- **Timing and controls (O02/O17):** Flight no longer enforces a minimum frame duration. Game rules retain the 10 Hz reference loop, while player roll, pitch and speed distribute movement across actual vsyncs with carried remainder. The pass reported **20 distinct positions/s in a 20 FPS launch scene**, rather than ten, with matching motion totals. A later 20-second heavy comparison reported **4.77 versus 4.80 frames/s**, indicating little cost there. Other ships' turns remained tied to the reference loop.

The viewport change also exposed and fixed a clipping bug: the next circle segment had reused a clipped endpoint, flattening rings at the screen edge and XORing away the border. This mattered to visual correctness as much as speed.

## What the numbers mean

The work produced large early gains in renderer routines, then smaller, measured gains in a complete game whose CPU budget was already tight. **4.33 frames/s** is the O15 heavy fixture result; **3.98**, **4.19** and **3.66 frames/s** belong to earlier audit fixtures with different conditions. The final dirty-clear step did not improve the crowded fixture's active cycles, and the later smooth-motion result is a separate timing experiment. None of these is a universal gameplay FPS figure, nor proof of a single cumulative before/after speedup from the earliest estimate.

The work also shows why careful measurement mattered. It caught test-state contamination, death frames, nested profiler costs, vsync rounding and RAM pressure before they could become misleading claims. The result is a port that was optimized through trace-guided 6809 design, cross-checked against the original, tested across crowded and sparse scenes, and revised when an appealing shortcut lost performance or changed the picture. Further work remains possible in dashboard caching, line setup and geometry specialization, but the roadmap's estimates for those items are not counted as achieved results here.

## Exact follow-up pass — 8 October 2026

This pass starts from the planet projection/type/detail checkpoint `90e05aa`. The
historical frame-rate figures above predate those planet changes and are not its
baseline. The default picture and game rules remain the reference for this pass.

| Roadmap item | Current implementation |
| --- | --- |
| O07 | Thirteen bar/marker values cached separately for each physical display page; exact nine-byte compass input cache; dashboard initialization invalidates both page caches. |
| O10, selected line specialization | Horizontal XOR spans write whole interior bytes and mask both endpoints; clipped and sloping lines keep their existing paths. General vertex endpoint-address caching is not included. |
| O11, scanner half | Six dirty bands per display page, restored in batches of eight rows (two rows in the last band). Contacts, attack pulses, compass and both bulbs mark their covered bands. Initializing a page forces its first full restoration. |
| O12 | Cache 32 circle magnitudes keyed by both radii. A changing radius uses the original path; a repeated radius builds the table. Centers and clipping remain live, and planet meridians remain orientation dependent. |
| O13, face specialization | Inline the nine exact signed face-view products and skip zero face-normal terms. Both later normal sign shifts still occur when a term is zero. Vertex product specialization is not included. |
| O17 | Flight bypasses vertex work counting when the synthetic work budget is zero. Title, hangar and mission timing retain their work budgets; FLYSWEEP retains its counter. Unused arithmetic helpers and release-only debug data/code are omitted. |

The new **PERF** segment is loaded once into `$EE00-$EFFF`; it remains available
when SHIPS and DOCK replace one another at `$C000`. It contains the performance
helpers, gauge tables and relocated startup arithmetic/market/random helpers.
The segment is 490 bytes, padded to two sectors. SHIPS and DOCK are bounded
below `$EE00` so loading either cannot overwrite PERF. The existing shaded-mode
workspace at `$B700-$B97F` remains separate. The circle table and dashboard
cache state occupy previously unused workspace. Assembly now rejects resident
code reaching the sector staging buffer or low code exceeding `$25FF`, and blob
packing checks the padded PERF allocation. This preserves the original disk and
cartridge loading layouts rather than expanding the low resident segment into
Disk BASIC workspace.

### Validation and measured limits

The comparisons execute the production routines in XRoar `coco2bus`, 64K, clear
RAM, with instruction timing. Before and after receive the same component inputs;
these are routine measurements, not whole-game FPS claims.

| Comparison | Coverage | Mean cycles before → after |
| --- | --- | ---: |
| Dashboard | 128 frames; alternating pages, gauge changes, moving contacts, compass changes and repeated initialization; every dashboard byte compared | 8,879 → 6,601 |
| Horizontal lines | 4,032 spans; every start bit, zero length, byte boundaries, long spans and right-edge saturation; framebuffer bytes compared | 629 → 238 |
| Face visibility | 3,968 sets; all 31 blueprints, signed inputs, near-face bias and detail levels; visibility bytes and ship-space vectors compared | 3,642 → 3,552 |
| Circle cache hits | All 256 byte-sized radii, three successive calls per radius; 22,272 projected points compared across misses/builds/hits | 6,312 → 5,242 |

All component comparisons matched. The projection (432 cases), close-up detail
(204 cases), and planet technology/type regressions (2,048 systems) also passed.
Disk BASIC LOADM/EXEC reached flight with the persistent segment loaded; the
normal cartridge reached its running title screen. Both normal game images are
rebuilt at the end of the pass. Local regression tools remain outside the commit,
as requested; they are not bundled as a new public benchmark harness.

Initial whole-scene traces are invalidated: the initial PERF placement overlapped
`shade` at `$B700`, so startup cleared the first instruction byte of CIRCACHE.
This accidentally negated circle radii and distorted both the tunnel and planet.
The corrected layout reserves `$EE00-$EFFF`, and full launch/tunnel rendering is
checked against the original checkpoint before publishing any frame-rate claim.
All ten tunnel frames now match the original binary byte for byte; launch keeps
the original 65,536-unit planet position and 96-pixel projected radius.

Still unimplemented are general endpoint caching, predecoded/zero-specialized
vertex transforms, mirror-pair vertex reuse (O14), and rotated-geometry caching
(O16). They require a measured net saving including metadata and cache misses.
The optional approximation, quality, hardware and ROM-execution proposals
(O18–O24) are also outside this exact stock-CoCo pass. None of their estimated
savings is counted above.

### O13 planar vertices — second follow-up

Vertices with zero Y use two products per row instead of three. The zero term
still contributes `$FFFF` when its XOR mask is negative; it is never dropped as
mathematical zero. The helper preserves the original X/Y overflow saturation,
shift ladder and live Z clamp/projection. Non-planar vertices keep the original
nine-product path.

Across 992 transforms using all 31 blueprints, both signs, seven shift counts,
detail thresholds and gun-vertex sentinels, all 317,440 projected coordinate and
outcode bytes matched. The natural blueprint fixture averaged 12,158.34 cycles
before and 12,130.69 after: a small aggregate saving, not the original 6–12k
whole-frame hypothesis. A second 992-case run with artificial negative-zero
vertex signs also matched all bytes, exercising the complement-bias case. Three
shaded title frames leave GEOM and PERF byte-identical to their source binaries.

GEOM is a persistent two-sector allocation at `$B600-$B7FF` (455 bytes of code
and view-banner data). Moving the 320-byte view banners out of the resident
image makes room without touching ship data. Shaded scalars move to
`$7EB0-$7EF1`; its span arrays stay at `$B800-$B97F`. Roll-test logging moves to
`$7E00-$7EAF`, with its pointer and sweep counters outside GEOM. Assembly guards
the resident end at `$7E00`, and segment packing guards GEOM below `$B800`.

### O10 general endpoint-cache gate

A lazy address-cache prototype was replayed against 225 direct ship-edge calls
from the first 32 drawn hulls of the isolated six-ship trace. Both versions
returned every expected framebuffer address. Including hit/miss bookkeeping and
selection of the left endpoint after a swap, the address stage averaged 54.00
cycles without caching and 61.14 with caching. This excludes the extra work a
production cache would need to reconstruct clipped coordinates, so the result
is already optimistic for the cache.

Across the whole captured trace, 500 of 1,333 left-endpoint accesses reused a
previous start vertex; 833 were first accesses. General endpoint-address caching
is therefore rejected for this pass. The shipped horizontal-span specialization
remains; the slower prototype is kept out of the game and its estimates are not
counted as savings.

### O14 mirror-pair gate

A runtime mirror-pair prototype cached each row's first product and raw sum.
For a matching X-mirror it recombined the exact complemented term as
`new_sum = old_sum - 2 * old_x_term - 1` modulo 16 bits. It reset the cache at
ship boundaries and consumed each matching pair once.

Across the same 992 natural blueprint transform cases, every one of the 317,440
coordinate/outcode bytes matched. Mean transform cost increased from 12,130.69
to 13,325.46 cycles (9.85%) after accounting for key comparisons, cache writes
and row dispatch. This runtime implementation is rejected and is not shipped.
A future predecoded pairing layout would have to beat that overhead and fit the
loader allocations; the original 5–7k estimate remains unproven.

### O16 rotated-geometry cache gate

The cache was measured in the six-still-ship `FLYTEST,FLYSTILL,AUDITSAFE`
cartridge fixture. At the entry to `TRANSFORM`, the full key was the blueprint
pointer plus all 18 matrix magnitude/sign bytes. Across 120 calls there were 12
distinct keys; a six-entry LRU replay hit 108 calls (90%), while capacities of
one through five hit none. Each ship's key was stable for 90–95% of its calls.

The six blueprints contain 106 vertices in total (10, 11, 15, 17, 25 and 28).
Caching three 16-bit rotated offsets per vertex takes 636 bytes, before the
six full keys (at least 120 bytes) and validity state. Even borrowing both the
384-byte shaded-span workspace and all 256 bytes at `$7E00-$7EFF` would provide
only 640 bytes, and those ranges already hold live shaded-mode and test data.
The exact cache therefore does not fit the available safe workspace. O16 is
rejected for this pass; no projected cycle saving is claimed.

### View-banner packing prerequisite

The fixed uppercase view names have an empty eighth bitmap row. GEOM now stores
seven rows per view and BANNER writes the last row as zero words. This removes
40 bytes of duplicated bitmap data. All four complete framebuffers match the
prior version, including the unchanged background outside the banner.

## Provenance and reproducibility

This paper consolidates the local project records `CoCo/PERFORMANCE.md`, `CoCo/PERFORMANCE-AUDIT.md`, `CoCo/Elite-CoCo-Optimization-Roadmap-Final.md`, `CoCo/PERF-PASS.md`, `CoCo/consolidated-fps-measurements.csv` and the independent Audit A in `CoCo/consolidated-audit-evidence.zip` from the separate `Elite` working tree. The original records remain there; they are not duplicated in this repository. The roadmap audited source commit `06c6bcf7c188db8580f50b01059f4cf705862fd8`, and the implementation pass started at that commit. The current implementation is in [`coco-source/`](coco-source/), including the renderer, flight timing, sound and view-clear routines named above.

The audit reports' XRoar instruction traces used `coco2bus`, 64K RAM, the cartridge build and cycle timing. They divided trace `dt` by 16 for CPU cycles and used approximately **894,886 cycles/s** for nominal elapsed time. Audit A excluded the first two completed frames and the final incomplete frame. The later implementation pass used `perf.sh FLYTEST,AUDITSAFE 12 <name>` in the original working tree; that profiling harness and its trace output are not shipped here. Reproducing *those exact historical figures* requires the original fixture defines, revision, emulator setup and logs. The present repo builds the game; it does not bundle the original BBC sources or the audit archive.
