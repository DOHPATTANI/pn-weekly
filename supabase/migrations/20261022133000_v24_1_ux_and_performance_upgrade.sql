-- Migration: 20261022133000_v24_1_ux_and_performance_upgrade.sql
-- Created at: 2026-10-22T13:30:00+07:00 (Asia/Bangkok)
-- มาตรฐาน Master Developer Rules & PLANNET DOH v24.1:
-- 1. สร้าง Composite Indexes สำหรับเร่งความเร็วการกรองตาม Scope และเรียงลำดับรายงาน/สัญญา
-- 2. เพิ่มฟังก์ชัน RPC เสริมสำหรับการดึงข้อมูลเฉพาะส่วน (On-Demand Report Detail) แบบ Idempotent

begin;

create index if not exists pn2_reports_scope_end_idx
  on public.pn2_reports (workspace_id, funding_id, year, end_date desc);

create index if not exists pn2_contracts_scope_idx
  on public.pn2_contracts (workspace_id, funding_id, year, archived);

create index if not exists pn2_entries_report_contract_idx
  on public.pn2_entries (workspace_id, report_id, contract_id);
create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $check$
    select jsonb_build_object('version','23.0.0','viewWriteSafe',not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosrc ~* '(delete from|insert into) public[.]pn2_registry_work_links'),'coldSnapshotsSafe',position('pn2_hydrate_changed' in pg_get_functiondef('public.pn2_amend_report(text,jsonb,bigint)'::regprocedure))>0,'p301Ready',to_regclass('public.pn2_p301_records') is not null,'p301Transactional',position('perform public.pn2_project_p301(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0,'assetHistoryReady',to_regclass('public.pn2_asset_project_links') is not null,'depreciationSourceReady',true,'workCatalogReady',to_regclass('public.pn2_registry_work_classifications') is not null and position('perform public.pn2_project_work_catalog(payload,uid)' in pg_get_functiondef('public.pn2_save_workspace(jsonb,bigint)'::regprocedure))>0);
$check$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;

notify pgrst, 'reload schema';

commit;
