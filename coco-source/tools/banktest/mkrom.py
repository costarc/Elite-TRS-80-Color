"""Bank-switching test cartridge for XRoar (Super Program Pak / Games Master style).

Builds build/romtest/t128.rom: eight 16K pages, page k holding the character 'A'+k at
$C100 and the same start-up code. The code copies itself to RAM, then writes 0..7 to
$FF40 and shows what each page has at $C100 on the text screen: ABCDEFGH when the
banking works.

  lwasm -9 --format=raw -o build/romtest/t.bin coco-source/tools/banktest/banktest.asm
  python coco-source/tools/banktest/mkrom.py
  xroar -machine coco2bus -ram 64 -cart tst -cart-type gmc -cart-rom build/romtest/t128.rom -cart-autorun -machine-cart tst

With -cart-type rom instead only page 0 is visible (AAAAAAAA).
"""
from pathlib import Path
root = Path(__file__).resolve().parents[3] / 'build' / 'romtest'
code = (root / 't.bin').read_bytes().ljust(0x4000, b'\0')
pages = []
for k in range(8):
    p = bytearray(code)
    p[0x100] = ord('A') + k
    pages.append(bytes(p))
(root / 't128.rom').write_bytes(b''.join(pages))
