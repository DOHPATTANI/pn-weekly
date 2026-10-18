-- v13: compatible personnel rename and bounded task writes. No business record is removed.
ALTER TABLE public.pn2_supervisors RENAME TO pn2_personnel;
ALTER TABLE public.pn2_personnel ADD COLUMN position_name text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_personnel ADD COLUMN person_roles jsonb NOT NULL DEFAULT '[]';
-- Preserve legacy relation name for read integrations. All internal writers move to the real table.
CREATE VIEW public.pn2_supervisors WITH (security_invoker=true) AS SELECT workspace_id,id,name,archived,code FROM public.pn2_personnel;
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT oid,pg_get_functiondef(oid) body FROM pg_proc WHERE pronamespace='public'::regnamespace AND prokind='f' AND prosrc LIKE '%pn2_supervisors%' LOOP
  EXECUTE replace(f.body,'pn2_supervisors','pn2_personnel');
 END LOOP;
END $migration$;
UPDATE public.pn2_personnel p SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'supervisors') x WHERE p.workspace_id=w.workspace_id AND p.id=x->>'id';
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT oid,conname FROM pg_constraint WHERE conrelid='public.pn2_contracts'::regclass AND contype='f' AND confrelid='public.pn2_fiscal_years'::regclass ORDER BY oid OFFSET 1 LOOP
  EXECUTE format('ALTER TABLE public.pn2_contracts DROP CONSTRAINT %I',f.conname);
 END LOOP;
END $migration$;

