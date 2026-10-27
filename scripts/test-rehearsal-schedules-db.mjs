// Install @electric-sql/pglite in a temporary directory and set PGLITE_MODULE to its dist/index.js.
const {PGlite}=await import(process.env.PGLITE_MODULE||'@electric-sql/pglite');
import {readFile,readdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth; create schema storage;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz,deleted_at timestamptz,is_anonymous boolean,encrypted_password text,email_change text,phone text);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth,storage to authenticated; grant execute on function auth.uid() to authenticated;
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
create table storage.objects(id uuid,bucket_id text,name text);alter table storage.objects enable row level security;
create function storage.foldername(text) returns text[] language sql as $$select string_to_array($1,'/')$$;`);
const root=new URL('../supabase/migrations/',import.meta.url);
for(const name of (await readdir(root)).filter(n=>n<='20261019195548_settings_access_refinements.sql'||n==='20261020234449_read_only_demo_access.sql'||n.endsWith('_rehearsal_schedules.sql')).sort()){
 // Legacy exported function definitions omit a final delimiter; normalize only in this test harness.
 try{await db.exec((await readFile(new URL(name,root),'utf8')).replaceAll('end $function$\n','end $function$;\n'));}catch(e){console.error(name,e.message);throw e;}
}
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
await db.exec(`insert into auth.users(id,email,email_confirmed_at) values('${id(1)}','sm@test.invalid',now()),('${id(2)}','other@test.invalid',now()),('${id(3)}','demo@test.invalid',now());
insert into theaters(id,slug,name) values('${id(10)}','a','Account A'),('${id(20)}','b','Account B');
insert into seasons(id,theater_id,name) values('${id(11)}','${id(10)}','Season A'),('${id(21)}','${id(20)}','Season B');
insert into scripts(id,theater_id,title,playwright) values('${id(12)}','${id(10)}','Script','Writer'),('${id(22)}','${id(20)}','Script','Writer');
insert into venues(id,theater_id,name) values('${id(13)}','${id(10)}','Hall'),('${id(23)}','${id(20)}','Hall');
insert into productions(id,theater_id,season_id,script_id,title,opening_date,closing_date) values('${id(14)}','${id(10)}','${id(11)}','${id(12)}','Show A','2026-11-01','2026-12-31'),('${id(24)}','${id(20)}','${id(21)}','${id(22)}','Show B','2026-11-01','2026-12-31');
insert into people(id,theater_id,source_key,display_name) values('${id(15)}','${id(10)}','a','Child A'),('${id(16)}','${id(10)}','b','Child B'),('${id(25)}','${id(20)}','c','Other actor');
insert into production_credits(theater_id,production_id,person_id,role,credit_type) values('${id(10)}','${id(14)}','${id(15)}','Child','Cast'),('${id(10)}','${id(14)}','${id(16)}','Child','Cast'),('${id(20)}','${id(24)}','${id(25)}','Child','Cast');
insert into private.workspace_members(theater_id,email,user_id,roles) values('${id(10)}','sm@test.invalid','${id(1)}',array['Stage Manager']),('${id(20)}','other@test.invalid','${id(2)}',array['Stage Manager']),('${id(10)}','demo@test.invalid','${id(3)}',array['Super Admin']);
insert into private.read_only_users(user_id) values('${id(3)}');
set role authenticated;set request.jwt.claim.sub='${id(1)}';`);
const draft=(n,extra={})=>({id:id(n),production_id:id(14),expected_updated_at:null,start:`2026-11-${String(n-90).padStart(2,'0')}T18:00:00Z`,end:`2026-11-${String(n-90).padStart(2,'0')}T21:00:00Z`,venue_id:id(13),title:'Rehearsal',schedule_scene:'',schedule_cast:[],call_status:'Published',...extra});
const save=async rows=>(await db.query('select save_rehearsal_schedule($1::jsonb) result',[JSON.stringify(rows)])).rows[0].result;
const first=draft(101);let saved=(await save([first]))[0];assert.equal(saved.rehearsal_schedule,true);
assert.equal((await save([first]))[0].id,saved.id);
assert.equal((await db.query('select count(*) n from rehearsal_calls')).rows[0].n,0);
await save([draft(102,{schedule_cast:[id(15),id(16)]})]);
await assert.rejects(save([draft(103,{schedule_cast:[id(25)]})]),/not cast/);
await assert.rejects(save([draft(103,{venue_id:id(23)})]),/venue|foreign key/);
await assert.rejects(save([draft(103,{production_id:id(24)})]),/access/);
await assert.rejects(save([draft(103),draft(104,{schedule_cast:[id(25)]})]),/not cast/);
assert.equal((await db.query('select count(*) n from calendar_events')).rows[0].n,2);
await assert.rejects(save([{...first,id:id(110)}]),/overlaps|duplicate/);
saved=(await save([{...first,expected_updated_at:saved.updated_at,title:'Photo shoot'}]))[0];
await assert.rejects(save([{...first,expected_updated_at:'2020-01-01T00:00:00Z'}]),/changed/);
await assert.rejects(db.query('insert into rehearsal_calls(event_id,theater_id,production_id,work) values($1,$2,$3,$4)',[id(101),id(10),id(14),'Call']),/cannot be published/);
// A separate daily call can coexist in the room without converting the plan.
await db.query('select save_rehearsal_call($1::jsonb)',[JSON.stringify({id:id(120),production_id:id(14),expected_updated_at:null,start:first.start,end:first.end,venue_id:id(13),work:'Daily detail',act:'',scene:'',location:'',notes:'',person_ids:[id(15)],call_status:'Published'})]);
assert.equal((await db.query('select count(*) n from rehearsal_calls')).rows[0].n,1);
await assert.rejects(save([draft(121,{start:first.start,end:first.end,title:'Conflicting planned event'})]),/overlaps/);
await db.exec(`set request.jwt.claim.sub='${id(2)}'`);
assert.equal((await db.query('select count(*) n from calendar_events')).rows[0].n,0);
await assert.rejects(save([draft(103)]),/access/);
await db.exec(`set request.jwt.claim.sub='${id(3)}'`);
await assert.rejects(save([draft(103)]),/access/);
await db.exec('set role anon');await assert.rejects(save([draft(103)]),/permission denied/);
console.log('PASS SQL: real migrations; stage manager save/edit; optional and multiple cast; atomic rollback; retries; duplicates; stale edits; cross-account denial; demo and anonymous write denial; callboard isolation.');
await db.close();
