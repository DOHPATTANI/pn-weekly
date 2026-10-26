# Decision log

## 2026-10-26 — Global UI layout standards v27.3

**Context**
- Toolbar, filters, dropdowns and responsive layout had multiple screen-local variants.

**Decision**
- Establish one Vanilla JS/CSS-token contract for action placement, filters, overlay layers and responsive table exceptions. Adopt `docs/UI-LAYOUT-STANDARDS-v27.3.md` and shared `--z-*` tokens.

**Reason**
- A shared contract removes duplicated CSS overrides while preserving live View Models and official report surfaces.

**Alternatives not chosen**
- Framework rewrite, new data state, or changing report HTML/CSS; all are outside this UI-only scope.

**Impact**
- Presentation and interaction layering only. No database, API, authentication, calculation, import, or export contract changes.

**Rollback**
- Revert the standards document and scoped cascade additions; generated assets can be rebuilt from `src/manifest.json`.

## 2026-10-24 — Rules continuity and evidence-based agent workflow

- **Decision:** Rules.md delegates to canonical AGENTS.md; docs/DEVELOPMENT-WORKFLOW.md records the owner's six-step workflow. Agent code validates explicit plan confirmation, per-role handoffs and existing hashed evidence. Codex performs actual agent delegation.
- **Authorization:** Owner's message “ยืนยัน” after the workflow adoption response. Scope: persist the workflow and align the existing agent runner, not resume paused product UI requirements.
- **Reason:** Previous runner automatically marked Audit/Data/UI/Performance/Security/Release passed during QA. Passing web tests did not establish those reviews had happened.
- **Alternatives rejected:** Duplicating all business rules into Rules.md (drift); adding model-service credentials or another CI/deployment service (unnecessary for this scope); treating successful shell commands as actual AI delegation (unsupported).
- **Files:** Rules.md, AGENTS.md, docs/DEVELOPMENT-WORKFLOW.md, docs/AI-AGENT-WORKFLOW.md, docs/AI-AGENT-WORKFLOW.yml, tools/agent-workflow.mjs, tests/agent-workflow.mjs, package.json, .github/workflows/ci.yml.
- **Compatibility:** No database/API/auth/data/import/report changes. Existing CI gates remain; add runner regression tests. Legacy v1 run state is explicitly rejected because its review claims were not evidenced. Original local run artifacts are retained under ignored work/.
- **Validation:** Eight runner integration cases passed against isolated temporary fixtures: approval/order/identity guards; changed-plan rejection; QA failure/nonzero/log/retry/release separation; downstream invalidation; changed rules and legacy state rejection; stale upstream evidence rejection at release; negative confirmation rejection. Fixtures simulate CI commands and do not prove production readiness or autonomous model execution. Web regression results are recorded separately after execution below.
- **Rollback:** Revert this workflow commit; no database rollback required. Keep previous state as evidence rather than accepting old automatic pass flags.
- **Limitations:** Confirmation is a coordinator-recorded attestation from the conversation, not a separate user authentication service. Hashes detect changed evidence but cannot prove prose is true; the coordinator/release agent must review content. CLI uses serial stages; Codex may parallelize independent analysis while serializing mutations. Logs are device-local ignored artifacts. No autonomous background execution with the session closed.

### Validation evidence

- `node --test tests/agent-workflow.mjs`: 8 passed, 0 failed. Reviewer found stale ignored evidence could bypass release; fixed and added regression. Negative confirmation and cancellation of stale runs also have regression coverage.
- `npm test`: 168 passed, 0 failed.
- `npm run verify-schema`: snapshot equals ordered upgrade; latest migration reapplied safely in local test DB.
- `npm run qa:audit`: passed at 1500px/375px across all nine application surfaces, errors empty.
- `npm run build`: passed; generated four-asset delivery unchanged.
- `node --check tools/agent-workflow.mjs` and `git diff --check`: passed.
- `npm run qa`: passed at 1500/900/640/375px; errors empty in every viewport.
- No schema deployment/data import performed; no production data written.

## 2026-10-25 — Collapsible shared sidebar (v26.0.1)

