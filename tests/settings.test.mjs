import test from 'node:test';
import assert from 'node:assert/strict';
import {permissionFor,templateDates} from '../lib/settings.ts';
import {configureCalendar,displayTime,toUTC,localDay} from '../lib/calendar.ts';
const member=(roles,overrides={},production_ids=[])=>({roles,overrides,production_ids});
test('direct stage publishing and explicit deny follow role rules',()=>{
 assert.equal(permissionFor(member(['Stage Manager']),'stage'),'edit');
 assert.equal(permissionFor(member(['Assistant Stage Manager']),'stage'),'edit');
 assert.equal(permissionFor(member(['Stage Manager','Production']),'stage'),'edit');
 assert.equal(permissionFor(member(['Production','Stage Manager']),'stage'),'edit');
 assert.equal(permissionFor(member(['Production']),'stage'),'view');
 assert.equal(permissionFor(member(['Stage Manager'],{stage:'none'}),'stage'),'none');
 assert.equal(permissionFor(member(['Super Admin'],{stage:'none'}),'stage'),'edit');
});
test('guest scope stays assigned while additional department roles remain theater scoped',()=>{
 assert.equal(permissionFor(member(['Cast'],{},['one']),'stage','two'),'none');
 assert.equal(permissionFor(member(['Guest'],{},['one']),'stage','one'),'view');
 assert.equal(permissionFor(member(['Marketing','Cast'],{},['one']),'personnel','two'),'view');
 assert.equal(permissionFor(member(['Development']),'personnel'),'none');
});
test('calendar template offsets and inclusive duration cross year boundaries',()=>{
 assert.deepEqual(templateDates({anchor:'opening',offset:-14,duration:14},{opening_date:'2027-01-07',closing_date:'2027-02-01'}),{start:'2026-12-24',end:'2027-01-06'});
 assert.deepEqual(templateDates({anchor:'closing',offset:7,duration:1},{opening_date:'2027-01-07',closing_date:'2027-02-01'}),{start:'2027-02-08',end:'2027-02-08'});
});
test('theater timezone and personal time format affect input and display consistently',()=>{
 try{configureCalendar('America/Los_Angeles','24');assert.equal(toUTC('2026-10-19T18:00'),'2026-10-20T01:00:00.000Z');assert.equal(displayTime('2026-10-20T01:00:00Z'),'18:00');assert.equal(localDay('2026-10-20T01:00:00Z'),'2026-10-19');}finally{configureCalendar('America/New_York','12');}
});

test('limited accounts land on onboarding before workspace settings and approved members honor their landing permission',async()=>{const {initialWorkspaceTab,defaultAccount}=await import('../lib/settings.ts');const c={theater_id:null,account:defaultAccount,permissions:{productions:'none',calendar:'none',personnel:'none',venues:'none',stage:'none'}};assert.equal(initialWorkspaceTab(c),'Onboarding');assert.equal(initialWorkspaceTab({...c,theater_id:'theater',permissions:{...c.permissions,productions:'view'}}),'Productions');assert.equal(initialWorkspaceTab({...c,theater_id:'theater'}),'Settings');});
