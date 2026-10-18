-- Smaller ordinary reads; historical backup/import APIs remain complete.
DO $migration$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 IF position('''projects'',(SELECT' in body)=0 THEN
  body:=replace(body,'''reports'',report_rows,', $scope$'projects',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM jsonb_array_elements(doc->'projects') p WHERE (p->>'year')::integer=yr AND coalesce(p->>'funding','DOH')=fund),'contractRegistry',(SELECT coalesce(jsonb_agg(p),'[]'::jsonb) FROM jsonb_array_elements(coalesce(doc->'contractRegistry','[]')) p WHERE (p->>'year')::integer=yr AND coalesce(p->>'funding','DOH')=fund),'reports',report_rows,$scope$);
  EXECUTE body;
 END IF;
 -- Report validation still covers every explicitly updated/removed report, and
 -- JSON replacement continues through the full validation path. Global project
 -- validation, FK protection, revision lock and audited lifecycle remain intact.
 body:=pg_get_functiondef('public.pn2_patch_workspace(jsonb,bigint,text)'::regprocedure);
 body:=regexp_replace(body,'IF NOT EXISTS\(SELECT 1 FROM jsonb_object_keys\(coalesce\(changes->''collections'',''\{\}''\)\) key WHERE key<>''reports''\)\s+AND NOT EXISTS\(SELECT 1 FROM jsonb_object_keys\(coalesce\(changes->''values'',''\{\}''\)\) key WHERE key<>ALL\(ARRAY\[''settings'',''issues'',''masterSequences''\]\)\) THEN','IF true THEN');
 EXECUTE body;
 -- Keep the carried baseline after authorized old-report pruning.
 body:=pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure);
 IF position('reportBaselines' in body)=0 THEN
  body:=replace(body,'prev:=previous_entries->e.key;', 'prev:=coalesce(previous_entries->e.key,payload->''settings''->''reportBaselines''->(r->>''id'')->e.key);');
  EXECUTE body;
 END IF;
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 body:=replace(body,'prior:=coalesce(prior,0);','prior:=coalesce(prior,(doc->''settings''->''reportBaselines''->report_id->change.key->>''actual'')::numeric,0);');
 EXECUTE body;
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'diff:=public.pn2_import_diff(old_doc,payload);','diff:=public.pn2_import_diff(old_doc-''importHistory'',payload-''importHistory'');');
 EXECUTE body;
END $migration$;
NOTIFY pgrst,'reload schema';

-- Remove retired identities before updating canonical road names to avoid
-- transient uniqueness conflicts when two source names consolidate.
CREATE OR REPLACE FUNCTION public.pn2_sync_road_catalog() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.document#>'{settings,roadSections}' IS NOT DISTINCT FROM NEW.document#>'{settings,roadSections}' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.document#>'{settings,roadSections}','[]'))<>'array' THEN RAISE EXCEPTION 'ทะเบียนสายทางต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_road_sections t WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x WHERE x->>'id'=t.id);
 INSERT INTO public.pn2_road_sections(workspace_id,id,road_no,control_section,section_name)
 SELECT NEW.workspace_id,x->>'id',coalesce(x->>'routeNumber',''),coalesce(x->>'controlSection',''),coalesce(x->>'sectionName','') FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x
 ON CONFLICT(workspace_id,id) DO UPDATE SET road_no=excluded.road_no,control_section=excluded.control_section,section_name=excluded.section_name WHERE (pn2_road_sections.road_no,pn2_road_sections.control_section,pn2_road_sections.section_name) IS DISTINCT FROM (excluded.road_no,excluded.control_section,excluded.section_name);

 RETURN NEW;
END $$;

-- Cover active FK lookups identified by the Supabase performance advisor.
-- Legacy pn_* tables are unrelated to this shared workspace release.
CREATE INDEX IF NOT EXISTS pn2_registry_contractor_fk_idx ON public.pn2_contract_registry(workspace_id,contractor_id);
CREATE INDEX IF NOT EXISTS pn2_registry_type_fk_idx ON public.pn2_contract_registry(workspace_id,work_type_id);
CREATE INDEX IF NOT EXISTS pn2_registry_budget_fk_idx ON public.pn2_contract_registry(workspace_id,budget_account_id);
CREATE INDEX IF NOT EXISTS pn2_registry_workcode_fk_idx ON public.pn2_contract_registry(workspace_id,work_code_id);
CREATE INDEX IF NOT EXISTS pn2_registry_job_fk_idx ON public.pn2_contract_registry(workspace_id,work_name_id);
CREATE INDEX IF NOT EXISTS pn2_registry_supervisor_fk_idx ON public.pn2_contract_registry(workspace_id,supervisor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_contractor_fk_idx ON public.pn2_contracts(workspace_id,contractor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_funding_fk_idx ON public.pn2_contracts(workspace_id,funding_source);
CREATE INDEX IF NOT EXISTS pn2_contract_registry_fk_idx ON public.pn2_contracts(workspace_id,registry_id);
CREATE INDEX IF NOT EXISTS pn2_contract_supervisor_fk_idx ON public.pn2_contracts(workspace_id,supervisor_id);
CREATE INDEX IF NOT EXISTS pn2_contract_workname_fk_idx ON public.pn2_contracts(workspace_id,work_name_id);
CREATE INDEX IF NOT EXISTS pn2_contract_worktype_fk_idx ON public.pn2_contracts(workspace_id,work_type_id);
CREATE INDEX IF NOT EXISTS pn2_contract_category_fk_idx ON public.pn2_contracts(workspace_id,category_id);
CREATE INDEX IF NOT EXISTS pn2_extensions_contract_fk_idx ON public.pn2_extensions(workspace_id,contract_id);
CREATE INDEX IF NOT EXISTS pn2_reports_funding_fk_idx ON public.pn2_reports(workspace_id,funding_source);
CREATE INDEX IF NOT EXISTS pn2_worknames_type_fk_idx ON public.pn2_work_names(workspace_id,type_id);
