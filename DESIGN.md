---
version: alpha
name: "PLANNET DOH"
description: "Thai highway weekly contract reporting, highway operations dashboard and operational archive"
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
    fontFamily: "Noto Sans Thai, Tahoma, sans-serif"
  utility:
    fontFamily: "Tahoma, sans-serif"
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

## Overview

Product/admin surface for one Thai highway officer preparing weekly management reports. The user-approved v7.4 redesign uses a forest-green navigation shell, brass accents and paper-white operational surfaces. The visual reference is highway operations and Thai institutional documents; these palette choices are not a claim of official brand specifications. The report itself follows the supplied institutional table. The archive is a chronological register rather than a dashboard of cards. Avoid repeated actions, decorative tiles and unnecessary status columns.

Authoritative business decisions are the user's requests in this chat and the installation/user manual. The user explicitly chose one shared workspace without login and direct historical editing without reason or extra confirmation. Older v3 immutable-history behavior is superseded through the audited amendment workflow; silent wholesale overwriting is still rejected.

## Colors

Runtime CSS in styles.css is canonical. This document records the existing variables: primary --green, text --ink, muted --muted, background --bg, border --line; website lifecycle colors --delivery-ink and --payment-ink. Paid red is retained in webpage and exported rows. Green awaiting-delivery and blue awaiting-payment are scoped to #app. Exported detail rows otherwise stay black. Summary colors follow the source report. Status text accompanies colors.

## Typography

Thai locale, Bangkok business timezone, Buddhist years in display, Gregorian YYYY-MM-DD for storage. Select/datalist popups are intentionally platform-owned. Date popups use the shared authored Thai BE Flatpickr owner. Tahoma is the deterministic offline fallback. No Japan-market behavior applies. Archive cells are 14px with 1.6 line-height; labels use 12px. Report fonts remain smaller to fit A4 landscape.

## Layout

Desktop sidebar + document-scrolling content. Archive: group/year filters, local search, five-column native table, latest end date first, ten rows per page. Mobile below 700px transforms each row into a vertical record with the same single Open action. Table owns horizontal overflow; the page must not overflow horizontally. Loading/error feedback must not move primary controls.

## Elevation & Depth

Use white bordered panels with 10–12px corners and very subtle elevation. The dashboard alone has a dark-green summary band with a brass progress line; avoid decorative imagery. Use the uploaded organizational seal on a white backing for contrast against the dark sidebar. Keep report/export presentation unchanged.

## Shapes

Reuse existing .btn, .card, .field, .pill and native dialog. Preserve keyboard focus rings and operable scrollbars. Respect reduced-motion preferences.

## Components

### Canonical UI Map and UX contract

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Select/Listbox | selectField + native select/datalist; searchableContractorField + bindContractorChoice for transfer | DESIGN.md + runtime owner | platform-owned defaults; authored transfer chooser | keyboard/open popup/explicit ID selection/browser tests |
| Date | bindThaiDates/openThaiCalendar backed by bundled Flatpickr | UX-CONTRACT.md | authored Thai BE popup; ISO CE value; date-only storage | keyboard, year/month/day, Escape, native DB ordering |
| Form | field/selectField, modal, showFormError | DESIGN.md + runtime owner | create/edit/history amendment | required/range checks, inline errors, duplicate-submit disable |
| Scrollbar | styles.css global baseline | DESIGN.md + runtime owner | responsive archive geometry | Chrome desktop/mobile inspection |
| Toast | toast + #toast role=status | DESIGN.md + runtime owner | success/error | DOM and browser live status |
| CRUD | mutate, catalogUI, saveAmendment | DESIGN.md + runtime owner | standard save vs audited historical save | actual PostgreSQL + DOM + Chrome |

Table Selection is not part of the archive: there are no bulk-selection checkboxes. Weekly confirmation checkboxes are a business review state, not a grid selection model.

### Shared interactions

Create/edit uses the same app dialog and save/cancel controls. Form errors preserve values. Historical editing is staged until Save, with no reason and no secondary confirmation. Contract choice is disabled after editing begins so a switch cannot silently discard input. Cancel intentionally discards that dialog's edits. Standard weekly input continues to autosave. Revision conflicts preserve entered values and require loading the latest version.

Search filters the already loaded workspace locally. Archive search is transient and non-shareable; group/year are remembered in localStorage because this is a single-person application rather than a shareable list URL. Reset/clamp pagination when filtering. Empty state explains how to recover. Add buttons appear only for a non-empty exact name not already in the master list; successful create keeps the contract form open and selects the new name.

### Historical data

pn2_amend_report accepts only entry-field patches, preserves contract snapshots and report identity, records before/after automatically, and updates the amended indicator. Changing historical cumulative actual preserves later cumulative figures and recomputes their weekly increment; reject negative increments rather than guessing. Delivery and acceptance dates are independent optional fields retained when payment status changes. Awaiting delivery/payment tabs only count completed work; ongoing is separate.

## Do's and Don'ts

- Keep one Open action on archive rows; edit/export is inside the report.
- Keep report titles separate by funding source and fiscal year derived from contract selection.
- Do not put internal IDs into executive exports.
- Do not introduce login, new approval gates or mandatory amendment reasons.
- Do not merge data-import JSON into GitHub package.json: they have separate destinations.
- Use installed skills/plugins when applicable; do not invoke unrelated plugins just because available.

## Verification and legacy migration

The maintained verification evidence is in the consolidated manual. Static premium audit supplements runtime tests; it does not replace them. The published code is one app.js assembled by section; tools.mjs owns test/build/serve. No runtime npm dependency or real contract data is bundled. Previous separate JS modules and separate workflows are retired when replacing the repository contents with this release.

