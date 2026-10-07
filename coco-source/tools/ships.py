"""Extract the original BBC Elite ship blueprints into 6809 include data.

The blueprint *byte layout* is the original's (20-byte header, 6-byte vertices,
4-byte edges, 4-byte faces), so the CoCo renderer reads it with plain indexed
addressing and nothing needs converting at run time. Only the header's edge and
face offsets are recomputed here.

  vertex: |x|, |y|, |z|, signs(7,6,5)|visibility, face1|face2<<4, face3|face4<<4
  edge:   visibility, face1|face2<<4, vertex1*4, vertex2*4
  face:   signs(7,6,5)|visibility, |nx|, |ny|, |nz|

Usage: python ships.py <original main-sources dir> <out.inc>
"""
import re
import sys
from pathlib import Path

SRC_ORDER = ['elite-source-docked.asm', 'elite-source-flight.asm', 'elite-missile.asm'] + \
    ['elite-ships-%s.asm' % c for c in 'abcdefghijklmnop']

HEADER_FIELDS = [  # (name, size)
    ('canisters', 1), ('area', 2), ('edge_lo', 1), ('face_lo', 1), ('heap', 1),
    ('gun', 1), ('explosion', 1), ('verts6', 1), ('edges', 1), ('bounty', 2),
    ('faces4', 1), ('vis', 1), ('energy', 1), ('speed', 1), ('edge_hi', 1),
    ('face_hi', 1), ('scale', 1), ('laser', 1),
]


def strip(line):
    return line.split('\\')[0].strip()


DEFINED = {'_STH_DISC'}   # the Stairway to Hell disc build: the refund-bug-fixed original


def preprocess(text):
    """Resolve the source's IF/ELIF/ELSE/ENDIF build-option blocks."""
    out = []
    stack = []   # (active, taken, parent_active)
    active = True
    for line in text.splitlines():
        t = line.strip()
        m = re.match(r'^(IF|ELIF)\s+(.+)$', t)
        if m:
            expr = re.sub(r'\\.*$', '', m.group(2))
            expr = re.sub(r'[A-Za-z_][A-Za-z_0-9]*',
                          lambda k: {'OR': 'or', 'AND': 'and', 'NOT': 'not'}.get(k.group(0), str(k.group(0) in DEFINED)),
                          expr)
            try:
                val = bool(eval(expr, {}, {}))
            except Exception:
                val = False
            if m.group(1) == 'IF':
                stack.append([active, val, active])
                active = active and val
            else:
                top = stack[-1]
                active = top[2] and (not top[1]) and val
                top[1] = top[1] or val
            continue
        if t == 'ELSE' and stack:
            top = stack[-1]
            active = top[2] and not top[1]
            continue
        if t == 'ENDIF' and stack:
            active = stack.pop()[2]
            continue
        if active:
            out.append(line)
    return '\n'.join(out)


def parse_blueprints(text):
    out = {}
    lines = preprocess(text).splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r'^\.(SHIP_[A-Z0-9_]+)$', lines[i].strip())
        if m and not m.group(1).endswith(('_VERTICES', '_EDGES', '_FACES')):
            name = m.group(1)
            i += 1
            hdr = []
            while not lines[i].startswith('.' + name + '_VERTICES'):
                s = strip(lines[i])
                mm = re.match(r'^EQU([BW])\s+(.*)$', s)
                if mm:
                    hdr.append((mm.group(1), mm.group(2)))
                i += 1
            verts, edges, faces = [], [], []
            i += 1
            section = verts
            while i < len(lines):
                raw = lines[i].strip()
                if raw.startswith('\\ ****') or raw.startswith('.SHIP_') and \
                        not raw.endswith(('_EDGES', '_FACES', '_VERTICES')):
                    break
                if raw == '.' + name + '_EDGES':
                    section = edges
                elif raw == '.' + name + '_FACES':
                    section = faces
                else:
                    mm = re.match(r'^(VERTEX|EDGE|FACE)\s+([^\\]*)', raw)
                    if mm:
                        section.append((mm.group(1), [int(x) for x in mm.group(2).split(',')]))
                i += 1
            if name not in out:
                out[name] = (hdr, verts, edges, faces)
            continue
        i += 1
    return out


def header_expr(expr):
    """Header field -> assembler expression text (symbolic if it names a label)."""
    e = expr.strip()
    if 'SHIP_' not in e:
        e = re.sub(r'%([01]+)', lambda m: '0b' + m.group(1), e)
        e = re.sub(r'&([0-9A-Fa-f]+)', lambda m: '0x' + m.group(1), e)
        return str(eval(e, {}, {}))
    e = e.replace(' ', '')
    e = re.sub(r'LO\(([^()]*)\)', r'(((\1)&$FFFF)&255)', e)
    e = re.sub(r'HI\(([^()]*)\)', r'((((\1)&$FFFF)/256)&255)', e)
    return e


