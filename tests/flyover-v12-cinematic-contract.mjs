import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const route=readFileSync('ios/PaceLabCompanion/PaceWorkoutRoute.swift','utf8');
const needs=['enum PaceFlyoverCameraMode','case follow = "Suivi"','case panorama = "Panorama"','case overhead = "Verticale"','case .intro:','case .chase:','case .outro:','case .finished:','introProgress: stage == .intro','outroProgress: stage == .outro','stage == .finished ? 1 : nil','wideDistance * pow','closeDistance * pow','showTelemetry.toggle()','freeCamera.toggle()','if !freeCamera { recenterToken += 1 }','ALLURE GPS · 45 S','ALTITUDE GPS','if editing {','sceneProgress = min(1, sceneProgress + elapsed / 4.5)','sceneProgress = min(1, sceneProgress + elapsed / 5)'];
for(const n of needs)assert.ok(route.includes(n),`Missing cinematic feature ${n}`);
assert.ok(route.includes('HKQuery.predicateForObjects(from: workout)'),'Real GPS source retained');
assert.ok(route.includes('MKImageryMapConfiguration(elevationStyle: .realistic)'));
console.log('V12 cinematic 3D camera, route UX, GPS, controls and recap contracts pass.');