## Registry import contract — v5

The user's approved mapping is PO -> contract value, payment-group Total Project -> actual construction cost. Missing is not zero. Contractor source names stay pending in registry records and never create contractor masters automatically. CSV schema is defined once by registryColumns in app.js and used for both import/export. XLSX conversion reads cached values and Thai dates, never evaluates workbook instructions.

Registry records are separate from projects/reports so imports and overwrites cannot change weekly report detail, entries or snapshots. Duplicate identity is funding/year/normalized contract; displayed text remains original. Preview makes missing fields and duplicates explicit and defaults to skipping duplicates. Invalid rows can be skipped, not fabricated. Type is manually assigned to code/title relationships. Dates fall back to matching weekly data only when absent. The CSV import, source converter and pending-contractor match use the existing modal, validation, select, file input and toast owners.

## Linked contract registry — v6, supersedes the v5 isolation at report creation

Preserve the established green/white Operate identity and shared modal/field/toast/CRUD owners. Registry is the current contract source; pn2_contracts is the report projection with registry_id and registry.project_id. Imports still do not rewrite existing weekly entries/snapshots. A new report materializes registry rows for its exact funding/year and carries prior progress; opening a previously unreported group/year automatically creates week1 with all three progress values0. Blank source contractor IDs remain pending even when projected and never create masters automatically.

Budget/code/job names are master records, with work_name_codes supporting the same job name under multiple codes. Work type -> code -> job selection is searchable; code with one linked job prefills title, which remains editable. Create/edit use one registry form. All deletions require shared confirmAction. Referenced contracts are removed from active registry/future weeks via archived flag; historical snapshots/FKs remain. Unreferenced contracts can be physically deleted. Replacing group/year on a previously reported contract is rejected.

Registry table has consistent SVG view/edit/delete icons, row Enter/Space opens full detail, action clicks do not bubble to row. Shared native dialog owns top Close, Escape, and backdrop hit test. Sort headers report aria-sort and use Thai natural text/numeric values, blanks last. Registry group/year controls contain no week selector. Summary strips sit outside table panels and filter budget/status lists; no duplicate status tabs. Mobile keeps summary2-column and table overflow inside its scroll owner. HeaderClose is sticky in long dialogs. Dates are edited in a contract dialog and never occupy weekly table date columns. Lifecycle amendments sync only the date keys actually patched, leaving frozen snapshots untouched.

Verification: tools.mjs test25 cases, work/v6-tests.mjs PGlite upgrade/FKs/amend/delete, work/v6-browser.cjs Chrome desktop1440x1000/phone390x844. Browser plugin absent: installed Playwright+systemChrome fallback. Detector advisories mainly flag existing palette literals and legacy dashboard Arial; preserve incumbent identity for this scoped feature. Print export palette/layout remain unchanged.

## v7 production decisions

Preserve Operate identity. Summary uses blue/all, amber/ongoing, green/delivery, blue/payment and red/paid tinted surfaces with explicit text and a selected outline; registry accounts use matching distinct tints. Responsive totals full row + remaining2-column on phone. New report font TH SarabunPSK is the user's exact bundled THSarabun.ttf: HTML/PDF/canvas use @font-face and wait for it; XLSX names the font and requires local installation. Contract display strips only leading Thai PN prefix; header is ปน. Canonical report values own all three export formats. Print thead explicitly avoids breaks for repeatable headers.

Master codes have a type prefix+6digits, hidden from UI, stored as code without replacing legacy PK/FK. Counters persist in workspace and are not recycled. CSV owner is masterCSV/previewMasterCSV/applyMasterCSV; preserve omitted metadata, skip duplicates by default, keep reference IDs on overwrite. Catalog uses existing shared CRUD/dialog/confirm/field owners, semantic SVG icon actions and25-row pagination.

Only latest draft week can edit period or cancel:7-dayTue–Mon, start after other report periods for same funding/year, cumulative preserved and weekly recalculated, confirmations reset. Closed history keeps snapshots and uses existing audited progress amendment. Settings has no URL/key fields; DEFAULT_CONFIG in app.js contains supplied anon config, connects automatically, no login. Cloud review does not imply live deployment. QA:30 unit tests, embedded PostgreSQL, realChrome desktop/phone,2-page printed PDF with embeddedfont, actualXLSX/JPG generated by UI.

## v7.1 audited file imports — user decision 15 October 2026

CSV and JSON may overwrite confirmed and closed records when the user imports a file. JSON replaces the full active workspace, preserving business-matched PK/FKs. CSV replaces the selected master tab or registry funding/year scope; referenced omitted masters/contracts are archived to retain relational references. The import audit shows file/time, readable record/field, old value, current value and added/updated/removed status in the existing native table with 25-row pagination. Values are text-escaped. No new palette or typography tokens; existing card/modal/confirm/toast/scroll owners remain canonical. Normal saves still protect closed report history.

The shared import mutation calls pn2_import_workspace with optimistic revision and stores a server-computed change log plus an inaccessible-to-anon full document archive in one transaction. A failed import rolls back both data and its audit. No-op imports do not advance revision. Ordinary changes use pn2_save_workspace. Master tables and relational projections are refreshed transactionally inside pn2_save_workspace.

