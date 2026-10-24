-- Read-only, funding-scoped P301 export. Does not hydrate reports or import history.
begin;
CREATE OR REPLACE FUNCTION public.pn2_load_p301_export(requested_funding text DEFAULT 'DOH') RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $export$
 WITH source AS (SELECT document,revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),
 registry AS (SELECT (SELECT jsonb_object_agg(k.key,k.value) FROM jsonb_each(r.value) k WHERE k.key=ANY(ARRAY['id','funding','year','contract','title','workCode','workCodeId','contractorId','contractorRaw','signedAt','acceptanceDate','actualCost','contractValue','segments','quantity','unit','p301'])) value FROM source s CROSS JOIN LATERAL jsonb_array_elements(coalesce(s.document->'contractRegistry','[]')) r(value) WHERE coalesce(r.value->>'funding','DOH')=requested_funding AND coalesce(r.value->>'deletedAt','')='')
 SELECT jsonb_build_object('revision',s.revision,'activeFunding',requested_funding,'settings',jsonb_build_object('p301',coalesce(s.document#>'{settings,p301}','{}')),
 'contractRegistry',coalesce((SELECT jsonb_agg(value) FROM registry),'[]'),
 'contractors',coalesce((SELECT jsonb_agg(c.value-ARRAY['dataChange','reviewedAt','sourceSheet','sourceRow','sourceEnd']) FROM jsonb_array_elements(coalesce(s.document->'contractors','[]')) c(value) WHERE EXISTS(SELECT 1 FROM registry r WHERE r.value->>'contractorId'=c.value->>'id')),'[]'),
 'workCodes',coalesce((SELECT jsonb_agg(c.value-ARRAY['dataChange','reviewedAt','sourceSheet','sourceRow','sourceEnd']) FROM jsonb_array_elements(coalesce(s.document->'workCodes','[]')) c(value) WHERE EXISTS(SELECT 1 FROM registry r WHERE r.value->>'workCodeId'=c.value->>'id' OR r.value->>'workCode'=c.value->>'name')),'[]')) FROM source s;
$export$;
REVOKE ALL ON FUNCTION public.pn2_load_p301_export(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_load_p301_export(text) TO anon,authenticated;
notify pgrst, 'reload schema';
commit;
