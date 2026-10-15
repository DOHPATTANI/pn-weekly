---
version: alpha
name: "PN Weekly"
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

# PN Weekly design and behavior contract

## Overview

Product/admin surface for one Thai highway officer preparing weekly management reports. The user-approved v7.4 redesign uses a forest-green navigation shell, brass accents and paper-white operational surfaces. The visual reference is highway operations and Thai institutional documents; these palette choices are not a claim of official brand specifications. The report itself follows the supplied institutional table. The archive is a chronological register rather than a dashboard of cards. Avoid repeated actions, decorative tiles and unnecessary status columns.

Authoritative business decisions are the user's requests in this chat and the installation/user manual. The user explicitly chose one shared workspace without login and direct historical editing without reason or extra confirmation. Older v3 immutable-history behavior is superseded through the audited amendment workflow; silent wholesale overwriting is still rejected.

## Colors

Runtime CSS in styles.css is canonical. This document records the existing variables: primary --green, text --ink, muted --muted, background --bg, border --line; website lifecycle colors --delivery-ink and --payment-ink. Paid red is retained in webpage and exported rows. Green awaiting-delivery and blue awaiting-payment are scoped to #app. Exported detail rows otherwise stay black. Summary colors follow the source report. Status text accompanies colors.

## Typography

Thai locale, Bangkok business timezone, Buddhist years in display, Gregorian YYYY-MM-DD for storage. Native date/select/datalist popups are intentionally platform-owned. Tahoma is the deterministic offline fallback. No Japan-market behavior applies. Archive cells are 14px with 1.6 line-height; labels use 12px. Report fonts remain smaller to fit A4 landscape.

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
| Select/Listbox | selectField + native select / native datalist | DESIGN.md + runtime owner | platform-owned; search/create is datalist plus semantic button | Chrome create/select flow, DOM relation test |
| Date | field(type=date), validateDates | DESIGN.md + runtime owner | native browser calendar, date-only storage | DOM/DB lifecycle ordering and Chrome fill/save |
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