CSV registry and master imports now share parseCSVTable; malformed quotes, inconsistent widths, duplicate headers and wrong/duplicate master codes are rejected. Export UTF-8 BOM, multiline quoted text, numeric zero vs blank and stable master codes remain supported. JSON validation rejects missing references, invalid dates, missing closed snapshots and dangerous object keys before confirmation. Browser verification uses local SQL and synthetic fixtures; this does not prove a live Supabase rollout.

## Weekly creation and operational loading — v7.2.1

Keep the existing shared modal, date controls, form error, toast and paid summary filter. Creating a report opens that draft once with all contracts visible. The shared modal blocks duplicate submissions, announces the pending save, and retains date values on failure. Historical paid rows without a documented day may carry into a draft unchanged; the draft names the number of missing dates and links to the paid contracts. Their existing `บันทึกวันที่` action owns correction. Do not invent dates or change old snapshots. Newly paid rows need an explicit day, and closing a new report requires all payment days and confirmations.

The operational load excludes bulky import diffs. Audit history is fetched when its screen opens; full backup uses the full snapshot RPC. Ordinary edits reuse immutable audit data in memory and omit it on the wire; the database preserves the authoritative history. Weekly scope membership does not sort every historical report, and one render reuses its active rows. The save callback selects the created report before rendering.

## Scoped operation and recoverable editing — v7.3

The initial scope is the latest fiscal year with contracts; a remembered valid year/funding wins. Scope RPCs return the complete report catalogue, progress history for reconciliation in the selected funding/year, and full snapshots only for the selected report. Changing the report loads its frozen detail before rendering. Full backup and audited imports continue using complete server snapshots.

Ordinary changes use a whitelisted delta RPC with optimistic revision. Unloaded report metadata is never written back. The database retains closed-history validation, authoritative import history, and atomic relational projections. When contracts and masters are unchanged, only changed report projections are refreshed. Settings changes merge only changed fields so an unchanged logo is not retransmitted.

The shared save queue serializes weekly edits, preserves newer typed values across renders, and retains failed drafts on the device for explicit retry. The status bar announces loading, queued saves, completion and failure. Unsaved drafts warn on exit; recovered drafts are shown for review. Clearing pending values requires the shared destructive confirmation. Modal close/cancel/Escape are blocked during submission. Failed IndexedDB writes produce a persistent temporary-storage notice instead of an implicit durable-save claim.

The `ตรวจข้อมูล` surface reuses periodBar, native tables, shared notices, pagination (25 rows), Open Report and registry-edit owners. Missing payment days are grouped by contract with affected report counts. Duplicate source periods and nonstandard source ranges are review items, never silently repaired. Settings counts reflect live catalogue totals, and internal PKs are hidden in weekly rows.

## v7.4 highway dashboard — user-authorized redesign

The dashboard is the canonical visual reference for the app shell. Runtime palette remains canonical in styles.css; --sidebar and --gold join the existing role variables. The dark navigation and brass active marker carry identity. White content surfaces, readable Thai text, native controls, lifecycle semantics and existing interaction owners remain shared across routes. Larger Latin numerals use Arial; Thai labels use Noto Sans Thai/Tahoma. No runtime dependency or database schema change.

Dashboard summary and charts use the selected funding/year/report. Status counters navigate into the weekly table with matching filters. Historical chart buttons use the existing lazy-load report opener before showing rows. Attention rows use the existing contract dialog. The average is explicitly unweighted per contract; no invented finance or trend data. Empty charts and zero totals remain truthful. Paid red remains semantic and export fonts/layout remain untouched. Desktop has four summary metrics and two analytical columns; tablet/phone use two metrics per row and a single analytical column. Keyboard focus, reduced motion, mobile menu and recoverable save status remain functional.

Reconciled intentional drift: the prior white sidebar/no-summary-band rule is superseded by the user-requested institutional dashboard redesign; the archive remains a chronological register and report documents retain their original style. No lifecycle or permission decision changes.

## v7.4.1 release identity
The sidebar displays a visible version and dashboard identity for support verification. Deployment rejects an outdated commit when using the updated workflow. On 15 October an old v7.3 workflow was rerun after v7.4 and replaced the live site; this was a release rollback, not evidence of a browser cache issue. To publish current main, start a new workflow, not a rerun of an old deployment.

## v7.5 CSV identity and upsert — user decision

CSV exports for all seven catalog tabs and the contract registry include ID and workspace_id. Fiscal years export their year as ID; registry exports also include funding/year. The combined workspace and ID represent the database primary key (workspace/year for fiscal years). Import history CSV includes the import-run ID and raw key path alongside human-readable labels.

CSV imports match explicit ID first, falling back to legacy business names/codes or scoped contract number only when no ID is supplied. Conflicting IDs, duplicated IDs, mismatched workspaces and wrong registry scopes are rejected in preview. Supplied new IDs are retained. Fiscal-year IDs are immutable; a new year must be added. CSV now adds/updates rows and preserves omitted records, superseding earlier CSV replacement semantics. JSON replacement and audited import retention remain unchanged. Blank registry values continue to preserve old values; CSV is not a full workspace backup.

The existing import dialogs own the workflow. Per-row details show old/new values, identical data is labeled unchanged, and successful unchanged CSV imports do not issue write RPCs or create a new revision. Registry timestamps and optional absent empty fields do not produce false changes. Changed imports still use the audited import RPC. Closed reports and snapshots remain unchanged by registry/master CSV import. No database migration or access-setting change in this release.

## v8 master-data simplification and responsive editing

The latest user decision supersedes the v7.5 visible-ID export design. Ordinary master CSV and tables expose one readable stable code. Opaque primary keys and workspace UUID stay internal; legacy CSV remains accepted. Fiscal years show the year alone. Each entity has its own columns; contractors add address and telephone, supervisors do not inherit contact fields. Archive controls are removed while report history remains intact.

