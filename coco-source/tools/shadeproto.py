"""A desk prototype of the shaded mode: draws a blueprint with filled, lit faces from the loops of
faceloops.py, to see the polygons and the shades before they are written in 6809.

  python shadeproto.py <main-sources dir> <SHIP_NAME> <out.png> [yaw pitch roll degrees]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import faceloops
import ships

LIGHT = (-0.45, 0.55, -0.70)       # towards the light, in view space (z into the screen: -z is towards us)


def rot(yaw, pitch, roll):
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    cr, sr = math.cos(roll), math.sin(roll)
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rp = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    rr = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(ry, mul(rp, rr))


def main(src, name, outp, yaw=30, pitch=20, roll=10):
    srcdir = Path(src)
    bps = {}
    for fn in ships.SRC_ORDER:
        p = srcdir / fn
        if p.exists():
            for k, v in ships.parse_blueprints(p.read_text(encoding='latin-1')).items():
                bps.setdefault(k, v)
    hdr, verts, edges, faces = bps[name]
    loops = faceloops.face_loops(verts, edges, faces)
    m = rot(math.radians(yaw), math.radians(pitch), math.radians(roll))
    size = 400
    img = Image.new('L', (size, size), 0)
    dr = ImageDraw.Draw(img)
    zd = 700.0
    pts = []
    for _, (x, y, z, *_r) in verts:
        v = [sum(m[i][k] * c for k, c in enumerate((x, y, z))) for i in range(3)]
        pts.append((v[0], v[1], v[2] + zd))
    scale = 160
    proj = [(size / 2 + scale * p[0] / p[2] * 3, size / 2 - scale * p[1] / p[2] * 3) for p in pts]
    order = []
    for f, (kind, (nx, ny, nz, vis)) in enumerate(faces):
        n = [sum(m[i][k] * c for k, c in enumerate((nx, ny, nz))) for i in range(3)]
        ln = math.sqrt(sum(c * c for c in n)) or 1
        n = [c / ln for c in n]
        lp = loops[f]
        if not lp:
            continue
        cx = sum(pts[v][0] for v in lp) / len(lp)
        cy = sum(pts[v][1] for v in lp) / len(lp)
        cz = sum(pts[v][2] for v in lp) / len(lp)
        view = (cx, cy, cz)
        if n[0] * view[0] + n[1] * view[1] + n[2] * view[2] >= 0:
            continue                                  # facing away
        shade = max(0.0, sum(n[i] * LIGHT[i] for i in range(3)))
        level = min(8, int(1 + shade * 8))
        order.append((cz, f, level, lp))
    for cz, f, level, lp in sorted(order, reverse=True):
        dr.polygon([proj[v] for v in lp], fill=int(level * 255 / 8))
        dr.line([proj[v] for v in lp] + [proj[lp[0]]], fill=255)
    img.save(outp)
    print(name, 'faces drawn', len(order))


if __name__ == '__main__':
    a = sys.argv
    main(a[1], a[2], a[3], *[float(x) for x in a[4:7]])