- **Authorization/scope:** User explicitly requested implementing the collapsible sidebar and reaffirmed using workflow/AI agents. Paused gradient cards, expanded filters and theme/settings redesign remain separate requirements.
- **Decision:** Reuse static shell/nav handlers. Add source-only shared presentation/search owner;252px desktop expanded/80px icon rail, guarded boolean localStorage preference, early bootstrap root class. Existing <=850px drawer remains expanded when open. Ctrl/Cmd+K opens/focuses menu-label search, blocked by modal/IME; clear/no-results and accessible names remain.
- **Alternatives rejected:** Framework/dependency rewrite or second app bundle; new DB preference table/auth; global business-data search. These add unrelated scope and risk.
- **Data/security:** No schema, API, auth, migration or live-data operations; only local boolean preference. Menu matches use text/attributes, not HTML interpolation. Canonical business navigation and official exports remain owners.
- **Risk found by independent safety review:** Reduced-motion disables transitionend, which could skip pinned-table sizing. Explicit animation-frame resize notification added; focused browser test asserts notification under reduced motion. Final transitionend still recalculates width after normal animations.
- **Validation:** Focused Chromium shell tests and168 unit cases passed before full QA. Final seven-gate run and release handoff are recorded under ignored work/agent-runs and work/sidebar; these are test evidence, not deployment proof. Full-app QA/CI must pass before delivery. Model delegation occurs via Codex agents; the CLI records handoffs/QA only.
- **Rollback:** Revert sidebar feature commit and rebuild generated bundles. Local preference key may remain unused harmlessly. No database rollback.
- **Sources:** index.html, src/sidebar.js, src/manifest.json, src/cascade-06.css, tests/sidebar-interactions.mjs; package/cache version refs26.0.1 and generated assets. Independent roles: sidebar_review, sidebar_qa, sidebar_safety.

## 25 October 2026 — v27 UI integration validation

Release follow-up: fresh audit now exercises advanced budget filter select/clear on weekly/registry/assets and theme/font/motion changes on both desktop and375px. All pass. Visual screenshot inspection identified cramped sidebar Settings text; utility grid now gives Settings a readable full column. Unit168, sidebar, schema and build were rerun successfully. Deployment is tracked separately by GitHub Actions and live smoke verification.

Owner authorized the screenshot-led dashboard, sidebar navigation, manual contextual tours, shell themes, registry columns, operational filters and P301 party-label presentation. Changes reuse existing business/save/export owners. Device preferences remain local; no schema, authentication or data import is added. Theme selection is an immediate live preview with reset; summary/chart semantic palettes and official document styles remain independent.

Integration fixed missing parentheses in advanced-filter/table markup, a removed notification element's startup handler, unmounted advanced filters and missing quality counts. Responsive regression caught six weekly cards squeezed into legacy columns at375px; explicit two-column mobile layout retains the full-width total. Sidebar tests wait for the media-state transition before opening the mobile drawer.

Validation actually run: npm test168/168; npm run qa at1500/900/640/375; npm run qa:audit across9screens at1500/375; npm run verify-schema; npm run build; node tools.mjs verify-source; git diff --check; focused sidebar interaction test. All passed in local fixtures. Full QA began before the final filter/font/motion hookup; final audit covered those rendered surfaces, not every new interaction. Theme preview has no separate confirmation step. No production deployment performed by this integration agent.

## 25 October 2026 — Agent efficiency policy and compact metrics

Owner authorized auditing quota waste and applying improvements. Evidence: v27 release notes, actual delegation/rework in task history, current runner/tests/CI. Provider token/quota telemetry is unavailable; no per-agent usage ranking or savings percentage is claimed. Consolidated role/ownership/context/testing/polling policy into docs/AGENT-EFFICIENCY.md; existing workflow docs link to it. Added read-only --summary with gate attempts/failures/duration/log bytes, explicitly not tokens. Existing confirmation, hash/rework and release protections remain unchanged. No runtime/database/data/security changes or web deployment required. Fresh validation: node --check tools/agent-workflow.mjs, node --test tests/agent-workflow.mjs (9/9), git diff --check pass. UI QA not run because only docs/runner output changed. Rollback via revert.

## 26 October 2026 — uploaded dashboard document /27.1

Pre-release CI exposed a delayed-scope disclosure race at640px: opening the P301 command menu before scope completion was undone by rerender. Added per-view open-state preservation and made the browser workflow open menus only if closed, retaining the immediate settings/scope test rather than force-clicking hidden controls. The failing CI attempt is retained as evidence; publication waits for a new passing head.

Owner requested reading, analysis and execution of ข้อความที่วาง.txt. Implemented against actual version1 state and existing store/RPC/save owners, retaining historical snapshots and official reports. Added immutable filter/stage/distribution/pending/account/KPI selectors, exclusive five-stage dashboard-only display, main+pending responsive tables, route/supervisor/stage filters, scoped CSV/print, asset-history navigation and explicit connection status. Removed obsolete English pipeline subtitle. Added real calendar/null workspace guards, new-input financial limits and RFC7807 timestamp. No schema/auth/dependency/package change; fonts extend the existing stylesheet owner with offline fallbacks.

