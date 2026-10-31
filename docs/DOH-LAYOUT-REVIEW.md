# Operational layout refinement — 31 October 2026

User scope: six Thai government operational screens, existing DOH forest/gold theme.

Implemented: compact toolbar spacing; advanced filters in document flow; grouped catalog navigation; actions adjacent to registry/asset/catalog tables; one system-settings submit action; explicit device-theme versus shared-system labels; archived Weekly batch controls hidden; readable contract/kilometre list accompanying the highway chart. Existing data calculations and official exports are unchanged.

Validation: source generation and verification, unit suite, build, and desktop/mobile audit regression. Production verification must follow successful deployment. Screen-reader speech testing remains separate from DOM and browser tests.

Known limitation: Weekly retains its sticky primary-action dock to preserve keyboard access and sticky-header behavior. All numerical metrics retain existing meaning; no data aggregation rules were changed.
