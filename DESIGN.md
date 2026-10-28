version: v27.3
name: "PLANNET DOH"
description: "Thai highway weekly contract reporting, extensible highway operations dashboard and operational archive"
colors:
  primary: "#145d47"
  text: "#173a32"
  muted: "#526b62"
  background: "#f3f5f1"
  surface: "#ffffff"
  border: "#d9e3dc"
  sidebar: "#103e32"
  accent: "#b79850"
  delivery: "#177245"
  payment: "#1455aa"
  paid: "#e22222"
typography:
  sans:
    fontFamily: "Kanit, IBM Plex Sans Thai, Inter, Noto Sans Thai, Tahoma, sans-serif"
  utility:
    fontFamily: "Tahoma, sans-serif"
  report:
    fontFamily: "TH SarabunPSK, THSarabun, sans-serif"
rounded:
  DEFAULT: "8px"
  panel: "12px"
spacing:
  page: "38px"
  phone: "14px"
components:
  button:
    rounded: "8px"
---

# PLANNET DOH design and behavior contract

> **Precedence Note (v27.3):** กฎในส่วนท้ายสุด (`v27.3`) และใน `AGENTS.md` มีผลบังคับใช้เหนือข้อจำกัดเก่าในส่วนต้นของเอกสารนี้ หากคำสั่งปัจจุบันของผู้ใช้ขัดแย้งกับภาพอ้างอิงเดิม ให้ยึดคำสั่งปัจจุบันของผู้ใช้เป็นหลักเสมอ

## v25–v27.3 current visual reference

Owner supplied `plannet_doh.html` (`หน้าภาพรวมโครงการ.html`); its emerald/gold theme and `.dash-v25-*` component system are the visual source for the operational shell, dashboard, and nine screens. Source sample records (`SEED_DATA`) and cache-deletion startup (`indexedDB.deleteDatabase`) are strictly excluded — all numbers, charts, and tables must bind 100% to live `Supabase` / `IndexedDB` state.

`styles.css` remains the Design Token owner (`:root`). Component variants (`.dash-v25-*`) and selector view models (`src/dashboard-selectors.js`) allow flexible UI customization without external Tailwind scripts or runtime frameworks, while keeping official report documents (`.main-report`, `.p301-accessible`) strictly isolated. Existing button, modal, field, date, selection, row-detail and persistence owners remain canonical.

Dashboard filter bar contains funding source (`#funding-select`), fiscal year (`#year`), work type (`#dash-worktype-select`), project search (`#dash-top-search`), and Create week (`[data-action="new-report"]`); the actual latest scoped report (`latestScopeReport()`) supplies the data. Weekly/archive retain historical week selection. Main project/registry page size defaults to 10/25/50/100, while the dual dashboard summary tables (`ตารางโครงการทั้งหมด` and `งานค้างดำเนินการ`) default to 8 rows per page via Config.

## Overview

Product/admin surface for Thai highway officers preparing weekly management reports and managing contract registries. The design uses a forest-green navigation shell (`--g900`, `--g800`), brass/gold accents (`--gold`) and paper-white operational surfaces. The executive and P.3-01 reports follow official institutional tables. The archive is a chronological register rather than a dashboard of cards.

Authoritative business decisions are the user's latest instructions, `Rules.md`, `AGENTS.md`, and the user manual. The system uses one shared workspace without login and audited historical editing.

## Colors

Runtime CSS in `styles.css` is canonical (`:root` Design Tokens). Existing variables include primary `--green` (`--g900`/`--g800`), text `--ink`, muted `--muted`, background `--bg`, border `--line`, `--gold`, and lifecycle colors `--delivery-ink` and `--payment-ink`. Paid red is retained in webpage and exported rows. Status text always accompanies colors.

## Typography

Thai locale, Bangkok business timezone, Buddhist years (พ.ศ.) in display, Gregorian `YYYY-MM-DD` for storage. Select/datalist popups are platform-owned. Date popups use the shared authored Thai BE Flatpickr owner. Web and Dashboard surfaces support `Kanit`, `IBM Plex Sans Thai`, `Inter`, `Noto Sans Thai`, and `Tahoma`. Official report fonts use bundled `THSarabun.ttf` (`TH SarabunPSK`) to fit A4 landscape accurately.

