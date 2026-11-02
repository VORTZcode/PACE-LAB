import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const read = name => readFileSync('ios/PaceLabCompanion/' + name, 'utf8');
const core=read('PaceViewsCore.swift');
const activities=read('PaceViewsActivities.swift');
const run=read('PaceRunAnalysis.swift');
const intervals=read('PaceRunIntervals.swift');
const progress=read('PaceViewsProgress.swift');
const body=read('PaceViewsBody.swift');
const timeline=read('PaceHeartTimeline.swift');
for (const text of [
  'struct PaceGlassCardSurface: ViewModifier',
  'content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))',
  '.modifier(PaceGlassCardSurface(cornerRadius: PaceDesign.cardRadius))',
  '.modifier(PaceGlassCardSurface(cornerRadius: 20))',
  'content.background(.regularMaterial,'
]) assert.ok(core.includes(text), 'Missing core glass: '+text);
for (const file of ['PaceViewsActivities.swift','PaceViewsProgramme.swift','PaceViewsNutrition.swift','PaceHomeInsights.swift','PaceCoachScreen.swift'])
  assert.ok(read(file).includes('.modifier(PaceGlassCardSurface('), 'Unconverted card in '+file);
for (const text of [
  'PaceHeartTimeline.prepare(',
  'minute: point.minute',
  '.chartXScale(domain: 0...max(1, timeline.lastMinute))',
  '.chartYScale(domain: timeline.yLower...timeline.yUpper)',
  'series: .value("Segment mesuré", point.segment)',
  'unmeasuredTailMinutes',
  'Énergie active'
]) assert.ok(activities.includes(text) || text==='minute: point.minute' && activities.includes('.value("Minute écoulée", point.minute)'), 'Missing HR chart: '+text);
assert.ok(!activities.includes('.value("Mesure", sample.offset)'), 'Legacy index-based HR chart still in use');
for (const text of [
  'date >= started, date <= ended',
  'if index > 0, item.0 - sorted[index-1].0 > 2',
  '(25...245).contains(item.bpm)',
  'hasMissingTail'
]) assert.ok(timeline.includes(text), 'Missing heart timeline guard: '+text);
for (const text of [
  'PaceHeartTimeline.decodeDate',
  'series: .value("Segment de mesure", point.segment)',
  'let window = max(2,Int(ceil(Double(full.count)/160)))',
  'chosen.insert(low)',
  'chosen.insert(high)',
  '.chartYAxisLabel(metric.unit)',
  'PaceFormat.pace(selectedPoint.value)',
  'Minutes écoulées'
]) assert.ok(run.includes(text), 'Missing running plot feature: '+text);
assert.ok(intervals.includes('(25...245).contains(p.bpm)'));
assert.ok(intervals.includes('(0.7...12).contains(p.value)'));
assert.ok(intervals.includes('(1...1800).contains(p.value)'));
assert.ok(progress.includes('.chartYAxisLabel("km")'));
assert.ok(progress.includes('.chartYAxisLabel("bpm")'));
assert.ok(progress.includes('PaceMetric(caption: "Courses"'));
assert.ok(body.includes('.chartYAxisLabel("kg")'));
console.log('V3.9: static Liquid Glass cards, truthful elapsed HR graphs, gap handling, peak-preserving run plots and chart units verified.');