Work names and official work codes share one screen and CSV, retaining work type. Internal readable job code remains necessary for legacy unpaired jobs; the separate official work-code business field is never fabricated. Existing code-less jobs show “รอระบุรหัสงาน”. Unused codes can be paired through a focused dialog and survive CSV round trips. New catalog jobs require a unique official code. Registry work-code selection fills the corresponding name/type.

CSV imports show loading, old/new differences, visible dialog errors and retry controls. Identical rows do not write. Weekly entry saves preserve input DOM nodes and focus, update row/status summaries, retain pending edits across reload, and send a single entry. Searches are debounced where the main weekly table rerendered per keystroke. Local durable writes remain immediate: revision checks use a small IndexedDB key; a delayed cache write was not adopted because a completed-save indicator must mean the offline copy has committed.

Cold snapshots/history are authoritative in dedicated tables; scope loading includes the selected snapshot, six recent entry sets and explicit prior carry values. Opening old reports fetches one detail. Full JSON backup hydrates all cold data. Security and login behavior remain outside this change.

The local cache stores import history under a separate IndexedDB key and writes it only when its immutable reference changes, preserving immediate atomic cache commits. Compact CSV imports append one cold history row; unchanged projection collections and obsolete entry-key scans are skipped. Report compaction uses a single aggregate rather than repeatedly extending an array.

- v8.1 registry: primary Excel import/export/template; text contract/code columns, numeric amounts, date cells, hidden retained identity. No forced manual master matching; preview states newly added types. Legacy CSV stays available.

- v8.1.1: source contractor names resolve to exact existing names automatically or create a contractor without a blocking review step. Persistent new/updated badges reuse the shared pill owner in registry list/detail and master list/edit; identical imports preserve their last actual change. Dates show Asia/Bangkok in Thai.

- v8.1.2 lifecycle-date dialog follows changed-field amendment semantics; untouched empty historical fields do not overwrite current registry dates.

## v9 authorized workflow contract
- Shared table selection defaults to all matching rows across pagination. Clearing all then selecting rows narrows export; filters always bound the dataset. Selection count and scope appear explicitly. Registry, catalog, reports, weekly and quality use one DOM selection owner, not independent handlers.
- Import comparison remains before write, and post-write change pills open field-level old/new review. Review confirmation is separate from mutation success; unchanged reimports preserve last real change/review state. Quality reviews hide only the same issue fingerprint and remain accessible in reviewed mode.
- Shared outbox persists local state and queued deltas in one IndexedDB transaction. Server conflict stops replay, never overwrites silently. Shared script doubles as service worker; no top-level-await because worker startup must remain supported. Cold historical reports need prior caching offline.
- Report-specific display names live in settings keyed by report/contract, never update the job master or registry. Web dates stay Thai; reversible file date-only values are DD/MM/YYYY Gregorian. Audit timestamps stay timestamps.
- Report deletion supports selected entries in a week and selected weeks, always names selected rows in confirmation and writes audited before/after history; registry survives.
- Project status is a pie plus clickable count legend; expiry uses latest effective end including approved extensions. Shared document widths apply relative factors and normalize to page width.

## v10 Plannet registry
Registry columns begin ID Code, contract, work code, job, contractor, supervisors and contract amount. Route segments and grouped financial/personnel fields belong in detail/edit dialogs. Import G-3 and personnel G-4 separately; show old/new values and preserve closed snapshots. Personnel share full-name identity with inspection/supervision roles, while report aliases carry forward from their effective week. Selection is opt-in and starts empty; hide checkbox controls in browse mode. Reviewed badges disappear until real data changes. Expiry cards/tables/badges exclude physically finished and paid work. Primary source-shaped Excel retains Thai dates; legacy typed files remain available.

## v10.1 contract detail reading layout
Owner approved a text-led read-only dossier, separate from edit field styling. The same domain headings organize both: project, contract/time, budgets, payments, progress/handover, personnel, routes/quantities and notes. View opens all business sections, shows a brief identity/status header and three key facts, uses two columns on desktop/one on mobile, distinguishes unknown from numeric zero, preserves every prior detail plus route notes and source progress, and keeps edit/close accessible. Existing modal/field/date/save/delete primitives remain canonical; no data schema or lifecycle changes. Intentional evolution resolves the previous long undifferentiated detail list.

- v10.1 route refinement: both detail and edit show a table with highway, control section, section/project name, start km, end km and direction; no route-distance column. Edit expands a named row form, add creates another child under the same contract, removal is confirmed locally and committed only on Save contract. Preserve leading-zero road/section identifiers and km text.

## v11 approved data and UI contract
Explicit owner start supersedes listening-only hold. Keep date storage CE/native date, Thai BE web/Plannet display. Remove amount only from main registry list. G4 import extracts full name, source ordinal and position, defaults inspection chair/member and supervision primary/assistant; position/duty belongs to a contract assignment, not the shared person. Native assignments and road catalogue are indexed projections with parent FKs. One primary duty per nonempty group. Inline row editing uses existing modal/fields, confirmed removals and atomic Save contract. Reset contractors/personnel only from current source/current contract evidence after full backup; retain fiscal years/types, valid budget accounts/codes/names and every report snapshot. Keep unidentified legacy supervisor text as reference; never regenerate short display aliases as master people. All formats preserve assignments and source keys; source G4 and own compact G4 export both supported. Repeated imports no-op. Browse exports all filtered rows; active selection exports only checked rows, zero selection blocks. Benchmark scope reads/compact writes against full backup, never promise all-browser/device support.

