-- Contact details are intentionally separate from directory rows and public biographies.
create table private.personnel_contacts (
 person_id uuid primary key, theater_id uuid not null,
 email text not null default '',address_line_1 text not null default '',address_line_2 text not null default '',
 city text not null default '',state text not null default '',zip text not null default '',
 emergency_contact_name text not null default '',emergency_contact_phone text not null default '',
 revision integer not null default 1,updated_at timestamptz not null default now(),updated_by uuid not null references auth.users(id),
 foreign key(theater_id,person_id) references public.people(theater_id,id) on delete cascade,
 check(length(email)<=254 and length(address_line_1)<=300 and length(address_line_2)<=300 and length(city)<=120 and length(state)<=120 and length(zip)<=32 and length(emergency_contact_name)<=200 and length(emergency_contact_phone)<=80)
);
alter table private.personnel_contacts enable row level security;
revoke all on private.personnel_contacts from public,anon,authenticated;
create policy no_direct_contact_access on private.personnel_contacts for all to authenticated using(false) with check(false);
create function private.can_manage_personnel_contact(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select private.verified_user() and (private.workspace_admin(t) or (private.workspace_permission(t,'stage','edit') and exists(select 1 from private.workspace_members where theater_id=t and user_id=auth.uid() and active and roles && array['Stage Manager','Assistant Stage Manager','Company Manager']::text[])));
$$;
revoke all on function private.can_manage_personnel_contact(uuid) from public,anon,authenticated;
create function private.get_personnel_contact(p uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid; result jsonb;
begin
 select theater_id into t from public.people where id=p;
 if t is null or not private.can_manage_personnel_contact(t) then raise exception 'Stage management or theater administrator access required' using errcode='42501';end if;
 select to_jsonb(c)-array['person_id','theater_id','updated_by','updated_at'] into result from private.personnel_contacts c where person_id=p and theater_id=t;
 return coalesce(result,jsonb_build_object('email','','address_line_1','','address_line_2','','city','','state','','zip','','emergency_contact_name','','emergency_contact_phone','','revision',0));
end $$;
create function private.save_personnel_contact(p uuid,draft jsonb,expected integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare t uuid; current_revision integer; clean jsonb:='{}'; key text; value text; max_length integer;
begin
 select theater_id into t from public.people where id=p;
 if t is null or not private.can_manage_personnel_contact(t) then raise exception 'Stage management or theater administrator access required' using errcode='42501';end if;
 if jsonb_typeof(draft) is distinct from 'object' then raise exception 'Supply contact information fields';end if;
 if expected is null or expected<0 then raise exception 'Refresh contact information before saving';end if;
 for key in select jsonb_object_keys(draft) loop
 if key<>all(array['email','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone']) then raise exception 'Unknown contact field: %',key;end if;
 end loop;
 foreach key in array array['email','address_line_1','address_line_2','city','state','zip','emergency_contact_name','emergency_contact_phone'] loop
 if not draft ? key or jsonb_typeof(draft->key) is distinct from 'string' then raise exception 'Supply a text value for %',key;end if;
 value:=trim(draft->>key);
 max_length:=case key when 'email' then 254 when 'address_line_1' then 300 when 'address_line_2' then 300 when 'city' then 120 when 'state' then 120 when 'zip' then 32 when 'emergency_contact_name' then 200 else 80 end;
 if length(value)>max_length then raise exception '% is too long',key;end if;
 if key='email' and value<>'' and value !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Enter a valid email address';end if;
 clean:=clean||jsonb_build_object(key,value);
 end loop;
 perform pg_advisory_xact_lock(hashtextextended(p::text,73));
 select revision into current_revision from private.personnel_contacts where person_id=p;
 if coalesce(current_revision,0)<>expected then raise exception 'Contact information changed. Cancel, refresh it and try again.';end if;
 insert into private.personnel_contacts(person_id,theater_id,email,address_line_1,address_line_2,city,state,zip,emergency_contact_name,emergency_contact_phone,updated_by)
 values(p,t,clean->>'email',clean->>'address_line_1',clean->>'address_line_2',clean->>'city',clean->>'state',clean->>'zip',clean->>'emergency_contact_name',clean->>'emergency_contact_phone',auth.uid())
 on conflict(person_id) do update set email=excluded.email,address_line_1=excluded.address_line_1,address_line_2=excluded.address_line_2,city=excluded.city,state=excluded.state,zip=excluded.zip,emergency_contact_name=excluded.emergency_contact_name,emergency_contact_phone=excluded.emergency_contact_phone,revision=private.personnel_contacts.revision+1,updated_at=now(),updated_by=auth.uid();
 -- Record who changed contacts without copying sensitive values into general history.
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),'personnel_contacts');
 return private.get_personnel_contact(p);
end $$;
revoke all on function private.get_personnel_contact(uuid),private.save_personnel_contact(uuid,jsonb,integer) from public,anon;
grant execute on function private.get_personnel_contact(uuid),private.save_personnel_contact(uuid,jsonb,integer) to authenticated;
create function public.get_personnel_contact(p uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_personnel_contact(p)$$;
create function public.save_personnel_contact(p uuid,draft jsonb,expected integer) returns jsonb language sql security invoker set search_path='' as $$select private.save_personnel_contact(p,draft,expected)$$;
revoke all on function public.get_personnel_contact(uuid),public.save_personnel_contact(uuid,jsonb,integer) from public,anon;
grant execute on function public.get_personnel_contact(uuid),public.save_personnel_contact(uuid,jsonb,integer) to authenticated;
