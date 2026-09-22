# ADR-0008: Facilities are configured through a capability engine, not per-facility code

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

Phase 1 has roughly 20 named facility areas, each behaving somewhat differently (payment terminal or none, open tab or pay-first, ticketing or none, bookable or not), and the specification explicitly requires the software not hardcode today's facilities and requires the architecture to accommodate additional facilities — and eventually a hotel — without rebuilding the platform ([spec §2, §4](../spec/)).

## Decision

Model facility behaviour as data: a fixed catalog of `capability_type`s (POS, TICKETING, BOOKING, INVENTORY, MEMBERSHIP, …), a `facility_capability` join saying which are switched on for a given facility, and typed `operating_rule` rows parameterizing each enabled capability (e.g. `payment_timing`, `validation_mode`, `slot_granularity_minutes`). Business logic queries "does this facility have capability X, and what do its rules say", never a facility name or type switch. Full detail in [05](../architecture/05-facility-capability-model.md).

## Alternatives considered

- **One service class per facility type** (`RestaurantService`, `PoolService`, `SportsArenaService`, …). Rejected: this is exactly the hardcoding the spec prohibits, and it does not create separate business engines cleanly either — most "services" would share 90% of their logic (order creation, payment, stock) and differ only in a handful of parameters, which is what `operating_rule` already expresses without code duplication.
- **A single global config flag set per property** (e.g. `hasOpenTabs: bool` at the site level). Rejected: real facilities differ from each other within the same site (Restaurant has open tabs, Salon does not), so the configuration must be scoped to the facility unit, not the site.
- **Fully generic, schema-less "facility config JSON blob".** Considered for maximum flexibility. Rejected in favor of a typed `capability_type` catalog with typed `operating_rule` rows: a fixed, reviewable set of capabilities is easier to validate, test against (the concurrency and acceptance tests in [18](../architecture/18-testing-strategy.md) assume specific rule keys exist) and query efficiently than an unstructured blob, while still being data rather than code.

## Consequences

- Adding a new facility, or changing an existing one's behaviour, is a configuration change in `otueke-admin-web`, not a deployment.
- New capability *types* (a genuinely new kind of behaviour, not a new facility) still require an API/schema change — this is a deliberate line: the set of *possible* behaviours is a controlled vocabulary, the assignment of behaviours to facilities is not.
- The future hotel module is expected to introduce new capability types (e.g. `ROOM_INVENTORY`, `HOUSEKEEPING`) rather than a parallel facility model, keeping [03 §5](../architecture/03-domain-model.md#5-future-hotel-pms-fit) achievable.
