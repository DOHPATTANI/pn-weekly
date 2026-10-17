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
