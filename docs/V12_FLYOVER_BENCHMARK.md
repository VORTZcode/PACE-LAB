# PACE-LAB V12 — cinematic Flyover vs Strava (2026-11-08)

## Public Strava feature benchmark
Official Strava Flyover support (Sep 2026) lists: 3D terrain for GPS activities, segments and routes; animated reveal, pause/play, seek, change speed, pinch/swipe camera adjustment, re-center, title/speed/distance/elevation overlay and optional statistics; social sharing and export with map privacy settings. Sources: https://support.strava.com/fr/articles/15401641-flyover and https://press.strava.com/articles/strava-releases-flyover-transforming-how-athletes-look-back-at-adventures

## V12 implemented
- 4.5s eased aerial zoom into the recorded route, camera pitch and heading variation
- Follow / Panorama / Overhead mode, map exploration and one-tap follow reset
- 5s eased outro that reveals entire route and remains on the final wide view
- Hideable statistics; GPS-only derived 45s moving pace and altitude (not estimated physiology)
- Existing 30fps playback, time seek, pause, 0.5/1/2/4x playback, GPS-only on-device MapKit, no coordinate transfer to the Coach
- Performance: route polyline redraw remains bounded and time-based camera smoothing retained; actual FPS on physical device still needs measurement

## Not completed / no superiority claim
- Dynamic camera angle optimization according to terrain occlusion / route geometry
- Actual frame-rate measurement under MapKit satellite tile loading, and handling poor network in a guided performance test
- Social video rendering/export, share sheet, route privacy masking for exported routes
- Seamless navigation across long/multi-day routes and segments
- Realistic 3D terrain/building availability depends on Apple Maps geographic coverage
- Physical iPhone visual QA still required, including battery, background pause, scrubbing and controls.
