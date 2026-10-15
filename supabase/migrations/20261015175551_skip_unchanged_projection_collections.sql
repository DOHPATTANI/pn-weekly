-- Skip unchanged collections and find deleted entry keys once rather than scanning every stored entry.
CREATE OR REPLACE FUNCTION public.pn2_delete_removed_projection(input_doc jsonb,previous_doc jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $delete8$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';
BEGIN
IF previous_doc->'contractors' IS DISTINCT FROM input_doc->'contractors' THEN DELETE FROM public.pn2_contractors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractors','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'supervisors' IS DISTINCT FROM input_doc->'supervisors' THEN DELETE FROM public.pn2_supervisors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'supervisors','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workTypes' IS DISTINCT FROM input_doc->'workTypes' THEN DELETE FROM public.pn2_work_types t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workTypes','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workNames' IS DISTINCT FROM input_doc->'workNames' THEN DELETE FROM public.pn2_work_names t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workNames','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workCodes' IS DISTINCT FROM input_doc->'workCodes' THEN DELETE FROM public.pn2_work_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workCodes','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'budgetAccounts' IS DISTINCT FROM input_doc->'budgetAccounts' THEN DELETE FROM public.pn2_budget_accounts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'budgetAccounts','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'categories' IS DISTINCT FROM input_doc->'categories' THEN DELETE FROM public.pn2_categories t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'categories','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'fundingSources' IS DISTINCT FROM input_doc->'fundingSources' THEN DELETE FROM public.pn2_funding_sources t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'fundingSources','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'projects' IS DISTINCT FROM input_doc->'projects' THEN DELETE FROM public.pn2_contracts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'projects','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'reports' IS DISTINCT FROM input_doc->'reports' THEN DELETE FROM public.pn2_reports t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'reports','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'contractRegistry' IS DISTINCT FROM input_doc->'contractRegistry' THEN DELETE FROM public.pn2_contract_registry t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'years' IS DISTINCT FROM input_doc->'years' THEN DELETE FROM public.pn2_fiscal_years t WHERE workspace_id=uid AND NOT input_doc->'years' @> to_jsonb(ARRAY[t.year]);END IF;
IF previous_doc->'reports' IS DISTINCT FROM input_doc->'reports' THEN
 WITH old_rows AS MATERIALIZED(SELECT r->>'id' id,r->'entries' entries FROM jsonb_array_elements(coalesce(previous_doc->'reports','[]')) r),
 new_rows AS MATERIALIZED(SELECT r->>'id' id,r->'entries' entries FROM jsonb_array_elements(input_doc->'reports') r),
 changed AS MATERIALIZED(SELECT o.id,o.entries AS old_entries,coalesce(n.entries,'{}') AS new_entries FROM old_rows o LEFT JOIN new_rows n ON o.id=n.id WHERE o.entries IS DISTINCT FROM n.entries),
 removed AS(SELECT c.id,k FROM changed c CROSS JOIN LATERAL jsonb_object_keys(c.old_entries) k WHERE NOT c.new_entries ? k)
 DELETE FROM public.pn2_entries t USING removed WHERE t.workspace_id=uid AND t.report_id=removed.id AND t.contract_id=removed.k;
END IF;
IF previous_doc->'projects' IS DISTINCT FROM input_doc->'projects' THEN DELETE FROM public.pn2_extensions t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'projects') p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p->'extensions','[]')) x WHERE x->>'id'=t.id);END IF;
IF previous_doc->'workNames' IS DISTINCT FROM input_doc->'workNames' THEN DELETE FROM public.pn2_work_name_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'workNames') w WHERE w->>'id'=t.work_name_id AND w->'codeIds' @> to_jsonb(ARRAY[t.work_code_id]));END IF;
IF previous_doc->'contractRegistry' IS DISTINCT FROM input_doc->'contractRegistry' THEN DELETE FROM public.pn2_registry_work_links t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'contractRegistry') r WHERE r->>'workCode'=t.work_code AND r->>'title'=t.title);END IF;
END $delete8$;
REVOKE ALL ON FUNCTION public.pn2_delete_removed_projection(jsonb,jsonb) FROM PUBLIC;
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
 select public.pn2_hydrate_document(document,false),revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
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
    prev:=previous_entries->e.key;
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
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_supervisors is distinct from excluded;end if;
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
 for p in select value from jsonb_array_elements(project_list)loop
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
 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=excluded.work_type_id where pn2_registry_work_links is distinct from excluded;end if;
 end loop;

 end if;
 if old_doc->'contractors' is distinct from payload->'contractors' then
 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 end if;
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;




NOTIFY pgrst,'reload schema';

