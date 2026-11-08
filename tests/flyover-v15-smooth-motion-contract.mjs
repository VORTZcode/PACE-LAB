import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const map=readFileSync('ios/PaceLabCompanion/PaceWorkoutRoute.swift','utf8');
const motion=readFileSync('ios/PaceLabCompanion/PaceFlightMotion.swift','utf8');
for(const phrase of ['static func minimumJerk(_ progress: Double)','t * t * t * (t * (t * 6 - 15) + 10)','static func cinematicTarget(_ samples:','projected[0].x * 0.22 + projected[1].x * 0.56','let alpha = 1 - exp(-dt / 0.84)','let alpha = 1 - exp(-dt / 0.75)']) assert.ok(motion.includes(phrase),`Smooth motion feature missing: ${phrase}`);
for(const phrase of ['PaceFlightMotion.minimumJerk(t)','PaceFlightMotion.cinematicTarget([','targetFraction - window','targetFraction + window','response: 1.05','response: 1.15','map.setCamera(camera, animated: false)','if editing {','stage = .chase']) assert.ok(map.includes(phrase),`Camera integration missing: ${phrase}`);
const ease=t=>t*t*t*(t*(t*6-15)+10);
for(const t of [0,.01,.1,.25,.5,.75,.9,.99,1]) {assert.ok(ease(t)>=0 && ease(t)<=1);if(t>0)assert.ok(ease(t)>=ease(Math.max(0,t-.01)))}
assert.equal(ease(0),0);assert.equal(ease(1),1);assert.equal(ease(.5),.5);
console.log('V15 cinematic easing and GPS-camera smoothing source contracts passed.');
