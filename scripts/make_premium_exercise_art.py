#!/usr/bin/env python3
"""PACE LAB Studio v2 — reproducible premium offline movement assets.

Uses manually defined pose geometry from make_original_exercise_art.py.
Renders 28 anatomically *indicative* 3D-shaded mannequin compositions.
Never substitutes an exercise or equipment it does not describe.
"""
from pathlib import Path
import importlib.util
import subprocess
from html import escape

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("basicposes", HERE/"make_original_exercise_art.py")
basic=importlib.util.module_from_spec(spec)
spec.loader.exec_module(basic)
ROOT=HERE.parents[0]/"ios/PaceLabCompanion/Assets.xcassets"
VECTORS=HERE.parents[0]/"assets/exercise-vectors"
TARGETS={
 "squat":("QUADRICEPS","FESSIERS","STABILITÉ"),
 "chair":("QUADRICEPS","FESSIERS","CONTRÔLE"),
 "row":("GRAND DORSAL","BICEPS","TRONC"),
 "press":("PECTORAUX","TRICEPS","GAINAGE"),
 "bridge":("FESSIERS","ISCHIO-JAMBIERS","GAINAGE"),
 "sideplank":("OBLIQUES","ÉPAULES","TRONC"),
 "plank":("ABDOMINAUX","GAINAGE","FESSIERS"),
 "calf":("MOLLETS","CHEVILLE","ÉQUILIBRE"),
 "split":("QUADRICEPS","FESSIERS","ÉQUILIBRE"),
 "overhead":("DELTOÏDES","TRICEPS","GAINAGE"),
 "hinge":("ISCHIO-JAMBIERS","FESSIERS","DOS"),
 "incline":("PECTORAUX","TRICEPS","GAINAGE"),
 "deadbug":("ABDOMINAUX","COORDINATION","TRONC"),
 "carry":("PRISE","OBLIQUES","POSTURE")
}
MAIN="#59f1b9"

def seg(a,b,width,kind="body"):
    grad={"body":"url(#fabric)","skin":"url(#skin)","rear":"url(#rear)"}[kind]
    path=f"M {a[0]} {a[1]} L {b[0]} {b[1]}"
    # Double edge + core gradient + specular spine (3D tube)
    return (f'<path d="{path}" stroke="#030b15" stroke-width="{width+13}" stroke-linecap="round"/>'
            f'<path d="{path}" stroke="#224459" stroke-width="{width+5}" stroke-linecap="round"/>'
            f'<path d="{path}" stroke="{grad}" stroke-width="{width}" stroke-linecap="round"/>'
            f'<path d="{path}" stroke="#e9fffa" stroke-opacity=".14" stroke-width="{max(3,width/10):.1f}" stroke-linecap="round"/>')

def shoe(x,y):
    return (f'<ellipse cx="{x+15}" cy="{y+1}" rx="29" ry="11" fill="url(#shoe)" '
            'stroke="#859dad" stroke-width="3"/>'
            f'<path d="M{x-3} {y+3} L{x+35} {y+3}" stroke="#8fffd4" stroke-opacity=".65" stroke-width="2"/>')

def equipment(p):
    out=[]
    if p.get("mat"):
        out.append('<rect x="185" y="495" width="600" height="11" rx="5" fill="#365c67"/>')
        out.append('<rect x="185" y="498" width="600" height="2" rx="1" fill="#4ae6b2" opacity=".38"/>')
    if p.get("chair"):
        out.append('<rect x="497" y="392" width="203" height="19" rx="6" fill="url(#metal)" stroke="#93b5b7" stroke-opacity=".4" stroke-width="2"/>')
        out.append('<path d="M678 392 L678 213 M540 409 L530 512 M660 409 L655 512" stroke="#456573" stroke-width="15" stroke-linecap="round"/>')
    if p.get("bench"):
        out.append('<rect x="238" y="379" width="142" height="19" rx="9" fill="url(#metal)"/>')
        out.append('<path d="M250 397 L242 511 M370 397 L378 511" stroke="#567887" stroke-width="13"/>')
    if p.get("support"):
        out.append('<path d="M299 263 L299 513" stroke="#4a6977" stroke-width="15" stroke-linecap="round"/>')
        out.append('<rect x="261" y="251" width="78" height="17" rx="8" fill="url(#metal)"/>')
    return ''.join(out)

def weight(x,y):
    return (f'<g transform="translate({x} {y})">'
            '<rect x="-36" y="-8" width="72" height="16" rx="7" fill="url(#metal)"/>'
            '<rect x="-27" y="-18" width="12" height="36" rx="4" fill="#142734" stroke="#6e929a" stroke-width="2"/>'
            '<rect x="15" y="-18" width="12" height="36" rx="4" fill="#142734" stroke="#6e929a" stroke-width="2"/>'
            '<rect x="-38" y="-15" width="8" height="30" rx="3" fill="#536f80"/>'
            '<rect x="30" y="-15" width="8" height="30" rx="3" fill="#536f80"/>'
            '</g>')

