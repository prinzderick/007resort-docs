# 18 — Testing Strategy

Status: **DRAFT, awaiting review**

## 1. By repository

| Repository | Levels |
| --- | --- |
| `otueke-api` | Unit (xUnit, domain/module logic in isolation) → Integration (`WebApplicationFactory` + Testcontainers MySQL 8.4, real schema, real transactions) → Authorization tests (every sensitive endpoint denied without permission, allowed with it, escalated to approval where configured) → Concurrency tests (§3) → Contract tests (OpenAPI snapshot diff) |
| `otueke-pos-desktop` | Unit (business-client logic, device abstraction implementations) → Integration (against a running `otueke-api` test instance, or a contract-mocked server) → Manual/exploratory UI pass per release |
| `otueke-mobile` | Unit (Dart) → Widget tests for critical workflows (attendant order flow, Sports Entrance result screen, Sports Store release flow) → API integration tests |
| `otueke-admin-web` / `otueke-booking-web` | Feature tests (Pest/PHPUnit) → Authorization/policy tests → Reporting tests (view output matches expected aggregates) → API integration tests (Http::fake plus a contract-mocked server) |
| `otueke-kds` | Routing tests (product/facility → station mapping) → State transition tests → Real-time update tests (SignalR reconnect/backfill behaviour) |

## 2. CI gating

Every repository's CI runs on every push and pull request to `main`: build, lint/format check, the test levels above appropriate to that stack, and a `gitleaks` secret scan. `otueke-api` additionally runs the OpenAPI snapshot check. A red pipeline blocks merge.

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

## 4. Acceptance testing (property-level, pre-go-live)

Traces directly to [spec §20 Acceptance Criteria](../spec/): every configured facility transacts per its rules; Reception processes pool/sports/sports-store/pool-bar payments correctly; restaurant/club/bar orders route correctly to KDS/dispensing; sports QR cannot be redeemed twice and equipment issue/return is traceable; inventory reconciles Main Store → unit → sale; NFC/PIN permissions and supervisor approvals function; critical local operations continue during a simulated internet outage ([13](13-offline-strategy.md)); remote authorized users can access permitted functions securely; online bookings reflect internal availability with no uncontrolled double booking; backups restore in a controlled test; reports reconcile to underlying transactions and audit records.

## 5. Test data and environments

- Integration tests run against ephemeral Testcontainers MySQL instances seeded with the capability matrix ([05](05-facility-capability-model.md)) and a representative facility set, never against a shared or production-like database.
- A dedicated `staging` environment ([16 §3](16-deployment-topology.md#3-environments)) is used for end-to-end and training-environment testing ahead of pilot go-live.
