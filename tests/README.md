# Planet projection regression

`planet_projection.py` assembles the game's actual projection and visibility
routines into a small test cartridge and runs it in XRoar. It needs Python 3,
LWTOOLS `lwasm`, XRoar and the usual CoCo BASIC ROMs; it does not need the
external BBC Elite checkout.

With tools on PATH:

```bat
python tests\planet_projection.py --rompath "C:\Apps\XRoar\roms"
```

With this project's local Windows tool paths:

```bat
"C:\Apps\Python\python.exe" tests\planet_projection.py --assembler "C:\Users\roniv\Dev\6809ASM\lwtools-4.25-win64\lwasm.exe" --xroar "C:\Apps\XRoar\xroar.exe" --rompath "C:\Apps\XRoar\roms"
```

The 432 cases cover both pitch directions, horizontal and diagonal motion,
four planet distances, behind-camera and near-plane rejection, and extreme
signed coordinates. The old projection fails 14 cases, including the planet
reappearing at 65 degrees of pitch at a distance of 65,536 units. The fixed
projection passes all cases. The test checks bounding-disc visibility, not
pixel-for-pixel rasterization or interactive gameplay.

Test cartridges are temporary files under `build/`. The runner terminates only
the emulator process it starts.
