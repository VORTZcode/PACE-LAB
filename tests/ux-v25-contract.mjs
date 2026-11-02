import assert from 'node:assert/strict';
import {readFileSync, existsSync} from 'node:fs';
const read = name => readFileSync('ios/PaceLabCompanion/' + name, 'utf8');
const chart=read('PaceRunAnalysis.swift');
const core=read('PaceViewsCore.swift');
const insights=read('PaceHomeInsights.swift');
assert.match(chart,/var prepared: \[RunChartMetric: \[RunChartPoint\]\]/);
assert.match(chart,/for item in RunChartMetric\.allCases/);
assert.match(chart,/preparedKey == preparationKey/);
assert.match(chart,/\.frame\(height: 238\)/);
assert.match(chart,/transaction\.animation = nil/);
assert.doesNotMatch(chart,/chartData = \[\]/);
assert.match(chart,/Double\(full\.count\)\/160/);
assert.match(chart,/chosen\.insert\(low\)/);
assert.match(chart,/chosen\.insert\(high\)/);
for (const metric of ['month','week']) {
  assert.ok(core.includes('PaceInsightScreen(kind: .' + metric + ')'));
}
assert.ok(core.includes('StrengthWorkoutDetailScreen(workout: latest)'));
assert.ok(core.includes('Ouvrir ma séance'));
assert.match(core,/glassEffect\(\.regular\.interactive\(\), in: \.rect\(cornerRadius: cornerRadius\)\)/);
assert.match(insights,/Chart\(volumeBars\)/);
assert.match(insights,/WorkoutDetailScreen\(workout: workout\)/);
assert.match(insights,/NavigationLink/);
assert.match(insights,/calendar\.isDate/);
assert.ok(existsSync('ios/PaceLabCompanion/PaceHomeInsights.swift'));
console.log('V2.5 navigation insights, stable chart viewport, precomputation and Liquid Glass surfaces verified.');
