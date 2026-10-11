import os,sys
OUT=sys.argv[1] if len(sys.argv)>1 else 'mine'
os.makedirs(OUT,exist_ok=True)
SW=2.3
def base():
    return ('<rect x="19" y="85" width="62" height="9" rx="3.5"/>'
            '<rect x="25" y="78" width="50" height="8" rx="3"/>')
body_pawn='<path d="M41 47C41 60 35 69 32 79H68C65 69 59 60 59 47Z"/>'
body_big='<path d="M37 47C37 60 33 70 29 79H71C67 70 63 60 63 47Z"/>'
def pawn():
    return (body_pawn+'<rect x="35" y="40" width="30" height="8" rx="4"/><circle cx="50" cy="29" r="11.5"/>'+base())
def rook():
    return ('<path d="M31 16H40V23H45V16H55V23H60V16H69V35H31Z"/>'
            '<rect x="33" y="34" width="34" height="7" rx="2"/>'
            '<path d="M37 41H63L67 79H33Z"/>'+base())
def bishop():
    return ('<path d="M50 19C63 26 68 38 61 48H39C32 38 37 26 50 19Z"/>'
            '<circle cx="50" cy="14" r="5"/>'
            '<rect x="33" y="47" width="34" height="8" rx="4"/>'
            '<path d="M40 55C40 65 35 72 32 79H68C65 72 60 65 60 55Z"/>'+base())
def queen():
    return ('<path d="M30 41L23 21L32 32L37 14L43 30L50 11L57 30L63 14L68 32L77 21L70 41Z"/>'
            '<circle cx="23" cy="19" r="3.4"/><circle cx="37" cy="12" r="3.4"/><circle cx="50" cy="9" r="3.4"/><circle cx="63" cy="12" r="3.4"/><circle cx="77" cy="19" r="3.4"/>'
            '<rect x="28" y="40" width="44" height="8" rx="4"/>'+body_big+base())
def king():
    return ('<path d="M45.5 5H54.5V10H59.5V18H54.5V25H45.5V18H40.5V10H45.5Z"/>'
            '<path d="M31 43C28 32 37 24 50 24C63 24 72 32 69 43Z"/>'
            '<rect x="28" y="42" width="44" height="8" rx="4"/>'+body_big+base())
def knight():
    return ('<path d="M31 79C31 68 31 60 37 55L27 57C21 58 18 53 20 48C22 42 30 34 36 26L37 13L46 21C60 23 73 37 73 57C73 66 71 73 70 79Z"/>'
            +base())
def detail(kind,col,w=SW):
    s=''
    if kind=='n':
        s+=f'<circle cx="41" cy="35" r="2.3" fill="{col}" stroke="none"/><path d="M23 50L26 52" stroke="{col}" stroke-width="{w}" stroke-linecap="round" fill="none"/><path d="M52 27C63 33 67 45 65 62" stroke="{col}" stroke-width="{w*.8}" stroke-linecap="round" fill="none"/>'
    if kind=='b':
        s+=f'<path d="M45 31L55 40" stroke="{col}" stroke-width="{w*1.2}" stroke-linecap="round" fill="none"/>'
    if kind=='r':
        s+=f'<path d="M31 35H69" stroke="{col}" stroke-width="{w*.7}" fill="none"/>'
    if kind=='k':
        s+=f'<path d="M30 43H70" stroke="{col}" stroke-width="{w*.6}" fill="none"/>'
    return s
PIECES={'p':pawn,'r':rook,'n':knight,'b':bishop,'q':queen,'k':king}
def svg(t,c):
    if c=='w': g1,g2,st,dt='#FFFFFF','#DCD2BA','#262626','#262626'
    else: g1,g2,st,dt='#5A5A5A','#1C1C1C','#0B0B0B','#E8E8E8'
    gid=f'g{t}{c}'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs>'
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{g1}"/><stop offset="1" stop-color="{g2}"/></linearGradient></defs>'
            f'<g fill="url(#{gid})" stroke="{st}" stroke-width="{SW}" stroke-linejoin="round" stroke-linecap="round">'
            +PIECES[t]()+'</g>'
            f'<g>{detail(t,dt)}</g></svg>')