-- Hydrate only reports whose content is actually changing. Other snapshots remain cold.
CREATE FUNCTION public.pn2_hydrate_changed(doc jsonb, ids jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path='' AS $$
 SELECT jsonb_set(doc-'importHistory','{reports}',coalesce((SELECT jsonb_agg(CASE WHEN ids @> jsonb_build_array(r->>'id') THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE r END ORDER BY ord) FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id'),'[]'))
$$;
CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb, expected_revision bigint, action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;prior_delta text;delta_ids jsonb;result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select public.pn2_hydrate_changed(document,coalesce((SELECT jsonb_agg(x->>'id') FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x),'[]')),revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 IF jsonb_typeof(changes)<>'object' OR octet_length(changes::text)>30000000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
 IF coalesce(changes->'values','{}'::jsonb)='{}'::jsonb AND coalesce(changes->'collections','{}'::jsonb)='{}'::jsonb THEN RETURN jsonb_build_object('revision',rev);END IF;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'values','{}')) LOOP
  IF k<>ALL(ARRAY['settings','years','yearCodes','masterSequences','issues']) THEN RAISE EXCEPTION 'ช่องข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  IF k='settings' THEN doc:=jsonb_set(doc,ARRAY[k],coalesce(doc->k,'{}'::jsonb)||item);ELSE doc:=jsonb_set(doc,ARRAY[k],item);END IF;
 END LOOP;
 FOR k,item IN SELECT key,value FROM jsonb_each(coalesce(changes->'collections','{}')) LOOP
  IF k<>ALL(ARRAY['projects','reports','contractRegistry','categories','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) THEN RAISE EXCEPTION 'ชุดข้อมูลเปลี่ยนแปลงไม่ถูกต้อง';END IF;
  removed:=coalesce(item->'remove','[]');
  IF jsonb_typeof(removed)<>'array' OR jsonb_typeof(coalesce(item->'upsert','[]'))<>'array' THEN RAISE EXCEPTION 'รูปแบบรายการไม่ถูกต้อง';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x WHERE jsonb_typeof(x)<>'object' OR nullif(x->>'id','') IS NULL OR x ? '_unloaded') THEN RAISE EXCEPTION 'ข้อมูลรายงานยังโหลดไม่ครบหรือไม่มีรหัส';END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(coalesce(item->'upsert','[]')))<>(SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x) THEN RAISE EXCEPTION 'รหัสรายการซ้ำ';END IF;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO upserts FROM jsonb_array_elements(coalesce(item->'upsert','[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',true),'{}') INTO old_ids FROM jsonb_array_elements(coalesce(doc->k,'[]')) x;
  SELECT coalesce(jsonb_agg(CASE WHEN k='contractRegistry' AND upserts ? (x->>'id') THEN (SELECT coalesce(jsonb_object_agg(key,value),'{}') FROM jsonb_each(x) WHERE key=ANY(ARRAY['sourceSheet','sourceRow','sourceEnd']))||(upserts->(x->>'id')) ELSE coalesce(upserts->(x->>'id'),x) END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 prior_delta:=current_setting('pn2.delta_report_ids',true);
 IF true THEN
  SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' AS id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) ids;
  PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 END IF;
 PERFORM set_config('pn2.changed_collections',coalesce(changes->'collections','{}')::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.changed_collections','',true);
 PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result;
END $function$
;
CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;new_locked boolean;existing jsonb;ext jsonb;extsum integer;expected_end date;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
begin
 -- No user session, email, password, or Supabase Auth record required.
 -- Serializes the first insert too; optimistic revision prevents silent overwrites.
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select CASE WHEN nullif(current_setting('pn2.delta_report_ids',true),'') IS NULL THEN public.pn2_hydrate_document(document,false) ELSE public.pn2_hydrate_changed(document,current_setting('pn2.delta_report_ids')::jsonb) END,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
 old_rev:=coalesce(old_rev,0);
 -- An empty bootstrap workspace may be initialized from the original JSON.
 if old_doc is not null and jsonb_array_length(old_doc->'projects')=0 and not exists(select 1 from jsonb_array_elements(old_doc->'reports') x where x->>'id'<>'EMPTY') then old_doc:=null;end if;
 if expected_revision<>old_rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then payload:=(payload-'importHistory')||jsonb_build_object('importHistory',coalesce(old_doc->'importHistory','[]'::jsonb));end if;
 if payload->>'version'<>'1' or jsonb_typeof(payload->'projects')<>'array' or jsonb_typeof(payload->'reports')<>'array' or jsonb_typeof(payload->'categories')<>'array' or jsonb_typeof(payload->'years')<>'array' or jsonb_array_length(payload->'reports')=0 then raise exception 'รูปแบบข้อมูลไม่ถูกต้อง';end if;
 if octet_length(payload::text)>30000000 then raise exception 'ข้อมูลเกินขนาด 30 MB';end if;
 -- Cache report collections once: repeated array expansion spilled megabytes to disk per report.
 history_list:=payload->'reports';report_list:=history_list;project_list:=payload->'projects';
 delta_ids:=nullif(current_setting('pn2.delta_report_ids',true),'')::jsonb;
 if delta_ids is not null then select coalesce(jsonb_agg(x),'[]') into report_list from jsonb_array_elements(history_list) x where delta_ids @> jsonb_build_array(x->>'id');end if;
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO old_reports FROM jsonb_array_elements(coalesce(old_doc->'reports','[]'::jsonb)) x where delta_ids is null or delta_ids @> jsonb_build_array(x->>'id');
 SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}'::jsonb) INTO new_reports FROM jsonb_array_elements(report_list) x;
 -- Published history cannot be removed or edited by changing the browser request.
 if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' then
  for v in select value from jsonb_each(old_reports) where (value->>'locked')::boolean loop
   existing:=new_reports->(v->>'id');
   if existing is null then raise exception 'ลบรายงานที่เก็บแล้วไม่ได้';end if;
   if existing<>v and current_setting('pn2.amending',true) is distinct from 'yes' then raise exception 'ใช้ปุ่มแก้ไขรายงานย้อนหลังเพื่อบันทึกประวัติ';end if;
  end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list) loop
  if r=old_reports->(r->>'id') and coalesce((r->>'locked')::boolean,false) then continue;end if;
  if coalesce((r->>'imported')::boolean,false) then
   if old_doc is not null and current_setting('pn2.importing',true) is distinct from 'yes' and coalesce(old_reports->(r->>'id')->>'imported','false')<>'true' then raise exception 'เพิ่มประวัตินำเข้าได้เฉพาะการเริ่มพื้นที่ข้อมูล';end if;
  else
   if (r->>'end')::date-(r->>'start')::date<>6 or (r->>'reference')::date<>(r->>'end')::date or extract(isodow from (r->>'end')::date)<>1 then raise exception 'รอบรายงานต้องเป็นอังคารถึงจันทร์';end if;
  end if;
  previous_entries:='{}'::jsonb;
  if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
   -- Read prior reports once per changed report, not once for every contract.
   SELECT coalesce(jsonb_object_agg(contract_id,entry),'{}'::jsonb) INTO previous_entries FROM (
    SELECT DISTINCT ON (item.key) item.key AS contract_id,item.value AS entry
    FROM jsonb_array_elements(history_list) WITH ORDINALITY AS hist(x,ord)
    CROSS JOIN LATERAL jsonb_each(x->'entries') item
    WHERE nullif(x->>'end','')::date<(r->>'start')::date
     AND coalesce(x->>'funding','DOH')=coalesce(r->>'funding','DOH')
     AND (x->>'year' IS NULL OR x->>'year'=r->>'year')
    ORDER BY item.key,nullif(x->>'end','')::date DESC,ord
   ) prior_rows;
  end if;
  for e in select * from jsonb_each(r->'entries') loop
   v:=e.value;
   if nullif(v->>'deliveryDate','')::date>nullif(v->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
   if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'acceptanceDate','')::date>nullif(v->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
   if (v->>'plan')::numeric not between 0 and 100 or (v->>'weekly')::numeric not between 0 and 100 or (v->>'actual')::numeric not between 0 and 100 then raise exception 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';end if;
   if not coalesce((r->>'imported')::boolean,false) and current_setting('pn2.importing',true) is distinct from 'yes' then
    if (r->>'locked')::boolean then p:=r->'snapshots'->e.key;else select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;end if;
    if coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') or (p->>'year')::integer<>(r->>'year')::integer then raise exception 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';end if;
    prev:=coalesce(previous_entries->e.key,payload->'settings'->'reportBaselines'->(r->>'id')->e.key);
    -- An inherited paid legacy row may have no documented day. Keep it unknown in drafts.
    -- Newly paid rows still require a day, and closing any new report requires complete dates.
    if v->>'payment'='เบิกจ่ายแล้ว' and nullif(v->>'paymentDate','') is null
     and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true'
     and (coalesce((r->>'locked')::boolean,false) or coalesce(prev->>'payment','')<>'เบิกจ่ายแล้ว' or nullif(prev->>'paymentDate','') is not null)
     then raise exception 'สัญญา %: กรุณาบันทึกวันที่เบิกจ่ายก่อนปิดรายงาน',e.key;end if;
    prior_actual:=coalesce((prev->>'actual')::numeric,0);
    if abs((v->>'actual')::numeric-prior_actual-(v->>'weekly')::numeric)>0.011 then raise exception 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';end if;
    if (r->>'locked')::boolean and not (v->>'confirmed')::boolean then raise exception 'ต้องยืนยันทุกโครงการก่อนปิดรายงาน';end if;
    if (r->>'locked')::boolean and (r->'snapshots'->e.key) is null then raise exception 'รายงานที่ปิดแล้วต้องมีข้อมูลสัญญา ณ วันรายงาน';end if;
    if (r->>'locked')::boolean and coalesce(old_reports->(r->>'id')->>'locked','false')<>'true' then
     select value into p from jsonb_array_elements(project_list) where value->>'id'=e.key;
     if p is null or p<>(r->'snapshots'->e.key) then raise exception 'ข้อมูลสัญญาขณะปิดรายงานไม่ตรงกับทะเบียน';end if;
    end if;
   end if;
  end loop;
 end loop;
 new_rev:=old_rev+1;
 insert into public.pn2_workspaces(workspace_id,revision,document)values(uid,new_rev,payload||jsonb_build_object('revision',new_rev))on conflict(workspace_id)do update set revision=new_rev,document=excluded.document,updated_at=now();

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload,old_doc);
 if old_doc->'years' is distinct from payload->'years' or old_doc->'yearCodes' is distinct from payload->'yearCodes' then
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 end if;
 if old_doc->'categories' is distinct from payload->'categories' then
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;
 end if;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_personnel(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_personnel existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_personnel is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 if old_doc->'workNames' is distinct from payload->'workNames' then
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 end if;
 if old_doc->'projects' is distinct from payload->'projects' then
 for p in select value from jsonb_array_elements(project_list) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'projects'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 end if;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 if old_doc->'contractRegistry' is distinct from payload->'contractRegistry' then
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) WHERE nullif(current_setting('pn2.changed_collections',true),'') IS NULL OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(current_setting('pn2.changed_collections')::jsonb->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=value->>'id') loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then UPDATE public.pn2_personnel n SET position_name=coalesce(x->>'position',''),person_roles=coalesce(x->'personRoles','[]') FROM jsonb_array_elements(payload->'supervisors') x WHERE n.workspace_id=uid AND n.id=x->>'id' AND row(n.position_name,n.person_roles) IS DISTINCT FROM row(coalesce(x->>'position',''),coalesce(x->'personRoles','[]'));end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;

-- Redundant text pairs are a read model of registry rows, not a second writable catalogue.
DO $migration$ DECLARE f record; BEGIN
 FOR f IN SELECT pg_get_functiondef(oid) body FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname='pn2_delete_removed_projection' LOOP
  EXECUTE regexp_replace(regexp_replace(f.body,'IF previous_doc->''contractRegistry'' IS DISTINCT FROM input_doc->''contractRegistry'' THEN DELETE FROM public.pn2_registry_work_links[^;]+;END IF;','','gi'),'DELETE FROM public.pn2_registry_work_links[^;]+;','','gi');
 END LOOP;
END $migration$;
DROP TABLE public.pn2_registry_work_links;
CREATE VIEW public.pn2_registry_work_links WITH (security_invoker=true) AS
 SELECT DISTINCT ON(workspace_id,work_code,title) workspace_id,work_code,title,work_type_id
 FROM public.pn2_contract_registry WHERE nullif(work_code,'') IS NOT NULL
 ORDER BY workspace_id,work_code,title,(work_type_id IS NULL),id;
GRANT SELECT ON public.pn2_registry_work_links TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL::text, requested_year integer DEFAULT NULL::integer, requested_report text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '15s'
AS $function$
DECLARE doc jsonb;rev bigint;yr integer;fund text;chosen text;selected_start text;recent jsonb;report_rows jsonb;prior jsonb;latest jsonb;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 yr:=requested_year;IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max((p->>'year')::integer) INTO yr FROM jsonb_array_elements(doc->'projects') p;END IF;
 yr:=coalesce(yr,2569);fund:=requested_funding;
 IF fund IS NULL OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'fundingSources') p WHERE p->>'id'=fund) THEN SELECT coalesce(p->>'funding','DOH') INTO fund FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr ORDER BY (coalesce(p->>'funding','DOH')='DOH') DESC LIMIT 1;END IF;fund:=coalesce(fund,'DOH');
 SELECT r->>'id',r->>'start' INTO chosen,selected_start FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY (r->>'id'=requested_report) DESC NULLS LAST,nullif(r->>'end','') DESC NULLS LAST,ord LIMIT 1;
 SELECT coalesce(jsonb_agg(id),'[]') INTO recent FROM (SELECT r->>'id' id FROM jsonb_array_elements(doc->'reports') r WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr ORDER BY nullif(r->>'end','') DESC NULLS LAST LIMIT 6) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO prior FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND r->>'end'<selected_start ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_object_agg(key,value),'{}') INTO latest FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(doc->'reports') r CROSS JOIN LATERAL jsonb_each(r->'entries') e WHERE coalesce(r->>'funding','DOH')=fund AND (r->>'year')::integer=yr AND nullif(r->>'end','') IS NOT NULL ORDER BY e.key,r->>'end' DESC) t;
 SELECT coalesce(jsonb_agg(CASE WHEN r->>'id'=chosen THEN (r-'_storedSnapshot')||coalesce(s.payload,'{}') ELSE
 (r-'entries'-'snapshots'-'settingsSnapshot'-'_storedSnapshot')||jsonb_build_object('entries',CASE WHEN recent @> jsonb_build_array(r->>'id') THEN r->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'_unloaded',true,'_entryCount',(SELECT count(*) FROM jsonb_object_keys(r->'entries')),'_missingPaymentDates',(SELECT coalesce(jsonb_agg(jsonb_build_array(e.key,'{}'::jsonb)),'[]') FROM jsonb_each(r->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND coalesce(e.value->>'paymentDate','')='')) END ORDER BY ord),'[]') INTO report_rows
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 RETURN (doc-'importHistory')||jsonb_build_object('projects',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contracts WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'contractRegistry',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM (SELECT payload AS p FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND fiscal_year=yr AND funding_source=fund) v),'reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen,'previousEntries',prior,'latestEntries',latest));
END $function$
;

-- Normal screens omit amendment bodies and source-sheet coordinates. Full backup/source imports keep them.
CREATE FUNCTION public.pn2_load_screen(requested_funding text DEFAULT NULL, requested_year integer DEFAULT NULL, requested_report text DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $$
DECLARE d jsonb; BEGIN
 d:=public.pn2_load_scope(requested_funding,requested_year,requested_report);
 IF d IS NULL THEN RETURN NULL;END IF;
 d:=jsonb_set(d,'{settings}',(d->'settings')-'logo');
 RETURN jsonb_set(d-'amendments','{contractRegistry}',coalesce((SELECT jsonb_agg(r-ARRAY['sourceSheet','sourceRow','sourceEnd']) FROM jsonb_array_elements(d->'contractRegistry') r),'[]'))||jsonb_build_object('referenceDeferred',true);
END $$;
GRANT EXECUTE ON FUNCTION public.pn2_load_screen(text,integer,text) TO anon,authenticated;
CREATE FUNCTION public.pn2_load_branding(known_hash text DEFAULT '') RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $brand$
 SELECT CASE WHEN md5(coalesce(document#>>'{settings,logo}',''))=coalesce(known_hash,'') THEN jsonb_build_object('hash',known_hash,'notModified',true) ELSE jsonb_build_object('hash',md5(coalesce(document#>>'{settings,logo}','')),'logo',coalesce(document#>>'{settings,logo}','')) END FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid
$brand$;
GRANT EXECUTE ON FUNCTION public.pn2_load_branding(text) TO anon,authenticated;

-- A common weekly edit touches exactly one entry; other linked edits use the established patch validator.
CREATE OR REPLACE FUNCTION public.pn2_save_entry(report_id text, contract_id text, entry jsonb, changes jsonb, expected_revision bigint, action text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;old_entry jsonb;previous jsonb;idx integer;p jsonb;patch jsonb;event jsonb;new_rev bigint;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 IF jsonb_typeof(entry)<>'object' OR octet_length(entry::text)>100000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลผลงานไม่ถูกต้อง';END IF;
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 SELECT value,(ord-1)::integer INTO r,idx FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(value,ord) WHERE value->>'id'=report_id;
 IF r IS NULL OR NOT r->'entries' ? contract_id THEN RAISE EXCEPTION 'ไม่พบสัญญาในรายงาน';END IF;
 IF coalesce((r->>'locked')::boolean,false) THEN RAISE EXCEPTION 'รายงานถูกปิดแล้ว ใช้แก้ไขรายงานย้อนหลัง';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) k WHERE k<>ALL(ARRAY['projects','contractRegistry'])) OR coalesce(changes->'values','{}')<>'{}' THEN RAISE EXCEPTION 'ชุดข้อมูลแก้ไขผลงานไม่ถูกต้อง';END IF;
 -- Lifecycle edits also update the linked registry/project and require that shared validation path.
 IF EXISTS(SELECT 1 FROM jsonb_each(coalesce(changes->'collections','{}')) c WHERE coalesce(c.value->'upsert','[]')<>'[]' OR coalesce(c.value->'remove','[]')<>'[]') THEN
  SELECT (public.pn2_load_report_detail(report_id))->'report' INTO r;
  r:=jsonb_set(r,ARRAY['entries',contract_id],entry);
  patch:=coalesce(changes,'{}')||jsonb_build_object('collections',coalesce(changes->'collections','{}')||jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(r),'remove','[]'::jsonb)));
  RETURN public.pn2_patch_workspace(patch,expected_revision,action);
 END IF;
 old_entry:=r->'entries'->contract_id;
 IF old_entry=entry THEN RETURN jsonb_build_object('revision',rev);END IF;
 IF NOT entry ?& ARRAY['plan','weekly','actual','payment','note'] OR entry->>'plan' IS NULL OR entry->>'weekly' IS NULL OR entry->>'actual' IS NULL OR (entry->>'plan')::numeric NOT BETWEEN 0 AND 100 OR (entry->>'weekly')::numeric NOT BETWEEN 0 AND 100 OR (entry->>'actual')::numeric NOT BETWEEN 0 AND 100 THEN RAISE EXCEPTION 'เปอร์เซ็นต์ต้องอยู่ระหว่าง 0 และ 100';END IF;
 IF entry->>'payment' NOT IN ('รอส่งมอบงาน','รอเบิกจ่าย','เบิกจ่ายแล้ว') THEN RAISE EXCEPTION 'สถานะเบิกจ่ายไม่ถูกต้อง';END IF;
 IF nullif(entry->>'deliveryDate','')::date>nullif(entry->>'acceptanceDate','')::date OR (entry->>'payment'='เบิกจ่ายแล้ว' AND nullif(entry->>'acceptanceDate','')::date>nullif(entry->>'paymentDate','')::date) THEN RAISE EXCEPTION 'ลำดับวันที่ไม่ถูกต้อง';END IF;
 IF coalesce((r->>'imported')::boolean,false)=false THEN
  SELECT payload INTO p FROM public.pn2_contracts WHERE workspace_id=uid AND id=contract_id;
  IF p IS NULL OR coalesce(p->>'funding','DOH')<>coalesce(r->>'funding','DOH') OR p->>'year'<>r->>'year' THEN RAISE EXCEPTION 'สัญญาไม่ตรงกับกลุ่มงบหรือปีงบประมาณของรายงาน';END IF;
  SELECT e.payload INTO previous FROM (SELECT pr.end_date,jsonb_build_object('actual',pe.actual_percent,'payment',pe.payment_status,'paymentDate',coalesce(pe.payment_date::text,'')) payload FROM public.pn2_entries pe JOIN public.pn2_reports pr ON pr.workspace_id=pe.workspace_id AND pr.id=pe.report_id WHERE pe.workspace_id=uid AND pe.contract_id=pn2_save_entry.contract_id AND pr.end_date<(r->>'start')::date AND pr.fiscal_year=(r->>'year')::integer AND pr.funding_source=coalesce(r->>'funding','DOH') ORDER BY pr.end_date DESC LIMIT 1) e;
  previous:=coalesce(previous,doc->'settings'->'reportBaselines'->report_id->contract_id);
  IF abs((entry->>'actual')::numeric-coalesce((previous->>'actual')::numeric,0)-(entry->>'weekly')::numeric)>0.011 THEN RAISE EXCEPTION 'ผลงานสะสมไม่ตรงกับรอบก่อนบวกผลงานรายสัปดาห์';END IF;
  IF entry->>'payment'='เบิกจ่ายแล้ว' AND nullif(entry->>'paymentDate','') IS NULL AND (coalesce(previous->>'payment','')<>'เบิกจ่ายแล้ว' OR nullif(previous->>'paymentDate','') IS NOT NULL) THEN RAISE EXCEPTION 'กรุณาบันทึกวันที่เบิกจ่าย';END IF;
 END IF;
 UPDATE public.pn2_entries t SET plan_percent=(entry->>'plan')::numeric,weekly_percent=(entry->>'weekly')::numeric,actual_percent=(entry->>'actual')::numeric,note=coalesce(entry->>'note',''),payment_status=entry->>'payment',confirmed=coalesce((entry->>'confirmed')::boolean,false),payment_date=nullif(entry->>'paymentDate','')::date,delivery_date=nullif(entry->>'deliveryDate','')::date,acceptance_date=nullif(entry->>'acceptanceDate','')::date WHERE t.workspace_id=uid AND t.report_id=pn2_save_entry.report_id AND t.contract_id=pn2_save_entry.contract_id;
 new_rev:=rev+1;event:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกผลงาน'),300));
 doc:=jsonb_set(doc,ARRAY['reports',idx::text,'entries',contract_id],entry);
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(event)||coalesce(doc->'audit','[]'));
 UPDATE public.pn2_workspaces SET document=jsonb_set(doc,'{revision}',to_jsonb(new_rev)),revision=new_rev,updated_at=now() WHERE workspace_id=uid;
 INSERT INTO public.pn2_audit(workspace_id,revision,action) VALUES(uid,new_rev,event->>'action');
 RETURN jsonb_build_object('revision',new_rev,'auditEntry',event);
END $$;
