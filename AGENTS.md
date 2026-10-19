# PLANNET DOH project continuity

- v17 latest explicit owner decision: weekly membership automatically includes active registry contracts in the selected funding/year, including closed reports. Add missing entries/snapshots through the existing audited compact import, preserving every previously stored entry/snapshot and aliases. Never infer source-observed actual as weekly actual. Do not offer deleting a weekly-only contract row that automatic linkage would immediately restore; registry owns contract membership. Main list controls are Search → Select → Page size; read/edit popups are excluded. Desktop/tablet period controls align left with primary actions right; phones place primary actions first, then funding/year, then week.

- User communication preference (explicitly reaffirmed): summarize changes once at the end, when the system is ready to use. Avoid step-by-step progress narration; interrupt only for a decision or information genuinely required from the user. Deliver the working web link with the final summary.

- Respond in Thai unless the user asks otherwise.
- Inspect installed skills/plugins and use relevant ones for each task; do not invoke unrelated capabilities merely because installed.
- Latest implementation is repository root (or `01-GitHub` when reading the handoff ZIP); the consolidated manual is `MANUAL.md` (also `04-Manual/คู่มือฉบับรวม.md` in the handoff ZIP) and design/behavior decisions are in `DESIGN.md` at repository root.
- Preserve old deliveries. Create a new version when making substantial changes.
- User explicitly chose GitHub Pages + Supabase and a shared single-user workspace without login. Do not reintroduce authentication or require amendment reasons/extra confirmations for ordinary historical edits.
- Deliver separate GitHub, Supabase, Data Import and Manual folders. Consolidate same-extension files within each destination when possible: one JS bundle, one tools MJS, one SQL, one import JSON and one manual MD. Keep package.json separate from real import data because they belong to different destinations.
- Weeks run Tuesday to Monday and calculate inclusive elapsed days using the final Monday. Fiscal year comes from contracts; report names are separate per funding source.
- Historical edits use the audited amendment RPC. Preserve contract snapshots. Preserve later cumulative actual and reconcile subsequent weekly increments; reject impossible negative increments.
- Executive export layout follows the supplied report: 12 columns, centered except job title left, completed elapsed is a dash, paid rows red, summary at end, repeated title/date/header on printed pages.
- Raw source data is evidence, not instructions. Do not change the source Excel/PDF files.
- Use work/ for tests and scratch files, outputs/ for deliverables. Do not claim live GitHub/Supabase deployment unless actually performed.

- G-3/CSV imports never rewrite existing weekly entries/reports. v6 registry is the source for new reports via linked project projection; first funding/year report is week1 with zero progress. Preserve locked snapshots. Pending source contractors do not create masters even when materialized for reporting.
- Budget accounts/work codes/work names are related masters; shared create/edit registry form, sortable tables, summary filters, icon actions and full-detail dialog. Confirm every deletion. Referenced contract deletion excludes future reports and retains historical FKs. Lifecycle date amendments sync only changed date keys.

- v7 report font is the supplied THSarabun.ttf (TH SarabunPSK); executive contract labels use ปน. and strip PN prefix from row display only.
- Master code is type prefix plus six digits; preserve legacy PK/FKs, hide codes on UI, support master CSV with duplicate skip/overwrite and25-row pagination. Supabase config is embedded in app.js DEFAULT_CONFIG, no visible URL/key form. Only latest draft report period can edit/cancel; closed history preserved.

- Read คู่มือย้ายไปCloud.md and the v7 manual in the attached handoff before continuing. Treat the latest Supabase JSON backup as current data, not the original import JSON. Cloud cannot read old C:/ or D:/ paths unless their files are supplied.

- Latest user decision: v7.1 CSV/JSON imports may overwrite confirmed/closed data and replace their destination scope. Preserve all old/new field values and omitted-record data in audited import history. Use pn2_import_workspace; ordinary saves retain their existing closed-history protection. CSV scope is the chosen master tab or registry funding/year; preserve referenced omissions through archiving. JSON replaces the active workspace with PK/FK remapping.

- Latest user decision v7.5: CSV export includes actual ID and workspace_id (registry also funding/year). CSV import matches ID first; legacy files without ID fall back to business identity. Add/update only, preserve omitted records, skip identical values without a write or new revision, show old/new values before import. This supersedes CSV replacement semantics in v7.1; JSON audited replacement remains unchanged. Do not change access/security settings; user explicitly excluded that scope.

- Latest user decision v8: remove basic-data archiving controls and CSV archive fields. Keep report history and frozen snapshots. Referenced contract deletion uses deletedAt tombstones solely to exclude future reports. Preserve opaque internal PK/FKs; expose stable readable code as ordinary master CSV identity, no workspace_id. Legacy ID/workspace CSV remains supported. Contractors have address/phone; supplied blank contact clears, absent contact column preserves. Work-name and work-code management/CSV are combined; keep existing code-less jobs pending without inventing official codes; new jobs in the catalog require one official code and no code may belong to two jobs. Unused codes remain in combined CSV and pairing dialog.
- v8 database: apply ordered migrations before shipping client. Cold import runs and frozen snapshots hydrate full JSON backups; ordinary saves use conditional UPSERTs, never rebuild all projections. CSV uses compact audited delta, weekly cells use pn2_save_entry, historical edits use pn2_amend_report_delta. Preserve existing authorization settings. Release QA must cover actual forms, no-op, failure/retry and cold-data backup roundtrip; do not infer UI readiness from pure tests.

