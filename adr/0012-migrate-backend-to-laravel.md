# ADR-0012: Migrate the core backend from ASP.NET Core to Laravel/PHP

Status: Accepted
Date: 2026-09-22
Deciders: 007 Resort & Spa (owner)

## Context

[ADR-0001](0001-api-is-the-single-business-engine.md) established the ASP.NET Core API as the single business engine, and Phase 0/1 built real, tested infrastructure on that basis: a modular-monolith skeleton, a MySQL 8.4 migration, staff auth (Argon2id + JWT), permission-based authorization, a hash-chained audit log, and idempotency middleware — 41 passing tests, all documented in [21 — Existing System Audit](../architecture/21-existing-system-audit.md).

The owner has decided to change the backend to Laravel/PHP + MySQL 8.4 + Redis, based on deployment familiarity, hosting familiarity, existing PHP/MySQL operational experience, and reducing backend technology fragmentation (the admin and booking web apps are already Laravel; consolidating onto one backend language reduces the number of runtimes the team has to operate and hire for). This decision follows directly from [ADR-0010](0010-cloud-hosting-platform.md)'s choice of budget shared hosting, which is a far more natural fit for PHP than for ASP.NET Core.

**This was a valid architecture whose operational priorities have changed, not a mistake.** ASP.NET Core correctly modeled the domain (modular monolith, permission-based authorization, hash-chained audit, idempotency, UUIDv7/DECIMAL/UTC conventions) — none of that domain modeling is discarded; it is reimplemented in a different language, using the same schema and the same rules.

## Decision

The authoritative backend becomes **Laravel (current LTS-track release) + PHP 8.4+ + MySQL 8.4 + Redis**, replacing ASP.NET Core in `007resort-api`.

- The existing `007resort-api` repository is **reused**, not replaced. A migration branch (`architecture/laravel-migration` in this docs repo for the design phase; the equivalent implementation branch will be created in `007resort-api` itself before any Laravel code is written there) carries the work. The ASP.NET Core implementation is **not deleted** until the Laravel implementation reaches verified functional parity ([22 — Migration Impact Assessment](../architecture/22-migration-impact-assessment.md), cutover sequence).
- The MySQL 8.4 schema and its conventions ([ADR-0003](0003-identifier-and-money-conventions.md): UUIDv7 `BINARY(16)`, `DECIMAL(19,4)` money, `DATETIME(6)` UTC, `CHECK` constraints, hash-chained audit) are **unchanged** — the `V0001__initial_schema.sql` migration already written and verified against real MySQL 8.4 is portable SQL, not EF Core-generated, and is reused essentially as-is by Laravel's migration runner.
- The domain rules already built (permission-based authorization — not role-name-based; idempotency-key handling; audit-on-every-mutation) are **reimplemented with the same behavior**, verified by porting the existing test scenarios (see [21 §13](../architecture/21-existing-system-audit.md#13-tests-that-must-survive-the-migration)), not redesigned from scratch.
- Redis is added as infrastructure for queues, caching, rate limiting, and real-time coordination — **never** as authoritative storage for money, inventory, bookings, tickets, memberships, or orders ([ADR-0003](0003-identifier-and-money-conventions.md) already established MySQL as the source of truth for exactly this reason; Redis does not change that).
- [ADR-0002](0002-modular-monolith.md) (modular monolith, not microservices) **remains accepted** — Laravel's `app/Domain/{Organization,Identity,Catalog,Orders,Payments,Inventory,Booking,Ticketing,Membership,Attendance,Devices,Audit,Sync}` structure is the Laravel-native expression of the same module-boundary principle, not a departure from it.
- [ADR-0006](0006-client-technology-choices.md) (POS: WPF, KDS: browser kiosk) is **unaffected** — those decisions were about client technology, not backend language.
- [ADR-0007](0007-php-apps-are-api-clients-without-business-data.md) (admin-web/booking-web own no business data) **gets easier to honor accidentally**, and correspondingly needs restating: even though the admin/booking apps and the backend are now the same *language*, they remain architecturally separate consuming applications unless a later ADR explicitly decides to merge them (tracked in [22 §6](../architecture/22-migration-impact-assessment.md#6-should-007resort-admin-web--007resort-booking-web-merge-into-the-backend)) — proximity in language must not quietly erode the "clients call the API, they don't touch its tables" boundary.

## Alternatives considered

- **Keep ASP.NET Core, choose .NET-compatible hosting instead.** This was the original plan (Azure, [ADR-0010](0010-cloud-hosting-platform.md) draft). Superseded by the owner's explicit hosting-cost decision; keeping ASP.NET Core on budget shared hosting was assessed as workable but a worse fit than Laravel for that hosting tier, and the owner's stated reasons (deployment/hosting familiarity) are about the whole stack, not just where it runs.
- **Rewrite from scratch as a new repository/project.** Explicitly rejected by the owner's instructions and by this ADR: the existing repositories, commit history, and the already-verified MySQL schema are retained. A greenfield rewrite would throw away the schema verification work and the 41 passing tests' worth of already-proven domain behavior for no benefit.
- **Partial migration (keep ASP.NET Core for some modules, Laravel for others).** Rejected: splits the "one brain" principle ([ADR-0001](0001-api-is-the-single-business-engine.md)) across two runtimes indefinitely, which is exactly the fragmentation this decision is meant to reduce. A phased *cutover* (old system running until parity, then retired) is used instead of a permanent split.

## Consequences

- Every module beyond what Phase 1 already built (Catalog, Orders, Payments, Inventory, Booking, Ticketing, Membership, Attendance) is now built directly in Laravel — there is no ASP.NET Core Phase 2+ work to discard, since Phase 1 is the only phase with real implementation so far.
- The Phase 1 ASP.NET Core PR ([007resort-api#1](https://github.com/prinzderick/007resort-api/pull/1)) is **not merged as ASP.NET Core code**. It remains open and tagged (`pre-laravel-migration-2026-09-22`) as the reference implementation the Laravel port must match behaviorally, then is closed once the Laravel equivalent has verified parity — not deleted, closed with a comment pointing to its replacement.
- `007resort-pos-desktop`, `007resort-mobile`, `007resort-kds`, `007resort-admin-web`, `007resort-booking-web` need **no rewrite** — they are HTTP/WebSocket clients of "the API," and only need the contract preserved (see [ADR-0013](0013-dual-node-local-cloud-sync.md) and the migration cutover plan for exactly how contract compatibility is verified before cutover).
- `007resort-kds`'s real-time transport moves from ASP.NET SignalR to Laravel Reverb (or a Pusher-protocol-compatible broadcaster) — a connection-library change in the KDS client, not a redesign of its ticket-state logic.
- This ADR does not by itself decide the dual-node local/cloud architecture — that is [ADR-0013](0013-dual-node-local-cloud-sync.md), a related but separable decision (Laravel could in principle run single-node; the dual-node decision stands on its own operational reasoning).
