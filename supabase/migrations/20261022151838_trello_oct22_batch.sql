-- One additive batch for the four October 22 Trello cards.
alter table public.people add column portfolio_url text not null default '' check (length(portfolio_url)<=2048 and (portfolio_url='' or portfolio_url ~* '^https?://[^[:space:]]+$'));

create or replace function private.can_manage_personnel_contact(t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and private.can_manage_intake(t);
$$;
do $$ declare definition text; begin
 select pg_get_functiondef('private.get_personnel_contact(uuid)'::regprocedure) into definition;
 definition:=replace(definition,'Stage management or theater administrator access required','Company Management or Super Admin access required');
 execute definition;
 select pg_get_functiondef('private.clean_intake(jsonb,uuid,uuid)'::regprocedure) into definition;
 definition:=replace(definition,'''AEA'',''SAG-AFTRA'',''IATSE'',''AGMA''','''AEA'',''SAG-AFTRA'',''IATSE'',''AFM'',''UMAW'',''AGMA''');
 definition:=replace(definition,'jsonb_array_length(d->''unions'')>8','jsonb_array_length(d->''unions'')>10');
 execute definition;
end $$;

-- Private contracts: all storage requests recheck company-management access.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('personnel-contracts','personnel-contracts',false,10485760,array['application/pdf','image/jpeg','image/png']);
create function private.can_access_contract(object_name text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare t uuid; p uuid;
begin
 if auth.uid() is null then return false;end if;
 begin t:=split_part(object_name,'/',1)::uuid;p:=split_part(object_name,'/',2)::uuid;exception when invalid_text_representation then return false;end;
 return private.can_manage_intake(t) and exists(select 1 from public.people where id=p and theater_id=t);
end $$;
revoke all on function private.can_access_contract(text) from public,anon;
grant execute on function private.can_access_contract(text) to authenticated;
create policy contracts_read on storage.objects for select to authenticated using(bucket_id='personnel-contracts' and private.can_access_contract(name));
create policy contracts_upload on storage.objects for insert to authenticated with check(bucket_id='personnel-contracts' and private.can_access_contract(name));

-- Server date, rather than client clocks or a midnight delete job, controls attendance.
create function private.theater_today(t uuid) returns date language sql stable security definer set search_path='' as $$
 select (now() at time zone coalesce(s.data->'theater'->>'timezone',th.timezone,'America/New_York'))::date from public.theaters th left join private.workspace_settings s on s.theater_id=th.id where th.id=t;
$$;
revoke all on function private.theater_today(uuid) from public,anon,authenticated;
create table private.actor_checkins(theater_id uuid not null,person_id uuid not null,check_date date not null,checked_at timestamptz not null default now(),checked_by uuid not null references auth.users(id),primary key(theater_id,person_id,check_date),foreign key(theater_id,person_id) references public.people(theater_id,id) on delete cascade);
alter table private.actor_checkins enable row level security;
revoke all on private.actor_checkins from public,anon,authenticated;
create function private.get_actor_checkins(t uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare d date:=private.theater_today(t); zone text; result jsonb;
begin
 if auth.uid() is null or not private.workspace_permission(t,'stage') then raise exception 'Callboard access required' using errcode='42501';end if;
 select coalesce(s.data->'theater'->>'timezone',th.timezone,'America/New_York') into zone from public.theaters th left join private.workspace_settings s on s.theater_id=th.id where th.id=t;
 select coalesce(jsonb_agg(to_jsonb(roster) order by roster.display_name),'[]') into result from (
 select p.id,p.display_name,p.known_as,c.checked_at,
 (not private.is_read_only() and (private.workspace_permission(t,'stage','edit') or exists(select 1 from private.workspace_members m where m.theater_id=t and m.user_id=auth.uid() and m.active and m.person_id=p.id))) as can_check_in,
 (select string_agg(distinct pr.title,', ' order by pr.title) from public.rehearsal_call_cast cc join public.calendar_events e on e.id=cc.event_id join public.productions pr on pr.id=e.production_id where cc.person_id=p.id and cc.theater_id=t and e.call_status='Published' and (e.start at time zone zone)::date=d and private.workspace_permission(t,'stage','view',e.production_id)) as productions
 from public.people p left join private.actor_checkins c on c.person_id=p.id and c.theater_id=t and c.check_date=d
 where p.theater_id=t and exists(select 1 from public.rehearsal_call_cast cc join public.calendar_events e on e.id=cc.event_id where cc.person_id=p.id and cc.theater_id=t and e.call_status='Published' and (e.start at time zone zone)::date=d and private.workspace_permission(t,'stage','view',e.production_id))
 ) roster;
 return jsonb_build_object('date',d,'timezone',zone,'actors',result);
end $$;
create function private.check_in_actor(t uuid,p uuid,expected_date date) returns jsonb language plpgsql security definer set search_path='' as $$
declare roster jsonb; actor jsonb; d date:=private.theater_today(t);
begin
 if auth.uid() is null or private.is_read_only() then raise exception 'Check-in access required' using errcode='42501';end if;
 if expected_date is distinct from d then raise exception 'A new day has started. Refresh the check-in roster.';end if;
 roster:=private.get_actor_checkins(t);
 select value into actor from jsonb_array_elements(roster->'actors') where value->>'id'=p::text;
 if actor is null or not coalesce((actor->>'can_check_in')::boolean,false) then raise exception 'You may only check in yourself or actors you manage on today''s callboard' using errcode='42501';end if;
 insert into private.actor_checkins(theater_id,person_id,check_date,checked_by) values(t,p,d,auth.uid()) on conflict do nothing;
 return private.get_actor_checkins(t);
end $$;

-- Production discussions: immutable author/time; idempotent message IDs and reactions.
create table private.production_messages(id uuid primary key,production_id uuid not null references public.productions(id),author uuid not null references auth.users(id),author_name text not null,body text not null check(length(btrim(body)) between 1 and 10000),created_at timestamptz not null default now());
create index production_messages_feed on private.production_messages(production_id,created_at desc);
create table private.production_message_likes(message_id uuid not null references private.production_messages(id) on delete cascade,user_id uuid not null references auth.users(id),primary key(message_id,user_id));
alter table private.production_messages enable row level security;
alter table private.production_message_likes enable row level security;
revoke all on private.production_messages,private.production_message_likes from public,anon,authenticated;
create function private.get_production_messages(p uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare t uuid;
begin
 select theater_id into t from public.productions where id=p;
 if auth.uid() is null or t is null or not private.workspace_permission(t,'productions','view',p) then raise exception 'Production access required' using errcode='42501';end if;
 return coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at desc) from (select id,body,author_name,created_at,(select count(*) from private.production_message_likes l where l.message_id=x.id) as likes,exists(select 1 from private.production_message_likes l where l.message_id=x.id and l.user_id=auth.uid()) as liked from private.production_messages x where production_id=p order by created_at desc limit 200) m),'[]');
end $$;
create function private.post_production_message(p uuid,message_id uuid,body text) returns jsonb language plpgsql security definer set search_path='' as $$
declare name text; existing private.production_messages%rowtype;
begin
 perform private.get_production_messages(p);
 if private.is_read_only() then raise exception 'Demo access is read only' using errcode='42501';end if;
 if body is null or length(btrim(body)) not between 1 and 10000 then raise exception 'Enter a message of 1–10,000 characters';end if;
 select coalesce(nullif(a.data->>'name',''),nullif(m.email,''),'Workspace member') into name from (select auth.uid() as id) u left join private.account_settings a on a.user_id=u.id left join private.workspace_members m on m.user_id=u.id and m.theater_id=(select theater_id from public.productions where id=p);
 insert into private.production_messages(id,production_id,author,author_name,body) values(message_id,p,auth.uid(),coalesce(name,'Workspace member'),btrim(body)) on conflict do nothing;
 select * into existing from private.production_messages where id=message_id;
 if existing.author<>auth.uid() or existing.production_id<>p or existing.body<>btrim(body) then raise exception 'Message identifier already used';end if;
 return private.get_production_messages(p);
end $$;
create function private.like_production_message(message_id uuid,liked boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare p uuid;
begin
 select production_id into p from private.production_messages where id=message_id;
 perform private.get_production_messages(p);
 if private.is_read_only() or liked is null then raise exception 'Reaction access required' using errcode='42501';end if;
 if liked then insert into private.production_message_likes values(message_id,auth.uid()) on conflict do nothing;else delete from private.production_message_likes l where l.message_id=like_production_message.message_id and l.user_id=auth.uid();end if;
 return private.get_production_messages(p);
end $$;

create function public.get_actor_checkins(t uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_actor_checkins(t)$$;
create function public.check_in_actor(t uuid,p uuid,expected_date date) returns jsonb language sql security invoker set search_path='' as $$select private.check_in_actor(t,p,expected_date)$$;
create function public.get_production_messages(p uuid) returns jsonb language sql security invoker set search_path='' as $$select private.get_production_messages(p)$$;
create function public.post_production_message(p uuid,message_id uuid,body text) returns jsonb language sql security invoker set search_path='' as $$select private.post_production_message(p,message_id,body)$$;
create function public.like_production_message(message_id uuid,liked boolean) returns jsonb language sql security invoker set search_path='' as $$select private.like_production_message(message_id,liked)$$;
do $$ declare sig text; begin foreach sig in array array['get_actor_checkins(uuid)','check_in_actor(uuid,uuid,date)','get_production_messages(uuid)','post_production_message(uuid,uuid,text)','like_production_message(uuid,boolean)'] loop
 execute 'revoke all on function private.'||sig||' from public,anon';execute 'grant execute on function private.'||sig||' to authenticated';
 execute 'revoke all on function public.'||sig||' from public,anon';execute 'grant execute on function public.'||sig||' to authenticated';
 end loop;end $$;
