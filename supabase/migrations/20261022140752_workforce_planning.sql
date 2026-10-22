create table private.work_tasks(
 id uuid primary key,theater_id uuid not null references public.theaters(id),production_id uuid not null,
 title text not null check(length(trim(title)) between 1 and 200),department text not null check(length(trim(department)) between 1 and 120),description text not null default '' check(length(description)<=10000),
 status text not null default 'To Do' check(status in ('Backlog','To Do','In Progress','In Review','Complete')),
 priority text not null default 'Normal' check(priority in ('Low','Normal','High','Urgent')),show_critical boolean not null default false,
 estimated_minutes integer not null default 60 check(estimated_minutes between 0 and 60000),due_date date,work_dates date[] not null default '{}',assignee_ids uuid[] not null default '{}',assigned_on date not null default current_date,
 archived boolean not null default false,is_demo boolean not null default false,revision integer not null default 1,
 created_by uuid references auth.users(id),updated_by uuid references auth.users(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(theater_id,id),foreign key(theater_id,production_id) references public.productions(theater_id,id),check(is_demo or (created_by is not null and updated_by is not null)),check(cardinality(assignee_ids)<=50 and cardinality(work_dates)<=366)
);
create index work_tasks_theater_production on private.work_tasks(theater_id,production_id);
create index work_tasks_assignees on private.work_tasks using gin(assignee_ids);
create table private.work_schedules(
 id uuid primary key,theater_id uuid not null references public.theaters(id),person_id uuid not null,production_id uuid not null,task_id uuid,event_id uuid,
 category text not null check(category in ('Company','Show/Rehearsal')),title text not null check(length(trim(title)) between 1 and 200),starts_at timestamptz not null,ends_at timestamptz not null,
 revision integer not null default 1,is_demo boolean not null default false,archived boolean not null default false,updated_by uuid references auth.users(id),updated_at timestamptz not null default now(),
 foreign key(theater_id,person_id) references public.people(theater_id,id),foreign key(theater_id,production_id) references public.productions(theater_id,id),foreign key(theater_id,task_id) references private.work_tasks(theater_id,id),foreign key(theater_id,event_id) references public.calendar_events(theater_id,id),
 check(ends_at>starts_at and ends_at<=starts_at+interval '24 hours'),check(is_demo or updated_by is not null)
);
create index work_schedules_person_time on private.work_schedules(person_id,starts_at,ends_at);
create table private.work_capacities(
 theater_id uuid not null,person_id uuid not null,week_start date not null,minutes integer not null check(minutes between 0 and 10080),revision integer not null default 1,is_demo boolean not null default false,updated_by uuid references auth.users(id),
 primary key(theater_id,person_id,week_start),foreign key(theater_id,person_id) references public.people(theater_id,id),check(extract(isodow from week_start)=1),check(is_demo or updated_by is not null)
);
create table private.task_attachments(id uuid primary key default gen_random_uuid(),theater_id uuid not null,task_id uuid not null,name text not null check(length(name) between 1 and 200),path text not null unique,uploaded_by uuid not null references auth.users(id),created_at timestamptz not null default now(),foreign key(theater_id,task_id) references private.work_tasks(theater_id,id));
create table private.task_changes(id bigint generated always as identity primary key,theater_id uuid not null,task_id uuid not null,actor uuid not null references auth.users(id),from_status text,to_status text not null,changed_at timestamptz not null default now(),foreign key(theater_id,task_id) references private.work_tasks(theater_id,id));
do $$ declare tbl text;begin foreach tbl in array array['work_tasks','work_schedules','work_capacities','task_attachments','task_changes'] loop
 execute format('alter table private.%I enable row level security',tbl);execute format('revoke all on private.%I from public,anon,authenticated',tbl);execute format('create policy deny_direct on private.%I for all to authenticated using(false) with check(false)',tbl);
end loop;end $$;
alter table private.clock_entries add column task_id uuid;
alter table private.clock_entries add foreign key(theater_id,task_id) references private.work_tasks(theater_id,id);
create index clock_entries_task on private.clock_entries(task_id);
create function private.task_visible(t uuid,task uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.clock_access(t) and exists(select 1 from private.work_tasks w where w.id=task and w.theater_id=t and private.clock_production(t,w.production_id) and (private.clock_manager(t) or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.person_id=any(w.assignee_ids))));
$$;
revoke all on function private.task_visible(uuid,uuid) from public,anon,authenticated;
create function private.save_work_task(t uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare w private.work_tasks%rowtype;prior private.work_tasks%rowtype;p uuid;d date;tz text;
begin
 if private.is_read_only() or not private.clock_manager(t) then raise exception 'Production management access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' or expected is null or expected<0 then raise exception 'Supply a task and revision';end if;
 w.id:=(draft->>'id')::uuid;w.production_id:=(draft->>'production_id')::uuid;
 if w.id is null or not private.clock_production(t,w.production_id) then raise exception 'Choose an accessible production' using errcode='42501';end if;
 w.title:=trim(draft->>'title');w.department:=trim(draft->>'department');w.description:=trim(coalesce(draft->>'description',''));w.status:=coalesce(draft->>'status','To Do');w.priority:=coalesce(draft->>'priority','Normal');w.show_critical:=coalesce((draft->>'show_critical')::boolean,false);w.estimated_minutes:=coalesce((draft->>'estimated_minutes')::integer,60);w.due_date:=nullif(draft->>'due_date','')::date;w.archived:=coalesce((draft->>'archived')::boolean,false);
 select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into w.assignee_ids from jsonb_array_elements_text(coalesce(draft->'assignee_ids','[]'));
 select coalesce(array_agg(distinct value::date order by value::date),'{}'::date[]) into w.work_dates from jsonb_array_elements_text(coalesce(draft->'work_dates','[]'));
 foreach p in array w.assignee_ids loop if not exists(select 1 from public.people x where x.id=p and x.theater_id=t and (x.intern or x.person_types && array['Creative','Staff','Crew'])) then raise exception 'Choose eligible personnel from this theater';end if;end loop;
 perform pg_advisory_xact_lock(hashtextextended(w.id::text,101));select * into prior from private.work_tasks where id=w.id for update;
 if prior.id is not null and (prior.theater_id<>t or not private.task_visible(t,prior.id)) then raise exception 'Task is outside your workspace' using errcode='42501';end if;
 if coalesce(prior.revision,0)<>expected then raise exception 'This task changed. Refresh and reopen it.';end if;
 if prior.id is not null and (w.production_id<>prior.production_id or w.assignee_ids is distinct from prior.assignee_ids) and (exists(select 1 from private.clock_entries where task_id=w.id and ended_at is null) or exists(select 1 from private.work_schedules s where s.task_id=w.id and not s.archived and (s.production_id<>w.production_id or not s.person_id=any(w.assignee_ids)))) then raise exception 'Finish active clock-ins or update linked schedules before changing the task production or assignees';end if;
 select timezone into tz from public.theaters where id=t;
 insert into private.work_tasks(id,theater_id,production_id,title,department,description,status,priority,show_critical,estimated_minutes,due_date,work_dates,assignee_ids,assigned_on,archived,created_by,updated_by)
 values(w.id,t,w.production_id,w.title,w.department,w.description,w.status,w.priority,w.show_critical,w.estimated_minutes,w.due_date,w.work_dates,w.assignee_ids,(now() at time zone tz)::date,w.archived,auth.uid(),auth.uid())
 on conflict(id) do update set production_id=excluded.production_id,title=excluded.title,department=excluded.department,description=excluded.description,status=excluded.status,priority=excluded.priority,show_critical=excluded.show_critical,estimated_minutes=excluded.estimated_minutes,due_date=excluded.due_date,work_dates=excluded.work_dates,assignee_ids=excluded.assignee_ids,archived=excluded.archived,revision=private.work_tasks.revision+1,updated_by=auth.uid(),updated_at=now() returning * into w;
 insert into private.task_changes(theater_id,task_id,actor,from_status,to_status) values(t,w.id,auth.uid(),prior.status,w.status);
 return to_jsonb(w);
end $$;
create function private.set_work_task_status(t uuid,task uuid,status text,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare w private.work_tasks%rowtype;old_status text;
begin
 if private.is_read_only() or not private.task_visible(t,task) then raise exception 'Task update access required' using errcode='42501';end if;
 if status='Complete' and not private.clock_manager(t) then raise exception 'Production management completes the review';end if;
 select * into w from private.work_tasks where id=task and theater_id=t for update;
 if w.archived or expected is distinct from w.revision then raise exception 'This task changed. Refresh and reopen it.';end if;
 old_status:=w.status;update private.work_tasks set status=set_work_task_status.status,revision=revision+1,updated_at=now(),updated_by=auth.uid() where id=task returning * into w;
 insert into private.task_changes(theater_id,task_id,actor,from_status,to_status) values(t,task,auth.uid(),old_status,w.status);return to_jsonb(w);
end $$;
create function private.save_work_capacity(t uuid,person uuid,week_start date,minutes integer,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare result private.work_capacities%rowtype;
begin
 if private.is_read_only() or not private.clock_manager(t) or not private.clock_target(t,person) then raise exception 'Production management access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(person::text||week_start::text,102));select * into result from private.work_capacities c where c.theater_id=t and c.person_id=person and c.week_start=save_work_capacity.week_start;
 if coalesce(result.revision,0) is distinct from expected then raise exception 'Capacity changed. Refresh and try again.';end if;
 insert into private.work_capacities(theater_id,person_id,week_start,minutes,updated_by) values(t,person,week_start,minutes,auth.uid()) on conflict on constraint work_capacities_pkey do update set minutes=excluded.minutes,revision=private.work_capacities.revision+1,updated_by=auth.uid() returning * into result;return to_jsonb(result);
end $$;
create function private.save_work_schedule(t uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.work_schedules%rowtype;prior private.work_schedules%rowtype;e public.calendar_events%rowtype;
begin
 if private.is_read_only() or not private.clock_manager(t) then raise exception 'Production management access required' using errcode='42501';end if;
 s.id:=(draft->>'id')::uuid;s.person_id:=(draft->>'person_id')::uuid;s.production_id:=(draft->>'production_id')::uuid;s.task_id:=nullif(draft->>'task_id','')::uuid;s.event_id:=nullif(draft->>'event_id','')::uuid;s.title:=trim(draft->>'title');s.category:=draft->>'category';s.starts_at:=(draft->>'starts_at')::timestamptz;s.ends_at:=(draft->>'ends_at')::timestamptz;s.archived:=coalesce((draft->>'archived')::boolean,false);
 if s.id is null or not private.clock_target(t,s.person_id) or not private.clock_production(t,s.production_id) then raise exception 'Choose eligible personnel and an accessible production' using errcode='42501';end if;
 if s.event_id is not null then select * into e from public.calendar_events where id=s.event_id and theater_id=t and production_id=s.production_id and call_status<>'Canceled';if e.id is null then raise exception 'Choose an active calendar event from this production';end if;s.starts_at:=e.start;s.ends_at:=e."end";s.category:='Show/Rehearsal';end if;
 if s.task_id is not null and not exists(select 1 from private.work_tasks where id=s.task_id and theater_id=t and production_id=s.production_id and s.person_id=any(assignee_ids) and not archived) then raise exception 'Choose a task assigned to this person and production';end if;
 -- One person cannot be scheduled for overlapping work across productions.
 perform pg_advisory_xact_lock(hashtextextended(s.id::text,103));perform pg_advisory_xact_lock(hashtextextended(s.person_id::text,104));select * into prior from private.work_schedules where id=s.id for update;
 if prior.id is not null and (prior.theater_id<>t or prior.person_id<>s.person_id) then raise exception 'Schedule ownership cannot change';end if;
 if coalesce(prior.revision,0) is distinct from expected then raise exception 'This schedule changed. Refresh and reopen it.';end if;
 if not s.archived and exists(select 1 from private.work_schedules x left join public.calendar_events ce on ce.id=x.event_id where x.person_id=s.person_id and x.id<>s.id and not x.archived and (x.event_id is null or ce.call_status<>'Canceled') and coalesce(ce.start,x.starts_at)<s.ends_at and coalesce(ce."end",x.ends_at)>s.starts_at) then raise exception 'This person already has scheduled work during that time';end if;
 insert into private.work_schedules(id,theater_id,person_id,production_id,task_id,event_id,title,category,starts_at,ends_at,archived,updated_by) values(s.id,t,s.person_id,s.production_id,s.task_id,s.event_id,s.title,s.category,s.starts_at,s.ends_at,s.archived,auth.uid())
 on conflict(id) do update set production_id=excluded.production_id,task_id=excluded.task_id,event_id=excluded.event_id,title=excluded.title,category=excluded.category,starts_at=excluded.starts_at,ends_at=excluded.ends_at,archived=excluded.archived,revision=private.work_schedules.revision+1,updated_by=auth.uid(),updated_at=now() returning * into s;return to_jsonb(s);
end $$;
create function private.get_workforce(t uuid,week_start date) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;mgr boolean;tz text;tasks jsonb;schedules jsonb;
begin
 if not private.clock_access(t) then raise exception 'Labor workspace access required' using errcode='42501';end if;
 if week_start is null or extract(isodow from week_start)<>1 then raise exception 'Choose the Monday of a week';end if;
 mgr:=private.clock_manager(t);select person_id into own from private.workspace_members where theater_id=t and user_id=auth.uid() and active;select timezone into tz from public.theaters where id=t;
 select coalesce(jsonb_agg(to_jsonb(w)||jsonb_build_object('actual_minutes',(select coalesce(sum(minutes),0) from private.clock_entries ce where ce.task_id=w.id and ce.ended_at is not null)) order by w.due_date nulls last,w.title),'[]') into tasks from private.work_tasks w where w.theater_id=t and not w.archived and private.task_visible(t,w.id);
 select coalesce(jsonb_agg(to_jsonb(x) order by starts_at),'[]') into schedules from (select s.id,s.theater_id,s.person_id,s.production_id,s.task_id,s.event_id,s.title,s.category,coalesce(e.start,s.starts_at) starts_at,coalesce(e."end",s.ends_at) ends_at,s.revision,s.is_demo from private.work_schedules s left join public.calendar_events e on e.id=s.event_id where s.theater_id=t and not s.archived and (mgr or s.person_id=own) and private.clock_production(t,s.production_id) and (s.event_id is null or e.call_status<>'Canceled') and coalesce(e.start,s.starts_at)<((week_start+7)::timestamp at time zone tz) and coalesce(e."end",s.ends_at)>(week_start::timestamp at time zone tz)) x;
 return jsonb_build_object('manager',mgr,'read_only',private.is_read_only(),'person_id',own,'tasks',tasks,'schedules',schedules,
 'people',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'display_name',p.display_name,'job_title',p.job_title,'departments',p.departments,'intern',p.intern) order by p.display_name),'[]') from public.people p where p.theater_id=t and (p.intern or p.person_types && array['Creative','Staff','Crew']) and (mgr or p.id=own or exists(select 1 from private.work_tasks w where private.task_visible(t,w.id) and p.id=any(w.assignee_ids)))),
 'capacities',(select coalesce(jsonb_agg(to_jsonb(c)),'[]') from private.work_capacities c where c.theater_id=t and c.week_start=get_workforce.week_start and (mgr or c.person_id=own)),
 'actuals',(select coalesce(jsonb_agg(jsonb_build_object('person_id',person_id,'task_id',task_id,'work_date',work_date,'minutes',minutes,'is_demo',is_demo)),'[]') from private.clock_entries ce where ce.theater_id=t and ce.ended_at is not null and ce.work_date between week_start and week_start+6 and (mgr or ce.person_id=own) and private.clock_production(t,ce.production_id)),
 'attachments',(select coalesce(jsonb_agg(to_jsonb(a)-'uploaded_by'),'[]') from private.task_attachments a where a.theater_id=t and private.task_visible(t,a.task_id)));
end $$;
create function private.get_clock_tasks(t uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Labor workspace access required' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title,'production_id',production_id,'department',department,'assignee_ids',assignee_ids,'show_critical',show_critical) order by title),'[]') from private.work_tasks where theater_id=t and not archived and status<>'Complete' and private.task_visible(t,id));
end $$;
create function private.import_work_tasks(t uuid,items jsonb,batch_key text) returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb;n integer:=0;skipped integer:=0;position integer:=0;task uuid;
begin
 if private.is_read_only() or not private.clock_manager(t) then raise exception 'Production management access required' using errcode='42501';end if;
 if jsonb_typeof(items) is distinct from 'array' or jsonb_array_length(items) not between 1 and 100 or batch_key is null or batch_key !~ '^[a-f0-9]{64}$' then raise exception 'Supply a validated import of 1–100 tasks';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text||batch_key,105));
 for item in select value from jsonb_array_elements(items) loop position:=position+1;task:=md5(t::text||batch_key||position::text)::uuid;
 if exists(select 1 from private.work_tasks where id=task and theater_id=t) then skipped:=skipped+1;else perform private.save_work_task(t,item||jsonb_build_object('id',task),0);n:=n+1;end if;end loop;
 return jsonb_build_object('created',n,'skipped',skipped);