## Layout

### DOH operational refinement — 2026-10-28

ผู้ใช้เลือกแนว “ห้องปฏิบัติงานทาง” จากหน้าเปรียบเทียบ oil-ui: คงเมนูซ้ายเต็ม ขอบเขตข้อมูลอยู่ด้านบน คำสั่งอยู่ใกล้ข้อมูลที่จัดการ และให้ตารางเป็นพื้นที่ทำงานหลัก ใช้ humanizer ปรับข้อความภาษาไทยให้สั้นและตรงงาน เช่น “ตัวกรอง”, “บันทึกการแก้ไข”, “ยังไม่ตรวจสอบ” โดยคงชื่อแบบฟอร์ม สถานะทางบัญชี และความหมายของการเก็บรายงานเดิม

หน้าปฏิบัติงานใช้ภาพลักษณ์ศูนย์ควบคุมงานทาง: เขียวป่า `#0f3e2f` และทองเส้นทาง `#e4b84a` เป็น brand accents บนพื้นขาว ตัวอักษรไทยใช้ font stack เดิม ตารางและตัวเลขใช้ tabular numerals ลำดับสำคัญคือ scope หนึ่งชุด → คำสั่งในกรอบเดียว → สรุปที่สัมพันธ์กับงาน → ตาราง หลีกเลี่ยงกรอบซ้อน แถบปุ่มเปลืองพื้นที่และเงาหลายชั้น ความพรีเมียมมาจาก alignment ความหนาแน่นที่อ่านง่าย และความสม่ำเสมอ ไม่เพิ่มของตกแต่งที่ไม่ช่วยเจ้าหน้าที่ทำงาน

Runtime owner คือ `src/cascade-06.css` ผ่าน `--doh-forest` / `--doh-highway-gold` และ business-named operational selectors เท่านั้น ไม่เปลี่ยนสีตัวอักษรเอกสารราชการหรือ semantic status ด้วย brand tokens

Desktop collapsible sidebar + document-scrolling content. Archive: group/year filters, local search, five-column native table, latest end date first. Table owns horizontal overflow; the page must not overflow horizontally. Loading/error feedback must not move primary controls.

## Elevation & Depth

Use white bordered panels with 10–12px corners and subtle elevation (`.dash-v25-card`). The dashboard features a dark-green summary hero band (`.dash-v25-hero-card`) with a gold progress bar (`.hbar`) and 4 KPI cards with sparklines. Keep official report/export presentation unchanged.

## Shapes

Reuse existing `.btn`, `.card`, `.dash-v25-card`, `.field`, `.pill`, `.pill-box` and native dialog. Preserve keyboard focus rings and operable scrollbars. Respect `prefers-reduced-motion: reduce`.

## Components

### Canonical UI Map and UX contract

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | selectField + native select/datalist; searchableContractorField + bindContractorChoice for transfer | DESIGN.md + runtime owner | platform-owned defaults; authored transfer chooser | keyboard/open popup/explicit ID selection/browser tests |
| Date | bindThaiDates/openThaiCalendar backed by bundled Flatpickr | UX-CONTRACT.md | authored Thai BE popup; ISO CE value; date-only storage | keyboard, year/month/day, Escape, native DB ordering |
| Form | field/selectField, modal, showFormError | DESIGN.md + runtime owner | create/edit/history amendment | required/range checks, inline errors, duplicate-submit disable |
| Scrollbar | styles.css global baseline | DESIGN.md + runtime owner | responsive archive & `.table-scroll` geometry | Chrome desktop/mobile inspection |
| Toast / Feedback | toast + #toast role=status / operationFeedback | DESIGN.md + runtime owner | success/error/loading | DOM and browser live status |
| CRUD | mutate, catalogUI, saveAmendment | DESIGN.md + runtime owner | standard save vs audited historical save | actual PostgreSQL + DOM + Chrome |

Table Selection is not part of the archive: there are no bulk-selection checkboxes. Weekly confirmation checkboxes are a business review state, not a grid selection model.

### Shared interactions

