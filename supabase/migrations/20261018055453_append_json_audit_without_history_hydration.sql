-- Append one immutable run without hydrating/re-writing all previous history.
-- Supports both the original and capped-history JSON implementation.
DO $append_json_run$
DECLARE body text;start_at integer;end_at integer;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 start_at:=position('payload:=payload||jsonb_build_object(''importHistory'',' in body);
 IF start_at>0 THEN
  end_at:=start_at+position(';' in substring(body from start_at))-1;
  body:=overlay(body placing $new$INSERT INTO public.pn2_import_runs(workspace_id,id,ordinal,payload) SELECT uid,run_id::text,coalesce(min(ordinal),0)-1,run FROM public.pn2_import_runs WHERE workspace_id=uid;
 payload:=payload-'importHistory';$new$ from start_at for end_at-start_at+1);
 ELSIF position('coalesce(min(ordinal),0)-1,run' in body)=0 THEN RAISE EXCEPTION 'Unrecognized JSON audit implementation';END IF;
 body:=replace(body,'WHERE token IS NOT NULL AND token<>''''','WHERE token IS NOT NULL AND token<>'''' AND length(token)<=200');
 EXECUTE body;
END $append_json_run$;
NOTIFY pgrst,'reload schema';
