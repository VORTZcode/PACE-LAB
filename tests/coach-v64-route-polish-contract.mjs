import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (name) => readFileSync('ios/PaceLabCompanion/' + name + '.swift', 'utf8');
const activity = read('PaceViewsActivities');
const map = read('PaceWorkoutRoute');
const motion = read('PaceFlightMotion');
const pbx = readFileSync('ios/PaceLabCompanion.xcodeproj/project.pbxproj', 'utf8');

// The hero map is part of the first screenful and precedes the Coach report.
const detail = activity.slice(activity.indexOf('struct WorkoutDetailScreen: View'));
assert.ok(detail.indexOf('PaceRouteSection(workout: workout)') <
  detail.indexOf('if let report = coach.report(for: workout.source_uuid)'));
assert.ok(map.includes('PaceRouteMap(track: route)'));
assert.ok(map.includes('.frame(height: 360)'));
assert.ok(map.includes('padding(.horizontal, -PaceDesign.screenInset)'));
assert.ok(map.includes('MKImageryMapConfiguration(elevationStyle: .realistic)'));
assert.ok(map.includes('PaceFlyoverSpeedControl(selection: $playbackSpeed)'));
assert.ok(map.includes('Button { showFullMap = true }'));
assert.ok(map.includes('PaceRouteFullMapScreen(track: route, workout: workout)'));
assert.ok(map.includes('Label("Survol 3D", systemImage: "play.fill")'));
assert.ok(map.includes('.clipShape(RoundedRectangle(cornerRadius: 18))'));

// Playback has time-based interpolation and smooth bounded angular velocity.
assert.ok(map.includes('track.cameraCourse(at: fraction)'));
assert.ok(map.includes('PaceFlightMotion.heading('));
assert.ok(map.includes('PaceFlightMotion.center('));
assert.ok(map.includes('every: 1.0 / 30.0'));
assert.ok(map.includes('map.setCamera(camera, animated: false)'));
assert.ok(motion.includes('static func shortestTurn(from: Double, to: Double)'));
assert.ok(motion.includes('max(-78 * dt, min(78 * dt, delta * alpha))'));
assert.ok(pbx.includes('PaceFlightMotion.swift in Sources'));

// The HealthKit crash fix must remain active even after the visual redesign.
assert.ok(map.includes('if retry {'));
assert.ok(map.includes('HKObjectType.workoutType(), HKSeriesType.workoutRoute()'));
assert.ok(!map.includes('read: [HKSeriesType.workoutRoute()]'));
console.log('PASS V6.4: hero map, full-screen navigation, 30fps time-driven camera, yaw smoothing, crash regression guard');