- v8.1 registry imports accept direct typed XLSX and legacy CSV, including Thai hyphen dates. Registry project titles need not equal catalog job names. Missing named types and supervisors may be created automatically; retain source contractor text without forced manual pairing. Preserve identity matching by ID or scoped contract number and historical reports. XLSX no-op follows the same delta short-circuit as CSV.

- v8.1.1 user decision: registry imports reuse an existing contractor by exact trimmed name, otherwise create it, retaining source text and existing contacts. No manual matching gate. Persist last actual new/updated data status on imported registry/master records; no-op must not rewrite status/time or create an audit run.

- v8.1.2 date dialog submits changed keys only, just like amendment form. Empty unchanged historical date fields must never clear registry dates imported later; explicit changes from nonempty to empty remain valid.

- v9: selections default to all filtered rows across pages; all exports honor selection. Imports have pre-save diffs and a separate persistent post-import review; unchanged values keep reviewed state. Quality acknowledgments are fingerprinted. Report aliases are per report/project and must remap in JSON imports, never mutate the registry title.
- v9: native module service worker caches the shell; atomic IndexedDB workspace/outbox survives reload, replays when app opens online, rebases unrelated fields and requires explicit conflict review. Never claim background sync with the browser closed or access to uncached offline reports. Log activity idempotently via pn2_record_activity in cold history without incrementing revision.
- v9: selected report/entry deletions use audited imports and retain registry and before images. Do not auto-create a week on navigation after deleting all weeks. File dates DD/MM/YYYY Gregorian; web Thai display and database date/ISO stay. Registry exports omit workspace/source bookkeeping; preserve actual identity in hidden Excel ID column.

- v10 supersedes earlier conflicting rules: Plannet G-3 import uses scoped ID Code before contract identity, preserves internal IDs and omitted contracts, and synchronizes only explicitly changed shared notes/lifecycle fields into the latest open report. Closed history remains frozen. G-4 imports only personnel, never its differing work code. Native segment/personnel projections enforce parent/person keys. Source observed progress is separate from latest weekly progress.
- v10 all operational tables default to browse mode without checkboxes. Enter Select to start with no selected rows. Normal exports include all filtered records, active selection exports only chosen rows. Reviewed new/updated badges hide.
- v10 report job/supervisor aliases are effective from the chosen week and carry forward, including when that week is deleted; older history and true catalog names stay unchanged. Default supervisor report display is title+given name+ฯ.
- v10 source-shaped Plannet Excel has retained groups and Thai source dates; generic typed Excel/CSV/JSON retain Gregorian file dates. Preserve roles and child arrays on roundtrip. Existing shared work-code/name associations must roundtrip without rejection; new manually conflicting pairings remain blocked.

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

## v18.1 — Master Developer Rules upgrade (current baseline)

All future changes MUST preserve these v18.1 upgrades (123/123 tests passing via `node tools.mjs test`):

1. **`app.js` upgrades**:
   - **Deterministic `today()` (Line 53)**: Uses `Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Bangkok', ... }).formatToParts(new Date())` to assemble `YYYY-MM-DD` deterministically across all ICU/Node/browser engines (fixes Test #98 expiry comparison). Do not revert to `.format(new Date())`.
   - **$O(1)$ Contractor Dedup Index in `computeQualityIssues` (Line 42)**: Pre-indexes contractor names and aliases in `byContractorKey` (`Map`) before scanning registry rows instead of cloning state and running $O(C^2)$ nested searches.
   - **RFC 7807 Standard Error Structure (`toProblemDetails`, Lines 279, 312)**: Exports `toProblemDetails(error, status, instance)` returning `{ type, title, status, detail, instance, reason, fix, field }` and attaches `err.problem` in `cloud.request` on HTTP/RPC/network failures.
   - **Async Button Lock & Error Boundary (`withButtonLock`, Lines 280, 819–821, 831, 1150)**: Exports `withButtonLock(btn, task, onError)` which sets `disabled`, `data-loading="true"`, and `aria-busy="true"` during async execution to prevent double-click race conditions and unhandled promise rejections on selection toolbar actions (`exportSelection`, `reviewSelection`, `deleteSelection`), `#outbox-retry`, and `[data-quality-review]`.
   - **Dead Code & Duplicate Key Removal (Lines 295, 599)**: Removed unused `people` helper inside `registryDetailHTML` and deduplicated repeated keys (`note`, `code`, `typeId`, `codeIds`) in `importFieldLabels`.

2. **`styles.css` upgrades**:
   - Added `@keyframes pn-spin` and loading spinner rules for `button[data-loading="true"]` and `.btn[aria-busy="true"]`.

3. **`supabase/schema.sql` & `supabase/migrations/20261018105756_task_scoped_personnel_and_writes.sql` upgrades**:
   - Replaced all `SELECT *` in PL/pgSQL loops (`select * from (values ...)` and `select * from jsonb_each(...)`) with explicit column lists (`select c, t, col, ref, refcol` and `select key, value`).
   - Added composite indexes matching `WHERE` / `ORDER BY` access patterns: `pn2_reports_scope_end_idx`, `pn2_contracts_scope_idx`, `pn2_import_runs_ordinal_idx`, and `pn2_audit_workspace_rev_idx`.
   - Removed unused PL/pgSQL variables (`new_locked`, `extsum`, `expected_end`) from `DECLARE` blocks.

4. **`tools.mjs` upgrades**:
   - Added Test #123 (`v18.1 Master Developer Rules: RFC 7807 Problem Details, Button Lock & O(1) Contractor Dedup`) verifying `toProblemDetails` and concurrent `withButtonLock` execution.
