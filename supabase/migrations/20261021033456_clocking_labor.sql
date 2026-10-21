-- Labor details remain private. Public RPC wrappers never inherit owner privileges.
create table private.clock_entries (
 id uuid primary key, theater_id uuid not null references public.theaters(id),
 person_id uuid not null, production_id uuid not null,
 work_date date not null, started_at timestamptz not null, ended_at timestamptz not null,
 break_minutes integer not null default 0 check(break_minutes>=0),
 minutes numeric generated always as ((extract(epoch from (ended_at-started_at))/60)-break_minutes) stored,
 department text not null check(length(trim(department)) between 1 and 120),
 role text not null check(length(trim(role)) between 1 and 200), notes text not null default '' check(length(notes)<=10000),
 revision integer not null default 1, created_by uuid not null references auth.users(id),updated_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 foreign key(theater_id,person_id) references public.people(theater_id,id),
 foreign key(theater_id,production_id) references public.productions(theater_id,id),
 check(ended_at>started_at and ended_at<=started_at+interval '24 hours'),check(minutes>0)
);
alter table private.clock_entries enable row level security;
revoke all on private.clock_entries from public,anon,authenticated;
create index clock_entries_person_time on private.clock_entries(person_id,started_at,ended_at);
create index clock_entries_theater_date on private.clock_entries(theater_id,work_date);
create function private.clock_access(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.verified_user() and (
 private.has_thanos() or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and (
 exists(select 1 from unnest(m.roles) r where r not in ('Cast','Guest')) or
 exists(select 1 from public.people p where p.theater_id=t and p.id=m.person_id and (p.intern or p.person_types && array['Creative','Staff','Crew'])))));
$$;
create function private.clock_manager(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.clock_access(t) and (private.has_thanos() or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.roles && array['Super Admin','Company Manager','Production Manager','Production','Stage Manager','Assistant Stage Manager']));
$$;
create function private.clock_target(t uuid,p uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.clock_access(t) and exists(select 1 from public.people x where x.theater_id=t and x.id=p and (x.intern or x.person_types && array['Creative','Staff','Crew'])) and
 (private.clock_manager(t) or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.person_id=p));
$$;
create function private.clock_production(t uuid,p uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.clock_access(t) and exists(select 1 from public.productions x where x.theater_id=t and x.id=p) and
 (private.has_thanos() or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and
 (exists(select 1 from unnest(m.roles) r where r not in ('Cast','Guest','Director')) or p=any(m.production_ids))));
$$;
create function private.get_clocking_context(t uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then return jsonb_build_object('allowed',false,'manager',false,'people','[]'::jsonb,'productions','[]'::jsonb,'read_only',private.is_read_only(),'person_id',null);end if;
 return jsonb_build_object('allowed',true,'manager',private.clock_manager(t),'read_only',private.is_read_only(),
 'person_id',(select person_id from private.workspace_members where theater_id=t and user_id=auth.uid() and active),
 'people',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'display_name',display_name,'job_title',job_title,'departments',departments,'intern',intern) order by display_name),'[]'::jsonb) from public.people where theater_id=t and private.clock_target(t,id)),
 'productions',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title) order by title),'[]'::jsonb) from public.productions where theater_id=t and private.clock_production(t,id)));
end $$;
create function private.get_clock_entries(t uuid,from_date date,to_date date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 if from_date is null or to_date is null or to_date<from_date then raise exception 'Choose a valid date range';end if;
 return (select coalesce(jsonb_agg(to_jsonb(e) order by work_date desc,started_at desc),'[]'::jsonb) from private.clock_entries e where theater_id=t and work_date between from_date and to_date and (private.clock_manager(t) or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.person_id=e.person_id)) and private.clock_production(t,e.production_id));
