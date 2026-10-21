-- Server-owned marker: only explicitly registered demo accounts are affected.
create table private.read_only_users(user_id uuid primary key references auth.users(id),created_at timestamptz not null default now());
alter table private.read_only_users enable row level security;
revoke all on private.read_only_users from public,anon,authenticated;
create function private.is_read_only() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from private.read_only_users where user_id=auth.uid());
$$;
revoke all on function private.is_read_only() from public,anon;
grant execute on function private.is_read_only() to authenticated;
-- Demo Super Admin membership retains read scope but gets no admin write bypass.
do $$ declare definition text; begin
 select pg_get_functiondef('private.workspace_admin(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'select private.has_thanos() or (','select not private.is_read_only() and (private.has_thanos() or (');
 definition:=replace(definition,'''Super Admin''=any(roles)));','''Super Admin''=any(roles))));');
 execute definition;
 select pg_get_functiondef('private.workspace_permission(uuid,text,text,uuid)'::regprocedure) into definition;
 definition:=replace(definition,E'begin\n',E'begin\n if private.is_read_only() and a <> ''view'' then return false;end if;\n');
 execute definition;
 select pg_get_functiondef('private.get_workspace(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'''user_id'',uid','''read_only'',private.is_read_only(),''user_id'',uid');
 -- The client can browse administrative settings; write authorization continues
 -- to use workspace_admin, which is false for this account.
 definition:=replace(definition,'''admin'',private.workspace_admin(chosen)','''admin'',(private.workspace_admin(chosen) or (u.id is not null and private.is_read_only()))');
 definition:=replace(definition,'''members'',case when private.workspace_admin(chosen) then','''members'',case when private.workspace_admin(chosen) or (u.id is not null and private.is_read_only()) then');
 execute definition;
 select pg_get_functiondef('private.save_account(jsonb,integer)'::regprocedure) into definition;
 definition:=replace(definition,E'begin\n',E'begin\n if private.is_read_only() then raise exception ''Demo access is read only'' using errcode=''42501'';end if;\n');
 execute definition;
end $$;
-- Prevent shared demo credentials from being changed through the Auth API.
-- Normal sign-in timestamps and token refresh continue to work.
create function private.protect_demo_credentials() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from private.read_only_users where user_id=old.id) and
 (new.email is distinct from old.email or new.encrypted_password is distinct from old.encrypted_password or new.email_change is distinct from old.email_change or new.phone is distinct from old.phone) then
 raise exception 'Demo credentials are read only' using errcode='42501';end if;
 return new;
end $$;
revoke all on function private.protect_demo_credentials() from public,anon,authenticated;
create trigger protect_demo_credentials before update of email,encrypted_password,email_change,phone on auth.users for each row execute function private.protect_demo_credentials();
