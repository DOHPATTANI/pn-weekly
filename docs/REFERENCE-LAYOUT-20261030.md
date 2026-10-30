# Owner reference layout — 30 October 2026

## Facts, scope and approach

The owner supplied screenshots and `Pasted text.txt` containing a complete visual prototype. It has local illustrative records and standalone handlers, not the production persistence model. Use its visual hierarchy (full-width forest header, white left navigation, compact page command frame, white KPI tiles, green dashboard hero and readable tables). Preserve the production handlers and live data. This is product/admin work, not a separate marketing site.

Rules inspected: Rules.md, AGENTS.md, UX-CONTRACT.md, DESIGN.md, development workflow and efficiency policy. Canonical owners: index.html/sidebar.js for navigation; operations.js for render/bind, mountGlobalScope, mountOperationalDock and compactOperationalLayout; dashboard-selectors.js for live dashboard values; highways-ui.css for shared screen presentation; source manifest for generated assets. Official report/export owners remain independent.

Assumption: existing extra controls and reports must remain available even where absent in the sample. Therefore retain secondary menus, historical archive, all five asset-status filters, and current table fields. No schema, authentication, business calculation or runtime dependency changes. Reference code is design evidence only. Unknown: exact browser/font rasterization of the screenshots; do not promise pixel-identical output.

## Implementation and risk

1. Reorganize shared shell and move original scope nodes into a persistent institutional header, preserving handlers, IDs and selections.
2. Consolidate original page actions into each page heading; retain weekly period/status and tools. Extend the existing screen-only stylesheet rather than import prototype scripts.
3. Match dashboard/card/table proportions and light navigation to the reference, retaining all real records and canonical interactions. Preserve mobile drawer and dashboard horizontal-table exception.
4. Inspect desktop/mobile screenshots across every route, search/no-results, scope controls, navigation, help, selection and read dialogs; run repository tests, QA, audit, build and CI; deploy and verify the live revision.

Primary risk: moving controls outside #app can produce stale IDs or unbound controls on rerender. Remove the previous header scope before rendering, move current nodes after binding, and verify navigation and scope changes. Sticky offsets must account for the institutional header. Rollback: revert this change set and regenerate runtime assets. Never reset stored data.

## Requirement-to-Acceptance Matrix

| Requirement | Source | Implementation area | Acceptance criteria | Validation |
|---|---|---|---|---|
| Forest header, white navigation | Owner images/HTML | index.html, reference-shell.css | Full-width branded header; selected menu clear; drawer/collapse usable | Browser screenshots across all app surfaces at 1500px and 375px; no page overflow |
| Shared funding/year | Owner request | operations.js | Exactly one control each; state persists through navigation | Browser inspection confirms one year and funding selector in institutional header; `qa` navigation/scope checks pass |
| Clear page actions/search/filters | Owner images | reference-layout.js, operations.js, reference-shell.css | Grouped toolbar, retained secondary actions, no overlap or blank frames | `qa` at 1500/900/640/375; `qa:audit` at 1500/375; dashboard advanced filters and clear action verified |
| Reference dashboard | Owner image | dashboard-selectors.js, reference-layout.js, reference-shell.css | Hero, four real KPI cards, pipeline, budget/distribution and project sections | Live-data selector tests pass; desktop/mobile screenshots reviewed; no illustrative production rows added |
| Preserve functionality/data/documents | Owner explicit constraint | original handlers and export owners | Search, selection, details and reports remain; no prototype records or writes introduced | `npm test` 169/169; `npm run qa` and `npm run qa:audit` pass; schema snapshot passes |
| Owner handoff | Latest owner instruction | release bundle v27.3.5 | Provide the changed project files for owner to upload | Bundle prepared locally; not uploaded to GitHub |

## Verification record

- `npm test`: 169 passed, 0 failed.
- `npm run qa`: passed at 1500, 900, 640 and 375px, including row detail/edit, scope navigation, dashboard tools, and no-op/cancel behavior; no browser errors.
- `npm run qa:audit`: passed on desktop (1500px) and mobile (375px) across dashboard, weekly, contracts, asset register, reports, catalog, quality, audit and settings; no browser errors.
- `npm run verify-schema`: passed; latest migration reapplied safely.
- `npm run build`, `node tools.mjs verify-source`, and `git diff --check`: passed.
- `npm run test:visual`: 6 tests skipped because this checkout does not have an approved deterministic visual target (`PLAYWRIGHT_VISUAL_APPROVED=1` and `PLAYWRIGHT_BASE_URL`). The app was instead visually reviewed from the live local screenshots under ignored `work/v26/` and `work/reference-refresh/`.
- Release identifiers and asset query strings are bumped to `27.3.5` so the owner's upload invalidates cached runtime bundles and service workers.
- No schema/data changes, no production writes, and no GitHub upload were made.

Skills: frontend-design, frontend-design-premium and web-qa-release. Results recorded after verification.
