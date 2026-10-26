# v26–v27.3 structure, UI architecture, and data integrity decisions

## Source, UI Architecture and Delivery
Source sections under `src/` are ordered by `manifest.json` and generate the existing single ESM module and CSS bundle. This preserves lexical bindings, exports, and canonical event owners. **In v27.3**, UI presentation is strictly separated from business logic through the `src/dashboard-selectors.js` View Model layer. UI renderers must only consume resolved view models instead of computing raw state. CI rejects stale generated bundles. The browser still requests the same four release assets without relying on external runtime frameworks.

## Strict Live Data Boundary
Dashboard and operational UI surfaces must derive 100% of their metrics, charts, and status pipelines from live Supabase/IndexedDB state (e.g., via `latestScopeReport()`). The injection of mock records (`SEED_DATA`), hypothetical mathematical multipliers for empty data, or destructive database bootstrap scripts (`indexedDB.deleteDatabase`) from HTML design prototypes into the production runtime is strictly prohibited.

## Transaction boundary
Retain workspace-wide optimistic revision and the existing native transactional projections. Weekly cell writes already use the narrow `pn2_save_entry` path; imports and historical amendments retain their audited owners. A new per-entry revision without guarding previous-week baselines, registry lifecycle dates, report locks, and settings would permit invalid concurrent writes. Entity-level concurrency is therefore a separate protocol migration, not enabled in v26/v27. Offline rebase and explicit conflict review remain the supported resolution path.

## CSS cascade and Extensibility
Split source ownership without rearranging cascade order. The approved report rendering and responsive behavior rely on existing overrides. **v27.3** introduces CSS Design Tokens (`:root`) and Component Variants (e.g., `.dash-v25-*`) to support flexible dashboard themes (emerald/gold) without mutating the isolated official `.main-report` and `.p301-accessible` document constraints. Broad `!important` removal remains maintenance work rather than a release correctness claim.

## Read boundaries
History is paginated/searchable on the server. P301 all-year export uses a dedicated funding-scoped read DTO with only report fields, relevant contractors/work codes, and P301 settings. It excludes reports, historical snapshots, import history, personnel assignments, and review metadata. Full backup remains complete and separate. Initial screen loading still includes masters/reviews; deferred master DTOs require explicit loaded ownership across import, save, offline cache, and conflict paths, and are not enabled yet.

## Owner policies
Shared access without login remains by explicit owner instruction. Confirmed P301 rule freezing is not introduced without the outstanding owner decision; current calculation behavior is preserved. Do not invent historical versions. UI layout and dashboard visuals may be updated freely per owner HTML references, provided these cosmetic changes never alter the underlying immutable data and report contracts.