## v12 — approved registry and weekly refinements

Latest owner instruction supersedes history-retention defaults for the one-time cleanup: retain the newest closed report per funding/year and every draft after a private full backup. Preserve every contract and retained snapshot. Store prior entry baselines separately so amendments and carry-forward remain valid. No general automatic history deletion is enabled.

Personnel masters retain current position, filled from authoritative ก-4 only when empty; per-contract position/duty remains independent. Choosing an existing name fills a blank position. Contractor raw source stays intact; canonical names and remembered aliases round-trip in JSON/Excel/CSV. Exact or approved aliases match automatically; fuzzy suggestions require explicit selection, otherwise import a pending name. Verified aliases may supersede a pending raw-name record without merging two verified firms automatically.

Road masters use highway/control/canonical name without a trailing numbered ตอน suffix; original segment text/km/direction remain contract-specific. Searchable combined road selection fills the three identifying fields. Quantity-unit options derive from actual records and do not create a new master tab.

Date is now a shared authored Thai BE calendar backed by bundled Flatpickr with ISO CE storage; no platform calendar popup is used. All modal date workflows reuse this owner. Compact management controls in the read dossier reveal route tools or open the shared personnel editor. Weekly table includes only the primary supervisor (title/given name/ฯ unless a report alias is set), compact alias/date icons, and reference-week expiry for ongoing work after approved extensions. Alias carry-forward and closed snapshots remain isolated.

Performance: scoped reads limit projects/registry to selected funding/year; explicit destination-scope loading precedes file preview. Offline rebase reads active state without cold import history; cached history is deferred and unchanged history is not rewritten. Report validation covers changed report IDs while native constraints/global revision remain. Large registry/personnel workbooks use a module Worker at 200 rows; worksheet parsing yields in batches. Keep four published runtime files; vendor license is recorded. Full backup requires a complete online workspace; offline selected-report export remains available.

## v13 — compact browse surfaces and compatible task writes

Owner approved rectangular horizontally scrollable basic-data category buttons with overflow arrows. The active category stays in view; all 24 people share one บุคลากร category, including inspection and supervision roles. Actual SQL owner is pn2_personnel; legacy relation/JSON keys remain compatibility adapters, never a second person list. Current position is projected into SQL; assignment positions and duties remain contract-specific.

The shared modal has a fixed header and exactly one scrolling .dialog-body; no content may paint above its title. Main-page scrolling remains document-owned. Archive uses a five-column desktop table and three-row mobile records (week/status, Thai Buddhist date range, count/open). Table selection is quiet count/action in browse mode, with explicit all-filtered-pages scope only in selection mode. No repeated instruction paragraphs or organization workspace card. Critical save/offline/error feedback remains; normal ready banners are hidden.

The dossier omits reference/history presentation. Source worksheet coordinates and amendment bodies are absent from normal screen responses, preserved in full backups/import context. Screen reads use native funding/year filters; branding has a separately cached hash-based read. Weekly entry writes update one native entry and the matching document entry, preserving snapshots; linked lifecycle edits retain shared validation. Other delta writes hydrate only changed reports and project changed IDs. Global revision locking and the compatibility document remain intentionally until a separately verified row-version migration. Redundant registry text work links become a derived read view, canonical job/code IDs remain stored. Old empty pn_* tables remain untouched.

### v14
รวมตัวกรองและสรุปในกรอบเดียว ลดหัวข้อซ้ำ ใช้กล่องสีอ่อน ตัวเลขเด่น และเส้นขอบ/เงาบางตามสถานะ มือถือแสดงยอดรวมเต็มแถวและอีกสี่ช่องเป็นสองคู่ ปุ่มดินสอไม่มีกรอบแต่ยังคงชื่อสำหรับเครื่องอ่านหน้าจอและพื้นที่กด หน้าเว็บแยกการแสดงผลตามงาน: ประวัติโหลดเป็นหน้าและเรียกค่าเต็มเฉพาะเมื่อเปิดดู

### v14.1 — consistent weekly controls and search
Weekly controls reuse the registry control frame: period, review/week actions, status cards, search/filter and one selection/count owner. The table panel contains only table/paging. Mobile status cards remain 1 + 2 + 2. Shared clearable search adds a labelled × without changing list/filter ownership or triggering saves. Contractor transfer is the authored searchable-combobox variant: exact/alias text and fuzzy suggestions are choices, never automatic identity changes. Other select/datalist fields remain platform-owned. Contract edit uses a separate opaque dialog footer outside the scrolling body so content cannot show below the action bar; native form association preserves submission and validation.
## v15 — compact controls and source-aware imports

Owner approval on 19 October 2026 supersedes the former listening-only hold. Keep the forest-green institutional identity and existing CSS tokens. Operational tables use a pale green, stronger header, fine column dividers and restrained alternate rows; management is the first visible column with a stable horizontal action group. Main list page size defaults to 10, with 25/50/100 options. Full filtered selection/export scope is independent of pagination. Editable child forms retain their parent/child sequence rather than acquiring a sort that could silently change stored assignment order. Server audit history retains its bounded server cursor.

Dashboard and weekly actions belong to the period control frame: right aligned on desktop/tablet, after controls on phones. Search and Select share a left-aligned row; browse mode has no redundant result-count label. Catalog file/add actions are a separate row above search. Calendar month/year share an aligned Thai BE header.

