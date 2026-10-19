import {test} from 'node:test';
import assert from 'node:assert/strict';
import {filterPeople, splitLabels, validateHeadshot} from '../lib/personnel.ts';
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
