-- Run in a trusted SQL session against an installation with a verified owner.
-- All synthetic events, users, and temporary edits are rolled back.
begin;
do $$
declare owner_id uuid; other_id uuid := gen_random_uuid();
begin
  select bound_user_id into owner_id from private.platform_owner_reservations where bound_user_id is not null limit 1;
  if owner_id is null then raise exception 'Requires a verified owner account'; end if;
  insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data)
    values(other_id,'loon-calendar-test@example.invalid',now(),false,'{"role":"Thanos"}');
  perform set_config('loon.test_owner',owner_id::text,true);
  perform set_config('loon.test_other',other_id::text,true);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('loon.test_owner'),true);
do $$
declare p public.productions%rowtype; e public.calendar_events%rowtype; activity_id uuid; stale timestamptz; rejected boolean;
begin
  assert public.current_access()='Thanos', 'Owner required';
  select * into p from public.productions order by opening_date limit 1;
  select * into e from public.calendar_events where category='Performance' order by start limit 1;
  insert into public.calendar_events(theater_id,production_id,title,category,start,"end",is_demo)
    values(p.theater_id,p.id,'ROLLBACK ONLY strike','Strike',p.closing_date+interval '1 day 09 hours',p.closing_date+interval '3 days 17 hours',true) returning id,updated_at into activity_id,stale;
  assert (select category='Strike' from public.calendar_events where id=activity_id), 'Strike save failed';
  update public.calendar_events set event_details='ROLLBACK ONLY' where id=activity_id;
  assert (select event_details='ROLLBACK ONLY' from public.calendar_events where id=activity_id), 'Activity edit failed';
  update public.calendar_events set event_details='ROLLBACK ONLY concurrency check' where id=e.id and updated_at=e.updated_at;
  assert found, 'First versioned update failed';
  update public.calendar_events set event_details='stale' where id=e.id and updated_at=e.updated_at;
  assert not found, 'Stale update must affect no rows';
  insert into public.calendar_events(theater_id,production_id,title,category,start,"end")
    select theater_id,production_id,title,category,start,"end" from public.calendar_events where id=e.id
    on conflict(theater_id,production_id,category,start) where category='Performance' do nothing;
  assert not found, 'Duplicate performance/start should be ignored by seed upsert';
  insert into public.calendar_events(theater_id,production_id,title,category,start,"end",is_demo)
    values(p.theater_id,p.id,'ROLLBACK ONLY meeting','Meeting',p.closing_date+interval '1 day 09 hours',p.closing_date+interval '1 day 10 hours',true);
  rejected:=false;
  begin update public.calendar_events set start='2035-01-01T20:00:00Z',"end"='2035-01-01T22:00:00Z' where id=e.id;
  exception when raise_exception then rejected:=true; end;
  assert rejected, 'Out-of-run performance accepted';
  if e.venue_id is not null then
    rejected:=false;
    begin insert into public.calendar_events(theater_id,production_id,venue_id,title,category,start,"end") values(e.theater_id,e.production_id,e.venue_id,'ROLLBACK ONLY overlap','Tech',e.start,e."end");
    exception when raise_exception then rejected:=true; end;
    assert rejected, 'Overlapping venue booking accepted';
  end if;
  rejected:=false;
  begin update public.calendar_events set category='Invalid' where id=activity_id;
  exception when check_violation then rejected:=true; end;
  assert rejected, 'Invalid category accepted';
  rejected:=false;
  begin update public.calendar_events set "end"=start where id=activity_id;
  exception when check_violation then rejected:=true; end;
  assert rejected, 'Invalid time range accepted';
  perform set_config('loon.test_production',p.id::text,true);
  perform set_config('loon.test_theater',p.theater_id::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('loon.test_other'),true);
do $$
declare rejected boolean:=false;
begin
  assert public.current_access() is null, 'Metadata spoof granted access';
  assert (select count(*)=0 from public.calendar_events), 'Nonowner can read calendar';
  begin
    insert into public.calendar_events(theater_id,production_id,title,category,start,"end") values(current_setting('loon.test_theater')::uuid,current_setting('loon.test_production')::uuid,'ROLLBACK ONLY denied','Strike','2035-01-01T12:00:00Z','2035-01-01T13:00:00Z');
  exception when insufficient_privilege or raise_exception then rejected:=true; end;
  assert rejected, 'Nonowner can create activity';
end $$;
reset role;
rollback;
