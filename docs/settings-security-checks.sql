-- All identities, calls, membership changes and template applications roll back.
begin;
do $$ declare owner_id uuid; tid uuid; uid uuid:=gen_random_uuid(); cid uuid:=gen_random_uuid(); gid uuid:=gen_random_uuid(); begin
 select bound_user_id into owner_id from private.platform_owner_reservations where bound_user_id is not null limit 1;
 select id into tid from public.theaters limit 1;
 insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(uid,'settings-stage@example.invalid',now(),false),(cid,'settings-cast@example.invalid',now(),false),(gid,'settings-guest@example.invalid',now(),false);
 perform set_config('test.owner',owner_id::text,true);perform set_config('test.stage',uid::text,true);perform set_config('test.cast',cid::text,true);perform set_config('test.guest',gid::text,true);perform set_config('test.theater',tid::text,true);
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
do $$ declare ctx jsonb; t uuid:=current_setting('test.theater')::uuid; pid uuid; person uuid; blocked boolean; draft jsonb; begin
 ctx:=public.get_workspace(t);assert (ctx->>'admin')::boolean;
 select id into pid from public.productions where theater_id=t order by title limit 1;
 select person_id into person from public.production_credits where production_id=pid and credit_type='Cast' limit 1;
 perform set_config('test.production',pid::text,true);perform set_config('test.person',person::text,true);
 draft:=jsonb_build_object('email','settings-stage@example.invalid','roles',array['Stage Manager'],'job_title','Stage Manager','active',true,'production_ids','[]'::jsonb,'delegated',array['stage','calendar'],'overrides',jsonb_build_object('calendar','edit'));
 ctx:=public.save_member(t,draft,0);
 perform public.save_member(t,jsonb_build_object('email','settings-cast@example.invalid','roles',array['Cast'],'production_ids',jsonb_build_array(pid),'person_id',person,'delegated','[]'::jsonb),0);
 perform public.save_member(t,jsonb_build_object('email','settings-guest@example.invalid','roles',array['Guest'],'production_ids',jsonb_build_array(pid),'delegated','[]'::jsonb),0);
 blocked:=false;begin perform public.save_member(t,jsonb_build_object('email','settings-bad@example.invalid','roles',array['Super Admin'],'job_title','Stage Manager'),0);exception when raise_exception then blocked:=true;end;assert blocked,'Ineligible admin accepted';
 blocked:=false;begin perform public.save_workspace(t,'stage',ctx->'settings'->'stage',0);exception when raise_exception then blocked:=true;end;assert blocked,'Stale revision accepted';
 ctx:=public.save_workspace(t,'stage',(ctx->'settings'->'stage')||'{"start":"10:00","end":"13:00","location":"Test room"}'::jsonb,(ctx->'settings'->>'revision')::integer);
 assert ctx->'settings'->'stage'->>'start'='10:00';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.stage'),true);
do $$ declare ctx jsonb; t uuid:=current_setting('test.theater')::uuid; pid uuid:=current_setting('test.production')::uuid; blocked boolean; result jsonb; begin
 ctx:=public.get_workspace(t);assert not (ctx->>'admin')::boolean;assert ctx->'permissions'->>'stage'='edit';assert jsonb_array_length(ctx->'members')=0;
 ctx:=public.save_workspace(t,'stage',ctx->'settings'->'stage',(ctx->'settings'->>'revision')::integer);
 blocked:=false;begin perform public.save_workspace(t,'theater',ctx->'settings'->'theater',(ctx->'settings'->>'revision')::integer);exception when insufficient_privilege then blocked:=true;end;assert blocked,'Delegate changed theater';
 blocked:=false;begin perform public.save_member(t,ctx->'member',1);exception when insufficient_privilege then blocked:=true;end;assert blocked,'Delegate changed membership';
 blocked:=false;begin perform public.get_workspace(gen_random_uuid());exception when insufficient_privilege then blocked:=true;end;assert blocked,'Cross theater access';
 result:=public.save_rehearsal_call(jsonb_build_object('id',gen_random_uuid(),'production_id',pid,'start','2036-02-01T15:00:00Z','end','2036-02-01T16:00:00Z','work','Rollback call','location','Test room','call_status','Published','person_ids',jsonb_build_array(current_setting('test.person'))));
 perform set_config('test.event',result->'event'->>'id',true);assert result->'event'->>'call_status'='Published','Stage manager cannot publish';
 result:=public.apply_templates(t,pid,(ctx->'settings'->>'revision')::integer);assert (result->>'created')::integer=9;
 result:=public.apply_templates(t,pid,(ctx->'settings'->>'revision')::integer);assert (result->>'created')::integer=0,'Templates duplicate on retry';
 ctx:=public.save_account('{"name":"Test","phone":"","photo":"","landing":"Callboard","calendar_view":"list","personnel_view":"list","time_format":"24"}',0);assert ctx->'account'->>'name'='Test';
 blocked:=false;begin perform public.save_account('{"landing":"Callboard"}',0);exception when raise_exception then blocked:=true;end;assert blocked,'Stale profile save accepted';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.cast'),true);
