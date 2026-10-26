# PLANNET DOH operational UI contract

v17.2.2 latest owner priority: province executive job titles must never wrap or clip. reportLayout measures the longest title with the bundled font and expands that physical column and document without a width cap. Preserve other columns' physical widths. Preview scrolls, workbook maps absolute pixels, canvas expands, print scales the type to fit. This supersedes the fixed-canvas/capped job-width rule for province reports only.
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

## v16 owner-approved changes

Source: explicit owner instructions and start/resume approval in this chat. `mountTablePresentation`, `sizeOperationalColumns`, `pinIdentityColumns` and `mountSelections` remain shared table owners. Management is rightmost and hidden outside selection; child contract editors retain visible icon actions. `disclosureFilters` owns weekly/archive filter visibility. Density precedes Select. All frame controls align right; registry commands follow Search as Import/Export then Add.

`reportLinkAudit` performs read-only identity/scope comparison; `fillMissingReportContracts` adds missing rows only in the latest draft through existing compact audited mutation. Do not rewrite existing weekly data, infer source progress as weekly progress, or auto-repair historical reports. `selectedReport` narrows only for explicit selection, never merely because a status/search filter is set. `submitWeeklyEdit` routes closed edits through `saveAmendment`, preserving server validation and subsequent-week reconciliation. Numeric/remarks double-click uses the same draft/error owner as ordinary entry edits.

`reportLayout` isolates province auto-measured dimensions from unchanged DOH document widths; operational table widths are separate from document layout. Both funding sources keep unfinished rows first. Browser and SQL-copy tests must verify fill idempotence, frozen-history preservation, closed amendment, scope counts and province exports. Audit history retains server paging; ordered child editors retain parent/child grouping.

## v17 — automatic linkage and revised control rows

Authority: latest explicit owner instruction in this chat to always populate weekly membership from scoped registry. This supersedes v15/v16 closed-membership restrictions only for additive links. `fillMissingReportContracts(...,{automatic:true})` adds missing entries and, for closed reports, new snapshots. It does not replace existing entry/snapshot values. `synchronizeReport` persists through compact audited import, does nothing on repeat, and loads only selected scope. Default helper mode still guards manual draft-only operations. Do not infer source progress as weekly progress. A private backup precedes publication; actual SQL-copy/reload tests cover closed additions and prior baseline carry-forward.

The shared table presentation owner moves the existing search primitive into Search → Select → Page size; popup controls stay unchanged. Period bars own always-visible scope at left and primary commands at right on larger screens, with actions first on phones. Weekly disclosure contains budget/type only; archive period stays visible. Link diagnostics are accessed via an unboxed heading icon, not another command-row button. Existing delete, validation, calendar and offline primitives remain authoritative.

Registry list refinement: show assignmentDetails names with stored duty in parentheses for inspection and supervision. Readable wrapping replaces unbounded column growth in this list only. Preserve sticky identity columns, selection, sorting, full values, details and export semantics.

Latest owner popup decision: the shared #modal never dismisses from backdrop clicks or native cancel/Escape. Explicit Close, Cancel or successful Save buttons retain their existing ownership and busy-state guard; form input must survive outside clicks. This applies consistently to all read/edit/import/report popups.

Weekly inline performance: successful closed-cell amendments use the same audited save owner with a row-refresh option; they must not rebuild the entire table or discard a second active cell editor while a previous cell saves. Drafts, error/retry, serialization and subsequent-week reconciliation remain unchanged. Repeated double-click on an already unlocked field must not reset its original value or selection.

v17.2 report-only owner decision supersedes province unbounded auto-measure: middle nine executive columns use DOH proportions and remaining province width goes to remarks. reportTitle removes funding labels from headings across renderers; report membership/configuration/snapshots are preserved. DOH contract gets a relative 7% increase with a matching remarks reduction, leaving the page width and other columns unchanged.

## v18 report layout studio
Source: owner request in chat, 19 October 2026, including explicit independent DOH/PROVINCE presets. Entry: executive preview → ปรับรูปแบบตาราง, or Settings for the current funding. Reuse modal/commitCSVForm/mutate; reportLayout owns all output widths; exportImages has a collect-only mode shared by preview and download. Drafts never write. Save touches one settings key, applies to that funding's past/future exports, and does not mutate snapshots/entries. Unsaved close is explicitly guarded; backdrop/Escape behavior remains unchanged. JPG preview uses actual blobs, Excel preview discloses application-dependent rendering, and PDF test-print uses the browser for pagination/save-to-PDF. Failure/retry, input boundaries, cross-funding isolation, reload persistence, default reset, all formats and 1500/900/390 viewport checks are required evidence.

## v19 confirmed requirements and owners
Source: user chat on 20 October 2026 and attached Master Developer Rules report. Existing record/date/import/security owners remain unchanged. finishCommandLayout owns the compact command-frame variant; confirmWeeklySelection uses the audited mutation owner and selected stable project IDs. No confirmation column. Historical form remains accessible via selection edit and inline cells. Personnel editor layout excludes the operational measurement owner. operationFeedback extends the existing toast/form/request owners, with modal-aware top-layer placement, genuine/indeterminate progress, persistent errors and safe retry. Database migration compatibility is verified before Pages deploy; neither prior snapshots nor registry membership is reset.

