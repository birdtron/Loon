-- Clock punches use database time; users never supply timestamps or unpaid breaks.
alter table private.clock_entries alter column ended_at drop not null;
do $$ declare c record;begin
 for c in select conname from pg_constraint where conrelid='private.clock_entries'::regclass and contype='c' and pg_get_constraintdef(oid) like '%24:00:00%' loop
 execute format('alter table private.clock_entries drop constraint %I',c.conname);
 end loop;
end $$;
alter table private.clock_entries add constraint clock_end_after_start check(ended_at is null or ended_at>started_at);
create unique index clock_entries_one_open_per_person on private.clock_entries(person_id) where ended_at is null;
create policy no_direct_clock_access on private.clock_entries for all to authenticated using(false) with check(false);
-- Retain historical records, but retire browser access to manual time entry.
revoke all on function public.save_clock_entry(uuid,jsonb,integer),private.save_clock_entry(uuid,jsonb,integer) from authenticated;
create function private.clock_in(t uuid,draft jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.clock_entries%rowtype;prior private.clock_entries%rowtype;tz text;stamp timestamptz:=clock_timestamp();
begin
 if private.is_read_only() or not private.clock_access(t) then raise exception 'Clocking write access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' then raise exception 'Choose personnel and a production';end if;
 if exists(select 1 from jsonb_object_keys(draft) k where k<>all(array['id','person_id','production_id','department','role','notes'])) then raise exception 'Clock-in accepts no dates, times or break values';end if;
 e.id:=(draft->>'id')::uuid;e.person_id:=(draft->>'person_id')::uuid;e.production_id:=(draft->>'production_id')::uuid;
 if e.id is null or e.person_id is null or e.production_id is null or not private.clock_target(t,e.person_id) or not private.clock_production(t,e.production_id) then raise exception 'Choose eligible personnel and an accessible production' using errcode='42501';end if;
 e.department:=trim(draft->>'department');e.role:=trim(draft->>'role');e.notes:=trim(coalesce(draft->>'notes',''));
 if e.department is null or e.role is null then raise exception 'Enter a department and role';end if;
 perform pg_advisory_xact_lock(hashtextextended(e.id::text,90));
 perform pg_advisory_xact_lock(hashtextextended(e.person_id::text,91));
 select * into prior from private.clock_entries where id=e.id;
 if prior.id is not null then
  if prior.theater_id<>t or prior.person_id<>e.person_id or prior.production_id<>e.production_id then raise exception 'This clock-in identifier has already been used' using errcode='42501';end if;
  return to_jsonb(prior);
 end if;
 if exists(select 1 from private.clock_entries where person_id=e.person_id and ended_at is null) then raise exception 'Already clocked in. Clock out before starting another shift.';end if;
 -- Recheck database time after waiting for any concurrent punch.
 stamp:=clock_timestamp();
 if exists(select 1 from private.clock_entries where person_id=e.person_id and ended_at>stamp) then raise exception 'This time overlaps an existing entry';end if;
 select timezone into tz from public.theaters where id=t;
 insert into private.clock_entries(id,theater_id,person_id,production_id,work_date,started_at,ended_at,break_minutes,department,role,notes,created_by,updated_by)
 values(e.id,t,e.person_id,e.production_id,(stamp at time zone tz)::date,stamp,null,0,e.department,e.role,e.notes,auth.uid(),auth.uid()) returning * into e;
 return to_jsonb(e);
end $$;
create function private.clock_out(t uuid,entry uuid,notes text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare e private.clock_entries%rowtype;stamp timestamptz;
begin
 if private.is_read_only() or not private.clock_access(t) then raise exception 'Clocking write access required' using errcode='42501';end if;
 select * into e from private.clock_entries where id=entry and theater_id=t;
 if e.id is null or not private.clock_target(t,e.person_id) then raise exception 'No accessible clock-in found' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(e.id::text,90));
 perform pg_advisory_xact_lock(hashtextextended(e.person_id::text,91));
 select * into e from private.clock_entries where id=entry and theater_id=t for update;
 if e.ended_at is not null then return to_jsonb(e);end if;
 stamp:=clock_timestamp();
 update private.clock_entries set ended_at=stamp,notes=coalesce(trim(clock_out.notes),clock_entries.notes),revision=revision+1,updated_at=stamp,updated_by=auth.uid() where id=entry returning * into e;
 return to_jsonb(e);
end $$;
create function private.get_active_clock_entries(t uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(to_jsonb(e) order by started_at),'[]'::jsonb) from private.clock_entries e where e.theater_id=t and e.ended_at is null and private.clock_target(t,e.person_id));
end $$;
create or replace function private.get_clock_entries(t uuid,from_date date,to_date date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 if from_date is null or to_date is null or to_date<from_date then raise exception 'Choose a valid date range';end if;
 return (select coalesce(jsonb_agg(to_jsonb(e) order by work_date desc,started_at desc),'[]'::jsonb) from private.clock_entries e where theater_id=t and e.ended_at is not null and work_date between from_date and to_date and (private.clock_manager(t) or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.person_id=e.person_id)) and private.clock_production(t,e.production_id));
end $$;
create or replace function private.get_production_labor(t uuid,from_date date,to_date date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 if from_date is null or to_date is null or to_date<from_date then raise exception 'Choose a valid date range';end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by personnel,production,department,role),'[]'::jsonb) from (
 select e.person_id,p.display_name personnel,e.production_id,s.title production,e.department,e.role,sum(e.minutes) minutes
 from private.clock_entries e join public.people p on p.id=e.person_id join public.productions s on s.id=e.production_id
 where e.theater_id=t and e.ended_at is not null and e.work_date between from_date and to_date and private.clock_production(t,e.production_id)
 group by e.person_id,p.display_name,e.production_id,s.title,e.department,e.role) x);
end $$;
revoke all on function private.clock_in(uuid,jsonb),private.clock_out(uuid,uuid,text),private.get_active_clock_entries(uuid) from public,anon;
grant execute on function private.clock_in(uuid,jsonb),private.clock_out(uuid,uuid,text),private.get_active_clock_entries(uuid) to authenticated;
create function public.clock_in(t uuid,draft jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.clock_in(t,draft)$$;
create function public.clock_out(t uuid,entry uuid,notes text default null) returns jsonb language sql security invoker set search_path='' as $$select private.clock_out(t,entry,notes)$$;
create function public.get_active_clock_entries(t uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_active_clock_entries(t)$$;
revoke all on function public.clock_in(uuid,jsonb),public.clock_out(uuid,uuid,text),public.get_active_clock_entries(uuid) from public,anon;
grant execute on function public.clock_in(uuid,jsonb),public.clock_out(uuid,uuid,text),public.get_active_clock_entries(uuid) to authenticated;
