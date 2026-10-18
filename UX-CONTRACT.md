# PLANNET DOH operational UI contract
Business sources: AGENTS.md, DESIGN.md and explicit owner decisions recorded in work/v9/requirements.md. Runtime remains a single maintained module.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Table Selection | mountSelections / tableSelections | DESIGN.md v9 | all filtered pages / explicit rows | tools.mjs browser QA |
| Select/Listbox | selectField, native select and datalist | DESIGN.md | native browser popup | desktop/mobile browser QA |
| Date | bindThaiDates/openThaiCalendar with bundled Flatpickr, parseG3Date, fileDate | MANUAL.md date rules | authored Thai BE popup / Gregorian storage | keyboard, year/month/day, workbook and DB tests |
| Form | field, modal, commitCSVForm | DESIGN.md | create/edit/import/review | success/failure/retry browser QA |
| Scrollbar | styles.css document baseline | DESIGN.md | table-scoped overflow | narrow viewport QA |
| Toast | initializeUI toast | DESIGN.md | success/error; persistent sync banner | browser QA |
| CRUD | mutate, audited imports, amendment RPC | AGENTS.md, server validators | online / durable outbox | database and browser QA |

Do not clear stored work on failed saves. Persist offline queue and workspace together; reconnect conflict is a review state, not automatic overwrite. Deletions always confirm selected objects and preserve an audited before image. Routine edit and review commits do not require redundant permission dialogs.

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

## v13
Same shared owners above. Modal header never scrolls; .dialog-body owns content scrolling with clipping. Basic-data categories use native buttons, rectangular selected state plus visible overflow arrows and keyboard focus. บุคลากร shows both role groups without copying identities; old supervisor CSV headings and JSON keys remain accepted.
Archive desktop cells become compact mobile rows with stable named cell classes, independent of injected selection checkboxes. Count/Select toolbar is shared across all operational tables, selection scope remains all filtered pages and zero selected blocks bulk actions. Normal ready text is hidden; busy/error/offline/outbox states persist.
Cold reference fields are omitted in the dossier and screen payload, not deleted from import evidence. Imports explicitly load complete destination scope before comparing rows. Full JSON restores and all exports retain established business fields and historical snapshots.

## v14 — focused controls and shared references

- Registry controls share one frame: funding/year, total and budget-account cards, search and a single result/selection toolbar. The table is separate; committee follows contractor. Weekly status cards retain expiry as a subset of ongoing work. Mobile uses 1 + 2 + 2; desktop adapts horizontally.
- Weekly title/contractor/supervisor double-click, Enter/F2 or a quiet pencil opens an inline report-only alias with master suggestions. Enter/blur saves; Escape cancels. Registry names remain canonical; aliases carry to later weeks. Executive remarks equal the weekly note, including blank.
- Shared contractor renames propagate by stable ID across all current years. Explicit transfer previews all years before moving references and removing the duplicate. A conflicting imported alias never blocks choosing a canonical contractor; no fuzzy automatic merge. Closed snapshots/source text remain unchanged.
- Bulk master deletion checks every active reference atomically, including secondary personnel and road segments. Referenced contractors offer transfer; no silent cascading master deletion.
- Roads share basic-data navigation. Search replaces the duplicate category title. Dossier pencils sit beside section headings, with labels/tooltips and usable hit areas.
- Audit opens 25 changes per request; large values are abbreviated and retrieved explicitly. Full-history export remains explicit. Save errors retain input and explain cause/recovery; normal connection indicators stay hidden, exceptional unsent/conflict warnings remain visible.
- Default year is the newest populated registry year. Existing offline identifiers are retained during the PLANNET DOH rename.

## v14.1 — search, overlay and report consistency

- `bindClearSearches` owns clear icons for list searches and searchable datalist fields. Show × only when populated; clear through the existing input/change owner, preserve remaining filters and return focus. Clearing a chooser invalidates its selected ID. It never saves or creates a record.
- `searchableContractorField` / `bindContractorChoice` is the authored Select/Listbox variant for transfer only. Filter locally by canonical/alias names; offer existing fuzzy suggestions. Arrow keys navigate, Enter selects, Escape closes the list before closing the dialog, Tab exits. Typed text alone cannot authorize a transfer. The chosen stable ID and full name must be explicit.
- `mountContractFooter` is the contract-form dialog variant. Body alone scrolls; footer and header are outside its clipping boundary. Footer buttons retain the contract form via native form association. Errors preserve input, focus the field and remain visible in the footer; submission blocks duplicate save/close as before.
- `arrangeWeeklyControls` reuses period/summary/filter/review fragments in the registry control frame. Weekly selection mounts in this same frame; count has one owner. Entry-only autosaves regenerate the same heading-free status-card fragment. The table keeps its own horizontal scroll and pagination. Empty report behavior remains unchanged.
- Executive remarks use `reportValues` without per-export substitution, including paid rows and blank notes. Excel may convert the date columns to BE formatting but cannot replace the remarks cell with payment date/status. HTML/print, image and Excel share the saved weekly note for the selected report.
## v15 approved interaction changes

Business authority: owner decisions in this chat on 19 October 2026. `tableSize`, `tableSorts`, `mountTablePresentation` and `mountReadTables` extend the existing native-table and selection owners. Primary lists paginate their complete loaded scope before rendering; selection/export remains across all filtered pages. Selection begins empty and its count appears only while active. Catalog actions appear above Search/Select. Management buttons stay in a non-wrapping first visible column. Report documents and row editors retain their structural header/child grouping; audit keeps its server cursor.

`fileOperationsMenu` exposes source and system branches, collapsed by default. Source import has no export button, and emergency data maps to งบฉุกเฉิน without refund fields. HTML spreadsheets are parsed inertly from content signatures and span-aware multi-table grids. Existing validation, preview, stable identities, no-op semantics and audited compact persistence remain authoritative.

Weekly text edits use double-click or Enter/F2; coarse pointers may tap. Row amendment uses the Confirmation pencil and existing audited dialog. Clicking the contract number opens registry details using the stable relation, with the weekly context retained for return. Date defaults prefer registry values per field; opening/canceling never mutates data and only changed fields save.

`changeFingerprint` owns recursive canonical review identity. Cold source coordinates and bookkeeping do not invalidate review after a screen reload, while real field edits do. SQL backup/screen-reload verification is required for this flow. All executive renderers share `widths` and `reportValues`, including exact saved remarks. Calendar BE presentation never changes underlying ISO CE dates.
