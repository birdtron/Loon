import {test} from 'node:test';
import assert from 'node:assert/strict';
import {filterPeople, peopleInSeason, splitLabels, validateHeadshot} from '../lib/personnel.ts';
const people=[{id:'shared',display_name:'Shared Person',known_as:'Alias',person_types:['Cast','Creative'],departments:['Production'],job_title:''},{id:'other',display_name:'Other Person',known_as:'',person_types:['Cast'],departments:[],job_title:''}];
const credits=[{person_id:'shared',production_id:'romeo',role:'Romeo'},{person_id:'shared',production_id:'titus',role:'Director'},{person_id:'other',production_id:'titus',role:'Titus'}];
test('shared personnel appear once and combined filters retain their credits',()=>{
  assert.deepEqual(filterPeople(people,credits,{query:'Alias',type:'Creative',production:'titus',department:'Production'}).map(p=>p.id),['shared']);
  assert.equal(filterPeople(people,credits,{query:'Director',type:'',production:'romeo',department:''}).length,1);
  assert.equal(filterPeople(people,credits,{query:'',type:'Creative',production:'romeo',department:'Missing'}).length,0);
});
test('labels preserve multi-department membership without duplicates',()=>assert.deepEqual(splitLabels(' Production, Marketing | Production, '),['Production','Marketing']));
test('headshots reject unsupported, empty and oversized files',()=>{
  assert.doesNotThrow(()=>validateHeadshot({size:4194304,type:'image/jpeg'}));
  assert.throws(()=>validateHeadshot({size:4194305,type:'image/png'}),/4 MB/);
  assert.throws(()=>validateHeadshot({size:0,type:'image/webp'}));
  assert.throws(()=>validateHeadshot({size:20,type:'image/svg+xml'}),/JPG/);
});

test('approved season memberships scope staff and cast while preserving legacy directory behavior',()=>{
 const list=[{id:'new-staff',person_types:['Staff']},{id:'new-cast',person_types:['Cast']},{id:'legacy-staff',person_types:['Staff']},{id:'legacy-cast',person_types:['Cast']}];
 const memberships=[{person_id:'new-staff',season_id:'new'},{person_id:'new-cast',season_id:'new'}];
 assert.deepEqual(peopleInSeason(list,[],'new',memberships).map(p=>p.id),['new-staff','new-cast','legacy-staff']);
 assert.deepEqual(peopleInSeason(list,[],'old',memberships).map(p=>p.id),['legacy-staff']);
 assert.deepEqual(peopleInSeason(list,[{person_id:'legacy-cast'}],'old',memberships).map(p=>p.id),['legacy-staff','legacy-cast']);
 assert.equal(peopleInSeason(list,[],'',memberships).length,4);
});