Create/edit uses the same app dialog and save/cancel controls. Form errors preserve values. Historical editing is staged until Save, with no reason and no secondary confirmation. Contract choice is disabled after editing begins so a switch cannot silently discard input. Cancel intentionally discards that dialog's edits. Standard weekly input continues to autosave. Revision conflicts preserve entered values and require loading the latest version.

Search filters the already loaded workspace locally. Archive search is transient and non-shareable; group/year are remembered in localStorage. Reset/clamp pagination when filtering. Empty state explains how to recover. Add buttons appear only for a non-empty exact name not already in the master list; successful create keeps the contract form open and selects the new name.

### Historical data

`pn2_amend_report` accepts only entry-field patches, preserves contract snapshots and report identity, records before/after automatically, and updates the amended indicator. Changing historical cumulative actual preserves later cumulative figures and recomputes their weekly increment; reject negative increments rather than guessing. Delivery and acceptance dates are independent optional fields retained when payment status changes. Awaiting delivery/payment tabs only count completed work; ongoing is separate.

## Do's and Don'ts

- Keep one Open action on archive rows; edit/export is inside the report.
- Keep report titles separate by funding source and fiscal year derived from contract selection.
- Do not put internal IDs into executive exports.
- Do not introduce login, new approval gates or mandatory amendment reasons.
- Do not merge data-import JSON into GitHub `package.json`: they have separate destinations.
- Use installed skills/plugins when applicable; do not invoke unrelated plugins just because available.

## Verification and modular source architecture

The maintained verification evidence is in the consolidated manual. Static premium audit supplements runtime tests; it does not replace them. Source code is organized into modular partitions under `src/` controlled by `src/manifest.json` (separating UI Components, Selectors/View Models in `src/dashboard-selectors.js`, and Services/Business Logic) and compiled into root `app.js` and `styles.css` via `node tools.mjs source`. `tools.mjs` owns source assembly, test, build, and serve. No external runtime npm framework or mock contract data is bundled into production state.

## Registry import contract — v5

The approved mapping is PO -> contract value, payment-group Total Project -> actual construction cost. Missing is not zero. Contractor source names stay pending in registry records and never create contractor masters automatically. CSV schema is defined once by `registryColumns` (Single Source of Truth) and used for both import/export. XLSX conversion reads cached values and Thai dates, never evaluates workbook instructions.

Registry records are separate from projects/reports so imports and overwrites cannot change weekly report detail, entries or snapshots. Duplicate identity is funding/year/normalized contract; displayed text remains original. Preview makes missing fields and duplicates explicit and defaults to skipping duplicates. Invalid rows can be skipped, not fabricated. Type is manually assigned to code/title relationships. Dates fall back to matching weekly data only when absent.

## Linked contract registry — v6

Preserve the established green/white identity and shared modal/field/toast/CRUD owners. Registry is the current contract source; `pn2_contracts` is the report projection with `registry_id` and `registry.project_id`. Imports do not rewrite existing weekly entries/snapshots. A new report materializes registry rows for its exact funding/year and carries prior progress; opening a previously unreported group/year automatically creates week 1 with all three progress values 0. Blank source contractor IDs remain pending even when projected and never create masters automatically.

Budget/code/job names are master records, with `work_name_codes` supporting the same job name under multiple codes. Work type -> code -> job selection is searchable; code with one linked job prefills title, which remains editable. Create/edit use one registry form. All deletions require shared `confirmAction`. Referenced contracts are removed from active registry/future weeks via archived flag; historical snapshots/FKs remain. Unreferenced contracts can be physically deleted. Replacing group/year on a previously reported contract is rejected.

## v7 – v7.5 production decisions, audited imports, and CSV upsert

