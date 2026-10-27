import {test} from 'node:test';
import assert from 'node:assert/strict';
import {previewScheduleCSV,scheduleHeaders,scheduleTimes} from '../lib/rehearsal-schedules.ts';
const venues=[{id:'v',name:'Rehearsal Hall'}],cast=[{id:'a',display_name:'Child A'},{id:'b',display_name:'Child B'}];
const csv=rows=>scheduleHeaders.join(',')+'\n'+rows;
test('schedule import allows optional scene and cast and quoted event names',()=>{
 const rows=previewScheduleCSV(csv('2026-11-02,18:00,21:00,Rehearsal Hall,"Photo shoot, costumes",,\n2026-11-03,18:00,20:00,v,Rehearsal,Act I,Child A|Child B'),'show',venues,cast,[]);
 assert.equal(rows[0].error,'');assert.deepEqual(rows[0].draft.schedule_cast,[]);assert.equal(rows[0].draft.title,'Photo shoot, costumes');assert.deepEqual(rows[1].draft.schedule_cast,['a','b']);
});
test('schedule import rejects unknown or ambiguous cast and venues, bad dates and duplicate events',()=>{
 for(const row of ['2026-02-30,18:00,21:00,v,Rehearsal,,','2026-11-02,21:00,18:00,v,Rehearsal,,','2026-11-02,18:00,21:00,missing,Rehearsal,,','2026-11-02,18:00,21:00,v,Rehearsal,,Other show actor'])assert.ok(previewScheduleCSV(csv(row),'show',venues,cast,[])[0].error);
 const row='2026-11-02,18:00,21:00,v,Rehearsal,,';
 assert.match(previewScheduleCSV(csv(row+'\n'+row),'show',venues,cast,[])[1].error,/already exists/);
 const prior=previewScheduleCSV(csv(row),'show',venues,cast,[])[0].draft;
 assert.match(previewScheduleCSV(csv(row),'show',venues,cast,[{...prior,rehearsal_schedule:true}])[0].error,/already exists/);
 assert.match(previewScheduleCSV(csv(row+'Child A'),'show',venues,[...cast,{id:'c',display_name:'Child A'}],[])[0].error,/ambiguous/);
});
test('schedule times use theater timezone and reject nonexistent DST times',()=>{
 assert.equal(scheduleTimes('2026-11-02','18:00','21:00').start,'2026-11-02T23:00:00.000Z');
 assert.throws(()=>scheduleTimes('2026-03-08','02:30','04:00'),/does not exist/);
});
