#!/usr/bin/env python3
"""PACE LAB original two-pose training illustrations.

Authored vector art, no third-party photograph or generated impostor:
each exercise has a distinct departure and end position. Creates the
offline JPEGs expected by PaceExerciseVisual and a reviewable SVG source.
"""
from pathlib import Path
from html import escape
import subprocess

ROOT = Path(__file__).resolve().parents[1] / "ios/PaceLabCompanion/Assets.xcassets"
INK = "#20334b"
SUIT = "#284158"
SKIN = "#e2a27b"
ACCENT = "#0fb7a9"
STROKE = "#14283c"
SOFT = "#ecf5f5"

# The figure intentionally uses an anatomical joint chain (head, shoulders, pelvis,
# elbows, hands, knees, feet) rather than a decorative stock photo.
def body(head, shoulder, hip, le, lw, re, rw, lk, la, rk, ra, **kwargs):
    return dict(head=head, shoulder=shoulder, hip=hip, le=le, lw=lw,
                re=re, rw=rw, lk=lk, la=la, rk=rk, ra=ra, **kwargs)

STANDING = body((445,165),(445,238),(445,354),(397,305),(404,355),
                (497,305),(492,355),(407,421),(396,507),(483,421),(495,507))

MOVEMENTS = {
  "squat": ("Squat avec haltère",
    STANDING,
    body((445,244),(445,307),(440,390),(395,325),(420,327),
         (495,325),(464,327),(360,421),(387,507),(526,422),(499,507),
         dumbbell=(441,315), arrow=(592,339,592,433))),
  "chair": ("Squat vers une chaise",
    dict(STANDING, chair=True),
    body((440,221),(440,295),(473,396),(385,309),(406,344),
         (496,319),(485,350),(395,420),(387,505),(555,425),(552,505),
         chair=True, arrow=(328,360,328,436))),
  "row": ("Rowing un bras",
    body((325,217),(390,275),(503,321),(379,352),(346,405),
         (445,305),(456,436),(519,408),(511,505),(611,408),(646,505),
         dumbbell=(456,447), support=True),
    body((325,216),(390,275),(503,321),(379,351),(348,407),
         (463,267),(487,318),(519,407),(511,505),(613,408),(646,505),
         dumbbell=(487,318), support=True, arrow=(550,410,550,328))),
  "press": ("Développé un bras au sol",
    body((248,408),(340,406),(521,419),(372,349),(401,354),
         (352,318),(408,350),(588,338),(635,500),(624,363),(688,501),
         mat=True,dumbbell=(408,346)),
    body((248,408),(340,406),(521,419),(360,343),(360,232),
         (410,390),(445,390),(588,338),(635,500),(624,363),(688,501),
         mat=True,dumbbell=(360,215),arrow=(250,335,250,250))),
  "bridge": ("Pont fessier",
    body((240,411),(336,441),(505,445),(318,468),(272,480),
         (394,477),(425,482),(606,364),(677,505),(635,379),(724,505),mat=True),
    body((240,411),(336,441),(522,326),(318,468),(272,480),
         (393,475),(426,480),(606,364),(677,505),(637,382),(724,505),
         mat=True,arrow=(520,420,520,325))),
  "sideplank": ("Planche latérale",
    body((273,347),(355,381),(525,433),(326,436),(270,449),
         (396,405),(433,415),(635,455),(733,493),(657,467),(749,503),mat=True),
    body((273,325),(355,376),(525,355),(326,435),(269,448),
         (396,296),(412,227),(635,401),(733,493),(657,416),(749,505),
         mat=True,arrow=(525,439,525,346))),
  "plank": ("Planche avant",
    body((255,373),(343,413),(526,452),(305,466),(254,472),
         (367,454),(311,479),(637,466),(731,494),(647,477),(750,500),mat=True),
    body((255,350),(343,392),(526,387),(305,466),(254,473),
         (365,451),(311,477),(637,450),(731,495),(647,452),(750,503),
         mat=True,arrow=(526,468,526,379))),
  "calf": ("Élévations des mollets",
    dict(STANDING,support=True),
    body((445,135),(445,207),(445,325),(397,279),(404,325),
         (497,279),(492,325),(407,391),(409,478),(483,391),(480,479),
         support=True,arrow=(558,455,558,369),tiptoe=True)),
  "split": ("Fente statique",
    body((445,151),(445,226),(445,348),(400,292),(403,349),
         (492,292),(484,350),(374,414),(343,503),(569,407),(650,504),support=True),
    body((445,222),(445,290),(441,398),(394,346),(403,390),
         (493,346),(485,395),(366,422),(343,504),(567,470),(650,504),
         support=True,arrow=(576,316,576,401))),
  "overhead": ("Développé épaules",
    dict(STANDING,dumbbell=(492,288)),
    body((445,165),(445,238),(445,354),(397,305),(404,355),
         (474,169),(484,89),(407,421),(396,507),(483,421),(495,507),
         dumbbell=(484,73),arrow=(585,275,585,136))),
  "hinge": ("Soulevé de terre roumain",
    dict(STANDING,dumbbell=(492,361)),
    body((333,250),(386,287),(498,358),(424,344),(443,431),
         (424,348),(485,429),(487,421),(488,506),(539,421),(549,506),
         dumbbell=(464,438),arrow=(622,273,555,350))),
  "incline": ("Pompes inclinées",
    body((275,263),(362,309),(537,382),(307,339),(275,378),
         (389,336),(342,384),(638,433),(718,508),(658,440),(743,508),
         bench=True),
    body((279,332),(362,390),(537,406),(328,387),(275,379),
         (408,397),(344,384),(638,454),(718,507),(658,460),(743,509),
         bench=True,arrow=(450,315,450,396))),
  "deadbug": ("Dead bug",
    body((237,425),(329,430),(503,432),(337,347),(354,269),
         (398,350),(421,272),(559,316),(625,318),(591,344),(655,342),mat=True),
    body((237,425),(329,430),(503,432),(292,361),(227,266),
         (398,350),(421,273),(565,348),(653,478),(591,344),(651,340),
         mat=True,arrow=(599,280,692,348))),
  "carry": ("Marche du fermier",
    dict(STANDING,dumbbell=(400,358)),
    body((445,165),(445,238),(445,354),(397,305),(400,355),
         (497,306),(492,355),(400,407),(354,510),(500,425),(544,504),
         dumbbell=(400,361),arrow=(584,458,645,458)))
}

