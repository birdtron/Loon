begin;
do $test$
declare owner_id uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid(); owner_email text;
begin
 select email into owner_email from private.platform_owner_reservations where bound_user_id is null;
 if owner_email is null then raise exception 'Owner reservation already bound: use the existing-account test path'; end if;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data) values(owner_id,owner_email,null,false,'{"role":"Thanos"}');
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 assert not private.has_thanos(), 'Unverified owner must be denied';
 update auth.users set email_confirmed_at=now() where id=owner_id;
 assert private.has_thanos(), 'Verified reserved owner must be Thanos';
 insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data) values(other_id,'loon-permission-test@example.invalid',now(),false,'{"role":"Thanos"}');
 perform set_config('loon.test_owner',owner_id::text,true);
 perform set_config('loon.test_other',other_id::text,true);
end $test$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('loon.test_other'),true);
do $test$
begin
 assert public.current_access() is null, 'Metadata spoof must be denied';
 assert (select count(*)=0 from public.productions), 'Nonowner read must be denied';
 assert not has_table_privilege('authenticated','private.platform_access_grants','INSERT'), 'No self elevation';
end $test$;
select set_config('request.jwt.claim.sub',current_setting('loon.test_owner'),true);
do $test$
declare event_id uuid; rejected boolean:=false;
begin
 assert public.current_access()='Thanos','Owner authorization missing';
 assert (select count(*)=2 from public.productions),'Owner must see both productions';
 assert (select count(*)=45 from public.calendar_events),'Owner must see all performances';
 select id into event_id from public.calendar_events order by start limit 1;
 update public.calendar_events set event_details='ROLLBACK-ONLY TEST' where id=event_id;
 assert (select event_details='ROLLBACK-ONLY TEST' from public.calendar_events where id=event_id),'Owner update failed';
 begin
 update public.calendar_events set start='2035-01-01T20:00:00Z',"end"='2035-01-01T22:00:00Z' where id=event_id;
 exception when raise_exception then rejected:=true; end;
 assert rejected,'Out-of-run date must be rejected';
end $test$;
reset role;
rollback;
