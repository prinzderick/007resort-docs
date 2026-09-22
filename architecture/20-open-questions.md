# 20 — Ambiguities and Open Questions

Status: most items below are now **Decided** as engineering recommendations (see each row) — treat them as `Proposed` in the same sense as the ADRs until you've reviewed this document set, but they no longer block work. A few genuinely need input only the client/owner can give and remain **Open**.

## Decided (engineering recommendation — see linked ADR/section)

| # | Question | Decision | Reference |
| --- | --- | --- | --- |
| Q1 | Which payment provider(s) will 007 Resort & Spa integrate for card/mobile money? | **Paystack** as the first concrete provider, behind an `IPaymentProviderAdapter` interface; Flutterwave designed-for as the second adapter. Pending the client's actual merchant account/commercial terms — development proceeds against sandbox keys | [ADR-0009](../adr/0009-payment-provider-selection.md) |
| Q2 | Cloud hosting provider and budget | **Microsoft Azure** (App Service + Azure Database for MySQL Flexible Server + Key Vault + Front Door), matching the .NET-heavy stack. Fallback: **DigitalOcean App Platform + Managed MySQL** if budget rules Azure out — no architecture change needed either way. Pending the client's budget sign-off; no cloud resources provisioned yet | [ADR-0010](../adr/0010-cloud-hosting-platform.md) |
| Q3 | EF Core vs. hand-written SQL split, and the exact migration tool | **DbUp**, applying versioned SQL scripts from `db/migrations/`; EF Core for aggregate writes, Dapper/raw SQL for the highest-contention updates and reporting reads — as originally proposed here, now confirmed by the Phase 1 core-API implementation | [ADR-0004](../adr/0004-schema-migrations-and-data-access.md) (to be moved from `Proposed` to `Accepted` once the Phase 1 PR merges) |
| Q4 | Individual-capacity booking: one `slot_allocation` row per capacity unit, or a counter with a row-locked check? | **One row per unit**, as originally proposed — same mechanism as whole-resource/time-slot booking, one invariant to test. Revisit only if a resource's capacity count grows into the hundreds and the row volume becomes a real concern | [10 §2](10-booking-state-model.md#2-booking-modes) |
| Q6 | Whether online payments require the property to be online at booking time, or a provisional online-only quota is pre-allocated | **No pre-allocated quota for Phase 1.** Online booking requires the site to be reachable (consistent with [ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md) — one true booking ledger, no cross-node double-booking risk). A brief "booking temporarily unavailable, please try again shortly" state during a site outage is an acceptable, honest degradation for a leisure property; revisit only if the business sees material lost online revenue from short outages | [12](12-sync-strategy.md), [ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md) |
| Q8 | Notification channels (SMS/email/push) for booking confirmations and staff alerts | **Email first** (booking confirmations, cancellations, staff digest alerts) via a standard transactional email provider, behind an `INotificationSender` abstraction supporting multiple channels. **SMS as a fast-follow** once a Nigerian SMS provider (e.g. Termii or Africa's Talking) is selected — same abstraction, additive, no redesign. Push notifications deferred until/unless a customer-facing mobile app (beyond the internal Flutter operations app) exists | — (tracked as a Phase 6/8 implementation detail, not a separate ADR) |
| Q9 | Whether `007resort-admin-web` and `007resort-booking-web` share a Laravel package for the API client, or duplicate it | **Keep duplicated for now.** Extracting a shared `007resort/api-client` Composer package before the API's contract has stabilized risks premature abstraction and a versioning dependency between two apps that otherwise evolve independently. Revisit as a refactor once Phase 2 (Catalog/Orders/Payments endpoints) lands and the client's real shape is proven in both apps | [ADR-0007](../adr/0007-php-apps-are-api-clients-without-business-data.md) |

## Open — needs client/owner input, not urgent yet

| # | Question | When it needs an answer |
| --- | --- | --- |
| Q5 | Exact biometric attendance terminal model/SDK, to finalize the attendance adapter interface | Before Phase 9 (offline resilience/hardware integration hardening) — no earlier phase depends on the specific model |
| Q7 | Tax/accounting requirements (VAT registration status, receipt format requirements) | Before Phase 7 (PHP Admin finance/reporting) — receipt and settlement-reconciliation formats depend on this |

## Explicitly deferred by the spec itself

- The hotel PMS (rooms, reservations, housekeeping, key cards, folios) — Phase 1 excludes it; [03 §5](03-domain-model.md#5-future-hotel-pms-fit) records how the model accommodates it later ([spec §21](../spec/)).
- Recipe/BOM-based automatic ingredient consumption — noted as a later enhancement ([09 §4](09-inventory-movement-model.md#4-recipebom)).
- An additional network switch — only if final port count proves it necessary ([spec §15](../spec/)).

## Governance

Per [spec §22](../spec/), material additions beyond this specification are handled as controlled change requests, and a change to an already-accepted architectural decision is recorded as a new ADR that supersedes the old one — never a silent edit ([CONTRIBUTING.md](../CONTRIBUTING.md)). The "Decided" items above are engineering recommendations made without a formal review cycle, at the project owner's direction, to keep work moving — they remain open to being overridden by a superseding ADR if you disagree with any of them.
