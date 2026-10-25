# Decision log

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