def silhouette(p,exercise):
    head,shoulder,hip=(p[v] for v in ("head","shoulder","hip"))
    le,lw,re,rw=(p[v] for v in ("le","lw","re","rw"))
    lk,la,rk,ra=(p[v] for v in ("lk","la","rk","ra"))
    ls=(shoulder[0]-23,shoulder[1]+12);rs=(shoulder[0]+23,shoulder[1]+12)
    lh=(hip[0]-17,hip[1]);rh=(hip[0]+17,hip[1])
    z=['<g filter="url(#shadow)">',equipment(p)]
    for a,b,w,k in [(rh,rk,33,"rear"),(rk,ra,28,"rear"),
                     (lh,lk,33,"body"),(lk,la,28,"body")]:
        z.append(seg(a,b,w,k))
    for foot in (la,ra):z.append(shoe(*foot))
    z.append(seg(hip,shoulder,69))
    z.append(seg((hip[0],hip[1]-24),(shoulder[0],shoulder[1]+22),42))
    z.append(f'<circle cx="{hip[0]}" cy="{hip[1]}" r="23" fill="url(#fabric)"/>')
    z.append(seg(shoulder,(head[0],head[1]+23),19,"skin"))
    z.append(f'<circle cx="{head[0]}" cy="{head[1]}" r="35" fill="url(#skin)" stroke="#132536" stroke-width="6"/>')
    # No fake portrait; clean neutral 3D mannequin.
    z.append(f'<path d="M{head[0]-15} {head[1]-19} Q {head[0]-5} {head[1]-33} {head[0]+14} {head[1]-18}" stroke="#f5d4af" opacity=".35" fill="none" stroke-width="5"/>')
    for a,b,w in [(rs,re,27),(re,rw,22),(ls,le,27),(le,lw,22)]:
        z.append(seg(a,b,w,"skin"))
    for pt in (lw,rw):
        z.append(f'<circle cx="{pt[0]}" cy="{pt[1]}" r="11" fill="url(#skin)"/>')
    if p.get("dumbbell"):z.append(weight(*p["dumbbell"]))
    z.append('</g>')
    if p.get("arrow"):
        x1,y1,x2,y2=p["arrow"]
        midx=(x1+x2)/2+25
        z.append(f'<path d="M{x1} {y1} Q{midx} {(y1+y2)/2} {x2} {y2}" stroke="#6dfdc6" stroke-width="18" opacity=".10" fill="none"/>')
        z.append(f'<path d="M{x1} {y1} Q{midx} {(y1+y2)/2} {x2} {y2}" stroke="#6dfdc6" stroke-width="6" fill="none" stroke-linecap="round" marker-end="url(#arrow)"/>')
    return ''.join(z)

