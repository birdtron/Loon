// Offline integration checks. PGLITE_MODULE can point at a temporary PGlite install.
import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
const {PGlite}=await import(process.env.PGLITE_MODULE||'@electric-sql/pglite');
const root=new URL('../../',import.meta.url), read=p=>readFile(new URL(p,root),'utf8');
const db=new PGlite();
await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select null::uuid$$;create function private.has_thanos() returns boolean language sql as $$select true$$;`);
await db.exec(await read('supabase/migrations/20261019170000_core.sql'));
await db.exec(await read('supabase/migrations/20261019180822_calendar_activities.sql'));
await db.exec(`create trigger validate_performance before insert or update on public.calendar_events for each row execute function private.validate_performance();`);
await db.exec((await read('supabase/migrations/20261019182146_personnel_directory.sql')).split('-- New uploaded headshots')[0]);
await db.exec(await read('supabase/migrations/20261019191421_cast_scheduling.sql'));
await db.exec(await read('supabase/migrations/20261019192435_parallel_rehearsal_calls.sql'));
await db.exec(`create unique index calendar_events_performance_start_key on public.calendar_events(theater_id,production_id,category,start) where category='Performance';`);
await db.exec(await read('supabase/seed-demo.sql'));
await db.exec(await read('supabase/seeds/personnel-demo.sql'));
await db.exec(`create table public.personnel_seasons(theater_id uuid,person_id uuid,season_id uuid,primary key(theater_id,person_id,season_id));`);
const count=async table=>(await db.query(`select count(*)::int n from public.${table}`)).rows[0].n;
const d=JSON.parse(await read('docs/test-shows/les-miserables.json'));
const before={people:await count('people'),credits:await count('production_credits'),events:await count('calendar_events')};
const oldPeople=JSON.stringify((await db.query('select * from people order by id')).rows);
const seed=await read('supabase/seeds/les-miserables-demo.sql');
await db.exec(seed);
const p=(await db.query("select * from productions where title='Les Misérables'")).rows[0];
assert.equal(p.is_demo,true);assert.equal(p.publish,false);assert.equal(p.runtime_minutes,180);
assert.equal((await db.query('select musical from scripts where id=$1',[p.script_id])).rows[0].musical,true);
assert.equal(await count('people'),before.people+d.people.filter(p=>!p.reuse).length);
assert.equal((await db.query('select count(distinct person_id)::int n from production_credits where production_id=$1',[p.id])).rows[0].n,d.people.length);
assert.equal((await db.query('select count(*)::int n from personnel_seasons where season_id=$1',[p.season_id])).rows[0].n,d.people.length);
assert.equal(JSON.stringify((await db.query("select * from people where source_key not like 'les-mis-demo:%' order by id")).rows),oldPeople);
const cast=(await db.query("select count(distinct person_id)::int n from production_credits where production_id=$1 and credit_type='Cast'",[p.id])).rows[0].n;assert.equal(cast,35);
for(const person of d.people){for(const role of person.covers){assert.equal((await db.query('select count(*)::int n from production_credits c join people p on p.id=c.person_id where c.production_id=$1 and p.source_key=$2 and c.role=$3',[p.id,person.source_key,'Understudy: '+role])).rows[0].n,1);}}
const perfs=(await db.query("select * from calendar_events where production_id=$1 and category='Performance' order by start",[p.id])).rows;
assert.equal(perfs.length,22);
for(const e of perfs){assert.equal((e.end-e.start)/60000,180);assert.ok(e.start.toISOString().slice(0,10)>=d.opening);assert.ok(e.start.toISOString().slice(0,10)<=d.closing);}
// Distinct people for parallel calls, no active cast or venue collisions in this fixture.
const conflicts=await db.query(`select a.id from calendar_events a join calendar_events b on a.id<b.id and a.start<b."end" and b.start<a."end" where a.production_id=$1 and b.production_id=$1 and a.call_status='Published' and b.call_status='Published' and (a.venue_id=b.venue_id or exists(select 1 from rehearsal_call_cast x join rehearsal_call_cast y using(person_id) where x.event_id=a.id and y.event_id=b.id))`,[p.id]);assert.equal(conflicts.rows.length,0);
assert.ok((await db.query("select 1 from calendar_events where production_id=$1 and call_status='Canceled'",[p.id])).rows.length);
assert.ok((await db.query("select 1 from calendar_events where production_id=$1 and call_status='Draft'",[p.id])).rows.length);
if(process.env.LOON_SNAPSHOT){const snapshot={};for(const table of ['productions','calendar_events','venues','people','production_credits','rehearsal_calls','rehearsal_call_cast'])snapshot[table]=(await db.query('select * from '+table)).rows;
for(const p of snapshot.productions){for(const key of ['opening_date','closing_date','rehearsal_start'])if(p[key] instanceof Date)p[key]=p[key].toISOString().slice(0,10);p.venues=(await db.query('select name from venues where id=$1',[p.venue_id])).rows[0];p.seasons=(await db.query('select name from seasons where id=$1',[p.season_id])).rows[0];p.scripts=(await db.query('select musical,composer from scripts where id=$1',[p.script_id])).rows[0];}await writeFile(process.env.LOON_SNAPSHOT,JSON.stringify(snapshot));}
const after={people:await count('people'),credits:await count('production_credits'),events:await count('calendar_events')};await db.exec(seed);assert.deepEqual({people:await count('people'),credits:await count('production_credits'),events:await count('calendar_events')},after);
assert.equal(after.events-before.events,d.events.length);
// A missing shared profile aborts without creating a partial musical import.
await db.exec(`delete from rehearsal_call_cast where production_id='${p.id}';delete from rehearsal_calls where production_id='${p.id}';delete from calendar_events where production_id='${p.id}';delete from production_credits where production_id='${p.id}';delete from productions where id='${p.id}';delete from personnel_seasons;delete from people where source_key like 'les-mis-demo:%';update people set display_name='Changed profile' where source_key='test-theater-data:people:row-29';`);
await assert.rejects(()=>db.exec(seed),/Missing or changed shared demo profile/);await db.exec('rollback');
assert.equal((await db.query("select count(*)::int n from productions where title='Les Misérables'")).rows[0].n,0);
assert.equal((await db.query("select count(*)::int n from people where source_key like 'les-mis-demo:%'")).rows[0].n,0);
console.log('PASS: musical flag, 73 people / 35 cast, 20 reused profiles unchanged, 22 three-hour performances, season membership, covers, draft/canceled calls, collision-free parallel calls, repeat import and atomic failure.');await db.close();
