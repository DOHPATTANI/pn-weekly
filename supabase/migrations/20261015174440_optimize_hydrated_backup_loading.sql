-- Materialize each cold collection once and insert revision before attaching the large history.
CREATE OR REPLACE FUNCTION public.pn2_hydrate_document(doc jsonb,with_history boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $hydrate8$
DECLARE hydrated_reports jsonb;history_rows jsonb;result jsonb;
BEGIN
 IF doc IS NULL THEN RETURN NULL;END IF;
 SELECT coalesce(jsonb_agg((r-'_storedSnapshot')||coalesce(s.payload,'{}') ORDER BY ord),'[]') INTO hydrated_reports
 FROM jsonb_array_elements(doc->'reports') WITH ORDINALITY v(r,ord) LEFT JOIN public.pn2_report_snapshots s ON s.workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND s.report_id=r->>'id';
 result:=jsonb_set(doc-'importHistory','{reports}',hydrated_reports);
 IF with_history THEN
  history_rows:=doc->'importHistory';
  IF history_rows IS NULL THEN SELECT coalesce(jsonb_agg(ir.payload ORDER BY ir.ordinal),'[]') INTO history_rows FROM public.pn2_import_runs ir WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;END IF;
  result:=jsonb_set(result,'{importHistory}',history_rows);
 END IF;
 RETURN result;
END $hydrate8$;
CREATE OR REPLACE FUNCTION public.pn2_load_workspace() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='25s' AS $load8$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 RETURN public.pn2_hydrate_document(jsonb_set(doc,'{revision}',to_jsonb(rev)),true);
END $load8$;
CREATE OR REPLACE FUNCTION public.pn2_load_active_workspace() RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET statement_timeout='15s' AS $active8$
DECLARE doc jsonb;rev bigint;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RETURN NULL;END IF;
 RETURN public.pn2_hydrate_document(jsonb_set(doc,'{revision}',to_jsonb(rev)),false);
END $active8$;
ALTER FUNCTION public.pn2_load_import_history() SET statement_timeout='25s';
-- The frozen snapshot has one authoritative source; clear obsolete relational copies.
UPDATE public.pn2_reports SET payload=payload-'settingsSnapshot' WHERE payload ? 'settingsSnapshot';
NOTIFY pgrst,'reload schema';