do $$ declare ctx jsonb; blocked boolean:=false;begin
 ctx:=public.get_workspace(current_setting('test.theater')::uuid);
 assert (select count(*)=1 from public.productions),'Cast read unassigned shows';
 assert (select count(*)=1 from public.people),'Cast read others personnel';
 assert exists(select 1 from public.calendar_events where id=current_setting('test.event')::uuid),'Own call missing';
 assert not exists(select 1 from public.calendar_events where call_status='Draft'),'Cast reads drafts';
 begin perform public.save_rehearsal_call(jsonb_build_object('id',gen_random_uuid(),'production_id',current_setting('test.production')));exception when insufficient_privilege then blocked:=true;end;assert blocked,'Cast can publish';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.guest'),true);
do $$ begin assert (select count(*)=1 from public.productions);assert not exists(select 1 from public.calendar_events where call_status='Draft');end $$;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
do $$ declare ctx jsonb; m jsonb;begin ctx:=public.get_workspace(current_setting('test.theater')::uuid);select value into m from jsonb_array_elements(ctx->'members') where value->>'email'='settings-stage@example.invalid';perform public.save_member(current_setting('test.theater')::uuid,m||'{"active":false}'::jsonb,(m->>'revision')::integer);end $$;
select set_config('request.jwt.claim.sub',current_setting('test.stage'),true);
do $$ begin assert (select count(*)=0 from public.productions),'Suspension not enforced';assert (select count(*)=0 from public.calendar_events);end $$;
select set_config('request.jwt.claim.sub',current_setting('test.owner'),true);
do $$ declare ctx jsonb;m jsonb;begin
 ctx:=public.get_workspace(current_setting('test.theater')::uuid);
 select value into m from jsonb_array_elements(ctx->'members') where value->>'email'='settings-guest@example.invalid';
 perform public.save_member(current_setting('test.theater')::uuid,m||'{"roles":["Super Admin"],"job_title":"IT"}'::jsonb,(m->>'revision')::integer);
 select value into m from jsonb_array_elements(ctx->'members') where value->>'email'='settings-stage@example.invalid';
 perform public.save_member(current_setting('test.theater')::uuid,m||'{"active":true,"overrides":{"stage":"none"}}'::jsonb,(m->>'revision')::integer);
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.guest'),true);
do $$ declare ctx jsonb;blocked boolean:=false;begin
 ctx:=public.get_workspace(current_setting('test.theater')::uuid);assert (ctx->>'admin')::boolean;
 begin perform public.save_member(current_setting('test.theater')::uuid,ctx->'member',(ctx->'member'->>'revision')::integer);exception when raise_exception then blocked:=true;end;assert blocked,'Admin could edit own access';
 blocked:=false;begin perform public.get_workspace(gen_random_uuid());exception when insufficient_privilege then blocked:=true;end;assert blocked,'Admin crossed theater boundary';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.stage'),true);
do $$ begin assert not private.workspace_permission(current_setting('test.theater')::uuid,'stage','edit'),'Explicit deny failed';end $$;
reset role;
rollback;
