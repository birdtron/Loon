-- All parsing, lookup checks and inserts share one transaction. No client-selected UUIDs.
create function private.import_date(value text) returns date language plpgsql immutable security invoker set search_path='' as $$
declare result date; canonical text;
begin
 if value ~ '^\d{4}-\d{2}-\d{2}$' then canonical:=value;
 elsif value ~ '^\d{1,2}/\d{1,2}/\d{4}$' then canonical:=split_part(value,'/',3)||'-'||lpad(split_part(value,'/',1),2,'0')||'-'||lpad(split_part(value,'/',2),2,'0');
 else raise exception 'Use YYYY-MM-DD or MM/DD/YYYY';end if;
 result:=canonical::date;
 if result < date '1900-01-01' or result > date '2200-12-31' then raise exception 'Date must be between 1900 and 2200';end if;
 return result;
end $$;
revoke all on function private.import_date(text) from public,anon,authenticated;
create function private.import_productions(t uuid,rows jsonb,commit boolean default false,expected text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare item jsonb; clean jsonb; preview jsonb:='[]'; staged jsonb:='[]'; warnings jsonb; sid uuid; vid uuid; script public.scripts%rowtype; pid uuid; first_day date; last_day date; mins integer; n integer:=1; fingerprint text; key text; seen text[]:='{}'; identity text; script_label text; created integer:=0; new_scripts jsonb:='{}'; signature jsonb;
begin
 if t is null or not private.verified_user() or not private.workspace_admin(t) or not exists(select 1 from public.theaters where id=t) then raise exception 'Theater administrator access required' using errcode='42501';end if;
 if jsonb_typeof(rows) is distinct from 'array' then raise exception 'Supply an array of production rows';end if;
 if jsonb_array_length(rows)<1 or jsonb_array_length(rows)>100 or octet_length(rows::text)>1000000 then raise exception 'Import 1–100 rows, up to 1 MB';end if;
 -- Serialize imports; lookup tables are shared-locked through validation and commit.
 perform pg_advisory_xact_lock(hashtextextended(t::text,72));
 lock table public.seasons,public.venues,public.scripts,public.productions in share row exclusive mode;
 fingerprint:=md5(rows::text||coalesce((select jsonb_agg(x order by x.id)::text from public.seasons x where theater_id=t),'[]')||coalesce((select jsonb_agg(x order by x.id)::text from public.venues x where theater_id=t),'[]')||coalesce((select jsonb_agg(x order by x.id)::text from public.scripts x where theater_id=t),'[]')||coalesce((select jsonb_agg(x order by x.id)::text from public.productions x where theater_id=t),'[]'));
 if commit and (expected is null or expected<>fingerprint) then raise exception 'Data changed since preview. Check the file again before importing.';end if;
 for item in select value from jsonb_array_elements(rows) loop
 n:=n+1;
 begin
 if jsonb_typeof(item) is distinct from 'object' then raise exception 'Expected named CSV fields';end if;
 clean:='{}';
 for key in select jsonb_object_keys(item) loop
 if key<>all(array['title','import_status','full_description','hero_image_url','season_name','production_status','series_name','script_playwright','script_musical','script_composer','rating_name','content_warnings','runtime','opening_date','closing_date','venue_name','program_file_url','sponsor_names','school_trip_sponsor_names','runtime_minutes']) then raise exception 'Unknown column: %',key;end if;
 if jsonb_typeof(item->key) is distinct from 'string' or length(item->>key)>20000 then raise exception 'Invalid or oversized field: %',key;end if;
 clean:=clean||jsonb_build_object(key,trim(item->>key));
 end loop;
 foreach key in array array['title','season_name','opening_date','closing_date'] loop
 if coalesce(clean->>key,'')='' then raise exception '% is required',key;end if;
 end loop;
 if length(clean->>'title')>200 then raise exception 'Title must be 200 characters or fewer';end if;
 if coalesce(clean->>'import_status','') not in ('','Draft','Publish') then raise exception 'import_status must be Draft or Publish';end if;
 if coalesce(clean->>'production_status','') not in ('','In Rehearsal','Open','Now Playing','Closed') then raise exception 'Invalid production_status';end if;
 if coalesce(clean->>'script_musical','') not in ('','Yes','No') then raise exception 'script_musical must be Yes or No';end if;
 foreach key in array array['hero_image_url','program_file_url'] loop
 if coalesce(clean->>key,'')<>'' and (clean->>key !~ '^https?://[^[:space:]]+$' or length(clean->>key)>2048) then raise exception '% must be a full HTTP or HTTPS URL',key;end if;
 end loop;
 first_day:=private.import_date(clean->>'opening_date');last_day:=private.import_date(clean->>'closing_date');
 if last_day<first_day then raise exception 'Closing date must be on or after opening';end if;
 select id into strict sid from public.seasons where theater_id=t and name=clean->>'season_name';
 vid:=null;
 if coalesce(clean->>'venue_name','')<>'' then select id into strict vid from public.venues where theater_id=t and name=clean->>'venue_name';end if;
 identity:=lower(clean->>'title')||':'||sid::text;
 if identity=any(seen) then raise exception 'Duplicate title and season in the file';end if;seen:=array_append(seen,identity);
 if exists(select 1 from public.productions where theater_id=t and season_id=sid and lower(trim(title))=lower(clean->>'title')) then raise exception 'Production already exists in this season. Existing productions cannot be overwritten.';end if;
 mins:=null;
 if coalesce(clean->>'runtime_minutes','')<>'' then
 if clean->>'runtime_minutes' !~ '^\d{1,4}$' then raise exception 'runtime_minutes must be a whole number';end if;
 mins:=(clean->>'runtime_minutes')::integer;if mins<1 or mins>1440 then raise exception 'runtime_minutes must be between 1 and 1440';end if;
 end if;
 select * into script from public.scripts where theater_id=t and title=clean->>'title';
 if script.id is null then
 if coalesce(clean->>'script_playwright','')='' then raise exception 'Playwright is required for a new script';end if;
 script_label:='Create script';
 signature:=jsonb_build_object('playwright',clean->>'script_playwright','musical',coalesce(clean->>'script_musical','')='Yes','composer',coalesce(clean->>'script_composer',''));
 if new_scripts ? (clean->>'title') and new_scripts->(clean->>'title')<>signature then raise exception 'Conflicting script values for the same title in this file';end if;
 new_scripts:=new_scripts||jsonb_build_object(clean->>'title',signature);
 else
 script_label:='Use existing script';
 if (coalesce(clean->>'script_playwright','')<>'' and script.playwright<>clean->>'script_playwright') or (coalesce(clean->>'script_musical','')<>'' and script.musical<>((clean->>'script_musical')='Yes')) or (coalesce(clean->>'script_composer','')<>'' and coalesce(script.composer,'')<>clean->>'script_composer') then raise exception 'Script values conflict with the existing script. Correct the file before importing.';end if;
 end if;
 warnings:='[]';
 if coalesce(clean->>'hero_image_url','')<>'' or coalesce(clean->>'program_file_url','')<>'' then warnings:=warnings||jsonb_build_array('Image and program URLs retained as references; files are not uploaded or displayed.');end if;
 if coalesce(clean->>'sponsor_names','')<>'' or coalesce(clean->>'school_trip_sponsor_names','')<>'' then warnings:=warnings||jsonb_build_array('Sponsor names retained as source metadata; sponsor records are not created.');end if;
 if coalesce(clean->>'production_status','')<>'' then warnings:=warnings||jsonb_build_array('Displayed production status is derived from dates.');end if;
 if mins is null and coalesce(clean->>'runtime','')<>'' then warnings:=warnings||jsonb_build_array('Runtime text saved; numeric scheduling duration is not set.');end if;
 preview:=preview||jsonb_build_array(jsonb_build_object('row',n,'title',clean->>'title','season',clean->>'season_name','venue',coalesce(clean->>'venue_name',''),'opening',first_day,'closing',last_day,'script',script_label,'warnings',warnings));
 staged:=staged||jsonb_build_array(jsonb_build_object('data',clean,'season',sid,'venue',vid,'opening',first_day,'closing',last_day,'minutes',mins));
 exception when no_data_found then raise exception 'CSV row %: Season or venue not found in the selected theater. Match the name exactly.',n;
 when too_many_rows then raise exception 'CSV row %: Ambiguous season or venue name.',n;
 when others then raise exception 'CSV row %: %',n,sqlerrm;
 end;
 end loop;
 if commit then
 for item in select value from jsonb_array_elements(staged) loop
 clean:=item->'data';
 select * into script from public.scripts where theater_id=t and title=clean->>'title';
 if script.id is null then
 insert into public.scripts(theater_id,title,playwright,musical,composer) values(t,clean->>'title',clean->>'script_playwright',coalesce(clean->>'script_musical','')='Yes',nullif(clean->>'script_composer','')) returning * into script;
 end if;
 insert into public.productions(theater_id,title,season_id,script_id,venue_id,series,full_description,rating,content_warnings,runtime,runtime_minutes,opening_date,closing_date,is_demo,publish,import_metadata)
 values(t,clean->>'title',(item->>'season')::uuid,script.id,(item->>'venue')::uuid,coalesce(clean->>'series_name',''),coalesce(clean->>'full_description',''),coalesce(clean->>'rating_name',''),array(select distinct trim(v) from unnest(string_to_array(coalesce(clean->>'content_warnings',''),'|')) v where trim(v)<>''),coalesce(clean->>'runtime',''),(item->>'minutes')::integer,(item->>'opening')::date,(item->>'closing')::date,false,false,clean) returning id into pid;
 created:=created+1;
 end loop;
 insert into private.settings_history(theater_id,actor,section) values(t,auth.uid(),'production_import');
 end if;
 return jsonb_build_object('fingerprint',fingerprint,'rows',preview,'created',created);
end $$;
revoke all on function private.import_productions(uuid,jsonb,boolean,text) from public,anon;
grant execute on function private.import_productions(uuid,jsonb,boolean,text) to authenticated;
create function public.import_productions(t uuid,rows jsonb,commit boolean default false,expected text default null) returns jsonb language sql security invoker set search_path='' as $$select private.import_productions(t,rows,commit,expected)$$;
revoke all on function public.import_productions(uuid,jsonb,boolean,text) from public,anon;
grant execute on function public.import_productions(uuid,jsonb,boolean,text) to authenticated;
