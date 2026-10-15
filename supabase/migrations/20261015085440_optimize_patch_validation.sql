-- Restrict validation to server-merged delta reports; full saves retain full validation.
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
 select document,revision into old_doc,old_rev from public.pn2_workspaces where workspace_id=uid for update;
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

 -- Weekly and settings edits do not rebuild unchanged contracts, masters or historical entries.
 if old_doc is not null and not exists (
  select 1 from unnest(array['projects','contractRegistry','categories','years','yearCodes','contractors','supervisors','workTypes','workNames','workCodes','budgetAccounts','fundingSources']) k where old_doc->k is distinct from payload->k
 ) then
  delete from public.pn2_entries where workspace_id=uid and report_id in (select key from jsonb_each(old_reports) where not new_reports ? key);
  delete from public.pn2_reports where workspace_id=uid and id in (select key from jsonb_each(old_reports)) and not new_reports ? id;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  delete from public.pn2_entries where workspace_id=uid and report_id=r->>'id';
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source;
  update public.pn2_reports set funding_source=coalesce(r->>'funding','DOH') where workspace_id=uid and id=r->>'id';
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,r->'snapshots'->entry_row.key,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row;
 end loop;
  insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','บันทึกข้อมูล'));
  return jsonb_build_object('revision',new_rev);
 end if;
 delete from public.pn2_work_name_codes where workspace_id=uid;delete from public.pn2_contract_registry where workspace_id=uid;delete from public.pn2_registry_work_links where workspace_id=uid;
 -- Materialized relational records are refreshed in the SAME transaction.
 delete from public.pn2_entries where workspace_id=uid;delete from public.pn2_reports where workspace_id=uid;delete from public.pn2_extensions where workspace_id=uid;delete from public.pn2_contracts where workspace_id=uid;delete from public.pn2_categories where workspace_id=uid;delete from public.pn2_fiscal_years where workspace_id=uid;if old_doc->'contractors' is distinct from payload->'contractors' then delete from public.pn2_contractors existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'contractors','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;if old_doc->'supervisors' is distinct from payload->'supervisors' then delete from public.pn2_supervisors existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'supervisors','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;delete from public.pn2_work_names where workspace_id=uid;if old_doc->'workTypes' is distinct from payload->'workTypes' then delete from public.pn2_work_types existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'workTypes','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;delete from public.pn2_funding_sources where workspace_id=uid;if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then delete from public.pn2_budget_accounts existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;if old_doc->'workCodes' is distinct from payload->'workCodes' then delete from public.pn2_work_codes existing where workspace_id=uid and not exists(select 1 from jsonb_array_elements(coalesce(payload->'workCodes','[]')) incoming_row where incoming_row->>'id'=existing.id); end if;
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}'));end loop;
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name');end loop;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code',''));end loop;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name');end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'));
  update public.pn2_contracts set registry_id=nullif(p->>'registryId',''),contractor_id=nullif(p->>'contractorId',''),supervisor_id=nullif(p->>'supervisorId',''),work_name_id=nullif(p->>'workNameId',''),work_type_id=nullif(p->>'workTypeId',''),funding_source=coalesce(p->>'funding','DOH') where workspace_id=uid and id=p->>'id';
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v);end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots',coalesce(r->>'funding','DOH'));
  update public.pn2_reports set funding_source=coalesce(r->>'funding','DOH') where workspace_id=uid and id=r->>'id';
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,r->'snapshots'->entry_row.key,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row;
 end loop;

 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false));
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=coalesce(excluded.work_type_id,public.pn2_registry_work_links.work_type_id);end if;
 end loop;

 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;



CREATE OR REPLACE FUNCTION public.pn2_patch_workspace(changes jsonb,expected_revision bigint,action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;prior_delta text;delta_ids jsonb;result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
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
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'at',now(),'action',left(coalesce(action,'บันทึกข้อมูล'),300)))||coalesce(doc->'audit','[]'));
 prior_delta:=current_setting('pn2.delta_report_ids',true);
 IF NOT EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) key WHERE key<>'reports')
 AND NOT EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'values','{}')) key WHERE key<>ALL(ARRAY['settings','issues','masterSequences'])) THEN
  SELECT coalesce(jsonb_agg(id),'[]') INTO delta_ids FROM (SELECT x->>'id' AS id FROM jsonb_array_elements(coalesce(changes->'collections'->'reports'->'upsert','[]')) x UNION SELECT value FROM jsonb_array_elements_text(coalesce(changes->'collections'->'reports'->'remove','[]'))) ids;
  PERFORM set_config('pn2.delta_report_ids',delta_ids::text,true);
 END IF;
 result:=public.pn2_save_workspace(doc,expected_revision);
 PERFORM set_config('pn2.delta_report_ids',coalesce(prior_delta,''),true);
 RETURN result;
END $patch$;

NOTIFY pgrst,'reload schema';