- **v7:** Report font `TH SarabunPSK` uses bundled `THSarabun.ttf`. Contract display strips only leading Thai `PN` prefix; header is `ปน.`. Master codes have a type prefix + 6 digits, hidden from UI, stored as code without replacing legacy PK/FK. Only latest draft week can edit period or cancel (7-day Tue–Mon). `DEFAULT_CONFIG` in `app.js` contains supplied anon config, connects automatically, no login.
- **v7.1:** JSON replaces the full active workspace, preserving business-matched PK/FKs. CSV adds/updates rows and preserves omitted records. The shared import mutation calls `pn2_import_workspace` with optimistic revision and stores a server-computed change log. No-op imports do not advance revision.
- **v7.2.1 – v7.3:** Creating a report opens that draft once with all contracts visible. Newly paid rows need an explicit day, and closing a new report requires all payment days and confirmations. Scope RPCs return the complete report catalogue, progress history for reconciliation in the selected funding/year, and full snapshots only for the selected report.
- **v7.4 – v7.5:** Dashboard summary and charts use the selected funding/year and latest scoped report. Average progress is unweighted per contract; no invented finance or trend data. CSV imports match explicit ID first, falling back to legacy business names/codes or scoped contract number only when no ID is supplied.

## v8 – v10.1 master-data simplification, workflow contract, and contract dossier

- **v8:** Ordinary master CSV and tables expose one readable stable code; opaque PKs and `workspace_id` stay internal. Work names and official work codes share one screen and CSV. Existing code-less jobs show “รอระบุรหัสงาน”. New catalog jobs require a unique official code.
- **v9:** Shared table selection defaults to all matching rows across pagination in selection mode. Import comparison shows before write, and post-write change pills open field-level old/new review. Quality reviews use `sha256-v1` of canonical `changeFingerprint`. Report-specific display aliases live in settings keyed by report/contract and never mutate registry titles.
- **v10 – v10.1:** Import G-3 and personnel G-4 separately. Contract detail reading layout is a text-led read-only dossier (2 columns on desktop, 1 on mobile), distinguishing unknown from numeric zero. Route detail/edit shows a table with highway, control section, section/project name, start km, end km and direction (no route-distance column). Child route removal is staged locally and committed only on Save contract.

## v11 – v16 registry refinements, compact surfaces, and linked weekly data

- **v11 – v12:** G-4 import extracts full name, source ordinal and position; position/duty belongs to a contract assignment, not the shared person. Personnel masters fill position from authoritative G-4 only when empty. Contractor fuzzy suggestions require explicit selection; never merge two verified firms automatically. Date uses shared authored Thai BE Flatpickr with ISO CE storage.
- **v13 – v15:** All personnel share one `บุคลากร` category (`pn2_personnel`). Shared modal has a fixed header, one scrolling `.dialog-body`, and a separate opaque footer. External file imports support ก-3, ก-3 งบฉุกเฉิน and ก-4.
- **v16:** Operational columns measure filtered loaded data and allow horizontal table scrolling. Weekly numeric plan/weekly/actual and remarks support inline activation; Escape cancels, blur/Enter saves.

## v17 – v19 registry-driven membership, report layout studio, and actionable feedback

- **v17 – v17.2:** Weekly reports automatically include all active contracts from their selected funding/year, including closed reports, via `synchronizeReport` using the existing compact audited import owner. Province job titles remain complete on one line in built-in layouts.
- **v18:** `reportLayout` is the sole width owner for HTML/print, workbook and image renderer (`settings.reportLayoutDOH` and `settings.reportLayoutPROVINCE`).
- **v19:** `operationFeedback` is the shared non-blocking feedback popover (reparenting inside open modals). `withButtonLock` disables buttons during async actions (`data-loading="true"`, `aria-busy="true"`). `toProblemDetails` uses RFC 7807 structure. `pn2_release_compatibility` verifies the database write contract.

## v20 – v23 P.3-01 asset register, highway asset history, and work hierarchy

- **v20 – v21:** P.3-01 uses `acceptanceDate` and `actualCost` (never `deliveryDate` or inferred progress money). P.3-01 has 12 columns including unit-price. PDF and PNG derive from one vector page model; XLSX uses the same pagination, editable cells, and repeated blocks. Highway asset history deduplicates contracts with multiple segments and unions overlapping kilometer intervals for centerline distance.
- **v22 – v23:** Form studios isolate DOH and PROVINCE settings. Depreciation catalog matches exact code (`p301WorkRule` in JS and `pn2_p301_work_rule` in SQL must match). `dayCountMethod` supports `actual/365/366`. Operational tables at ≤640px become label/value cards **except** official report documents, child editors, and Dashboard `.dash-v25-clean-table` tables.

