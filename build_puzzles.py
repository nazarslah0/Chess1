#!/usr/bin/env python3
"""يحوّل lichess_1000_puzzles.csv إلى assets/puzzles/lichess_puzzles.json.

التصنيف:
  mate      = أي لغز يحمل ثيم mate (mateIn1..4 وغيرها) -> صفحة جيك ميت
  brilliant = كل ما عداه (التضحيات أولًا في الترتيب)    -> صفحة بريليانت
Lichess لا يملك ثيم "brilliant"، لذا ما لا يمكن تمييزه يذهب لبريليانت.
"""
import csv, json, sys

src = sys.argv[1] if len(sys.argv) > 1 else 'lichess_1000_puzzles.csv'
out = sys.argv[2] if len(sys.argv) > 2 else 'assets/puzzles/lichess_puzzles.json'

rows = []
with open(src, newline='', encoding='utf-8') as f:
    for r in csv.DictReader(f):
        themes = r['Themes'].split()
        moves = r['Moves'].split()
        cat = 'mate' if 'mate' in themes else 'brilliant'
        rows.append({
            'id': r['PuzzleId'],
            'fen': r['FEN'],
            'moves': moves,
            'rating': int(r['Rating']),
            'themes': themes,
            'cat': cat,
            'sac': 'sacrifice' in themes,
        })

with open(out, 'w', encoding='utf-8') as f:
    json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))

m = sum(1 for r in rows if r['cat'] == 'mate')
print(f'total={len(rows)} mate={m} brilliant={len(rows)-m} '
      f'brilliant_with_sacrifice={sum(1 for r in rows if r["cat"]=="brilliant" and r["sac"])}')
