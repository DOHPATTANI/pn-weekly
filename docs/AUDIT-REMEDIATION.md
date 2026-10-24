# v26 remediation working evidence
Implemented: financial denominator/known-vs-unknown totals; real pipeline proportions and historical KPI sparklines; draft identity-safe cleanup; paginated audit DTO and server search; working unconfirmed filter; concurrent branding/detail reads; P301 export excludes cold import history; targeted list search; dead helper removal; shared sticky action/header system; registry column preferences; budget-account summaries; mobile 10-row default and readable summary cards; complete generated schema and parity check; duplicate index removal; single CI artifact and retired legacy patcher.

Still requires architectural follow-through: deferred master/review DTOs and compact review hashes; entity-level write revision design; complete source-module decomposition; full CSS consolidation. Existing review before-images and transactional write aggregate are deliberately retained until compatible replacement is verified.

Pending owner decisions: write authorization policy (existing contract excludes auth changes); confirmed P301 rule version policy. No production migration or deployment has been performed by this working branch yet.

Regression lessons: clear only the exact saved draft object; rebinding inline entry listeners must replace handlers to avoid stale batch-mode closures; tests must await debounced result rows before clicking; paged history uses rows/change pairs, not importHistory runs; fresh schema snapshots must not replay historical non-idempotent migrations on top of themselves. New migrations must reapply safely.