## v24 – v26.0.1 375px baseline, operational dock, and collapsible navigation

- **v24:** 375px mobile baseline across operational surfaces, 44px touch targets, 16px mobile inputs, and `env(safe-area-inset-bottom)`.
- **v26 – v26.0.1:** `mountOperationalDock` owns sticky primary actions. `mountCollapsibleSidebar` in `src/sidebar.js` owns desktop rail (252px expanded / 80px collapsed) and menu search (Ctrl/Cmd+K).

---

## v27.3 — Unified Extensible Architecture, Component Breakdown & Flexible Dashboard

This section is the active architectural and UI baseline, superseding any conflicting presentation constraints in earlier sections while preserving all data, report, import, and database contracts:

1. **Instruction Precedence & Flexible Dashboard (`plannet_doh.html`):**
   - Latest user instructions take highest priority over reference images, mockups, or older section locks.
   - The Dashboard (`หน้าภาพรวมโครงการ`) is fully extensible to match `plannet_doh.html` (`หน้าภาพรวมโครงการ.html`) or new user requirements:
     - **Header & Filter Bar (`.dash-v25-header-bar` & `.dash-v25-filter`):** Displays `ภาพรวมโครงการ` (agency seal optional via config/variant) with `#funding-select`, `#year`, `#dash-worktype-select`, `#dash-top-search`, and `[data-action="new-report"]`.
     - **Hero Banner & 4 KPI Cards (`.dash-v25-hero-card`, `.dash-v25-kpi-card` `k1`–`k4`):** Driven 100% by live `Supabase` / `IndexedDB` state (`latestScopeReport()`). Never copy sample records (`SEED_DATA`), database-deletion scripts, or synthetic budget multipliers from preview HTML files.
     - **5-Stage Contract Status Card (`.dash-v25-card.pipe`):** Titled `สถานะสัญญา` with `สัดส่วนสถานะสัญญา 100%`, hover tooltips on `.pbar` (`data-tip` / `title`), and 5 clickable `.pill-box` cards (`ongoing`, `deliver`, `pay`, `paid`, `expired`) showing count, `.pill-bar`, and two-decimal `.pill-tag`.
     - **Budget Account Progress (`.dash-v25-card.route`) & Work-Type Donut (`.dash-v25-card.donut-card`):** Grouped from live database records (`budgetAccount` and `workTypeId`) with clickable filters and no artificial AI warning banner.
     - **Dual Bottom Tables (`.grid.row4.dash-v25-grid4`):** Left table `ตารางโครงการทั้งหมด` (4 columns) and right table `งานค้างดำเนินการ` (`#expired-contracts`, 6 columns with 5 filter chips: `all`, `incomplete`, `expired`, `followup`, and `projects` link). Both use `.tbl.dash-v25-clean-table` (default 8 rows/page via Config) and explicitly opt out of `operationalTable` / `mountResponsiveRows` mobile-card transformation at ≤640px.

2. **Project Setup, Modular Structure & Context Management:**
   - **Single Source of Truth:** Centralize constants, configs, and schemas/typedefs; never duplicate definitions across files.
   - **Modular Structure & Component Breakdown:** Separate **Presentation UI Components** (Atomic/Functional with clear Props/JSDoc interfaces and zero hardcoded strings/numbers) from **Selectors / View Models / Hooks (`src/dashboard-selectors.js`)** and **Services / Pure Business Functions**.
   - **Context Injection & File Merging:** Map all module dependencies in `src/manifest.json` before editing, preserve all existing code without truncation, and run `node tools.mjs source` to synchronize runtime assets.
   - **Self-Documenting Code:** Provide JSDoc for every function and update `README.md`, `src/manifest.json`, and `docs/decision-log.md` whenever structure or design contracts change.

3. **Pre-Finalization QA & Security Audit:**
   - Before completing any change, verify runtime null/undefined safety (`?.`, `??`, safe fallbacks), input/schema validation, HTML escaping against XSS, and deterministic locked dependencies.