## v21 — owner PDF and highway asset history
- Latest owner examples supersede v20 presentation: P.3-01 has 12 columns including a separate unit-price column. Acquisition date stays in column 1; signed date and calculation period belong in document column 2. Repeat the full heading, metadata and acquisition row on continuation pages; signatures only on the final page. Preserve the approved depreciation formula and 1-baht residual.
- PDF and PNG derive from one vector page model; XLSX uses the same pagination and records, editable cells, explicit page breaks and repeated blocks. Use named print pages without changing executive report sizing. Validate rendered PDF page count, not only document model count.
- P.3-01 width presets are independent by funding source. Five-column asset-history presets are also editable, by the selected funding/all scope. Save through the existing mutation/error/locking owner.
- Selection mode buttons read จัดการ; checkbox semantics and เลือกทั้งหมด remain. Existing main-table search → management → page-size order stays; modal editors are excluded.
- Highway asset identity is the exact highway/control pair with leading zeros preserved. Native indexed links project existing segments transactionally inside the protected save chain. Read-only pn2_load_asset_history supports all years; no new standalone write RPC or broad grants. Preserve contract/project/report/entry/snapshot keys.
- History deduplicates contracts with several matching segments, unions overlapping kilometer intervals for centerline distance, and shows unknown data explicitly. Never allocate total contract money/quantity to one of several road assets without evidence. Cost is actualCost; acceptanceDate is the event date. Missing contacts remain blank. Offline history must identify its incomplete cached scope.

## v22 accepted evolution
- Weekly primary actions: ตัวอย่างรายงาน → ตั้งค่าแบบฟอร์ม → รายงานสัปดาห์. The form studio includes title, actual week, widths and live preview; latest report by default, independent per funding. System Settings no longer duplicates report controls.
- P.3-01 ตั้งค่าแบบฟอร์ม combines defaults/signers and table layout. Name/position pairs share a row. Acceptance is the hidden default date source; explicit contract overrides remain. All-year PDF ignores row selection and uses complete online data; incomplete records are disclosed.
- Metadata value centering/dotted baselines and Excel native editable cells follow the supplied official form. Large acquisition text may continue across pages rather than clip; financial rows appear once, signatures at the end.
- Operational registry/weekly/project tables use labeled cards at≤640px, native tables above640px. Official report tables and edit/view child tables are excluded. Touch fonts16px/targets44px, safe-area footer and nowrap KPI values are canonical. Resize restores table sizing and pinning.
- ข้อมูลพื้นฐาน → ตารางค่าเสื่อมราคา is a read-only paginated reference to the verified source rows and groups; code-linked rules update life/rate automatically from recognized feature text.
- v22.0.1 scope readiness: settings/preview waits for the current funding data, including an immediate click during a scope change. Blank/empty previews require a genuinely empty resolved dataset.

## v23 accepted evolution
- The canonical modal/field/native-select/date/button-lock/save queue owners remain. New catalog references are buttons in the existing master tab row. No second date picker or persistence engine.
- Confirmation reports confirmed count and an explicit draft state. Archive preflight lists all actionable causes and uses the existing editors. Failed/queued writes never claim that the report is archived.
- Registry selects cascade budget abbreviation → PDF project → activity → code and offer relevant units. Missing budget links remain visible and editable, not guessed. Dossiers show the reverse hierarchy.
- P301 configured records default365, new records actual fiscal days; choose365/366 explicitly when needed. Each save stores the chosen basis. Model/spec defaults '-'. PDF/PNG share vector baselines and18px description inset; native XLSX retains editable fields and uses the bundled font metrics.

## v24 — mobile cards and shared row dossiers

### v25 HTML reference evolution

Source: owner's23October2026 request and uploaded `plannet_doh.html`, with explicit exception for the current dashboard band. The operational shell adopts emerald/gold navigation, frosted topbar and tinted summaries; existing record/save/error/import/export owners retain behavior. Counts use actual scoped records. Demo data and destructive browser-storage bootstrap from the reference are excluded.

Dashboard removes its week selector and secondary preview command; it uses the latest actual report for the chosen funding/year. Weekly/archive continue to expose historical periods and existing preview/form settings. Default50project/registry rows accommodates42contracts in one page. Thai labels wrap in their owned region. Official report tables/PDF/Excel/image renderers keep their independent styles; theme additions use screen media only.

Authority: owner's pending requirements after v23 and explicit start instruction in this chat. `mountResponsiveRows` extends the native table owner to operational tables in the app and dialogs. More than3columns become labeled cards below640px; print/preview documents are excluded. Identity/status lead the card, other facts/actions remain readable without horizontal swiping. Coarse-pointer controls use44px targets, while mouse layouts remain dense. Mobile fields use16px type and semantic keyboard/autofill/enter hints. KPI numbers remain together with a30px font cap; fixed/sticky footers reserve content and safe-area space.

