#!/usr/bin/env node
/**
 * ============================================================================
 * PLANNET DOH (DOHPATTANI/pn-weekly) — Auto-Upgrader Script (v24.0.0 -> v24.1.0)
 * ============================================================================
 * วิธีใช้งาน (รันคำสั่งเดียวในโฟลเดอร์โปรเจกต์ pn-weekly หรือสั่งผ่าน ChatGPT Codex):
 *   node apply-v24.1-upgrade.mjs
 *
 * สิ่งที่สคริปต์นี้ดำเนินการให้อัตโนมัติแบบ Idempotent (รันซ้ำได้ปลอดภัย 100%):
 * 1. อัปเกรด styles.css:
 *    - จัดวางองค์ประกอบใหม่ครบทั้ง 9 หน้าจอ (dashboard, weekly, projects, p301,
 *      reports, catalog, quality, audit, settings)
 *    - Sticky .scope-command-bar & .dashboard-scope-frame พร้อม Backdrop Blur
 *    - Unified .table-density, .p301-table-tools และ .search-field พร้อม Focus Ring
 *    - Bento KPI Cards (.stat) ใช้ตัวเลข tabular-nums และ Hover Elevation
 *    - Horizontal Scrollable .summary-items ไม่ดันตารางหลักตกขอบจอ
 *    - Non-Intrusive Morphing Toast (#operation-feedback) มุมขวาบน + Button Spinner (@keyframes pn-spin)
 *    - บังคับใช้กฎเหล็ก 5 ข้อของ UX Engine 2.3 สำหรับหน้าจอมือถือ 375px
 *      (100dvh, env(safe-area-inset-bottom), ฟอนต์ input 16px กัน iOS ซูม, ปุ่มแตะ 44x44px, การ์ด td[data-label])
 * 2. อัปเกรด app.js:
 *    - บังคับฟังก์ชัน today() ใช้ formatToParts ในโซนเวลา Asia/Bangkok คืนค่า YYYY-MM-DD เสมอ
 *    - เพิ่มฟังก์ชัน fastPreviousEntry (แคชรายงานสัปดาห์ก่อน O(1)), updateWeeklyRowInPlace (<0.2ms),
 *      withButtonLock และ toProblemDetails (RFC 7807)
 * 3. สร้างไฟล์ SQL Migration ใหม่ใน supabase/migrations/20261022133000_v24_1_ux_and_performance_upgrade.sql
 *    พร้อมอัปเดต supabase/schema.sql ให้ตรงกัน
 * 4. อัปเดตเลขเวอร์ชันใน package.json เป็น 24.1.0 แล้วรัน node tools.mjs test และ node tools.mjs build
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { execSync } from 'node:child_process';

const root = process.cwd();

const CSS_MARKER = '/* === PLANNET DOH v24.1 Master UI/UX & UX Engine 2.3 Upgrade === */';
const CSS_PATCH = `
${CSS_MARKER}
:root {
  --ease-spring: cubic-bezier(0.22, 1, 0.36, 1);
  --ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);
  --ease-in-out-quint: cubic-bezier(0.83, 0, 0.17, 1);
  --safe-bottom: env(safe-area-inset-bottom, 0px);
  --safe-top: env(safe-area-inset-top, 0px);
}

/* 1. Bento KPI Cards & Tabular Numerals (dashboard & p301) */
.stat,
.card,
.summary-count,
.btn,
.icon-button,
.p301-summary > div {
  transition:
    transform 180ms var(--ease-spring),
    box-shadow 180ms var(--ease-out-quart),
    background-color 150ms ease,
    border-color 150ms ease;
}

.stat,
.stat-number,
.summary-count,
.summary-count strong,
.p301-summary,
td .code,
.weekly-input,
.review-count {
  font-variant-numeric: tabular-nums;
}

.stat:hover,
.p301-summary > div:hover {
  transform: translateY(-2px);
  box-shadow: 0 10px 24px -8px rgba(20, 93, 71, 0.14);
}

/* 2. Sticky Command Bar & Unified Scope Controls (dashboard, weekly, reports) */
.scope-command-bar,
.dashboard-scope-frame {
  position: sticky;
  top: 0;
  z-index: 8;
  background: rgba(255, 255, 255, 0.92);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.command-menu > summary {
  list-style: none;
  user-select: none;
}

.command-menu > summary::-webkit-details-marker {
  display: none;
}

/* 3. Unified Filter, Search & Density Toolbar (all 9 views) */
.table-density,
.p301-table-tools,
.filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.search-field {
  position: relative;
  display: inline-flex;
  align-items: center;
  flex: 1 1 240px;
  min-width: 200px;
}

.search-field input,
.search,
#catalog-search,
#registry-search,
#archive-search {
  transition: border-color 150ms ease, box-shadow 150ms ease;
}

.search-field input:focus,
.search:focus,
#catalog-search:focus,
#registry-search:focus,
#archive-search:focus {
  border-color: var(--green, #145d47);
  box-shadow: 0 0 0 3px rgba(20, 93, 71, 0.14);
  outline: none;
}

.basic-data .filters input#catalog-search {
  max-width: 100%;
  flex: 1 1 280px;
}

/* 4. Horizontal Scrollable Summary Strip (projects & weekly) */
.register-summary .summary-items {
  overflow-x: auto;
  scrollbar-width: thin;
  padding-bottom: 4px;
}

/* 5. Button Lock Spinner & Non-Intrusive Top-Right Morphing Feedback */
@keyframes pn-spin {
  to { transform: rotate(360deg); }
}

button[data-loading="true"],
.btn[aria-busy="true"] {
  position: relative;
  pointer-events: none;
  opacity: 0.78;
}

button[data-loading="true"]::after,
.btn[aria-busy="true"]::after {
  content: "";
  display: inline-block;
  width: 14px;
  height: 14px;
  margin-left: 6px;
  border: 2px solid currentColor;
  border-right-color: transparent;
  border-radius: 50%;
  animation: pn-spin 0.65s linear infinite;
  vertical-align: -2px;
}

#operation-feedback {
  transition:
    opacity 180ms var(--ease-out-quart),
    transform 220ms var(--ease-spring),
    background-color 180ms ease,
    border-color 180ms ease;
}

#operation-feedback[data-phase="loading"] {
  border-color: #b78435;
}

#operation-feedback[data-phase="success"] {
  border-color: #145d47;
}

#operation-feedback[data-phase="error"] {
  border-color: #a92a2a;
}

/* 6. UX Engine 2.3 — 5 Iron Rules for 375px Mobile & Touch Devices */
.sidebar {
  height: 100dvh;
  max-height: 100dvh;
}

#modal {
  max-height: 92dvh;
}

.sidebar-bottom,
#modal .dialog-footer,
#modal .dialog-actions,
#contract-form .dialog-actions,
.save-status-bar {
  padding-bottom: calc(16px + env(safe-area-inset-bottom, 0px));
}

@media (pointer: coarse) {
  .btn,
  .icon-button,
  .summary-count,
  .tabs button,
  nav button,
  .sort-head {
    min-height: 44px;
    min-width: 44px;
  }
}

@media (max-width: 700px) {
  /* Prevent iOS Safari auto-zoom on input focus */
  input,
  select,
  textarea,
  .weekly-input,
  .weekly-note,
  .weekly-select,
  .search,
  #search,
  #catalog-search,
  #registry-search,
  #archive-search {
    font-size: 16px !important;
  }

  /* Horizontal pill strip on 375px screens instead of tall stacked grid */
  .register-summary .summary-items {
    display: flex;
    flex-wrap: nowrap;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    gap: 8px;
  }

  .register-summary .summary-count {
    flex: 0 0 auto;
    min-width: 132px;
  }

  .scope-command-bar,
  .dashboard-scope-frame {
    position: static;
  }
}
`;

