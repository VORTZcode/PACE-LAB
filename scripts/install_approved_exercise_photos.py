#!/usr/bin/env python3
"""Review and install a complete 28-photo human exercise pack.

Never mixes unreviewed / low-resolution images with the production app.
Use --check by default. --install requires exactly 28 approved photographs,
backed-up current assets and an explicit human-review manifest.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / ".generated-exercise-photo-staging"
BACKUP = ROOT / ".generated-exercise-photo-backup"
ASSETS = ROOT / "ios/PaceLabCompanion/Assets.xcassets"

EXERCISES = (
    "squat", "chair", "row", "press", "bridge", "sideplank", "plank",
    "calf", "split", "overhead", "hinge", "incline", "deadbug", "carry"
)
EXPECTED = [f"Movement_{name}_{phase}" for name in EXERCISES for phase in ("Start", "End")]

def dimensions(path: Path) -> tuple[int, int]:
    proc = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
                          capture_output=True, text=True, check=True)
    values = {}
    for line in proc.stdout.splitlines():
        key, _, value = line.partition(":")
        if key.strip() in ("pixelWidth", "pixelHeight"):
            values[key.strip()] = int(value.strip())
    return values["pixelWidth"], values["pixelHeight"]

def inputs() -> tuple[list[tuple[str, Path]], list[str]]:
    found = []
    problems = []
    for name in EXPECTED:
        candidates = [STAGE / f"{name}.{ext}" for ext in ("jpg", "jpeg", "png")]
        valid = [p for p in candidates if p.exists()]
        if len(valid) != 1:
            problems.append(f"{name}: expected one image, found {len(valid)}")
        else:
            found.append((name, valid[0]))
    manifest_path = STAGE / "manifest.json"
    if not manifest_path.exists():
        problems.append("Missing human-review manifest.json")
        records = {}
    else:
        items = json.loads(manifest_path.read_text(encoding="utf-8"))
        records = {f"Movement_{x['name']}_{x['phase']}": x for x in items}
    for name, path in found:
        try:
            w, h = dimensions(path)
        except Exception:
            problems.append(f"{name}: unreadable image")
            continue
        if w < 1024 or h < 768:
            problems.append(f"{name}: only {w}x{h} (minimum 1024x768)")
        record = records.get(name)
        if not record or record.get("approved") is not True:
            problems.append(f"{name}: not reviewed/approved")
        elif record.get("file") != path.name:
            problems.append(f"{name}: manifest does not match file")
        elif record.get("source") != "generated":
            problems.append(f"{name}: source not verified as AI-generated")
    return found, problems

def install(found: list[tuple[str, Path]]) -> None:
    BACKUP.mkdir(parents=True, exist_ok=True)
    converted = []
    for name, photo in found:
        target = ASSETS / f"{name}.imageset" / "pose.jpg"
        if not target.exists():
            raise RuntimeError(f"Missing existing Xcode image set: {name}")
        # Create every conversion before touching production assets.
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
            temp = Path(tmp.name)
        try:
            subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "90",
                            str(photo), "--out", str(temp)],
                           capture_output=True, text=True, check=True)
            converted.append((name, target, temp))
        except Exception:
            temp.unlink(missing_ok=True)
            raise
    try:
        for name, target, temp in converted:
            backup = BACKUP / (name + ".jpg")
            if not backup.exists():
                shutil.copy2(target, backup)
            shutil.copy2(temp, target)
    finally:
        for _, _, temp in converted:
            temp.unlink(missing_ok=True)
    print(f"Installed {len(converted)} approved photos. Previous assets backed up locally.")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true", help="Replace production files after review")
    args = parser.parse_args()
    found, errors = inputs()
    print(f"Photographic candidates present: {len(found)}/{len(EXPECTED)}")
    for problem in errors[:15]: print("CHECK:", problem)
    if len(errors) > 15: print(f"... plus {len(errors)-15} other findings")
    if errors:
        print("BLOCKED: Xcode resources are unchanged.")
        if args.install: raise SystemExit(2)
        return
    print("All 28 photos passed structural checks. Check visual biomechanics manually.")
    if args.install:
        install(found)
    else:
        print("Dry-run: nothing installed.")

if __name__ == "__main__":
    main()
