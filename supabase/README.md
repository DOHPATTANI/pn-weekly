# PLANNET DOH v8 database

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

`npm test` runs 103 unit tests. `npm run qa` creates a local PGlite database with synthetic data, starts a local server, intercepts remote RPCs, and runs Chromium at desktop/mobile sizes. It covers all six master tabs, no-op reimport, failed-import retry, old-report detail and audited amendment. It never writes test records to the live database. Install development dependencies and Chromium as described in `MANUAL.md`.

Additional release tests against a private copy of the full workspace cover granular entry saves, rapid queued edits, failure/reload recovery, full JSON backup, both funding groups, unknown legacy payment dates, closing/newly-paid date gates, invalid-entry rollback and unchanged frozen history. A live PostgreSQL contact-import probe under the client role took 1,224 ms and 1,011 ms in two runs; each verified the write then rolled it back, keeping revision 78 and no test data. These server-only samples are not HTTP latency guarantees. Release measurements and live deployment evidence are supplied in `05-Verification` of the delivery. Local and HTTP timings depend on data, cache and network conditions; they are not fixed latency guarantees.

The older SQL regression files in `tests/` document their original v7 migration context. Use the v8 QA and current schema for release verification. See `MANUAL.md` for current user workflows and limits.

## v11 registry relations

Apply `20261017091813_personnel_assignments_and_road_catalog.sql` after the previous migrations. Personnel assignments retain group, ordinal, position and duty per contract; the common person record retains the full name. `pn2_road_sections` projects the reusable road catalogue while kilometres and direction remain contract-specific. Native foreign keys and ordinal constraints reject invalid assignments atomically. Existing scoped reads and changed-only writes remain in use; full history is loaded only for explicit backup operations.

The authorized master rebuild is a separately audited XLSX delta with a private full backup. It rebuilds contractor/personnel references from current contracts and authoritative ก-4 names without deleting contracts or report snapshots. Legacy supervisor labels remain contract references rather than being guessed as new people.

## v12 scoped reads and cleanup

Apply `20261017231300_scoped_registry_reads_and_delta_validation.sql`. Scope reads return only the current funding/year projects and registry, while the report catalogue/carry context remain available. Patches validate the affected report set and retain global project checks/FKs/revision locking. Explicit JSON imports ignore cold import-history payloads when computing field diffs, preventing recursive history comparisons. Prior baselines in settings preserve cumulative validation after authorized report pruning. Road catalogue consolidation deletes retired IDs before renaming survivors to avoid transient unique conflicts. Active FK indexes follow the Supabase advisor; legacy pn_* tables remain unchanged.

The one-time production cleanup is audited and backed up separately; ordinary saves still protect closed reports. Full JSON backup remains an explicit online operation.

JSON replacement uploads exclude cold import audit (which remains in the destination). New JSON archives use the existing delta-v1 representation, preserving field before/after values without repeated full documents. Apply `20261018054604_avoid_reprocessing_cold_history_in_json_restore.sql` after the v12 scope migration.

Apply `20261018055038_compact_added_removed_audit_nodes.sql` to retain complete added/removed record nodes in one diff item rather than recursively appending every absent leaf. Changed records still have granular field diffs. This bounds report-cleanup audit work while retaining the exact removed report.

`20261018055453_append_json_audit_without_history_hydration.sql` appends a new JSON audit run directly, retaining every existing cold run instead of loading, concatenating and rewriting the old history. This also supports legacy capped-history function variants found in production.
