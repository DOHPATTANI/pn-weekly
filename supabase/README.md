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
