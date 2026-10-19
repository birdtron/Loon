-- Different departments can begin distinct activities on the same date.
drop index public.calendar_events_non_rehearsal_start_key;
create unique index calendar_events_performance_start_key on public.calendar_events(theater_id,production_id,category,start) where category='Performance';
