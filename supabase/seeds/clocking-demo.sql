-- Forty completed, system-generated sample shifts, October 16–20, 2026.
-- Only existing fictional demo personnel and demo productions are used.
-- Repeat execution cannot duplicate entries or overwrite staff time.
with roster(source_key,department,idx) as (values
 ('les-mis-demo:alex-morgan','Stage Management',0),
 ('les-mis-demo:quinn-brooks','Stage Management',1),
 ('les-mis-demo:emery-blake','Scenic',2),
 ('les-mis-demo:riley-shaw','Audio',3),
 ('les-mis-demo:dakota-lee','Costuming',4),
 ('les-mis-demo:jules-avery','Lighting',5),
 ('les-mis-demo:morgan-vale','Video',6),
 ('les-mis-demo:jordan-price','Props',7)
), shows as (
 select id,theater_id,row_number() over(partition by theater_id order by title)-1 idx
 from public.productions where is_demo and title in ('Titus Andronicus','Romeo and Juliet','Les Misérables')
), shifts as (
 select md5('clocking-demo-v1|'||p.id::text||'|'||d::text)::uuid id,p.theater_id,p.id person_id,s.id production_id,
 date '2026-10-16'+d work_date,
 ((date '2026-10-16'+d)+make_time(9+(r.idx%3),0,0)) at time zone t.timezone started_at,
 make_interval(mins=>120+30*((r.idx+d)%7)) duration,r.department,p.job_title role
 from roster r join public.people p on p.source_key=r.source_key and p.is_demo and p.person_types && array['Creative','Staff','Crew']
 join public.theaters t on t.id=p.theater_id cross join generate_series(0,4) d
 join shows s on s.theater_id=p.theater_id and s.idx=(r.idx+d)%3
)
insert into private.clock_entries(id,theater_id,person_id,production_id,work_date,started_at,ended_at,break_minutes,department,role,notes,created_by,updated_by,is_demo)
select x.id,x.theater_id,x.person_id,x.production_id,x.work_date,x.started_at,x.started_at+x.duration,0,x.department,x.role,
 'DEMO HOURS · System-generated sample for the labor dashboard. Not actual time worked. Seed: clocking-demo-v1.',null,null,true
from shifts x where not exists(select 1 from private.clock_entries e where e.person_id=x.person_id and e.id<>x.id and (e.ended_at is null or (e.started_at<x.started_at+x.duration and e.ended_at>x.started_at)))
on conflict(id) do nothing;
