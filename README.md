# Elite for the TRS-80 Color Computer

A work-in-progress Motorola 6809 rewrite of Elite for the 64K CoCo 1/2. The rewrite follows the original game's data, rules and behaviour, with CoCo-specific graphics, keyboard input, disk overlays and banked cartridge support.

## Repository contents

- `coco-source/`: 6809 engine, flight, docked screens, title, overlay and cartridge boot code, plus Python build generators.
- `mk.ps1` and `build.bat`: build a disk image and cartridge image.
- [Controls and technical notes](coco-source/README.md).
- [Performance paper: audits, optimizations and measured results](PERFORMANCE.md).

Original BBC Micro sources, reference binaries, BBC build tools, emulator ROMs, generated output, local audit captures and unrelated ports are not included. Generated assets are created locally under `coco-source/gen/` and ignored by Git.

## Build on Windows

Requires Python 3, PowerShell, LWTOOLS `lwasm` and ToolShed `decb`. Put the tools on PATH or pass `-Python`, `-Assembler` and `-Decb` with their executable paths. XRoar or a compatible CoCo setup is needed to run the results.

The generators read the original ship blueprints, text tokens and dashboard image from an **external** checkout of [Mark Moxon's BBC Micro disc Elite source repository](https://github.com/markmoxon/elite-source-code-bbc-micro-disc). Keep that checkout outside this repository. The source tree used during extraction was based on commit `5af23a31c33ad159ff0b33c9f304741b4bc05fd6`.

```powershell
# Use the existing original-source checkout:
.\mk.ps1 -OriginalSource 'C:\Users\roniv\Dev\github\Elite'

# Or point to another external checkout:
$env:ELITE_ORIGINAL_SOURCE = 'C:\path\to\elite-source-code-bbc-micro-disc'
.\build.bat
```

`-OriginalSource` points to the repository root containing `1-source-files`, not to `main-sources`. The original files are read in place, never copied into this repository. `-Skip n` and `-Define NAME,NAME` remain available for development builds.

Outputs: `build/elite.dsk` and `build/elite.rom`. The cartridge targets a Super Program Pak style banked ROM (XRoar Games Master Cartridge type). Commander saving is supported on disk only.

On a 64K CoCo with Disk BASIC, mount the disk and run:

```basic
CLEAR 200,&H2800:LOADM"ELITE":EXEC
```

## Original sources and acknowledgements

Elite was written by **Ian Bell and David Braben**, originally published by **Acornsoft (1984)**. The annotated BBC Micro disc sources and explanations by **Mark Moxon** are the primary reference for this rewrite:

- [BBC Micro disc Elite: annotated source repository](https://github.com/markmoxon/elite-source-code-bbc-micro-disc)
- [Elite source code and technical commentary](https://elite.bbcelite.com)
- [Ian Bell's Elite homepage and original releases](http://www.elitehomepage.org/)

The rewrite's generators derive game data from those original sources; excluding the original source files does not make that data newly authored. Original game material and commentary retain their respective attribution. See the upstream repository's acknowledgements and copyright notes for the original material.
