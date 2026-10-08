"""Generate the Cobra Mk III blueprint tables, reciprocal table and title bitmap.

Blueprint numbers come from the documented BBC Elite Cobra Mk III (vertices,
edges, faces). They are repacked here for the 6809 renderer in main.asm:

  VERTS  4 bytes: |x|/2, |y|, |z|, sign flags (bit7 x, bit6 y, bit5 z)
         (every Cobra x is even and reaches 128, so x is stored halved)
  FACES  6 bytes: |nx|, |ny|, |nz|, sign flags, K hi, K lo
         K = |n|^2 / 2^scale (scale = 1), the original's visibility bias
  EDGES  4 bytes: vertex1*2, vertex2*2, face1 | face2<<4, visibility
  RECIPU 128 bytes: perspective reciprocal mantissa, see PERSP in main.asm
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / 'gen'

# Own 5x7 lettering placed in 8x8 character cells (the BBC MOS font is not
# redistributable). Rows 0-6 are the cap/ascender rows, row 7 holds descenders.
_UPPER = {
    'A': [14, 17, 17, 31, 17, 17, 17], 'B': [30, 17, 17, 30, 17, 17, 30],
    'C': [14, 17, 16, 16, 16, 17, 14], 'D': [30, 17, 17, 17, 17, 17, 30],
    'E': [31, 16, 16, 30, 16, 16, 31], 'F': [31, 16, 16, 30, 16, 16, 16],
    'H': [17, 17, 17, 31, 17, 17, 17], 'I': [31, 4, 4, 4, 4, 4, 31],
    'K': [17, 18, 20, 24, 20, 18, 17], 'L': [16, 16, 16, 16, 16, 16, 31],
    'M': [17, 27, 21, 21, 17, 17, 17], 'N': [17, 25, 25, 21, 19, 19, 17],
    'O': [14, 17, 17, 17, 17, 17, 14], 'P': [30, 17, 17, 30, 16, 16, 16],
    'R': [30, 17, 17, 30, 20, 18, 17], 'S': [15, 16, 16, 14, 1, 1, 30],
    'T': [31, 4, 4, 4, 4, 4, 4], 'U': [17, 17, 17, 17, 17, 17, 14],
    'W': [17, 17, 17, 21, 21, 21, 10], 'Y': [17, 17, 10, 4, 4, 4, 4],
}
_ART = {
    'G': ".###./#...#/#..../#.###/#...#/#...#/.####",
    'J': "..###/...#./...#./...#./...#./#..#./.##..",
    'Q': ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",
    'V': "#...#/#...#/#...#/#...#/#...#/.#.#./..#..",
    'X': "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
    'Z': "#####/....#/...#./..#../.#.../#..../#####",
    '0': ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",
    '1': "..#../.##../..#../..#../..#../..#../.###.",
    '2': ".###./#...#/....#/...#./..#../.#.../#####",
    '3': ".###./#...#/....#/..##./....#/#...#/.###.",
    '4': "...#./..##./.#.#./#..#./#####/...#./...#.",
    '5': "#####/#..../####./....#/....#/#...#/.###.",
    '6': ".###./#..../#..../####./#...#/#...#/.###.",
    '7': "#####/....#/...#./..#../.#.../.#.../.#...",
    '8': ".###./#...#/#...#/.###./#...#/#...#/.###.",
    '9': ".###./#...#/#...#/.####/....#/....#/.###.",
    '-': "...../...../...../#####",
    '(': "...#./..#../.#.../.#.../.#.../..#../...#.",
    ')': ".#.../..#../...#./...#./...#./..#../.#...",
    '?': ".###./#...#/....#/...#./..#../...../..#..",
    '/': "....#/...#./...#./..#../.#.../.#.../#....",
    '.': "...../...../...../...../...../...../..#..",
    ',': "...../...../...../...../...../..#../..#../.#...",
    ':': "...../..#../...../...../...../..#..",
    '!': "..#../..#../..#../..#../..#../...../..#..",
    '&': ".##../#..#./#.#../.#.../#.#.#/#..#./.##.#",
    ' ': "",
    "'": "..#../..#../.#...",
    '"': ".#.#./.#.#./.#.#.",
    '+': "...../..#../..#../#####/..#../..#..",
    '=': "...../#####/...../#####",
    ';': "...../..#../...../...../..#../..#../.#...",
    '*': "...../#.#.#/.###./#####/.###./#.#.#",
    '%': "##..#/##..#/...#./..#../.#.../#..##/#..##",
    '#': ".#.#./#####/.#.#./.#.#./#####/.#.#.",
    '<': "...#./..#../.#.../..#../...#.",
    '>': ".#.../..#../...#./..#../.#...",
    'a': "...../...../.###./....#/.####/#...#/.####",
    'b': "#..../#..../####./#...#/#...#/#...#/####.",
    'c': "...../...../.###./#...#/#..../#...#/.###.",
    'd': "....#/....#/.####/#...#/#...#/#...#/.####",
    'e': "...../...../.###./#...#/#####/#..../.###.",
    'f': "..##./.#.../####./.#.../.#.../.#.../.#...",
    'g': "...../...../.####/#...#/#...#/.####/....#/.###.",
    'h': "#..../#..../####./#...#/#...#/#...#/#...#",
    'i': "..#../...../.##../..#../..#../..#../.###.",
    'j': "...#./...../..##./...#./...#./...#./#..#./.##..",
    'k': "#..../#..../#..#./#.#../##.../#.#../#..#.",
    'l': ".##../..#../..#../..#../..#../..#../.###.",
    'm': "...../...../##.#./#.#.#/#.#.#/#.#.#/#.#.#",
    'n': "...../...../####./#...#/#...#/#...#/#...#",
    'o': "...../...../.###./#...#/#...#/#...#/.###.",
    'p': "...../...../####./#...#/#...#/####./#..../#....",
    'q': "...../...../.####/#...#/#...#/.####/....#/....#",
    'r': "...../...../#.##./##..#/#..../#..../#....",
    's': "...../...../.####/#..../.###./....#/####.",
    't': ".#.../.#.../####./.#.../.#.../.#..#/..##.",
    'u': "...../...../#...#/#...#/#...#/#..##/.##.#",
    'v': "...../...../#...#/#...#/#...#/.#.#./..#..",
    'w': "...../...../#...#/#...#/#.#.#/#.#.#/.#.#.",
    'x': "...../...../#...#/.#.#./..#../.#.#./#...#",
    'y': "...../...../#...#/#...#/#...#/.####/....#/.###.",
    'z': "...../...../#####/...#./..#../.#.../#####",
}


def glyph(ch):
    """Return 8 rows of 5-bit values for ch."""
    if ch in _UPPER:
        rows = list(_UPPER[ch])
    elif _ART[ch]:
        rows = [int(r.replace('#', '1').replace('.', '0'), 2) for r in _ART[ch].split('/')]
    else:
        rows = []
    rows += [0] * (8 - len(rows))
    return rows[:8]


def background():
    """The original title screen: border box, heading, prompt and credit line.

    Layout is the original 32x24 character grid of 8x8 cells (TITLE/TT66):
    border = top line + 2-pixel side bars, heading row 1 col 6, prompt row 21
    (CLYNS, then token 6 with its two leading spaces), credit row 23 col 7.
    """
    buf = bytearray(6144)

    def pixel(x, y):
        buf[y * 32 + x // 8] |= 128 >> (x % 8)

    def text(col, row, string):
        for i, c in enumerate(string):
            for r, bits in enumerate(glyph(c)):
                for b in range(5):
                    if bits & (16 >> b):
                        pixel((col + i) * 8 + 1 + b, row * 8 + r)

    for x in range(256):
        pixel(x, 0)
    for y in range(192):
        for x in (0, 1, 254, 255):
            pixel(x, y)
    text(6, 1, '---- E L I T E ----')
    text(1, 21, '  Load New Commander (Y/N)?')
    text(7, 23, '(C) Acornsoft 1984')
    return buf


def fcb(values):
    return '        FCB ' + ','.join(str(v) for v in values)


def emit():
    out = ['; Generated by tools/assets.py: perspective table and the title background.']
    out.append('RECIPU')
    # T = 2^15 / (mantissa + 0.5), mantissa = 128..255; stored as T - 128.
    recip = [round(32768 / (m + 0.5)) - 128 for m in range(128, 256)]
    assert all(0 <= v <= 127 for v in recip)
    for i in range(0, 128, 16):
        out.append(fcb(recip[i:i + 16]))
    out.append('SNE')       # sin(i*pi/32)*256 for i = 0..31, the original's sine table
    sne = [min(255, round(256 * math.sin(i * math.pi / 32))) for i in range(32)]
    for i in range(0, 32, 16):
        out.append(fcb(sne[i:i + 16]))
    # Star speed factor: q = speed * (64/z_hi); R[z] = 64*256/z split into hi/lo byte tables
    rz = [0] * 256
    for z in range(1, 256):
        rz[z] = min(65535, round(64 * 256 / z))
    out.append('STRHI')
    for i in range(0, 256, 16):
        out.append(fcb([v >> 8 for v in rz[i:i + 16]]))
    out.append('STRLO')
    for i in range(0, 256, 16):
        out.append(fcb([v & 255 for v in rz[i:i + 16]]))
    # Perspective multiplier for TRANSFORM: T = 2^15 / (mantissa + 0.5), mantissa 128..255,
    # one byte (255 at most)
    out.append('RT8')
    rt8 = [min(255, round(32768 / (m + 0.5))) for m in range(128, 256)]
    for i in range(0, 128, 16):
        out.append(fcb(rt8[i:i + 16]))
    # side-view dust: dx = 256 * speed / (z_hi / 8) as speed * T / 256 with T = 65536 / A (A = z_hi / 8)
    out.append('DXT')
    for k in range(32):
        out.append('        FDB %d' % min(65535, 65536 // max(k, 1)))
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    out.append('SHPAT')     # the shaded mode: 8 brightness levels x 4 rows, a cell is 2 pixels wide
    for level in range(1, 9):
        rows = []
        for r in range(4):
            v = 0
            for c in range(4):
                if bayer[r][c] < 2 * level:
                    v |= 3 << (6 - 2 * c)
            rows.append(v)
        out.append(fcb(rows))
    out.append('        IFDEF DEBUGFONT')
    out.append('HEXFONT')   # debug: 16 glyphs x 8 rows, 8 pixels wide
    for ch in '0123456789ABCDEF':
        out.append(fcb([r << 2 for r in glyph(ch)]))
    out.append('        ENDC')
    out.append('FONT')      # ASCII 32..126, 8 rows each, glyph in bits 6..2
    for code in range(32, 127):
        ch = chr(code)
        known = ch in _UPPER or ch in _ART
        out.append(fcb([r << 2 for r in glyph(ch)] if known else [0] * 8))
    banner = ['VIEWBANNER']   # "FRONT VIEW" etc. for the top of the space view: 4 x 8 rows x 10 bytes
    for name in ('FRONT VIEW', 'REAR VIEW', 'LEFT VIEW', 'RIGHT VIEW'):
        name = name.ljust(10)
        for row in range(8):
            banner.append(fcb([(glyph(ch)[row] << 2) if (ch in _UPPER or ch in _ART) else 0 for ch in name]))
    (ROOT / 'viewbanner.inc').write_text('\n'.join(banner) + '\n')
    # MKMASK: the vertex-sign x matrix-sign XOR masks used by TRANSFORM.
    # MSKTAB + 32*p + e : p = vertex sign bits (x,y,z negative) as bits 2,1,0,
    # e = k + 3*j (row k of the matrix, vertex axis j): $FF when the term is negative.
    # The table is a page of its own, so the stores go through the direct page: DP
    # is pointed at it for the stores (one cycle each) and the matrix signs are read
    # with extended addressing.
    mk = ['; Generated by tools/assets.py: see MKMASK in engine/ll9.asm', 'MKMASK',
          '        LDA #MSKTAB/256', '        TFR A,DP', '        SETDP MSKTAB/256']
    for e in range(9):
        j = e // 3
        mk.append('        LDB >sgn+%d' % e)
        mk.append('        SEX')
        for want in (0, 1):
            if want:
                mk.append('        COMA')
            for p in range(8):
                if ((p >> (2 - j)) & 1) == want:
                    mk.append('        STA <%d' % (32 * p + e))
    mk += ['        LDA #2', '        TFR A,DP', '        SETDP $02', '        RTS']
    (ROOT / 'mkmask.inc').write_text(chr(10).join(mk) + chr(10))
    (ROOT / 'assets.inc').write_text('\n'.join(out) + '\n')
    bg = ['; Generated by tools/assets.py: the title background, loaded at $0E00 (6144 bytes)',
          'BACKGROUND']
    bitmap = background()
    # RESTORE pulls 6-byte blocks upward (PULU) and pushes them downward
    # (PSHS), so the blocks are stored in reverse order.
    blocks = [bitmap[k:k + 6] for k in range(0, 6144, 6)][::-1]
    rev = b''.join(blocks)
    for k in range(0, len(rev), 16):
        bg.append('        FCB ' + ','.join(f'${v:02X}' for v in rev[k:k + 16]))
    (ROOT / 'background.inc').write_text(chr(10).join(bg) + chr(10))
    

if __name__ == '__main__':
    emit()
