# ADR-0002: otueke-api is a modular monolith, not microservices

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

The API owns many bounded contexts (organization, identity, catalog, orders, payments, inventory, hospitality, booking, ticketing, membership, attendance, audit, sync, reporting). A single property with a fixed, modest hardware footprint (one on-site Windows server) needs the operational simplicity of one deployable, while still needing clear internal boundaries so the codebase does not collapse into an unmaintainable ball of mud as it grows.

## Decision

Build one ASP.NET Core solution with one deployable host, internally split into module projects with enforced boundaries (a module's tables and internals are private; other modules and the host call its application services only). Cross-module side effects flow through an in-process transactional outbox/integration-event mechanism, not direct calls into another module's data layer. See [01 §5](../architecture/01-architecture-overview.md#5-logical-architecture-a-modular-monolith) and [14](../architecture/14-api-module-map.md).

## Alternatives considered

- **Microservices per module.** Rejected for Phase 1: the on-site deployment target is a single Windows server with modest hardware; running a dozen independently deployed services there adds operational complexity (service discovery, distributed transactions across payments/inventory/orders, more failure modes) without a corresponding benefit at this scale. It also complicates the "local-first, single LAN hop" latency requirement for POS transactions.
- **One undifferentiated project with no internal boundaries.** Rejected: with 15 bounded contexts, that reliably degrades into tangled cross-cutting dependencies within a few months.

## Consequences

- A future split into services remains possible module-by-module, because each module already owns its data and exposes a service interface — the boundary this ADR establishes is also the seam a later extraction would use.
- Module boundaries are enforced by an architecture test in CI ([14 §1](../architecture/14-api-module-map.md#1-solutionproject-layout-proposed)), so the constraint is checked, not just documented.
- Financial/inventory operations that must be atomic across modules (e.g. settling an order also posts a stock movement) rely on being in one process/one database transaction — a benefit of the monolith that a distributed-services split would have to rebuild deliberately.
