-- Memberships and configuration are private; bounded RPCs enforce their own authorization.
create table private.workspace_members (
 id uuid primary key default gen_random_uuid(), theater_id uuid not null references public.theaters(id),
 email text not null check(email=lower(trim(email)) and email ~ '^[^ @]+@[^ @]+[.][^ @]+$'), user_id uuid references auth.users(id),
 roles text[] not null check(cardinality(roles)>0 and roles <@ array['Super Admin','Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming','Marketing','Development','Box Office','Director','Guest','Cast']),
 job_title text not null default '', active boolean not null default true, production_ids uuid[] not null default '{}', person_id uuid,
 delegated text[] not null default '{}' check(delegated <@ array['stage','calendar']), overrides jsonb not null default '{}', revision integer not null default 1,
 unique(theater_id,email), unique(theater_id,user_id), foreign key(theater_id,person_id) references public.people(theater_id,id)
);
create table private.account_settings(user_id uuid primary key references auth.users(id), data jsonb not null default '{}',revision integer not null default 1);
create table private.workspace_settings(theater_id uuid primary key references public.theaters(id),data jsonb not null,revision integer not null default 1);
create table private.template_applications(theater_id uuid not null references public.theaters(id),production_id uuid not null references public.productions(id),template_id text not null,event_id uuid not null references public.calendar_events(id),primary key(production_id,template_id));
create table private.settings_history(id uuid primary key default gen_random_uuid(),theater_id uuid references public.theaters(id),actor uuid not null,section text not null,changed_at timestamptz not null default now());
do $$ declare t text; begin foreach t in array array['workspace_members','account_settings','workspace_settings','template_applications','settings_history'] loop
 execute format('alter table private.%I enable row level security',t);
 execute format('revoke all on private.%I from public,anon,authenticated',t);
 execute format('create policy deny_direct on private.%I for all to authenticated using(false) with check(false)',t);
end loop; end $$;
create function private.verified_user() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null and deleted_at is null and is_anonymous is not true);
$$;
create function private.workspace_admin(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_thanos() or (private.verified_user() and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and 'Super Admin'=any(roles)));
$$;
create function private.workspace_permission(t uuid,m text,a text default 'view',p uuid default null) returns boolean language plpgsql stable security definer set search_path='' as $$
declare u private.workspace_members%rowtype; r text; level text:='none'; dept boolean;
begin
 if private.has_thanos() then return true;end if;
 if not private.verified_user() then return false;end if;
 select * into u from private.workspace_members where theater_id=t and user_id=auth.uid() and active;
 if not found then return false;end if;
 if 'Super Admin'=any(u.roles) then return true;end if;
 if u.overrides->>m='none' then return false;end if;
 dept:=exists(select 1 from unnest(u.roles) x where x not in ('Cast','Guest','Director'));
 if not dept and p is not null and not p=any(u.production_ids) then return false;end if;
 foreach r in array u.roles loop
  if m in ('productions','calendar') or r in ('Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming') or (r='Marketing' and m='personnel') or (r='Box Office' and m in ('personnel','venues')) or (r in ('Director','Guest') and m in ('stage','personnel','venues')) or (r='Cast' and m='stage') then
   if level='none' then level:='view';end if;
  end if;
  if m='stage' and r in ('Stage Manager','Assistant Stage Manager','Company Manager') then level:='edit';end if;
 end loop;
 level:=coalesce(u.overrides->>m,level);
 return level='edit' or (a='view' and level='view');
end $$;
create function private.can_configure(t uuid,s text) returns boolean language sql stable security definer set search_path='' as $$
 select private.workspace_admin(t) or (private.verified_user() and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and s=any(delegated)));