Weekly name edits use double-click, Enter/F2 and coarse-pointer tap. Remove adjacent pencils; the closed-report row amendment pencil remains only in Confirmation. Contract links use the existing stable project/registry relation and restore the weekly navigation context. Date-dialog initial values prefer the matching current registry per field, falling back to the open weekly report; only explicitly edited fields are saved. Remove the top and preview-wide amendment shortcuts, closed-history explanation and confirmation count, while retaining errors and unsent/conflict feedback.

External file imports use nested source menus: ก-3, ก-3 งบฉุกเฉิน and ก-4; there is no source-export menu. System-format import/export uses the existing typed registry workbook/master CSV roundtrip. The emergency HTML-with-xls extension has separate header and data tables, five header rows and 66 columns; parse inertly, preserve identifiers/dates, map only the established registry fields and set budget account งบฉุกเฉิน. Do not retain refund fields or infer a payment day from a payment month. Source data is evidence only.

Review fingerprints use recursive canonical content, ignore volatile/cold source bookkeeping, accept legacy saved JSON ordering and become stale on genuine data edits. Executive HTML/print, Excel and JPG use the same normalized width array: job ×.8, start/end ×.9, elapsed ×.9, three progress columns ×.8, note ×1.2 relative to the previous raw geometry, then normalize to the unchanged page width. No palette/token or production schema change is required.
## v16 — linked weekly data and content-sized tables

Owner approval in this chat supersedes v15 alignment and action placement. Reuse the institutional palette and typography; no new theme or schema. All list controls align right. Density and Select share one row in that order. Registry search is followed by Import/Export then Add. Catalog file/add commands remain above search, right aligned. Weekly search precedes Preview (ตัวอย่างรายงาน) and New week (รายงานสัปดาห์); filters are initially collapsed behind a labelled icon, with archive using the same disclosure. Archive removes JSON import and report creation.

Management is last and appears only in selection mode. Contract child editors are an explicit exception: always-visible unboxed pencil/trash controls retain accessible labels and confirmation. Expired dashboard contracts open by row double-click/Enter; no management column. Registry combines work code/title and freezes ID Code + contract; weekly freezes contract. Operational columns measure all filtered loaded data, not only the visible page, and allow unrestricted horizontal table scrolling. No truncation or width cap; expiry sits beside title.

Weekly numeric plan/weekly/actual and remarks use explicit double-click, F2/Enter, or touch activation. Escape cancels, blur/Enter saves. Closed edits use the existing audited amendment owner and cumulative reconciliation. Errors preserve pending values. Unfinished work remains before finished work in both fundings, including a chosen secondary table sort.

ReportLinkAudit distinguishes registry total, report entries, filtered rows, missing stable links, duplicate links and unresolved/out-of-scope references. Explicit fill adds only missing contracts to the latest draft, never overwrites existing entries or closed snapshots. A check refreshes only the selected scope and never fetches cold import history. Normal executive preview/export uses all report entries; explicit selection narrows output, filtering alone does not. Province layout measures content independently of the preserved DOH width policy; HTML, Excel and JPG share reportLayout. Printing fits the resulting column proportions onto the selected page; unusually wide JPGs produce an explicit browser-limit error instead of clipping.
## v17 — registry-driven report membership

Explicit latest owner instruction supersedes frozen membership: weekly reports must automatically include all active contracts from their selected funding/year, including formerly closed reports. `synchronizeReport` uses the existing compact audited import owner to append missing entries/snapshots only. Existing entries, snapshots, aliases and notes remain byte-for-byte unchanged. Newly linked entries carry an earlier weekly baseline when available; otherwise progress starts at zero, never source-observed progress. Loading another funding/year is scoped; sorting/searching do not write. Reload/repeat is idempotent; failures retain an inline warning and the heading's link icon opens a diagnostic popup. Keep a private pre-release full backup.

Main lists use Search → Select → Page size in one responsive row, excluding read/edit popups. Desktop/tablet funding/year align left with primary commands right; phones place two primary commands above the funding/year pair. Dashboard adds week as the third mobile row. Weekly primary commands are Preview then Report week, registry commands Import/Export then Add. Weekly funding/year/week are always visible; only budget/type filters collapse. Archive keeps its populated period frame with no empty leftover frame. Registry budget summaries use wrapping equal flexible cards, with full-width total on phones and balanced remaining rows as accounts grow. The heading's unboxed link icon retains an accessible label and tooltip.

## Registry readability refinement
Latest owner request supersedes unrestricted column sizing for the main registry only. Job code and full job title share a bold block; latest progress remains quiet below. Registry sizing clamps job width to 240–360px, contractor to 170–240px and personnel to 240–320px, with wrapping and table-local horizontal scrolling. Names include the assignment's actual duty in parentheses; never infer a missing role in rendering. Shared assignmentDetails remains the identity and duty owner. Popup tables, weekly tables and exports retain existing policies.

## v17.2 executive report-only geometry

Latest correction: province job titles must remain complete on one line. Their measured column width has no upper cap. Grow the document width to fit the longest title instead of taking space from the other columns. Other province columns retain their existing physical widths. Preview scrolls horizontally, workbook uses those physical widths and images grow with the document. Print scales text to fit the page while retaining single-line job titles. This supersedes the fixed 1100px province canvas and capped job column below.
Latest owner request: omit funding-group names from executive headings in preview, print, Excel and image using reportTitle, without changing stored configuration or scope. DOH contract column grows by 7% relative to its prior normalized width; take that small increase from remarks to preserve total width and all other columns. Province columns C–K exactly share DOH proportions; A/B may be shorter when their content permits, and all remaining width belongs to remarks. Province has a stable 1100px document canvas, wrapping rather than unbounded content-driven widening. Shared reportLayout remains the owner for HTML, workbook and canvas. Operational list/table widths are outside this change.

