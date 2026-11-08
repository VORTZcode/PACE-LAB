# V15 smoother cinematic replay

- The three-point GPS camera target averages positions (22/56/22%) in projected coordinates, without editing the recorded route, distances or athlete marker.
- Introductions and outros use a fifth-degree minimum-jerk easing function with smooth endpoint velocity/acceleration.
- Heading and follow-camera position settle more gradually; zoom and pitch use a slightly longer filter response.
- Seeking remains an immediate camera jump, not a slow animation to an incorrect location.
- 30fps SwiftUI timeline retained; actual MapKit FPS and tile-download jitter are not yet measured on the connected physical device. Smoother command trajectories do not guarantee a fixed render frame rate.
- iPhone app install is non-destructive and user data remains local.
