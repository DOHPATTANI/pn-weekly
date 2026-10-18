-- v14: latest populated registry year and paged cold audit. No business data deletion here.
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
 yr:=requested_year;IF yr IS NULL OR NOT doc->'years' @> to_jsonb(ARRAY[yr]) THEN SELECT max(fiscal_year) INTO yr FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND payload->>'deletedAt' IS NULL AND (requested_funding IS NULL OR funding_source=requested_funding);IF yr IS NULL THEN SELECT max(fiscal_year) INTO yr FROM public.pn2_contract_registry WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND payload->>'deletedAt' IS NULL;END IF;END IF;
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

CREATE FUNCTION public.pn2_history_preview(value jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN octet_length(value::text)>2400 THEN jsonb_build_object('_historyPreview',true,'label',CASE jsonb_typeof(value) WHEN 'array' THEN 'รายการข้อมูล' WHEN 'object' THEN 'ชุดข้อมูล' ELSE 'ข้อความ' END,'text',left(value::text,1600)) ELSE value END
$$;
CREATE FUNCTION public.pn2_load_history_page(requested_page integer DEFAULT 1) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' SET statement_timeout='15s' AS $$
 WITH runs AS MATERIALIZED(SELECT id,ordinal,payload FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),
 totals AS(SELECT coalesce(sum(jsonb_array_length(coalesce(payload->'changes','[]'))),0)::integer n FROM runs),
 paging AS(SELECT greatest(1,least(coalesce(requested_page,1),greatest(1,(n+24)/25))) p,n FROM totals),
 changes AS(SELECT r.id,r.ordinal,r.payload,c.value,c.ord FROM runs r CROSS JOIN LATERAL jsonb_array_elements(coalesce(r.payload->'changes','[]')) WITH ORDINALITY c(value,ord) ORDER BY r.ordinal,c.ord LIMIT 25 OFFSET (SELECT (p-1)*25 FROM paging))
 SELECT jsonb_build_object('revision',(SELECT revision FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid),'page',(SELECT p FROM paging),'total',(SELECT n FROM paging),'pages',greatest(1,((SELECT n FROM paging)+24)/25),'rows',coalesce((SELECT jsonb_agg(jsonb_build_object('run',payload-'changes'-'labels'||jsonb_build_object('labels',coalesce(payload->'labels','{}')),'changeIndex',ord-1,'change',value||jsonb_build_object('before',public.pn2_history_preview(value->'before'),'after',public.pn2_history_preview(value->'after')))) FROM changes),'[]'),'audit',coalesce((SELECT jsonb_agg(row_to_json(t)) FROM (SELECT action,created_at AS at FROM public.pn2_audit WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid ORDER BY id DESC LIMIT 20) t),'[]'))
$$;
CREATE FUNCTION public.pn2_load_history_change(requested_run text,requested_index integer) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT jsonb_build_object('run',payload-'changes','change',payload->'changes'->requested_index) FROM public.pn2_import_runs WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid AND id=requested_run
$$;
GRANT EXECUTE ON FUNCTION public.pn2_load_history_page(integer),public.pn2_load_history_change(text,integer) TO anon,authenticated;
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
 -- A shared master rename must reach linked projections outside the currently loaded year.
 FOREACH k IN ARRAY ARRAY['contractors','supervisors'] LOOP
  SELECT coalesce(jsonb_object_agg(x->>'id',x->>'name'),'{}') INTO upserts FROM jsonb_array_elements(coalesce(changes->'collections'->k->'upsert','[]')) x;
  IF upserts<>'{}' THEN
   SELECT coalesce(jsonb_agg(CASE WHEN upserts ? (x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END) THEN x||jsonb_build_object(CASE WHEN k='contractors' THEN 'contractor' ELSE 'supervisor' END,upserts->>(x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END)) ELSE x END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(doc->'projects') WITH ORDINALITY v(x,ord);
   doc:=jsonb_set(doc,'{projects}',merged);
   SELECT coalesce(jsonb_agg(x),'[]') INTO removed FROM jsonb_array_elements(merged) x WHERE upserts ? (x->>CASE WHEN k='contractors' THEN 'contractorId' ELSE 'supervisorId' END) OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(changes->'collections'->'projects'->'upsert','[]')) q WHERE q->>'id'=x->>'id');
   changes:=jsonb_set(changes,'{collections,projects}',coalesce(changes->'collections'->'projects','{}')||jsonb_build_object('upsert',removed,'remove',coalesce(changes->'collections'->'projects'->'remove','[]')));
   IF k='contractors' THEN
    SELECT coalesce(jsonb_agg(CASE WHEN upserts ? (x->>'contractorId') THEN x||jsonb_build_object('contractorNeedsReview',coalesce((m->>'needsNameReview')::boolean,false)) ELSE x END ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(doc->'contractRegistry') WITH ORDINALITY v(x,ord) LEFT JOIN LATERAL(SELECT value m FROM jsonb_array_elements(doc->'contractors') WHERE value->>'id'=x->>'contractorId') lookup ON true;
    doc:=jsonb_set(doc,'{contractRegistry}',merged);
    SELECT coalesce(jsonb_agg(x),'[]') INTO removed FROM jsonb_array_elements(merged) x WHERE upserts ? (x->>'contractorId') OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(changes->'collections'->'contractRegistry'->'upsert','[]')) q WHERE q->>'id'=x->>'id');
    changes:=jsonb_set(changes,'{collections,contractRegistry}',coalesce(changes->'collections'->'contractRegistry','{}')||jsonb_build_object('upsert',removed,'remove',coalesce(changes->'collections'->'contractRegistry'->'remove','[]')));
   END IF;
  END IF;
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

