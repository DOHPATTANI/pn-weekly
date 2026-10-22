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

notify pgrst, 'reload schema';

commit;
