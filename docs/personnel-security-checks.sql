-- Run in a trusted SQL session. All temporary edits, users and objects roll back.
begin;
do $$
declare owner_id uuid; other_id uuid:=gen_random_uuid();
begin
 select bound_user_id into owner_id from private.platform_owner_reservations where bound_user_id is not null limit 1;
 assert owner_id is not null;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data) values(other_id,'loon-personnel-test@example.invalid',now(),false,'{"role":"Thanos"}');
 perform set_config('loon.test_owner',owner_id::text,true); perform set_config('loon.test_other',other_id::text,true);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('loon.test_owner'),true);
do $$
declare p public.people%rowtype; object_name text; rejected boolean;
begin
 assert public.current_access()='Thanos';
 assert (select count(*)=56 from public.people);
 assert (select count(*)=63 from public.production_credits);
 select * into p from public.people order by display_name limit 1;
 update public.people set hometown='Rollback only' where id=p.id and updated_at=p.updated_at; assert found;
 update public.people set hometown='Stale edit' where id=p.id and updated_at=p.updated_at; assert not found;
 object_name:=p.theater_id::text||'/'||p.id::text||'/rollback-only.jpg';
 insert into storage.objects(bucket_id,name) values('personnel-headshots',object_name);
 assert (select count(*)=1 from storage.objects where bucket_id='personnel-headshots' and name=object_name);
 rejected:=false;
 begin update public.people set headshot_kind='uploaded',headshot_path='wrong/person/photo.jpg' where id=p.id;
 exception when check_violation then rejected:=true;end; assert rejected;
 rejected:=false;
 begin insert into storage.objects(bucket_id,name) values('personnel-headshots','wrong/person/photo.jpg');
 exception when insufficient_privilege then rejected:=true;end; assert rejected;
 perform set_config('loon.test_theater',p.theater_id::text,true);
end $$;
select set_config('request.jwt.claim.sub',current_setting('loon.test_other'),true);
do $$
declare rejected boolean:=false;
begin
 assert public.current_access() is null;
 assert (select count(*)=0 from public.people);
 assert (select count(*)=0 from public.production_credits);
 assert (select count(*)=0 from storage.objects where bucket_id='personnel-headshots');
 begin insert into public.people(theater_id,source_key,display_name) values(current_setting('loon.test_theater')::uuid,'rollback-only','Denied');
 exception when insufficient_privilege then rejected:=true;end; assert rejected;
end $$;
reset role;
rollback;
