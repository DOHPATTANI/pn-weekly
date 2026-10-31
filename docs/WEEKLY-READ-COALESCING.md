# Weekly read lifecycle — A1

Scope: presentation loading only. No database/schema/report calculation changes.

Pending `pn2_load_*` requests share one transport promise only when configuration,
RPC name and serialized parameters match. Completed and failed requests are removed;
later reads always contact the server. Mutations never pass through this mechanism.
Each consumer receives a structured clone so workspace normalization cannot mutate
another caller's result. Existing scope-generation checks still reject stale results.

After a fresh screen response, an existing closed report may supply its detail only
when the server revision, funding, year and report ID match the previously loaded
workspace and every entry has a snapshot. Unknown revisions, incomplete snapshots,
different scopes and changed revisions fall back to the existing detail RPC.
Branding hash validation is unchanged.

Regression evidence: `npm test` includes pending-read deduplication, independent
response ownership, post-completion refresh, failure recovery, separate scope keys,
and strict report-detail revision/scope/completeness checks.

Rollback: revert the A1 changes in `src/cloud-client.js`, `loadWorkspace` in
`src/operations.js`, and related tests, then regenerate using `node tools.mjs source`.
Do not revert unrelated dashboard presentation changes.

Production timing remains unverified until the new revision is deployed and the
cold/warm/Weekly/scope-change capture is repeated. Do not infer a measured speedup
from unit-test or build success.
