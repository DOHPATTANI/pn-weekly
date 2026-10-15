-- Compact audited CSV/XLSX import. Merge against authoritative full document inside the transaction; never transmit unloaded reports.
CREATE OR REPLACE FUNCTION public.pn2_import_changes(changes jsonb,expected_revision bigint,source jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='25s' AS $patch$
DECLARE uid uuid:='00000000-0000-0000-0000-000000000001';doc jsonb;rev bigint;k text;item jsonb;upserts jsonb;removed jsonb;merged jsonb;old_ids jsonb;result jsonb;audit_entry jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(uid::text,0));
 SELECT document,revision INTO doc,rev FROM public.pn2_workspaces WHERE workspace_id=uid FOR UPDATE;
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
  SELECT coalesce(jsonb_agg(coalesce(upserts->(x->>'id'),x) ORDER BY ord),'[]') INTO merged FROM jsonb_array_elements(coalesce(doc->k,'[]')) WITH ORDINALITY v(x,ord) WHERE NOT removed @> jsonb_build_array(x->>'id');
  SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]')||merged INTO merged FROM jsonb_array_elements(coalesce(item->'upsert','[]')) WITH ORDINALITY v(x,ord) WHERE NOT old_ids ? (x->>'id');
  doc:=jsonb_set(doc,ARRAY[k],merged);
 END LOOP;
 IF source->>'format' NOT IN ('CSV','XLSX') OR source->>'format' IS NULL THEN RAISE EXCEPTION 'ใช้สำหรับ CSV หรือ XLSX เท่านั้น';END IF;
 audit_entry:=jsonb_build_object('id',gen_random_uuid(),'at',now(),'action','นำเข้าไฟล์ '||left(coalesce(source->>'fileName','CSV'),250));
 doc:=jsonb_set(doc,'{audit}',jsonb_build_array(audit_entry)||coalesce(doc->'audit','[]'));
 result:=public.pn2_import_workspace(doc,expected_revision,source);
 IF (result->>'revision')::bigint>rev THEN RETURN (result-'document')||jsonb_build_object('importRun',result->'document'->'importHistory'->0,'auditEntry',audit_entry);END IF;
 RETURN result-'document';
END $patch$;
REVOKE ALL ON FUNCTION public.pn2_import_changes(jsonb,bigint,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_import_changes(jsonb,bigint,jsonb) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