def line(a,b,width,outer=STROKE,fill=SUIT):
    return (f'<path d="M {a[0]} {a[1]} L {b[0]} {b[1]}" fill="none" stroke="{outer}"'
            f' stroke-width="{width+6}" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<path d="M {a[0]} {a[1]} L {b[0]} {b[1]}" fill="none" stroke="{fill}"'
            f' stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>')

def circle(pos,r,fill,stroke="none",width=1):
    return f'<circle cx="{pos[0]}" cy="{pos[1]}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"/>'

def accessory(p):
    out = []
    if p.get("mat"):
        out.append('<rect x="185" y="493" width="595" height="11" rx="6" fill="#c9dfdc"/>')
    if p.get("chair"):
        out.extend(['<rect x="502" y="396" width="191" height="16" rx="7" fill="#6f8c98"/>',
                    '<path d="M 675 398 L 675 220" stroke="#5d7c88" stroke-width="16" stroke-linecap="round"/>',
                    '<path d="M 540 412 L 532 503 M 660 412 L 660 503" stroke="#7c9aa4" stroke-width="12"/>'])
    if p.get("bench"):
        out.extend(['<rect x="239" y="379" width="135" height="17" rx="8" fill="#678b98"/>',
                    '<path d="M 252 398 L 245 515 M 370 398 L 377 515" stroke="#597986" stroke-width="13"/>'])
    if p.get("support"):
        out.extend(['<path d="M 301 275 L 301 505" stroke="#a1bdc1" stroke-width="13" stroke-linecap="round"/>',
                    '<rect x="265" y="259" width="74" height="13" rx="6" fill="#7d9fa8"/>'])
    return ''.join(out)

def dumbbell(pos):
    x,y = pos
    return (f'<g transform="translate({x} {y}) rotate(0)">'
            '<path d="M -32 0 H 32" stroke="#8dabb4" stroke-width="12" stroke-linecap="round"/>'
            '<rect x="-30" y="-15" width="13" height="30" rx="4" fill="#2e4c5b"/>'
            '<rect x="17" y="-15" width="13" height="30" rx="4" fill="#2e4c5b"/>'
            '<rect x="-39" y="-12" width="8" height="24" rx="3" fill="#557988"/>'
            '<rect x="31" y="-12" width="8" height="24" rx="3" fill="#557988"/>'
            '</g>')

