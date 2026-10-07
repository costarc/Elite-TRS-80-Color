"""Decode the original dashboard image (P.DIALS.bin, BBC mode 5: 4 colours, 2 bits a pixel)
into pixels: 128 x 56, colour 0-3. python dashimg.py [png]  writes a preview."""
import sys
import os
from pathlib import Path
src = Path(os.environ['ELITE_ORIGINAL_SOURCE']) / '1-source-files' / 'images' / 'P.DIALS.bin'
data = src.read_bytes()
W, H = 128, 56


def pixels():
    px = [[0] * W for _ in range(H)]
    for row in range(7):
        for col in range(32):
            for line in range(8):
                b = data[row * 256 + col * 8 + line]
                for i in range(4):
                    c = (((b >> (7 - i)) & 1) << 1) | ((b >> (3 - i)) & 1)
                    px[row * 8 + line][col * 4 + i] = c
    return px


if __name__ == '__main__':
    from PIL import Image
    pal = {0: (0, 0, 0), 1: (255, 0, 0), 2: (255, 255, 0), 3: (0, 255, 0)}
    px = pixels()
    im = Image.new('RGB', (W * 2, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x * 2, y), pal[px[y][x]])
            im.putpixel((x * 2 + 1, y), pal[px[y][x]])
    im = im.resize((W * 2 * 4, H * 4 * 4 // 3 * 1), Image.NEAREST)
    im.save(sys.argv[1] if len(sys.argv) > 1 else 'build/dashimg.png')
    print('ok')
