#!/usr/bin/env python3
"""Integrate only carefully matched photographic PACE LAB movement pairs.

Sources: six original AI diptychs and five freely licensed Everkinetic
demonstrations. Never replace an exercise with the wrong equipment.
The existing vector illustrations remain available for the other three moves.
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageEnhance, ImageOps
import json, shutil

ROOT=Path(__file__).resolve().parents[1]
CATALOG=ROOT/"ios/PaceLabCompanion/Assets.xcassets"
BACKUP=ROOT/".generated-exercise-photo-backup"
AI=Path("/tmp/pace-photoreal-new")
PUBLIC=Path("/tmp/pacelab-photo-options")
AI_EXERCISES=["squat","chair","row","press","bridge","sideplank"]
PUBLIC_EXERCISES={
    "plank":("Plank",(0,1)),
    "split":("Split_Squats",(1,0)),
    "overhead":("Dumbbell_One-Arm_Shoulder_Press",(0,1)),
    "incline":("Incline_Push-Up",(1,0)),
    "deadbug":("Dead_Bug",(0,1)),
}
SKIP={"calf":"No suitable unweighted one-dumbbell photo",
      "hinge":"Photos found show two dumbbells, not one",
      "carry":"Photos found show two hand weights instead of suitcase carry"}
OUT=ROOT/"assets/photo-sources.json"

def paint(frame):
    frame=frame.convert("RGB")
    bg=ImageOps.fit(frame,(900,550),method=Image.Resampling.LANCZOS).filter(ImageFilter.GaussianBlur(34))
    bg=ImageEnhance.Brightness(bg).enhance(.31)
    fg=ImageOps.contain(frame,(888,530),Image.Resampling.LANCZOS)
    bg.paste(fg,((900-fg.width)//2,(550-fg.height)//2))
    return bg

def main():
    images=[]
    meta={}
    for name in AI_EXERCISES:
        src=AI/f"{name}.png"
        if not src.exists():raise RuntimeError("Missing original high-res image: "+str(src))
        diptych=Image.open(src)
        w,h=diptych.size
        for i,phase in enumerate(("Start","End")):
            left=round(w*i/2); right=round(w*(i+1)/2)
            crop=diptych.crop((left+2,0,right-2,h))
            images.append((name,phase,paint(crop)))
        meta[name]={"source":"OpenAI generated fitness photo","license":"Original AI composition",
                    "equipment_verified":True}
    for name,(slug,order) in PUBLIC_EXERCISES.items():
        for phase,index in zip(("Start","End"),order):
            src=PUBLIC/f"{name}_{index}.jpg"
            if not src.exists():raise RuntimeError("Missing original public demo: "+str(src))
            frame=Image.open(src)
            images.append((name,phase,paint(frame)))
        meta[name]={"source":"Everkinetic via yuhonas/free-exercise-db",
                    "license":"CC BY-SA 4.0",
                    "url":"https://github.com/yuhonas/free-exercise-db",
                    "license_url":"https://creativecommons.org/licenses/by-sa/4.0/",
                    "modified":"Resized and placed on a dark, softly blurred background"}
    assert len(images)==22
    BACKUP.mkdir(parents=True,exist_ok=True)
    for name,phase,photo in images:
        path=CATALOG/f"Movement_{name}_{phase}.imageset"/"pose.jpg"
        if not path.exists():raise RuntimeError("Missing asset: "+str(path))
        backup=BACKUP/f"Movement_{name}_{phase}.jpg"
        if not backup.exists():shutil.copy2(path,backup)
        photo.save(path,"JPEG",quality=91,subsampling=0,optimize=True)
        print(name,phase,photo.size,path.stat().st_size,flush=True)
    meta["_pending"]=SKIP
    OUT.write_text(json.dumps(meta,ensure_ascii=False,indent=2)+"\n")
    print("INSTALLED 22 HUMAN PHOTO ASSETS; 6 ORIGINAL VECTOR ASSETS PRESERVED",flush=True)
if __name__=="__main__":main()
