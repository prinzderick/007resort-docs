# ADR-0004: Versioned SQL migrations owned by 007resort-api; EF Core + Dapper split for data access

Status: Proposed (see [open question Q3](../architecture/20-open-questions.md))
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

The specification requires the database schema to have exactly one authoritative owner, and requires proper foreign keys, indexes, `CHECK` constraints, and reviewable, forward-only migrations. It does not mandate a specific ORM or migration tool.

## Decision

- **Migrations**: versioned, hand-reviewed SQL scripts in `007resort-api/db/migrations`, named `V{NNNN}__{description}.sql`, applied forward-only and never edited after merge. This keeps every schema change (including `CHECK` constraints and exact index definitions) explicit and reviewable in a pull request, independent of what any ORM would generate.
- **Data access**: EF Core for aggregate reads/writes where change-tracking and navigation properties genuinely simplify the module (Orders, Bookings, Inventory transfers); Dapper or raw parameterized SQL for the highest-contention conditional updates (stock deduction, entitlement redemption — [04 §3](../architecture/04-database-schema.md#3-highest-risk-tables-in-detail)) where the exact statement shape *is* the correctness guarantee, and for reporting queries where a hand-tuned query matters.

## Alternatives considered

- **EF Core Migrations** for schema changes. Rejected as the primary mechanism: EF's generated migrations are workable for straightforward column/table changes but are less transparent for MySQL-specific detail (exact `CHECK` constraints, `utf8mb4` collation choices, `BINARY(16)` mapping) that this schema depends on; hand-written SQL keeps that detail explicit in review.
- **Dapper/raw SQL everywhere.** Rejected as the sole approach: for aggregates with many related child rows (an order with lines, adjustments, voids), EF Core's unit-of-work meaningfully reduces boilerplate and mapping bugs.
- **DbUp** as the migration runner. Still a candidate purely as the *runner* that applies the versioned SQL scripts at startup/deploy; the choice of runner does not change the "hand-written SQL, forward-only" decision above and is left open for the first implementation PR.

## Consequences

- Contributors need to be comfortable writing SQL directly for schema changes and for the contention-critical statements; this is called out in `007resort-api/CONTRIBUTING.md`.
- The migration review is a required step in every pull request that touches `db/migrations/` ([`007resort-api` PR template](https://github.com/prinzderick/007resort-api)).
- This ADR will be finalized (moved to Accepted) once the first real migration is written and the runner is chosen; see [20 Q3](../architecture/20-open-questions.md).
