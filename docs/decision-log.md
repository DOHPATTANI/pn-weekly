# Decision log

## 2026-10-24 — Rules continuity and evidence-based agent workflow

- **Decision:** Rules.md delegates to canonical AGENTS.md; docs/DEVELOPMENT-WORKFLOW.md records the owner's six-step workflow. Agent code validates explicit plan confirmation, per-role handoffs and existing hashed evidence. Codex performs actual agent delegation.
- **Authorization:** Owner's message “ยืนยัน” after the workflow adoption response. Scope: persist the workflow and align the existing agent runner, not resume paused product UI requirements.
- **Reason:** Previous runner automatically marked Audit/Data/UI/Performance/Security/Release passed during QA. Passing web tests did not establish those reviews had happened.
- **Alternatives rejected:** Duplicating all business rules into Rules.md (drift); adding model-service credentials or another CI/deployment service (unnecessary for this scope); treating successful shell commands as actual AI delegation (unsupported).
- **Files:** Rules.md, AGENTS.md, docs/DEVELOPMENT-WORKFLOW.md, docs/AI-AGENT-WORKFLOW.md, docs/AI-AGENT-WORKFLOW.yml, tools/agent-workflow.mjs, tests/agent-workflow.mjs, package.json, .github/workflows/ci.yml.
- **Compatibility:** No database/API/auth/data/import/report changes. Existing CI gates remain; add runner regression tests. Legacy v1 run state is explicitly rejected because its review claims were not evidenced. Original local run artifacts are retained under ignored work/.
- **Validation:** Eight runner integration cases passed against isolated temporary fixtures: approval/order/identity guards; changed-plan rejection; QA failure/nonzero/log/retry/release separation; downstream invalidation; changed rules and legacy state rejection; stale upstream evidence rejection at release; negative confirmation rejection. Fixtures simulate CI commands and do not prove production readiness or autonomous model execution. Web regression results are recorded separately after execution below.
- **Rollback:** Revert this workflow commit; no database rollback required. Keep previous state as evidence rather than accepting old automatic pass flags.
- **Limitations:** Confirmation is a coordinator-recorded attestation from the conversation, not a separate user authentication service. Hashes detect changed evidence but cannot prove prose is true; the coordinator/release agent must review content. CLI uses serial stages; Codex may parallelize independent analysis while serializing mutations. Logs are device-local ignored artifacts. No autonomous background execution with the session closed.

### Validation evidence

- `node --test tests/agent-workflow.mjs`: 8 passed, 0 failed. Reviewer found stale ignored evidence could bypass release; fixed and added regression. Negative confirmation and cancellation of stale runs also have regression coverage.
- `npm test`: 168 passed, 0 failed.
- `npm run verify-schema`: snapshot equals ordered upgrade; latest migration reapplied safely in local test DB.
- `npm run qa:audit`: passed at 1500px/375px across all nine application surfaces, errors empty.
- `npm run build`: passed; generated four-asset delivery unchanged.
- `node --check tools/agent-workflow.mjs` and `git diff --check`: passed.
- `npm run qa`: passed at 1500/900/640/375px; errors empty in every viewport.
- No schema deployment/data import performed; no production data written.
