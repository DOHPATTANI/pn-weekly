# PN Weekly database performance patch

Apply `migrations/20261015070325_optimize_workspace_timeouts.sql` to the existing v7.1+ database. This patch was applied to the live pn-weekly project on 15 October 2026. It does not import or replace business data.

The old save function expanded the complete report array for every historical report and every lookup. On the live 130-report workspace, a save benchmark took 71,939 ms and wrote 158,852 temporary blocks. The patch caches report arrays and ID maps once, preserves the closed-history guard, and reuses validation for byte-identical locked reports. Changed reports continue through the existing validation. Load returns the stored document directly when its revision already matches the authoritative revision.

PostgREST RPC timeouts are set on individual functions: load 15 seconds; save, import and amendment 25 seconds. The browser's existing request timeout is 30 seconds. The default role limits and access grants remain unchanged. The migration notifies PostgREST to reload its schema cache.

Validation on 15 October 2026:

- Live PostgreSQL save benchmark after patch: 2,850 ms (transaction rolled back), about 25 times faster. Temporary blocks written fell to 3,021.
- Live regression SQL passed as both administrator and `anon`, with every write rolled back. It verifies settings save preserves reports/import history, rejects stale revisions and unauthorized history edits/deletions, and keeps identical imports idempotent.
- Full-size local PostgreSQL tests passed for changed imports, invalid-import rollback, audited amendments and preserved snapshots.
- Existing application tests: 42 passed; production build passed.
- Live HTTP load passed. HTTP write verification from the managed environment was blocked by its credential proxy with `401 Unauthorized: authentication failed for integration`; it did not reach the database. Database writes were verified separately through the Supabase plugin under the `anon` role. Actual browser write performance remains to be observed.

Run `tests/workspace_timeout.sql` through an SQL connection or the Supabase SQL editor against an existing populated workspace. It ends in `ROLLBACK`. To exercise client permissions, add `SET LOCAL ROLE anon` immediately after `BEGIN`.

Supabase security advisors were checked. Existing anonymous SECURITY DEFINER endpoints reflect this project's chosen shared workspace without login. The private import archive intentionally has RLS and no client policy. Advisor explanations: [anonymous SECURITY DEFINER endpoints](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [private table without a client policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

The patch still rebuilds the relational projection when saving. Incremental projection updates are a possible next step if the workspace grows; they are not required for this fix. Database elapsed times above exclude network transfer.

## v7.2.1 — weekly report creation

`20261015073328_fix_weekly_report_creation.sql` fixes draft creation when a prior imported row says paid but has no documented payment day. Such rows remain unknown in drafts; newly paid rows and closing a new report still require dates. Prior entries are indexed once per changed report instead of repeatedly expanding all reports per contract. Ordinary saves preserve server-authored import history even when the client omits it.

The new invoker RPCs `pn2_load_active_workspace` and `pn2_load_import_history` split operational data from audit details. The original `pn2_load_workspace` remains the full backup endpoint for backward compatibility. On the current workspace, UTF-8 operational JSON falls from 13,243,425 to 4,725,781 bytes (about 64% smaller). Historical reports, snapshots and import archives remain intact.

`tests/report_creation.sql` verifies legacy draft creation, deferred history and the closing gate in a rolled-back transaction; it passed on the live database as `anon`. Local PostgreSQL tests additionally cover both funding groups, correcting one missing date while others remain unknown, rejecting a newly paid undated row, and retaining locked history. The application has 45 passing unit tests. Desktop 1500×1000 and mobile 390×844 browser tests exercise the rendered create/open/date-correction/audit/backup flows using the current workspace against local PostgreSQL, without writes to production.
