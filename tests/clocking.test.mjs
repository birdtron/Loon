import test from 'node:test';
import assert from 'node:assert/strict';
import {eligibleForClocking,elapsedMinutes,laborGroups,validateClockDraft} from '../lib/clocking.ts';
test('creative, admin and interns qualify, cast-only does not',()=>{
 for(const person_types of [['Creative'],['Staff'],['Crew'],['Cast','Creative']])assert.equal(eligibleForClocking({intern:false,person_types}),true);
 assert.equal(eligibleForClocking({intern:false,person_types:['Cast']}),false);
 assert.equal(eligibleForClocking({intern:false,person_types:['Other']}),false);
 assert.equal(eligibleForClocking({intern:true,person_types:['Cast']}),true);
});
test('elapsed time uses actual timestamps, including overnight and DST',()=>{
 assert.equal(elapsedMinutes('2026-10-19T22:00Z','2026-10-20T06:00Z'),480);
 assert.equal(elapsedMinutes('2026-11-01T04:00Z','2026-11-01T08:00Z'),240);
 assert.equal(elapsedMinutes('2026-10-19T22:00Z','2026-10-21T06:00Z'),1920);
});
test('clock-in needs assignment details, never user-entered dates or breaks',()=>{
 const d={id:'entry',person_id:'person',production_id:'show',department:'Scenic',role:'Designer',notes:''};
 assert.doesNotThrow(()=>validateClockDraft(d));assert.throws(()=>validateClockDraft({...d,department:''}),/department/);
 assert.throws(()=>validateClockDraft({...d,person_id:''}),/personnel/);
 assert.throws(()=>validateClockDraft({...d,notes:'x'.repeat(10001)}),/10,000/);
});
test('chart groups conserve hours without multiplying multi-department people',()=>{
 const rows=[{personnel:'A',production:'Show A',department:'Scenic',minutes:90},{personnel:'A',production:'Show B',department:'Lighting',minutes:120},{personnel:'B',production:'Show A',department:'Scenic',minutes:30}];
 for(const group of ['personnel','production','department'])assert.equal(laborGroups(rows,group).reduce((n,g)=>n+g.minutes,0),240);
 assert.deepEqual(laborGroups(rows,'personnel'),[{label:'A',minutes:210},{label:'B',minutes:30}]);
 assert.deepEqual(laborGroups([],'production'),[]);
});
