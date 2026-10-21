-- Public intake has a narrow API schema; it never grants anonymous access to private.
create schema intake_api;
revoke all on schema intake_api from public;
grant usage on schema intake_api to anon,authenticated;
alter table private.personnel_contacts add column phone text not null default '' check(length(phone)<=80);
create or replace function private.get_personnel_contact(p uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid; result jsonb;
begin
 select theater_id into t from public.people where id=p;
 if t is null or not private.can_manage_personnel_contact(t) then raise exception 'Stage management or theater administrator access required' using errcode='42501';end if;
 select to_jsonb(c)-array['person_id','theater_id','updated_by','updated_at'] into result from private.personnel_contacts c where person_id=p and theater_id=t;
 return coalesce(result,jsonb_build_object('email','','phone','','address_line_1','','address_line_2','','city','','state','','zip','','emergency_contact_name','','emergency_contact_phone','','revision',0));
end $$;
create or replace function private.save_personnel_contact(p uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid; current_revision integer; clean jsonb:='{}'; key text; value text; max_length integer;
begin
 select theater_id into t from public.people where id=p;
 if t is null or not private.can_manage_personnel_contact(t) then raise exception 'Stage management or theater administrator access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' then raise exception 'Supply contact information fields';end if;
 if expected is null or expected<0 then raise exception 'Refresh contact information before saving';end if;
 for key in select jsonb_object_keys(draft) loop
 if key<>all(array['email','phone','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone']) then raise exception 'Unknown contact field: %',key;end if;
 end loop;
 foreach key in array array['email','phone','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone'] loop
 if not draft ? key or jsonb_typeof(draft->key) is distinct from 'string' then raise exception 'Supply a text value for %',key;end if;
 value:=trim(draft->>key);
 max_length:=case key when 'email' then 254 when 'phone' then 80 when 'address_line_1' then 300 when 'address_line_2' then 300 when 'city' then 120 when 'state' then 120 when 'zip' then 32 when 'emergency_contact_name' then 200 else 80 end;
 if length(value)>max_length then raise exception '% is too long',key;end if;
 if key='email' and value<>'' and value !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Enter a valid email address';end if;
 clean:=clean||jsonb_build_object(key,value);
 end loop;
 perform pg_advisory_xact_lock(hashtextextended(p::text,73));
 select revision into current_revision from private.personnel_contacts where person_id=p;
 if coalesce(current_revision,0)<>expected then raise exception 'Contact information changed. Cancel, refresh it and try again.';end if;
 insert into private.personnel_contacts(person_id,theater_id,email,phone,address_line_1,address_line_2,city,state,zip,emergency_contact_name,emergency_contact_phone,updated_by)
 values(p,t,clean->>'email',clean->>'phone',clean->>'address_line_1',clean->>'address_line_2',clean->>'city',clean->>'state',clean->>'zip',clean->>'emergency_contact_name',clean->>'emergency_contact_phone',auth.uid())
 on conflict(person_id) do update set email=excluded.email,phone=excluded.phone,address_line_1=excluded.address_line_1,address_line_2=excluded.address_line_2,city=excluded.city,state=excluded.state,zip=excluded.zip,emergency_contact_name=excluded.emergency_contact_name,emergency_contact_phone=excluded.emergency_contact_phone,revision=private.personnel_contacts.revision+1,updated_at=now(),updated_by=auth.uid();
 -- Record who changed contacts without copying sensitive values into general history.
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),'personnel_contacts');
 return private.get_personnel_contact(p);
end $$;

