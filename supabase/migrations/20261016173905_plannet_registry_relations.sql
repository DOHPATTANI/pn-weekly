-- Additive Plannet projections. Existing registry, report IDs and snapshots remain authoritative.
CREATE UNIQUE INDEX IF NOT EXISTS pn2_registry_source_identity
 ON public.pn2_contract_registry(workspace_id,fiscal_year,funding_source,(nullif(btrim(payload->>'sourceId'),'')))
 WHERE nullif(btrim(payload->>'sourceId'),'') IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.pn2_registry_segments(
 workspace_id uuid NOT NULL,registry_id text NOT NULL,ordinal integer NOT NULL CHECK(ordinal>0),
 road_no text,control_section text,section_name text,km_start text,km_end text,direction text,note text,
 PRIMARY KEY(workspace_id,registry_id,ordinal),
 FOREIGN KEY(workspace_id,registry_id) REFERENCES public.pn2_contract_registry(workspace_id,id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE IF NOT EXISTS public.pn2_registry_personnel(
 workspace_id uuid NOT NULL,registry_id text NOT NULL,person_id text NOT NULL,
 role text NOT NULL CHECK(role IN('inspection','supervision')),ordinal integer NOT NULL CHECK(ordinal>0),
 PRIMARY KEY(workspace_id,registry_id,role,person_id),UNIQUE(workspace_id,registry_id,role,ordinal),
 FOREIGN KEY(workspace_id,registry_id) REFERENCES public.pn2_contract_registry(workspace_id,id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
 FOREIGN KEY(workspace_id,person_id) REFERENCES public.pn2_supervisors(workspace_id,id) DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE public.pn2_registry_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pn2_registry_personnel ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION public.pn2_sync_registry_relations()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.payload->'segments' IS NOT DISTINCT FROM NEW.payload->'segments'
  AND OLD.payload->'committeeIds' IS NOT DISTINCT FROM NEW.payload->'committeeIds'
  AND OLD.payload->'supervisorIds' IS NOT DISTINCT FROM NEW.payload->'supervisorIds' THEN RETURN NEW;END IF;
 IF jsonb_typeof(coalesce(NEW.payload->'segments','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'committeeIds','[]'))<>'array' OR jsonb_typeof(coalesce(NEW.payload->'supervisorIds','[]'))<>'array' THEN RAISE EXCEPTION 'ช่วงทางและบุคลากรต้องเป็นรายการ';END IF;
 DELETE FROM public.pn2_registry_segments WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_segments SELECT NEW.workspace_id,NEW.id,ord::integer,x->>'routeNumber',x->>'controlSection',x->>'sectionName',x->>'kmStart',x->>'kmEnd',x->>'direction',x->>'routeNote' FROM jsonb_array_elements(coalesce(NEW.payload->'segments','[]')) WITH ORDINALITY a(x,ord);
 DELETE FROM public.pn2_registry_personnel WHERE workspace_id=NEW.workspace_id AND registry_id=NEW.id;
 INSERT INTO public.pn2_registry_personnel SELECT NEW.workspace_id,NEW.id,x#>>'{}','inspection',ord::integer FROM jsonb_array_elements(coalesce(NEW.payload->'committeeIds','[]')) WITH ORDINALITY a(x,ord);
 INSERT INTO public.pn2_registry_personnel SELECT NEW.workspace_id,NEW.id,x#>>'{}','supervision',ord::integer FROM jsonb_array_elements(coalesce(NEW.payload->'supervisorIds','[]')) WITH ORDINALITY a(x,ord);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.pn2_sync_registry_relations() FROM PUBLIC;
DROP TRIGGER IF EXISTS pn2_registry_relations ON public.pn2_contract_registry;
CREATE TRIGGER pn2_registry_relations AFTER INSERT OR UPDATE OF payload ON public.pn2_contract_registry FOR EACH ROW EXECUTE FUNCTION public.pn2_sync_registry_relations();

-- One payment note formatter retains explicit free-text remarks across all exports.
CREATE OR REPLACE FUNCTION public.pn2_format_paid_note(note text,paid_date date)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $note$
 SELECT format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from paid_date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from paid_date)::integer],extract(year from paid_date)::integer+543)||CASE WHEN btrim(regexp_replace(coalesce(note,''),'^เบิกจ่ายแล้ว วันที่ [^·]*(·[[:space:]]*)?',''))<>'' THEN ' · '||btrim(regexp_replace(coalesce(note,''),'^เบิกจ่ายแล้ว วันที่ [^·]*(·[[:space:]]*)?','')) ELSE '' END;
$note$;
REVOKE ALL ON FUNCTION public.pn2_format_paid_note(text,date) FROM PUBLIC;
-- Extend the installed amendment function in place, preserving cold-data hydration and compact delta flags.
DO $v10$ DECLARE body text; BEGIN
 body:=pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure);
 IF position($old$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end$old$ IN body)=0 THEN RAISE EXCEPTION 'Missing amendment lifecycle anchor';END IF;
 body:=replace(body,$noteold$e:=jsonb_set(e,'{note}',to_jsonb(format('เบิกจ่ายแล้ว วันที่ %s %s %s',extract(day from (e->>'paymentDate')::date)::integer,(array['มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน','กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม'])[extract(month from (e->>'paymentDate')::date)::integer],extract(year from (e->>'paymentDate')::date)::integer+543)));$noteold$,$notenew$e:=jsonb_set(e,'{note}',to_jsonb(public.pn2_format_paid_note(e->>'note',(e->>'paymentDate')::date)));$notenew$);
 body:=replace(body,$old$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end$old$,$new$|| case when change.value ? 'paymentDate' then jsonb_build_object('finalPaymentDate',coalesce(e->>'paymentDate','')) else '{}'::jsonb end
    || case when (change.value ? 'note' OR (change.value ? 'paymentDate' AND e->>'payment'='เบิกจ่ายแล้ว')) AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'reports') newer WHERE newer->>'end'>r->>'end' AND newer->'entries' ? change.key) THEN jsonb_build_object('note',coalesce(e->>'note','')) ELSE '{}'::jsonb END
    || case when change.value ? 'payment' AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(doc->'reports') newer WHERE newer->>'end'>r->>'end' AND newer->'entries' ? change.key) THEN jsonb_build_object('payment',coalesce(e->>'payment',''),'sourceStatus',CASE WHEN e->>'payment'='เบิกจ่ายแล้ว' THEN 'แล้วเสร็จ' ELSE '' END) ELSE '{}'::jsonb END$new$);EXECUTE body;
END $v10$;
NOTIFY pgrst,'reload schema';