$$;
create function private.visible_person(t uuid,p uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_thanos() or (private.workspace_permission(t,'personnel') and (exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and exists(select 1 from unnest(roles) x where x not in ('Guest','Director','Cast'))) or exists(select 1 from public.production_credits c where c.person_id=p and private.workspace_permission(t,'personnel','view',c.production_id)))) or (private.verified_user() and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and person_id=p));
$$;
create function private.visible_event(t uuid,p uuid,e uuid,category text,state text) returns boolean language sql stable security definer set search_path='' as $$
 select private.has_thanos() or (private.workspace_permission(t,'calendar','view',p) and exists(select 1 from private.workspace_members u where u.theater_id=t and u.user_id=auth.uid() and u.active and (exists(select 1 from unnest(u.roles) r where r not in ('Cast','Guest','Director')) or (state='Published' and (u.roles && array['Guest','Director'] or category='Performance' or exists(select 1 from public.rehearsal_call_cast c where c.event_id=e and c.person_id=u.person_id))))));
$$;
insert into private.workspace_settings(theater_id,data) select t.id,jsonb_build_object('theater',jsonb_build_object('name',t.name,'timezone',t.timezone,'contact_email','','phone','','logo','','current_season_id',coalesce((select id::text from public.seasons where theater_id=t.id order by name desc limit 1),'')),'stage',jsonb_build_object('start','18:00','end','21:00','location','','departments',array['Scenic','Lighting','Audio','Costuming','Video','Props']),'templates','[{"id": "default-0", "name": "Programming and Painting", "anchor": "opening", "offset": -28, "duration": 28, "category": "Other", "department": "Production", "enabled": true}, {"id": "default-1", "name": "Build", "anchor": "opening", "offset": -56, "duration": 28, "category": "Other", "department": "Production", "enabled": true}, {"id": "default-2", "name": "Design Finalization", "anchor": "opening", "offset": -84, "duration": 28, "category": "Other", "department": "Production", "enabled": true}, {"id": "default-3", "name": "Tech Rehearsals", "anchor": "opening", "offset": -8, "duration": 7, "category": "Tech", "department": "Production", "enabled": true}, {"id": "default-4", "name": "Final Dress Rehearsal", "anchor": "opening", "offset": -1, "duration": 1, "category": "Rehearsal", "department": "Production", "enabled": true}, {"id": "default-5", "name": "Strike", "anchor": "closing", "offset": 7, "duration": 7, "category": "Strike", "department": "Production", "enabled": true}, {"id": "default-6", "name": "Load out & Changeover", "anchor": "closing", "offset": 14, "duration": 14, "category": "Load-in", "department": "Production", "enabled": true}, {"id": "default-7", "name": "Costume Build", "anchor": "opening", "offset": -56, "duration": 42, "category": "Other", "department": "Costuming", "enabled": true}, {"id": "default-8", "name": "Costume Final Fittings", "anchor": "opening", "offset": -14, "duration": 14, "category": "Other", "department": "Costuming", "enabled": true}]'::jsonb) from public.theaters t;
create function private.get_workspace(t uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); chosen uuid; u private.workspace_members%rowtype; cfg private.workspace_settings%rowtype; ac private.account_settings%rowtype; perms jsonb:='{}'; m text;
begin
 if not private.verified_user() then raise exception 'Verify your email before opening this workspace' using errcode='42501';end if;
 -- A reserved email binds once to the verified account. Subsequent email changes cannot transfer access.
 update private.workspace_members set user_id=uid where user_id is null and active and email=(select lower(email) from auth.users where id=uid);
 select coalesce(t,(select theater_id from private.workspace_members where user_id=uid and active order by theater_id limit 1),(select id from public.theaters where private.has_thanos() order by name limit 1)) into chosen;
 if chosen is not null and not (private.has_thanos() or exists(select 1 from private.workspace_members where theater_id=chosen and user_id=uid and active)) then raise exception 'No access to this theater' using errcode='42501';end if;
 select * into u from private.workspace_members where theater_id=chosen and user_id=uid and active;
 select * into cfg from private.workspace_settings where theater_id=chosen;
 select * into ac from private.account_settings where user_id=uid;
 foreach m in array array['productions','calendar','venues','personnel','stage'] loop perms:=perms||jsonb_build_object(m,case when private.workspace_permission(chosen,m,'edit') then 'edit' when private.workspace_permission(chosen,m) then 'view' else 'none' end);end loop;
 return jsonb_build_object('user_id',uid,'thanos',private.has_thanos(),'theater_id',chosen,'member',case when u.id is null then null else to_jsonb(u) end,'admin',private.workspace_admin(chosen),'delegated',coalesce(to_jsonb(u.delegated),'[]'),'permissions',perms,
 'theaters',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'timezone',timezone) order by name),'[]') from public.theaters where private.has_thanos() or id in (select theater_id from private.workspace_members where user_id=uid and active)),
 'account',coalesce(ac.data,'{}'),'account_revision',coalesce(ac.revision,0),
 'settings',case when cfg.theater_id is null then null else cfg.data||jsonb_build_object('theater_id',chosen,'revision',cfg.revision) end,
 'seasons',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name desc),'[]') from public.seasons where theater_id=chosen),
 'members',case when private.workspace_admin(chosen) then (select coalesce(jsonb_agg(to_jsonb(x) order by email),'[]') from private.workspace_members x where theater_id=chosen) else '[]'::jsonb end);
