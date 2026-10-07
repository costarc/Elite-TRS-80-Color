"""Print the original's text tokens as text (for porting): python tokdump.py q|e|r [n ...]"""
import re
import sys
from pathlib import Path
g = Path(__file__).resolve().parents[1] / 'gen'
TWO = ['AL','LE','XE','GE','ZA','CE','BI','SO','US','ES','AR','MA','IN','DI','RE','A?','ER','AT','EN','BE','RA','LA','VE','TI','ED','OR','QU','AN','TE','IS','RI','ON']
TWOX = ['--','AB','OU','SE','IT','IL','ET','ST','ON','LO','NU','TH','NO'] + TWO + ['QU','AN'][0:0]
TWOX = ['--','AB','OU','SE','IT','IL','ET','ST','ON','LO','NU','TH','NO','AL','LE','XE','GE','ZA','CE','BI','SO','US','ES','AR','MA','IN','DI','RE','A?','ER','AT','EN','BE','RA','LA','VE','TI','ED','OR','QU','AN']


def table(name, text, xor=0):
    m = re.search(name + r'\n((?:\s+FCB [\d,]+\n)+)', text)
    data = [int(x) for x in re.findall(r'\d+', m.group(1).replace('FCB', ''))]
    toks, cur = [], []
    for b in data:
        if b == 0:
            toks.append(cur); cur = []
        else:
            cur.append(b ^ xor)
    return toks


q = table('QQ18', (g / 'tokens.inc').read_text(), 0x23)
d = (g / 'tokens_dock.inc').read_text()
e = table('TKN1', d)
r = table('RUTOK', d)


def qdec(i):
    out = ''
    for b in q[i]:
        out += '{%d}' % b if b < 32 else ('[' + qdec(b - 160) + ']' if b >= 160 else TWO[b - 128] if b >= 128 else '[' + qdec(b) + ']' if b >= 96 else chr(b))
    return out


def edec(tab, i):
    out = ''
    for b in tab[i]:
        if b < 32: out += '{J%d}' % b
        elif b < 91: out += chr(b)
        elif b < 129: out += '{R%d}' % (b - 91)
        elif b < 215: out += '<' + edec(e, b) + '>'
        else: out += TWOX[b - 215]
    return out


kind = sys.argv[1]
for a in sys.argv[2:]:
    n = int(a)
    print(n, qdec(n) if kind == 'q' else edec(e if kind == 'e' else r, n))
