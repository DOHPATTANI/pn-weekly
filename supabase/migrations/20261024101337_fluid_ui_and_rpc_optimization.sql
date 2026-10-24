-- v26 audit correction: paged search uses actual change rows, never downloads cold history into the page.
-- Read-only surface follows the existing shared-workspace access contract. No business data rewrite.
begin;
CREATE OR REPLACE FUNCTION public.pn2_search_history(requested_page integer DEFAULT 1,requested_query text DEFAULT '',requested_kind text DEFAULT 'all') RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $history$
BEGIN
 RETURN (WITH matching AS MATERIALIZED(
  SELECT r.id,r.ordinal,r.payload,c.value,c.ord
  FROM public.pn2_import_runs r
  CROSS JOIN LATERAL jsonb_array_elements(coalesce(r.payload->'changes','[]'::jsonb)) WITH ORDINALITY c(value,ord)
  WHERE r.workspace_id='00000000-0000-0000-0000-000000000001'::uuid
   AND (coalesce(requested_kind,'all')='all' OR c.value->>'kind'=CASE requested_kind WHEN 'new' THEN 'added' WHEN 'updated' THEN 'updated' WHEN 'removed' THEN 'removed' ELSE '' END)
   AND (coalesce(btrim(requested_query),'')='' OR strpos(lower(concat_ws(' ',r.payload->>'fileName',r.payload->>'format',r.payload->>'source',c.value->>'path')),lower(btrim(requested_query)))>0)
 ), totals AS(SELECT count(*)::integer n FROM matching),
 paging AS(SELECT greatest(1,least(coalesce(requested_page,1),greatest(1,(n+24)/25))) p,n FROM totals),
 page_rows AS(SELECT id,ordinal,payload,value,ord FROM matching ORDER BY ordinal,ord LIMIT 25 OFFSET (SELECT (p-1)*25 FROM paging))
 SELECT jsonb_build_object('revision',(SELECT revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'page',(SELECT p FROM paging),'total',(SELECT n FROM paging),'pages',greatest(1,((SELECT n FROM paging)+24)/25),
 'rows',coalesce((SELECT jsonb_agg(jsonb_build_object('run',payload-'changes','changeIndex',ord-1,'change',value||jsonb_build_object('before',public.pn2_history_preview(value->'before'),'after',public.pn2_history_preview(value->'after'))) ORDER BY ordinal,ord) FROM page_rows),'[]'::jsonb),
 'audit',coalesce((SELECT jsonb_agg(row_to_json(t)) FROM (SELECT action,created_at AS at FROM public.pn2_audit WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid ORDER BY id DESC LIMIT 20) t),'[]'::jsonb)));
END;
$history$;
REVOKE ALL ON FUNCTION public.pn2_search_history(integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_search_history(integer,text,text) TO anon,authenticated;
-- This index duplicates the primary key exactly. Keep the primary key and reverse lookup index.
DROP INDEX IF EXISTS public.pn2_entries_report_contract_idx;
-- Existing readiness flags stay backward compatible; the new client requires paged audit search too.
CREATE OR REPLACE FUNCTION public.pn2_release_compatibility() RETURNS jsonb LANGUAGE sql STABLE SET search_path=public AS $check$
 SELECT jsonb_build_object('version','23.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'auditSearchReady',to_regprocedure('public.pn2_search_history(integer,text,text)') is not null);
$check$;
commit;
notify pgrst, 'reload schema';