Actual local validation:168unit +3focused domain tests, sidebar interactions, audit9screens1500/375 including filters/search/CSV/print, full QA1500/900/640/375, schema/source/build and diff checks passed. Subsequent small display/cross-filter changes receive exact-commit CI before merge. Screenshots reviewed at desktop/mobile. Historical monetary sparklines are not invented because monetary history is not stored weekly. Sample store keys/default departments were deliberately not installed. Release/live status is recorded separately after deployment; local passes are not a deployment claim.

## 26 October 2026 — Confirmed dashboard and device theme update

**Context**
- The uploaded HTML is a presentation reference. Existing dashboard projections, live records, business calculations, save owners and official exports must stay authoritative.
- The existing theme selector saved immediately and styled mainly the shell. The latest owner request asks for preview before confirmation and a theme across the website.

**Decision**
- Use the current data selectors for dashboard cards. The second card displays real average cumulative progress and historical trend; the pending card is labeled as work requiring follow-up because its selector includes handover and payment items.
- Place secondary dashboard export/refresh controls in one disclosure. Keep the primary create-week action visible in the topbar.
- Preview theme and light/dark icon changes in the DOM; persist only on confirmation. Settings cancel restores the saved selection. Theme CSS covers the web shell, operational summary cards and non-semantic chart palette while preserving status meanings and the existing report/print renderers.
- Retain the existing P301 per-record party role and shared vector/XLSX label renderer, and the manually launched guide covering nine pages.

**Reason**
- The reference figures are examples, while the live state defines the true values. A disclosure prevents mobile actions from crowding the header. Device-local preview avoids unintentional preference changes.

**Alternatives not chosen**
- Installing the uploaded HTML/store or changing business projections would break source ownership and risk historical data. A new theme persistence table is unnecessary for a device preference.

**Impact**
- Presentation and local preference only; no database, API, authentication, or export data change. Existing theme preferences remain readable.

**Rollback**
- Revert the source and regenerated bundles. The existing local theme key can remain without affecting business data.

**Release verification note — v27.2.0:** A new rendered dark-mode assertion exposed the pre-existing `#app:not([data-screen="dashboard"]) .card { background: white !important; }` override. The theme rule now takes precedence in screen media. The test waits for the card's CSS transition to finish before checking its final color. Audit passed on 1500px and 375px after this correction; it also verifies that preview does not write localStorage and confirmation does.

## 2026-10-26 — Compact dashboard release v27.2.1

**Context**
- The owner compared v27.2.0 with the supplied visual reference and found oversized hero/KPI panels and charts split across rows. The source-only dashboard layout updates reached main without regenerated runtime assets.

**Decision**
- Publish the existing dashboard-scoped compact layout and matching generated runtime assets together. Increment the application and offline cache version to v27.2.1 so installed browsers fetch the new layout.

**Reason**
- The layout follows the reference hierarchy while leaving data projections, API, authentication and official exports intact. A new cache identity avoids serving v27.2.0 assets after release.

**Alternatives not chosen**
- Replacing the application with the illustrative HTML would lose live data behavior and source ownership.

**Impact**
- Dashboard presentation and shell asset cache only; no schema or business calculation change.

**Rollback**
- Revert this release commit and redeploy the previous complete source and generated bundles.

## 2026-10-27 — v27.3 Unified Extensible Architecture and Live Database Dashboard

**Context**
- The owner provided `plannet_doh.html` as a strict visual reference for the operational shell and dashboard components (e.g., emerald/gold theme, specific KPI card layouts).
- Previous implementations occasionally mixed data retrieval, business rules, and HTML templating, which risked destabilizing official report constraints when updating UI designs.
- The supplied HTML reference contained illustrative mock data (`SEED_DATA`) and destructive scripts (`indexedDB.deleteDatabase`).

**Decision**
- **Live Data Mandate:** 100% of dashboard metrics, KPI cards, and status pipelines must bind to live Supabase/IndexedDB state via `latestScopeReport()`. Mock records, fabricated budget multipliers, and destructive bootstrap scripts are strictly prohibited.
- **View Model Separation:** `src/dashboard-selectors.js` now exclusively owns data aggregation and pure business rules (e.g., status distributions, budget progress, pending action rows). UI renderers must only consume these resolved view models.
- **Design Tokens & Variants:** Implemented the requested emerald/gold theme using CSS Design Tokens (`:root`) and Component Variants (`.dash-v25-*`). These isolate the dashboard UI from official report layouts (`.main-report`, `.p301-accessible`), ensuring print compliance remains untouched.
- **Responsive Exemption:** Explicitly excluded the dual bottom dashboard tables (`.dash-v25-clean-table`) from the standard `mountResponsiveRows` mobile card transformation to preserve their intended multi-column grid layout at ≤640px.

