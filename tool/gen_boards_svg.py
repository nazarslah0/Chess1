#!/usr/bin/env python3
"""يولّد رقع SVG متعددة الألوان في assets/boards_svg/ (بدون صور)."""
import os, random
OUT = 'assets/boards_svg'
os.makedirs(OUT, exist_ok=True)

def tw(c, k):
    c = c.lstrip('#'); x = [int(c[i:i+2], 16) for i in (0, 2, 4)]
    return '#%02X%02X%02X' % tuple(max(0, min(255, int(t * (1 + k)))) for t in x)

def board(name, light, dark, grain_l, grain_d, seed, grain=3, sheen=.10, vary=.04):
    r = random.Random(seed)
    defs = ''; body = ''
    for kind, (a, b) in (('l', light), ('d', dark)):
        for v in range(4):
            sh = r.uniform(-vary, vary)
            ang = r.choice([0, 0, 10, -10])
            defs += (f'<linearGradient id="{kind}{v}" x1="0" y1="0" x2="1" y2="{0.25+ang/100:.2f}">'
                     f'<stop offset="0" stop-color="{tw(a, sh)}"/><stop offset="1" stop-color="{tw(b, sh)}"/></linearGradient>')
    for row in range(8):
        for col in range(8):
            dk = (row + col) % 2 == 1
            x, y = col * 100, row * 100
            body += f'<rect x="{x}" y="{y}" width="100" height="100" fill="url(#{"d" if dk else "l"}{r.randrange(4)})"/>'
            gc = grain_d if dk else grain_l
            for _ in range(grain):
                gy = y + r.uniform(12, 88); amp = r.uniform(2, 6); w = r.uniform(.8, 1.8)
                body += (f'<path d="M{x} {gy:.0f}Q{x+50} {gy+amp*r.choice([-1,1]):.0f} {x+100} {gy+r.uniform(-4,4):.0f}" '
                         f'stroke="{gc}" stroke-width="{w:.1f}" stroke-opacity="{r.uniform(.12,.28):.2f}" fill="none"/>')
    defs += (f'<linearGradient id="sheen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="{sheen}"/>'
             f'<stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="{sheen}"/></linearGradient>')
    body += '<rect width="800" height="800" fill="url(#sheen)"/>'
    open(f'{OUT}/{name}.svg', 'w').write(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" preserveAspectRatio="none"><defs>{defs}</defs>{body}</svg>')

board('classic_wood',  ('#F3DDB8', '#E6C896'), ('#BC8C62', '#A27248'), '#8B5E34', '#4A2C12', 7)
board('classic_green', ('#F2F2D8', '#E3E4C0'), ('#7DA05C', '#688C48'), '#9DB87F', '#3E5A2A', 11)
board('dark_wood',     ('#D9B48A', '#C79D70'), ('#7A4B2A', '#5E3719'), '#6B4020', '#2C160A', 23, grain=4, sheen=.12)
board('classic_blue',  ('#E6EEF6', '#D3DFEC'), ('#6F8FB0', '#5B7C9E'), '#9FB5CC', '#35506E', 31, grain=2, sheen=.14, vary=.03)
