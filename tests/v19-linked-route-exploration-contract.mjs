import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const map=readFileSync('ios/PaceLabCompanion/PaceWorkoutRoute.swift','utf8');
const detail=readFileSync('ios/PaceLabCompanion/PaceViewsActivities.swift','utf8');
for(const piece of [
'import Charts','var inspectionFraction: Double? = nil',
'let fraction = progress ?? inspectionFraction ?? 0',
'if progress == nil, let previous = coordinator.completedRoute {',
'@State private var inspectedMinute: Double? = nil',
'inspectionFraction: inspectedMinute.map {',
'struct PaceRouteInspectionTimeline: View',
'PaceHeartTimeline.prepare(start: workout.started_at,',
'series: .value("Segment mesuré", point.segment)',
'.chartXSelection(value: $inspectedMinute)',
'abs(point.minute - inspectedMinute) <= 0.9',
'Pas de FC mesurée à cet instant',
'Slider(value: Binding(',
'await reader.load(workoutID: workout.source_uuid)',
'HKQuery.predicateForObjects(from: workout)',
])assert.ok(map.includes(piece),`Missing linked GPS evidence: ${piece}`);
assert.ok(map.includes('if progress != nil,'),'Inspection must not redraw the partial playback route');
const last=detail.slice(detail.indexOf('struct WorkoutDetailScreen: View'));
const header=last.indexOf('ACTIVITÉ /'), route=last.indexOf('PaceRouteSection(workout: workout)'), report=last.indexOf('if let report = coach.report(for:');
assert.ok(header < route && route < report,'Route must be first-class before coach report');
for(const text of ['Label("Parcours", systemImage: "map")','Label("Analyses", systemImage: "waveform.path.ecg")','Label("Intervalles", systemImage: "list.number")','Label("Ressenti", systemImage: "square.and.pencil")'])assert.ok(last.includes(text),`Missing direct section navigation: ${text}`);
console.log('V19 GPS↔heart timeline, honest missing samples and activity nav contracts pass');
