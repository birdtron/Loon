-- System-generated demo fixtures stay distinguishable from staff punches.
alter table private.clock_entries add column is_demo boolean not null default false;
alter table private.clock_entries alter column created_by drop not null;
alter table private.clock_entries alter column updated_by drop not null;
alter table private.clock_entries add constraint real_clock_entries_have_actor check(is_demo or (created_by is not null and updated_by is not null));
create or replace function private.get_production_labor(t uuid,from_date date,to_date date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.clock_access(t) then raise exception 'Clocking access required' using errcode='42501';end if;
 if from_date is null or to_date is null or to_date<from_date then raise exception 'Choose a valid date range';end if;
 return (select coalesce(jsonb_agg(to_jsonb(x) order by personnel,production,department,role,is_demo),'[]'::jsonb) from (
 select e.person_id,p.display_name personnel,e.production_id,s.title production,e.department,e.role,e.is_demo,sum(e.minutes) minutes
 from private.clock_entries e join public.people p on p.id=e.person_id join public.productions s on s.id=e.production_id
 where e.theater_id=t and e.ended_at is not null and e.work_date between from_date and to_date and private.clock_production(t,e.production_id)
 group by e.person_id,p.display_name,e.production_id,s.title,e.department,e.role,e.is_demo) x);
end $$;
