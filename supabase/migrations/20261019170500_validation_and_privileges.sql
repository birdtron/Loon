do $$ begin if to_regprocedure('public.rls_auto_enable()') is not null then execute 'revoke execute on function public.rls_auto_enable() from public, anon, authenticated'; end if; end $$;
create policy deny_direct_client_grants on private.platform_access_grants for all to anon, authenticated using (false) with check (false);
create policy deny_direct_client_reservations on private.platform_owner_reservations for all to anon, authenticated using (false) with check (false);
CREATE OR REPLACE FUNCTION private.audit_record()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ begin
if TG_OP='UPDATE' then
 if new.id is distinct from old.id then raise exception 'Record identity is immutable'; end if;
 if TG_TABLE_NAME<>'theaters' then
  if new.theater_id is distinct from old.theater_id then raise exception 'Theater identity is immutable'; end if;
 end if;
 new.created_at=old.created_at;new.created_by=old.created_by;
else new.created_at=now();new.created_by=auth.uid();end if;
new.updated_at=now();new.updated_by=auth.uid();return new;end $function$

CREATE OR REPLACE FUNCTION private.validate_performance()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p public.productions%rowtype; tz text; begin
select * into p from public.productions where id=new.production_id and theater_id=new.theater_id;
if not found then raise exception 'Production not found';end if;
select timezone into tz from public.theaters where id=new.theater_id;
if (new.start at time zone tz)::date not between p.opening_date and p.closing_date then raise exception 'Performance must be within production dates';end if;
if new.venue_id is not null and new.call_status<>'Canceled' then
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.venue_id::text,0));
 if exists(select 1 from public.calendar_events e where e.venue_id=new.venue_id and e.id<>new.id and e.call_status<>'Canceled' and e.start<new."end" and e."end">new.start) then raise exception 'Another performance overlaps in this venue';end if;
end if;
return new; end $function$

revoke all on function private.validate_performance() from public,anon,authenticated;
create trigger validate_performance before insert or update on public.calendar_events for each row execute function private.validate_performance();