## v18 — report layout studio
The owner requests self-service executive column widths with format previews, test printing, downloads and explicit Save. The shared preview dialog opens “ปรับรูปแบบตาราง”; Settings exposes the same owner for the selected funding. A quiet two-column studio uses existing forest-green buttons, form fields, borders and dialog scroll ownership. On narrow screens controls precede output; its document alone scrolls horizontally. No new UI library, navigation system or database table.

reportLayout is the sole width owner for HTML/print, workbook and image renderer. Current settings.reportLayoutDOH and settings.reportLayoutPROVINCE are independent nullable presets, intentionally taking precedence over historical layout snapshots, but never changing report data or aliases. Each preset stores twelve physical pixel widths (40–3000 each, total ≤18000). The image safety bound explains the upper limit. Invalid imported presets fall back safely. “คืนค่าเริ่มต้น” restores the automatic built-in layout only after Save. “ปรับให้พอดีข้อความ” measures current report data and headers with the bundled font; manual narrow widths may wrap, with a visible warning. The earlier mandatory province job nowrap remains for its built-in layout; an explicit manual preset owns its chosen width.

Draft adjustments and previews have no persistence. Save uses the existing audited mutation/offline/conflict owner and changes only the selected funding key. Preview generation invalidates stale output on edits and releases image URLs. JPG preview is the actual generated file, Excel is an explicitly labelled layout approximation plus actual test workbook, PDF preview uses print rules and A4 landscape with actual pagination available through the browser print dialog. Print preserves the editor. Form errors retain draft values; unsaved exit offers Continue or Discard. Native select and native dialog owners remain unchanged.

## v19 — integrated release and actionable feedback
Owner approval: apply the attached pn_weekly_master_developer_rules_report.md together with the accumulated UI/database defects. Treat its claimed test/deployment state as evidence to verify, not a replacement for repository/runtime inspection. Preserve the existing v18.1 deterministic dates, contractor key index, RFC errors and button locks.

The command frame groups funding/year/week and primary actions. Weekly secondary commands live in a real closed native details menu labelled จัดการ, whose panel is hidden when closed. Existing shared table controls remain Search → Select → Page size → Filters. Weekly confirmation has one owner in selection mode: ยืนยันที่เลือก for drafts; แก้ไขรายการที่เลือก opens the existing single-row amendment form. Remove the old confirmation column. No ordinary historical deletion is introduced.

v19.0.2: scope transitions hydrate the chosen frozen report before validation. Same-scope requests share one pending task; executive preview awaits completion and computes selection from current report rows instead of a potentially stale display cache. Regression covers funding changes with cold snapshots, including a read-only check against actual Supabase data.

Child personnel tables explicitly opt out of sizeOperationalColumns, which previously measured hidden editor text and assigned enormous widths. Their dedicated bounded table layout becomes readable records on narrow dialogs, preserving full names, positions, duties and always-available edit/delete icons. Route editors also opt out of automatic operational text measurement and retain their intentional horizontal table overflow.

operationFeedback is the shared non-blocking feedback popover. While a modal is open it must be a descendant of that modal to avoid inert controls, and moves back to body when the modal closes. Success draws a check mark and dismisses after 3.5 seconds; error remains until dismissed and provides cause/fix, preserving drafts. Safe form failures offer retry; ambiguous network completion instead directs verification before retry. Loading is delayed 350 ms to avoid flicker. Download percentages use actual stream bytes only when an uncompressed Content-Length is known; otherwise show indeterminate progress. Never invent elapsed-time percentages for server work. Reduced motion disables animation. Input focus is retained during inline autosave.

Database release compatibility is explicit: pn2_release_compatibility reports the current write contract. The new additive migration repairs legacy writes into the read-only work-links view, restores scoped native projections, batches the five specified master/extension paths and hydrates only touched historical snapshots before amendments. schema.sql and the ordered migration path must both finish at this contract. Without CLI secrets the pipeline verifies the connector-deployed contract; it cannot silently skip database readiness. Never repair an unknown migration as applied after an arbitrary SQL error.
## P.3-01 asset register — v20

