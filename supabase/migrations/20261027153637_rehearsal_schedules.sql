-- Planned schedules live on calendar events, never in rehearsal_calls / rehearsal_call_cast.
alter table public.calendar_events
 add column rehearsal_schedule boolean not null default false,
 add column schedule_scene text not null default '',
 add column schedule_cast uuid[] not null default '{}',
 add constraint rehearsal_schedule_fields check (
  (rehearsal_schedule and category='Rehearsal' and venue_id is not null and length(schedule_scene)<=200 and cardinality(schedule_cast)<=500)
  or (not rehearsal_schedule and schedule_scene='' and cardinality(schedule_cast)=0));
create unique index rehearsal_schedule_duplicate on public.calendar_events
 (theater_id,production_id,venue_id,start,"end",lower(trim(title)))
 where rehearsal_schedule and call_status<>'Canceled';
create function private.validate_rehearsal_schedule() returns trigger language plpgsql security invoker set search_path='' as $$
declare member uuid;
begin
 if tg_op='UPDATE' and new.rehearsal_schedule is distinct from old.rehearsal_schedule then raise exception 'Calendar event source cannot be changed';end if;
 if new.rehearsal_schedule then
  if not private.workspace_permission(new.theater_id,'stage','edit',new.production_id) then raise exception 'Stage management edit access required' using errcode='42501';end if;
  if exists(select 1 from public.rehearsal_calls where event_id=new.id) then raise exception 'A callboard call cannot be a rehearsal schedule';end if;
  if not exists(select 1 from public.venues where id=new.venue_id and theater_id=new.theater_id) then raise exception 'Choose a venue in this account';end if;
  foreach member in array new.schedule_cast loop
   if member is null or not exists(select 1 from public.production_credits where theater_id=new.theater_id and production_id=new.production_id and person_id=member and credit_type='Cast') then raise exception 'Selected person is not cast in this show';end if;
  end loop;
 end if;
 return new;
end $$;
create trigger validate_rehearsal_schedule before insert or update on public.calendar_events for each row execute function private.validate_rehearsal_schedule();
create function private.prevent_schedule_callboard() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if exists(select 1 from public.calendar_events where id=new.event_id and rehearsal_schedule) then raise exception 'Rehearsal schedules cannot be published to the callboard';end if;
 return new;
end $$;
create trigger prevent_schedule_callboard before insert or update on public.rehearsal_calls for each row execute function private.prevent_schedule_callboard();
revoke all on function private.validate_rehearsal_schedule(),private.prevent_schedule_callboard() from public,anon,authenticated;