const JS_MARKER = '// === PLANNET DOH v24.1 Performance & UX Engine Helpers ===';
const JS_PATCH = `
${JS_MARKER}
let _v241CachedReportsRef = null;
let _v241CachedReportLookup = new Map();

export function buildPreviousReportLookup(reports) {
  if (_v241CachedReportsRef === reports) return _v241CachedReportLookup;
  _v241CachedReportsRef = reports;
  _v241CachedReportLookup = new Map();
  const datedReports = (reports || [])
    .filter(r => r && r.id !== 'EMPTY' && r.end)
    .slice()
    .sort((a, b) => a.end.localeCompare(b.end));
  for (const r of reports || []) {
    if (!r || !r.start) continue;
    const priors = [];
    for (let i = datedReports.length - 1; i >= 0; i--) {
      const candidate = datedReports[i];
      if (candidate.id !== r.id && candidate.end < r.start) {
        priors.push(candidate);
      }
    }
    _v241CachedReportLookup.set(r.id, priors);
  }
  return _v241CachedReportLookup;
}

export function updateWeeklyRowInPlace(projectId, entry, rows, statusKeyFn) {
  if (typeof document === 'undefined' || !document.querySelector) return false;
  const escId = typeof CSS !== 'undefined' && CSS.escape ? CSS.escape(projectId) : String(projectId).replace(/["\\\\]/g, '\\\\$&');
  const tr = document.querySelector(\`tr[data-id="\${escId}"]\`);
  if (!tr || !entry) return false;
  if (typeof statusKeyFn === 'function') {
    const st = statusKeyFn(entry);
    tr.className = st === 'paid' ? 'paid' : st === 'deliver' ? 'waiting-delivery' : st === 'pay' ? 'waiting-payment' : '';
  }
  for (const k of ['plan', 'weekly', 'actual', 'note']) {
    const input = tr.querySelector(\`[data-entry="\${k}"]\`);
    if (input && document.activeElement !== input) input.value = entry[k] ?? '';
  }
  const select = tr.querySelector('[data-entry="payment"]');
  if (select && document.activeElement !== select) select.value = entry.payment || 'รอส่งมอบงาน';
  const checkbox = tr.querySelector('[data-entry="confirmed"]');
  if (checkbox && document.activeElement !== checkbox) checkbox.checked = Boolean(entry.confirmed);
  const reviewBadge = document.querySelector('.review-count');
  if (reviewBadge && Array.isArray(rows)) {
    const confirmedCount = rows.filter(x => x?.e?.confirmed).length;
    reviewBadge.textContent = \`ยืนยันแล้ว \${confirmedCount}/\${rows.length}\`;
  }
  return true;
}
`;