end $$;
-- Private storage access follows the task's production and assignee scope.
create function private.task_file_access(path text,write_access boolean default false) returns boolean language plpgsql stable security definer set search_path='' as $$
declare parts text[]:=string_to_array(path,'/');t uuid;task uuid;
begin
 if auth.uid() is null or array_length(parts,1)<>3 or parts[1] !~ '^[a-f0-9-]{36}$' or parts[2] !~ '^[a-f0-9-]{36}$' then return false;end if;
 begin t:=parts[1]::uuid;task:=parts[2]::uuid;exception when invalid_text_representation then return false;end;
 return private.task_visible(t,task) and (not write_access or not private.is_read_only());
end $$;
create function private.add_task_attachment(t uuid,task uuid,path text,name text) returns jsonb language plpgsql security definer set search_path='' as $$
declare a private.task_attachments%rowtype;
begin
 if private.is_read_only() or not private.task_visible(t,task) or not private.task_file_access(path,true) or split_part(path,'/',1)<>t::text or split_part(path,'/',2)<>task::text then raise exception 'Task attachment access required' using errcode='42501';end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='task-attachments' and o.name=add_task_attachment.path) then raise exception 'Upload the attachment first';end if;
 insert into private.task_attachments(theater_id,task_id,path,name,uploaded_by) values(t,task,path,name,auth.uid()) on conflict on constraint task_attachments_path_key do update set name=excluded.name returning * into a;return to_jsonb(a)-'uploaded_by';