end $$;
create function private.save_account(payload jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare rev integer; clean jsonb;
begin
 if not private.verified_user() then raise exception 'Verified account required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,51));
 select revision into rev from private.account_settings where user_id=auth.uid();
 if coalesce(rev,0)<>expected then raise exception 'Your settings changed. Refresh before saving.';end if;
 if length(coalesce(payload->>'name',''))>200 or length(coalesce(payload->>'phone',''))>80 or length(coalesce(payload->>'photo',''))>700000 then raise exception 'Profile field is too long';end if;
 if coalesce(payload->>'photo','')<>'' and payload->>'photo' !~ '^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$' then raise exception 'Choose a JPG, PNG, or WebP photo';end if;
 if payload->>'landing' not in ('Productions','Schedule','Personnel','Callboard') or payload->>'calendar_view' not in ('calendar','list') or payload->>'personnel_view' not in ('tiles','list') or payload->>'time_format' not in ('12','24') then raise exception 'Invalid preference';end if;
 clean:=jsonb_build_object('name',trim(coalesce(payload->>'name','')),'phone',coalesce(payload->>'phone',''),'photo',coalesce(payload->>'photo',''),'landing',coalesce(payload->>'landing','Productions'),'calendar_view',coalesce(payload->>'calendar_view','calendar'),'personnel_view',coalesce(payload->>'personnel_view','tiles'),'time_format',coalesce(payload->>'time_format','12'));
 insert into private.account_settings(user_id,data) values(auth.uid(),clean) on conflict(user_id) do update set data=excluded.data,revision=private.account_settings.revision+1;
 return private.get_workspace();
end $$;
create function private.save_workspace(t uuid,section text,payload jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.workspace_settings%rowtype; item jsonb; v text; clean jsonb; sid uuid;
begin
 if auth.uid() is null or section not in ('theater','stage','templates') or not private.can_configure(t,case when section='templates' then 'calendar' else section end) then raise exception 'You cannot change these settings' using errcode='42501';end if;
 select * into cfg from private.workspace_settings where theater_id=t for update;
 if cfg.revision is distinct from expected then raise exception 'These settings changed. Refresh before saving.';end if;
 if section='theater' then
  if length(trim(coalesce(payload->>'name',''))) not between 1 and 200 then raise exception 'Enter a theater name';end if;
  if not exists(select 1 from pg_timezone_names where name=payload->>'timezone') then raise exception 'Choose a valid timezone';end if;
  sid:=nullif(payload->>'current_season_id','')::uuid;
  if sid is not null and not exists(select 1 from public.seasons where id=sid and theater_id=t) then raise exception 'Season belongs to another theater';end if;
  if length(coalesce(payload->>'logo',''))>700000 or (coalesce(payload->>'logo','')<>'' and payload->>'logo' !~ '^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/=]+$') then raise exception 'Choose a logo under 500 KB';end if;
  clean:=jsonb_build_object('name',trim(payload->>'name'),'timezone',payload->>'timezone','current_season_id',coalesce(sid::text,''),'contact_email',left(coalesce(payload->>'contact_email',''),320),'phone',left(coalesce(payload->>'phone',''),80),'logo',coalesce(payload->>'logo',''));
  update public.theaters set name=clean->>'name',timezone=clean->>'timezone' where id=t;
 elsif section='stage' then
  if coalesce(payload->>'start','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or coalesce(payload->>'end','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' or payload->>'end'<=payload->>'start' then raise exception 'Enter a valid same-day rehearsal time range';end if;
  if length(coalesce(payload->>'location',''))>300 or jsonb_typeof(payload->'departments') is distinct from 'array' then raise exception 'Invalid stage management settings';end if;
  for v in select jsonb_array_elements_text(payload->'departments') loop if v not in ('Scenic','Lighting','Audio','Costuming','Video','Props','SFX','Projection','Pyrotechnics','Cosmo','Conductor','Music') then raise exception 'Unknown report department';end if;end loop;
  clean:=jsonb_build_object('start',payload->>'start','end',payload->>'end','location',coalesce(payload->>'location',''),'departments',payload->'departments');
 else
  if jsonb_typeof(payload) is distinct from 'array' or jsonb_array_length(payload)>40 then raise exception 'Use at most 40 templates';end if;
  if (select count(*) from jsonb_array_elements(payload))<>(select count(distinct x->>'id') from jsonb_array_elements(payload)x) then raise exception 'Template IDs must be unique';end if;
  for item in select jsonb_array_elements(payload) loop
   if length(coalesce(item->>'id','')) not between 1 and 100 or length(trim(coalesce(item->>'name',''))) not between 1 and 200 or coalesce(item->>'anchor','') not in ('opening','closing') or coalesce(item->>'category','') not in ('Rehearsal','Tech','Load-in','Strike','Meeting','Other') or (item->>'offset')::integer not between -730 and 730 or (item->>'duration')::integer not between 1 and 365 or item->>'offset' is null or item->>'duration' is null then raise exception 'Check template name, category, offset, and duration';end if;
   perform (item->>'enabled')::boolean;
  end loop;clean:=payload;
 end if;
 update private.workspace_settings set data=jsonb_set(data,array[section],clean),revision=revision+1 where theater_id=t;
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),section);
 return private.get_workspace(t);
end $$;
create function private.save_member(t uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare prior private.workspace_members%rowtype; mid uuid:=coalesce(nullif(draft->>'id','')::uuid,gen_random_uuid()); em text:=lower(trim(draft->>'email')); assigned uuid; rs text[]; ps uuid[]; ds text[]; ov jsonb:=coalesce(draft->'overrides','{}'); target uuid; k text; val text;
begin
 if auth.uid() is null or not private.workspace_admin(t) then raise exception 'Administrator access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(t::text,52));
 select * into prior from private.workspace_members where id=mid for update;
 if found and prior.theater_id<>t then raise exception 'Wrong theater' using errcode='42501';end if;
 if coalesce(prior.revision,0)<>expected then raise exception 'This membership changed. Refresh before saving.';end if;
 if prior.user_id=auth.uid() or em=(select lower(email) from auth.users where id=auth.uid()) then raise exception 'You cannot edit your own access';end if;
 if prior.id is not null and em<>prior.email then raise exception 'Membership email cannot be reassigned';end if;
 select id into target from auth.users where lower(email)=em and email_confirmed_at is not null and deleted_at is null and is_anonymous is not true;
 if exists(select 1 from private.platform_access_grants where user_id=coalesce(prior.user_id,target)) then raise exception 'Platform owner access is managed separately';end if;
 select array_agg(value) into rs from jsonb_array_elements_text(draft->'roles');
 select coalesce(array_agg(value::uuid),'{}') into ps from jsonb_array_elements_text(draft->'production_ids');
 select coalesce(array_agg(value),'{}') into ds from jsonb_array_elements_text(draft->'delegated');
 if 'Super Admin'=any(rs) and coalesce(draft->>'job_title','') not in ('Artistic Director','Managing Director','IT') then raise exception 'Super Admin requires Artistic Director, Managing Director, or IT';end if;
 if ds<>'{}' and not (rs && array['Production','Stage Manager','Assistant Stage Manager','Company Manager','Production Manager','Lighting','Audio','Video','Scenic','Costuming']) then raise exception 'Delegate department settings to production department staff';end if;
 foreach assigned in array ps loop if not exists(select 1 from public.productions where id=assigned and theater_id=t) then raise exception 'Assigned production belongs to another theater';end if;end loop;
 for k,val in select key,value from jsonb_each_text(ov) loop
  if k not in ('productions','calendar','venues','personnel','stage') or val not in ('none','view','edit') then raise exception 'Unknown permission';end if;
 end loop;
 insert into private.workspace_members(id,theater_id,email,user_id,roles,job_title,active,production_ids,person_id,delegated,overrides)
 values(mid,t,em,target,rs,left(coalesce(draft->>'job_title',''),200),coalesce((draft->>'active')::boolean,true),ps,nullif(draft->>'person_id','')::uuid,ds,ov)
 on conflict(id) do update set roles=excluded.roles,job_title=excluded.job_title,active=excluded.active,production_ids=excluded.production_ids,person_id=excluded.person_id,delegated=excluded.delegated,overrides=excluded.overrides,revision=private.workspace_members.revision+1;
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),'users');
 return private.get_workspace(t);
