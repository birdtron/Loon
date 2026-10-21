import test from 'node:test';
import assert from 'node:assert/strict';
import {eligibleForClocking,workedMinutes,laborGroups,validateClockDraft} from '../lib/clocking.ts';
import {configureCalendar} from '../lib/calendar.ts';
test('creative, admin and interns qualify, cast-only does not',()=>{
 for(const person_types of [['Creative'],['Staff'],['Crew'],['Cast','Creative']])assert.equal(eligibleForClocking({intern:false,person_types}),true);
 assert.equal(eligibleForClocking({intern:false,person_types:['Cast']}),false);
 assert.equal(eligibleForClocking({intern:false,person_types:['Other']}),false);
 assert.equal(eligibleForClocking({intern:true,person_types:['Cast']}),true);
});
test('hours handle overnight shifts, breaks, and DST by elapsed time',()=>{
 assert.equal(workedMinutes('2026-10-19T22:00Z','2026-10-20T06:00Z',30),450);
 assert.equal(workedMinutes('2026-11-01T04:00Z','2026-11-01T08:00Z',0),240);
 for(const [s,e,b] of [['bad','bad',0],['2026-10-20','2026-10-19',0],['2026-10-19','2026-10-21',0],['2026-10-19','2026-10-20',1440],['2026-10-19','2026-10-20',-1],['2026-10-19','2026-10-20',1.5]])assert.throws(()=>workedMinutes(s,e,b));
});
test('work date uses theater time zone',()=>{
 configureCalendar('America/New_York');
 const d={id:'entry',person_id:'person',production_id:'show',work_date:'2026-10-19',started_at:'2026-10-20T02:00:00Z',ended_at:'2026-10-20T05:00:00Z',break_minutes:0,department:'Scenic',role:'Designer',notes:''};
 assert.equal(validateClockDraft(d),180);assert.throws(()=>validateClockDraft({...d,work_date:'2026-10-20'}),/work date/);
 assert.throws(()=>validateClockDraft({...d,department:''}),/department/);
});
test('chart groups conserve hours without multiplying multi-department people',()=>{
 const rows=[{personnel:'A',production:'Show A',department:'Scenic',minutes:90},{personnel:'A',production:'Show B',department:'Lighting',minutes:120},{personnel:'B',production:'Show A',department:'Scenic',minutes:30}];
 for(const group of ['personnel','production','department'])assert.equal(laborGroups(rows,group).reduce((n,g)=>n+g.minutes,0),240);
 assert.deepEqual(laborGroups(rows,'personnel'),[{label:'A',minutes:210},{label:'B',minutes:30}]);
 assert.deepEqual(laborGroups([],'production'),[]);
});
