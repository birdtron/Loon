-- Super Admin is full access within their own active theater membership.
do $$ declare t text; key text;begin foreach t in array array['theaters','seasons','scripts','venues','productions','calendar_events','people','production_credits','rehearsal_calls','rehearsal_call_cast'] loop
 key:=case when t='theaters' then 'id' else 'theater_id' end;
 execute format('create policy theater_admin_all on public.%I for all to authenticated using(private.workspace_admin(%I)) with check(private.workspace_admin(%I))',t,key,key);
end loop;end $$;
create policy member_update on public.venues for update to authenticated using(private.workspace_permission(theater_id,'venues','edit')) with check(private.workspace_permission(theater_id,'venues','edit'));
-- Box Office has Staff access in the source grid, but not Cast access.
create or replace function private.visible_person(t uuid,p uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare u private.workspace_members%rowtype;begin
 if private.workspace_admin(t) then return true;end if;
 if not private.verified_user() then return false;end if;
 select * into u from private.workspace_members where theater_id=t and user_id=auth.uid() and active;
 if not found then return false;end if;
 if u.person_id=p then return true;end if;
 if not private.workspace_permission(t,'personnel') then return false;end if;
 if exists(select 1 from unnest(u.roles) r where r not in ('Guest','Director','Cast','Box Office','Development')) or u.overrides->>'personnel' in ('view','edit') then
  if exists(select 1 from unnest(u.roles) r where r not in ('Guest','Director','Cast')) then return true;end if;
 end if;
 if 'Box Office'=any(u.roles) and exists(select 1 from public.people where id=p and theater_id=t and 'Staff'=any(person_types) and not 'Cast'=any(person_types)) then return true;end if;
 if u.roles && array['Guest','Director'] then return exists(select 1 from public.production_credits where theater_id=t and person_id=p and production_id=any(u.production_ids));end if;
 return false;
end $$;
