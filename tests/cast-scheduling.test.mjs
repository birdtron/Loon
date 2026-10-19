import {test} from 'node:test';
import assert from 'node:assert/strict';
import {productionCast,callOnDay,rehearsalTimes} from '../lib/cast-scheduling.ts';
test('only cast credited to selected production are selectable and shared roles do not duplicate people',()=>{
 const people=[{id:'a',display_name:'Actor'},{id:'b',display_name:'Creative'},{id:'c',display_name:'Other show'}];
 const credits=[{person_id:'a',production_id:'romeo',credit_type:'Cast'},{person_id:'a',production_id:'romeo',credit_type:'Cast'},{person_id:'b',production_id:'romeo',credit_type:'Creative'},{person_id:'c',production_id:'titus',credit_type:'Cast'}];
 assert.deepEqual(productionCast(people,credits,'romeo').map(p=>p.id),['a']);
});
test('callboard uses Eastern date, excludes canceled/draft calls and treats midnight end as exclusive',()=>{
 const e={category:'Rehearsal',call_status:'Published',start:'2026-10-20T01:00:00Z',end:'2026-10-20T04:00:00Z'};
 assert.equal(callOnDay(e,'2026-10-19'),true);assert.equal(callOnDay(e,'2026-10-20'),false);
 assert.equal(callOnDay({...e,call_status:'Canceled'},'2026-10-19'),false);assert.equal(callOnDay({...e,call_status:'Draft'},'2026-10-19'),false);
});
test('rehearsal time conversion validates order and the DST boundary',()=>{
 assert.deepEqual(rehearsalTimes('2026-11-02','18:00','21:00'),{start:'2026-11-02T23:00:00.000Z',end:'2026-11-03T02:00:00.000Z'});
 assert.throws(()=>rehearsalTimes('2026-10-19','20:00','18:00'),/after/);
 assert.throws(()=>rehearsalTimes('2026-03-08','02:30','04:00'),/does not exist/);
});