-- Compact imports append a single cold run without reassembling all prior history.
-- Compact audited CSV/XLSX import. Merge against authoritative full document inside the transaction; never transmit unloaded reports.
CREATE OR REPLACE FUNCTION public.pn2_import_changes(changes jsonb,expected_revision bigint,source jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;before_doc jsonb;diff jsonb;labels jsonb;run jsonb;run_id uuid:=gen_random_uuid();prior_import text;prior_delta text;delta_ids jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;result jsonb;audit_entry jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT public.pn2_hydrate_document(document,false),revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
 IF rev IS NULL OR rev<>expected_revision THEN RAISE EXCEPTION 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';END IF;
 before_doc:=doc;
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
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 IF source->>'format' NOT IN ('CSV','XLSX') OR source->>'format' IS NULL THEN RAISE EXCEPTION 'ใช้สำหรับ CSV หรือ XLSX เท่านั้น';END IF;
 audit_entry:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action','นำเข้าไฟล์ '||left(coalesce(source->>'fileName','CSV'),250));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(audit_entry)||coalesce(doc->'audit','[]'));
 diff:=public.pn2_import_diff(before_doc,doc);
 IF jsonb_array_length(diff)=0 THEN RETURN jsonb_build_object('revision',rev);END IF;
 SELECT coalesce(jsonb_object_agg(x->>'id',coalesce(x->>'contract',x->>'title',x->>'name',x->>'id')),'{}') INTO labels
 FROM (SELECT x FROM jsonb_each(before_doc) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id' UNION ALL SELECT x FROM jsonb_each(doc) e CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(e.value)='array' THEN e.value ELSE '[]' END) x WHERE x ? 'id') names
 WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(diff) d WHERE x->>'id'=ANY(string_to_array(d->>'path',' / ')));
 run:=jsonb_build_object('id',run_id,'labels',labels,'at',now(),'fileName',left(coalesce(source->>'fileName','CSV'),250),'format',source->>'format','changes',diff);
 INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT uid,run_id::text,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=uid;
 INSERT INTO public.pn2_import_archives(id,workspace_id,file_name,format,before_document,after_document,changes) VALUES(run_id,uid,run->>'fileName',run->>'format',jsonb_build_object('storageFormat','delta-v1','changes',diff),jsonb_build_object('storageFormat','delta-v1','run',run),diff);
 SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) changed_reports;
 prior_import:=current_setting('pn2.importing',true);prior_delta:=current_setting('pn2.delta_report_ids',true);
 PERFORM set_config('pn2.importing','yes',true);PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.importing',coalesce(prior_import,''),true);PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result||jsonb_build_object('importRun',run,'auditEntry',audit_entry);
END $patch$;

NOTIFY pgrst,'reload schema';
-- Compact the report array in one aggregate, avoiding repeated growth/copies in a PL/pgSQL loop.
CREATE OR REPLACE FUNCTION public.pn2_compact_document() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $compactset8$
DECLARE reports jsonb;report_ids jsonb;
BEGIN
 IF NEW.document ? 'importHistory' THEN
  INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload)
  SELECT NEW.workspace_id,x->>'id',pos,x FROM jsonb_array_elements(NEW.document->'importHistory') WITH ORDINALITY v(x,pos) WHERE nullif(x->>'id','') IS NOT NULL
  ON CONFLICT(workspace_id,id) DO UPDATE SET ordinal=excluded.ordinal,payload=excluded.payload WHERE row(pn2_import_runs.ordinal,pn2_import_runs.payload) IS DISTINCT FROM row(excluded.ordinal,excluded.payload);
 END IF;
 INSERT INTO public.pn2_report_snapshots(workspace_id,report_id,payload)
 SELECT NEW.workspace_id,r->>'id',CASE WHEN r ? 'snapshots' THEN jsonb_build_object('snapshots',r->'snapshots') ELSE '{}'::jsonb END || CASE WHEN r ? 'settingsSnapshot' THEN jsonb_build_object('settingsSnapshot',r->'settingsSnapshot') ELSE '{}'::jsonb END
 FROM jsonb_array_elements(NEW.document->'reports') r WHERE r ? 'snapshots' OR r ? 'settingsSnapshot'
 ON CONFLICT(workspace_id,report_id) DO UPDATE SET payload=excluded.payload WHERE pn2_report_snapshots.payload IS DISTINCT FROM excluded.payload;
 SELECT coalesce(jsonb_agg((r-'snapshots'-'settingsSnapshot')||jsonb_build_object('_storedSnapshot',true) ORDER BY ord),'[]'),coalesce(jsonb_object_agg(r->>'id',true),'{}') INTO reports,report_ids FROM jsonb_array_elements(NEW.document->'reports') WITH ORDINALITY v(r,ord);
 DELETE FROM public.pn2_report_snapshots s WHERE workspace_id=NEW.workspace_id AND NOT report_ids ? s.report_id;
 NEW.document:=(NEW.document-'importHistory')||jsonb_build_object('reports',reports);RETURN NEW;
END $compactset8$;
NOTIFY pgrst,'reload schema';