end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('task-attachments','task-attachments',false,10485760,array['application/pdf','image/png','image/jpeg','image/webp','text/plain']) on conflict(id) do nothing;
revoke all on function private.task_file_access(text,boolean) from public,anon;grant execute on function private.task_file_access(text,boolean) to authenticated;
create policy task_file_read on storage.objects for select to authenticated using(bucket_id='task-attachments' and private.task_file_access(name,false));
create policy task_file_upload on storage.objects for insert to authenticated with check(bucket_id='task-attachments' and private.task_file_access(name,true));
create policy task_file_delete on storage.objects for delete to authenticated using(bucket_id='task-attachments' and private.task_file_access(name,true));
-- Public invoker wrappers; privilege checks live in the bounded private functions.
do $$ declare sig text;begin foreach sig in array array['save_work_task(uuid,jsonb,integer)','set_work_task_status(uuid,uuid,text,integer)','save_work_capacity(uuid,uuid,date,integer,integer)','save_work_schedule(uuid,jsonb,integer)','get_workforce(uuid,date)','get_clock_tasks(uuid)','import_work_tasks(uuid,jsonb,text)','add_task_attachment(uuid,uuid,text,text)'] loop execute 'revoke all on function private.'||sig||' from public,anon';execute 'grant execute on function private.'||sig||' to authenticated';end loop;end $$;
create function public.save_work_task(t uuid,draft jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_work_task(t,draft,expected)$$;
create function public.set_work_task_status(t uuid,task uuid,status text,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.set_work_task_status(t,task,status,expected)$$;
create function public.save_work_capacity(t uuid,person uuid,week_start date,minutes integer,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_work_capacity(t,person,week_start,minutes,expected)$$;
create function public.save_work_schedule(t uuid,draft jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_work_schedule(t,draft,expected)$$;
create function public.get_workforce(t uuid,week_start date) returns jsonb language sql security invoker set search_path='' as $$select private.get_workforce(t,week_start)$$;
create function public.get_clock_tasks(t uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_clock_tasks(t)$$;
create function public.import_work_tasks(t uuid,items jsonb,batch_key text) returns jsonb language sql security invoker set search_path='' as $$select private.import_work_tasks(t,items,batch_key)$$;
create function public.add_task_attachment(t uuid,task uuid,path text,name text) returns jsonb language sql security invoker set search_path='' as $$select private.add_task_attachment(t,task,path,name)$$;
do $$ declare sig text;begin foreach sig in array array['save_work_task(uuid,jsonb,integer)','set_work_task_status(uuid,uuid,text,integer)','save_work_capacity(uuid,uuid,date,integer,integer)','save_work_schedule(uuid,jsonb,integer)','get_workforce(uuid,date)','get_clock_tasks(uuid)','import_work_tasks(uuid,jsonb,text)','add_task_attachment(uuid,uuid,text,text)'] loop execute 'revoke all on function public.'||sig||' from public,anon';execute 'grant execute on function public.'||sig||' to authenticated';end loop;end $$;

create or replace function private.clock_in(t uuid,draft jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.clock_entries%rowtype;prior private.clock_entries%rowtype;tz text;stamp timestamptz:=clock_timestamp();
begin
 if private.is_read_only() or not private.clock_access(t) then raise exception 'Clocking write access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' then raise exception 'Choose personnel and a production';end if;
 if exists(select 1 from jsonb_object_keys(draft) k where k<>all(array['id','person_id','production_id','department','role','notes','task_id'])) then raise exception 'Clock-in accepts no dates, times or break values';end if;
 e.id:=(draft->>'id')::uuid;e.person_id:=(draft->>'person_id')::uuid;e.production_id:=(draft->>'production_id')::uuid;
 if e.id is null or e.person_id is null or e.production_id is null or not private.clock_target(t,e.person_id) or not private.clock_production(t,e.production_id) then raise exception 'Choose eligible personnel and an accessible production' using errcode='42501';end if;
 e.task_id:=nullif(draft->>'task_id','')::uuid;
 if e.task_id is not null then perform 1 from private.work_tasks where id=e.task_id for share;end if;
 if e.task_id is not null and not exists(select 1 from private.work_tasks w where w.id=e.task_id and w.theater_id=t and w.production_id=e.production_id and e.person_id=any(w.assignee_ids) and not w.archived and w.status<>'Complete' and private.task_visible(t,w.id)) then raise exception 'Choose an active task assigned to this person and production';end if;
 e.department:=trim(draft->>'department');e.role:=trim(draft->>'role');e.notes:=trim(coalesce(draft->>'notes',''));
 if e.department is null or e.role is null then raise exception 'Enter a department and role';end if;
 perform pg_advisory_xact_lock(hashtextextended(e.id::text,90));
 perform pg_advisory_xact_lock(hashtextextended(e.person_id::text,91));
 select * into prior from private.clock_entries where id=e.id;
 if prior.id is not null then
  if prior.theater_id<>t or prior.person_id<>e.person_id or prior.production_id<>e.production_id or prior.task_id is distinct from e.task_id then raise exception 'This clock-in identifier has already been used' using errcode='42501';end if;
  return to_jsonb(prior);
 end if;
 if exists(select 1 from private.clock_entries where person_id=e.person_id and ended_at is null) then raise exception 'Already clocked in. Clock out before starting another shift.';end if;
 -- Recheck database time after waiting for any concurrent punch.
 stamp:=clock_timestamp();
 if exists(select 1 from private.clock_entries where person_id=e.person_id and ended_at>stamp) then raise exception 'This time overlaps an existing entry';end if;
 select timezone into tz from public.theaters where id=t;
 insert into private.clock_entries(id,theater_id,person_id,production_id,work_date,started_at,ended_at,break_minutes,department,role,notes,task_id,created_by,updated_by)
 values(e.id,t,e.person_id,e.production_id,(stamp at time zone tz)::date,stamp,null,0,e.department,e.role,e.notes,e.task_id,auth.uid(),auth.uid()) returning * into e;
 return to_jsonb(e);
end $$;