Thai highway accounting staff prepare an official asset ledger after acceptance and disbursement. Retain the existing forest green shell (#145d47), white paper (#ffffff), text (#173a32), muted text (#526b62), and borders (#d9e3dc). Tahoma/Noto Sans Thai remain application typography; the bundled TH SarabunPSK owns the official form. The distinctive element is the complete fiscal depreciation ledger rather than a second progress dashboard.

Canonical owners: funding/year uses periodBar/ensureScope; main ledger uses shared search/selection/page-size, guarded mutation queue, RFC problem feedback, Thai date picker and explicit modal close. Bounded wrapping in the new asset ledger is intentional, consistent with the owner request to avoid excessive registry width. Primary form settings/year export join scope controls (actions first on mobile). Master depreciation rules live on workCodes; per-contract p301 stores overrides only. Native pn2_p301_records is a projection, never a second contract authority. Unknown work-code rules require user classification. Missing contacts remain empty. Acceptance date and actualCost are the confirmed accounting sources.


## v21 — owner PDF and highway asset history
- Latest owner examples supersede v20 presentation: P.3-01 has 12 columns including a separate unit-price column. Acquisition date stays in column 1; signed date and calculation period belong in document column 2. Repeat the full heading, metadata and acquisition row on continuation pages; signatures only on the final page. Preserve the approved depreciation formula and 1-baht residual.
- PDF and PNG derive from one vector page model; XLSX uses the same pagination and records, editable cells, explicit page breaks and repeated blocks. Use named print pages without changing executive report sizing. Validate rendered PDF page count, not only document model count.
- P.3-01 width presets are independent by funding source. Five-column asset-history presets are also editable, by the selected funding/all scope. Save through the existing mutation/error/locking owner.
- Selection mode buttons read จัดการ; checkbox semantics and เลือกทั้งหมด remain. Existing main-table search → management → page-size order stays; modal editors are excluded.
- Highway asset identity is the exact highway/control pair with leading zeros preserved. Native indexed links project existing segments transactionally inside the protected save chain. Read-only pn2_load_asset_history supports all years; no new standalone write RPC or broad grants. Preserve contract/project/report/entry/snapshot keys.
- History deduplicates contracts with several matching segments, unions overlapping kilometer intervals for centerline distance, and shows unknown data explicitly. Never allocate total contract money/quantity to one of several road assets without evidence. Cost is actualCost; acceptanceDate is the event date. Missing contacts remain blank. Offline history must identify its incomplete cached scope.

## v22 — form studios, source rules and mobile records
The weekly report title, actual example week, widths and preview now belong to one ตั้งค่าแบบฟอร์ม dialog immediately after preview. Editing updates the paper after a short debounce; saving applies the funding-specific title and layout together. System Settings retains branding and backup configuration. The P.3-01 studio follows the same structure and keeps signers on paired rows. Both studios isolate DOH and PROVINCE settings. Pending assets may preview real metadata with blank amounts; they cannot print an invented schedule.

P.3-01 metadata values are centered within their own dotted fields, labels remain left aligned and underline baselines are consistent across vector exports. Excel stays editable:36 physical columns support12 logical columns and independent label/value merges, point-sized fonts, row heights, manual page breaks and native vector checkbox shapes. The print page model is shared with PDF/PNG. Long multi-route acquisitions shrink description text down to10px and then continue onto additional pages while preserving every segment and financial row; signatures appear only on the final page.

The depreciation reference catalog retains the user Sheet's84 source rows,35 category mappings and source group boundaries. Matching is exact by code and never fuzzy. Feature keywords override lifetime only for the explicitly approved codes; unmatched features use MAX numeric source life, annual rate100/life rounded to2 decimals. Old manual rules remain available only for codes absent from the source. This intentionally updates the earlier provisional v20 defaults. The source Sheet is unchanged.

Operational tables at≤640px become label/value cards, preserving edit and management controls. At larger widths native tables/pinned identity columns remain. Report pages and modal child tables keep their own layout. Dashboard filters and actions share a padded, balanced frame; mobile places actions before funding/year and week. Touch input font16px,44px controls, nowrap KPI figures and device safe areas prevent zoom, clipping and obscured actions.

## v23 — confirmation, fiscal day basis and official work hierarchy

The weekly status strip states draft/archived and the confirmed count. Confirmation opens a result dialog with a direct archive action. The shared archive preflight groups all issues by contract and opens the canonical date/entry editors. Only validated snapshots enter the archive.

The registry form adds native cascading selects for budget abbreviation, PDF project, activity and code. This assists the existing work-code/title fields; original titles remain editable. A code offers its documented quantity units. Read dossiers show the reverse path and the depreciation code. Basic-data reference tabs place depreciation next to roads and the code catalogue. The catalogue includes source pages and supports explicit budget association; associations inferred from matching current contracts are distinguished from manually added ones. PDF work taxonomy is not claimed to establish undocumented PLANNET bureau/programme assignments.

P301 dayCountMethod is actual/365/366. Actual uses inclusive partial-year days and each Thai fiscal year's actual denominator; whole fiscal years are one annual depreciation charge. The last charge reconciles to one baht. Existing configured records use365 until changed; new ones actual. Metadata dotted lines lie2px below the glyph baseline; values center after their label. Description columns have an18px inset. Fonts use the bundled TH SarabunPSK glyph advances when no browser canvas exists. XLSX remains editable native cells with merged metadata fields, dotted borders and check shapes.

Database: pn2_work_catalog_nodes stores an explicit parent tree with source edition/pages; duplicate code20000 has distinct node identities. pn2_work_catalog_budget_links stores observed/manual associations. pn2_registry_work_classifications joins contract, account, leaf, project, activity and P301 code; existing asset-route links provide the road/control-section relationship. All are projections of the existing audited JSON/RPC owner and preserve original primary/foreign keys and historical snapshots.


## v24 — shared record reading and375px audit

Keep the forest-green/paper palette and existing font/spacing tokens. The owner requested the375px baseline on all operational surfaces, without changing official report layouts. `mountResponsiveRows` and `.mobile-records` now extend cards to masters, P301, asset history, audit/reference and modal child summaries below640px; desktop native-table density remains unchanged. `mountRowDetails` gives desktop double-click/keyboard and a mobile “ดูรายละเอียด” action one read owner. Preserve inline edit gestures, explicit modal closing, parent form state and canonical edit/delete handlers. Reference/history actions stay honest about read-only data; work-catalog budget linking remains an intentional editable relationship.

Metadata labels in P301 are never ruled underneath. `p301MetadataFields` measures each label and begins the value's dotted rule after it, shared with PDF/PNG/nativeXLSX. Keep seller label continuous and values centered. Source columns are hidden in reference lists without removing stored evidence. Master file menus have direct system import/export only. No new colors or persistent data fields are introduced.
