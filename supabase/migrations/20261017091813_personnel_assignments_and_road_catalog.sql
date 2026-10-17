-- Reusable road identity and per-contract personnel positions/duties. No authentication changes.
ALTER TABLE public.pn2_registry_personnel ADD COLUMN IF NOT EXISTS position_name text NOT NULL DEFAULT '';
ALTER TABLE public.pn2_registry_personnel ADD COLUMN IF NOT EXISTS duty text NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS pn2_registry_personnel_person_idx ON public.pn2_registry_personnel(workspace_id,person_id);
CREATE TABLE IF NOT EXISTS public.pn2_road_sections(
 workspace_id uuid NOT NULL REFERENCES public.pn2_workspaces(workspace_id) ON DELETE CASCADE,
 id text NOT NULL,road_no text NOT NULL DEFAULT '',control_section text NOT NULL DEFAULT '',section_name text NOT NULL DEFAULT '',
 PRIMARY KEY(workspace_id,id),UNIQUE(workspace_id,road_no,control_section,section_name)
);
ALTER TABLE public.pn2_road_sections ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_sync_road_catalog() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.document#>'{settings,roadSections}' IS NOT DISTINCT FROM NEW.document#>'{settings,roadSections}' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.document#>'{settings,roadSections}','[]'))<>'array' THEN RAISE EXCEPTION 'ทะเบียนสายทางต้องเป็นรายการ';END IF;
 INSERT INTO public.pn2_road_sections(workspace_id,id,road_no,control_section,section_name)
 SELECT NEW.workspace_id,x->>'id',coalesce(x->>'routeNumber',''),coalesce(x->>'controlSection',''),coalesce(x->>'sectionName','') FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x
 ON CONFLICT(workspace_id,id) DO UPDATE SET road_no=excluded.road_no,control_section=excluded.control_section,section_name=excluded.section_name WHERE (pn2_road_sections.road_no,pn2_road_sections.control_section,pn2_road_sections.section_name) IS DISTINCT FROM (excluded.road_no,excluded.control_section,excluded.section_name);
 DELETE FROM public.pn2_road_sections t WHERE workspace_id=NEW.workspace_id AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(NEW.document#>'{settings,roadSections}','[]')) x WHERE x->>'id'=t.id);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_road_catalog() FROM PUBLIC;
CREATE TRIGGER pn2_road_catalog AFTER INSERT OR UPDATE OF document ON public.pn2_workspaces FOR EACH ROW EXECUTE FUNCTION public.pn2_sync_road_catalog();
CREATE OR REPLACE FUNCTION public.pn2_sync_registry_relations()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item jsonb;expected jsonb;group_key text;BEGIN
 IF TG_OP='UPDATE' AND OLD.payload->'segments' IS NOT DISTINCT FROM NEW.payload->'segments' AND OLD.payload->'committeeIds' IS NOT DISTINCT FROM NEW.payload->'committeeIds' AND OLD.payload->'supervisorIds' IS NOT DISTINCT FROM NEW.payload->'supervisorIds' AND OLD.payload->'personnelAssignments' IS NOT DISTINCT FROM NEW.payload->'personnelAssignments' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.payload->'segments','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'committeeIds','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'supervisorIds','[]'))<>'array' THEN RAISE EXCEPTION 'ช่วงทางและบุคลากรต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_registry_segments WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_segments SELECT NEW.workspace_id,NEW.id,ord::integer,x->>'routeNumber',x->>'controlSection',x->>'sectionName',x->>'kmStart',x->>'kmEnd',x->>'direction',x->>'routeNote' FROM jsonb_array_elements(coalesce(NEW.payload->'segments','[]')) WITH ORDINALITY a(x,ord);
 DELETE FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 IF NEW.payload ? 'personnelAssignments' THEN
  IF jsonb_typeof(NEW.payload->'personnelAssignments')<>'array' THEN RAISE EXCEPTION 'รูปแบบบุคลากรไม่ถูกต้อง';END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(NEW.payload->'personnelAssignments') LOOP
   IF item->>'group' NOT IN('inspection','supervision') OR nullif(item->>'personId','') IS NULL OR coalesce(item->>'ordinal','') !~ '^[1-9][0-9]*$' THEN RAISE EXCEPTION 'ประเภท คีย์ หรือลำดับบุคลากรไม่ถูกต้อง';END IF;
   IF (item->>'group'='inspection' AND item->>'duty' NOT IN('ประธาน','กรรมการ')) OR (item->>'group'='supervision' AND item->>'duty' NOT IN('ผู้ควบคุมงาน','ผู้ช่วยผู้ควบคุมงาน')) OR item->>'duty' IS NULL THEN RAISE EXCEPTION 'บทบาทบุคลากรไม่ถูกต้อง';END IF;
   INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,position_name,duty) VALUES(NEW.workspace_id,NEW.id,item->>'personId',item->>'group',(item->>'ordinal')::integer,coalesce(item->>'position',''),item->>'duty');
  END LOOP;
  FOREACH group_key IN ARRAY ARRAY['inspection','supervision'] LOOP
   SELECT coalesce(jsonb_agg(person_id ORDER BY ordinal),'[]') INTO expected FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id AND role=group_key;
   IF expected IS DISTINCT FROM coalesce(NEW.payload->(CASE WHEN group_key='inspection' THEN 'committeeIds' ELSE 'supervisorIds' END),'[]') THEN RAISE EXCEPTION 'รายการบุคลากรและคีย์อ้างอิงไม่ตรงกัน';END IF;
   IF jsonb_array_length(expected)>0 AND (SELECT count(*) FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id AND role=group_key AND duty=CASE WHEN group_key='inspection' THEN 'ประธาน' ELSE 'ผู้ควบคุมงาน' END)<>1 THEN RAISE EXCEPTION 'ต้องมีประธานหรือผู้ควบคุมงานหลักเพียงหนึ่งคนต่อกลุ่ม';END IF;
  END LOOP;
 ELSE
  INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,duty) SELECT NEW.workspace_id,NEW.id,x#>>'{}','inspection',ord::integer,CASE WHEN ord=1 THEN 'ประธาน' ELSE 'กรรมการ' END FROM jsonb_array_elements(coalesce(NEW.payload->'committeeIds','[]')) WITH ORDINALITY a(x,ord);
  INSERT INTO public.pn2_registry_personnel(workspace_id,registry_id,person_id,role,ordinal,duty) SELECT NEW.workspace_id,NEW.id,x#>>'{}','supervision',ord::integer,CASE WHEN ord=1 THEN 'ผู้ควบคุมงาน' ELSE 'ผู้ช่วยผู้ควบคุมงาน' END FROM jsonb_array_elements(coalesce(NEW.payload->'supervisorIds','[]')) WITH ORDINALITY a(x,ord);
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_registry_relations() FROM PUBLIC;
-- Set legacy duty values without changing source documents, identities or report snapshots.
UPDATE public.pn2_registry_personnel SET duty=CASE WHEN role='inspection' THEN CASE WHEN ordinal=1 THEN 'ประธาน' ELSE 'กรรมการ' END ELSE CASE WHEN ordinal=1 THEN 'ผู้ควบคุมงาน' ELSE 'ผู้ช่วยผู้ควบคุมงาน' END END WHERE duty='';
NOTIFY pgrst,'reload schema';
