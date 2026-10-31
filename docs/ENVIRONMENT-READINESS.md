# Environment readiness and access recovery

Checked: 1 November 2026 (Bangkok). Scope: development tooling and access diagnosis; no production data, database grants, account permissions or network protections are changed.

## Established facts

- The managed environment is running with current observations and an enforced restricted HTTP policy. Its configured preset is `package_managers`; custom allowed hosts are empty. The inherited proxy and TLS verification must remain enabled.
- `github.com` and the npm registry are allowed. `api.github.com`, `dohpattani.github.io`, the production database host and Google Fonts hosts are absent from the effective allowlist. A successful Git push does not establish GitHub API or production-browser access.
- GitHub's connected plugin can read the repository and Actions independently of the shell's GitHub CLI. The PR workflow for commit `5f1293ea73ddfe0d63d8d4575f4bbaaebbd54e8f` succeeded: [Actions run](https://github.com/DOHPATTANI/pn-weekly/actions/runs/41230192810). Database synchronization and deployment were skipped by the PR-event conditions, not denied by account permissions.
- The user-authorized Windows device is online through Remote Desktop Commander. A read-only command successfully found Node, npm and Git. This establishes terminal access only; it does not establish a connected browser-control session or permission to alter every operating-system setting.
- The managed executor has system Chromium. Earlier browser errors came from looking only for Playwright's downloaded browser, while earlier npm failures came from using the home cache. These are local tooling issues, separate from network access.

## Recovery plan and ownership

| Requirement | Area | Acceptance | Verification / status |
| --- | --- | --- | --- |
| Run local browser checks without repeating a machine-specific override | Shared test-runtime helper and browser callers | Explicit override wins; otherwise use installed Playwright, then system Chromium; missing browser gives an actionable error | Resolver tests and real Chromium checks; see execution evidence and decision log |
| Avoid an unwritable home npm cache | Project `.npmrc` | Cache resolves inside ignored `work/` | `npm config get cache` and writable-cache smoke |
| Inspect GitHub CI reliably | Connected GitHub plugin | Read actual workflow run and job conclusion | Pass: Actions run above succeeded; combined commit statuses alone are insufficient |
| Reach deployed application from Cloud | Environment network configuration | Destination explicitly allowed and a read-only live check succeeds | Pending: owner must apply supported environment configuration; current tools expose status/diagnostics, not a policy update |
| Control local browser UI | Browser connection | Browser-specific tool confirms connection | Not established: Browser skill is present, but its control tool is not exposed in this chat |
| Compare against an approved visual reference | Visual fixtures / reference review | Deterministic approved target and matching baseline | Pending: an absent baseline is a review/input issue, not a network or administrator-permission failure |

## Minimal environment-policy changes

Local recovery verification: `npm ci --prefer-offline` installed 88 packages; `npm test` passed 177 tests (6 resolver + 171 application); source verification, build and cache verification passed. With `PN_CHROMIUM` unset, sidebar checks, the 375px nine-screen audit and main 375px QA suite passed. These checks establish the local toolchain recovery, not external production connectivity.

Use the supported Cloud environment configuration interface to add only the destinations needed for the selected operation. This document is a request checklist, not a claim that policy has changed.

Required for live website smoke checks:

```text
dohpattani.github.io
iiuearxdsbilcpsfzhyp.supabase.co
```

Required to inspect the application's externally loaded web fonts:

```text
fonts.googleapis.com
fonts.gstatic.com
```

Optional for shell-based Actions inspection (the connected GitHub plugin already works):

```text
api.github.com
```

Retain the existing package-manager preset. Do not switch off TLS verification, remove proxy settings, edit the policy snapshot, broaden database grants, copy credentials into source, or relay blocked requests through a different host. Editing `/etc/codex/network-policy.json` cannot grant access: enforcement is outside the executor.

After configuration is applied, recheck `environment_status` for current observations and enforced policy, then perform bounded read-only HTTP/browser checks. A new chat's blanket authorization does not itself alter the environment's effective policy. If the UI requires an owner or administrator, that action must remain with the authorized person.

## Interpretation rules

- An empty workflow listing is not proof of denied access. Check workflow/job state and the actual tool error.
- A skipped deploy on a PR is not a failed deployment.
- Passing local tests is not proof of production readiness or approved pixel parity.
- Remote terminal access does not mean browser UI automation is connected.
- Project-local fixes are reversible by reverting their commit. Environment-policy changes have a separate owner-controlled rollback.