end $$;
create function private.apply_templates(t uuid,p uuid,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare cfg private.workspace_settings%rowtype; prod public.productions%rowtype; item jsonb; starts date; eid uuid; n integer:=0; tz text;
begin
 if auth.uid() is null or not private.can_configure(t,'calendar') or not private.workspace_permission(t,'calendar','edit',p) then raise exception 'Calendar edit and template access required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p::text,53));
 select * into cfg from private.workspace_settings where theater_id=t;
 if cfg.revision is distinct from expected then raise exception 'Templates changed. Refresh the preview.';end if;
 select * into prod from public.productions where id=p and theater_id=t;
 if not found then raise exception 'Production not found';end if;
 select timezone into tz from public.theaters where id=t;
 for item in select jsonb_array_elements(cfg.data->'templates') loop
  if coalesce((item->>'enabled')::boolean,false) and not exists(select 1 from private.template_applications where production_id=p and template_id=item->>'id') then
   starts:=(case when item->>'anchor'='opening' then prod.opening_date else prod.closing_date end)+(item->>'offset')::integer;
   insert into public.calendar_events(theater_id,production_id,title,category,start,"end",event_details,call_status,is_demo) values(t,p,item->>'name',item->>'category',starts::timestamp at time zone tz,(starts+(item->>'duration')::integer)::timestamp at time zone tz,coalesce(item->>'department','')||' · Calendar template','Draft',false) returning id into eid;
   insert into private.template_applications values(t,p,item->>'id',eid);n:=n+1;
  end if;
 end loop;
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),'apply calendar templates');
 return jsonb_build_object('created',n);