**Reason**
- This architectural separation allows the UI to flexibly match the owner's latest design references without compromising data integrity, historical snapshots, or the strict dimensional requirements of official A4 reports.

**Alternatives not chosen**
- Importing the reference HTML's `SEED_DATA` (causes severe data corruption).
- Hardcoding formulas for missing budget data (violates the financial data contract).
- Adding external UI frameworks like Tailwind (adds unnecessary dependency and bloat).

**Impact**
- UI presentation, CSS cascade architecture, and module structure separation. No database schema, API, authentication, or data import contract changes.

**Rollback**
- Revert the v27.3 architectural updates and restore v27.2.1 source and generated bundles.

## 2026-10-26 — v27.3 dashboard live-data view model

**Context**
- The v27.3 policy documents reached main before the implementation. Dashboard metrics, trend and work-type calculations remained inside the HTML renderer, and a hidden simulator still contained a fabricated 47-contract action.

**Decision**
- Keep the existing Supabase/IndexedDB scope and report selection. Move filtered KPI, history, status, budget, work-type, pending and project-row preparation to `selectDashboardViewModel` in `src/dashboard-selectors.js`. Remove the simulator handler and illustrative data branch. Use a central eight-row dashboard table setting and screen-only `.dash-v25-*` variants; exempt the two summary tables from mobile card conversion.

**Reason**
- The renderer can now consume a resolved read-only projection without inventing records or changing persisted lifecycle and official report contracts. The mobile table exception follows the owner's latest UX rule.

**Alternatives not chosen**
- Importing sample records or changing database schema would risk historical data. A framework rewrite would add unrelated complexity.

**Impact**
- Dashboard read and screen presentation paths only. No database migration, API, authentication, import, or official export changes. Legacy CSS for hidden simulator states remains inert and may be removed in a separate cleanup.

**Rollback**
- Revert this commit and redeploy v27.2.1. Workspace data requires no rollback.

**Validation for v27.3.0 (local, 2026-10-26)**
- `node tools.mjs verify-source`, `npm run build`, `npm run verify-schema`, `node tests/p301-export-dto.mjs`, `npm test` (168 passed), `node --test tests/dashboard-contract.mjs` (4 passed), `npm run qa` (1500/900/640/375px), and `npm run qa:audit` (nine surfaces at 1500/375px) passed after the source was frozen. The dashboard audit checks both clean tables remain tables and the project table renders at most eight rows.
- Browser screenshots were inspected locally at 1500px and 375px. This is a rendered check, not a pixel-perfect comparison with the illustrative attachment. No production data was altered or directly inspected in these local fixture tests.
- The existing `docs/ARCHITECTURE-DECISIONS-v26.md` is the maintained architecture file; there is no unversioned `docs/ARCHITECTURE-DECISIONS.md`. Legacy simulator CSS is unused; the runtime handler and fabricated record action were removed.

## 2026-10-26 — Dashboard reference parity (v27.3.1)

**Context**
- The owner approved applying `ภาพรวมโครงการ.html.txt` and its fully loaded Google Sites preview specifically to Dashboard. The previous dashboard only reused class aliases and compact geometry, rather than the reference component structure.

**Decision**
- Reuse the reference's screen-scoped hero, four KPI cards, five status pills, budget tracks, work-type donut and dual table components. Replace the obsolete compact Dashboard override block instead of layering another cosmetic alias. All values still resolve through the existing live selectors; no sample records, synthetic monetary fallback, database cleanup script, API/auth/schema or official report change is included.
- Preserve route/supervisor/status filters, CSV, print and refresh in a collapsed secondary disclosure. New pending-table search/chips use read-only view-model projections. Dashboard clean tables bypass the generic presentation and mobile-card transformation, retaining their own contract buttons and local horizontal scrolling.
- Scope CSS to screen media and `#app[data-screen="dashboard"]`; the shared sidebar/topbar and other pages retain their owners. Version/cache identity advances to27.3.1.

**Reason**
- The reference's actual HTML structure and measured geometry (168px hero,148px KPI cards,20px grid gaps and2:1:1 chart row at1440px) are necessary to reproduce the requested visual hierarchy. Data values and text wrapping vary with actual records.

**Rollback**
- Revert this release commit and redeploy the prior complete source/runtime assets; no data rollback is required.

