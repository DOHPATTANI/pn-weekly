# PLANNET DOH

Vanilla ESM application with generated app.js/styles.css from src/manifest.json. Read Rules.md and AGENTS.md before changes. Main user documentation is MANUAL.md.

Dashboard v27.3 pure projections and view models are in src/dashboard-selectors.js. See docs/DASHBOARD-DOCUMENT-v27.1.md and DESIGN.md for the flexible dashboard design mapping, and tests/dashboard-contract.mjs for focused invariants. Existing persistence/schema/report owners remain unchanged.

Dashboard layouts are UI-only presets in `DASHBOARD_LAYOUT_PRESETS`: `operational` is the default and `executive` omits optional presentation panels. Both use the same live view model and do not alter stored data, calculations, exports, or reports.

Checks: npm test, node --test tests/dashboard-contract.mjs, npm run qa, npm run qa:audit, node tools.mjs verify-schema, npm run build.

### Visual regression checks

Use `npm run test:visual` to run the Playwright dashboard visual suite. Screenshot comparison is intentionally gated until an approved deterministic visual target and baseline are supplied:

```bash
PLAYWRIGHT_VISUAL_APPROVED=1 PLAYWRIGHT_BASE_URL=https://your-approved-test-target npm run test:visual
```

When local browser dependencies are unavailable, use `docker compose -f docker-compose.visual.yml run --rm visual-test` with the same two environment variables. Playwright reports and failure artifacts are ignored; approved snapshots remain versioned with the test.
