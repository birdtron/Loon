-- Integration assertions run as authenticated roles. Everything rolls back.
begin;
do $$ declare t uuid; p uuid; actor uuid; uid uuid; role_name text; begin
 select id,theater_id into p,t from public.productions order by title limit 1;
 select person_id into actor from public.production_credits where production_id=p and credit_type='Cast' limit 1;
 perform set_config('test.theater',t::text,true);perform set_config('test.production',p::text,true);perform set_config('test.person',actor::text,true);
 foreach role_name in array array['Stage Manager','Cast','Lighting','Guest'] loop
  uid:=gen_random_uuid();insert into auth.users(id,email,email_confirmed_at,is_anonymous) values(uid,replace(lower(role_name),' ','-')||'-reports@example.invalid',now(),false);
  insert into private.workspace_members(theater_id,user_id,email,roles,production_ids,person_id) values(t,uid,replace(lower(role_name),' ','-')||'-reports@example.invalid',array[role_name],array[p],case when role_name='Cast' then actor end);
  perform set_config('test.'||replace(lower(role_name),' ','_'),uid::text,true);
 end loop;
 insert into public.production_credits(theater_id,production_id,person_id,role,credit_type) values(t,p,actor,'Fight Choreographer','Creative') on conflict do nothing;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.stage_manager'),true);
do $$ declare pid uuid:=current_setting('test.production')::uuid; result jsonb; draft jsonb; d jsonb; saved jsonb; blocked boolean; perf public.calendar_events%rowtype; tz text; begin
 result:=public.save_rehearsal_call(jsonb_build_object('id',gen_random_uuid(),'production_id',pid,'start','2036-02-01T15:00:00Z','end','2036-02-01T16:00:00Z','work','Report rollback call','location','Test room','call_status','Published','person_ids',jsonb_build_array(current_setting('test.person'))));
 perform set_config('test.call',result->'event'->>'id',true);
 d:='{"start":"2036-02-01T15:00:00Z","end":"2036-02-01T16:00:00Z","summary":"Rollback report","cancelled":false,"penalties":false,"has_intermission":false,"breaks":"Yes","departments":{"Scenic":"Check platform"}}';
 draft:=jsonb_build_object('id',gen_random_uuid(),'production_id',pid,'kind','Rehearsal','report_date','2036-02-01','data',d,'additional_cast','[]'::jsonb);
 saved:=public.save_stage_report(draft);assert jsonb_array_length(saved->'cast_snapshot')=1,'Callboard cast missing';assert saved->'cast_snapshot'->0->>'source'='callboard';
 assert public.save_stage_report(draft)=saved,'Create retry was not idempotent';
 perform set_config('test.report',saved->>'id',true);perform set_config('test.draft',draft::text,true);
 blocked:=false;begin perform public.save_stage_report(draft||jsonb_build_object('id',gen_random_uuid()));exception when raise_exception then blocked:=true;end;assert blocked,'Duplicate day accepted';
 blocked:=false;begin perform public.save_stage_report(draft||'{"expected":99}');exception when raise_exception then blocked:=true;end;assert blocked,'Stale edit accepted';
 blocked:=false;begin perform public.save_stage_report(draft||jsonb_build_object('expected',1,'data',d||'{"breaks":"No"}'));exception when raise_exception then blocked:=true;end;assert blocked,'Missing break details accepted';
 blocked:=false;begin perform public.save_stage_report(draft||jsonb_build_object('expected',1,'additional_cast',jsonb_build_array(gen_random_uuid())));exception when raise_exception then blocked:=true;end;assert blocked,'Foreign cast accepted';
 blocked:=false;begin update public.stage_reports set data='{}';exception when insufficient_privilege then blocked:=true;end;assert blocked,'Direct report writes accepted';
 -- A calendar cancellation must not rewrite a previously saved report's cast snapshot.
 perform public.save_rehearsal_call(jsonb_build_object('id',result->'event'->>'id','production_id',pid,'expected_updated_at',result->'event'->>'updated_at','start','2036-02-01T15:00:00Z','end','2036-02-01T16:00:00Z','work','Report rollback call','location','Test room','call_status','Canceled','person_ids',jsonb_build_array(current_setting('test.person'))));
 saved:=public.save_stage_report(draft||'{"expected":1,"refresh_cast":false}');assert jsonb_array_length(saved->'cast_snapshot')=1,'Snapshot changed with callboard';
 saved:=public.save_stage_report(draft||'{"expected":2,"refresh_cast":true}');assert jsonb_array_length(saved->'cast_snapshot')=0,'Explicit refresh failed';
 -- Performance chronology, fight call, overtime, and cancellation branches.
 select * into perf from public.calendar_events where production_id=pid and category='Performance' order by start limit 1;
 tz:=(public.get_workspace(current_setting('test.theater')::uuid))->'settings'->'theater'->>'timezone';
 d:=d||jsonb_build_object('start',perf.start,'end',perf."end",'house',perf.start-interval '30 minutes','fight','No');
 draft:=jsonb_build_object('id',gen_random_uuid(),'production_id',pid,'kind','Performance','event_id',perf.id,'report_date',(perf.start at time zone tz)::date,'data',d);
 blocked:=false;begin perform public.save_stage_report(draft);exception when raise_exception then blocked:=true;end;assert blocked,'Missing fight-call explanation accepted';
 d:=d||'{"fight_details":"Per choreographer instruction","penalties":true,"penalty_reason":"7th Day"}';
 blocked:=false;begin perform public.save_stage_report(draft||jsonb_build_object('data',d));exception when raise_exception then blocked:=true;end;assert blocked,'Missing penalty details accepted';
 d:=d||'{"penalty_details":"Two people; two additional hours."}';saved:=public.save_stage_report(draft||jsonb_build_object('data',d));assert (saved->>'fight_required')::boolean;
 d:=d||'{"cancelled":true,"cancel_reason":"Facility","cancel_details":"Power outage"}';saved:=public.save_stage_report(draft||jsonb_build_object('expected',1,'data',d));assert saved->'data'->>'start'='','Canceled report retained run times';
