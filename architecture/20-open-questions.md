# 20 — Ambiguities and Open Questions

Status: **awaiting decisions from review**. Nothing here blocks Phase 0 scaffolding; several items block starting Phase 1 work in earnest and are flagged.

## Blocks Phase 1

| # | Question | Why it matters | Recommendation |
| --- | --- | --- | --- |
| Q1 | Which payment provider(s) will 007 Resort & Spa integrate for card/mobile money? | Shapes the `Payments` module's provider adapter, webhook signature scheme, and whether electronic tender works offline at all | Confirm with the client; design the provider adapter interface now, defer the concrete implementation to Phase 2 |
| Q2 | Cloud hosting provider and budget | Shapes [16 §2](16-deployment-topology.md#2-cloud) concretely (managed MySQL choice, container runtime, secret manager) | Keep the topology provider-agnostic until decided; do not block Phase 0–1 on it |
| Q3 | EF Core vs. hand-written SQL split, and the exact migration tool (DbUp vs. EF Core migrations) | Affects `007resort-api`'s `R007.Infrastructure` structure from the first commit | Proposed: EF Core for aggregate writes (Orders, Payments, Bookings, Inventory) where change-tracking and relationships help; Dapper/raw SQL for high-volume reporting reads and the hottest concurrency-guarded updates (stock, entitlement redemption) where an explicit, reviewable SQL statement is preferable to a generated one. Migrations as versioned SQL scripts either way, so the schema stays reviewable independent of ORM choice |
| Q4 | Individual-capacity booking: one `slot_allocation` row per capacity unit, or a counter with a row-locked check? | Affects the booking schema and the C-1 concurrency test design | Proposed: one row per unit (simpler invariant, same mechanism as whole-resource/time-slot booking); revisit if capacity numbers get very large (hundreds) |

## Should be resolved before Phase 6–8, not urgent now

| # | Question |
| --- | --- |
| Q5 | Exact biometric attendance terminal model/SDK, to finalize the attendance adapter interface |
| Q6 | Whether online payments require the property to be online at booking time, or whether a provisional online-only quota is pre-allocated to survive a site outage during checkout |
| Q7 | Tax/accounting requirements (VAT registration status, receipt format requirements) — flagged in [spec §22](../spec/) as confirmed during implementation |
| Q8 | Notification channels (SMS/email/push) for booking confirmations and staff alerts — not named in the spec |
| Q9 | Whether `007resort-admin-web` and `007resort-booking-web` share a Laravel package for the API client, or duplicate it (current scaffolding duplicates; revisit once both exist) |

## Explicitly deferred by the spec itself

- The hotel PMS (rooms, reservations, housekeeping, key cards, folios) — Phase 1 excludes it; [03 §5](03-domain-model.md#5-future-hotel-pms-fit) records how the model accommodates it later ([spec §21](../spec/)).
- Recipe/BOM-based automatic ingredient consumption — noted as a later enhancement ([09 §4](09-inventory-movement-model.md#4-recipebom)).
- An additional network switch — only if final port count proves it necessary ([spec §15](../spec/)).

## Governance

Per [spec §22](../spec/), material additions beyond this specification are handled as controlled change requests, and a change to an already-accepted architectural decision is recorded as a new ADR that supersedes the old one — never a silent edit ([CONTRIBUTING.md](../CONTRIBUTING.md)).
