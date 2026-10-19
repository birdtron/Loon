-- Rehearsal calls share calendar events so the calendar and callboard cannot drift.
alter table public.calendar_events add constraint calendar_events_call_identity unique(theater_id,production_id,id);
create table public.rehearsal_calls (
 event_id uuid primary key, theater_id uuid not null, production_id uuid not null,
 work text not null check(length(trim(work)) between 1 and 500),
 act text not null default '' check(length(act)<=40), scene text not null default '' check(length(scene)<=80),
 location text not null default '' check(length(location)<=300),
 foreign key(theater_id,production_id,event_id) references public.calendar_events(theater_id,production_id,id) on delete cascade,
 unique(theater_id,production_id,event_id)
);
create table public.rehearsal_call_cast (
 event_id uuid not null, person_id uuid not null, theater_id uuid not null, production_id uuid not null,
 primary key(event_id,person_id),
 foreign key(theater_id,production_id,event_id) references public.rehearsal_calls(theater_id,production_id,event_id) on delete cascade,
 foreign key(theater_id,person_id) references public.people(theater_id,id)
);
create index rehearsal_call_cast_person_idx on public.rehearsal_call_cast(theater_id,person_id);
create index rehearsal_calls_production_idx on public.rehearsal_calls(production_id);
alter table public.rehearsal_calls enable row level security;
alter table public.rehearsal_call_cast enable row level security;
revoke all on public.rehearsal_calls,public.rehearsal_call_cast from anon;
grant select,insert,update,delete on public.rehearsal_calls,public.rehearsal_call_cast to authenticated;
create policy thanos_all on public.rehearsal_calls for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create policy thanos_all on public.rehearsal_call_cast for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create function private.validate_rehearsal_call() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.calendar_events e where e.id=new.event_id and e.theater_id=new.theater_id and e.production_id=new.production_id and e.category='Rehearsal') then raise exception 'A cast call must belong to a rehearsal'; end if;
 if TG_TABLE_NAME='rehearsal_call_cast' then
  if not exists(select 1 from public.production_credits c where c.theater_id=new.theater_id and c.production_id=new.production_id and c.person_id=new.person_id and c.credit_type='Cast') then raise exception 'Selected person is not cast in this production';end if;
 end if;
 return new;
end $$;
revoke all on function private.validate_rehearsal_call() from public,anon,authenticated;
create trigger validate_rehearsal_call before insert or update on public.rehearsal_calls for each row execute function private.validate_rehearsal_call();
create trigger validate_rehearsal_call before insert or update on public.rehearsal_call_cast for each row execute function private.validate_rehearsal_call();
create function private.guard_cast_call_category() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.category<>'Rehearsal' and exists(select 1 from public.rehearsal_calls where event_id=old.id) then raise exception 'Edit this rehearsal through Cast Scheduling';end if;
 return new;
end $$;
revoke all on function private.guard_cast_call_category() from public,anon,authenticated;
create trigger guard_cast_call_category before update on public.calendar_events for each row execute function private.guard_cast_call_category();

create function public.save_rehearsal_call(draft jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 call_id uuid:=(draft->>'id')::uuid; production uuid:=(draft->>'production_id')::uuid;
 p public.productions%rowtype; e public.calendar_events%rowtype; prior public.calendar_events%rowtype;
 member uuid; members uuid[]; expected timestamptz:=(draft->>'expected_updated_at')::timestamptz;
 work_label text:=trim(draft->>'work'); state text:=draft->>'call_status'; begin_at timestamptz:=(draft->>'start')::timestamptz; end_at timestamptz:=(draft->>'end')::timestamptz; venue uuid:=(draft->>'venue_id')::uuid;
begin
 if not private.has_thanos() then raise exception 'Owner access required' using errcode='42501';end if;
 if call_id is null or production is null or begin_at is null or end_at is null or end_at<=begin_at then raise exception 'Enter a valid rehearsal time range';end if;
 if state is null or state not in ('Published','Canceled') then raise exception 'Invalid call state';end if;
 if work_label is null or length(work_label) not between 1 and 500 then raise exception 'Enter what will be rehearsed';end if;
 if venue is null and length(trim(coalesce(draft->>'location','')))=0 then raise exception 'Choose a venue or enter a rehearsal location';end if;
 select * into p from public.productions where id=production;
 if not found then raise exception 'Production not found';end if;
 select array_agg(distinct value::uuid order by value::uuid) into members from jsonb_array_elements_text(draft->'person_ids');
 if coalesce(cardinality(members),0)=0 then raise exception 'Select at least one cast member';end if;
 foreach member in array members loop
  if not exists(select 1 from public.production_credits where theater_id=p.theater_id and production_id=p.id and person_id=member and credit_type='Cast') then raise exception 'Selected person is not cast in this production';end if;
 end loop;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(call_id::text,0));
 if state='Published' then
  foreach member in array members loop
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(member::text,1));
   if exists(select 1 from public.rehearsal_call_cast c join public.calendar_events ce on ce.id=c.event_id where c.person_id=member and ce.id<>call_id and ce.call_status='Published' and ce.start<end_at and ce."end">begin_at) then raise exception 'A selected cast member already has a rehearsal call at this time';end if;
  end loop;
 end if;
 select * into prior from public.calendar_events where id=call_id for update;
 if found then
  if prior.production_id<>production or prior.category<>'Rehearsal' or not exists(select 1 from public.rehearsal_calls where event_id=call_id) then raise exception 'Rehearsal call does not match';end if;
  if expected is null then
   if prior.created_by is distinct from auth.uid() then raise exception 'Call already exists';end if;
   e:=prior; -- A retry of a completed create returns the same call, never a duplicate.
  else
   if prior.updated_at<>expected then raise exception 'This call changed. Refresh before editing again.';end if;
   update public.calendar_events set title=work_label,start=begin_at,"end"=end_at,venue_id=venue,event_details=coalesce(draft->>'notes',''),call_status=state where id=call_id returning * into e;
  end if;
 elsif expected is not null then raise exception 'This call no longer exists. Refresh before editing again.';
 else
  insert into public.calendar_events(id,theater_id,production_id,venue_id,title,category,start,"end",event_details,call_status,is_demo)
   values(call_id,p.theater_id,p.id,venue,work_label,'Rehearsal',begin_at,end_at,coalesce(draft->>'notes',''),state,false) returning * into e;
 end if;
 if prior.id is null or expected is not null then
  insert into public.rehearsal_calls(event_id,theater_id,production_id,work,act,scene,location)
   values(e.id,p.theater_id,p.id,work_label,trim(coalesce(draft->>'act','')),trim(coalesce(draft->>'scene','')),trim(coalesce(draft->>'location','')))
   on conflict(event_id) do update set work=excluded.work,act=excluded.act,scene=excluded.scene,location=excluded.location;
  delete from public.rehearsal_call_cast where event_id=e.id;
  insert into public.rehearsal_call_cast(event_id,person_id,theater_id,production_id) select e.id,unnest(members),p.theater_id,p.id;
 end if;
 return jsonb_build_object('event',to_jsonb(e),'call',(select to_jsonb(c) from public.rehearsal_calls c where event_id=e.id),'cast',(select coalesce(jsonb_agg(c),'[]') from public.rehearsal_call_cast c where event_id=e.id));
end $$;
revoke all on function public.save_rehearsal_call(jsonb) from public,anon;
grant execute on function public.save_rehearsal_call(jsonb) to authenticated;