end $$;
reset role;
do $$ declare r public.stage_reports%rowtype; begin
 select * into r from public.stage_reports where production_id=current_setting('test.production')::uuid and kind='Performance';
 update public.calendar_events set start=start+interval '1 day 1 minute',"end"="end"+interval '1 day 1 minute',venue_id=null where id=r.event_id;
 assert not has_function_privilege('anon','public.save_stage_report(jsonb)','EXECUTE'),'Anonymous report RPC exposed';
end $$;
set local role authenticated;
do $$ declare r public.stage_reports%rowtype; result jsonb;begin
 select * into r from public.stage_reports where production_id=current_setting('test.production')::uuid and kind='Performance';
 result:=public.save_stage_report(jsonb_build_object('id',r.id,'production_id',r.production_id,'kind',r.kind,'report_date',r.report_date,'event_id',r.event_id,'expected',r.revision,'data',r.data));
 assert result->>'report_date'=r.report_date::text,'Rescheduling changed historical report date';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.cast'),true);
do $$ declare blocked boolean:=false;begin
 assert (select count(*)=0 from public.stage_reports),'Cast can read private reports';
 begin perform public.save_stage_report(current_setting('test.draft')::jsonb);exception when insufficient_privilege then blocked:=true;end;assert blocked,'Cast can save reports';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.lighting'),true);
do $$ declare blocked boolean:=false;begin
 assert (select count(*)=2 from public.stage_reports),'Department cannot read reports';
 begin perform public.save_stage_report(current_setting('test.draft')::jsonb);exception when insufficient_privilege then blocked:=true;end;assert blocked,'View-only department can save';
 assert not private.report_permission(gen_random_uuid(),current_setting('test.production')::uuid),'Cross-theater access';
end $$;
select set_config('request.jwt.claim.sub',current_setting('test.guest'),true);
do $$ begin assert (select count(*)=2 from public.stage_reports),'Assigned guest cannot read';assert not private.report_permission(current_setting('test.theater')::uuid,gen_random_uuid()),'Guest can read unassigned production';end $$;
reset role;
update private.workspace_members set overrides='{"stage":"none"}' where user_id=current_setting('test.stage_manager')::uuid;
set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('test.stage_manager'),true);
do $$ begin assert (select count(*)=0 from public.stage_reports),'Explicit deny ignored';end $$;
reset role;
rollback;
