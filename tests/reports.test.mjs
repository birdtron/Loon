import {test} from 'node:test';
import assert from 'node:assert/strict';
import {blankReport,calledOnDate,hasFightCredit,validateReport,reportRuntime} from '../lib/reports.ts';
const base=()=>({...blankReport(['Scenic']),start:'2026-10-20T01:00:00Z',end:'2026-10-20T04:30:00Z',summary:'Blocking',breaks:'Yes'});
test('called cast uses show and local date, deduplicates overlapping calls, excludes drafts and cancellations',()=>{
 const e={production_id:'p',category:'Rehearsal',call_status:'Published',start:'2026-10-20T01:00:00Z',end:'2026-10-20T04:00:00Z'};
 const events=[{...e,id:'a'},{...e,id:'b'},{...e,id:'c',call_status:'Canceled'},{...e,id:'d',production_id:'other'}];
 const members=[{event_id:'a',person_id:'1'},{event_id:'b',person_id:'1'},{event_id:'c',person_id:'2'},{event_id:'d',person_id:'3'}];
 assert.deepEqual(calledOnDate(events,members,'p','2026-10-19'),['1']);assert.deepEqual(calledOnDate(events,members,'p','2026-10-20'),[]);
});
test('reports permit midnight crossing and validate break explanations and report date',()=>{
 validateReport('Rehearsal','2026-10-19',base(),false);assert.equal(reportRuntime(base()),210);
 assert.throws(()=>validateReport('Rehearsal','2026-10-20',base(),false),/report date/);
 assert.throws(()=>validateReport('Rehearsal','2026-10-19',{...base(),breaks:'No'},false),/breaks/);
 assert.throws(()=>validateReport('Rehearsal','2026-10-19',{...base(),end:'2026-10-22T04:30:00Z'},false),/24 hours/);
});
test('performance validates ordered timing, conditional fight call, penalties and cancellation',()=>{
 const d={...base(),house:'2026-10-20T00:30:00Z',has_intermission:true,intermission:'2026-10-20T02:00:00Z',act_two:'2026-10-20T02:20:00Z'};
 validateReport('Performance','2026-10-19',d,false);
 assert.throws(()=>validateReport('Performance','2026-10-19',d,true),/fight/);
 assert.throws(()=>validateReport('Performance','2026-10-19',{...d,act_two:'2026-10-20T01:50:00Z'},false),/order/);
 assert.throws(()=>validateReport('Performance','2026-10-19',{...d,penalties:true},false),/overtime/);
 const cancelled={...blankReport([]),cancelled:true,cancel_reason:'Facility',cancel_details:'Power outage',summary:'Canceled before house opened.'};
 validateReport('Performance','2026-10-19',cancelled,true);assert.equal(reportRuntime(cancelled),null);
 assert.throws(()=>validateReport('Performance','2026-10-19',{...cancelled,cancel_details:''},true),/cancellation/);
 assert.equal(hasFightCredit([{production_id:'p',role:'Fight Choreographer'}],'p'),true);
 assert.equal(hasFightCredit([{production_id:'other',role:'Fight Choreographer'}],'p'),false);
});
