-- Append-only activity events use the existing cold history store and shared-workspace access model.
CREATE OR REPLACE FUNCTION public.pn2_record_activity(event jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET statement_timeout='10s' AS $$
DECLARE workspace uuid:='00000000-0000-0000-0000-000000000001';eid text;run jsonb;
BEGIN
 IF jsonb_typeof(event)<>'object' OR nullif(event->>'id','') IS NULL OR nullif(event->>'action','') IS NULL OR octet_length(event::text)>2000000 THEN RAISE EXCEPTION 'รูปแบบประวัติไม่ถูกต้อง';END IF;
 eid:=event->>'id';IF length(eid)>200 THEN RAISE EXCEPTION 'รหัสประวัติยาวเกินกำหนด';END IF;
 IF jsonb_typeof(coalesce(event->'changes','[]'))<>'array' THEN RAISE EXCEPTION 'รายละเอียดประวัติต้องเป็นรายการ';END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(workspace::text,0));
 IF NOT EXISTS(SELECT 1 FROM public.pn2_workspaces WHERE workspace_id=workspace) THEN RAISE EXCEPTION 'ยังไม่มีพื้นที่ข้อมูล';END IF;
 run:=jsonb_build_object('id',eid,'at',now(),'occurredAt',event->>'at','fileName',left(event->>'action',300),'format','ACTIVITY','labels',coalesce(event->'labels','{}'),'details',coalesce(event->'details','{}'),'changes',CASE WHEN jsonb_array_length(coalesce(event->'changes','[]'))>0 THEN event->'changes' ELSE jsonb_build_array(jsonb_build_object('path','การดำเนินการ','kind','activity','before',null,'after',coalesce(event->'details','{}'))) END);
 INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT workspace,eid,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=workspace ON CONFLICT(workspace_id,id) DO NOTHING;
 SELECT payload INTO run FROM public.pn2_import_runs WHERE workspace_id=workspace AND id=eid;
 RETURN run||jsonb_build_object('recorded',true);
END $$;
REVOKE ALL ON FUNCTION public.pn2_record_activity(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pn2_record_activity(jsonb) TO anon,authenticated;
NOTIFY pgrst,'reload schema';
