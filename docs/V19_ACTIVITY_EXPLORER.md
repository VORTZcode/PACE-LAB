# V19 — GPS/effort activity explorer (first milestone)

This release is the first practical step from colored metric cards to an immersive, real-data activity experience. The user expressly requested application updates following the Strava product audit.

## Delivered

- Activity detail top redesigned with prominent recorded distance, pace, duration and HR alongside the workout date, with the actual HealthKit GPS route displayed before Coach and analytics details.
- In-page direct navigation to Route, Analyses, Intervals and athlete journal.
- A new `PaceRouteInspectionTimeline` directly below the live satellite route map. It shows timestamp-aligned real HR samples with explicit segment boundaries when sensor gaps exceed two minutes.
- `chartXSelection` selects a time in the session and moves an **inspection-only** GPS marker to the matching recorded location. No permanent workout mutations, GPS uploads, invented heart readings, virtual workouts or social sharing.
- When HR samples aren't present, a manual time slider still lets the athlete explore the GPS timeline. If the cursor falls more than 0.9 minutes away from any actual HR sample, the label states no measurement at that moment.
- Reuse the existing full-screen GPS map and 3D Flyover; avoid repeated per-row map rendering.

## QA

- Signed physical-device Xcode build succeeds and V19 and previously introduced source-contract suites pass.
- Real tap/scrub interaction on iPhone, GPS/HR alignment quality, accessibility labels and large-text layouts still need a manual functional check after installation.
- The project is still short of Strava ecosystem parity: routes/segments/records, feed map thumbnails, social/privacy-safe sharing, route discovery and multiple-period comparative analytics remain future work.
- Install the application over the existing bundle and do not uninstall, clear container preferences or accept any pending AI plan.
