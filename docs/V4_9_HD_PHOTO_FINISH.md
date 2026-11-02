# PACE-LAB V4.9 — Three final movements upgraded to HD

## Integrated assets
- Mollets `calf`: support at a fixed wall, feet flat and heels raised, no dumbbell.
- Charnière de hanches `hinge`: one dumbbell held with both hands, hips move backward and the back stays neutral.
- Marche du fermier `carry`: one dumbbell in a single hand, static start then one controlled walking step.
- All six images originate from original 1536 × 1024 px AI diptychs. Each has been individually cropped and presented at 1200 × 800 px with a softly blurred dark background, avoiding the very small cropped collage sources used in V4.8.
- 22 other human photos, already added in V4.7, have not been replaced.

## QA safeguards
- These are photorealistic AI-generated images, not photographs of a real athlete or technique certification.
- The physical form and loading setup are visually plausible and consistent; all exercises still require review by a competent coach before positioning as authoritative technique instruction.
- Image sources, resolution and flags are tracked in `assets/photo-sources.json`.
- Existing V4.8 image assets were saved locally under `.generated-exercise-photo-backup/v48/`.
- The SwiftUI visual viewer now uses an aspect-fit presentation to preserve hands, head, knees and feet on smaller screens; users can still expand the image and switch starting/ending poses.
- The previous low-resolution-specific warnings were removed because the six inputs are new HD images. General AI-generated illustration disclaimers remain.
- Test contract: `tests/photoreal-asset-contract.mjs`.

## Deliberately not promised
- Aesthetic consistency among all 28 images has not been perfected: previous Everkinetic photos and the six HD generated illustrations have different models and scenery.
- A successful Xcode build and device launch do not substitute for human usability testing inside the app or professional biomechanical validation.
