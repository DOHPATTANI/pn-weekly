# v27 approved interface refresh

Owner explicitly authorized the complete discussed interface update on 25 October 2026. Implementation reuses the existing native table, save, report and navigation owners. No authentication, database schema or business-data import is included.

Scope: dashboard toolbar and work-type chart; icon navigation with edge toggle and manual contextual help; device-local shell themes; registry column preferences; operational advanced filters and status cards; asset party label formatting in official renderers.

Theme preferences affect shell controls only. Financial and lifecycle charts retain semantic palettes. Official report typography and column geometry remain independent. Existing configured P301 calculation bases remain unchanged.

Validation must include fresh unit tests, browser QA at desktop and mobile sizes, audit regressions, schema verification, generated-source verification and build. A build alone does not establish release readiness. Rollback is the previous published commit; no data rollback is necessary for this client-only update.
