-- Additive, idempotent migration; preserve existing data.
begin;
-- Projection must run before the existing SECURITY DEFINER save returns.
-- A deferred invoker trigger fires as anon after that boundary on PostgreSQL.
-- Keep helpers private; do not grant public projection writes or add new elevated RPCs.
drop trigger if exists pn2_p301_project_at_commit on public.pn2_workspaces;
drop function if exists public.pn2_p301_projection_trigger();
do $install$ declare definition text;anchor text:='return jsonb_build_object(''revision'',new_rev);'; begin
 select pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure) into definition;
 if position('perform public.pn2_project_p301(payload,uid)' in definition)=0 then
  if position(anchor in definition)=0 then raise exception 'Unknown save contract: cannot safely attach P301 projection';end if;
  execute replace(definition,anchor,'if old_doc->''contractRegistry'' is distinct from payload->''contractRegistry'' or old_doc->''workCodes'' is distinct from payload->''workCodes'' then perform public.pn2_project_p301(payload,uid);end if; '||anchor);
 end if;
end $install$;
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
 select jsonb_build_object('version','20.0.0','viewWritesSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0 and not exists(select 1 from pg_trigger where tgname='pn2_p301_project_at_commit' and tgrelid='public.pn2_workspaces'::regclass));
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;
commit;
notify pgrst, 'reload schema';
