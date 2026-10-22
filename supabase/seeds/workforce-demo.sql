-- Fictional workforce examples for the week of October 19, 2026.
-- Deterministic IDs make this safe to run again. Only existing demo people/shows are used.
with examples(key,title,department,state,priority,critical,estimate,due,dates,person_keys,show_title) as (values
 ('scenic','Finish barricade platform','Scenic','In Progress','Urgent',true,720,'2026-10-23'::date,array['2026-10-19','2026-10-20','2026-10-22']::date[],array['emery-blake','alex-morgan'],'Les Misérables'),
 ('costume','Complete principal costume fittings','Costuming','To Do','High',true,480,'2026-10-23',array['2026-10-21','2026-10-22','2026-10-23']::date[],array['dakota-lee'],'Les Misérables'),
 ('audio','Test wireless microphone plot','Audio','In Review','High',true,300,'2026-10-21',array['2026-10-19','2026-10-20']::date[],array['riley-shaw'],'Les Misérables'),
 ('lighting','Refine balcony lighting cues','Lighting','In Progress','Normal',false,600,'2026-10-24',array['2026-10-20','2026-10-22','2026-10-23']::date[],array['jules-avery'],'Romeo and Juliet'),
 ('props','Source rehearsal props','Props','Backlog','Normal',false,240,'2026-10-28',array[]::date[],array['jordan-price'],'Titus Andronicus'),
 ('video','Approve projection transitions','Video','In Review','High',true,360,'2026-10-22',array['2026-10-20','2026-10-21']::date[],array['morgan-vale'],'Titus Andronicus'),
 ('calls','Publish next week’s rehearsal calls','Stage Management','To Do','High',false,180,'2026-10-23',array['2026-10-22','2026-10-23']::date[],array['alex-morgan','quinn-brooks'],'Les Misérables'),
 ('safety','Review scene-change safety notes','Stage Management','Complete','High',true,120,'2026-10-20',array['2026-10-19']::date[],array['alex-morgan'],'Romeo and Juliet'),
 ('paint','Prepare scenic paint samples','Scenic','Complete','Normal',false,240,'2026-10-20',array['2026-10-19','2026-10-20']::date[],array['emery-blake'],'Titus Andronicus'),
 ('sound','Organize sound library','Audio','Backlog','Low',false,180,null,array[]::date[],array['riley-shaw'],'Romeo and Juliet'),
 ('handoff','Prepare technical handoff packet','Stage Management','In Progress','Normal',false,420,'2026-10-23',array['2026-10-19','2026-10-21','2026-10-23']::date[],array['quinn-brooks'],'Titus Andronicus'),
 ('inventory','Reconcile wardrobe inventory','Costuming','To Do','Normal',false,240,'2026-10-20',array['2026-10-22']::date[],array['dakota-lee'],'Romeo and Juliet'),
 ('backup','Build backup cue checklist','Lighting','Backlog','Low',false,120,'2026-10-27',array['2026-10-26']::date[],array['jules-avery','morgan-vale'],'Les Misérables'),
 ('propscheck','Check fight-scene props','Props','In Progress','Urgent',true,360,'2026-10-23',array['2026-10-21','2026-10-22','2026-10-23']::date[],array['jordan-price'],'Titus Andronicus'),
 ('schedule','Confirm weekend crew coverage','Stage Management','To Do','Normal',false,120,'2026-10-23',array['2026-10-23']::date[],array['alex-morgan'],'Romeo and Juliet')
), resolved as (
 select e.*,s.id production_id,s.theater_id,array(select p.id from public.people p where p.theater_id=s.theater_id and p.is_demo and p.source_key=any(array(select 'les-mis-demo:'||k from unnest(e.person_keys) k)) and (p.intern or p.person_types && array['Creative','Staff','Crew'])) assignees
 from examples e join public.productions s on s.title=e.show_title and s.is_demo
)
insert into private.work_tasks(id,theater_id,production_id,title,department,description,status,priority,show_critical,estimated_minutes,due_date,work_dates,assignee_ids,assigned_on,is_demo)
select md5('workforce-demo-v1|'||theater_id||'|'||key)::uuid,theater_id,production_id,title,department,'DEMO · Fictional task for dashboard testing. Adjust the estimate, dates, assignees or status to try the workflow.',state,priority,critical,estimate,due,dates,assignees,'2026-10-19',true from resolved where cardinality(assignees)=cardinality(person_keys) on conflict(id) do nothing;
-- Forty company hours plus six evening rehearsal hours for Alex demonstrates overload.
with roster(key,idx,hours) as (values('alex-morgan',0,8),('quinn-brooks',1,6),('emery-blake',2,6),('riley-shaw',3,5),('dakota-lee',4,6),('jules-avery',5,5),('morgan-vale',6,4),('jordan-price',7,4)),shows as(select id,theater_id,row_number() over(partition by theater_id order by title)-1 idx from public.productions where is_demo and title in('Titus Andronicus','Romeo and Juliet','Les Misérables')),
blocks as(select p.id person_id,p.theater_id,s.id production_id,((date '2026-10-19'+d)+time '09:00') at time zone t.timezone starts_at,make_interval(hours=>r.hours) duration,d,'Company' category,'Company production work' title from roster r join public.people p on p.source_key='les-mis-demo:'||r.key and p.is_demo join public.theaters t on t.id=p.theater_id cross join generate_series(0,4) d join shows s on s.theater_id=p.theater_id and s.idx=r.idx%3
union all select p.id,p.theater_id,s.id,((date '2026-10-19'+d)+time '18:00') at time zone t.timezone,interval '3 hours',d,'Show/Rehearsal','Evening rehearsal support' from public.people p join public.theaters t on t.id=p.theater_id cross join unnest(array[1,3]) d join shows s on s.theater_id=p.theater_id and s.idx=0 where p.is_demo and p.source_key='les-mis-demo:alex-morgan')
insert into private.work_schedules(id,theater_id,person_id,production_id,category,title,starts_at,ends_at,is_demo)
select md5('workforce-schedule-demo-v1|'||person_id||'|'||d||'|'||category)::uuid,theater_id,person_id,production_id,category,title,starts_at,starts_at+duration,true from blocks on conflict(id) do nothing;
insert into private.work_capacities(theater_id,person_id,week_start,minutes,is_demo)
select theater_id,id,'2026-10-19',case when source_key='les-mis-demo:morgan-vale' then 1200 else 1920 end,true from public.people where is_demo and source_key in('les-mis-demo:quinn-brooks','les-mis-demo:morgan-vale') on conflict do nothing;
-- Connect existing fictional completed shifts only; preserve all hours and real entries.
update private.clock_entries ce set task_id=(select w.id from private.work_tasks w where w.is_demo and w.theater_id=ce.theater_id and w.production_id=ce.production_id and ce.person_id=any(w.assignee_ids) and w.department=ce.department order by w.id limit 1)
where ce.is_demo and ce.task_id is null and ce.notes like '%Seed: clocking-demo-v1.%';
