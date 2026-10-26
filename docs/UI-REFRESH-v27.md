# v27–v27.3 approved interface refresh

Owner explicitly authorized the complete discussed interface update on 25 October 2026, with architectural refinements for v27.3 added on 27 October 2026. Implementation reuses the existing native table, save, report, and navigation owners. No authentication, database schema, or business-data import is included.

**Scope:** 
Dashboard toolbar and work-type chart; icon navigation with edge toggle and manual contextual help; device-local shell themes; registry column preferences; operational advanced filters and status cards; asset party label formatting in official renderers.

**Architectural Constraints (v27.3):**
- **Live Database State:** All dashboard elements (work-type charts, status cards, and KPI filters) must be strictly driven by actual database records via `latestScopeReport()`. The use of mock data (`SEED_DATA`) or illustrative hardcoded multipliers is strictly prohibited.
- **View Model Separation:** Data aggregation for the dashboard is exclusively owned by `src/dashboard-selectors.js`. Renderers must only consume these resolved view models.
- **Theme & Presentation Isolation:** Theme preferences affect shell controls only, utilizing CSS Design Tokens (`:root`) and Component Variants (`.dash-v25-*`). Financial and lifecycle charts retain semantic palettes. Official report typography, column geometry (`.main-report`, `.p301-accessible`), and configured P301 calculation bases remain strictly independent and unchanged.
- **Responsive Table Exemption:** The dashboard's `.dash-v25-clean-table` grids explicitly opt out of standard mobile card transformations to preserve multi-column layouts at ≤640px.

**Validation:**
Validation must include fresh unit tests, browser QA at desktop (1500px) and mobile (375px) sizes, audit regressions, schema verification, generated-source verification, and build. A build alone does not establish release readiness. Check for strict absence of mock data artifacts in the UI layer. 

**Rollback:** 
The previous published commit; no data rollback is necessary for this client-only update.
