create table public.people (
  id uuid primary key default gen_random_uuid(),
  theater_id uuid not null references public.theaters(id),
  source_key text not null,
  display_name text not null check(length(trim(display_name)) between 1 and 200),
  first_name text not null default '', last_name text not null default '', known_as text not null default '',
  person_types text[] not null default array['Cast']::text[] check(cardinality(person_types)>0 and person_types <@ array['Cast','Creative','Staff','Crew','Other']::text[]),
  job_title text not null default '', departments text[] not null default '{}', area text not null default '',
  hometown text not null default '', bio text not null default '', favorite_shakespeare text not null default '',
  unions text[] not null default '{}', intern boolean not null default false,
  is_demo boolean not null default false,
  headshot_kind text check(headshot_kind in ('demo','uploaded')),
  headshot_path text, headshot_source_url text, headshot_credit text, headshot_license text, headshot_license_url text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  unique(theater_id,id), unique(theater_id,source_key),
  check((headshot_kind is null and headshot_path is null) or (headshot_kind is not null and headshot_path is not null)),
  check(headshot_kind <> 'uploaded' or headshot_path like theater_id::text || '/' || id::text || '/%'),
  check(headshot_kind <> 'demo' or headshot_path ~ '^demo/[a-z0-9-]+[.]jpg$'),
  check(headshot_source_url is null or headshot_source_url like 'https://%'),
  check(headshot_license_url is null or headshot_license_url like 'https://%')
);
create index people_theater_name_idx on public.people(theater_id,display_name);

create table public.production_credits (
  id uuid primary key default gen_random_uuid(),
  theater_id uuid not null references public.theaters(id), production_id uuid not null, person_id uuid not null,
  role text not null check(length(trim(role)) between 1 and 200),
  credit_type text not null check(credit_type in ('Cast','Creative','Staff','Crew','Other')),
  billing_order integer not null default 0 check(billing_order>=0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
  foreign key(theater_id,production_id) references public.productions(theater_id,id),
  foreign key(theater_id,person_id) references public.people(theater_id,id),
  unique(theater_id,production_id,person_id,credit_type,role)
);
create index production_credits_person_idx on public.production_credits(theater_id,person_id);

alter table public.people enable row level security;
alter table public.production_credits enable row level security;
revoke all on public.people,public.production_credits from anon;
grant select,insert,update,delete on public.people,public.production_credits to authenticated;
create policy thanos_all on public.people for all to authenticated
  using ((select private.has_thanos())) with check ((select private.has_thanos()));
create policy thanos_all on public.production_credits for all to authenticated
  using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.people for each row execute function private.audit_record();
create trigger audit_record before insert or update on public.production_credits for each row execute function private.audit_record();

-- New uploaded headshots are private, never application-public assets.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('personnel-headshots','personnel-headshots',false,4194304,array['image/jpeg','image/png','image/webp']);
create policy personnel_headshots_read on storage.objects for select to authenticated
using (bucket_id='personnel-headshots' and (select private.has_thanos()) and exists (
  select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]
));
create policy personnel_headshots_insert on storage.objects for insert to authenticated
with check (bucket_id='personnel-headshots' and (select private.has_thanos()) and exists (
  select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]
));
create policy personnel_headshots_update on storage.objects for update to authenticated
using (bucket_id='personnel-headshots' and (select private.has_thanos()) and exists (
  select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]
)) with check (bucket_id='personnel-headshots' and (select private.has_thanos()) and exists (
  select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]
));
create policy personnel_headshots_delete on storage.objects for delete to authenticated
using (bucket_id='personnel-headshots' and (select private.has_thanos()) and exists (
  select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]
));
