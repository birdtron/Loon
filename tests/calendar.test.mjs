import {test} from 'node:test';
import assert from 'node:assert/strict';
import {addDays, calendarItems, dayDifference, localDay, matchesProduction, toUTC, weekSegments} from '../lib/calendar.ts';

test('30-day ranges and navigation stay calendar-based across DST and leap days', () => {
  assert.equal(addDays('2026-10-19', 29), '2026-11-17');
  assert.equal(addDays('2026-10-19', 30), '2026-11-18');
  assert.equal(dayDifference('2026-10-19', '2026-11-17'), 29);
  assert.equal(addDays('2028-02-28', 1), '2028-02-29');
  assert.equal(addDays('2026-11-01', -1), '2026-10-31');
});
test('timestamp dates use Eastern time and midnight end is exclusive', () => {
  assert.equal(localDay('2026-10-20T01:00:00Z'), '2026-10-19');
  const items=calendarItems([], [{id:'strike', production_id:'p', title:'Strike', category:'Strike', start:'2026-11-02T14:00:00Z', end:'2026-11-04T05:00:00Z'}]);
  assert.equal(items[0].startDay, '2026-11-02');
  assert.equal(items[0].endDay, '2026-11-03');
});
test('multi-week bars clip and mark continuation at both edges', () => {
  const item={id:'run', productionId:'p', label:'Run', category:'Performance run', startDay:'2026-10-01', endDay:'2026-11-30'};
  const [segment]=weekSegments([item], '2026-10-19', '2026-11-17');
  assert.deepEqual({...segment,item:undefined},{item:undefined,column:1,span:7,lane:0,continuesBefore:true,continuesAfter:true});
  const [last]=weekSegments([item], '2026-11-16', '2026-11-17');
  assert.equal(last.span, 2);
  assert.equal(last.continuesAfter, true);
});
test('overlapping bars never share a lane and separated bars reuse space', () => {
  const make=(id,startDay,endDay)=>({id,productionId:'p',label:id,category:'Strike',startDay,endDay});
  const rows=weekSegments([make('a','2026-10-19','2026-10-21'),make('b','2026-10-20','2026-10-22'),make('c','2026-10-23','2026-10-24')], '2026-10-19','2026-11-17');
  assert.notEqual(rows[0].lane,rows[1].lane);
  assert.equal(rows[0].lane,rows[2].lane);
});
test('production and series filters combine, including unassigned series', () => {
  const p={id:'a',series:'Signature'};
  assert.equal(matchesProduction(p,'a','Signature'),true);
  assert.equal(matchesProduction(p,'a','Youth'),false);
  assert.equal(matchesProduction(p,'b','Signature'),false);
  assert.equal(matchesProduction({id:'b',series:null},'','Unassigned'),true);
});
test('local activity times survive DST and nonexistent times are rejected', () => {
  assert.equal(toUTC('2026-10-31T09:00'),'2026-10-31T13:00:00.000Z');
  assert.equal(toUTC('2026-11-02T09:00'),'2026-11-02T14:00:00.000Z');
  assert.throws(()=>toUTC('2026-03-08T02:30'),/does not exist/);
});
