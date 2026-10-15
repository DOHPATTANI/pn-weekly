-- Quality counts need the contract identity, not every old note and percentage.
DO $quality8$
DECLARE body text;
BEGIN
 body:=pg_get_functiondef('public.pn2_load_scope(text,integer,text)'::regprocedure);
 body:=replace(body,'jsonb_build_array(e.key,e.value)',$new$jsonb_build_array(e.key,'{}'::jsonb)$new$);
 EXECUTE body;
END $quality8$;
NOTIFY pgrst,'reload schema';
