-- Parallel rehearsal rooms may have different casts called at the same start time.
-- Other event kinds retain their prior duplicate-start protection.
alter table public.calendar_events drop constraint calendar_events_production_category_start_key;
create unique index calendar_events_non_rehearsal_start_key on public.calendar_events(theater_id,production_id,category,start) where category<>'Rehearsal';
