"""Run the actual 6809 projection routines in XRoar against pitch/roll cases.

python tests/planet_projection.py --assembler lwasm --xroar xroar --rompath PATH
No BBC source checkout or complete game build is needed.
"""
import argparse
import math
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def section(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]


def fixtures():
    cases = []
    # Both pitch directions, both horizontal directions and combined roll/pitch.
    # The 65-degree, 65536-unit pitch cases used to reappear after leaving view.
    for distance in (32768, 65536, 98304, 393216):
        for axis in ('pitch', 'horizontal', 'diagonal'):
            for sign in (-1, 1):
                for angle in range(0, 90, 5):
                    t = math.radians(angle)
                    lateral = round(distance * math.sin(t)) * sign
                    z = round(distance * math.cos(t))
                    x, y = (0, lateral) if axis == 'pitch' else (lateral, 0)
                    if axis == 'diagonal':
                        x = y = round(lateral / math.sqrt(2))
                    cx, cy = 128 + 256 * x / z, 72 - 192 * y / z
                    radius = min(248, int(0x600000 / z))
                    ry = math.ceil(radius * 3 / 4)
                    margins = (cx + radius, 255 - cx + radius,
                               cy + ry, 143 - cy + ry)
                    # Avoid border-rounding differences of a few pixels.
                    if min(abs(v) for v in margins) < 4:
                        continue
                    cases.append((f'{axis} {sign:+d} {angle}deg d={distance}',
                                  x, y, z, int(all(v >= 0 for v in margins))))
    cases.extend([
        ('centred near plane', 0, 0, 256, 1),
        ('too near', 0, 0, 255, 0),
        ('behind', 0, 0, -65536, 0),
        ('distance limit', 0, 0, 48 * 65536, 0),
        ('extreme right', 0x7fffff, 0, 256, 0),
        ('extreme left', -0x800000, 0, 256, 0),
        ('extreme above', 0, 0x7fffff, 256, 0),
        ('extreme below', 0, -0x800000, 256, 0),
    ])
    return cases


def source(cases):
    planet = (ROOT / 'coco-source/engine/planet.asm').read_text()
    ll9 = (ROOT / 'coco-source/engine/ll9.asm').read_text()
    # Assemble production routines directly; do not model them in Python.
    routines = section(planet, 'ZNORM ', '; draw one segment')
    routines += section(planet, 'CHKON ', '; Draw the circle')
    routines += section(ll9, 'SHS ', '; D (signed)')
    routines += section(ll9, 'PERSP   ', '; ---- edges')
    tables = '\nRECIPU\n        FCB ' + ','.join(
        str(round(32768 / (m + 0.5)) - 128) for m in range(128, 256)) + '\n'
    data = '\nCASES\n'
    for _, x, y, z, expected in cases:
        values = b''.join((v & 0xffffff).to_bytes(3, 'big') for v in (x, y, z))
        data += '        FCB ' + ','.join(str(v) for v in values) + f',{expected}\n'
    data += 'CASES_END EQU *\n'
    return '''        INCLUDE "engine/vars.inc"
        ORG $C000
BOOT    ORCC #$50
        LDS #$0600
        LDA #2
        TFR A,DP
        LDU #CASES
T_NEXT  LDX #inwk
        LDB #9
T_COPY  LDA ,U+
        STA ,X+
        DECB
        BNE T_COPY
        LDA ,U+
        STA $0600
        STU $0601
        JSR PLANPROJ
        BCS T_OFF
        JSR CHKON
        BCS T_OFF
        LDA #1
        BRA T_CHECK
T_OFF   CLRA
T_CHECK CMPA $0600
        BNE TEST_FAIL
TEST_PASS NOP
        BRA T_CONT
TEST_FAIL NOP
T_CONT  LDU $0601
        CMPU #CASES_END
        LBLO T_NEXT
TEST_DONE BRA TEST_DONE
''' + routines + '\n        INCLUDE "engine/math.asm"\n' + tables + data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assembler', default='lwasm')
    parser.add_argument('--xroar', default='xroar')
    parser.add_argument('--rompath')
    parser.add_argument('--timeout', default='15')
    args = parser.parse_args()
    cases = fixtures()
    # Put temporary paths beside the script so Windows/WSL paths stay usable.
    with tempfile.TemporaryDirectory(prefix='planet-', dir=ROOT / 'build') as folder:
        folder = Path(folder)
        asm, rom, symbols = (folder / name for name in ('test.asm', 'test.rom', 'test.map'))
        asm.write_text(source(cases))
        relative = lambda p: str(p.relative_to(ROOT))
        subprocess.run([args.assembler, '-9', '--format=raw', '-Icoco-source',
                        '-o' + relative(rom), '--map=' + relative(symbols),
                        relative(asm)], cwd=ROOT, check=True)
        image = rom.read_bytes()
        rom.write_bytes(image + bytes(16384 - len(image)))
        addresses = {int(v, 16): name for name, v in re.findall(
            r'Symbol: (TEST_\w+) .*? = ([0-9A-Fa-f]+)', symbols.read_text())}
        command = [args.xroar, '-machine', 'coco2bus', '-ram', '64', '-ram-init', 'clear',
                   '-ui', 'null', '-ao', 'null', '-no-ratelimit', '-timeout', args.timeout,
                   '-cart', 'ptest', '-cart-type', 'gmc', '-cart-rom', relative(rom),
                   '-cart-autorun', '-machine-cart', 'ptest', '-trace']
        if args.rompath:
            command += ['-rompath', args.rompath]
        outcomes = []
        completed = False
        with subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE,
                              stderr=subprocess.DEVNULL, text=True) as process:
            for line in process.stdout:
                match = re.match(r'([0-9a-fA-F]{4})\|', line)
                if not match:
                    continue
                label = addresses.get(int(match[1], 16))
                if label in ('TEST_PASS', 'TEST_FAIL'):
                    outcomes.append(label == 'TEST_PASS')
                elif label == 'TEST_DONE':
                    completed = True
                    process.terminate()
                    break
        if not completed or len(outcomes) != len(cases):
            raise SystemExit(f'Incomplete emulator run: {len(outcomes)}/{len(cases)} cases')
        failures = [case[0] for case, ok in zip(cases, outcomes) if not ok]
        if failures:
            raise SystemExit('Projection failures:\n' + '\n'.join(failures))
        print(f'PASS: {len(cases)} projection cases, both pitch directions and clipping limits')


if __name__ == '__main__':
    (ROOT / 'build').mkdir(exist_ok=True)
    main()
