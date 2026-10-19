-- ============================================================================
-- Migration: 20261020090000_master_developer_rules_optimization.sql
-- Repository: https://github.com/DOHPATTANI/pn-weekly.git
-- Purpose:
--   1. Add 6 composite indexes aligned with WHERE / JOIN / ORDER BY clauses
--   2. Eliminate all SELECT * in PL/pgSQL functions (pn2_save_workspace,
--      pn2_amend_report) and remove unused local variables
--   3. Preserve v14pn2_load_scope & pn2_patch_workspace behaviors
--   4. Reload PostgREST schema cache automatically on push
-- ============================================================================

begin;

create index if not exists pn2_reports_scope_end_idx
  on public.pn2_reports (workspace_id, funding_source, fiscal_year, end_date desc);

create index if not exists pn2_contracts_scope_idx
  on public.pn2_contracts (workspace_id, funding_source, fiscal_year)
  where not archived;

create index if not exists pn2_import_runs_ordinal_idx
  on public.pn2_import_runs (workspace_id, ordinal asc);

create index if not exists pn2_audit_workspace_rev_idx
  on public.pn2_audit (workspace_id, revision desc, created_at desc);

create index if not exists pn2_registry_segments_lookup_idx
  on public.pn2_registry_segments (workspace_id, registry_id, ordinal);

create index if not exists pn2_registry_personnel_lookup_idx
  on public.pn2_registry_personnel (workspace_id, registry_id, role, ordinal);