-- One transaction for a complete import; failed rows never leave a partial schedule.
create function public.save_rehearsal_schedule(drafts jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare d jsonb; p public.productions%rowtype; prior public.calendar_events%rowtype; saved public.calendar_events%rowtype;
 eid uuid; expected timestamptz; members uuid[]; result jsonb:='[]';
begin
 if auth.uid() is null or jsonb_typeof(drafts) is distinct from 'array' then raise exception 'A signed-in user and schedule rows are required';end if;
 if jsonb_array_length(drafts) not between 1 and 500 then raise exception 'Save between 1 and 500 schedule entries';end if;
 -- All imports are scoped to one show and serialized to make retry behavior predictable.
 if (select count(distinct value->>'production_id') from jsonb_array_elements(drafts))<>1 then raise exception 'Choose one show per import';end if;
 select * into p from public.productions where id=(drafts->0->>'production_id')::uuid;
 if not found or not private.workspace_permission(p.theater_id,'stage','edit',p.id) then raise exception 'Stage management edit access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p.id::text,65));
 for d in select value from jsonb_array_elements(drafts) loop
  eid:=(d->>'id')::uuid; expected:=(d->>'expected_updated_at')::timestamptz;
  if eid is null or (d->>'production_id')::uuid is distinct from p.id or length(trim(coalesce(d->>'title',''))) not between 1 and 200
   or d->>'start' is null or d->>'end' is null or (d->>'end')::timestamptz<=(d->>'start')::timestamptz
   or (d->>'venue_id')::uuid is null or coalesce(d->>'call_status','') not in ('Published','Canceled')
   or jsonb_typeof(d->'schedule_cast') is distinct from 'array' then raise exception 'Check event name, venue, times, status, and cast';end if;
  select coalesce(array_agg(distinct value::uuid),'{}') into members from jsonb_array_elements_text(d->'schedule_cast');
  select * into prior from public.calendar_events where id=eid for update;
  if found then
   if not prior.rehearsal_schedule or prior.production_id<>p.id then raise exception 'Schedule entry does not match';end if;
   if expected is null then
    if prior.created_by is distinct from auth.uid() or prior.title<>trim(d->>'title') or prior.start<>(d->>'start')::timestamptz or prior."end"<>(d->>'end')::timestamptz or prior.venue_id<>(d->>'venue_id')::uuid or prior.schedule_scene<>coalesce(d->>'schedule_scene','') or not(prior.schedule_cast @> members and prior.schedule_cast <@ members) or prior.call_status<>d->>'call_status' then raise exception 'Entry already exists. Refresh before editing.';end if;
    result:=result||jsonb_build_array(to_jsonb(prior));continue;
   end if;
   if prior.updated_at<>expected then raise exception 'This entry changed. Refresh before editing.';end if;
   update public.calendar_events set title=trim(d->>'title'),start=(d->>'start')::timestamptz,"end"=(d->>'end')::timestamptz,venue_id=(d->>'venue_id')::uuid,schedule_scene=coalesce(d->>'schedule_scene',''),schedule_cast=members,call_status=d->>'call_status' where id=eid returning * into saved;
  else
   if expected is not null then raise exception 'Entry no longer exists. Refresh before editing.';end if;
   insert into public.calendar_events(id,theater_id,production_id,venue_id,title,category,start,"end",call_status,is_demo,rehearsal_schedule,schedule_scene,schedule_cast)
    values(eid,p.theater_id,p.id,(d->>'venue_id')::uuid,trim(d->>'title'),'Rehearsal',(d->>'start')::timestamptz,(d->>'end')::timestamptz,d->>'call_status',false,true,coalesce(d->>'schedule_scene',''),members) returning * into saved;
  end if;
  result:=result||jsonb_build_array(to_jsonb(saved));
 end loop;
 return result;
end $$;
revoke all on function public.save_rehearsal_schedule(jsonb) from public,anon;
grant execute on function public.save_rehearsal_schedule(jsonb) to authenticated;

-- Planning and daily-call layers may describe the same room/time for one show.
-- Keep venue conflicts within each layer and between different shows.
create or replace function private.validate_performance()
returns trigger language plpgsql security invoker set search_path='' as $$
declare p public.productions%rowtype; tz text;
begin
 select * into p from public.productions where id=new.production_id and theater_id=new.theater_id;
 if not found then raise exception 'Production not found';end if;
 select timezone into tz from public.theaters where id=new.theater_id;
 if new.category='Performance' and (new.start at time zone tz)::date not between p.opening_date and p.closing_date then raise exception 'Performance must be within production dates';end if;
 if new.venue_id is not null and new.call_status<>'Canceled' then
  perform pg_advisory_xact_lock(hashtextextended(new.venue_id::text,0));
  if exists(select 1 from public.calendar_events e where e.venue_id=new.venue_id and e.id<>new.id and e.call_status<>'Canceled' and e.start<new."end" and e."end">new.start
   and not(e.production_id=new.production_id and e.category='Rehearsal' and new.category='Rehearsal' and e.rehearsal_schedule<>new.rehearsal_schedule)) then raise exception 'Another event overlaps in this venue';end if;
 end if;
 return new;
end $$;
revoke all on function private.validate_performance() from public,anon,authenticated;
