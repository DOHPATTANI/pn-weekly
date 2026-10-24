# v26 structure and data integrity decisions

## Source and delivery
Source sections under src/ are ordered by manifest.json and generate the existing single ESM module and CSS bundle. This preserves lexical bindings, exports and canonical event owners. It does not claim independent module isolation. CI rejects stale generated bundles. The browser still requests the same four release assets.

## Transaction boundary
Retain workspace-wide optimistic revision and the existing native transactional projections. Weekly cell writes already use the narrow pn2_save_entry path; imports and historical amendments retain their audited owners. A new per-entry revision without guarding previous-week baselines, registry lifecycle dates, report locks and settings would permit invalid concurrent writes. Entity-level concurrency is therefore a separate protocol migration, not enabled in v26. Offline rebase and explicit conflict review remain the supported resolution path.

## CSS cascade
Split source ownership without rearranging cascade order. The approved report rendering and responsive behavior rely on existing overrides. A scan found 1,489 top-level blocks and zero exact redundant blocks; deleting differing selectors as duplicates would change behavior. Removed obsolete summary rules in the main v26 change. Broad !important removal remains maintenance work rather than a release correctness claim.

## Read boundaries
History is paginated/searchable on the server. P301 all-year export uses a dedicated funding-scoped read DTO with only report fields, relevant contractors/work codes and P301 settings. It excludes reports, historical snapshots, import history, personnel assignments and review metadata. Full backup remains complete and separate. Initial screen loading still includes masters/reviews; deferred master DTOs require explicit loaded ownership across import, save, offline cache and conflict paths, and are not enabled in v26.

## Owner policies
Shared access without login remains by explicit owner instruction. Confirmed P301 rule freezing is not introduced without the outstanding owner decision; current calculation behavior is preserved. Do not invent historical versions.
