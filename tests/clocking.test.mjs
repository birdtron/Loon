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

test('pill filters support combined selections, no selection, and demo isolation',async()=>{
 const {filterLabor,toggleLaborPill}=await import('../lib/clocking.ts');
 const rows=[{person_id:'a',personnel:'A',production_id:'one',production:'One',department:'Scenic',minutes:120,is_demo:true},{person_id:'b',personnel:'B',production_id:'two',production:'Two',department:'Audio',minutes:180,is_demo:false},{person_id:'a',personnel:'A',production_id:'two',production:'Two',department:'Audio',minutes:60,is_demo:true}];
 const all={production:null,personnel:null,department:null};
 assert.equal(filterLabor(rows,all).length,3);
 assert.equal(filterLabor(rows,{...all,production:['two'],personnel:['a']}).reduce((sum,r)=>sum+r.minutes,0),60);
 assert.equal(filterLabor(rows,{...all,production:['one','two'],department:['Audio']}).reduce((sum,r)=>sum+r.minutes,0),240);
 assert.equal(filterLabor(rows,{...all,production:[]}).length,0);
 assert.equal(filterLabor(rows,all,false).reduce((sum,r)=>sum+r.minutes,0),180);
 assert.deepEqual(toggleLaborPill(null,'one'),['one']);assert.deepEqual(toggleLaborPill(['one'],'two'),['one','two']);assert.deepEqual(toggleLaborPill(['one'],'one'),[]);
});