CREATE OR REPLACE FUNCTION public.pn2_save_workspace(payload jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET statement_timeout TO '25s'
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001'::uuid;old_doc jsonb;old_rev bigint;new_rev bigint;v jsonb;r jsonb;e record;p jsonb;prev jsonb;prior_actual numeric;existing jsonb;ext jsonb;old_reports jsonb;new_reports jsonb;report_list jsonb;project_list jsonb;previous_entries jsonb;history_list jsonb;delta_ids jsonb;
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
  for e in select key, value from jsonb_each(r->'entries') loop
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

CREATE OR REPLACE FUNCTION public.pn2_amend_report(report_id text, entries_patch jsonb, expected_revision bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;r jsonb;before_r jsonb;change record;e jsonb;old_e jsonb;prior numeric;changed_actual boolean;changed_weekly boolean;later jsonb;later_e jsonb;new_weekly numeric;affected jsonb:='[]';result jsonb;ts text:=now()::text;previous_flag text;has_changes boolean:=false;
begin
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 select document,revision into doc,rev from public.pn2_workspaces where workspace_id=uid for update;
 if doc is null then raise exception 'ไม่พบพื้นที่ข้อมูล';end if;
 if expected_revision<>rev then raise exception 'ข้อมูลถูกแก้ไขจากอีกหน้าจอ กรุณาโหลดล่าสุดก่อนบันทึก';end if;
 select value into r from jsonb_array_elements(doc->'reports') x where x->>'id'=report_id;
 if r is null then raise exception 'ไม่พบรายงาน';end if;before_r:=r;
 if jsonb_typeof(entries_patch)<>'object' or entries_patch='{}' then raise exception 'ไม่มีข้อมูลเปลี่ยนแปลง';end if;
 for change in select key, value from jsonb_each(entries_patch) loop
  if not (r->'entries' ? change.key) then raise exception 'ไม่พบสัญญาในรายงาน';end if;
  if jsonb_typeof(change.value)<>'object' or exists(select 1 from jsonb_object_keys(change.value) k where k not in ('plan','weekly','actual','note','payment','paymentDate','deliveryDate','acceptanceDate')) then raise exception 'ช่องแก้ไขไม่ถูกต้อง';end if;
  old_e:=r->'entries'->change.key;e:=old_e||change.value;
  changed_actual:=(e->>'actual')::numeric<>(old_e->>'actual')::numeric;
  changed_weekly:=(e->>'weekly')::numeric<>(old_e->>'weekly')::numeric;
  if changed_actual or changed_weekly then
   if nullif(r->>'start','') is null or nullif(r->>'end','') is null then raise exception 'รายงานไม่มีช่วงวันที่ จึงยังแก้เปอร์เซ็นต์ย้อนหลังไม่ได้';end if;
   select coalesce((x->'entries'->change.key->>'actual')::numeric,0) into prior from jsonb_array_elements(doc->'reports') x where x->>'id'<>report_id and (x->>'end')::date<(r->>'start')::date and x->'entries' ? change.key order by (x->>'end')::date desc limit 1;
   prior:=coalesce(prior,(doc->'settings'->'reportBaselines'->report_id->change.key->>'actual')::numeric,0);
   if changed_actual then e:=jsonb_set(e,'{weekly}',to_jsonb(round((e->>'actual')::numeric-prior,2)));else e:=jsonb_set(e,'{actual}',to_jsonb(round(prior+(e->>'weekly')::numeric,2)));end if;
  end if;
  if nullif(e->>'deliveryDate','')::date>nullif(e->>'acceptanceDate','')::date then raise exception 'วันที่ตรวจรับต้องไม่น้อยกว่าวันที่ส่งมอบ';end if;
  if e->>'payment'='เบิกจ่ายแล้ว' and nullif(e->>'acceptanceDate','')::date>nullif(e->>'paymentDate','')::date then raise exception 'วันที่เบิกจ่ายต้องไม่น้อยกว่าวันที่ตรวจรับ';end if;
  if e->>'payment'='เบิกจ่ายแล้ว' and nullif(e->>'paymentDate','') is not null then
   e:=jsonb_set(e,'{note}',to_jsonb(format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from (e->>'paymentDate')::date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from (e->>'paymentDate')::date)::integer],extract(year from (e->>'paymentDate')::date)::integer+543)));
  elsif old_e->>'payment'='เบิกจ่ายแล้ว' and e->>'payment'<>'เบิกจ่ายแล้ว' and e->>'note' like 'เบิกจ่ายแล้ว วันที่ %' then e:=jsonb_set(e,'{note}','""');end if;
  if e<>old_e then has_changes:=true;end if;
  r:=jsonb_set(r,array['entries',change.key],e);
  if (e->>'actual')::numeric<>(old_e->>'actual')::numeric then
   prior:=(e->>'actual')::numeric;
   for later in select value from jsonb_array_elements(doc->'reports') x where (x->>'end')::date>(r->>'end')::date and x->'entries' ? change.key order by (x->>'end')::date loop
    later_e:=later->'entries'->change.key;new_weekly:=round((later_e->>'actual')::numeric-prior,2);
    if new_weekly<0 or new_weekly>100 then raise exception 'ผลงานสะสมใหม่มากกว่าสัปดาห์ถัดไป กรุณาตรวจผลงานสะสมให้สอดคล้องกัน';end if;
    if new_weekly<>(later_e->>'weekly')::numeric then
     later:=jsonb_set(later,array['entries',change.key,'weekly'],to_jsonb(new_weekly));
     later:=later||jsonb_build_object('modifiedAt',ts,'amendedVersion',coalesce((later->>'amendedVersion')::integer,0)+1);
     affected:=affected||jsonb_build_array(later->>'id');
     doc:=jsonb_set(doc,'{reports}',(select jsonb_agg(case when x->>'id'=later->>'id' then later else x end order by ord) from jsonb_array_elements(doc->'reports') with ordinality as v(x,ord)));
    end if;prior:=(later_e->>'actual')::numeric;
   end loop;
  end if;
 end loop;
 if not has_changes then raise exception 'ยังไม่มีข้อมูลเปลี่ยนแปลง';end if;
 r:=r||jsonb_build_object('modifiedAt',ts,'amendedVersion',coalesce((r->>'amendedVersion')::integer,0)+1);
 doc:=jsonb_set(doc,'{reports}',(select jsonb_agg(case when x->>'id'=report_id then r else x end order by ord) from jsonb_array_elements(doc->'reports') with ordinality as v(x,ord)));
 doc:=jsonb_set(doc,'{amendments}',(select jsonb_agg(x order by ord) from (select x,ord from jsonb_array_elements(jsonb_build_array(jsonb_build_object('reportId',report_id,'at',ts,'beforeEntries',before_r->'entries','afterEntries',r->'entries','affectedReports',affected))||coalesce(doc->'amendments','[]')) with ordinality as v(x,ord) limit 100) kept));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(jsonb_build_object('id',md5(random()::text||ts),'at',ts,'action','แก้ไขรายงานย้อนหลัง '||(r->>'title')))||coalesce(doc->'audit','[]'));
 previous_flag:=current_setting('pn2.amending',true);perform set_config('pn2.amending','yes',true);
 if doc ? 'contractRegistry' then
  for change in select key, value from jsonb_each(entries_patch) loop
   e:=r->'entries'->change.key;
   doc:=jsonb_set(doc,'{contractRegistry}',coalesce((select jsonb_agg(case when x->>'projectId'=change.key then x
    || case when change.value ? 'deliveryDate' then jsonb_build_object('deliveryDate',coalesce(e->>'deliveryDate','')) else '{}'::jsonb end
    || case when change.value ? 'acceptanceDate' then jsonb_build_object('acceptanceDate',coalesce(e->>'acceptanceDate','')) else '{}'::jsonb end
    || case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    else x end) from jsonb_array_elements(doc->'contractRegistry') x),'[]'));
  end loop;
 end if;
 perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);
 result:=public.pn2_save_workspace(doc,expected_revision);
 perform set_config('pn2.delta_report_ids','',true);
 perform set_config('pn2.amending',coalesce(previous_flag,''),true);
 insert into public.pn2_report_amendments(workspace_id,report_id,before_report,after_report,affected_reports) values(uid,report_id,before_r,r,affected);
 select public.pn2_hydrate_document(document,false) into doc from public.pn2_workspaces where workspace_id=uid;
 return result||jsonb_build_object('document',doc);
end $function$
;

NOTIFY pgrst, 'reload schema';

commit;
