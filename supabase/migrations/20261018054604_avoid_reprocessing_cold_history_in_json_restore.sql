-- Import audit history belongs to the destination, not the active replacement
-- payload. Existing archived history remains intact; every new change is audited.
DO $json_history$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_import_workspace(jsonb,bigint,jsonb)'::regprocedure);
 body:=replace(body,'payload:=payload-''sourceArchive'';', 'payload:=payload-''sourceArchive''-''importHistory''-''importHistoryDeferred''-''importHistoryCached''-''loadedScope'';');
 body:=replace(body,'file_name,format_name,old_doc,payload,diff)', 'file_name,format_name,jsonb_build_object(''storageFormat'',''delta-v1'',''changes'',diff),jsonb_build_object(''storageFormat'',''delta-v1'',''run'',run),diff)');
 EXECUTE body;
END $json_history$;
NOTIFY pgrst,'reload schema';
