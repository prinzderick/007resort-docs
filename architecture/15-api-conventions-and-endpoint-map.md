# 15 — API Conventions and Initial Endpoint Map

Status: **DRAFT, awaiting review**

## 1. Conventions

| Concern | Rule |
| --- | --- |
| Versioning | URL-segment versioning: `/api/v1/...`. A breaking change ships as `/api/v2/...` with a documented deprecation window for v1 |
| Documentation | OpenAPI 3.1, generated from the code, published as a build artifact and checked into review as a diffable snapshot |
| Request/response | JSON, `camelCase` properties, ISO-8601 UTC (`...Z`) timestamps, money as a **decimal string** (`"amount": "1500.0000", "currency": "NGN"`), ids as canonical UUID strings |
| Errors | RFC 7807 `application/problem+json` — `type`, `title`, `status`, `detail`, `instance`, plus an `errors` map for field-level validation errors and a stable `code` for programmatic handling |
| Auth errors | `401` (not authenticated), `403` with a `problem.code` of `permission_denied` or `approval_required` (never a bare 403 with no reason a client can act on) |
| Pagination | Cursor-based: `?limit=50&cursor=...`, response envelope `{ items: [...], nextCursor: string \| null }` |
| Filtering/sorting | `?filter[field]=value`, `?sort=-createdAt,field` — documented per endpoint, not a generic passthrough to SQL |
| Idempotency | `Idempotency-Key` header **required** on every non-idempotent mutating request (`POST` that creates, and any endpoint explicitly marked mutating); missing header on a marked endpoint is a `400` |
| Concurrency | `ETag` / `If-Match` (backed by `row_version`) on updates to mutable aggregates; mismatch is `409 Conflict` with `problem.code = concurrency_conflict` |
| DTOs | Contracts in `R007.Contracts`; entities are never serialized directly |
| Correlation | `X-Correlation-Id` accepted and echoed; generated if absent; flows into logs and traces |

## 2. Endpoint map (representative, not exhaustive — grows with the OpenAPI doc)

### System

| Method & path | Purpose |
| --- | --- |
| `GET /health/live`, `GET /health/ready` | Liveness/readiness |
| `GET /api/v1/system/info` | Service name, `apiVersion`, `deploymentMode`, `minClientVersion` per client type |

### Identity & devices

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/auth/staff/login` | NFC/PIN or password login → session/access token |
| `POST /api/v1/auth/staff/step-up` | Re-auth for a sensitive action (supervisor PIN) |
| `POST /api/v1/auth/sessions/{id}/revoke` | Revoke a session/device |
| `POST /api/v1/devices/register`, `GET /api/v1/devices/{id}` | Device registration/lookup |
| `POST /api/v1/devices/{id}/checkout`, `POST /api/v1/devices/{id}/checkin` | Tablet checkout to staff/shift/facility |

### Catalog

| Method & path | Purpose |
| --- | --- |
| `GET /api/v1/catalog/products?facilityUnitId=` | Products available at a facility, with resolved price/tax |
| `GET /api/v1/facilities/{id}/capabilities` | Effective capabilities + operating rules for a facility |

### Orders & payments

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/orders` | Create draft order |
| `POST /api/v1/orders/{id}/lines`, `DELETE /api/v1/orders/{id}/lines/{lineId}` | Add/remove line (draft only) |
| `POST /api/v1/orders/{id}/send` | Lock lines, route to prep |
| `POST /api/v1/orders/{id}/void`, `POST /api/v1/orders/{id}/lines/{lineId}/adjustments` | Sensitive actions (may return `PENDING_APPROVAL`) |
| `POST /api/v1/tabs`, `POST /api/v1/tabs/{id}/settle` | Open-tab lifecycle |
| `POST /api/v1/payments` | Create a payment against order(s)/tab (Idempotency-Key required) |
| `POST /api/v1/payments/{id}/refund`, `POST /api/v1/payments/{id}/reversal` | Corrections |
| `POST /api/v1/payments/webhooks/{provider}` | Provider callback inbox (signature-verified) |

### Hospitality / KDS

| Method & path | Purpose |
| --- | --- |
| `GET /api/v1/kds/stations/{id}/tickets` | Current board (also pushed via SignalR) |
| `POST /api/v1/prep-tickets/{id}/transition` | `ACCEPTED`/`IN_PROGRESS`/`READY`/`DISPENSED` |

### Inventory

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/inventory/purchase-receipts` | Receive into Main Store |
| `POST /api/v1/inventory/transfers` | Main Store → facility |
| `POST /api/v1/inventory/adjustments` | Sensitive action |
| `POST /api/v1/inventory/counts`, `POST /api/v1/inventory/counts/{id}/post` | Physical count → variance |
| `GET /api/v1/inventory/balances?locationId=` | Current balances |

### Booking, ticketing, membership

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/bookings/hold`, `POST /api/v1/bookings/{id}/confirm` | Hold → confirm |
| `POST /api/v1/bookings/{id}/cancel`, `POST /api/v1/bookings/{id}/reschedule` | Per policy |
| `GET /api/v1/resources/{id}/availability?from=&to=` | Shared by Reception and booking-web |
| `POST /api/v1/entitlements/{id}/redeem` | Ticket/entitlement validation (Sports Entrance, Pool) |
| `GET /api/v1/entitlements/{id}` | Sports Store lookup ("what was paid/rented") |
| `POST /api/v1/entitlements/{id}/release`, `POST /api/v1/entitlements/{id}/return` | Equipment issue/return |
| `POST /api/v1/memberships`, `POST /api/v1/memberships/{id}/renew`, `POST /api/v1/memberships/{id}/suspend` | Membership lifecycle |

### Attendance & audit

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/attendance/punches` (device-integration) | Biometric clock-in/out |
| `GET /api/v1/audit?entityType=&entityId=` | Audit trail lookup (permissioned) |

### Reporting (read-only)

| Method & path | Purpose |
| --- | --- |
| `GET /api/v1/reports/facility-daily-summary?date=&facilityUnitId=` | Owner dashboard feed |
| `GET /api/v1/reports/cashier-shift/{shiftId}` | Shift reconciliation |
| `GET /api/v1/reports/inventory-variance` | Stock count variance |

### Sync (site ↔ cloud only, mutually authenticated, not exposed to end-user clients)

| Method & path | Purpose |
| --- | --- |
| `POST /api/v1/sync/push` | Site → Cloud batch |
| `GET /api/v1/sync/pull` | Cloud → Site commands |

This list will grow as modules are implemented; the generated OpenAPI document is the source of truth once `007resort-api` exists.
