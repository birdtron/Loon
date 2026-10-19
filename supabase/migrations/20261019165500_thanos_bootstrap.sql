
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

create table private.platform_access_grants (
 user_id uuid primary key references auth.users(id) on delete cascade,
 security_level text not null check (security_level = 'Thanos'),
 created_at timestamptz not null default now()
);
alter table private.platform_access_grants enable row level security;
revoke all on private.platform_access_grants from public, anon, authenticated;
grant all on private.platform_access_grants to service_role;

create table private.platform_owner_reservations (
 email text primary key check (email = lower(email)),
 security_level text not null check (security_level = 'Thanos'),
 bound_user_id uuid unique references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(),
 bound_at timestamptz
);
alter table private.platform_owner_reservations enable row level security;
revoke all on private.platform_owner_reservations from public, anon, authenticated;
grant all on private.platform_owner_reservations to service_role;

create function private.bind_verified_platform_owner()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare reservation_email text;
begin
 if new.email_confirmed_at is null or new.email is null
    or new.deleted_at is not null or new.is_anonymous is true then
   return new;
 end if;
 update private.platform_owner_reservations
 set bound_user_id = new.id, bound_at = now()
 where email = lower(new.email) and bound_user_id is null
 returning email into reservation_email;
 if reservation_email is not null then
   insert into private.platform_access_grants(user_id, security_level)
   values (new.id, 'Thanos')
   on conflict (user_id) do nothing;
 end if;
 return new;
end;
$$;
revoke all on function private.bind_verified_platform_owner() from public, anon, authenticated;
create trigger loon_bind_verified_platform_owner
 after insert or update of email_confirmed_at on auth.users
 for each row execute function private.bind_verified_platform_owner();

create function private.has_thanos()
returns boolean language sql stable security definer set search_path = ''
as $$
 select auth.uid() is not null and exists (
  select 1 from private.platform_access_grants g
  join auth.users u on u.id=g.user_id
  where g.user_id = auth.uid() and g.security_level='Thanos'
  and u.email_confirmed_at is not null and u.deleted_at is null
  and (u.is_anonymous is not true)
 );
$$;
revoke all on function private.has_thanos() from public, anon;
grant execute on function private.has_thanos() to authenticated, service_role;

comment on table private.platform_access_grants is
'Loon global Thanos grants. Unrestricted application authorization across all theaters; evaluated before tenant policies. Not a database superuser or Supabase organization-owner role.';
comment on table private.platform_owner_reservations is
'One-time owner provisioning reservation. Grants only after Supabase verifies the exact reserved email; never trusts user_metadata.';

-- Provision the owner email separately using a trusted administrator. Never commit account records.