**Actual validation**
- Unit168/168 and dashboard domain4/4 passed. Full browser QA passed1500/900/640/375px, with errors[] and official P301, historical amendments, imports, offline replay and conflict flows intact.
- A subsequent CSS-only substitution centralized23 shared palette values into `:root --dash-ref-*` tokens without changing their values. On that final source, regeneration, build, verify-source, and nine-screen audit at1440/375px passed. The final GitHub CI must recheck the exact release digest; the preceding full-QA result is behavior evidence before that token-only substitution.
- Schema verification and P301 DTO invariance passed. Screenshots inspected at work/v26/dashboard-1440.png and dashboard-375.png; reference geometry and remaining differences are recorded in ignored work/dashboard-reference-v27.3.1.md. No claim of100% pixel identity: actual records, persisted theme/device preferences, sidebar/topbar and browser font rendering affect the result.

## 2026-10-26 — Deterministic visual regression gate

**Context**
- Dashboard data must remain live at runtime; an arbitrary browser run against a changing remote dataset cannot establish a valid pixel baseline.
- The project needed a reusable Playwright configuration and a container fallback without claiming screenshot parity before an approved comparison exists.

**Decision**
- Add a Playwright visual-test entry point with desktop, tablet and mobile projects, a Dashboard screenshot assertion, and a mobile page-width assertion.
- Gate screenshot execution on an explicitly approved deterministic target (`PLAYWRIGHT_VISUAL_APPROVED=1` and `PLAYWRIGHT_BASE_URL`). The suite therefore cannot silently create or validate a baseline from an uncontrolled live environment.
- Add a Docker Compose runner using the repository’s Playwright version and record the environment fallback policy in `AGENTS.md`.

**Reason**
- This keeps runtime Dashboard data live while making visual regression reproducible once a stable approved test environment and reviewed baseline are available.

**Alternatives not chosen**
- Generating a baseline from production or fabricating dashboard data would make visual evidence unreliable and conflict with the live-data policy.

**Impact**
- Test tooling and documentation only; no runtime data binding, API, authentication, database, report, or Dashboard calculation changes.

**Rollback**
- Revert the visual-test tooling commit and remove its script; no data rollback is required.


## 2026-10-26 — Dashboard layout presets and acceptance traceability

**Context**
- Dashboard presentation needed a selectable structure independent of live-data selectors, and UI geometry values were split between legacy and new screen styles.
- Delivery evidence needed a consistent mapping from approved requirements to validation.

**Decision**
- Add immutable `operational` and `executive` Dashboard layout presets beside the existing view configuration. The renderer reads the preset only to order or omit presentation panels; `selectDashboardViewModel` remains the sole source for live scoped metrics.
- Centralize the requested emerald, gold, surface, border, spacing, radius, control-height and sidebar-width tokens in the screen stylesheet while keeping official report selectors excluded.
- Require a Requirement-to-Acceptance Matrix in project rules and the development workflow.

**Reason**
- UI composition can evolve without duplicating, fabricating or recalculating Dashboard data, while each accepted change has a testable delivery record.

**Alternatives not chosen**
- Storing the layout choice in business records would mix device presentation with audited data.
- Replacing report CSS with shared tokens would risk official print geometry.

**Impact**
- Dashboard presentation/configuration, shared operational tokens and documentation only. No API, database, authentication, live-data calculation or PDF/XLSX semantics change.

**Rollback**
- Revert this change set; no data migration or rollback is required.

## 2026-10-26 — Tailwind build-time coexistence for operational layout

**Context**
- The owner explicitly authorized Tailwind to coexist with the established Vanilla ESM and custom-CSS architecture while asking for consistent scope bars, table toolbars, form fields and responsive operational tables.
- Existing operational layouts contain legacy cascade overrides; report layouts must remain isolated.

**Decision**
- Add Tailwind 3 as a development-only compiler with `tw-` prefix and Preflight disabled.
- Compile `src/tailwind.css` into `src/tailwind.generated.css` before the existing source bundle is assembled; the generated utilities are ordered before `src/cascade-06.css`.
- Keep data selectors, API/RPC, state, reports and exports unchanged. Use the established presentation owner to place search, filter disclosure, selection toolbar and page-size controls.

**Reason**
- Prefixing and no reset prevent collisions with existing CSS while allowing scoped utility composition for shared operational layout. The final cascade remains the existing custom token/component layer.

**Alternatives not chosen**
- Tailwind CDN/runtime and global Preflight, because either could change unrelated UI and official report styling.

**Impact**
- Development build dependencies and screen-only presentation code. No schema, API, authentication, live-data calculation, or document-rendering change.

**Rollback**
- Revert the Tailwind config, generated source entry, dev dependencies and screen-layout changes; regenerate `app.js` and `styles.css`.
