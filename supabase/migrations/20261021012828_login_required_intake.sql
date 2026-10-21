-- Company Management issues email-bound access; verified recipients can only use
-- their own intake. Approval creates a bounded, view-only workspace membership.
alter table private.personnel_intake_links add column claimed_by uuid references auth.users(id),add column claimed_at timestamptz,add column access_role text not null default 'Cast' check(access_role in ('Cast','Guest','Director','Production'));
create index intake_recipient_idx on private.personnel_intake_links(recipient_email);
create function private.require_intake_login(key text) returns private.personnel_intake_links language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;em text;
begin
 if not private.verified_user() or private.is_read_only() then raise exception 'Sign in with your verified Loon login to open intake' using errcode='42501';end if;
 if key ~ '^[a-f0-9]{64}$' then select * into l from private.personnel_intake_links where token_hash=encode(sha256(convert_to(key,'UTF8')),'hex');
 elsif key ~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' then select * into l from private.personnel_intake_links where id=key::uuid;
 end if;
 select lower(email) into em from auth.users where id=auth.uid();
 if l.id is null or l.revoked_at is not null or l.expires_at<=now() or l.recipient_email='' or l.recipient_email<>em or (l.claimed_by is not null and l.claimed_by<>auth.uid()) then raise exception 'This invitation is unavailable for your account. Ask Company Management for a new invitation.' using errcode='42501';end if;
 return l;
end $$;
revoke all on function private.require_intake_login(text) from public,anon,authenticated;
-- Only minimal invitation branding is available before login; no profiles or roles.
create function intake_api.get_intake_invitation(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;
begin
 if token is null or token !~ '^[a-f0-9]{64}$' then raise exception 'This invitation is unavailable';end if;
 select * into l from private.personnel_intake_links where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') and revoked_at is null and expires_at>now();
 if not found or l.recipient_email='' or not exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text) then raise exception 'This invitation is unavailable. Ask Company Management for a new invitation.';end if;
 return jsonb_build_object('recipient_name',l.recipient_name,'recipient_email',l.recipient_email,'theater_name',(select name from public.theaters where id=l.theater_id),'theater_logo',(select data->'theater'->>'logo' from private.workspace_settings where theater_id=l.theater_id));
end $$;
revoke all on function intake_api.get_intake_invitation(text) from public;
grant execute on function intake_api.get_intake_invitation(text) to anon,authenticated;
create function public.get_intake_invitation(token text) returns jsonb language sql security invoker set search_path='' as $$select intake_api.get_intake_invitation(token)$$;
revoke all on function public.get_intake_invitation(text) from public;
grant execute on function public.get_intake_invitation(text) to anon,authenticated;
create or replace function intake_api.get_personnel_intake(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;used boolean;
begin
 l:=private.require_intake_login(token);used:=exists(select 1 from private.personnel_intake_submissions where link_id=l.id);
 if not used and not exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text) then raise exception 'The current season changed. Ask Company Management for a new invitation.';end if;
 return jsonb_build_object('theater_name',(select name from public.theaters where id=l.theater_id),'theater_logo',(select data->'theater'->>'logo' from private.workspace_settings where theater_id=l.theater_id),'season_name',(select name from public.seasons where id=l.season_id),'recipient_name',l.recipient_name,'recipient_email',l.recipient_email,'submitted',used,'productions',case when used then '[]'::jsonb else (select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'roles',jsonb_build_object('Cast',(select coalesce(jsonb_agg(r.role order by r.role),'[]') from(select distinct role from public.production_credits where production_id=p.id and credit_type='Cast')r),'Creative',(select coalesce(jsonb_agg(r.role order by r.role),'[]') from(select distinct role from public.production_credits where production_id=p.id and credit_type='Creative')r))) order by p.title),'[]') from public.productions p where p.theater_id=l.theater_id and p.season_id=l.season_id)end);