end $$;
-- Exposed functions are invoker wrappers. All privileged work is in private with explicit checks.
create function public.get_workspace(t uuid default null) returns jsonb language sql security invoker set search_path='' as $$select private.get_workspace(t)$$;
create function public.save_account(payload jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_account(payload,expected)$$;
create function public.save_workspace(t uuid,section text,payload jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_workspace(t,section,payload,expected)$$;
create function public.save_member(t uuid,draft jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_member(t,draft,expected)$$;
create function public.apply_templates(t uuid,p uuid,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.apply_templates(t,p,expected)$$;
do $$ declare f record;begin
 for f in select n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname in ('verified_user','workspace_admin','workspace_permission','can_configure','visible_person','visible_event','get_workspace','save_account','save_workspace','save_member','apply_templates') loop
 execute format('revoke all on function %I.%I(%s) from public,anon',f.nspname,f.proname,f.args);
 execute format('grant execute on function %I.%I(%s) to authenticated',f.nspname,f.proname,f.args);
 end loop;
end $$;
-- Existing owner policies remain. Add scoped reads and action-specific writes.
create policy member_read on public.theaters for select to authenticated using(private.workspace_permission(id,'productions'));
create policy member_read on public.seasons for select to authenticated using(private.workspace_permission(theater_id,'productions'));
create policy member_read on public.productions for select to authenticated using(private.workspace_permission(theater_id,'productions','view',id));
create policy member_update on public.productions for update to authenticated using(private.workspace_permission(theater_id,'productions','edit',id)) with check(private.workspace_permission(theater_id,'productions','edit',id));
create policy member_read on public.venues for select to authenticated using(private.workspace_permission(theater_id,'venues') or private.workspace_permission(theater_id,'stage','edit'));
create policy member_read on public.people for select to authenticated using(private.visible_person(theater_id,id));
create policy member_update on public.people for update to authenticated using(private.workspace_permission(theater_id,'personnel','edit') and private.visible_person(theater_id,id)) with check(private.workspace_permission(theater_id,'personnel','edit') and private.visible_person(theater_id,id));
create policy member_read on public.production_credits for select to authenticated using(private.visible_person(theater_id,person_id) and private.workspace_permission(theater_id,'productions','view',production_id));
create policy member_read on public.calendar_events for select to authenticated using(private.visible_event(theater_id,production_id,id,category,call_status));
create policy member_insert on public.calendar_events for insert to authenticated with check(private.workspace_permission(theater_id,'calendar','edit',production_id) or (category='Rehearsal' and private.workspace_permission(theater_id,'stage','edit',production_id)));
create policy member_update on public.calendar_events for update to authenticated using(private.workspace_permission(theater_id,'calendar','edit',production_id) or (category='Rehearsal' and private.workspace_permission(theater_id,'stage','edit',production_id))) with check(private.workspace_permission(theater_id,'calendar','edit',production_id) or (category='Rehearsal' and private.workspace_permission(theater_id,'stage','edit',production_id)));
create policy member_read on public.rehearsal_calls for select to authenticated using(private.workspace_permission(theater_id,'stage','view',production_id) and exists(select 1 from public.calendar_events e where e.id=event_id));
create policy member_read on public.rehearsal_call_cast for select to authenticated using(private.workspace_permission(theater_id,'stage','view',production_id) and exists(select 1 from public.calendar_events e where e.id=event_id));
do $$ declare t text;begin foreach t in array array['rehearsal_calls','rehearsal_call_cast'] loop
 execute format('create policy member_insert on public.%I for insert to authenticated with check(private.workspace_permission(theater_id,''stage'',''edit'',production_id))',t);
 execute format('create policy member_update on public.%I for update to authenticated using(private.workspace_permission(theater_id,''stage'',''edit'',production_id)) with check(private.workspace_permission(theater_id,''stage'',''edit'',production_id))',t);
 execute format('create policy member_delete on public.%I for delete to authenticated using(private.workspace_permission(theater_id,''stage'',''edit'',production_id))',t);
end loop;end $$;
create policy members_headshots_read on storage.objects for select to authenticated using(bucket_id='personnel-headshots' and exists(select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2]));
create policy members_headshots_insert on storage.objects for insert to authenticated with check(bucket_id='personnel-headshots' and exists(select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2] and private.workspace_permission(p.theater_id,'personnel','edit')));
create policy members_headshots_cleanup on storage.objects for delete to authenticated using(bucket_id='personnel-headshots' and exists(select 1 from public.people p where p.theater_id::text=(storage.foldername(name))[1] and p.id::text=(storage.foldername(name))[2] and private.workspace_permission(p.theater_id,'personnel','edit')));

create or replace function public.save_rehearsal_call(draft jsonb) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 call_id uuid:=(draft->>'id')::uuid; production uuid:=(draft->>'production_id')::uuid;
 p public.productions%rowtype; e public.calendar_events%rowtype; prior public.calendar_events%rowtype;
 member uuid; members uuid[]; expected timestamptz:=(draft->>'expected_updated_at')::timestamptz;
 work_label text:=trim(draft->>'work'); state text:=draft->>'call_status'; begin_at timestamptz:=(draft->>'start')::timestamptz; end_at timestamptz:=(draft->>'end')::timestamptz; venue uuid:=(draft->>'venue_id')::uuid;
begin
 if not exists(select 1 from public.productions where id=production and private.workspace_permission(theater_id,'stage','edit',id)) then raise exception 'Cast scheduling edit access required' using errcode='42501';end if;
 if call_id is null or production is null or begin_at is null or end_at is null or end_at<=begin_at then raise exception 'Enter a valid rehearsal time range';end if;
 if state is null or state not in ('Published','Canceled') then raise exception 'Invalid call state';end if;
 if work_label is null or length(work_label) not between 1 and 500 then raise exception 'Enter what will be rehearsed';end if;
 if venue is null and length(trim(coalesce(draft->>'location','')))=0 then raise exception 'Choose a venue or enter a rehearsal location';end if;
 select * into p from public.productions where id=production;
 if not found then raise exception 'Production not found';end if;
 select array_agg(distinct value::uuid order by value::uuid) into members from jsonb_array_elements_text(draft->'person_ids');
 if coalesce(cardinality(members),0)=0 then raise exception 'Select at least one cast member';end if;
 foreach member in array members loop
  if not exists(select 1 from public.production_credits where theater_id=p.theater_id and production_id=p.id and person_id=member and credit_type='Cast') then raise exception 'Selected person is not cast in this production';end if;
 end loop;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(call_id::text,0));
 if state='Published' then
  foreach member in array members loop
   perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(member::text,1));
   if exists(select 1 from public.rehearsal_call_cast c join public.calendar_events ce on ce.id=c.event_id where c.person_id=member and ce.id<>call_id and ce.call_status='Published' and ce.start<end_at and ce."end">begin_at) then raise exception 'A selected cast member already has a rehearsal call at this time';end if;
  end loop;
 end if;
 select * into prior from public.calendar_events where id=call_id for update;
 if found then
  if prior.production_id<>production or prior.category<>'Rehearsal' or not exists(select 1 from public.rehearsal_calls where event_id=call_id) then raise exception 'Rehearsal call does not match';end if;
  if expected is null then
   if prior.created_by is distinct from auth.uid() then raise exception 'Call already exists';end if;
   e:=prior; -- A retry of a completed create returns the same call, never a duplicate.
  else
   if prior.updated_at<>expected then raise exception 'This call changed. Refresh before editing again.';end if;
   update public.calendar_events set title=work_label,start=begin_at,"end"=end_at,venue_id=venue,event_details=coalesce(draft->>'notes',''),call_status=state where id=call_id returning * into e;
  end if;
 elsif expected is not null then raise exception 'This call no longer exists. Refresh before editing again.';
 else
  insert into public.calendar_events(id,theater_id,production_id,venue_id,title,category,start,"end",event_details,call_status,is_demo)
   values(call_id,p.theater_id,p.id,venue,work_label,'Rehearsal',begin_at,end_at,coalesce(draft->>'notes',''),state,false) returning * into e;
 end if;
 if prior.id is null or expected is not null then
  insert into public.rehearsal_calls(event_id,theater_id,production_id,work,act,scene,location)
   values(e.id,p.theater_id,p.id,work_label,trim(coalesce(draft->>'act','')),trim(coalesce(draft->>'scene','')),trim(coalesce(draft->>'location','')))
   on conflict(event_id) do update set work=excluded.work,act=excluded.act,scene=excluded.scene,location=excluded.location;
  delete from public.rehearsal_call_cast where event_id=e.id;
  insert into public.rehearsal_call_cast(event_id,person_id,theater_id,production_id) select e.id,unnest(members),p.theater_id,p.id;
 end if;
 return jsonb_build_object('event',to_jsonb(e),'call',(select to_jsonb(c) from public.rehearsal_calls c where event_id=e.id),'cast',(select coalesce(jsonb_agg(c),'[]') from public.rehearsal_call_cast c where event_id=e.id));
end $$;
revoke all on function public.save_rehearsal_call(jsonb) from public,anon;
grant execute on function public.save_rehearsal_call(jsonb) to authenticated;
