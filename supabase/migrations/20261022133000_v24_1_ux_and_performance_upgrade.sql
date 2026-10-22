-- Migration: 20261022133000_v24_1_ux_and_performance_upgrade.sql
-- Created at: 2026-10-22T13:30:00-- Migration: 20261022133000_v24_1_ux_and_performance_upgrade.sql
-- Created at: 2026-10-22T13:30:00+07:00 (Asia/Bangkok)
-- Master Developer Rules & PLANNET DOH v24.1:
-- 1. Create Composite Indexes for Scope filtering on reports/contracts
-- 2. Optimize RPC for On-Demand Report Detail & Idempotent

begin;

create index if not exists pn2_reports_scope_end_idx
  on public.pn2_reports (workspace_id, funding_source, year, end_date desc);

create index if not exists pn2_contracts_scope_idx
  on public.pn2_contracts (workspace_id, funding_source, year, archived);

create index if not exists pn2_entries_report_contract_idx
  on public.pn2_entries (workspace_id, report_id, contract_id);

create or replace function public.pn2_release_compatibility() returns jsonb language sql stable set search_path=public as $$
  select jsonb_build_object('version', '23.0.0', 'viewWriteSafe', not exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'pn2_get_report_detail_v24_1'));
$$;
grant execute on function public.pn2_release_compatibility() to anon,authenticated;

notify pgrst, 'reload schema';

commit;.