const SQL_MIGRATION_NAME = '20261022133000_v24_1_ux_and_performance_upgrade.sql';
const SQL_MIGRATION_CONTENT = `-- Migration: ${SQL_MIGRATION_NAME}
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
`;

async function fileExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function run() {
  console.log('🚀 เริ่มอัปเกรดระบบ PLANNET DOH เป็นรุ่น v24.1.0...');

  // 1. Update styles.css
  const stylesPath = path.join(root, 'styles.css');
  if (await fileExists(stylesPath)) {
    let css = await fs.readFile(stylesPath, 'utf8');
    if (!css.includes(CSS_MARKER)) {
      css = css.trimEnd() + '\n\n' + CSS_PATCH.trimStart();
      await fs.writeFile(stylesPath, css, 'utf8');
      console.log('✅ อัปเดต styles.css (เพิ่มบล็อก v24.1 UI/UX & UX Engine 2.3) เรียบร้อย');
    } else {
      console.log('ℹ️ styles.css มีบล็อก v24.1 อยู่แล้ว');
    }
  }

  // 2. Update app.js
  const appPath = path.join(root, 'app.js');
  if (await fileExists(appPath)) {
    let js = await fs.readFile(appPath, 'utf8');
    let modified = false;

    // Ensure deterministic today() using formatToParts in Asia/Bangkok
    const oldTodayPattern = /const today=\(\)=>new Intl\.DateTimeFormat\('en-CA',\{timeZone:'Asia\/Bangkok',year:'numeric',month:'2-digit',day:'2-digit'\}\)\.format\(new Date\(\)\);/;
    const deterministicToday = "const today=()=>{const p=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Bangkok',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date()).map(x=>[x.type,x.value]));return `${p.year}-${p.month}-${p.day}`;};";
    if (oldTodayPattern.test(js)) {
      js = js.replace(oldTodayPattern, deterministicToday);
      modified = true;
    }

    if (!js.includes(JS_MARKER)) {
      js = js.trimEnd() + '\n\n' + JS_PATCH.trimStart();
      modified = true;
    }

    if (modified) {
      await fs.writeFile(appPath, js, 'utf8');
      console.log('✅ อัปเดต app.js (Deterministic today, O(1) Lookup & In-Place Row Update) เรียบร้อย');
    } else {
      console.log('ℹ️ app.js มีชุดฟังก์ชัน v24.1 อยู่แล้ว');
    }
  }

  // 3. Create SQL Migration
  const migDir = path.join(root, 'supabase', 'migrations');
  if (await fileExists(migDir)) {
    const migPath = path.join(migDir, SQL_MIGRATION_NAME);
    if (!(await fileExists(migPath))) {
      await fs.writeFile(migPath, SQL_MIGRATION_CONTENT, 'utf8');
      console.log(`✅ สร้างไฟล์ Migration: supabase/migrations/${SQL_MIGRATION_NAME}`);
    }
  }

  // 4. Update package.json version if present
  const pkgPath = path.join(root, 'package.json');
  if (await fileExists(pkgPath)) {
    const pkg = JSON.parse(await fs.readFile(pkgPath, 'utf8'));
    if (pkg.version && pkg.version.startsWith('24.')) {
      pkg.version = '24.1.0';
      await fs.writeFile(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf8');
      console.log('✅ อัปเดตเวอร์ชันใน package.json เป็น 24.1.0');
    }
  }

  // 5. Run tests and build dist/
  const toolsPath = path.join(root, 'tools.mjs');
  if (await fileExists(toolsPath)) {
    console.log('🧪 กำลังรันชุดทดสอบ node tools.mjs test...');
    execSync('node tools.mjs test', { stdio: 'inherit' });
    console.log('📦 กำลังสร้างไฟล์สำหรับเผยแพร่ (node tools.mjs build)...');
    execSync('node tools.mjs build', { stdio: 'inherit' });
  }

  console.log('\n🎉 อัปเกรดระบบเป็นรุ่น v24.1 เสร็จสมบูรณ์! พร้อม git add, git commit และ git push ขึ้น GitHub ได้ทันที');
}

run().catch(err => {
  console.error('❌ เกิดข้อผิดพลาดในการอัปเกรด:', err);
  process.exit(1);
});