def svg(name,p,index,exercise):
    phase="POSITION INITIALE" if index==0 else "POSITION FINALE"
    short="DÉPART" if index==0 else "ARRIVÉE"
    a,b,c=TARGETS[exercise]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600" viewBox="0 0 900 600">
    <defs>
      <linearGradient id="bg" x1="0" y1="0" x2=".85" y2="1"><stop stop-color="#0e2632"/><stop offset=".5" stop-color="#08141f"/><stop offset="1" stop-color="#030911"/></linearGradient>
      <radialGradient id="light"><stop stop-color="#3d998b" stop-opacity=".32"/><stop offset=".52" stop-color="#1c4750" stop-opacity=".11"/><stop offset="1" stop-color="#04101b" stop-opacity="0"/></radialGradient>
      <linearGradient id="fabric" x1="0" x2="1" y1="0" y2=".24"><stop stop-color="#799aaa"/><stop offset=".2" stop-color="#426778"/><stop offset=".58" stop-color="#183647"/><stop offset="1" stop-color="#071621"/></linearGradient>
      <linearGradient id="skin" x1="0" x2="1" y1=".15" y2=".9"><stop stop-color="#ffe5bc"/><stop offset=".32" stop-color="#e2a583"/><stop offset=".7" stop-color="#956047"/><stop offset="1" stop-color="#5e3f3b"/></linearGradient>
      <linearGradient id="rear" x1="0" x2="1" y1="0" y2="1"><stop stop-color="#3b6174"/><stop offset=".7" stop-color="#142f40"/><stop offset="1" stop-color="#081624"/></linearGradient>
      <linearGradient id="metal" x1="0" x2="1"><stop stop-color="#213b48"/><stop offset=".46" stop-color="#a7c1c8"/><stop offset=".77" stop-color="#3c5a65"/><stop offset="1" stop-color="#152834"/></linearGradient>
      <linearGradient id="shoe" x1="0" x2="0" y1="0" y2="1"><stop stop-color="#e2f8f5"/><stop offset="1" stop-color="#8faeb7"/></linearGradient>
      <linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#172b36"/><stop offset="1" stop-color="#06101b"/></linearGradient>
      <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feDropShadow dx="4" dy="11" stdDeviation="8" flood-color="#000000" flood-opacity=".55"/></filter>
      <marker id="arrow" markerWidth="7" markerHeight="7" refX="5" refY="3.5" orient="auto"><path d="M0 0 L6 3.5 L0 7" fill="none" stroke="#6dfdc6" stroke-width="1.7"/></marker>
    </defs>
    <rect width="900" height="600" fill="url(#bg)"/>
    <circle cx="455" cy="296" r="375" fill="url(#light)"/>
    <path d="M70 56 L70 510 M810 54 L810 513" stroke="#4c8191" stroke-width="7" opacity=".09"/>
    <path d="M0 520 L900 520 L900 600 L0 600 Z" fill="url(#floor)"/>
    <path d="M0 520 H900" stroke="#9acac5" opacity=".24" stroke-width="2"/>
    <path d="M0 567 L900 567 M0 584 L900 584 M280 520 L210 600 M615 520 L687 600" stroke="#678e9a" opacity=".10"/>
    <ellipse cx="458" cy="517" rx="214" ry="12" fill="#5bf6bd" opacity=".11"/>
    <path d="M25 24 h148 a15 15 0 0 1 15 15 v18 a15 15 0 0 1 -15 15 H25 a15 15 0 0 1 -15 -15 V39 a15 15 0 0 1 15 -15" fill="#112c38" stroke="#3f857f" opacity=".95"/>
    <path d="M28 51 l10 -13 l7 24 l9 -18 l7 7 h17" fill="none" stroke="#56f7b4" stroke-width="3.5" stroke-linejoin="round"/>
    <text x="86" y="53" font-family="Helvetica,Arial" font-size="18" letter-spacing="2" font-weight="bold" fill="#ecfffa">PACE LAB</text>
    <text x="32" y="114" font-family="Helvetica,Arial" font-size="26" font-weight="bold" fill="#f5fffd">{escape(name)}</text>
    <text x="33" y="143" font-family="Helvetica,Arial" font-size="14" letter-spacing="2.5" fill="#8ccdc1">{phase}</text>
    <rect x="747" y="32" width="121" height="39" rx="18" fill="#12382f" stroke="#59f1b9" stroke-opacity=".6"/>
    <text x="807" y="57" text-anchor="middle" font-family="Helvetica,Arial" font-size="14" letter-spacing="1" fill="#77ffc8" font-weight="bold">{short}</text>
    {silhouette(p,exercise)}
    <rect x="21" y="529" width="857" height="58" rx="16" fill="#142531" stroke="#2f4953" stroke-width="1.5"/>
    <text x="43" y="550" font-family="Helvetica,Arial" font-size="11" letter-spacing="2" fill="#6faeaa">MUSCLES &amp; OBJECTIF</text>
    <text x="43" y="570" font-family="Helvetica,Arial" font-size="16" font-weight="bold" fill="#defff2">{a} <tspan fill="#5ff1b7"> • </tspan> {b} <tspan fill="#5ff1b7"> • </tspan> {c}</text>
    <circle cx="842" cy="558" r="20" fill="#5ff1b7"/>
    <text x="842" y="564" text-anchor="middle" font-family="Helvetica,Arial" font-size="17" font-weight="bold" fill="#06171c">{index+1}</text>
    </svg>'''

def main():
    assert set(basic.MOVEMENTS)==set(TARGETS)
    for key,(name,start,end) in basic.MOVEMENTS.items():
        for i,pose in enumerate((start,end)):
            suffix="Start" if i==0 else "End"
            directory=ROOT/f"Movement_{key}_{suffix}.imageset"
            directory.mkdir(parents=True,exist_ok=True)
            src=VECTORS/f"Movement_{key}_{suffix}.svg"
            src.write_text(svg(name,pose,i,key),encoding="utf-8")
            dest=directory/"pose.jpg"
            r=subprocess.run(["sips","-s","format","jpeg","-s","formatOptions","92",str(src),"--out",str(dest)],
                             capture_output=True,text=True)
            if r.returncode: raise RuntimeError(r.stderr)
            print(f"{key}: {suffix}",flush=True)
    print("28 studio demonstration renders updated.",flush=True)

if __name__=="__main__":
    main()
