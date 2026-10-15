-- Uses the populated historical workspace; all changes roll back.
BEGIN;
DO $test$
DECLARE doc jsonb;rev bigint;prior jsonb;draft jsonb;entries jsonb;candidate jsonb;after_doc jsonb;rejected boolean;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RAISE EXCEPTION 'A populated workspace is required';END IF;
 SELECT x INTO prior FROM jsonb_array_elements(doc->'reports') x WHERE x->>'funding'='PROVINCE' AND x->>'year'='2569' ORDER BY nullif(x->>'end','')::date DESC LIMIT 1;
 IF NOT EXISTS(SELECT 1 FROM jsonb_each(prior->'entries') e WHERE e.value->>'payment'='เบิกจ่ายแล้ว' AND nullif(e.value->>'paymentDate','') IS NULL) THEN RAISE EXCEPTION 'Fixture requires inherited paid rows with unknown days';END IF;
 SELECT jsonb_object_agg(key,value||'{"weekly":0,"confirmed":false}'::jsonb) INTO entries FROM jsonb_each(prior->'entries');
 draft:=jsonb_build_object('id','REGRESSION-DRAFT','funding','PROVINCE','year',2569,'title','regression','start',(prior->>'end')::date+1,'end',(prior->>'end')::date+7,'reference',(prior->>'end')::date+7,'locked',false,'imported',false,'entries',entries,'snapshots','{}'::jsonb);
 candidate:=jsonb_set(doc-'importHistory','{reports}',jsonb_build_array(draft)||(doc->'reports'));
 PERFORM public.pn2_save_workspace(candidate,rev);
 after_doc:=public.pn2_load_workspace();
 IF after_doc->'importHistory' IS DISTINCT FROM doc->'importHistory' THEN RAISE EXCEPTION 'Import history lost during active save';END IF;
 IF public.pn2_load_active_workspace() ? 'importHistory' THEN RAISE EXCEPTION 'Operational load includes heavy audit history';END IF;
 IF (public.pn2_load_import_history())->'importHistory' IS DISTINCT FROM doc->'importHistory' THEN RAISE EXCEPTION 'Deferred audit history changed';END IF;
 SELECT jsonb_object_agg(key,value||'{"confirmed":true}'::jsonb) INTO entries FROM jsonb_each(draft->'entries');
 draft:=draft||jsonb_build_object('entries',entries,'locked',true,'snapshots',(SELECT jsonb_object_agg(x->>'id',x) FROM jsonb_array_elements(doc->'projects') x WHERE entries ? (x->>'id')));
 candidate:=jsonb_set(after_doc-'importHistory','{reports}',jsonb_build_array(draft)||(doc->'reports'));rejected:=false;
 BEGIN PERFORM public.pn2_save_workspace(candidate,rev+1);EXCEPTION WHEN raise_exception THEN IF position('วันที่เบิกจ่าย' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Closing without documented payment days was accepted';END IF;
 IF (SELECT jsonb_array_length(document->'reports') FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid)<>jsonb_array_length(doc->'reports')+1 THEN RAISE EXCEPTION 'Unexpected report count';END IF;
END $test$;
ROLLBACK;
