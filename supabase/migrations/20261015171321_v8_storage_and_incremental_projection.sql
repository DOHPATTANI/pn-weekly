-- Incremental projections: keep primary/foreign keys, validate with the existing domain rules.
ALTER TABLE public.pn2_contractors ADD COLUMN IF NOT EXISTS address text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_contractors ADD COLUMN IF NOT EXISTS phone text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_fiscal_years ALTER CONSTRAINT pn2_fiscal_years_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_categories ALTER CONSTRAINT pn2_categories_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_fiscal_year_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contracts_workspace_id_category_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_extensions ALTER CONSTRAINT pn2_extensions_workspace_id_contract_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_reports_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_entries ALTER CONSTRAINT pn2_entries_workspace_id_report_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_entries ALTER CONSTRAINT pn2_entries_workspace_id_contract_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contractors ALTER CONSTRAINT pn2_contractors_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_names ALTER CONSTRAINT pn2_work_names_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_funding_sources ALTER CONSTRAINT pn2_funding_sources_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_contractor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_supervisor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_workname_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_worktype_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_contractor_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_contract_registry_workspace_id_work_type_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_budget_accounts ALTER CONSTRAINT pn2_budget_accounts_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_codes ALTER CONSTRAINT pn2_work_codes_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_name_codes ALTER CONSTRAINT pn2_work_name_codes_workspace_id_work_name_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_name_codes ALTER CONSTRAINT pn2_work_name_codes_workspace_id_work_code_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_budget_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_code_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_job_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_supervisor_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contract_registry ALTER CONSTRAINT pn2_registry_project_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_registry_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_work_names ALTER CONSTRAINT pn2_work_name_type_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_contracts ALTER CONSTRAINT pn2_contract_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_report_year_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_reports ALTER CONSTRAINT pn2_report_funding_fk DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE public.pn2_report_amendments ALTER CONSTRAINT pn2_report_amendments_workspace_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
CREATE OR REPLACE FUNCTION public.pn2_delete_removed_projection(input_doc jsonb) RETURNS void LANGUAGE plpgsql SET search_path='' AS $del$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';
BEGIN
DELETE FROM public.pn2_contractors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractors','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_supervisors t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'supervisors','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_types t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workTypes','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_names t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workNames','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'workCodes','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_budget_accounts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'budgetAccounts','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_categories t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'categories','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_funding_sources t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'fundingSources','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_contracts t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'projects','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_reports t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'reports','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_contract_registry t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(input_doc->'contractRegistry','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_fiscal_years t WHERE workspace_id=uid AND NOT input_doc->'years' @> to_jsonb(ARRAY[t.year]);
DELETE FROM public.pn2_entries t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'reports') r WHERE r->>'id'=t.report_id AND r->'entries' ? t.contract_id);
DELETE FROM public.pn2_extensions t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'projects') p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p->'extensions','[]')) x WHERE x->>'id'=t.id);
DELETE FROM public.pn2_work_name_codes t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'workNames') w WHERE w->>'id'=t.work_name_id AND w->'codeIds' @> to_jsonb(ARRAY[t.work_code_id]));
DELETE FROM public.pn2_registry_work_links t WHERE workspace_id=uid AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(input_doc->'contractRegistry') r WHERE r->>'workCode'=t.work_code AND r->>'title'=t.title);
END $del$;
REVOKE ALL ON FUNCTION public.pn2_delete_removed_projection(jsonb) FROM PUBLIC;
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

 set constraints all deferred;
 perform public.pn2_delete_removed_projection(payload);
 for v in select value from jsonb_array_elements(payload->'years')loop insert into public.pn2_fiscal_years(workspace_id,year,code) values(uid,(v#>>'{}')::integer,payload->'yearCodes'->>(v#>>'{}')) on conflict(workspace_id,year) do update set code=excluded.code where pn2_fiscal_years is distinct from excluded;end loop;
 for v in select value from jsonb_array_elements(payload->'categories')loop insert into public.pn2_categories values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_categories is distinct from excluded;end loop;

 if old_doc->'contractors' is distinct from payload->'contractors' then insert into public.pn2_contractors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'contractors','[]')) AS master_row(value) left join public.pn2_contractors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_contractors is distinct from excluded;end if;
 if old_doc->'supervisors' is distinct from payload->'supervisors' then insert into public.pn2_supervisors(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'supervisors','[]')) AS master_row(value) left join public.pn2_supervisors existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_supervisors is distinct from excluded;end if;
 if old_doc->'workTypes' is distinct from payload->'workTypes' then insert into public.pn2_work_types(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workTypes','[]')) AS master_row(value) left join public.pn2_work_types existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_types is distinct from excluded;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]'))loop
  if nullif(v->>'typeId','') is not null and not exists(select 1 from public.pn2_work_types where workspace_id=uid and id=v->>'typeId') then raise exception 'ประเภทงานของชื่องานไม่มีในทะเบียน';end if;
  insert into public.pn2_work_names(workspace_id,id,name,type_id,archived,code) values(uid,v->>'id',v->>'name',nullif(v->>'typeId',''),coalesce((v->>'archived')::boolean,false),nullif(v->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,type_id=excluded.type_id,archived=excluded.archived,code=excluded.code where pn2_work_names is distinct from excluded;end loop;
 for v in select value from jsonb_array_elements(coalesce(payload->'fundingSources','[{"id":"DOH","name":"กรมทางหลวง"},{"id":"PROVINCE","name":"งบจังหวัด"}]'))loop insert into public.pn2_funding_sources values(uid,v->>'id',v->>'name') on conflict(workspace_id,id) do update set name=excluded.name where pn2_funding_sources is distinct from excluded;end loop;

 if old_doc->'budgetAccounts' is distinct from payload->'budgetAccounts' then insert into public.pn2_budget_accounts(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'budgetAccounts','[]')) AS master_row(value) left join public.pn2_budget_accounts existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_budget_accounts is distinct from excluded;end if;
 if old_doc->'workCodes' is distinct from payload->'workCodes' then insert into public.pn2_work_codes(workspace_id,id,name,archived,code) select uid,master_row.value->>'id',master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','') from jsonb_array_elements(coalesce(payload->'workCodes','[]')) AS master_row(value) left join public.pn2_work_codes existing on existing.workspace_id=uid and existing.id=master_row.value->>'id' where existing.id is null or row(existing.name,existing.archived,existing.code) is distinct from row(master_row.value->>'name',coalesce((master_row.value->>'archived')::boolean,false),nullif(master_row.value->>'code','')) on conflict(workspace_id,id) do update set name=excluded.name,archived=excluded.archived,code=excluded.code where pn2_work_codes is distinct from excluded;end if;
 for v in select value from jsonb_array_elements(coalesce(payload->'workNames','[]')) loop
  for ext in select value from jsonb_array_elements(coalesce(v->'codeIds','[]')) loop insert into public.pn2_work_name_codes values(uid,v->>'id',ext#>>'{}') on conflict do nothing;end loop;
 end loop;
 for p in select value from jsonb_array_elements(project_list)loop
  insert into public.pn2_contracts(workspace_id,id,contract_no,fiscal_year,category_id,title,start_date,end_date,base_days,contractor,supervisor,archived,payload,funding_source,registry_id,contractor_id,supervisor_id,work_name_id,work_type_id) values(uid,p->>'id',p->>'contract',(p->>'year')::integer,p->>'category',p->>'title',(p->>'start')::date,(p->>'end')::date,(p->>'duration')::integer,p->>'contractor',coalesce(p->>'supervisor',''),coalesce((p->>'archived')::boolean,false),p,coalesce(p->>'funding','DOH'),nullif(p->>'registryId',''),nullif(p->>'contractorId',''),nullif(p->>'supervisorId',''),nullif(p->>'workNameId',''),nullif(p->>'workTypeId','')) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,category_id=excluded.category_id,title=excluded.title,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor=excluded.contractor,supervisor=excluded.supervisor,archived=excluded.archived,payload=excluded.payload,contractor_id=excluded.contractor_id,supervisor_id=excluded.supervisor_id,work_name_id=excluded.work_name_id,work_type_id=excluded.work_type_id,funding_source=excluded.funding_source,registry_id=excluded.registry_id where pn2_contracts is distinct from excluded;
  if not exists(select 1 from public.pn2_funding_sources where workspace_id=uid and id=coalesce(p->>'funding','DOH')) then raise exception 'กลุ่มงบไม่มีในทะเบียน';end if;
  for v in select value from jsonb_array_elements(p->'extensions')loop insert into public.pn2_extensions values(uid,v->>'id',p->>'id',(v->>'days')::integer,v->>'reference',(v->>'approved')::boolean,v) on conflict(workspace_id,id) do update set contract_id=excluded.contract_id,days=excluded.days,approval_reference=excluded.approval_reference,approved=excluded.approved,payload=excluded.payload where pn2_extensions is distinct from excluded;end loop;
 end loop;
 for r in select value from jsonb_array_elements(report_list)loop
  if r=old_reports->(r->>'id') then continue;end if;
  insert into public.pn2_reports(workspace_id,id,fiscal_year,start_date,end_date,reference_date,locked,imported,title,payload,funding_source) values(uid,r->>'id',(r->>'year')::integer,(r->>'start')::date,(r->>'end')::date,(r->>'reference')::date,(r->>'locked')::boolean,(r->>'imported')::boolean,r->>'title',r-'entries'-'snapshots'-'settingsSnapshot',coalesce(r->>'funding','DOH')) on conflict(workspace_id,id) do update set fiscal_year=excluded.fiscal_year,start_date=excluded.start_date,end_date=excluded.end_date,reference_date=excluded.reference_date,locked=excluded.locked,imported=excluded.imported,title=excluded.title,payload=excluded.payload,funding_source=excluded.funding_source where pn2_reports is distinct from excluded;
  insert into public.pn2_entries(workspace_id,report_id,contract_id,plan_percent,weekly_percent,actual_percent,note,payment_status,confirmed,contract_snapshot,payment_date,delivery_date,acceptance_date) select uid,r->>'id',entry_row.key,(entry_row.value->>'plan')::numeric,(entry_row.value->>'weekly')::numeric,(entry_row.value->>'actual')::numeric,coalesce(entry_row.value->>'note',''),entry_row.value->>'payment',(entry_row.value->>'confirmed')::boolean,NULL,nullif(entry_row.value->>'paymentDate','')::date,nullif(entry_row.value->>'deliveryDate','')::date,nullif(entry_row.value->>'acceptanceDate','')::date from jsonb_each(r->'entries') AS entry_row on conflict(workspace_id,report_id,contract_id) do update set plan_percent=excluded.plan_percent,weekly_percent=excluded.weekly_percent,actual_percent=excluded.actual_percent,note=excluded.note,payment_status=excluded.payment_status,confirmed=excluded.confirmed,contract_snapshot=excluded.contract_snapshot,payment_date=excluded.payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date where pn2_entries is distinct from excluded;
 end loop;

 for v in select value from jsonb_array_elements(coalesce(payload->'contractRegistry','[]')) loop
  insert into public.pn2_contract_registry(workspace_id,id,contract_no,fiscal_year,funding_source,title,work_code,budget_account,signed_date,start_date,end_date,base_days,contractor_raw,contractor_id,contractor_needs_review,contract_value,actual_cost,quantity,unit,final_payment_date,delivery_date,acceptance_date,work_type_id,project_id,payload,budget_account_id,work_code_id,work_name_id,supervisor_id,archived) values(uid,v->>'id',v->>'contract',(v->>'year')::integer,v->>'funding',v->>'title',v->>'workCode',v->>'budgetAccount',nullif(v->>'signedAt','')::date,(v->>'start')::date,(v->>'end')::date,(v->>'duration')::integer,v->>'contractorRaw',nullif(v->>'contractorId',''),coalesce((v->>'contractorNeedsReview')::boolean,true),nullif(v->>'contractValue','')::numeric,nullif(v->>'actualCost','')::numeric,nullif(v->>'quantity','')::numeric,v->>'unit',nullif(v->>'finalPaymentDate','')::date,nullif(v->>'deliveryDate','')::date,nullif(v->>'acceptanceDate','')::date,nullif(v->>'workTypeId',''),nullif(v->>'projectId',''),v,nullif(v->>'budgetAccountId',''),nullif(v->>'workCodeId',''),nullif(v->>'workNameId',''),nullif(v->>'supervisorId',''),coalesce((v->>'archived')::boolean,false)) on conflict(workspace_id,id) do update set contract_no=excluded.contract_no,fiscal_year=excluded.fiscal_year,funding_source=excluded.funding_source,title=excluded.title,work_code=excluded.work_code,budget_account=excluded.budget_account,signed_date=excluded.signed_date,start_date=excluded.start_date,end_date=excluded.end_date,base_days=excluded.base_days,contractor_raw=excluded.contractor_raw,contractor_id=excluded.contractor_id,contractor_needs_review=excluded.contractor_needs_review,contract_value=excluded.contract_value,actual_cost=excluded.actual_cost,quantity=excluded.quantity,unit=excluded.unit,final_payment_date=excluded.final_payment_date,delivery_date=excluded.delivery_date,acceptance_date=excluded.acceptance_date,work_type_id=excluded.work_type_id,project_id=excluded.project_id,payload=excluded.payload,budget_account_id=excluded.budget_account_id,work_code_id=excluded.work_code_id,work_name_id=excluded.work_name_id,supervisor_id=excluded.supervisor_id,archived=excluded.archived where pn2_contract_registry is distinct from excluded;
  if nullif(v->>'workCode','') is not null then insert into public.pn2_registry_work_links values(uid,v->>'workCode',v->>'title',nullif(v->>'workTypeId','')) on conflict(workspace_id,work_code,title) do update set work_type_id=excluded.work_type_id where pn2_registry_work_links is distinct from excluded;end if;
 end loop;

 update public.pn2_contractors c set address=coalesce(x->>'address',''),phone=coalesce(x->>'phone','') from jsonb_array_elements(payload->'contractors') x where c.workspace_id=uid and c.id=x->>'id' and row(c.address,c.phone) is distinct from row(coalesce(x->>'address',''),coalesce(x->>'phone',''));
 insert into public.pn2_audit(workspace_id,revision,action) values(uid,new_rev,coalesce(payload->'audit'->0->>'action','เริ่มพื้นที่ข้อมูล'));
 return jsonb_build_object('revision',new_rev);
end $function$
;



-- Cold immutable snapshots and append-only import history are kept outside the hot document.
CREATE TABLE IF NOT EXISTS public.pn2_import_runs(workspace_id uuid NOT NULL,id text NOT NULL,ordinal bigint NOT NULL,payload jsonb NOT NULL,PRIMARY KEY(workspace_id,id));
CREATE TABLE IF NOT EXISTS public.pn2_report_snapshots(workspace_id uuid NOT NULL,report_id text NOT NULL,payload jsonb NOT NULL,PRIMARY KEY(workspace_id,report_id));
ALTER TABLE public.pn2_import_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pn2_report_snapshots ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_hydrate_document(doc jsonb,with_history boolean DEFAULT false) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $hydrate$
 SELECT CASE WHEN doc IS NULL THEN NULL ELSE
 (doc-'importHistory')||jsonb_build_object('reports',(SELECT coalesce(jsonb_agg((r-'_storedSnapshot')||coalesce(s.payload,'{}') ORDER BY ord),'[]') FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id'))
 ||CASE WHEN with_history THEN jsonb_build_object('importHistory',coalesce(doc->'importHistory',(SELECT jsonb_agg(payload ORDER BY ordinal) FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'[]')) ELSE '{}'::jsonb END END
$hydrate$;
REVOKE ALL ON FUNCTION public.pn2_hydrate_document(jsonb,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_hydrate_document(jsonb,boolean) TO anon,authenticated;
CREATE OR REPLACE FUNCTION public.pn2_compact_document() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $compact$
DECLARE reports jsonb;r jsonb;ord bigint;bits jsonb;
BEGIN
 IF NEW.document ? 'importHistory' THEN
  INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload)
  SELECT NEW.workspace_id,x->>'id',pos,x FROM jsonb_array_elements(NEW.document->'importHistory') WITH ORDINALITY v(x,pos) WHERE nullif(x->>'id','') IS NOT NULL
  ON CONFLICT(workspace_id,id) DO UPDATE SET ordinal=excluded.ordinal,payload=excluded.payload WHERE row(pn2_import_runs.ordinal,pn2_import_runs.payload) IS DISTINCT FROM row(excluded.ordinal,excluded.payload);
 END IF;
 reports:='[]';
 FOR r,ord IN SELECT x,pos FROM jsonb_array_elements(NEW.document->'reports') WITH ORDINALITY v(x,pos) LOOP
  bits:='{}';IF r ? 'snapshots' THEN bits:=bits||jsonb_build_object('snapshots',r->'snapshots');END IF;IF r ? 'settingsSnapshot' THEN bits:=bits||jsonb_build_object('settingsSnapshot',r->'settingsSnapshot');END IF;
  IF bits<>'{}' THEN INSERT INTO public.pn2_report_snapshots VALUES(NEW.workspace_id,r->>'id',bits) ON CONFLICT(workspace_id,report_id) DO UPDATE SET payload=excluded.payload WHERE pn2_report_snapshots.payload IS DISTINCT FROM excluded.payload;END IF;
  reports:=reports||jsonb_build_array((r-'snapshots'-'settingsSnapshot')||jsonb_build_object('_storedSnapshot',true));
 END LOOP;
 DELETE FROM public.pn2_report_snapshots s WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(reports) z WHERE z->>'id'=s.report_id);
 NEW.document:=(NEW.document-'importHistory')||jsonb_build_object('reports',reports);RETURN NEW;
END $compact$;
REVOKE ALL ON FUNCTION public.pn2_compact_document() FROM PUBLIC;
CREATE TRIGGER pn2_compact_workspace BEFORE INSERT OR UPDATE OF document ON public.pn2_workspaces FOR EACH ROW EXECUTE FUNCTION public.pn2_compact_document();
-- Migrate the existing document without changing its revision or any user data.
UPDATE public.pn2_workspaces SET document=document;
-- Keep established validation and amendment logic; hydrate only inside RPCs that need it.
DO $adapt$
DECLARE sig text;body text;
BEGIN
 FOREACH sig IN ARRAY ARRAY['pn2_save_workspace(jsonb,bigint)','pn2_patch_workspace(jsonb,bigint,text)','pn2_import_changes(jsonb,bigint,jsonb)','pn2_amend_report(text,jsonb,bigint)','pn2_import_workspace(jsonb,bigint,jsonb)'] LOOP
  body:=pg_get_functiondef(('public.'||sig)::regprocedure);
  body:=regexp_replace(body,'select document,revision','select public.pn2_hydrate_document(document,false),revision','gi');
  -- JSON replacement remains fully audited; CSV records only the changed data, never repeated full history.
  IF sig='pn2_import_workspace(jsonb,bigint,jsonb)' THEN
   body:=replace(body,$old$old_doc,payload,diff);$old$,$new$jsonb_build_object('storageFormat','delta-v1','changes',diff),jsonb_build_object('storageFormat','delta-v1','run',run),diff);$new$);
   body:=replace(body,$old$coalesce(old_doc->'importHistory','[]'::jsonb)$old$,$new$coalesce((select jsonb_agg(ir.payload order by ir.ordinal) from public.pn2_import_runs ir where ir.workspace_id=uid),'[]'::jsonb)$new$);
  END IF;
  EXECUTE body;
 END LOOP;
END $adapt$;
CREATE OR REPLACE FUNCTION public.pn2_load_workspace() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$SELECT public.pn2_hydrate_document(document,true)||jsonb_build_object('revision',revision) FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
CREATE OR REPLACE FUNCTION public.pn2_load_active_workspace() RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $$SELECT public.pn2_hydrate_document(document,false)||jsonb_build_object('revision',revision) FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
CREATE OR REPLACE FUNCTION public.pn2_load_import_history() RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$SELECT jsonb_build_object('revision',revision,'importHistory',coalesce((SELECT jsonb_agg(payload ORDER BY ordinal) FROM public.pn2_import_runs WHERE workspace_id=w.workspace_id),'[]')) FROM public.pn2_workspaces w WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid$$;
-- Scope reads only one frozen snapshot; older metadata does not carry logo copies.
DO $scope$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 body:=replace(body,$old$WHEN x->>'id'=chosen THEN x ELSE$old$,$new$WHEN x->>'id'=chosen THEN (x-'_storedSnapshot')||coalesce((select payload from public.pn2_report_snapshots where workspace_id='00000000-0000-0000-0000-000000000001'::uuid and report_id=chosen),'{}'::jsonb) ELSE$new$);
 body:=replace(body,'SECURITY INVOKER','SECURITY DEFINER');EXECUTE body;
END $scope$;
NOTIFY pgrst,'reload schema';
-- Compact scope with the selected report, six recent entry sets and explicit prior carry context.
CREATE OR REPLACE FUNCTION public.pn2_load_scope(requested_funding text DEFAULT NULL,requested_year integer DEFAULT NULL,requested_report text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $scope8$
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
 (r-'entries'-'snapshots'-'settingsSnapshot'-'_storedSnapshot')||jsonb_build_object('entries',CASE WHEN recent @> jsonb_build_array(r->>'id') THEN r->'entries' ELSE '{}'::jsonb END,'snapshots','{}'::jsonb,'_unloaded',true,'_entryCount',(SELECT count(*) FROM jsonb_object_keys(r->'entries')),'_missingPaymentDates',(SELECT coalesce(jsonb_agg(jsonb_build_array(e.key,e.value)),'[]') FROM jsonb_each(r->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND coalesce(e.value->>'paymentDate','')='')) END ORDER BY ord),'[]') INTO report_rows
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 RETURN (doc-'importHistory')||jsonb_build_object('reports',report_rows,'revision',rev,'loadedScope',jsonb_build_object('funding',fund,'year',yr,'reportId',chosen,'previousEntries',prior,'latestEntries',latest));
END $scope8$;
CREATE OR REPLACE FUNCTION public.pn2_load_report_detail(requested_report text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $detail$
 SELECT jsonb_build_object('revision',w.revision,'report',(r-'_storedSnapshot')||coalesce(s.payload,'{}')) FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'reports') r LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id=w.workspace_id AND s.report_id=r->>'id' WHERE w.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND r->>'id'=requested_report
$detail$;
REVOKE ALL ON FUNCTION public.pn2_load_report_detail(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_load_report_detail(text) TO anon,authenticated;
CREATE UNIQUE INDEX IF NOT EXISTS pn2_one_name_per_work_code ON public.pn2_work_name_codes(workspace_id,work_code_id);
NOTIFY pgrst,'reload schema';
CREATE OR REPLACE FUNCTION public.pn2_save_entry(report_id text,contract_id text,entry jsonb,changes jsonb,expected_revision bigint,action text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $entry8$
DECLARE selected_report jsonb;patch jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-000000000001',0));
 IF jsonb_typeof(entry)<>'object' OR octet_length(entry::text)>100000 THEN RAISE EXCEPTION 'รูปแบบข้อมูลผลงานไม่ถูกต้อง';END IF;
 SELECT (public.pn2_load_report_detail(report_id))->'report' INTO selected_report;
 IF selected_report IS NULL OR NOT selected_report->'entries' ? contract_id THEN RAISE EXCEPTION 'ไม่พบสัญญาในรายงาน';END IF;
 IF coalesce((selected_report->>'locked')::boolean,false) THEN RAISE EXCEPTION 'รายงานถูกปิดแล้ว ใช้แก้ไขรายงานย้อนหลัง';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(coalesce(changes->'collections','{}')) k WHERE k<>ALL(ARRAY['projects','contractRegistry'])) OR coalesce(changes->'values','{}')<>'{}' THEN RAISE EXCEPTION 'ชุดข้อมูลแก้ไขผลงานไม่ถูกต้อง';END IF;
 selected_report:=jsonb_set(selected_report,ARRAY['entries',contract_id],entry);
 patch:=coalesce(changes,'{}')||jsonb_build_object('collections',coalesce(changes->'collections','{}')||jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(selected_report),'remove','[]'::jsonb)));
 RETURN public.pn2_patch_workspace(patch,expected_revision,action);
END $entry8$;
REVOKE ALL ON FUNCTION public.pn2_save_entry(text,text,jsonb,jsonb,bigint,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_save_entry(text,text,jsonb,jsonb,bigint,text) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
DO $amend8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 body:=replace(body,'result:=public.pn2_save_workspace(doc,expected_revision);',$new$perform set_config('pn2.delta_report_ids',(affected||jsonb_build_array(report_id))::text,true);result:=public.pn2_save_workspace(doc,expected_revision);perform set_config('pn2.delta_report_ids','',true);$new$);
 body:=replace(body,'select document into doc','select public.pn2_hydrate_document(document,false) into doc');EXECUTE body;
END $amend8$;
CREATE OR REPLACE FUNCTION public.pn2_amend_report_delta(report_id text,entries_patch jsonb,expected_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $amenddelta$
DECLARE before_doc jsonb;after_doc jsonb;result jsonb;updates jsonb;registry_updates jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended('00000000-0000-0000-0000-000000000001',0));
 SELECT document INTO before_doc FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 result:=public.pn2_amend_report(report_id,entries_patch,expected_revision);after_doc:=result->'document';
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',n->>'id','metadata',n-'entries'-'snapshots'-'settingsSnapshot','entries',(SELECT coalesce(jsonb_object_agg(e.key,e.value),'{}') FROM jsonb_each(n->'entries') e WHERE e.value IS DISTINCT FROM o->'entries'->e.key))),'[]') INTO updates FROM jsonb_array_elements(after_doc->'reports') n JOIN jsonb_array_elements(before_doc->'reports') o ON n->>'id'=o->>'id' WHERE (n-'snapshots'-'settingsSnapshot'-'_storedSnapshot') IS DISTINCT FROM (o-'_storedSnapshot');
 SELECT coalesce(jsonb_agg(n),'[]') INTO registry_updates FROM jsonb_array_elements(after_doc->'contractRegistry') n LEFT JOIN jsonb_array_elements(before_doc->'contractRegistry') o ON n->>'id'=o->>'id' WHERE n IS DISTINCT FROM o;
 RETURN jsonb_build_object('revision',result->'revision','reports',updates,'registry',registry_updates,'amendment',after_doc->'amendments'->0,'auditEntry',after_doc->'audit'->0);
END $amenddelta$;
REVOKE ALL ON FUNCTION public.pn2_amend_report_delta(text,jsonb,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_amend_report_delta(text,jsonb,bigint) TO anon,authenticated;
NOTIFY pgrst,'reload schema';

-- Snapshot source has been preserved in pn2_report_snapshots; avoid a second mutable copy in entry projections.
UPDATE public.pn2_entries SET contract_snapshot=NULL WHERE contract_snapshot IS NOT NULL;
ALTER TABLE public.pn2_contractors ADD CONSTRAINT pn2_contractor_contact_lengths CHECK(length(address)<=2000 AND length(phone)<=80);

DO $labels8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'run:=jsonb_build_object(',$new$labels:=(select coalesce(jsonb_object_agg(e.key,e.value),'{}') from jsonb_each(labels) e where exists(select 1 from jsonb_array_elements(diff) d where e.key=ANY(string_to_array(d->>'path',' / '))));run:=jsonb_build_object($new$);EXECUTE body;
END $labels8$;
ALTER TABLE public.pn2_import_runs ADD CONSTRAINT pn2_import_runs_workspace_fk FOREIGN KEY(workspace_id) REFERENCES public.pn2_workspaces(workspace_id) DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE public.pn2_report_snapshots ADD CONSTRAINT pn2_report_snapshots_workspace_fk FOREIGN KEY(workspace_id) REFERENCES public.pn2_workspaces(workspace_id) DEFERRABLE INITIALLY DEFERRED;
CREATE OR REPLACE FUNCTION public.pn2_load_report_detail(requested_report text) RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $detail8$
 SELECT jsonb_build_object('revision',w.revision,'report',(r-'_storedSnapshot')||coalesce(s.payload,'{}'),'previousEntries',(SELECT coalesce(jsonb_object_agg(key,value),'{}') FROM (SELECT DISTINCT ON(e.key) e.key,e.value FROM jsonb_array_elements(w.document->'reports') p CROSS JOIN LATERAL jsonb_each(p->'entries') e WHERE coalesce(p->>'funding','DOH')=coalesce(r->>'funding','DOH') AND p->>'year'=r->>'year' AND p->>'end'<r->>'start' ORDER BY e.key,p->>'end' DESC) prior)) FROM public.pn2_workspaces w CROSS JOIN LATERAL jsonb_array_elements(w.document->'reports') r LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id=w.workspace_id AND s.report_id=r->>'id' WHERE w.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND r->>'id'=requested_report
$detail8$;
ALTER TABLE public.pn2_report_snapshots ADD CONSTRAINT pn2_report_snapshots_report_fk FOREIGN KEY(workspace_id,report_id) REFERENCES public.pn2_reports(workspace_id,id) DEFERRABLE INITIALLY DEFERRED;
NOTIFY pgrst,'reload schema';
