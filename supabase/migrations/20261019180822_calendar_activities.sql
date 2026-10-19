-- Preserve owner-only RLS and allow dated production work outside the show run.
alter table public.calendar_events drop constraint calendar_events_category_check;
alter table public.calendar_events add constraint calendar_events_category_check
  check (category in ('Performance', 'Rehearsal', 'Tech', 'Load-in', 'Strike', 'Meeting', 'Other'));

-- Separate kinds of work may begin together; duplicate calls of the same kind may not.
alter table public.calendar_events drop constraint calendar_events_theater_id_production_id_start_key;
alter table public.calendar_events add constraint calendar_events_production_category_start_key
  unique (theater_id, production_id, category, start);

create or replace function private.validate_performance()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare p public.productions%rowtype; tz text;
begin
  select * into p from public.productions where id = new.production_id and theater_id = new.theater_id;
  if not found then raise exception 'Production not found'; end if;
  select timezone into tz from public.theaters where id = new.theater_id;
  if new.category = 'Performance' and (new.start at time zone tz)::date not between p.opening_date and p.closing_date then
    raise exception 'Performance must be within production dates';
  end if;
  if new.venue_id is not null and new.call_status <> 'Canceled' then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.venue_id::text, 0));
    if exists (select 1 from public.calendar_events e where e.venue_id = new.venue_id and e.id <> new.id and e.call_status <> 'Canceled' and e.start < new."end" and e."end" > new.start) then
      raise exception 'Another event overlaps in this venue';
    end if;
  end if;
  return new;
end $$;
revoke all on function private.validate_performance() from public, anon, authenticated;
