import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const route=readFileSync('ios/PaceLabCompanion/PaceWorkoutRoute.swift','utf8');
const motion=readFileSync('ios/PaceLabCompanion/PaceFlightMotion.swift','utf8');
for (const key of ['var footprintMeters: CLLocationDistance','north = max(north','south = min(south','east = max(east','west = min(west','track.footprintMeters * 2.6','@State private var cinemaMode = false','cinemaMode.toggle()','if !cinemaMode {','sceneProgress = min(1, sceneProgress + elapsed / 4.5)','coordinator.cameraDistance = smoothedDistance','coordinator.cameraPitch = smoothedPitch','previous: coordinator.cameraDistance','previous: coordinator.cameraPitch']) {
  assert.ok(route.includes(key),`V14 missing: ${key}`)
}
assert.ok(motion.includes('static func scalar(previous: Double?, desired: Double,'),'Zoom easing regression');
assert.ok(route.includes('HKWorkoutRouteQuery(route: sample)'));
console.log('V14 route footprint cinema mode and smooth camera contracts passed');