`mountRowDetails` owns double-click and keyboard reading; interactive fields retain their own gestures. A mobile ดูรายละเอียด button reaches the same dossier. Edits/deletions delegate to existing mutation, confirmation and scope owners. Nested detail close restores the parent's exact DOM, input values, handlers and scroll; backdrop/Escape retain the existing explicit-close policy. Read-only reference/audit data and automatically linked weekly membership explain unavailable actions. Weekly dossier facts come from the chosen report snapshot/entry.

`p301MetadataFields` is the common label/value geometry owner for vector/PDF/PNG and native XLSX. Labels never have underlines or dotted rules; value rules start after measured label width. Preserve exact seller wording ชื่อผู้ขาย/ผู้รับจ้าง/ผู้บริจาค. Master-data menus use direct system นำเข้า/ส่งออก actions. Source columns are hidden on both reference tables without deleting stored provenance. Database23contract and all persistence/history semantics stay unchanged.

## Collapsible Sidebar (v26.0.1)

Canonical owner: src/sidebar.js + static index.html shell; runtime tokens in src/cascade-06.css. The current user-authorized sidebar requirement owns this extension. Expanded desktop252px, collapsed80px; `.is-collapsed` hides `.nav-text`, `.nav-header`, `.badge`, branding/profile details, while native icon actions retain Thai accessible names/title. Toggle persists only a boolean device preference; failure to access localStorage never blocks navigation. Early root bootstrap prevents refresh expansion flash. Mobile uses existing drawer at<=850px with expanded content and preserves desktop preference.

Ctrl/Cmd+K and search icon expand/focus menu search. Search matches navigation labels only; clear restores all items, unknown query shows a no-results message. Modal open/composition guards protect active workflows. Menu search does not reset report/form/data filters. Width changes notify canonical sticky-table sizing, including reduced-motion mode. Shared exports and business-state owners are untouched. Verify with tests/sidebar-interactions.mjs and existing full-app QA.

## v27.1 dashboard interaction

Search, route, supervisor, type, budget and display stage apply to latest scoped report projections. Clear resets filters. CSV uses visible scope; print summary opens independently of official outputs. Pending includes handover/payment at100%, excludes paid and prioritizes expired. Display partition never changes entries or snapshots.

## v27.3 — Unified Extensible Architecture & Live Database Dashboard

Authority: Latest baseline specified in `AGENTS.md` (v27.3) and `DESIGN.md` (v27.3). 
- **Flexible Dashboard & Instruction Precedence:** The operational shell and dashboard must adapt to `plannet_doh.html` visuals (emerald/gold theme, `.dash-v25-*` components) or new user instructions. Latest user commands override prior reference images, mockups, or legacy section locks, provided core data/report contracts are preserved.
- **100% Live Database State:** **Mock data (`SEED_DATA`), database reset scripts, and hardcoded logic are strictly prohibited**. All dashboard metrics, 4 KPI cards, status pipelines, charts, and tables must be entirely bound to live Supabase/IndexedDB state via `latestScopeReport()`.
- **View Model Separation:** `src/dashboard-selectors.js` acts as the canonical View Model layer. UI renderers (HTML template strings) must only consume resolved view models and must not contain raw data mapping or business calculations.
- **Status Pipeline & Rules:** The dashboard features a 5-stage contract status card (`ongoing`, `deliver`, `pay`, `paid`, `expired`). KPI calculations (e.g., budget accounts, delayed projects) must strictly use actual database values (no arbitrary multipliers for empty data).
- **Responsive Table Exemption:** The dashboard's dual bottom tables (`ตารางโครงการทั้งหมด` and `งานค้างดำเนินการ`) use `.tbl.dash-v25-clean-table` and explicitly opt out of the standard `mountResponsiveRows` mobile card transformation at ≤640px to preserve their multi-column grid layouts.

## v27.3 Global UI Layout Standards

Canonical layout, toolbar, filter, overlay and responsive rules are maintained in `docs/UI-LAYOUT-STANDARDS-v27.3.md` and implemented by the shared application-shell styles in `src/cascade-06.css`. The standard owner is presentation-only: it does not change selector calculations, API contracts, database state, authentication, or official report surfaces.

- Primary page actions stay in the right side of the shared operational toolbar; secondary actions use the existing disclosure/menu owners.
- Search and primary filters share one horizontal bar. Secondary filters use the existing advanced-filter disclosure and active chips.
- Layer ownership uses `--z-sticky`, `--z-dropdown`, `--z-dropdown-submenu`, `--z-popover`, `--z-modal`, and `--z-toast`; screen-local numeric z-index values are not canonical.
- General operational tables may use the existing mobile labeled-card owner at ≤640px. Dashboard clean tables and official report tables retain their horizontal multi-column exception.
- Busy primary actions preserve geometry and expose both `data-loading="true"` and `aria-busy="true"`.