alter table public.people add column profile_avatar text check(profile_avatar in ('bird-00','bird-01','bird-02','bird-03','bird-04','bird-05','bird-06','bird-07','bird-08','bird-09','bird-10','bird-11','bird-12','bird-13'));
alter table public.people add column intake_headshot boolean not null default false;
create table public.personnel_seasons (
 theater_id uuid not null,person_id uuid not null,season_id uuid not null,
 primary key(person_id,season_id),foreign key(theater_id,person_id) references public.people(theater_id,id) on delete cascade,
 foreign key(theater_id,season_id) references public.seasons(theater_id,id)
);
alter table public.personnel_seasons enable row level security;
revoke all on public.personnel_seasons from public,anon,authenticated;
grant select on public.personnel_seasons to authenticated;
create policy personnel_seasons_read on public.personnel_seasons for select to authenticated using(private.visible_person(theater_id,person_id));
create table private.personnel_intake_links (
 id uuid primary key default gen_random_uuid(),theater_id uuid not null references public.theaters(id),season_id uuid not null,
 token_hash text not null unique,recipient_name text not null,recipient_email text not null default '',
 created_at timestamptz not null default now(),created_by uuid not null references auth.users(id),expires_at timestamptz not null default now()+interval '14 days',revoked_at timestamptz,
 foreign key(theater_id,season_id) references public.seasons(theater_id,id)
);
create table private.personnel_intake_submissions (
 id uuid primary key default gen_random_uuid(),link_id uuid not null unique references private.personnel_intake_links(id),theater_id uuid not null,season_id uuid not null,
 request_id uuid not null,payload_hash text not null,payload jsonb not null,status text not null default 'Pending' check(status in ('Pending','Approved','Rejected')),
 submitted_at timestamptz not null default now(),revision integer not null default 1,reviewed_at timestamptz,reviewed_by uuid references auth.users(id),review_note text not null default '',person_id uuid,
 foreign key(theater_id,season_id) references public.seasons(theater_id,id),foreign key(theater_id,person_id) references public.people(theater_id,id)
);
create index intake_queue_idx on private.personnel_intake_submissions(theater_id,status,submitted_at);
create table private.personnel_intake_media (
 person_id uuid primary key,theater_id uuid not null,headshot text not null default '',resume text not null default '',resume_name text not null default '',
 foreign key(theater_id,person_id) references public.people(theater_id,id) on delete cascade
);
do $$declare t text;begin foreach t in array array['personnel_intake_links','personnel_intake_submissions','personnel_intake_media'] loop
 execute format('alter table private.%I enable row level security',t);execute format('revoke all on private.%I from public,anon,authenticated',t);
 execute format('create policy deny_direct on private.%I for all to authenticated using(false) with check(false)',t);
 end loop;end $$;
