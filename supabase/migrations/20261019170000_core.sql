
create table public.theaters (
 id uuid primary key default gen_random_uuid(), slug text not null unique, name text not null,
 timezone text not null default 'America/New_York', created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(), created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null
);
create table public.seasons (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 name text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 unique(theater_id,id), unique(theater_id,name)
);
create table public.scripts (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 title text not null, playwright text not null, musical boolean not null default false, composer text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 unique(theater_id,id),unique(theater_id,title)
);
create table public.venues (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 name text not null, capacity integer check(capacity>=0), stage_style text, stage_size text, indoor_outdoor text, description text,
 import_metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 unique(theater_id,id),unique(theater_id,name)
);
create table public.productions (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 title text not null, season_id uuid not null, script_id uuid not null, venue_id uuid,
 series text, full_description text, rating text, content_warnings text[] not null default '{}',
 runtime text, runtime_minutes integer check(runtime_minutes>0),
 opening_date date not null, closing_date date not null, rehearsal_start date,
 is_aea boolean, aea_tier text, publish boolean not null default false,
 is_demo boolean not null default true,
 import_metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 unique(theater_id,id),unique(theater_id,title,season_id),
 foreign key(theater_id,season_id) references public.seasons(theater_id,id),
 foreign key(theater_id,script_id) references public.scripts(theater_id,id),
 foreign key(theater_id,venue_id) references public.venues(theater_id,id),
 check(closing_date>=opening_date),
 check(rehearsal_start is null or rehearsal_start<=opening_date),
 check((is_aea is null and aea_tier is null) or (is_aea=false and aea_tier is null) or (is_aea=true and aea_tier is not null and aea_tier in ('Tier 1','Tier 2','Tier 3')))
);
create table public.calendar_events (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 production_id uuid not null, venue_id uuid, title text not null, category text not null default 'Performance' check(category='Performance'),
 start timestamptz not null, "end" timestamptz not null,
 accessibility text[] not null default '{}', is_special_event boolean not null default false, event_details text,
 call_status text not null default 'Draft' check(call_status in ('Draft','Published','Canceled')),
 is_demo boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 unique(theater_id,id),unique(theater_id,production_id,start),
 foreign key(theater_id,production_id) references public.productions(theater_id,id),
 foreign key(theater_id,venue_id) references public.venues(theater_id,id),
 check("end">start),
 check(accessibility <@ array['ASL Interpreted','Audio Described','Open Captioned','Sensory Friendly']::text[])
);
create index calendar_events_production_idx on public.calendar_events(production_id,start);
create index calendar_events_venue_idx on public.calendar_events(venue_id,start);
create index productions_season_idx on public.productions(season_id);
create index productions_script_idx on public.productions(script_id);
create index productions_venue_idx on public.productions(venue_id);

create function private.audit_record() returns trigger language plpgsql security invoker set search_path=''
as $$ begin
 if TG_OP='UPDATE' then
   if new.id is distinct from old.id then raise exception 'Record identity is immutable'; end if;
   if TG_TABLE_NAME<>'theaters' and new.theater_id is distinct from old.theater_id then raise exception 'Theater identity is immutable'; end if;
   new.created_at=old.created_at; new.created_by=old.created_by;
 else new.created_at=now(); new.created_by=auth.uid();
 end if;
 new.updated_at=now(); new.updated_by=auth.uid(); return new;
end $$;
revoke all on function private.audit_record() from public,anon,authenticated;

alter table public.theaters enable row level security;
revoke all on public.theaters from anon;
grant select,insert,update,delete on public.theaters to authenticated;
create policy thanos_all on public.theaters for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.theaters for each row execute function private.audit_record();

alter table public.seasons enable row level security;
revoke all on public.seasons from anon;
grant select,insert,update,delete on public.seasons to authenticated;
create policy thanos_all on public.seasons for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.seasons for each row execute function private.audit_record();

alter table public.scripts enable row level security;
revoke all on public.scripts from anon;
grant select,insert,update,delete on public.scripts to authenticated;
create policy thanos_all on public.scripts for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.scripts for each row execute function private.audit_record();

alter table public.venues enable row level security;
revoke all on public.venues from anon;
grant select,insert,update,delete on public.venues to authenticated;
create policy thanos_all on public.venues for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.venues for each row execute function private.audit_record();

alter table public.productions enable row level security;
revoke all on public.productions from anon;
grant select,insert,update,delete on public.productions to authenticated;
create policy thanos_all on public.productions for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.productions for each row execute function private.audit_record();

alter table public.calendar_events enable row level security;
revoke all on public.calendar_events from anon;
grant select,insert,update,delete on public.calendar_events to authenticated;
create policy thanos_all on public.calendar_events for all to authenticated using ((select private.has_thanos())) with check ((select private.has_thanos()));
create trigger audit_record before insert or update on public.calendar_events for each row execute function private.audit_record();

create function public.current_access() returns text language sql stable security invoker set search_path='' as $$
 select case when private.has_thanos() then 'Thanos' else null end;
$$;
revoke all on function public.current_access() from public,anon;
grant execute on function public.current_access() to authenticated;

