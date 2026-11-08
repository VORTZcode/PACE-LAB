# V13 Flyover visual polish — based on physical iPhone screen capture, 2026-11-08

Observed: satellite overview remained visually flat; the teal route was excessively broad; the lower black controls consumed too much image space; play controls competed with the route.

Implemented:
- thinner, more transparent played/unplayed GPS overlays and smaller position marker
- compact translucent floating control dock with cleaner typographic hierarchy; hideable metrics and reduced dark masks
- closer following camera, 25s route-ahead heading and modest widening around corners
- preserves the V12 aerial intro/outro, camera modes, user control, GPS-on-device approach, and reading location privacy

Verified: Xcode device build; V6.2/V6.4/V12/V13 source tests. Still requires a recorded full-speed video on physical iPhone and measurements of FPS, device battery, terrain coverage. Apple Maps 3D elevation varies by region; no unverified claim that this is objectively superior to Strava.
