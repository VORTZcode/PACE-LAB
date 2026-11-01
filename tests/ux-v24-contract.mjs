import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const data=JSON.parse(readFileSync('ios/PaceLabCompanion/AppData/pace-programme.json','utf8'));
const lines=data.recipes.flatMap(r=>r.ingredients.split('\n').map(s=>s.replace('•','').trim()).filter(Boolean));
const aggregated=new Map();
for(const item of lines) {
  const match=item.match(/^(.*?) : (\d+) g$/);
  assert.ok(match, 'Ingredient quantities must be parseable in grams for exact grouping');
  const key=match[1].toLocaleLowerCase('fr');
  aggregated.set(key,(aggregated.get(key)??0)+Number(match[2]));
}
assert.equal(data.recipes.length,14);
assert.equal(lines.length,98);
assert.ok(aggregated.size < lines.length);
assert.equal(aggregated.get('huile d\'olive'), 182); // total across 14 recipes
const source=readFileSync('ios/PaceLabCompanion/PaceGrocery.swift','utf8');
assert.match(source,/grammes/);
assert.match(source,/setGroceries/);
assert.doesNotMatch(source,/quantity .*? estimated/i);
console.log('Nutrition V2.4: ingredient grouping is lossless over all 98 programme lines; number of distinct products',aggregated.size);
