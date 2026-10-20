begin;
do $$ declare t uuid; p uuid; uid uuid; r text; begin
 select id,theater_id into p,t from public.productions order by title limit 1;
 perform set_config('test.production',p::text,true);
 foreach r in array array['Stage Manager','Cast'] loop
  uid:=gen_random_uuid();
  insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(uid,uid::text||'@example.invalid',now(),false);
  insert into private.workspace_members(theater_id,user_id,email,roles,production_ids)
   values(t,uid,uid::text||'@example.invalid',array[r],array[p]);
  perform set_config('test.'||replace(lower(r),' ','_'),uid::text,true);
 end loop;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.stage_manager'),true);
do $$ declare d jsonb; saved jsonb; n jsonb; blocked boolean; begin
 d:=jsonb_build_object('id',gen_random_uuid(),'production_id',current_setting('test.production'),'kind','Rehearsal','report_date','2038-02-03','data',
  '{"start":"2038-02-03T15:00:00Z","end":"2038-02-03T16:00:00Z","summary":"Rollback only","cancelled":false,"penalties":false,"has_intermission":false,"breaks":"Yes","departments":{},"show_critical":true,"critical_note":"Unsafe platform"}'::jsonb);
 saved:=public.save_stage_report(d);
 perform set_config('test.report',saved->>'id',true);perform set_config('test.draft',d::text,true);
 assert (select note='Unsafe platform' and resolved_at is null from public.show_critical_notes where report_id=(saved->>'id')::uuid),'Critical note missing';
 blocked:=false;begin perform public.save_stage_report(jsonb_set(d||'{"expected":1}','{data,show_critical}','false'));exception when raise_exception then blocked:=true;end;assert blocked,'Unresolved note cleared';
 blocked:=false;begin perform public.save_stage_report(jsonb_set(d||'{"expected":1}','{data,critical_note}','""'));exception when raise_exception then blocked:=true;end;assert blocked,'Blank note accepted';
 blocked:=false;begin perform public.resolve_show_critical_note((saved->>'id')::uuid,99);exception when raise_exception then blocked:=true;end;assert blocked,'Stale resolution accepted';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.cast'),true);
do $$ declare blocked boolean:=false; begin
 assert (select count(*)=1 from public.show_critical_notes where report_id=current_setting('test.report')::uuid),'Assigned cast cannot see warning';
 assert not exists(select 1 from public.stage_reports where id=current_setting('test.report')::uuid),'Private report exposed';
 begin perform public.resolve_show_critical_note(current_setting('test.report')::uuid,1);exception when insufficient_privilege then blocked:=true;end;assert blocked,'Cast resolved warning';
 blocked:=false;begin update public.show_critical_notes set note='Bypass';exception when insufficient_privilege then blocked:=true;end;assert blocked,'Direct writes allowed';
end $$;
reset role;
update private.workspace_members set production_ids='{}' where user_id=current_setting('test.cast')::uuid;
set local role authenticated;
do $$ begin assert not exists(select 1 from public.show_critical_notes where report_id=current_setting('test.report')::uuid),'Unassigned cast saw warning';end $$;
select set_config('request.jwt.claim.sub',current_setting('test.stage_manager'),true);
do $$ declare n jsonb; saved jsonb; begin
 n:=public.resolve_show_critical_note(current_setting('test.report')::uuid,1);assert n->>'resolved_at' is not null;
 saved:=public.save_stage_report(current_setting('test.draft')::jsonb||'{"expected":1}');
 assert (select resolved_at is not null from public.show_critical_notes where report_id=current_setting('test.report')::uuid),'Unchanged note reopened';
 saved:=public.save_stage_report(jsonb_set(current_setting('test.draft')::jsonb||'{"expected":2}','{data,critical_note}','"New hazard"'));
 assert (select resolved_at is null and revision=3 and note='New hazard' from public.show_critical_notes where report_id=current_setting('test.report')::uuid),'Changed note did not reopen';
end $$;
reset role;
do $$ begin
 assert not has_table_privilege('anon','public.show_critical_notes','SELECT'),'Anonymous note access';
 assert not has_function_privilege('anon','public.resolve_show_critical_note(uuid,integer)','EXECUTE'),'Anonymous resolution access';
end $$;
rollback;
