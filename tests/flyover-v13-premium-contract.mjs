import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const source=readFileSync('ios/PaceLabCompanion/PaceWorkoutRoute.swift','utf8');
for(const token of ['renderer.lineWidth = isPlayback ? 3.4 : 4.1','renderer.lineWidth = isPlayback ? 1.6 : 3.3','.ultraThinMaterial.opacity(0.85)','let aheadFraction =','let bend = min(1, turn / 75)','let adaptivePitch =','max(500.0, min(940.0, track.totalDistance / 7))','showTelemetry.toggle()','PaceFlyoverSpeedControl(selection: $playbackSpeed)','stage == .finished ? 1 : nil'])assert.ok(source.includes(token),`V13 missing: ${token}`);
assert.ok(!source.includes('.black.opacity(0.68),\n                            in: RoundedRectangle'), 'Legacy large opaque panel should be removed');
console.log('V13 premium Flyover contract passed');
