# ADR-0007: Laravel apps hold no business database; reporting uses read-only views

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

Laravel ships with strong conventions for owning its own database (migrations, Eloquent models, a `users` table). Left unchecked, that convention pulls `007resort-admin-web` and `007resort-booking-web` toward maintaining their own copies of business data — exactly what the specification forbids ("PHP must not independently perform core business operations", "other repositories must not maintain competing database schemas" — [spec §3, §9](../spec/)).

## Decision

Both Laravel applications carry **no business tables**. Framework-only concerns (sessions, cache, queue) use file/sync drivers, not a database, in Phase 1. All operational reads and writes go through `007resort-api`'s HTTP endpoints via a thin `R007ApiClient` service. Where reporting query volume genuinely does not fit comfortably through the REST API, the API exposes **read-only SQL views** and issues the PHP app a read-only, view-restricted database credential — never write access, and never a join against raw ledger tables ([04 §4](../architecture/04-database-schema.md#4-reporting-access)).

## Alternatives considered

- **Laravel owns a `users`/reporting database that mirrors API data.** Rejected: this is precisely the "competing schema" the spec prohibits, and it reintroduces the two-copies-of-the-truth problem this whole architecture exists to avoid ([ADR-0001](0001-api-is-the-single-business-engine.md)).
- **Laravel writes directly to the operational MySQL database for convenience (e.g. configuration screens).** Rejected: bypasses business rules, authorization and audit logging that only the API enforces; a config edit made this way would not be validated, versioned, or audited the same way as one made through the API.
- **No direct database access at all, even read-only; every report goes through a paginated API endpoint.** Considered as the purer version of this ADR. Not mandated, because some management reports are naturally expressed as SQL aggregations that would be inefficient or awkward to build purely through a paginated REST endpoint; the read-only view escape hatch is deliberately narrow and reviewed per view, not a general-purpose database connection.

## Consequences

- `007resort-admin-web` and `007resort-booking-web` scaffolding (already committed) removes the default Laravel `users` migration/model rather than adapting it, since there is no local user table.
- Every mutating admin action (approve a refund, change a price, suspend a membership) is implemented as a call to an API endpoint, keeping authorization and audit centralized even for actions initiated from the PHP UI.
- If reporting load later requires more than views can comfortably serve, the fix is a dedicated reporting replica or store, decided by a new ADR — not by quietly granting PHP write access.