def emit_blueprint(name, bp):
    import faceloops
    hdr, verts, edges, faces = bp
    loops = faceloops.face_loops(verts, edges, faces)
    # the byte before the blueprint: its bounding radius / 2, rounded up (LL9's view test)
    rad = max(((x * x + y * y + z * z) ** 0.5) for _, (x, y, z, *_r) in verts)
    lines = ['        FCB %d' % (int(rad / 2) + 1), name]
    exprs = [header_expr(x[1]) for x in hdr]
    kinds = [x[0] for x in hdr]
    assert len(hdr) == len(HEADER_FIELDS), (name, len(hdr))
    nums = dict(zip([f[0] for f in HEADER_FIELDS], exprs))
    assert nums['verts6'] == str(len(verts) * 6), (name, 'vertices')
    assert nums['faces4'] == str(len(faces) * 4), (name, 'faces')
    if edges:
        assert nums['edges'] == str(len(edges)), (name, 'edges')
    # EQUW fields are big-endian FDB here; everything else is a byte
    for kind, e in zip(kinds, exprs):
        lines.append('        %s %s' % ('FDB' if kind == 'W' else 'FCB', e))
    lines.append(name + '_VERTICES')
    for _, (x, y, z, f1, f2, f3, f4, vis) in verts:
        sg = (0x80 if x < 0 else 0) + (0x40 if y < 0 else 0) + (0x20 if z < 0 else 0) + vis
        lines.append('        FCB %d,%d,%d,%d,%d,%d' % (abs(x), abs(y), abs(z), sg, f1 + (f2 << 4), f3 + (f4 << 4)))
    if edges:
        lines.append(name + '_EDGES')
        for _, (v1, v2, f1, f2, vis) in edges:
            lines.append('        FCB %d,%d,%d,%d' % (vis, f1 + (f2 << 4), v1 << 2, v2 << 2))
    lines.append(name + '_FACES')
    for _, (nx, ny, nz, vis) in faces:
        sg = (0x80 if nx < 0 else 0) + (0x40 if ny < 0 else 0) + (0x20 if nz < 0 else 0) + vis
        lines.append('        FCB %d,%d,%d,%d' % (sg, abs(nx), abs(ny), abs(nz)))
    # the shaded mode's polygons: per face a count (0: none), the normal (signed bytes, length 64)
    # and the vertices of its outline * 4 (tools/faceloops.py)
    lines.append(name + '_LOOPS')
    size = 20 + 6 * len(verts) + 4 * len(edges) + 4 * len(faces)
    for (_, (nx, ny, nz, vis)), lp in zip(faces, loops):
        if not lp:
            lines.append('        FCB 0')
            size += 1
            continue
        ln = (nx * nx + ny * ny + nz * nz) ** 0.5 or 1.0
        n = [max(-127, min(127, int(round(64.0 * c / ln)))) for c in (nx, ny, nz)]
        lines.append('        FCB %d,%d,%d,%d,%s' % (len(lp), n[0] & 255, n[1] & 255, n[2] & 255,
                                                   ','.join(str(v * 4) for v in lp)))
        size += 4 + len(lp)
    return lines, size


def parse_types(text):
    """Ship type numbers from the XX21 table: EQUW SHIP_X  \\ ABC = n = name"""
    types = {}
    for m in re.finditer(r'EQUW (SHIP_[A-Z0-9_]+)[ \t]+\\[ \t]+(?:\w+[ \t]*=[ \t]*)?(\d+)[ \t]*=[ \t]*(.*)', text):
        types[int(m.group(2))] = (m.group(1), m.group(3).strip())
    return types


def parse_newb(text):
    """The default NEWB flags (the E% table): one byte per ship type 1..31."""
    lines = preprocess(text).splitlines()
    for i, l in enumerate(lines):
        if l.strip() == '.E%':
            vals = []
            for k in range(i + 1, len(lines)):
                m = re.match(r'^\s*EQUB\s+([^\\]*)', lines[k])
                if m:
                    e = m.group(1).strip()
                    e = re.sub(r'%([01]+)', lambda q: '0b' + q.group(1), e)
                    vals.append(int(eval(e, {}, {})))
                elif strip(lines[k]) and not lines[k].lstrip().startswith('\\'):
                    break
            return vals
    return []


