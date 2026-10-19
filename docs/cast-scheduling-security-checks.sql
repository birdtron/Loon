-- Rollback-only integration test. Requires an existing verified owner and imported cast.
begin;
do $$
declare owner_id uuid;other_id uuid:=gen_random_uuid();
begin
 select bound_user_id into owner_id from private.platform_owner_reservations where bound_user_id is not null limit 1;
 assert owner_id is not null;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data) values(other_id,'loon-cast-test@example.invalid',now(),false,'{"role":"Thanos"}');
 perform set_config('loon.test_owner',owner_id::text,true);perform set_config('loon.test_other',other_id::text,true);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('loon.test_owner'),true);
do $$
declare p public.productions%rowtype; actor uuid;wrong_actor uuid;call_id uuid:=gen_random_uuid();d jsonb;r jsonb;rejected boolean;
begin
 select * into p from public.productions where title='Romeo and Juliet' limit 1;
 select person_id into actor from public.production_credits where production_id=p.id and credit_type='Cast' limit 1;
 select pe.id into wrong_actor from public.people pe where not exists(select 1 from public.production_credits c where c.person_id=pe.id and c.production_id=p.id and c.credit_type='Cast') limit 1;
 d:=jsonb_build_object('id',call_id,'production_id',p.id,'start','2035-01-02T23:00:00Z','end','2035-01-03T02:00:00Z','work','Rollback only scene work','act','I','scene','II','location','Rollback room','person_ids',jsonb_build_array(actor),'call_status','Published');
 r:=public.save_rehearsal_call(d);
 assert r->'call'->>'scene'='II';assert jsonb_array_length(r->'cast')=1;
 assert (select category='Rehearsal' and call_status='Published' and (start at time zone 'America/New_York')::date='2035-01-02' from public.calendar_events where id=call_id);
 r:=public.save_rehearsal_call(d);assert (select count(*)=1 from public.calendar_events where id=call_id),'Retry duplicated call';
 rejected:=false;begin perform public.save_rehearsal_call(d||jsonb_build_object('id',gen_random_uuid()));exception when raise_exception then rejected:=true;end;assert rejected,'Cast overlap accepted';
 perform public.save_rehearsal_call(d||jsonb_build_object('id',gen_random_uuid(),'person_ids',jsonb_build_array((select person_id from public.production_credits where production_id=p.id and credit_type='Cast' and person_id<>actor limit 1))));
 rejected:=false;begin perform public.save_rehearsal_call(d||jsonb_build_object('id',gen_random_uuid(),'person_ids',jsonb_build_array(wrong_actor)));exception when raise_exception then rejected:=true;end;assert rejected,'Noncast accepted';
 assert (select count(*)=1 from public.rehearsal_call_cast where event_id=call_id),'Failed save damaged members';
 rejected:=false;begin perform public.save_rehearsal_call(d||jsonb_build_object('expected_updated_at','2000-01-01T00:00:00Z'));exception when raise_exception then rejected:=true;end;assert rejected,'Stale edit accepted';
 rejected:=false;begin perform public.save_rehearsal_call(d||jsonb_build_object('expected_updated_at',r->'event'->>'updated_at','work','Must roll back','location',repeat('x',301)));exception when check_violation then rejected:=true;end;assert rejected,'Invalid metadata accepted';
 assert (select title='Rollback only scene work' from public.calendar_events where id=call_id),'Partial event update survived failed transaction';
 d:=d||jsonb_build_object('expected_updated_at',r->'event'->>'updated_at','scene','III','call_status','Canceled');r:=public.save_rehearsal_call(d);
 assert r->'call'->>'scene'='III';assert r->'event'->>'call_status'='Canceled';
 rejected:=false;begin update public.calendar_events set category='Other' where id=call_id;exception when raise_exception then rejected:=true;end;assert rejected,'Rehearsal category was lost';
 perform set_config('loon.test_call',call_id::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('loon.test_other'),true);
do $$
declare rejected boolean:=false;
begin
 assert (select count(*)=0 from public.rehearsal_calls);assert (select count(*)=0 from public.rehearsal_call_cast);
 begin perform public.save_rehearsal_call(jsonb_build_object('id',current_setting('loon.test_call')));exception when insufficient_privilege then rejected:=true;end;assert rejected,'Nonowner RPC access';
end $$;
reset role;
rollback;
