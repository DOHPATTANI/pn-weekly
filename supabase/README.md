# PN Weekly v8 database

The live pn-weekly project was migrated on 15 October 2026. Existing business data was preserved: the hydrated JSON backup matched the pre-migration document exactly, at revision 78 with 111 projects, 130 reports and 5 import-history runs.

For a fresh database, apply `schema.sql`, then `migrations/*.sql` in filename order. The delivery's `02-Supabase/ติดตั้งระบบ.sql` combines this sequence. Do not reapply a fresh-install script to the live database. MCP-applied migration timestamps can differ from local creation timestamps; reconcile the migration ledger before using CLI push against an existing deployment.

Current behavior:

- `pn2_import_changes` accepts small audited CSV/XLSX deltas and appends one cold run without rebuilding the old history. Identical imports do not advance the revision. New import archives retain field-level before/after deltas instead of repeated full documents; existing archives remain intact.
- `pn2_patch_workspace` merges whitelisted ID-based changes under the shared revision/advisory lock. Domain validation and closed-report protections remain active.
- `pn2_save_workspace` conditionally upserts relational rows and removes only records absent from the authoritative payload. It skips unchanged collections, finds removed entry keys once, and no longer clears and rebuilds projection tables. Weekly edits leave unchanged contract rows untouched.
- `pn2_save_entry` merges one draft entry server-side, then uses the normal validated patch path. `pn2_amend_report_delta` retains audited historical-edit logic and returns only changed entries/metadata and lifecycle changes. Later cumulative actuals and frozen snapshots remain preserved.
- `pn2_import_runs` and `pn2_report_snapshots` hold cold history and frozen snapshots. Both have primary keys and workspace foreign keys; snapshots also reference their report. The work-code linkage has a uniqueness constraint enforcing one job per official work code.
- `pn2_load_scope` returns the report catalogue, selected snapshot, six recent entry sets and explicit carry context. Quality metadata retains missing-date identities without repeated entry notes. `pn2_load_report_detail` loads one older report and its prior entries.
- `pn2_load_workspace` hydrates all cold data for full JSON backup. Revision is inserted before attaching the large history; collections are materialized once. Complete backup/history RPCs allow 25 seconds, scope/active reads 15 seconds, with the existing 30-second browser request limit. Access grants, login behavior and role-wide limits remain unchanged.
- Contractor address/phone are stored in both source data and relational columns, with length checks. The `archived` database columns remain for compatibility with legacy schema/snapshots; v8 has no basic-data archive controls or archive CSV column. Referenced contract deletion retains history using `deletedAt` tombstones.

Verification:

`npm test` runs 62 unit tests. `npm run qa` creates a local PGlite database with synthetic data, starts a local server, intercepts remote RPCs, and runs Chromium at desktop/mobile sizes. It covers all six master tabs, no-op reimport, failed-import retry, old-report detail and audited amendment. It never writes test records to the live database. Install development dependencies and Chromium as described in `MANUAL.md`.

Additional release tests against a private copy of the full workspace cover granular entry saves, rapid queued edits, failure/reload recovery, full JSON backup, both funding groups, unknown legacy payment dates, closing/newly-paid date gates, invalid-entry rollback and unchanged frozen history. A live PostgreSQL contact-import probe under the client role took 1,224 ms and 1,011 ms in two runs; each verified the write then rolled it back, keeping revision 78 and no test data. These server-only samples are not HTTP latency guarantees. Release measurements and live deployment evidence are supplied in `05-Verification` of the delivery. Local and HTTP timings depend on data, cache and network conditions; they are not fixed latency guarantees.

The older SQL regression files in `tests/` document their original v7 migration context. Use the v8 QA and current schema for release verification. See `MANUAL.md` for current user workflows and limits.