def main(src_dir, out_path):
    src = Path(src_dir)
    blueprints = {}
    types = {}
    tables = {}   # variant name -> {type: (blueprint, description)}
    newb = {}
    for fn in SRC_ORDER:
        p = src / fn
        if not p.exists():
            continue
        text = p.read_text(encoding='latin-1')
        for k, v in parse_blueprints(text).items():
            blueprints.setdefault(k, v)
        t = parse_types(text)
        nb = parse_newb(text)
        if fn == 'elite-source-docked.asm':
            tables['DOCKED'] = t
            newb['DOCKED'] = nb
        elif fn.startswith('elite-ships-'):
            tables[fn[len('elite-ships-'):-4].upper()] = t
            newb[fn[len('elite-ships-'):-4].upper()] = nb
    out = ['; Generated by tools/ships.py from the original ship blueprints.',
           '; Layout is the original: 20-byte header, 6-byte vertices, 4-byte edges,',
           '; 4-byte faces (16-bit header fields big-endian). SHIPTAB[type-1] -> blueprint.']
    total = 0
    for name, bp in blueprints.items():
        lines, size = emit_blueprint(name, bp)
        total += size
        out += lines
    docked = tables.pop('DOCKED', {})
    for name in tables:                      # the always-resident ships plus the set's own
        merged = dict(docked)
        merged.update(tables[name])
        tables[name] = merged
    top = max(max(t) for t in tables.values() if t)
    out.append('; Per-set type tables: the original loads one of 16 ship files (A-P) per')
    out.append('; system, so only some ship types exist at a time. DOCKED is the station set.')
    for name in sorted(tables):
        out.append('SHIPTAB_' + name)
        for typ in range(1, top + 1):
            ent = tables[name].get(typ)
            if ent and ent[0] in blueprints:
                out.append('        FDB %s            ; %d %s' % (ent[0], typ, ent[1]))
            else:
                out.append('        FDB 0')
    out.append('; the default NEWB flags (the original E%%) per set: one byte per type 1..%d' % top)
    dn = newb.get('DOCKED', [])
    for name in sorted(tables):
        sn = newb.get(name, [])
        out.append('NEWBTAB_' + name)
        vals = []
        for i in range(top):
            v = sn[i] if i < len(sn) and sn[i] else (dn[i] if i < len(dn) else 0)
            vals.append(v)
        for i in range(0, top, 16):
            out.append('        FCB ' + ','.join(str(v) for v in vals[i:i + 16]))
    out.append('SHIPSETS EQU %d' % len(tables))
    out.append('SHIPSETTAB')
    for name in sorted(tables):
        out.append('        FDB SHIPTAB_%s,NEWBTAB_%s' % (name, name))
    # Every blueprint once, in ship type order (title screen browsing, tests).
    order = []
    for typ in range(1, top + 1):
        for name in sorted(tables):
            ent = tables[name].get(typ)
            if ent and ent[0] in blueprints and ent[0] not in order:
                order.append(ent[0])
    order += [n for n in blueprints if n not in order]
    out.append('SHIPCOUNT EQU %d' % len(order))
    out.append('COBRAIDX  EQU %d' % order.index('SHIP_COBRA_MK_3'))
    for i, n in enumerate(order):
        out.append('IDX_%s EQU %d' % (n, i))
    out.append('SHIPLIST')
    for n in order:
        out.append('        FDB %s' % n)
    # Ship names (the original's descriptions), NUL terminated, same order.
    desc = {}
    for t in tables.values():
        for bp_name, text in t.values():
            desc.setdefault(bp_name, text)
    # Bounding radius per blueprint (same order): LL9 uses perspective from the ship's
    # centre for every vertex when the ship is far enough away for that to be within
    # a pixel (distance >= 16 radii).
    out.append('SHIPSIZE')
    for n in order:
        verts = blueprints[n][1]
        r = max(((x * x + y * y + z * z) ** 0.5) for _, (x, y, z, *_r) in verts)
        out.append('        FCB %d' % min(255, int(r) + 1))
    out.append('SHIPNAMES')
    for n in order:
        out.append('        FDB NAME_%s' % n)
    for n in order:
        text = desc.get(n, n[5:].replace('_', ' ').capitalize())
        out.append('NAME_%s' % n)
        out.append('        FCB %s,0' % ','.join(str(ord(c)) for c in text))
    Path(out_path).write_text('\n'.join(out) + '\n')
    if len(sys.argv) > 3:                      # the Constrictor again for the docked overlay:
        lines, _ = emit_blueprint('DKCON', blueprints['SHIP_CONSTRICTOR'])   # the mission 1 briefing shows it
        Path(sys.argv[3]).write_text('; the Constrictor for the briefing (tools/ships.py)\n' +
                                     '\n'.join(lines).replace('SHIP_CONSTRICTOR', 'DKCON') + '\n')
    print('%d blueprints, ~%d bytes, %d ship types' % (len(blueprints), total, len(types)))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