for t in 'pnbrqk':
    for c in 'wb':
        open(f'{OUT}/{c}{t.upper()}.svg','w').write(svg(t,c))

# ================================================================
# مجموعة "عصري": أشكال أعرض، تظليل مسطح بلونين، وحدود أسمك.
# الاستخدام: python3 tool/gen_classic_svg_pieces.py <مجلد الإخراج> modern
# ================================================================
def _modern_base():
    return ('<rect x="18" y="85" width="64" height="9" rx="4"/>'
            '<rect x="24" y="78" width="52" height="8" rx="3.5"/>')
_big = '<path d="M36 47C36 60 31 70 27 79H73C69 70 64 60 64 47Z"/>'
MODERN = {
 'p': lambda: ('<path d="M38 47C38 60 31 70 28 79H72C69 70 62 60 62 47Z"/><rect x="33" y="39" width="34" height="9" rx="4.5"/><circle cx="50" cy="27" r="13"/>'+_modern_base()),
 'r': lambda: ('<path d="M28 15H38V22H44V15H56V22H62V15H72V34H28Z"/><rect x="31" y="33" width="38" height="8" rx="2.5"/><path d="M35 41H65L69 79H31Z"/>'+_modern_base()),
 'b': lambda: ('<path d="M50 15C66 23 70 38 62 49H38C30 38 34 23 50 15Z"/><circle cx="50" cy="11" r="5.5"/><rect x="31" y="48" width="38" height="9" rx="4.5"/><path d="M39 57C39 66 33 72 30 79H70C67 72 61 66 61 57Z"/>'+_modern_base()),
 'q': lambda: ('<path d="M28 42L21 22L33 33L39 15L45 31L50 12L55 31L61 15L67 33L79 22L72 42Z"/>'
               '<circle cx="21" cy="20" r="4"/><circle cx="39" cy="13" r="4"/><circle cx="50" cy="10" r="4"/><circle cx="61" cy="13" r="4"/><circle cx="79" cy="20" r="4"/>'
               '<rect x="26" y="41" width="48" height="9" rx="4.5"/>'+_big+_modern_base()),
 'k': lambda: ('<path d="M44 3H56V9H62V19H56V25H44V19H38V9H44Z"/><path d="M30 44C26 32 36 24 50 24C64 24 74 32 70 44Z"/><rect x="26" y="43" width="48" height="9" rx="4.5"/>'+_big+_modern_base()),
 'n': lambda: ('<path d="M30 79C30 66 31 58 38 53L29 55C22 56 19 50 21 45C24 38 31 32 35 24L35 11L45 19C61 21 74 36 74 56C74 66 72 73 71 79Z"/>'+_modern_base()),
}
def modern_svg(t, c):
    if c == 'w': g1, g2, st, dt = '#FFFFFF', '#D4D4D4', '#2A2A2A', '#2A2A2A'
    else: g1, g2, st, dt = '#4E4E4E', '#262626', '#0B0B0B', '#EDEDED'
    gid = f'm{t}{c}'; sw = 2.8
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs>'
            f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="{g1}"/><stop offset=".58" stop-color="{g1}"/>'
            f'<stop offset=".58" stop-color="{g2}"/><stop offset="1" stop-color="{g2}"/></linearGradient></defs>'
            f'<g fill="url(#{gid})" stroke="{st}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round">{MODERN[t]()}</g>'
            f'<g>{detail(t, dt, sw)}</g></svg>')
if len(sys.argv) > 2 and sys.argv[2] == 'modern':
    for t in 'pnbrqk':
        for c in 'wb':
            open(f'{OUT}/{c}{t.upper()}.svg', 'w').write(modern_svg(t, c))
