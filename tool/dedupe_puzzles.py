#!/usr/bin/env python3
"""يحذف ألغاز الكش مات المتشابهة من assets/puzzles/lichess_puzzles.json.

التشابه: نفس نمط الكش مات النهائي = نفس محتوى المربعات المحيطة بالملك
المهزوم (3×3، مع مراعاة الانعكاس الأفقي واللون)، ونفس القطعة التي
أعطت الكش، ونفس عدد النقلات. من كل مجموعة متشابهة نُبقي لغزين فقط
(الأسهل والأصعب تقييمًا) حتى لا يتكرر النمط في المستوى نفسه.
الألغاز غير المنتهية بكش مات لا تُمس، وكذلك ألغاز التضحية (بريليانت).
"""
import collections, json, sys

KEEP_PER_GROUP = 2
path = sys.argv[1] if len(sys.argv) > 1 else 'assets/puzzles/lichess_puzzles.json'


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
        b.pop((t[0], f[1]), None)  # en passant
    if pc.lower() == 'k' and abs(f[0] - t[0]) == 2:  # castling
        r = (7 if t[0] > f[0] else 0, f[1])
        b[(5 if t[0] > f[0] else 3, f[1])] = b.pop(r)
    if len(uci) > 4:
        pc = uci[4].upper() if pc.isupper() else uci[4]
    b[t] = pc


def signature(p):
    b = parse(p['fen'])
    for m in p['moves']:
        apply(b, m)
    last = sq(p['moves'][-1][2:4])
    mater = b[last]
    white_mates = mater.isupper()
    king = [s for s, c in b.items() if c == ('k' if white_mates else 'K')][0]
    items = []
    for df in (-1, 0, 1):
        for dr in (-1, 0, 1):
            x, y = king[0] + df, king[1] + dr
            dy = -dr if white_mates else dr
            if not (0 <= x < 8 and 0 <= y < 8):
                items.append((df, dy, '#'))
                continue
            c = b.get((x, y))
            if c is None:
                items.append((df, dy, '.'))
            else:
                loser_piece = c.isupper() != white_mates
                items.append((df, dy, c.lower() + ('L' if loser_piece else 'W')))
    n = tuple(sorted(items))
    m = tuple(sorted((-a, bb, c) for a, bb, c in items))
    return (min(n, m), mater.lower(), len(p['moves']))


puzzles = json.load(open(path, encoding='utf-8'))
groups = collections.defaultdict(list)
for p in puzzles:
    if p.get('mt') and not p.get('br'):
        groups[signature(p)].append(p)

drop = set()
for g in groups.values():
    g.sort(key=lambda p: (p['rating'], p['id']))
    keep = g[:1] + (g[-1:] if len(g) > 1 and KEEP_PER_GROUP > 1 else [])
    keep_ids = {p['id'] for p in keep}
    drop.update(p['id'] for p in g if p['id'] not in keep_ids)

out = [p for p in puzzles if p['id'] not in drop]
with open(path, 'w', encoding='utf-8') as f:
    json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
print(f'before={len(puzzles)} dropped={len(drop)} after={len(out)}')
