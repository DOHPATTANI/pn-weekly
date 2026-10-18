-- Compact whole-node additions/removals while retaining exact before/after.
CREATE OR REPLACE FUNCTION public.pn2_import_diff(old_value jsonb,new_value jsonb,field_path text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SET search_path='' AS $$
DECLARE result jsonb:='[]';k text;left_obj jsonb;right_obj jsonb;
BEGIN
 IF old_value IS NOT DISTINCT FROM new_value THEN RETURN result;END IF;
 -- A whole added/removed node already contains every old/new field. Recursing
 -- through thousands of absent snapshot leaves caused quadratic JSON appends.
 IF old_value IS NULL OR new_value IS NULL THEN RETURN jsonb_build_array(jsonb_build_object('path',field_path,'before',old_value,'after',new_value,'kind',CASE WHEN old_value IS NULL THEN 'added' ELSE 'removed' END));END IF;
 IF (old_value IS NULL OR jsonb_typeof(old_value)='array') AND (new_value IS NULL OR jsonb_typeof(new_value)='array') AND
 NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(old_value,'[]')||coalesce(new_value,'[]')) x WHERE jsonb_typeof(x)<>'object' OR NOT x ? 'id') THEN
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO left_obj FROM jsonb_array_elements(coalesce(old_value,'[]')) x;
  SELECT coalesce(jsonb_object_agg(x->>'id',x),'{}') INTO right_obj FROM jsonb_array_elements(coalesce(new_value,'[]')) x;
  RETURN public.pn2_import_diff(left_obj,right_obj,field_path);
 END IF;
 IF (old_value IS NULL OR jsonb_typeof(old_value)='object') AND (new_value IS NULL OR jsonb_typeof(new_value)='object') THEN
  old_value:=coalesce(old_value,'{}');new_value:=coalesce(new_value,'{}');
  FOR k IN SELECT key FROM (SELECT jsonb_object_keys(old_value) AS key UNION SELECT jsonb_object_keys(new_value)) keys ORDER BY key LOOP
   IF k=ANY(ARRAY['revision','audit','importHistory','sourceArchive','masterSequences','yearCodes','updatedAt','sourceImported','sourceFile','sourceSheet','sourceRow','createdAt']) THEN CONTINUE;END IF;
   result:=result||public.pn2_import_diff(old_value->k,new_value->k,CASE WHEN field_path='' THEN k ELSE field_path||' / '||k END);
  END LOOP;
  RETURN result;
 END IF;
 RETURN jsonb_build_array(jsonb_build_object('path',field_path,'before',old_value,'after',new_value,'kind',CASE WHEN old_value IS NULL THEN 'added' WHEN new_value IS NULL THEN 'removed' ELSE 'updated' END));
END $$;

NOTIFY pgrst,'reload schema';
