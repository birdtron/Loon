-- Expose only critical notes on the cast-facing callboard, never full reports.
create table public.show_critical_notes (
 report_id uuid primary key references public.stage_reports(id),
 theater_id uuid not null, production_id uuid not null,
 report_date date not null, note text not null check(length(trim(note)) between 1 and 10000),
 revision integer not null default 1,
 resolved_at timestamptz, resolved_by uuid references auth.users(id),
 updated_at timestamptz not null default now(),
 foreign key(theater_id,production_id) references public.productions(theater_id,id)
);
create index show_critical_notes_scope on public.show_critical_notes(theater_id,production_id) where resolved_at is null;
alter table public.show_critical_notes enable row level security;
revoke all on public.show_critical_notes from public,anon,authenticated;
grant select on public.show_critical_notes to authenticated;
create policy critical_note_read on public.show_critical_notes for select to authenticated
 using(private.workspace_permission(theater_id,'stage','view',production_id));

create function private.sync_show_critical_note() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.data ? 'show_critical' and jsonb_typeof(new.data->'show_critical') <> 'boolean' then
  raise exception 'Answer whether any notes are show critical';
 end if;
 if coalesce((new.data->>'show_critical')::boolean,false) then
  if new.kind <> 'Rehearsal' or jsonb_typeof(new.data->'critical_note') is distinct from 'string'
   or length(trim(coalesce(new.data->>'critical_note',''))) not between 1 and 10000 then
   raise exception 'Describe the show-critical rehearsal note';
  end if;
  insert into public.show_critical_notes(report_id,theater_id,production_id,report_date,note)
   values(new.id,new.theater_id,new.production_id,new.report_date,trim(new.data->>'critical_note'))
   on conflict(report_id) do update set note=excluded.note,revision=show_critical_notes.revision+1,
    resolved_at=null,resolved_by=null,updated_at=clock_timestamp()
   where show_critical_notes.note is distinct from excluded.note;
 elsif exists(select 1 from public.show_critical_notes where report_id=new.id and resolved_at is null) then
  raise exception 'Resolve the show-critical note on the callboard before clearing this flag';
 end if;
 return new;
end $$;
revoke all on function private.sync_show_critical_note() from public,anon,authenticated;
create trigger sync_show_critical_note after insert or update on public.stage_reports for each row execute function private.sync_show_critical_note();

create function private.resolve_show_critical_note(report uuid,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare n public.show_critical_notes%rowtype;
begin
 select * into n from public.show_critical_notes where report_id=report for update;
 if auth.uid() is null or n.report_id is null
  or not private.report_permission(n.theater_id,n.production_id,'edit')
  or not (private.workspace_admin(n.theater_id) or exists(select 1 from private.workspace_members m where m.theater_id=n.theater_id and m.user_id=auth.uid() and m.active and m.roles && array['Stage Manager','Assistant Stage Manager','Company Manager'])) then
  raise exception 'Stage management access required' using errcode='42501';
 end if;
 if expected is null or n.revision<>expected then raise exception 'This note changed. Refresh before resolving it.';end if;
 if n.resolved_at is null then
  update public.show_critical_notes set resolved_at=clock_timestamp(),resolved_by=auth.uid(),revision=revision+1,updated_at=clock_timestamp()
   where report_id=report returning * into n;
 end if;
 return to_jsonb(n);
end $$;
revoke all on function private.resolve_show_critical_note(uuid,integer) from public,anon;
grant execute on function private.resolve_show_critical_note(uuid,integer) to authenticated;
create function public.resolve_show_critical_note(report uuid,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.resolve_show_critical_note(report,expected)$$;
revoke all on function public.resolve_show_critical_note(uuid,integer) from public,anon;
grant execute on function public.resolve_show_critical_note(uuid,integer) to authenticated;
