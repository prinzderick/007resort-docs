# 18 — Testing Strategy

Status: **DRAFT, awaiting review**

## 1. By repository

| Repository | Levels |
| --- | --- |
| `007resort-api` | Unit (xUnit, domain/module logic in isolation) → Integration (`WebApplicationFactory` + Testcontainers MySQL 8.4, real schema, real transactions) → Authorization tests (every sensitive endpoint denied without permission, allowed with it, escalated to approval where configured) → Concurrency tests (§3) → Contract tests (OpenAPI snapshot diff) |
| `007resort-pos-desktop` | Unit (business-client logic, device abstraction implementations) → Integration (against a running `007resort-api` test instance, or a contract-mocked server) → Manual/exploratory UI pass per release |
| `007resort-mobile` | Unit (Dart) → Widget tests for critical workflows (attendant order flow, Sports Entrance result screen, Sports Store release flow) → API integration tests |
| `007resort-admin-web` / `007resort-booking-web` | Feature tests (Pest/PHPUnit) → Authorization/policy tests → Reporting tests (view output matches expected aggregates) → API integration tests (Http::fake plus a contract-mocked server) |
| `007resort-kds` | Routing tests (product/facility → station mapping) → State transition tests → Real-time update tests (SignalR reconnect/backfill behaviour) |

## 2. CI gating

Every repository's CI runs on every push and pull request to `main`: build, lint/format check, the test levels above appropriate to that stack, and a `gitleaks` secret scan. `007resort-api` additionally runs the OpenAPI snapshot check. A red pipeline blocks merge.

## 3. Critical concurrency tests (mandatory, tracked to completion before Phase 2 sign-off)

These are written as **integration tests that actually issue concurrent requests** against a real database transaction, not unit tests that assert intent:

