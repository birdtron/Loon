-- Read access for a marked, verified Super Admin in their active theater only.
-- Mutation authorization helpers remain unchanged.
create function private.demo_admin_view(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.is_read_only() and private.verified_user() and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and 'Super Admin'=any(roles));
$$;
revoke all on function private.demo_admin_view(uuid) from public,anon,authenticated;
do $$ declare definition text; fn text; begin
 foreach fn in array array['private.get_company_management(uuid)','private.get_intake_submission(uuid)','private.get_personnel_media(uuid,text)'] loop
 select pg_get_functiondef(fn::regprocedure) into definition;
 definition:=replace(definition,'not private.can_manage_intake(t)','not (private.can_manage_intake(t) or private.demo_admin_view(t))');
 definition:=replace(definition,'not private.can_manage_intake(q.theater_id)','not (private.can_manage_intake(q.theater_id) or private.demo_admin_view(q.theater_id))');
 execute definition;
 end loop;
 select pg_get_functiondef('private.get_personnel_contact(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'not private.can_manage_personnel_contact(t)','not (private.can_manage_personnel_contact(t) or private.demo_admin_view(t))');
 execute definition;
end $$;