end $$;
create function private.save_clock_entry(t uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.clock_entries%rowtype; prior private.clock_entries%rowtype; tz text;
begin
 if private.is_read_only() or not private.clock_access(t) then raise exception 'Clocking write access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' or expected is null or expected<0 then raise exception 'Supply an entry and its revision';end if;
 e.id:=(draft->>'id')::uuid;e.theater_id:=t;e.person_id:=(draft->>'person_id')::uuid;e.production_id:=(draft->>'production_id')::uuid;
 if not private.clock_target(t,e.person_id) or not private.clock_production(t,e.production_id) then raise exception 'Choose eligible personnel and an accessible production' using errcode='42501';end if;
 e.work_date:=(draft->>'work_date')::date;e.started_at:=(draft->>'started_at')::timestamptz;e.ended_at:=(draft->>'ended_at')::timestamptz;e.break_minutes:=(draft->>'break_minutes')::integer;
 e.department:=trim(draft->>'department');e.role:=trim(draft->>'role');e.notes:=trim(coalesce(draft->>'notes',''));
 select timezone into tz from public.theaters where id=t;
 if e.work_date is null or e.started_at is null or e.ended_at is null or e.break_minutes is null or e.id is null or e.department is null or e.role is null then raise exception 'Complete all required fields';end if;
 if (e.started_at at time zone tz)::date<>e.work_date then raise exception 'Start time must fall on the work date';end if;
 if e.ended_at>now() then raise exception 'Only completed work can be submitted';end if;
 -- Serialize per person across productions. Edits cannot change ownership.
 perform pg_advisory_xact_lock(hashtextextended(e.id::text,90));
 perform pg_advisory_xact_lock(hashtextextended(e.person_id::text,91));
 select * into prior from private.clock_entries where id=e.id for update;
 if prior.id is not null and (prior.theater_id<>t or prior.person_id<>e.person_id) then raise exception 'Entry ownership cannot change' using errcode='42501';end if;
 if coalesce(prior.revision,0)<>expected then raise exception 'This entry changed. Refresh and try again.';end if;
 if exists(select 1 from private.clock_entries x where x.person_id=e.person_id and x.id<>e.id and x.started_at<e.ended_at and x.ended_at>e.started_at) then raise exception 'This time overlaps another entry for this person';end if;
 insert into private.clock_entries(id,theater_id,person_id,production_id,work_date,started_at,ended_at,break_minutes,department,role,notes,created_by,updated_by)
 values(e.id,t,e.person_id,e.production_id,e.work_date,e.started_at,e.ended_at,e.break_minutes,e.department,e.role,e.notes,auth.uid(),auth.uid())
 on conflict(id) do update set production_id=excluded.production_id,work_date=excluded.work_date,started_at=excluded.started_at,ended_at=excluded.ended_at,break_minutes=excluded.break_minutes,department=excluded.department,role=excluded.role,notes=excluded.notes,revision=private.clock_entries.revision+1,updated_at=now(),updated_by=auth.uid()
 returning * into e;
 return to_jsonb(e);
end $$;
-- Aggregate only; other people's notes and individual shift details are never returned.
create function private.get_production_labor(t uuid,from_date date,to_date date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 if from_date is null or to_date is null or to_date<from_date then raise exception 'Choose a valid date range';end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by personnel,production,department,role),'[]'::jsonb) from (
 select e.person_id,p.display_name personnel,e.production_id,s.title production,e.department,e.role,sum(e.minutes) minutes
 from private.clock_entries e join public.people p on p.id=e.person_id join public.productions s on s.id=e.production_id
 where e.theater_id=t and e.work_date between from_date and to_date and private.clock_production(t,e.production_id)
 group by e.person_id,p.display_name,e.production_id,s.title,e.department,e.role) x);
end $$;
revoke all on function private.clock_access(uuid),private.clock_manager(uuid),private.clock_target(uuid,uuid),private.clock_production(uuid,uuid) from public,anon,authenticated;
revoke all on function private.get_clocking_context(uuid),private.get_clock_entries(uuid,date,date),private.save_clock_entry(uuid,jsonb,integer),private.get_production_labor(uuid,date,date) from public,anon;
grant execute on function private.get_clocking_context(uuid),private.get_clock_entries(uuid,date,date),private.save_clock_entry(uuid,jsonb,integer),private.get_production_labor(uuid,date,date) to authenticated;
create function public.get_clocking_context(t uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_clocking_context(t)$$;
create function public.get_clock_entries(t uuid,from_date date,to_date date) returns jsonb language sql security invoker set search_path='' as $$select private.get_clock_entries(t,from_date,to_date)$$;
create function public.save_clock_entry(t uuid,draft jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_clock_entry(t,draft,expected)$$;
create function public.get_production_labor(t uuid,from_date date,to_date date) returns jsonb language sql security invoker set search_path='' as $$select private.get_production_labor(t,from_date,to_date)$$;
revoke all on function public.get_clocking_context(uuid),public.get_clock_entries(uuid,date,date),public.save_clock_entry(uuid,jsonb,integer),public.get_production_labor(uuid,date,date) from public,anon;
grant execute on function public.get_clocking_context(uuid),public.get_clock_entries(uuid,date,date),public.save_clock_entry(uuid,jsonb,integer),public.get_production_labor(uuid,date,date) to authenticated;
