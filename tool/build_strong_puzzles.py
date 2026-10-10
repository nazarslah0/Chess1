#!/usr/bin/env python3
"""يبني assets/puzzles/lichess_puzzles.json من ملف ألغاز التضحية القوية.

الاستخدام:
  python3 tool/build_strong_puzzles.py lichess_100000_strong_sacrifice_puzzles.csv

الاختيار (الأقوى فقط):
  - شعبية >= 90 (أو >= 85 لألغاز الكش مات)، لُعب >= 300 مرة، وانحراف
    التقييم <= 100 (تقييم موثوق).
  - كل الألغاز تحمل ثيم sacrifice => تظهر كلها في صفحة بريلينت.
  - ألغاز الكش مات (ثيم mate) تُصفّى من المتشابه: نمط الكش النهائي
    نفسه (المربعات حول الملك + القطعة + عدد النقلات) لا يتكرر أكثر من مرتين.
  - ترتيب الجودة: الشعبية، عدد مرات اللعب، تنوّع الأفكار (انحراف،
    نقلة هادئة، تحويل، اعتراض...)، وتفضيل الألغاز متعددة النقلات.
"""
import collections, csv, json, math, sys

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else 'assets/puzzles/lichess_puzzles.json'
MAX_NON_MATE = 22000   # سقف ألغاز غير الكش مات (للحفاظ على حجم التطبيق)
MATE_KEEP_PER_PATTERN = 2

IDEAS = {
    'deflection', 'quietMove', 'clearance', 'interference', 'discoveredAttack',
    'intermezzo', 'attraction', 'skewer', 'doubleCheck', 'xRayAttack',
    'trappedPiece', 'zugzwang', 'capturingDefender', 'hangingPiece',
    'smotheredMate', 'backRankMate', 'anastasiaMate', 'arabianMate',
    'bodenMate', 'doubleBishopMate', 'hookMate', 'dovetailMate',
    'underPromotion', 'enPassant', 'castling',
}
DROP_THEMES = {'long', 'veryLong', 'short', 'oneMove'}


def parse(fen):
    b = {}
    for ri, row in enumerate(fen.split()[0].split('/')):
        f = 0
        for ch in row:
            if ch.isdigit():
                f += int(ch)
            else:
                b[(f, 7 - ri)] = ch
                f += 1
    return b


def sq(s):
    return (ord(s[0]) - 97, int(s[1]) - 1)


def apply(b, uci):
    f, t = sq(uci[:2]), sq(uci[2:4])
    pc = b.pop(f)
    if pc.lower() == 'p' and f[0] != t[0] and t not in b:
        b.pop((t[0], f[1]), None)
    if pc.lower() == 'k' and abs(f[0] - t[0]) == 2:
        r = (7 if t[0] > f[0] else 0, f[1])
        b[(5 if t[0] > f[0] else 3, f[1])] = b.pop(r)
    if len(uci) > 4:
        pc = uci[4].upper() if pc.isupper() else uci[4]
    b[t] = pc


def mate_signature(p):
    b = parse(p['fen'])
    for m in p['moves']:
        apply(b, m)
    last = sq(p['moves'][-1][2:4])
    mater = b[last]
    white_mates = mater.isupper()
    king = [s for s, c in b.items() if c == ('k' if white_mates else 'K')][0]
    items = []
    for df in range(-2, 3):
        for dr in range(-2, 3):
            x, y = king[0] + df, king[1] + dr
            dy = -dr if white_mates else dr
            if not (0 <= x < 8 and 0 <= y < 8):
                items.append((df, dy, '#'))
                continue
            c = b.get((x, y))
            if c is None:
                items.append((df, dy, '.'))
            else:
                items.append((df, dy, c.lower() + ('L' if c.isupper() != white_mates else 'W')))
    n = tuple(sorted(items))
    m = tuple(sorted((-a, bb, c) for a, bb, c in items))
    return (min(n, m), mater.lower(), len(p['moves']))


rows = []
with open(src, newline='', encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        pop, plays, rd = int(r['Popularity']), int(r['NbPlays']), int(r['RatingDeviation'])
        themes = r['Themes'].split()
        is_mate = 'mate' in themes
        if rd > 100 or plays < 300 or pop < (85 if is_mate else 90):
            continue
        moves = r['Moves'].split()
        if len(moves) < 4:
            continue
        ideas = len(IDEAS.intersection(themes))
        score = pop + 5 * math.log10(plays) + 2 * min(ideas, 3) + (2 if len(moves) >= 6 else 0)
        rows.append({
            'id': r['PuzzleId'], 'fen': r['FEN'], 'moves': moves,
            'rating': int(r['Rating']),
            'themes': [t for t in themes if t not in DROP_THEMES],
            'br': True, 'mt': is_mate, '_s': score,
        })

mates = [p for p in rows if p['mt']]
others = [p for p in rows if not p['mt']]

groups = collections.defaultdict(list)
for p in mates:
    groups[mate_signature(p)].append(p)
mates_kept = []
for g in groups.values():
    g.sort(key=lambda p: -p['_s'])
    mates_kept += g[:MATE_KEEP_PER_PATTERN]

others.sort(key=lambda p: -p['_s'])
others = others[:MAX_NON_MATE]

final = mates_kept + others
final.sort(key=lambda p: p['rating'])
for p in final:
    del p['_s']

with open(out, 'w', encoding='utf-8') as f:
    json.dump(final, f, ensure_ascii=False, separators=(',', ':'))

r = [p['rating'] for p in final]
print(f'pool={len(rows)} mates_before={len(mates)} mates_kept={len(mates_kept)} '
      f'others={len(others)} total={len(final)} ratings={min(r)}..{max(r)}')
