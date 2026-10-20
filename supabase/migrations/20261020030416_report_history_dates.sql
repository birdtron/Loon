-- A report keeps its original date when the linked calendar event is rescheduled.
-- Only new reports must match the current performance date.
do $$ declare definition text; original text := 'if not exists(select 1 from public.calendar_events where id=eid and production_id=p.id and category=''Performance'' and (start at time zone tz)::date=day)';begin
 definition:=pg_get_functiondef('private.save_stage_report(jsonb)'::regprocedure);
 if strpos(definition,original)=0 then raise exception 'Expected report date validation was not found';end if;
 execute replace(definition,original,replace(original,'if not exists','if old.id is null and not exists'));
end $$;