end $$;
create or replace function private.create_personnel_intake(t uuid,recipient_name text,recipient_email text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare season uuid;raw text;lid uuid;
begin
 if not private.can_manage_intake(t) then raise exception 'Company Management access required' using errcode='42501';end if;
 if length(trim(recipient_name)) not between 1 and 200 or trim(recipient_email)='' or length(recipient_email)>254 or (recipient_email<>'' and trim(recipient_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$') then raise exception 'Enter a recipient name and valid optional email';end if;
 select nullif(data->'theater'->>'current_season_id','')::uuid into season from private.workspace_settings where theater_id=t;
 if season is null or not exists(select 1 from public.seasons where id=season and theater_id=t) then raise exception 'Set the theater current season in Settings first';end if;
 raw:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
 insert into private.personnel_intake_links(theater_id,season_id,token_hash,recipient_name,recipient_email,created_by) values(t,season,encode(sha256(convert_to(raw,'UTF8')),'hex'),trim(recipient_name),lower(trim(recipient_email)),auth.uid()) returning id into lid;
 return jsonb_build_object('id',lid,'token',raw,'expires_at',now()+interval '14 days');
end $$;
create or replace function intake_api.submit_personnel_intake(token text,payload jsonb,request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;existing private.personnel_intake_submissions%rowtype;clean jsonb;hash text;receipt uuid;
begin
 if request_id is null then raise exception 'This intake link is unavailable';end if;
 l:=private.require_intake_login(token);
 select * into l from private.personnel_intake_links where id=l.id for update;
 if l.claimed_by is not null and l.claimed_by<>auth.uid() then raise exception 'This invitation belongs to another account' using errcode='42501';end if;
 if not found or l.revoked_at is not null or l.expires_at<=now() then raise exception 'This intake link is unavailable or expired';end if;
 clean:=private.clean_intake(payload,l.theater_id,l.season_id);hash:=encode(sha256(convert_to(clean::text,'UTF8')),'hex');
 select * into existing from private.personnel_intake_submissions where link_id=l.id;
 if found then if existing.request_id=request_id and existing.payload_hash=hash then return jsonb_build_object('receipt',existing.id,'status','Pending review');else raise exception 'This link has already been submitted. Contact Company Management for another link.';end if;end if;
 if l.recipient_email<>'' and l.recipient_email<>lower(clean->'contacts'->>'email') then raise exception 'Use the email address this invitation was issued for';end if;
 if not exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text) then raise exception 'The theater current season has changed. Ask Company Management for a new link.';end if;
 update private.personnel_intake_links set claimed_by=auth.uid(),claimed_at=coalesce(claimed_at,now()) where id=l.id;
 insert into private.personnel_intake_submissions(link_id,theater_id,season_id,request_id,payload_hash,payload) values(l.id,l.theater_id,l.season_id,request_id,hash,clean) returning id into receipt;
 return jsonb_build_object('receipt',receipt,'status','Pending review');
end $$;
revoke execute on function intake_api.get_personnel_intake(text),intake_api.submit_personnel_intake(text,jsonb,uuid),public.get_personnel_intake(text),public.submit_personnel_intake(text,jsonb,uuid) from anon;
create function private.issue_personnel_login(t uuid,recipient_name text,recipient_email text,access_role text) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if access_role is null or access_role not in ('Cast','Guest','Director','Production') then raise exception 'Choose an assigned access role';end if;
 result:=private.create_personnel_intake(t,recipient_name,recipient_email);
 update private.personnel_intake_links set access_role=issue_personnel_login.access_role where id=(result->>'id')::uuid;
 return result;
end $$;
create function private.get_my_onboarding() returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.verified_user() then raise exception 'Verified login required' using errcode='42501';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'theater_name',t.name,'season_name',s.name,'status',coalesce(q.status,'Intake required'),'expires_at',l.expires_at,'access_role',l.access_role) order by l.created_at desc),'[]') from private.personnel_intake_links l join public.theaters t on t.id=l.theater_id join public.seasons s on s.id=l.season_id left join private.personnel_intake_submissions q on q.link_id=l.id where l.revoked_at is null and (q.id is not null or (l.expires_at>now() and exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text))) and l.recipient_email=(select lower(email) from auth.users where id=auth.uid()) and (l.claimed_by is null or l.claimed_by=auth.uid()));
end $$;
-- Preserve the existing transaction and all duplicate/stale-write safeguards.
alter function private.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) rename to review_intake_profile;
revoke all on function private.review_intake_profile(uuid,text,integer,uuid,timestamptz,integer,boolean,text) from public,anon,authenticated;
create function private.review_personnel_intake(submission uuid,decision text,expected integer,person uuid default null,person_expected timestamptz default null,contact_expected integer default 0,allow_duplicate boolean default false,note text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare q private.personnel_intake_submissions%rowtype;l private.personnel_intake_links%rowtype;result jsonb;existing private.workspace_members%rowtype;prod_ids uuid[];
begin
 select * into q from private.personnel_intake_submissions where id=submission;
 if not found or not private.can_manage_intake(q.theater_id) then raise exception 'Company Management access required' using errcode='42501';end if;
 select * into q from private.personnel_intake_submissions where id=submission for update;
 select * into l from private.personnel_intake_links where id=q.link_id for update;
 if decision='approve' and l.revoked_at is not null then raise exception 'This invitation was revoked';end if;
 result:=private.review_intake_profile(submission,decision,expected,person,person_expected,contact_expected,allow_duplicate,note);
 -- Old, pre-login submissions remain reviewable; they never gain account access.
 if decision='approve' and l.claimed_by is not null then
 if not exists(select 1 from auth.users where id=l.claimed_by and lower(email)=l.recipient_email and email_confirmed_at is not null and deleted_at is null and is_anonymous is not true) then raise exception 'The invited account changed. Review it before approval.';end if;
 perform pg_advisory_xact_lock(hashtextextended(q.theater_id::text,52));
 select * into existing from private.workspace_members where theater_id=q.theater_id and (user_id=l.claimed_by or email=l.recipient_email) for update;
 if found then
 if (existing.user_id is not null and existing.user_id<>l.claimed_by) or (existing.person_id is not null and existing.person_id<>(result->>'person_id')::uuid) then raise exception 'Existing workspace access belongs to another profile. Ask an administrator to review the match.';end if;
 -- Never replace existing roles, explicit denies, inactive access or delegations.
 else
 select coalesce(array_agg(distinct (a->>'production_id')::uuid),'{}') into prod_ids from jsonb_array_elements(q.payload->'assignments')a;
 insert into private.workspace_members(theater_id,email,user_id,roles,person_id,production_ids) values(q.theater_id,l.recipient_email,l.claimed_by,array[l.access_role],(result->>'person_id')::uuid,prod_ids);
 insert into private.settings_history(theater_id,actor,section) values(q.theater_id,auth.uid(),'onboarding_access_activated');
 end if;
 end if;
 return result;
end $$;
create or replace function public.review_personnel_intake(submission uuid,decision text,expected integer,person uuid default null,person_expected timestamptz default null,contact_expected integer default 0,allow_duplicate boolean default false,note text default '') returns jsonb language sql security invoker set search_path='' as $$select private.review_personnel_intake(submission,decision,expected,person,person_expected,contact_expected,allow_duplicate,note)$$;
create or replace function private.get_intake_submission(submission uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare q private.personnel_intake_submissions%rowtype;l private.personnel_intake_links%rowtype;
begin
 select * into q from private.personnel_intake_submissions where id=submission;
 if not found or not (private.can_manage_intake(q.theater_id) or private.demo_admin_view(q.theater_id)) then raise exception 'Company Management access required' using errcode='42501';end if;
 select * into l from private.personnel_intake_links where id=q.link_id;
 return (to_jsonb(q)-array['request_id','payload_hash','link_id','reviewed_by'])||jsonb_build_object('full_name',q.payload->>'full_name','email',q.payload->'contacts'->>'email','area',q.payload->>'area','season_name',(select name from public.seasons where id=q.season_id),'access_role',l.access_role,'login_verified',l.claimed_by is not null);
end $$;
-- Enforce invitation-only account creation even if a caller bypasses the UI.
create function private.require_issued_login() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.is_anonymous is true or new.email is null or not (exists(select 1 from private.workspace_members where active and email=lower(new.email)) or exists(select 1 from private.personnel_intake_links where recipient_email=lower(new.email) and revoked_at is null and expires_at>now() and claimed_by is null and exists(select 1 from private.workspace_settings where theater_id=private.personnel_intake_links.theater_id and data->'theater'->>'current_season_id'=private.personnel_intake_links.season_id::text)) or exists(select 1 from private.platform_owner_reservations where email=lower(new.email) and bound_user_id is null)) then raise exception 'Company Management must issue your Loon access first' using errcode='42501';end if;
 return new;
end $$;
revoke all on function private.require_issued_login() from public,anon,authenticated;
create trigger require_issued_loon_login before insert on auth.users for each row execute function private.require_issued_login();
create function public.issue_personnel_login(t uuid,recipient_name text,recipient_email text,access_role text) returns jsonb language sql security invoker set search_path='' as $$select private.issue_personnel_login(t,recipient_name,recipient_email,access_role)$$;
create function public.get_my_onboarding() returns jsonb language sql security invoker set search_path='' as $$select private.get_my_onboarding()$$;
revoke all on function private.issue_personnel_login(uuid,text,text,text),public.issue_personnel_login(uuid,text,text,text),private.get_my_onboarding(),public.get_my_onboarding(),private.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) from public,anon;
grant execute on function private.issue_personnel_login(uuid,text,text,text),public.issue_personnel_login(uuid,text,text,text),private.get_my_onboarding(),public.get_my_onboarding(),private.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) to authenticated;