create function private.can_manage_intake(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.verified_user() and (private.workspace_admin(t) or (private.workspace_permission(t,'stage','edit') and private.workspace_permission(t,'personnel') and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and 'Company Manager'=any(roles))));
$$;
revoke all on function private.can_manage_intake(uuid) from public,anon,authenticated;
create function private.clean_intake(d jsonb,t uuid,s uuid) returns jsonb language plpgsql security invoker set search_path='' as $$
declare k text;v text;maximum integer;clean jsonb:='{}';contacts jsonb:='{}';a jsonb;assignments jsonb:='[]';seen text[]:='{}';identity text;bytes bytea;
begin
 if jsonb_typeof(d) is distinct from 'object' or octet_length(d::text)>4000000 then raise exception 'Invalid or oversized submission';end if;
 for k in select jsonb_object_keys(d) loop if k<>all(array['full_name','known_as','area','job_title','department','bio','favorite_shakespeare','unions','other_union','intern','contacts','assignments','avatar','headshot','resume','resume_name','consent']) then raise exception 'Unknown intake field: %',k;end if;end loop;
 foreach k in array array['full_name','known_as','area','job_title','department','bio','favorite_shakespeare','other_union','avatar','headshot','resume','resume_name'] loop
 if jsonb_typeof(d->k) is distinct from 'string' then raise exception 'Supply a text value for %',k;end if;
 v:=trim(d->>k);maximum:=case k when 'bio' then 10000 when 'headshot' then 700000 when 'resume' then 2800000 when 'department' then 120 else 200 end;
 if length(v)>maximum then raise exception '% is too long',k;end if;clean:=clean||jsonb_build_object(k,v);
 end loop;
 if clean->>'full_name'='' then raise exception 'Full name is required';end if;
 if clean->>'area' not in ('Cast','Creative','Admin') or clean->>'avatar' not in ('bird-00','bird-01','bird-02','bird-03','bird-04','bird-05','bird-06','bird-07','bird-08','bird-09','bird-10','bird-11','bird-12','bird-13') then raise exception 'Choose your area and profile image';end if;
 if d->'consent' is distinct from 'true'::jsonb or jsonb_typeof(d->'intern') is distinct from 'boolean' then raise exception 'Confirm consent and intern status';end if;
 clean:=clean||jsonb_build_object('consent',true,'intern',d->'intern');
 if jsonb_typeof(d->'contacts') is distinct from 'object' then raise exception 'Contact information is required';end if;
 for k in select jsonb_object_keys(d->'contacts') loop if k<>all(array['email','phone','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone']) then raise exception 'Unknown contact field: %',k;end if;end loop;
 foreach k in array array['email','phone','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone'] loop
 if jsonb_typeof(d->'contacts'->k) is distinct from 'string' then raise exception 'Supply text for %',k;end if;v:=trim(d->'contacts'->>k);
 maximum:=case k when 'email' then 254 when 'phone' then 80 when 'address_line_1' then 300 when 'address_line_2' then 300 when 'city' then 120 when 'state' then 120 when 'zip' then 32 when 'emergency_contact_name' then 200 else 80 end;
 if length(v)>maximum then raise exception '% is too long',k;end if;contacts:=contacts||jsonb_build_object(k,v);
 end loop;
 if contacts->>'email' !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Enter a valid email address';end if;clean:=clean||jsonb_build_object('contacts',contacts);
 if jsonb_typeof(d->'unions') is distinct from 'array' then raise exception 'Choose union affiliations';end if;
 if jsonb_array_length(d->'unions')>8 or exists(select 1 from jsonb_array_elements(d->'unions') u where jsonb_typeof(u)<>'string' or u#>>'{}' not in ('AEA','SAG-AFTRA','IATSE','AGMA','AGVA','USA 829','SDC','Other')) then raise exception 'Invalid union affiliation';end if;
 if d->'unions' ? 'Other' and clean->>'other_union'='' then raise exception 'Specify your other union';end if;clean:=clean||jsonb_build_object('unions',d->'unions');
 if jsonb_typeof(d->'assignments') is distinct from 'array' then raise exception 'Supply production roles';end if;
 if clean->>'area'='Admin' then
 if clean->>'department'='' or clean->>'job_title'='' then raise exception 'Department and job title are required';end if;
 else
 if jsonb_array_length(d->'assignments') not between 1 and 20 then raise exception 'Add between 1 and 20 production roles';end if;
 for a in select value from jsonb_array_elements(d->'assignments') loop
 if jsonb_typeof(a) is distinct from 'object' or jsonb_typeof(a->'role') is distinct from 'string' or jsonb_typeof(a->'production_id') is distinct from 'string' then raise exception 'Choose a show and enter a role';end if;
 if exists(select 1 from jsonb_object_keys(a) x where x not in ('role','production_id')) then raise exception 'Unexpected production role field';end if;
 if length(trim(a->>'role')) not between 1 and 200 or not exists(select 1 from public.productions where id::text=a->>'production_id' and theater_id=t and season_id=s) then raise exception 'Each show must belong to this theater and season and include a role';end if;
 identity:=a->>'production_id'||':'||lower(trim(a->>'role'));if identity=any(seen) then raise exception 'Remove the duplicate production role';end if;seen:=array_append(seen,identity);
 assignments:=assignments||jsonb_build_array(jsonb_build_object('production_id',a->>'production_id','role',trim(a->>'role')));
 end loop;end if;clean:=clean||jsonb_build_object('assignments',assignments);
 if clean->>'headshot'<>'' then
 if clean->>'headshot' !~ '^data:image/jpeg;base64,[A-Za-z0-9+/]+={0,2}$' then raise exception 'Choose a JPEG headshot';end if;
 bytes:=decode(substr(clean->>'headshot',24),'base64');if octet_length(bytes)<4 or octet_length(bytes)>524288 or substr(bytes,1,3)<>decode('ffd8ff','hex') then raise exception 'Invalid headshot file';end if;
 end if;
 if clean->>'resume'<>'' then
 if clean->>'resume' !~ '^data:application/pdf;base64,[A-Za-z0-9+/]+={0,2}$' or clean->>'resume_name'='' then raise exception 'Choose a PDF resume';end if;
 bytes:=decode(substr(clean->>'resume',29),'base64');if octet_length(bytes)>2097152 or convert_from(substr(bytes,1,5),'UTF8')<>'%PDF-' then raise exception 'Invalid PDF resume';end if;
 end if;return clean;
end $$;
revoke all on function private.clean_intake(jsonb,uuid,uuid) from public,anon,authenticated;
create function private.create_personnel_intake(t uuid,recipient_name text,recipient_email text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare season uuid;raw text;lid uuid;
begin
 if not private.can_manage_intake(t) then raise exception 'Company Management access required' using errcode='42501';end if;
 if length(trim(recipient_name)) not between 1 and 200 or length(recipient_email)>254 or (recipient_email<>'' and trim(recipient_email) !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$') then raise exception 'Enter a recipient name and valid optional email';end if;
 select nullif(data->'theater'->>'current_season_id','')::uuid into season from private.workspace_settings where theater_id=t;
 if season is null or not exists(select 1 from public.seasons where id=season and theater_id=t) then raise exception 'Set the theater current season in Settings first';end if;
 raw:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
 insert into private.personnel_intake_links(theater_id,season_id,token_hash,recipient_name,recipient_email,created_by) values(t,season,encode(sha256(convert_to(raw,'UTF8')),'hex'),trim(recipient_name),lower(trim(recipient_email)),auth.uid()) returning id into lid;
 return jsonb_build_object('id',lid,'token',raw,'expires_at',now()+interval '14 days');
end $$;
create function intake_api.get_personnel_intake(token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;result jsonb;used boolean;
begin
 if token !~ '^[a-f0-9]{64}$' or token is null then raise exception 'This intake link is unavailable. Ask Company Management for a new link.';end if;
 select * into l from private.personnel_intake_links where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex');
 if not found or l.revoked_at is not null or l.expires_at<=now() then raise exception 'This intake link is unavailable or expired. Ask Company Management for a new link.';end if;
 used:=exists(select 1 from private.personnel_intake_submissions where link_id=l.id);
 if not used and not exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text) then raise exception 'The theater current season changed. Ask Company Management for a new link.';end if;
 return jsonb_build_object('theater_name',(select name from public.theaters where id=l.theater_id),'season_name',(select name from public.seasons where id=l.season_id),'recipient_name',l.recipient_name,'submitted',used,'productions',case when used then '[]'::jsonb else (select coalesce(jsonb_agg(jsonb_build_object('id',id,'title',title) order by title),'[]') from public.productions where theater_id=l.theater_id and season_id=l.season_id) end);
end $$;
create function intake_api.submit_personnel_intake(token text,payload jsonb,request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare l private.personnel_intake_links%rowtype;existing private.personnel_intake_submissions%rowtype;clean jsonb;hash text;receipt uuid;
begin
 if token is null or token !~ '^[a-f0-9]{64}$' or request_id is null then raise exception 'This intake link is unavailable';end if;
 select * into l from private.personnel_intake_links where token_hash=encode(sha256(convert_to(token,'UTF8')),'hex') for update;
 if not found or l.revoked_at is not null or l.expires_at<=now() then raise exception 'This intake link is unavailable or expired';end if;
 clean:=private.clean_intake(payload,l.theater_id,l.season_id);hash:=encode(sha256(convert_to(clean::text,'UTF8')),'hex');
 select * into existing from private.personnel_intake_submissions where link_id=l.id;
 if found then if existing.request_id=request_id and existing.payload_hash=hash then return jsonb_build_object('receipt',existing.id,'status','Pending review');else raise exception 'This link has already been submitted. Contact Company Management for another link.';end if;end if;
 if l.recipient_email<>'' and l.recipient_email<>lower(clean->'contacts'->>'email') then raise exception 'Use the email address this invitation was issued for';end if;
 if not exists(select 1 from private.workspace_settings where theater_id=l.theater_id and data->'theater'->>'current_season_id'=l.season_id::text) then raise exception 'The theater current season has changed. Ask Company Management for a new link.';end if;
 insert into private.personnel_intake_submissions(link_id,theater_id,season_id,request_id,payload_hash,payload) values(l.id,l.theater_id,l.season_id,request_id,hash,clean) returning id into receipt;
 return jsonb_build_object('receipt',receipt,'status','Pending review');
end $$;
revoke all on function intake_api.get_personnel_intake(text),intake_api.submit_personnel_intake(text,jsonb,uuid) from public;
grant execute on function intake_api.get_personnel_intake(text),intake_api.submit_personnel_intake(text,jsonb,uuid) to anon,authenticated;
create function public.get_personnel_intake(token text) returns jsonb language sql security invoker set search_path='' as $$select intake_api.get_personnel_intake(token)$$;
create function public.submit_personnel_intake(token text,payload jsonb,request_id uuid) returns jsonb language sql security invoker set search_path='' as $$select intake_api.submit_personnel_intake(token,payload,request_id)$$;
revoke all on function public.get_personnel_intake(text),public.submit_personnel_intake(text,jsonb,uuid) from public;
grant execute on function public.get_personnel_intake(text),public.submit_personnel_intake(text,jsonb,uuid) to anon,authenticated;
create function private.get_company_management(t uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.can_manage_intake(t) then raise exception 'Company Management access required' using errcode='42501';end if;
 return jsonb_build_object('pending_count',(select count(*) from private.personnel_intake_submissions where theater_id=t and status='Pending'),
 'links',(select coalesce(jsonb_agg(x order by x.created_at desc),'[]') from (select l.id,l.recipient_name,l.recipient_email,s.name season_name,l.created_at,l.expires_at,l.revoked_at,exists(select 1 from private.personnel_intake_submissions where link_id=l.id) submitted from private.personnel_intake_links l join public.seasons s on s.id=l.season_id where l.theater_id=t order by l.created_at desc limit 100) x),
 'submissions',(select coalesce(jsonb_agg(x order by case when x.status='Pending' then 0 else 1 end,x.submitted_at desc),'[]') from (select q.id,q.payload->>'full_name' full_name,q.payload->'contacts'->>'email' email,q.payload->>'area' area,q.status,q.season_id,s.name season_name,q.submitted_at,q.revision,q.review_note from private.personnel_intake_submissions q join public.seasons s on s.id=q.season_id where q.theater_id=t order by case when q.status='Pending' then 0 else 1 end,q.submitted_at desc limit 200) x),
 'people',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'display_name',p.display_name,'email',coalesce(c.email,''),'updated_at',p.updated_at,'contact_revision',coalesce(c.revision,0)) order by p.display_name),'[]') from public.people p left join private.personnel_contacts c on c.person_id=p.id where p.theater_id=t));
end $$;
create function private.get_intake_submission(submission uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare q private.personnel_intake_submissions%rowtype;
begin
 select * into q from private.personnel_intake_submissions where id=submission;
 if not found or not private.can_manage_intake(q.theater_id) then raise exception 'Company Management access required' using errcode='42501';end if;
 return (to_jsonb(q)-array['request_id','payload_hash','link_id','reviewed_by'])||jsonb_build_object('full_name',q.payload->>'full_name','email',q.payload->'contacts'->>'email','area',q.payload->>'area','season_name',(select name from public.seasons where id=q.season_id));
end $$;
create function private.revoke_personnel_intake(link uuid) returns void language plpgsql security definer set search_path='' as $$
declare t uuid;
begin select theater_id into t from private.personnel_intake_links where id=link;
 if t is null or not private.can_manage_intake(t) then raise exception 'Company Management access required' using errcode='42501';end if;
 update private.personnel_intake_links set revoked_at=coalesce(revoked_at,now()) where id=link;
end $$;
create function private.review_personnel_intake(submission uuid,decision text,expected integer,person uuid default null,person_expected timestamptz default null,contact_expected integer default 0,allow_duplicate boolean default false,note text default '') returns jsonb language plpgsql security definer set search_path='' as $$
declare q private.personnel_intake_submissions%rowtype;d jsonb;pid uuid;old public.people%rowtype;a jsonb;kind text;contact_revision integer;duplicate_found boolean;
begin
 select * into q from private.personnel_intake_submissions where id=submission;
 if not found or not private.can_manage_intake(q.theater_id) then raise exception 'Company Management access required' using errcode='42501';end if;
 select * into q from private.personnel_intake_submissions where id=submission for update;
 if decision not in ('approve','reject') or decision is null or length(note)>2000 then raise exception 'Choose approve or reject with a note up to 2000 characters';end if;
 if q.status<>'Pending' then
 if (q.status='Approved' and decision='approve') or (q.status='Rejected' and decision='reject') then return jsonb_build_object('status',q.status,'person_id',q.person_id);end if;
 raise exception 'This submission has already been reviewed';end if;
 if expected is null or expected<>q.revision then raise exception 'This submission changed. Refresh before reviewing.';end if;
 if decision='reject' then
 if trim(note)='' then raise exception 'Enter a reason for rejection';end if;
 update private.personnel_intake_submissions set status='Rejected',reviewed_at=now(),reviewed_by=auth.uid(),review_note=trim(note),revision=revision+1 where id=submission;
 return jsonb_build_object('status','Rejected');end if;
 -- Never silently move a submission into a different season after the manager's review.
 if not exists(select 1 from private.workspace_settings where theater_id=q.theater_id and data->'theater'->>'current_season_id'=q.season_id::text) then raise exception 'This submission is for a different season. Restore that season in Settings or issue a new link before approval.';end if;
 d:=private.clean_intake(q.payload,q.theater_id,q.season_id);kind:=case d->>'area' when 'Admin' then 'Staff' else d->>'area' end;
 if person is null then
 select exists(select 1 from public.people p left join private.personnel_contacts c on c.person_id=p.id where p.theater_id=q.theater_id and (lower(trim(p.display_name))=lower(d->>'full_name') or lower(c.email)=lower(d->'contacts'->>'email'))) into duplicate_found;
 if duplicate_found and allow_duplicate is not true then raise exception 'Possible existing person found. Match the record or confirm this is a different person.';end if;
 insert into public.people(theater_id,source_key,display_name,person_types) values(q.theater_id,'intake:'||q.id::text,d->>'full_name',array[kind]) returning id into pid;
 else
 select * into old from public.people where id=person and theater_id=q.theater_id for update;
 if not found then raise exception 'Choose a person from this theater';end if;
 if person_expected is null or old.updated_at<>person_expected then raise exception 'The personnel profile changed. Refresh and review the match again.';end if;pid:=person;
 perform pg_advisory_xact_lock(hashtextextended(pid::text,73));select revision into contact_revision from private.personnel_contacts where person_id=pid;
 if contact_expected is null or coalesce(contact_revision,0)<>contact_expected then raise exception 'Contact information changed. Refresh and review the match again.';end if;
 end if;
 update public.people set display_name=d->>'full_name',first_name=split_part(d->>'full_name',' ',1),last_name=case when strpos(d->>'full_name',' ')>0 then substr(d->>'full_name',strpos(d->>'full_name',' ')+1) else '' end,known_as=d->>'known_as',person_types=array(select distinct x from unnest(person_types||array[kind]) x),job_title=d->>'job_title',departments=case when d->>'department'='' then '{}'::text[] else array[d->>'department'] end,area=d->>'area',bio=d->>'bio',favorite_shakespeare=d->>'favorite_shakespeare',unions=array(select case when v='Other' then d->>'other_union' else v end from jsonb_array_elements_text(d->'unions') v),intern=(d->>'intern')::boolean,is_demo=false,profile_avatar=d->>'avatar',intake_headshot=d->>'headshot'<>'',headshot_kind=null,headshot_path=null,headshot_source_url=null,headshot_credit=null,headshot_license=null,headshot_license_url=null where id=pid;
 perform private.save_personnel_contact(pid,d->'contacts',case when person is null then 0 else contact_expected end);
 insert into public.personnel_seasons(theater_id,person_id,season_id) values(q.theater_id,pid,q.season_id) on conflict do nothing;
 for a in select value from jsonb_array_elements(d->'assignments') loop
 insert into public.production_credits(theater_id,production_id,person_id,role,credit_type) values(q.theater_id,(a->>'production_id')::uuid,pid,a->>'role',kind) on conflict(theater_id,production_id,person_id,credit_type,role) do nothing;
 end loop;
 insert into private.personnel_intake_media(person_id,theater_id,headshot,resume,resume_name) values(pid,q.theater_id,d->>'headshot',d->>'resume',d->>'resume_name') on conflict(person_id) do update set headshot=excluded.headshot,resume=case when excluded.resume='' then private.personnel_intake_media.resume else excluded.resume end,resume_name=case when excluded.resume='' then private.personnel_intake_media.resume_name else excluded.resume_name end;
 update private.personnel_intake_submissions set status='Approved',reviewed_at=now(),reviewed_by=auth.uid(),review_note=trim(note),person_id=pid,revision=revision+1 where id=submission;
 insert into private.settings_history(theater_id,actor,section) values(q.theater_id,auth.uid(),'personnel_intake_approved');
 return jsonb_build_object('status','Approved','person_id',pid);
end $$;
create function private.get_personnel_media(p uuid,kind text) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid;result jsonb;
begin
 select theater_id into t from public.people where id=p;
 if t is null or not private.verified_user() or (kind='resume' and not private.can_manage_intake(t)) or (kind='headshot' and not private.visible_person(t,p)) or kind not in ('headshot','resume') or kind is null then raise exception 'Personnel media access denied' using errcode='42501';end if;
 select case when kind='headshot' then jsonb_build_object('data',headshot,'name','headshot.jpg') else jsonb_build_object('data',resume,'name',resume_name) end into result from private.personnel_intake_media where person_id=p;
 return coalesce(result,jsonb_build_object('data','','name',''));
end $$;

revoke all on function private.create_personnel_intake(uuid,text,text) from public,anon;
grant execute on function private.create_personnel_intake(uuid,text,text) to authenticated;
create function public.create_personnel_intake(t uuid,recipient_name text,recipient_email text default '') returns jsonb language sql security invoker set search_path='' as $$select private.create_personnel_intake(t,recipient_name,recipient_email)$$;
revoke all on function public.create_personnel_intake(uuid,text,text) from public,anon;
grant execute on function public.create_personnel_intake(uuid,text,text) to authenticated;

revoke all on function private.get_company_management(uuid) from public,anon;
grant execute on function private.get_company_management(uuid) to authenticated;
create function public.get_company_management(t uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_company_management(t)$$;
revoke all on function public.get_company_management(uuid) from public,anon;
grant execute on function public.get_company_management(uuid) to authenticated;

revoke all on function private.get_intake_submission(uuid) from public,anon;
grant execute on function private.get_intake_submission(uuid) to authenticated;
create function public.get_intake_submission(submission uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_intake_submission(submission)$$;
revoke all on function public.get_intake_submission(uuid) from public,anon;
grant execute on function public.get_intake_submission(uuid) to authenticated;

revoke all on function private.revoke_personnel_intake(uuid) from public,anon;
grant execute on function private.revoke_personnel_intake(uuid) to authenticated;
create function public.revoke_personnel_intake(link uuid) returns void language sql security invoker set search_path='' as $$select private.revoke_personnel_intake(link)$$;
revoke all on function public.revoke_personnel_intake(uuid) from public,anon;
grant execute on function public.revoke_personnel_intake(uuid) to authenticated;

revoke all on function private.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) from public,anon;
grant execute on function private.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) to authenticated;
create function public.review_personnel_intake(submission uuid,decision text,expected integer,person uuid default null,person_expected timestamptz default null,contact_expected integer default 0,allow_duplicate boolean default false,note text default '') returns jsonb language sql security invoker set search_path='' as $$select private.review_personnel_intake(submission,decision,expected,person,person_expected,contact_expected,allow_duplicate,note)$$;
revoke all on function public.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) from public,anon;
grant execute on function public.review_personnel_intake(uuid,text,integer,uuid,timestamptz,integer,boolean,text) to authenticated;

revoke all on function private.get_personnel_media(uuid,text) from public,anon;
grant execute on function private.get_personnel_media(uuid,text) to authenticated;
create function public.get_personnel_media(p uuid,kind text) returns jsonb language sql security invoker set search_path='' as $$select private.get_personnel_media(p,kind)$$;
revoke all on function public.get_personnel_media(uuid,text) from public,anon;
grant execute on function public.get_personnel_media(uuid,text) to authenticated;
