-- Full integration regression on an existing workspace. Writes are rolled back.
BEGIN;
DO $test$
DECLARE before_doc jsonb;scope_doc jsonb;prior jsonb;draft jsonb;items jsonb;rev bigint;pid text;result jsonb;after_doc jsonb;rejected boolean;locked_id text;
BEGIN
 before_doc:=public.pn2_load_workspace();rev:=(before_doc->>'revision')::bigint;
 scope_doc:=public.pn2_load_scope('PROVINCE',2569,NULL);
 IF scope_doc ? 'importHistory' THEN RAISE EXCEPTION 'History was loaded unnecessarily';END IF;
 IF jsonb_array_length(scope_doc->'reports')<>jsonb_array_length(before_doc->'reports') THEN RAISE EXCEPTION 'Report catalogue incomplete';END IF;
 SELECT x INTO prior FROM jsonb_array_elements(scope_doc->'reports') x WHERE NOT coalesce((x->>'_unloaded')::boolean,false) LIMIT 1;
 SELECT jsonb_object_agg(key,value||'{"weekly":0,"confirmed":false}'::jsonb) INTO items FROM jsonb_each(prior->'entries');
 draft:=(prior-'lockedAt'-'settingsSnapshot'-'modifiedAt'-'amendedVersion')||jsonb_build_object('id','REGRESSION-DELTA','title','ทดสอบ delta','year',2569,'funding','PROVINCE','start',(prior->>'end')::date+1,'end',(prior->>'end')::date+7,'reference',(prior->>'end')::date+7,'locked',false,'imported',false,'snapshots','{}'::jsonb,'entries',items);
 result:=public.pn2_patch_workspace(jsonb_build_object('collections',jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(draft),'remove','[]'::jsonb))),rev,'ทดสอบสร้าง delta');
 SELECT key INTO pid FROM jsonb_each(items) LIMIT 1;draft:=jsonb_set(draft,ARRAY['entries',pid,'note'],'"ทดสอบบันทึกเฉพาะรายงาน"');
 PERFORM public.pn2_patch_workspace(jsonb_build_object('collections',jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(draft),'remove','[]'::jsonb))),rev+1,'ทดสอบแก้ delta');
 after_doc:=public.pn2_load_workspace();
 IF after_doc->'importHistory' IS DISTINCT FROM before_doc->'importHistory' THEN RAISE EXCEPTION 'Import history changed';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(before_doc->'reports') old WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(after_doc->'reports') current WHERE old=current)) THEN RAISE EXCEPTION 'Existing report changed';END IF;
 IF NOT EXISTS(SELECT 1 FROM public.pn2_entries WHERE report_id='REGRESSION-DELTA' AND contract_id=pid AND note='ทดสอบบันทึกเฉพาะรายงาน') THEN RAISE EXCEPTION 'Relational projection not synchronized';END IF;
 PERFORM public.pn2_patch_workspace('{"values":{"settings":{"systemName":"regression settings"}}}',rev+2,'ทดสอบตั้งค่า');
 IF public.pn2_load_workspace()->'settings'->'logo' IS DISTINCT FROM before_doc->'settings'->'logo' THEN RAISE EXCEPTION 'Unchanged logo was lost';END IF;
 rejected:=false;
 BEGIN PERFORM public.pn2_patch_workspace('{"values":{"settings":{"systemName":"stale"}}}',rev,'stale');EXCEPTION WHEN raise_exception THEN IF position('อีกหน้าจอ' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Stale write accepted';END IF;
 SELECT x->>'id' INTO locked_id FROM jsonb_array_elements(before_doc->'reports') x WHERE x->>'locked'='true' LIMIT 1;
 rejected:=false;
 BEGIN PERFORM public.pn2_patch_workspace(jsonb_build_object('collections',jsonb_build_object('reports',jsonb_build_object('upsert','[]'::jsonb,'remove',jsonb_build_array(locked_id)))),rev+3,'forbidden delete');EXCEPTION WHEN raise_exception THEN IF position('ลบรายงาน' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Closed report removal was accepted';END IF;
 draft:=jsonb_set(draft,ARRAY['entries',pid,'plan'],'101');rejected:=false;
 BEGIN PERFORM public.pn2_patch_workspace(jsonb_build_object('collections',jsonb_build_object('reports',jsonb_build_object('upsert',jsonb_build_array(draft),'remove','[]'::jsonb))),rev+3,'invalid percent');EXCEPTION WHEN raise_exception THEN IF position('เปอร์เซ็นต์' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Invalid percentage was accepted';END IF;
 IF (public.pn2_patch_workspace('{}',rev+3,'no-op')->>'revision')::bigint<>rev+3 THEN RAISE EXCEPTION 'No-op changed revision';END IF;
END $test$;
ROLLBACK;
