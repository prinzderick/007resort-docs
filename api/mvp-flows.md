# MVP demo slice — exact endpoint sequences

Reference: [`openapi/v1.yaml`](openapi/v1.yaml). All calls below are relative to `/api/v1`, carry `X-Device-Token` (except where noted), and every `POST`/`PUT`/`DELETE` also carries a fresh `Idempotency-Key`. Ids in examples are abbreviated.

## Flow A — Attendant: table order to payment

| # | Actor | Call | Result / notes |
| --- | --- | --- | --- |
| 1 | App | `GET /system/info` (public) | Check `minClientVersion`, `deploymentMode`, realtime endpoint |
| 2 | Attendant | `POST /auth/staff/login` `{credentialType:"PIN", identifier:"S-0042", secret:"4821"}` | `accessToken`, `refreshToken`, `staff.permissions[]`, `session.id` |
| 3 | Attendant | `POST /devices/{deviceId}/checkout` `{staffId, facilityId, shiftId}` | Tablet bound to staff + facility + shift |
| 4 | Cashier | `POST /cash-sessions` `{facilityId, openingFloat:"0.0000"}` | Needed before cash tenders when the facility rule `requireCashSession` is true |
| 5 | App | `GET /facilities/{facilityId}/capabilities` | Operating rules (approval threshold, offline policy) |
| 6 | App | `GET /catalog/categories`, `GET /catalog/products?facilityId=` | Cache menu (use `updatedSince` to refresh, ETag on list) |
| 7 | App | `GET /tables?facilityId=` | Table map |
| 8 | App | Connect Reverb; `POST /broadcasting/auth` for `private-facility.{id}.orders` and `private-device.{id}` | See [`realtime.md`](realtime.md) |
| 9 | Attendant | `POST /tables/{tableId}/open` | Table OCCUPIED |
| 10 | Attendant | `POST /orders` `{facilityId, tableId, channel:"DINE_IN", lines:[...]}` | `201` DRAFT order, `ETag` |
| 11 | Attendant | `POST /orders/{id}/lines` (optional) / `DELETE /orders/{id}/lines/{lineId}` (optional), with `If-Match` | Edit while DRAFT |
| 12 | Attendant | `POST /orders/{id}/send` with `If-Match` | SENT; PrepTickets created; events `prep-ticket.created`, `order.updated` |
| 13 | Kitchen (KDS) | `POST /auth/staff/login`, then `GET /kds/stations?facilityId=`, `GET /kds/stations/{stationId}/tickets`; subscribe `private-kds.station.{stationId}` | Live board |
| 14 | Kitchen | `POST /prep-tickets/{id}/transition` `{to:"ACCEPTED"}` then `{to:"IN_PROGRESS"}` | Order becomes IN_PREPARATION |
| 15 | Kitchen | `POST /prep-tickets/{id}/transition` `{to:"READY"}` | Order READY; `order.ready` pushed to attendant |
| 16 | Attendant | `POST /orders/{id}/serve` | Order SERVED (tickets DISPENSED) |
| 17 | Attendant | `POST /tabs` `{facilityId, tableId}` then `POST /tabs/{tabId}/orders` `{orderIds:[...]}` | Optional: put the table's orders on a tab |
| 18 | Cashier | `POST /tabs/{tabId}/settle` `{tenders:[...], cashSessionId}` **or** `POST /payments` `{allocations, tenders}` | Payments CAPTURED, orders SETTLED, `receiptId` returned; split by adding tenders |
| 19 | Cashier | `GET /receipts/{receiptId}` | Print receipt |
| 20 | Cashier | `POST /cash-sessions/{id}/close` `{countedCash}` | End of shift; then `POST /devices/{id}/checkin` and `POST /auth/staff/logout` |

### Flow A2 — Supervisor approves a void

| # | Actor | Call | Result / notes |
| --- | --- | --- | --- |
| 1 | Attendant | `POST /orders/{id}/void` `{reason}` with `If-Match` | `202` `ApprovalOutcome` (order `PENDING_APPROVAL`) unless attendant holds approve permission |
| 2 | Supervisor device | `approval.requested` on `private-device.{id}`, or `GET /approvals?scope=approvable` | Pending list |
| 3 | Supervisor | `POST /approvals/{approvalId}/decision` `{decision:"APPROVE"}` (own session) | Order VOIDED, stock and tickets reversed; `approval.decided` to attendant device |
| 3b | Alternative inline | Attendant hands tablet over: `POST /auth/staff/step-up` (supervisor PIN, `permission:"order.void.approve"`), then repeat step 1 with `X-Step-Up-Token` | `200` order VOIDED immediately |

## Flow B — Sports: booking, QR, entrance, store

| # | Actor | Call | Result / notes |
| --- | --- | --- | --- |
| 1 | Reception | `POST /auth/staff/login`; `POST /devices/{id}/checkout` | Facility = Reception |
| 2 | Reception | `GET /bookings/resources?facilityId=`, `GET /bookings/resources/{id}/availability?from=&to=` | Slots |
| 3 | Reception | `POST /bookings/hold` | `201` HELD with `holdExpiresAt`; `409 slot_unavailable` if lost the race |
| 4 | Reception | `POST /bookings/{id}/confirm` `{tenders, cashSessionId}` with `If-Match` | CONFIRMED; payment + receipt; entitlement issued (`entitlementId`) |
| 5 | Reception | `GET /entitlements/{entitlementId}` | `qrToken`; print/show QR |
| 6 | Entrance scanner | `POST /devices/{id}/checkout` (facility = Sports Entrance); scan QR; `POST /entitlement-tokens/{qrToken}/redeem` `{action:"ENTRY"}` | `result` in `VALID`, `USED`, `EXPIRED`, `WRONG_FACILITY`, `NOT_YET_VALID`, `CANCELLED` (always HTTP 200) |
| 7 | Store attendant | Scan QR; `GET /entitlement-tokens/{qrToken}` | Shows what was paid/rented |
| 8 | Store attendant | `POST /entitlements/{entitlementId}/release` `{itemIds}` | Rental items RELEASED |
| 9 | Store attendant | `POST /entitlements/{entitlementId}/return` `{itemIds, condition}` | Items RETURNED (`DAMAGED`/`LOST` may carry `damageCharge`) |
| 10 | Reception | `POST /bookings/{id}/reschedule` or `/cancel` (optional) | Per policy |

## Minimal call order for the first demo

1. `GET /system/info`
2. `POST /auth/staff/login`
3. `POST /devices/register` (once per device, before step 2 on a new tablet; uses the registration code)
4. `POST /devices/{id}/checkout`
5. `GET /catalog/products`, `GET /tables`
6. `POST /orders`, `POST /orders/{id}/send`
7. KDS: `GET /kds/stations/{id}/tickets`, `POST /prep-tickets/{id}/transition`
8. `POST /orders/{id}/serve`, `POST /payments`
9. `POST /orders/{id}/void`, `POST /approvals/{id}/decision`
10. `POST /bookings/hold`, `POST /bookings/{id}/confirm`, `POST /entitlement-tokens/{qrToken}/redeem`, `POST /entitlements/{id}/release`, `POST /entitlements/{id}/return`
