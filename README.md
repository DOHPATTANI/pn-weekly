# PLANNET DOH

Vanilla ESM application with generated app.js/styles.css from src/manifest.json. Read Rules.md and AGENTS.md before changes. Main user documentation is MANUAL.md.

Dashboard v27.3 pure projections and view models are in src/dashboard-selectors.js. See docs/DASHBOARD-DOCUMENT-v27.1.md and DESIGN.md for the flexible dashboard design mapping, and tests/dashboard-contract.mjs for focused invariants. Existing persistence/schema/report owners remain unchanged.

Checks: npm test, node --test tests/dashboard-contract.mjs, npm run qa, npm run qa:audit, node tools.mjs verify-schema, npm run build.
