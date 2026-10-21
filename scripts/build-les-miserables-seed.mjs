import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const root=new URL('../',import.meta.url);
const d=JSON.parse(readFileSync(new URL('docs/test-shows/les-miserables.json',root)));
const q=x=>"'"+String(x).replaceAll("'","''")+"'";
const arr=xs=>'array['+xs.map(q).join(',')+']::text[]';
const uuid=key=>{const h=createHash('sha256').update(key).digest('hex');return `${h.slice(0,8)}-${h.slice(8,12)}-4${h.slice(13,16)}-a${h.slice(17,20)}-${h.slice(20,32)}`};
const sql=[`-- REVIEW ONLY: explicit data import, never run by application builds or schema migrations.
-- Fictional test company. No emails, invitations, auth users, grants, or policy changes.
begin;
do $seed$
declare t uuid; s uuid; v uuid; p uuid; sc uuid; person uuid; ev uuid;
begin
 select id into strict t from public.theaters where slug=${q(d.theater)};
 select id into strict s from public.seasons where theater_id=t and name=${q(d.season)};
 select id into strict v from public.venues where theater_id=t and name=${q(d.venue)};
 if exists(select 1 from public.productions where theater_id=t and title=${q(d.title)} and season_id=s and (not is_demo or import_metadata->>'test_seed' is distinct from 'les-mis-demo-v1')) then raise exception 'Refusing to replace an existing production';end if;
 if exists(select 1 from public.productions where theater_id=t and title=${q(d.title)} and season_id=s and import_metadata->>'test_seed'='les-mis-demo-v1') then return;end if;
`];
for(const x of d.people.filter(x=>x.reuse))sql.push(` if not exists(select 1 from public.people where theater_id=t and source_key=${q(x.source_key)} and display_name=${q(x.name)} and is_demo) then raise exception 'Missing or changed shared demo profile: ${x.name.replaceAll("'","''")}';end if;`);
sql.push(` if exists(select 1 from public.people where theater_id=t and source_key like 'les-mis-demo:%') then raise exception 'Unexpected partial test import; review before continuing';end if;
 if exists(select 1 from public.scripts where theater_id=t and title=${q(d.title)} and (not musical or composer is distinct from 'Claude-Michel Schönberg')) then raise exception 'Conflicting musical script';end if;
 insert into public.scripts(theater_id,title,playwright,musical,composer) values(t,${q(d.title)},'Alain Boublil and Claude-Michel Schönberg; English lyrics by Herbert Kretzmer',true,'Claude-Michel Schönberg') on conflict(theater_id,title) do nothing;
 select id into strict sc from public.scripts where theater_id=t and title=${q(d.title)};
 insert into public.productions(theater_id,title,season_id,script_id,venue_id,series,full_description,rating,content_warnings,runtime,runtime_minutes,opening_date,closing_date,rehearsal_start,is_aea,aea_tier,publish,is_demo,import_metadata)
 values(t,${q(d.title)},s,sc,v,'Musical / Test Production','FICTIONAL TEST PRODUCTION — A sung-through musical set in nineteenth-century France. Demo cast, crew, dates and agreement values are invented for Loon testing; no real engagement or announced theater production is implied.','Recommended ages 12+',array['Violence','Gunshot effects','Death','Suicide themes','Sexual references','Haze'],'3 hours, including one 20-minute intermission',180,${q(d.opening)},${q(d.closing)},${q(d.rehearsal_start)},true,'Tier 2',false,true,${q(JSON.stringify({test_seed:'les-mis-demo-v1',script_musical:true,script_composer:'Claude-Michel Schönberg',hero_image_url:d.poster,production_status:'Test / Announced',cover_assignments:d.people.filter(x=>x.covers.length).map(x=>({source_key:x.source_key,roles:x.covers})),voice_parts:d.people.filter(x=>x.voice).map(x=>({source_key:x.source_key,voice:x.voice}))}))}::jsonb) returning id into p;`);
for(const [i,x] of d.people.entries()){
 if(!x.reuse)sql.push(` insert into public.people(theater_id,source_key,display_name,first_name,last_name,person_types,job_title,departments,bio,is_demo) values(t,${q(x.source_key)},${q(x.name)},${q(x.name.split(' ')[0])},${q(x.name.split(' ').slice(1).join(' '))},${arr([x.type])},${q(x.type==='Cast'?'':x.role)},${arr([x.group==='Orchestra'?'Music':x.type==='Cast'?'Performance':x.type==='Creative'?'Creative':'Production'])},${q('FICTIONAL TEST PROFILE — Invented for the Les Misérables test production. '+x.role+(x.voice?'; test voice part: '+x.voice:'')+'.')},true);`);
 sql.push(` select id into strict person from public.people where theater_id=t and source_key=${q(x.source_key)};
 insert into public.production_credits(theater_id,production_id,person_id,role,credit_type,billing_order) values(t,p,person,${q(x.role)},${q(x.type)},${i+1});`);
 for(const cover of x.covers)sql.push(` insert into public.production_credits(theater_id,production_id,person_id,role,credit_type,billing_order) values(t,p,person,${q('Understudy: '+cover)},'Cast',${i+1});`);
}
// Live intake schema has season membership; older local schemas do not. No schema mutation.
sql.push(` if to_regclass('public.personnel_seasons') is not null then
 execute 'insert into public.personnel_seasons(theater_id,person_id,season_id) select distinct c.theater_id,c.person_id,$1 from public.production_credits c where c.production_id=$2 on conflict do nothing' using s,p;
 end if;`);
for(const e of d.events){
 sql.push(` select id into strict v from public.venues where theater_id=t and name=${q(e.venue||d.venue)};
 ev:=${q(uuid(e.key))};
 insert into public.calendar_events(id,theater_id,production_id,venue_id,title,category,start,"end",accessibility,is_special_event,event_details,call_status,is_demo) values(ev,t,p,v,${q(e.title)},${q(e.category)},${q(e.start)},${q(e.end)},${arr(e.accessibility)},${e.title==='Opening night'||e.title==='Closing performance'},${q(e.notes)},${q(e.state)},true);`);
 if(e.category==='Rehearsal'){
  sql.push(` insert into public.rehearsal_calls(event_id,theater_id,production_id,work,act,scene,location) values(ev,t,p,${q(e.title)},${q(e.act)},${q(e.scene)},${q(e.venue||d.venue)});`);
  for(const key of e.cast)sql.push(` insert into public.rehearsal_call_cast(event_id,person_id,theater_id,production_id) select ev,id,t,p from public.people where theater_id=t and source_key=${q(key)};`);
 }
}
sql.push(`end $seed$;
commit;
`);
writeFileSync(new URL('supabase/seeds/les-miserables-demo.sql',root),sql.join('\n'));
console.log('Generated review-only musical import.');