def person(p):
    h,s,hip=(p[x] for x in ("head","shoulder","hip"))
    le,lw,re,rw=(p[x] for x in ("le","lw","re","rw"))
    lk,la,rk,ra=(p[x] for x in ("lk","la","rk","ra"))
    lshoulder=(s[0]-23,s[1]+12); rshoulder=(s[0]+23,s[1]+12)
    lhip=(hip[0]-17,hip[1]); rhip=(hip[0]+17,hip[1])
    out=[accessory(p)]
    # Rear legs first, then ribcage and arms. Every segment uses round joins.
    for a,b,w,c in [(rhip,rk,30,"#334e60"),(rk,ra,25,"#344e60"),
                     (lhip,lk,30,SUIT),(lk,la,25,SUIT)]:
        out.append(line(a,b,w,fill=c))
    # Shoes and contact surface
    for x,y in (la,ra):
        out.append(f'<ellipse cx="{x+16}" cy="{y+1}" rx="26" ry="10" fill="#f2f8f8" stroke="#8ba7ad" stroke-width="4"/>')
    out.append(line(hip,s,65))
    out.append(line((hip[0],hip[1]-26),(s[0],s[1]+21),37,fill="#31566a"))
    out.append(circle(hip,23,SUIT))
    # Head and neck
    out.append(line(s,(h[0],h[1]+24),20,fill=SKIN))
    out.append(circle(h,35,SKIN,STROKE,6))
    out.append(f'<circle cx="{h[0]+13}" cy="{h[1]-2}" r="3.2" fill="{STROKE}"/>')
    out.append(f'<path d="M {h[0]-16} {h[1]-24} Q {h[0]} {h[1]-42} {h[0]+23} {h[1]-20}" stroke="{STROKE}" stroke-width="15" fill="none" stroke-linecap="round"/>')
    # Active limb positions.
    for a,b,w in [(rshoulder,re,25),(re,rw,21),(lshoulder,le,25),(le,lw,21)]:
        out.append(line(a,b,w,fill=SKIN))
    for w in (lw,rw):
        out.append(circle(w,10,SKIN))
    if p.get("dumbbell"):
        out.append(dumbbell(p["dumbbell"]))
    if p.get("tiptoe"):
        for a in (la,ra):
            out.append(f'<path d="M {a[0]-2} {a[1]+10} l 18 18" stroke="{ACCENT}" stroke-width="5" stroke-linecap="round"/>')
    if p.get("arrow"):
        x1,y1,x2,y2=p["arrow"]
        out.append(f'<path d="M {x1} {y1} Q {(x1+x2)/2+24} {(y1+y2)/2} {x2} {y2}"'
                   f' stroke="{ACCENT}" stroke-width="8" stroke-linecap="round" fill="none"'
                   f' marker-end="url(#arrow)"/>')
    return ''.join(out)

def svg(name,pose,index):
    label="POSITION DE DÉPART" if index==0 else "POSITION FINALE"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600" viewBox="0 0 900 600">
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#f7fbfa"/>
        <stop offset="1" stop-color="#e4f3f2"/></linearGradient>
      <radialGradient id="glow"><stop stop-color="#abede2" stop-opacity=".55"/>
        <stop offset="1" stop-color="#dff6f1" stop-opacity="0"/></radialGradient>
      <marker id="arrow" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto">
        <path d="M0 0 L6 3 L0 6" fill="none" stroke="{ACCENT}" stroke-width="1.5"/>
      </marker>
    </defs>
    <rect width="900" height="600" fill="url(#bg)"/>
    <circle cx="445" cy="300" r="290" fill="url(#glow)"/>
    <path d="M 80 519 H 820" stroke="#c5dcd9" stroke-width="3" stroke-linecap="round"/>
    <ellipse cx="465" cy="522" rx="195" ry="11" fill="#a6c5c5" opacity=".20"/>
    <rect x="31" y="30" width="141" height="41" rx="20" fill="#e2f2ef"/>
    <text x="47" y="57" font-family="Helvetica,Arial" font-size="18" font-weight="bold" fill="#0a968d">PACE / LAB</text>
    <text x="34" y="108" font-family="Helvetica,Arial" font-size="21" font-weight="bold" fill="{INK}">{escape(name)}</text>
    <text x="35" y="139" font-family="Helvetica,Arial" font-size="14" letter-spacing="2" fill="#73918e">{label}</text>
    {person(pose)}
    <text x="35" y="564" font-family="Helvetica,Arial" font-size="13" fill="#527874">ILLUSTRATION ORIGINALE • CONSULTER LES CONSEILS TECHNIQUES</text>
    <circle cx="845" cy="552" r="22" fill="{ACCENT}"/>
    <text x="845" y="559" text-anchor="middle" font-family="Helvetica,Arial" font-size="18" font-weight="bold" fill="#fff">{index+1}</text>
    </svg>'''

def main():
    for key,(title,start,end) in MOVEMENTS.items():
        for index,pose in enumerate((start,end)):
            suffix="Start" if index==0 else "End"
            directory=ROOT/f"Movement_{key}_{suffix}.imageset"
            directory.mkdir(parents=True,exist_ok=True)
            src=Path(__file__).resolve().parents[1]/"assets/exercise-vectors"/f"Movement_{key}_{suffix}.svg"
            src.parent.mkdir(parents=True,exist_ok=True)
            src.write_text(svg(title,pose,index),encoding="utf-8")
            result=subprocess.run(
                ["sips","-s","format","jpeg","-s","formatOptions","91",str(src),
                 "--out",str(directory/"pose.jpg")],
                capture_output=True,text=True)
            if result.returncode:
                raise RuntimeError(result.stderr)
            print(f"CREATED {key}/{suffix}",flush=True)
    print("ALL 28 ORIGINAL VECTOR ILLUSTRATIONS RENDERED")

if __name__=="__main__":
    main()
