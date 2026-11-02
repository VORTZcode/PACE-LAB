import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const elements = new Map();
const node = id => {
  if(!elements.has(id)) elements.set(id, {textContent:'', innerHTML:'',style:{},classList:{add(){},remove(){}}});
  return elements.get(id);
};
const storage = new Map();
const context = vm.createContext({
  window:{scrollTo(){}},
  navigator:{},
  location:{protocol:'file:'},
  document:{getElementById:node,querySelector:node,addEventListener(){}},
  localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
  Date, Intl, console, Math, Number, String, Array, Object,
});
vm.runInContext(fs.readFileSync('assets/programme.js','utf8'),context);
vm.runInContext(fs.readFileSync('assets/app.js','utf8'),context);
assert.equal(node('pageTitle').textContent,'Tableau de bord');
assert.match(node('view').innerHTML,/Construire le moteur/);
vm.runInContext("page='runs';render()",context);
assert.match(node('view').innerHTML,/0 séances enregistrées/);
vm.runInContext("page='plan';render()",context);
assert.match(node('view').innerHTML,/Détail de la séance/);
vm.runInContext("page='food';render()",context);
assert.match(node('view').innerHTML,/Les 14 recettes/);
vm.runInContext("page='progress';render()",context);
assert.match(node('view').innerHTML,/VO₂ MAX ESTIMÉE/);
context.example = {date:'2026-11-01',distance:7,minutes:61,pace:61/7,hr:156,origin:'manual'};
vm.runInContext("state.runs=[example];page='runs';render()",context);
assert.match(node('view').innerHTML,/1 séances enregistrées/);
console.log('Rendu de base OK : accueil, courses vides, programme, nutrition, progrès, nouvelle course');