| # | Scenario | Expected safe failure | Where |
| --- | --- | --- | --- |
| C-1 | Two users book the last available sports slot simultaneously | Exactly one `CONFIRMED`; the other gets `409 Conflict` | [10 §3](10-booking-state-model.md#3-preventing-the-two-users-one-final-slot-race) |
| C-2 | Two scanners redeem the same single-use ticket simultaneously | Exactly one `VALID`; the other gets `USED` | [11 §4](11-ticket-validation-model.md#4-preventing-double-redemption--the-concurrency-test-spec-26) |
| C-3 | Two staff release the same rental entitlement simultaneously | Exactly one release succeeds; the other is rejected as already released | Same pattern as C-2, applied to `RENTAL` items |
| C-4 | Two payment provider callbacks arrive for the same payment | Exactly one state transition is applied; the duplicate is a no-op | [04 §3.3](04-database-schema.md#33-provider_event-and-idempotency_record--duplicate-payment-protection), [07 §4](07-payment-state-model.md#4-duplicate-payment-protection-spec-26) |
| C-5 | A client retries a mutating request after a dropped response (duplicate API request) | The retried request returns the original result; no duplicate effect | `Idempotency-Key` / `idempotency_record`, same references |
| C-6 | Two terminals sell the last unit of stock concurrently | Exactly one sale succeeds; the other gets a clear insufficient-stock error | [09 §3](09-inventory-movement-model.md#3-concurrency-the-last-unit-test) |

Each test asserts the database-level invariant directly (row counts, constraint behaviour), not just the HTTP response, so a future refactor that accidentally removes the guarding constraint or lock is caught even if the service-layer code still "looks" correct.

## 3.1 Distributed-system test scenarios (dual-node — mandatory, tracked to completion before Phase 9 sign-off)

Added per [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md); these require an actual Local + Cloud pair (or a faithful local simulation of both) exchanging real sync traffic, not mocks of "the other node":

| # | Scenario | Expected safe outcome | Where |
| --- | --- | --- | --- |
| D-1 | Property internet disconnects during Restaurant operation | Orders, KDS and local cash continue uninterrupted; events queue in the outbox and drain once connectivity returns | [Failure Mode Matrix](24-failure-mode-matrix.md), [Outbox/Inbox Design](sync/outbox-inbox-design.md) |
| D-2 | Online customer and Reception attempt the final sports slot simultaneously | Exactly one valid booking is produced | [Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md) §2 |
| D-3 | Local is offline; Reception books using the offline allocation reserve | Booking succeeds within the reserve; reconnection reconciles without overbooking | [Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md) §3.A |
| D-4 | Cloud transmits the same event three times (retry storm) | Local applies it exactly once | [Outbox/Inbox Design](sync/outbox-inbox-design.md) §3, `inbox_event.event_id` uniqueness |
| D-5 | Local transmits the same payment event three times | Cloud records exactly one payment | Same mechanism as D-4, applied to `PaymentCompleted` |
| D-6 | Events arrive out of order for the same entity | Entity state remains valid; the out-of-order event is deferred and retried, not corrupted | [Outbox/Inbox Design](sync/outbox-inbox-design.md) §4, entity-version check |
| D-7 | Online payment succeeds while Local is temporarily disconnected | Payment remains recorded at Cloud and safely queued; syncs to Local once reconnected; never lost | [Domain Authority Matrix](23-domain-authority-matrix.md), `OnlinePaymentConfirmed` |
| D-8 | Local heartbeat becomes stale beyond the configured threshold | Immediate online ordering is disabled per policy; the rest of the website remains fully functional | [Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md) §4, [Heartbeat / Node Health](sync/heartbeat-and-node-health.md) |
| D-9 | Redis/queue worker temporarily stops on either node | Already-committed transactions are not lost; sync resumes once the worker restarts | [Outbox/Inbox Design](sync/outbox-inbox-design.md) §2, [Failure Mode Matrix](24-failure-mode-matrix.md) |
| D-10 | Local and Cloud configuration versions conflict (the same product/price/rule edited on both) | The stale-versioned event is rejected as `CONFIGURATION_CONFLICT`, not silently overwritten; recorded for manual review | [Conflict Resolution Matrix](sync/conflict-resolution-matrix.md) |
| D-11 | Two scanners attempt to redeem the same single-use ticket | Exactly one succeeds (same as C-2, restated here because it's also a dual-node-adjacent guarantee — validation stays Local-authoritative regardless of Cloud's state) | [Domain Authority Matrix](23-domain-authority-matrix.md), [11 §4](11-ticket-validation-model.md#4-preventing-double-redemption--the-concurrency-test-spec-26) |
| D-12 | Two staff attempt to release the same rental entitlement | Exactly one valid release occurs (same as C-3, restated for the same reason as D-11) | [Domain Authority Matrix](23-domain-authority-matrix.md) |
| D-13 | Payment provider sends duplicate webhook callbacks | Exactly one payment is recorded at Cloud | `provider_event` uniqueness, unchanged from [04 §3.3](04-database-schema.md#33-provider_event-and-idempotency_record--duplicate-payment-protection) |
| D-14 | Local database backup is restored in a test environment | Restore succeeds; the restored instance resumes syncing cleanly (no duplicate-event storm on reconnect, since `inbox_event`/`outbox_event` state restores consistently with the business data) | [26 — Windows Local Server Deployment Spec](26-windows-local-server-deployment.md) §5 |
| D-15 | Cloud database backup is restored in a test environment | Same as D-14, for the Cloud node | [25 — VPS Production Deployment Spec](25-vps-production-deployment.md) §6 |

## 4. Acceptance testing (property-level, pre-go-live)

Traces directly to [spec §20 Acceptance Criteria](../spec/): every configured facility transacts per its rules; Reception processes pool/sports/sports-store/pool-bar payments correctly; restaurant/club/bar orders route correctly to KDS/dispensing; sports QR cannot be redeemed twice and equipment issue/return is traceable; inventory reconciles Main Store → unit → sale; NFC/PIN permissions and supervisor approvals function; critical local operations continue during a simulated internet outage ([13](13-offline-strategy.md)); remote authorized users can access permitted functions securely; online bookings reflect internal availability with no uncontrolled double booking; backups restore in a controlled test; reports reconcile to underlying transactions and audit records.

## 5. Test data and environments

- Integration tests run against ephemeral Testcontainers MySQL instances seeded with the capability matrix ([05](05-facility-capability-model.md)) and a representative facility set, never against a shared or production-like database.
- A dedicated `staging` environment ([16 §3](16-deployment-topology.md#3-environments)) is used for end-to-end and training-environment testing ahead of pilot go-live.
