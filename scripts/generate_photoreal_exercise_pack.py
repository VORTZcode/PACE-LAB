#!/usr/bin/env python3
"""Build a *staged* 28-image photorealistic exercise pack for PACE LAB.

Dry-run by default. Explicit --generate requires an API key and uses billed
OpenAI Images API calls. Generated files stay outside Assets.xcassets until
they pass technical and visual review. No silent automatic deployment.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path
import ssl
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "ios/PaceLabCompanion/Assets.xcassets"
STAGE = ROOT / ".generated-exercise-photo-staging"
API = "https://api.openai.com/v1"
MODEL = "gpt-image-2.5-sunburst"

# Actual PACE LAB exercises, NOT stock gym exercises and NOT a full-body programme.
MOVEMENTS = {
    "squat": ("Goblet squat: one dumbbell held vertically at chest",
              "Standing upright, heels grounded, dumbbell held with both palms at sternum",
              "Deep comfortable squat with hips low, chest tall, elbows in front, heels flat"),
    "chair": ("Controlled squat to stable chair, no dumbbell",
              "Standing just ahead of a stable chair, hips over feet",
              "Hips travel back toward seat, knees track feet, seat almost touches chair"),
    "row": ("One-arm dumbbell row with stable support",
            "Left palm on sturdy table, back neutral, one dumbbell hanging in right hand",
            "Same trunk and support, right elbow drawn toward hip with single dumbbell"),
    "press": ("Single-arm dumbbell floor press, supine",
              "Lying on back on mat, knees bent and feet grounded, one dumbbell by right chest",
              "Same supine torso and feet, right arm vertical over shoulder with dumbbell"),
    "bridge": ("Glute bridge on mat",
               "Lying on back, both knees bent, heels grounded, hips resting on mat",
               "Hips raised to straight shoulder-hip-knee line, same foot placement"),
    "sideplank": ("Side plank, forearm support",
                  "Lying sideways, elbow below shoulder, hips just above mat",
                  "Side plank with hips lifted into straight head-to-ankle line"),
    "plank": ("Front forearm plank",
               "Forearms and toes on mat, body aligned, abdominals braced",
               "Same sustained forearm plank with neutral spine and level hips; no false dynamic phase"),
    "calf": ("Standing calf raise with optional fingertip support",
              "Both feet flat, knees softly extended, fingertips touch stable wall",
              "Both heels lifted, balance stable, fingertips still supported"),
    "split": ("Assisted stationary split squat",
               "Staggered stance, one hand on stable chair back, front heel flat",
               "Lower rear knee toward floor, same feet positions, torso upright"),
    "overhead": ("Single-arm dumbbell overhead shoulder press",
                 "Standing, one dumbbell by right shoulder, no second dumbbell",
                 "Same standing pose, right arm overhead with only one dumbbell"),
    "hinge": ("One-dumbbell hip hinge / Romanian deadlift",
              "Standing tall, one dumbbell in both hands or one hand in front of thighs",
              "Hips shifted back, knees softly bent, back neutral, dumbbell close to thighs"),
    "incline": ("Incline push-up against stable sturdy table",
                "Hands shoulder-width on immovable stable raised bench, arms straight, feet behind",
                "Same hand/foot support, elbows bent, chest lowered toward bench edge"),
    "deadbug": ("Opposite-arm-and-leg dead bug",
                "Supine on mat, arms vertical, hips and knees at 90 degrees",
                "Lower opposite right arm and left leg near floor without arching lower back"),
    "carry": ("Single-dumbbell suitcase carry",
              "Standing upright holding exactly one dumbbell in right hand, arm by side",
              "Mid-step forward holding same single dumbbell by right thigh, torso not leaning"),
}

ATHLETE = (
    "Photorealistic editorial fitness photograph of one fictional adult male athlete, "
    "approximately 30 years old, athletic but natural build, short dark brown hair, "
    "light olive skin, clean shaven, black plain fitted training shirt, charcoal shorts, "
    "white training shoes; full body visible head to toe. Photographic skin pores, natural "
    "fabric folds, authentic lighting and realistic geometry. Dark minimal home-training "
    "studio with graphite walls and a matte floor, subtle soft key light and green rim light. "
    "No logos, no text, no collage, no UI, no cards, no overlay, no visual diagrams."
)

def data_url(path: Path) -> str:
    suffix = path.suffix.lower()
    mime = {"png": "image/png", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}.get(suffix, "image/jpeg")
    return "data:" + mime + ";base64," + base64.b64encode(path.read_bytes()).decode("ascii")

def request_image(endpoint: str, body: dict, key: str) -> bytes:
    req = urllib.request.Request(
        API + endpoint,
        json.dumps(body).encode("utf-8"),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"},
        method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=180, context=ssl.create_default_context()) as reply:
            result = json.load(reply)
    except urllib.error.HTTPError as error:
        snippet = error.read(1000).decode("utf-8", "replace")
        raise RuntimeError(f"Images endpoint {error.code}: {snippet}") from error
    outputs = result.get("data") or []
    if not outputs or not outputs[0].get("b64_json"):
        raise RuntimeError("No image bytes returned; never save an empty placeholder.")
    return base64.b64decode(outputs[0]["b64_json"], validate=True)

def prompt_for(name: str, phase: str) -> str:
    title, start, end = MOVEMENTS[name]
    position = start if phase == "Start" else end
    return (
        ATHLETE +
        "\nTASK: Single full-frame photographic portrait in landscape 1536x1024. "
        "Match the SAME person's face, physique, shirt, shorts, sneakers, camera angle, "
        "camera position, room, and direction of light shown in the reference portrait. "
        "Use the SECOND reference solely as a schematic of approximate body pose, not as visual style. "
        f"Exercise: {title}. Exact phase: {phase}. Precise joint and equipment details: {position}. "
        "Keep the entire athlete and supporting equipment in frame. "
        "Equipment limited to ONE adjustable dumbbell and a mat, chair, table or wall only when "
        "specified by the exercise. No barbell, no bench press, no pull-up bar, no second dumbbell. "
        "Natural hands, five realistic fingers, realistic knees, elbows, neck, spine, feet, and "
        "correct floor/support contact. Absolutely no text, panel, multiple views or drawn arrows."
    )

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate", action="store_true", help="Uses billable Images API calls")
    parser.add_argument("--only", choices=sorted(MOVEMENTS), help="Stage just one exercise pair")
    args = parser.parse_args()
    names = [args.only] if args.only else list(MOVEMENTS)
    print(f"Exercise pairs: {len(names)}. Proposed images: {len(names)*2}. API model: {MODEL}")
    if not args.generate:
        for name in names:
            print(name, "=>", MOVEMENTS[name][0])
        print("Dry-run only: NOTHING generated or installed, NO billable API calls.")
        return

    key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not key:
        raise SystemExit("OPENAI_API_KEY not found. No API calls made.")
    STAGE.mkdir(parents=True, exist_ok=True)
    ref = STAGE / "athlete-reference.png"
    if not ref.exists():
        print("Creating consistent fictional athlete reference.", flush=True)
        image = request_image("/images/generations", {
            "model": MODEL, "prompt": ATHLETE + " Standing neutral, full body, studio reference photograph.",
            "size": "1024x1536", "quality": "high", "output_format": "png"
        }, key)
        ref.write_bytes(image)
    manifest = []
    for name in names:
        for phase in ("Start", "End"):
            pose = ASSETS / f"Movement_{name}_{phase}.imageset/pose.jpg"
            if not pose.exists(): raise RuntimeError(f"Reference pose missing: {pose}")
            dest = STAGE / f"Movement_{name}_{phase}.png"
            if dest.exists():
                print("Already staged:", dest.name, flush=True)
            else:
                print("Rendering:", name, phase, flush=True)
                image = request_image("/images/edits", {
                    "model": MODEL, "size": "1536x1024", "quality": "high",
                    "output_format": "png",
                    "images": [{"image_url": data_url(ref)}, {"image_url": data_url(pose)}],
                    "prompt": prompt_for(name, phase)
                }, key)
                dest.write_bytes(image)
                time.sleep(0.25)
            manifest.append({"name": name, "phase": phase, "file": dest.name,
                             "source": "generated", "approved": False})
    (STAGE / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(f"Staged {len(manifest)} images. NOT installed: biomechanical and visual review required.")

if __name__ == "__main__":
    main()
