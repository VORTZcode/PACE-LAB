# V14 Flyover — corrected aerial staging

A physical iPhone capture of V12 showed a loop of about 7 km viewed from too far away, yielding a flat map. The old introduction scaled wide-camera distance from TOTAL accumulated route distance, which is not its visual footprint. V14 computes the physical SW–NE diagonal of recorded GPS coordinates, and uses it to set a bounded overview height (1.4–7.6 km). Loops are thus framed by the area covered instead of the kilometres run.

The existing 30fps MapKit movement, 3 camera views and GPS-only on-device handling are unchanged. A Cinema toggle hides the large timeline and statistics during playback but keeps a small distance and playback control; exiting restores the full panel. Virtual follow-camera zoom and pitch now ease over time, with instant scrubbing.

Not evaluated: real animation framerate and imagery on the physical device during a full replay, camera coverage on areas with flat/no realistic 3D in Apple Maps, multi-loop/dateline tracks. No claims of superiority over Strava. Install over existing iOS app; never uninstall and lose saved health/workout data.
