# 20 — Ambiguities and Open Questions

Status: all items below are resolved. Q1, Q2, Q7 and Q9 were confirmed directly by the owner; the rest are engineering recommendations made at the owner's direction to keep work moving (see the Governance note).

## Accepted (confirmed by the owner)

| # | Question | Decision | Reference |
| --- | --- | --- | --- |
| Q1 | Which payment provider(s) will 007 Resort & Spa integrate for card/mobile money? | **Paystack**, behind an `IPaymentProviderAdapter` interface; Flutterwave designed-for as the second adapter. Confirmed by the owner. Development proceeds against sandbox keys until a merchant account exists | [ADR-0009](../adr/0009-payment-provider-selection.md) (Accepted) |
| Q2 | Cloud hosting provider and budget | **Budget Windows/.NET shared hosting to start** (e.g. SmarterASP.NET or equivalent — ASP.NET Core + MySQL on one cheap plan), confirmed by the owner over the original Azure/DigitalOcean recommendation for cost reasons. Azure remains the documented upgrade path once traffic, secret-management needs, or DR requirements outgrow shared hosting — no schema or app-code change needed to move | [ADR-0010](../adr/0010-cloud-hosting-platform.md) (Accepted) |
| Q5 | Exact biometric attendance terminal model/SDK | **ZKTeco**, confirmed by the owner — the most common brand for this in Nigeria, with push-to-server integration options that fit the local-first architecture | [architecture/18](18-testing-strategy.md), attendance adapter interface (to be built against ZKTeco's SDK/push protocol in the Attendance module) |
| Q7 | Tax/accounting requirements (VAT registration status, receipt format) | **Admin-settable**, not a fixed build decision, per the owner: `vat_registered` + `default_vat_rate` + TIN as an organization-level setting editable in `007resort-admin-web`, defaulting to VAT off | [ADR-0011](../adr/0011-tax-configuration-is-admin-settable.md) (Accepted) |
| Q9 | Whether `007resort-admin-web` and `007resort-booking-web` share a Laravel package for the API client, or duplicate it | **Keep duplicated for now**, confirmed direction — extracting a shared package before the API's contract has stabilized risks premature abstraction. Revisit once Phase 2 endpoints land and the client's real shape is proven in both apps | [ADR-0007](../adr/0007-php-apps-are-api-clients-without-business-data.md) |

## Decided (engineering recommendation, not separately confirmed)

| # | Question | Decision | Reference |
| --- | --- | --- | --- |
| Q3 | EF Core vs. hand-written SQL split, and the exact migration tool | **DbUp**, applying versioned SQL scripts from `db/migrations/`; EF Core for aggregate writes, Dapper/raw SQL for the highest-contention updates and reporting reads. Confirmed working by the Phase 1 core-API implementation, including a real MySQL 8.4 run of the migration | [ADR-0004](../adr/0004-schema-migrations-and-data-access.md) (to be moved from `Proposed` to `Accepted` once the Phase 1 PR merges) |
| Q4 | Individual-capacity booking: one `slot_allocation` row per capacity unit, or a counter with a row-locked check? | **One row per unit** — same mechanism as whole-resource/time-slot booking, one invariant to test. Revisit only if a resource's capacity count grows into the hundreds | [10 §2](10-booking-state-model.md#2-booking-modes) |
| Q6 | Whether online payments require the property to be online at booking time, or a provisional online-only quota is pre-allocated | **No pre-allocated quota for Phase 1** — online booking requires the site to be reachable, consistent with [ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md). A brief "booking temporarily unavailable" state during a site outage is an acceptable trade-off; revisit only if material online revenue is lost to short outages | [12](12-sync-strategy.md), [ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md) |
| Q8 | Notification channels (SMS/email/push) for booking confirmations and staff alerts | **Email first**, via a standard transactional provider, behind an `INotificationSender` abstraction. **SMS as a fast-follow** (e.g. Termii or Africa's Talking) once selected — additive, no redesign. Push deferred until/unless a customer-facing mobile app exists | Tracked as a Phase 6/8 implementation detail, not a separate ADR |

## Explicitly deferred by the spec itself

- The hotel PMS (rooms, reservations, housekeeping, key cards, folios) — Phase 1 excludes it; [03 §5](03-domain-model.md#5-future-hotel-pms-fit) records how the model accommodates it later ([spec §21](../spec/)).
- Recipe/BOM-based automatic ingredient consumption — noted as a later enhancement ([09 §4](09-inventory-movement-model.md#4-recipebom)).
- An additional network switch — only if final port count proves it necessary ([spec §15](../spec/)).

## Governance

Per [spec §22](../spec/), material additions beyond this specification are handled as controlled change requests, and a change to an already-accepted architectural decision is recorded as a new ADR that supersedes the old one — never a silent edit ([CONTRIBUTING.md](../CONTRIBUTING.md)). The "Decided (engineering recommendation)" items were made without a separate confirmation round, at the owner's direction, to keep work moving — they remain open to being overridden by a superseding ADR if you disagree with any of them.
