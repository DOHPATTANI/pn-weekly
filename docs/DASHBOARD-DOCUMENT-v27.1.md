# Uploaded document implementation — 26 October 2026

## Rules review and analysis

Rules.md → AGENTS.md and AGENT-EFFICIENCY.md apply. Source ownership is src/manifest.json; generated app.js/styles.css remain the delivery. The user explicitly requested analysis and execution of ข้อความที่วาง.txt. No additional approval is needed for this scope.

Facts: live state version is 1, project fields are contract/title/start/end, weekly fields are plan/weekly/actual, finance comes from registry contractValue/actualCost. The supplied SCHEMA_VERSION=7, planPct and store keys are examples, not the current persistence contract. Replacing them would strand offline work and break imports. Existing mutation queue, button lock, RFC7807 error owner, Bangkok today(), workspace guards and scoped RPCs remain canonical.

Root problem: the dashboard mixes selectors, repeated registry lookups and presentation, its pending section omitted completed work awaiting handover/payment, and date guards accepted impossible calendar days.

Goal: real-data executive dashboard and defensive ingress validation while preserving IDs, snapshots, reports and offline queue. No database/auth/dependency changes. Display expiry is exclusive only in the dashboard five-part distribution; persisted lifecycle and weekly rules do not change. Money is never inferred from progress or payment label.

## Plan and ownership

1. src/dashboard-selectors.js owns pure filter/stage/distribution/pending/account projections, concatenated into the existing module.
2. src/operations.js owns escaped HTML presentation and canonical control bindings. Pending and all-project tables use native operational table owners.
3. data-rules.js/registry-import.js/master-data.js strengthen existing guards/errors instead of adding competing validation or persistence.
4. Focused domain tests, browser filter interaction and mobile checks precede final existing gates. Rollback is git revert; no data migration.

Alternatives rejected: copied sample state model (incompatible), framework/Tailwind runtime (unnecessary dependency), changing payment lifecycle from finance totals (unsafe domain inference), marking an expired record twice in a100% display bar (misleading proportions).

## Data flow and traceability

Scoped latest report → activeRows (saved snapshot/entry) → filterDashboardRows with scoped registry → selectDashboardViewModel (KPI, history, exclusive stages, budget/work types, pending and project rows) → escaped renderers → existing native controls/save/detail owners. The view model is read-only and never writes Supabase or IndexedDB.

| Request | Owner / resolution |
|---|---|
| Architecture, central state, naming | Existing src manifest plus new pure selector section; persistence names retained |
| Five status cards /100% tooltip | computeStatusDistribution / renderContractStatusSection; expired removes that row from ongoing for display |
| Work remaining including delivery/payment | selectPendingActionRows / renderPendingActionsTable; paid excluded, expired first |
| Account progress | Indexed registry projection; count, actual/plan averages |
| Work-type donut | Existing actual workTypes; shared category filter |
| Search / route / supervisor / status / clear | Native dashboard toolbar, no extra dependency |
| Main and pending tables | Side by side on desktop, stacked sections with table-local horizontal scroll on mobile; both `.dash-v25-clean-table` tables opt out of mobile record-card conversion and display eight rows per page |
| Null/invalid workspace guard | validateLoadedWorkspace rejects before replacing state |
| Calendar validation | isValidISODate and validateDates reject impossible dates, preserve ISO CE |
| Financial inputs | Existing registry import/manual preview rejects negative/nonfinite or over-contract cost before saving; existing records are not rewritten |
| Errors | Existing toProblemDetails retains previous fields and adds timestamp |
| Race/offline | Existing serialized mutationTail, scopeRequest, withButtonLock and drafts retained |
| XSS | Dynamic strings escaped at renderer boundary; CSV quoting; no source scripts executed |
| Fonts / tokens | Requested IBM Plex Sans Thai / Kanit / Inter added through the existing Google Fonts stylesheet owner; Thai/system fallbacks remain for offline use |
| Official reports | Executive/P301 renderers unchanged |

Limit: historical money sparklines require historical monetary observations; current registry money must not be presented as past weekly money. No fabricated history or default department assignments are installed from the example.

Validation evidence is stored under work/document-*; actual final results must be recorded in decision-log before delivery.
