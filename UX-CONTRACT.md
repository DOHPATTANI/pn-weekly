# PN Weekly operational UI contract
Business sources: AGENTS.md, DESIGN.md and explicit owner decisions recorded in work/v9/requirements.md. Runtime remains a single maintained module.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Table Selection | mountSelections / tableSelections | DESIGN.md v9 | all filtered pages / explicit rows | tools.mjs browser QA |
| Select/Listbox | selectField, native select and datalist | DESIGN.md | native browser popup | desktop/mobile browser QA |
| Date | field date input, parseG3Date, fileDate | MANUAL.md date rules | Thai display / Gregorian files | unit and workbook tests |
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
