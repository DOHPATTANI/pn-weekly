-- Run against a populated PN Weekly workspace. Every write is rolled back.
BEGIN;
DO $test$
DECLARE doc jsonb;rev bigint;candidate jsonb;rid text;pid text;changed jsonb;actual jsonb;rejected boolean;
BEGIN
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF doc IS NULL THEN RAISE EXCEPTION 'Test requires an existing workspace';END IF;
 SELECT x->>'id' INTO rid FROM jsonb_array_elements(doc->'reports') x WHERE x->>'locked'='true' AND x->'entries'<>'{}' LIMIT 1;
 IF rid IS NULL THEN RAISE EXCEPTION 'Test requires a locked historical report';END IF;
 SELECT key INTO pid FROM jsonb_each((SELECT x->'entries' FROM jsonb_array_elements(doc->'reports') x WHERE x->>'id'=rid)) LIMIT 1;
 candidate:=jsonb_set(doc,'{settings,systemName}',to_jsonb(coalesce(doc->'settings'->>'systemName','PN Weekly')||' regression'));
 PERFORM public.pn2_save_workspace(candidate,rev);
 SELECT document INTO actual FROM public.pn2_workspaces WHERE workspace_id='00000000-0000-0000-0000-000000000001'::uuid;
 IF actual->'reports' IS DISTINCT FROM doc->'reports' THEN RAISE EXCEPTION 'Reports changed during settings save';END IF;
 IF actual->'importHistory' IS DISTINCT FROM doc->'importHistory' THEN RAISE EXCEPTION 'Import history changed';END IF;
 rejected:=false;
 BEGIN PERFORM public.pn2_save_workspace(actual,rev);EXCEPTION WHEN raise_exception THEN IF position('อีกหน้าจอ' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Stale revision was accepted';END IF;
 SELECT jsonb_agg(CASE WHEN x->>'id'=rid THEN jsonb_set(x,ARRAY['entries',pid,'note'],'"unauthorized"') ELSE x END ORDER BY ord) INTO changed FROM jsonb_array_elements(actual->'reports') WITH ORDINALITY v(x,ord);
 candidate:=jsonb_set(actual,'{reports}',changed);rejected:=false;
 BEGIN PERFORM public.pn2_save_workspace(candidate,rev+1);EXCEPTION WHEN raise_exception THEN IF position('แก้ไขรายงานย้อนหลัง' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Unauthorized history edit was accepted';END IF;
 SELECT jsonb_agg(x ORDER BY ord) INTO changed FROM jsonb_array_elements(actual->'reports') WITH ORDINALITY v(x,ord) WHERE x->>'id'<>rid;
 candidate:=jsonb_set(actual,'{reports}',changed);rejected:=false;
 BEGIN PERFORM public.pn2_save_workspace(candidate,rev+1);EXCEPTION WHEN raise_exception THEN IF position('ลบรายงาน' in SQLERRM)=0 THEN RAISE;END IF;rejected:=true;END;
 IF NOT rejected THEN RAISE EXCEPTION 'Historical report deletion was accepted';END IF;
 IF (public.pn2_import_workspace(actual,rev+1,'{"fileName":"idempotent-regression.json","format":"JSON"}')->>'revision')::bigint<>rev+1 THEN RAISE EXCEPTION 'No-op import changed revision';END IF;
END $test$;
ROLLBACK;
