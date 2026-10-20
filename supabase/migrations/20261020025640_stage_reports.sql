-- Report records have separate access from the cast-facing callboard.
create function private.report_permission(t uuid,p uuid,a text default 'view') returns boolean language sql stable security definer set search_path='' as $$
 select private.workspace_admin(t) or (private.verified_user() and private.workspace_permission(t,'stage',a,p) and exists(
 select 1 from private.workspace_members u where u.theater_id=t and u.user_id=auth.uid() and u.active and
 (u.roles && array['Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming']
 or (u.roles && array['Guest','Director'] and p=any(u.production_ids))
 or (u.overrides->>'stage' in ('view','edit') and exists(select 1 from unnest(u.roles) r where r<>'Cast')))));
$$;
revoke all on function private.report_permission(uuid,uuid,text) from public,anon;
grant execute on function private.report_permission(uuid,uuid,text) to authenticated;
create table public.stage_reports(
 id uuid primary key,theater_id uuid not null,production_id uuid not null,
 kind text not null check(kind in ('Rehearsal','Performance')),report_date date not null,event_id uuid,
 data jsonb not null,cast_snapshot jsonb not null,source_calls uuid[] not null default '{}',fight_required boolean not null,
 revision integer not null default 1,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),created_by uuid not null,updated_by uuid not null,
 foreign key(theater_id,production_id) references public.productions(theater_id,id),
 foreign key(theater_id,production_id,event_id) references public.calendar_events(theater_id,production_id,id),
 check((kind='Performance' and event_id is not null) or (kind='Rehearsal' and event_id is null))
);
create unique index stage_report_rehearsal_day on public.stage_reports(production_id,report_date) where kind='Rehearsal';
create unique index stage_report_performance on public.stage_reports(event_id) where kind='Performance';
create index stage_reports_theater on public.stage_reports(theater_id,production_id,report_date);
alter table public.stage_reports enable row level security;
revoke all on public.stage_reports from anon,authenticated;
grant select on public.stage_reports to authenticated;
create policy report_read on public.stage_reports for select to authenticated using(private.report_permission(theater_id,production_id));
-- Bounded writer: all validation, cast sourcing, and optimistic revision checks are atomic.
create function private.save_stage_report(draft jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 r public.stage_reports%rowtype; old public.stage_reports%rowtype; p public.productions%rowtype;
 d jsonb:=draft->'data'; day date:=(draft->>'report_date')::date; kind text:=draft->>'kind';
 rid uuid:=(draft->>'id')::uuid; eid uuid:=(draft->>'event_id')::uuid; expected integer:=(draft->>'expected')::integer;
 tz text; starts timestamptz; ends timestamptz; house timestamptz; inter timestamptz; acttwo timestamptz;
 cancelled boolean; fight boolean; snapshot jsonb; source_ids uuid[]; additions uuid[]; person uuid; item record;
begin
 select * into p from public.productions where id=(draft->>'production_id')::uuid;
 if p.id is null or not private.report_permission(p.theater_id,p.id,'edit') then raise exception 'Report editing access required' using errcode='42501';end if;
 if rid is null or day is null or kind is null or kind not in ('Rehearsal','Performance') or jsonb_typeof(d) is distinct from 'object' then raise exception 'Invalid report';end if;
 if octet_length(d::text)>100000 then raise exception 'Report is too long';end if;
 select coalesce(data->'theater'->>'timezone','America/New_York') into tz from private.workspace_settings where theater_id=p.theater_id;
 tz:=coalesce(tz,'America/New_York');
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(rid::text,4));
 select * into old from public.stage_reports where id=rid for update;
 if old.id is not null then
  if old.production_id<>p.id or old.kind<>kind or old.report_date<>day or old.event_id is distinct from eid then raise exception 'Report identity cannot change';end if;
  if expected is null then
   if old.created_by=auth.uid() then return to_jsonb(old);end if;
   raise exception 'Report already exists';
  end if;
  if old.revision<>expected then raise exception 'This report changed. Refresh before editing again.';end if;
 elsif expected is not null then raise exception 'Report no longer exists';end if;
 if kind='Performance' then
  if not exists(select 1 from public.calendar_events where id=eid and production_id=p.id and category='Performance' and (start at time zone tz)::date=day) then raise exception 'Choose a performance on the report date';end if;
 elsif eid is not null then raise exception 'Rehearsal reports cover the daily callboard';end if;
 if jsonb_typeof(d->'cancelled') is distinct from 'boolean' or jsonb_typeof(d->'penalties') is distinct from 'boolean' or jsonb_typeof(d->'has_intermission') is distinct from 'boolean' then raise exception 'Answer the report questions';end if;
 cancelled:=(d->>'cancelled')::boolean;
 select exists(select 1 from public.production_credits where production_id=p.id and role ~* '(fight.*choreograph|choreograph.*fight)') into fight;
 fight:=coalesce(old.fight_required,fight);
 if length(trim(coalesce(d->>'summary','')))=0 then raise exception 'Enter a general summary';end if;
 if cancelled then
  if coalesce(d->>'cancel_reason','') not in ('Staffing','Technical','Facility','Other') or length(trim(coalesce(d->>'cancel_details','')))=0 then raise exception 'Choose a cancellation reason and add details';end if;
 else
  starts:=nullif(d->>'start','')::timestamptz;ends:=nullif(d->>'end','')::timestamptz;
  if starts is null or ends is null or ends<=starts or ends>starts+interval '24 hours' or (starts at time zone tz)::date<>day then raise exception 'Enter valid start and end times on the report date (up to 24 hours)';end if;
  if kind='Rehearsal' then
   if coalesce(d->>'breaks','') not in ('Yes','No') or (d->>'breaks'='No' and length(trim(coalesce(d->>'break_details','')))=0) then raise exception 'Record union breaks and explain any missed breaks';end if;
  else
   house:=nullif(d->>'house','')::timestamptz;
   if house is null or house>starts or house<starts-interval '24 hours' then raise exception 'Enter house open before performance start';end if;
   if (d->>'has_intermission')::boolean then
    inter:=nullif(d->>'intermission','')::timestamptz;acttwo:=nullif(d->>'act_two','')::timestamptz;
    if inter is null or acttwo is null or inter<starts or acttwo<=inter or acttwo>ends then raise exception 'Intermission and Act II times must be in performance order';end if;
   end if;
   if fight and (coalesce(d->>'fight','') not in ('Yes','No') or (d->>'fight'='No' and length(trim(coalesce(d->>'fight_details','')))=0)) then raise exception 'Record fight call and explain if it did not take place';end if;
  end if;
 end if;
 if kind='Performance' and (d->>'penalties')::boolean and (coalesce(d->>'penalty_reason','') not in ('Break intrusion','Schedule change < 24 hours','Matrix Overage','6th Day','7th Day','Media','Other') or length(trim(coalesce(d->>'penalty_details','')))=0) then raise exception 'Record penalty or overtime reason and details';end if;
 if jsonb_typeof(d->'departments') is distinct from 'object' then raise exception 'Invalid department notes';end if;
 for item in select * from jsonb_each(d->'departments') loop
  if item.key not in ('Scenic','Lighting','Audio','Costuming','Video','Props','SFX','Projection','Pyrotechnics','Cosmo','Conductor','Music') or jsonb_typeof(item.value)<>'string' then raise exception 'Invalid department notes';end if;
 end loop;
 if old.id is null or coalesce((draft->>'refresh_cast')::boolean,false) then
  select coalesce(array_agg(e.id),'{}') into source_ids from public.calendar_events e join public.rehearsal_calls c on c.event_id=e.id
   where e.production_id=p.id and e.call_status='Published' and (e.start at time zone tz)::date<=day and ((e."end"-interval '1 microsecond') at time zone tz)::date>=day;
  select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'name',x.display_name,'source','callboard') order by x.display_name),'[]') into snapshot from public.people x where exists(select 1 from public.rehearsal_call_cast c where c.person_id=x.id and c.event_id=any(source_ids));
 else
  source_ids:=old.source_calls;
  select coalesce(jsonb_agg(value),'[]') into snapshot from jsonb_array_elements(old.cast_snapshot) where value->>'source'='callboard';
 end if;
 select coalesce(array_agg(distinct value::uuid),'{}') into additions from jsonb_array_elements_text(coalesce(draft->'additional_cast','[]'));
 foreach person in array additions loop
  if not exists(select 1 from public.production_credits where production_id=p.id and person_id=person and credit_type='Cast') then raise exception 'Additional cast must belong to this production';end if;
  if not exists(select 1 from jsonb_array_elements(snapshot) where value->>'id'=person::text) then
   snapshot:=snapshot||jsonb_build_array((select jsonb_build_object('id',id,'name',display_name,'source','additional') from public.people where id=person and theater_id=p.theater_id));
  end if;
 end loop;
 -- Clear fields for branches that do not apply; clients cannot store contradictory hidden answers.
 if cancelled then d:=d||jsonb_build_object('start','','end','','house','','intermission','','act_two','','breaks','','break_details','','fight','','fight_details','');else d:=d||jsonb_build_object('cancel_reason','','cancel_details','');end if;
 if kind='Rehearsal' then d:=d||jsonb_build_object('house','','intermission','','act_two','','has_intermission',false,'penalties',false,'penalty_reason','','penalty_details','','fight','','fight_details','');end if;
 if not (d->>'penalties')::boolean then d:=d||jsonb_build_object('penalty_reason','','penalty_details','');end if;
 if not (d->>'has_intermission')::boolean then d:=d||jsonb_build_object('intermission','','act_two','');end if;
 if d->>'breaks'<>'No' then d:=d||jsonb_build_object('break_details','');end if;
 if not fight or d->>'fight'<>'No' then d:=d||jsonb_build_object('fight_details','');end if;
 if old.id is null then
  insert into public.stage_reports(id,theater_id,production_id,kind,report_date,event_id,data,cast_snapshot,source_calls,fight_required,created_by,updated_by)
   values(rid,p.theater_id,p.id,kind,day,eid,d,snapshot,source_ids,fight,auth.uid(),auth.uid()) returning * into r;
 else
  update public.stage_reports set data=d,cast_snapshot=snapshot,source_calls=source_ids,revision=revision+1,updated_at=clock_timestamp(),updated_by=auth.uid() where id=rid returning * into r;
 end if;
 return to_jsonb(r);
exception when unique_violation then raise exception 'A report already exists for this day or performance. Refresh and open the saved report.';
end $$;
revoke all on function private.save_stage_report(jsonb) from public,anon;
grant execute on function private.save_stage_report(jsonb) to authenticated;
create function public.save_stage_report(draft jsonb) returns jsonb language sql security invoker set search_path='' as $$select private.save_stage_report(draft)$$;
revoke all on function public.save_stage_report(jsonb) from public,anon;
grant execute on function public.save_stage_report(jsonb) to authenticated;
