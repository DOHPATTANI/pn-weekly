# v26–v27.3 remediation and architectural working evidence

## Implemented
Financial denominator/known-vs-unknown totals; real pipeline proportions and historical KPI sparklines (now strictly driven by 100% live database state via View Models, zero mock data allowed[cite: 1, 2]); draft identity-safe cleanup; paginated audit DTO and server search; working unconfirmed filter; concurrent branding/detail reads; P301 export excludes cold import history; targeted list search; dead helper removal; shared sticky action/header system; registry column preferences; budget-account summaries; mobile 10-row default and readable summary cards (explicitly excluding dashboard `.dash-v25-clean-table` which retains its multi-column grid at ≤640px[cite: 1, 2]); complete generated schema and parity check; duplicate index removal; single CI artifact and retired legacy patcher.

## Requires architectural follow-through
Deferred master/review DTOs; entity-level write revision design; complete source-module decomposition (including the mandatory separation of UI renderers and `src/dashboard-selectors.js` View Models[cite: 1, 2]); full CSS consolidation (incorporating v27.3 Design Tokens and Component Variants[cite: 1, 2]). Existing review before-images and transactional write aggregate are deliberately retained until a compatible replacement is verified.

## Owner decisions
Owner confirmed: retain current shared write authorization, no login until explicitly requested later. Pending owner decision: confirmed P301 rule version policy. UI themes and dashboard configurations are now flexible to match HTML references, provided data contracts remain immutable[cite: 1, 2]. No production migration or deployment has been performed by this working branch yet.

## Regression lessons
Clear only the exact saved draft object; rebinding inline entry listeners must replace handlers to avoid stale batch-mode closures; tests must await debounced result rows before clicking; paged history uses rows/change pairs, not importHistory runs; fresh schema snapshots must not replay historical non-idempotent migrations on top of themselves. New migrations must reapply safely.

## Follow-up
New review acknowledgments use versioned SHA-256 identities (74 characters), with legacy JSON fingerprint reads preserved. Existing stored review records are not bulk rewritten; original import before-images remain in audited history. Schema parity now compares constraints, triggers, views, policies, relation ACL/RLS flags, and function grants/security settings as well as tables, indexes, functions, and columns. SHA-256 tests compare Unicode and multi-block inputs against Node crypto.

## Verification follow-up
168 unit cases passed; browser audit passed nine screens at 1500px and 375px (including stable search focus, sticky controls, registry preferences, audit search, and dashboard view models[cite: 1, 2]). Browser runner must set `PN_CHROMIUM=/usr/bin/chromium` on this host; the default Playwright download is absent. This is an environment configuration issue, not an application failure.

## Release extension
Ordered src sections and manifest now generate root bundles with a CI parity gate. Dedicated `pn2_load_p301_export` filters funding and whitelists report business fields; native report-model equivalence is tested in `tests/p301-export-dto.mjs`. Production read measured 184,218 bytes versus active workspace 3,113,831 bytes (94.1% smaller for this export path, not a whole-app speed claim). Three additive read migrations applied successfully; business revision remained 549, contracts 183, and reports 6. Broader architectural proposals have explicit retained/deferred dispositions in `docs/ARCHITECTURE-DECISIONS-v26.md`; they are not represented as completed implementations.
