# 23 — Domain Authority Matrix

Status: **DRAFT, awaiting review**. Companion to [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md).

## Purpose

For every domain, state which node commits the authoritative write, how the other node finds out, and — for shared/contended domains — the concurrency rule that prevents two simultaneous writers from both succeeding.

## Matrix

| Domain | Authoritative node | How the other node learns | Contended? | Concurrency rule |
| --- | --- | --- | --- | --- |
| Orders (in-person: POS/attendant) | **Local** | `OrderCreated`/`OrderUpdated`/`OrderSettled` events sync to Cloud (reporting only) | No | Single-writer (one order, created and mutated only at Local) |
| Orders (online) | **Cloud** | `OnlineOrderCreated` syncs to Local for fulfilment | Only during immediate fulfilment — see [Booking Authority §4](sync/booking-authority-and-offline-allocation.md#4-immediate-online-orders) | Gated by heartbeat/availability policy before acceptance, not after |
| Payments (cash, in-person electronic) | **Local** | `PaymentCompleted`/`PaymentReversed` sync to Cloud | No | Single-writer |
| Payments (online, provider webhook) | **Cloud** | `OnlinePaymentConfirmed` syncs to Local | No (webhook idempotency handles duplicates; see [Event Catalogue](sync/event-catalogue.md)) | Provider `event_id` uniqueness, same pattern as the existing `provider_event` table design ([architecture/04 §3.3](04-database-schema.md#33-provider_event-and-idempotency_record--duplicate-payment-protection)) |
| KDS / prep ticket state | **Local** | Not synced to Cloud as operational state (only summarized in reporting) | No | Single-writer, real-time via Local's broadcast service |
| Inventory movements (receipt, transfer, sale, wastage, adjustment, count) | **Local** | `StockReceived`/`StockTransferred`/`StockConsumed`/`StockAdjusted` sync to Cloud (reporting) | No | Local row-lock/conditional-update, same mechanism already designed in [architecture/09 §3](09-inventory-movement-model.md#3-concurrency-the-last-unit-test) |
| Attendance (biometric clock-in/out) | **Local** | `StaffClockedIn`/`StaffClockedOut` sync to Cloud | No | Single-writer (one terminal) |
| Bookings — whole-resource / time-slot (sports, spa) | **Cloud when reachable; Local within its offline allocation when not** | See [Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md) | **Yes** | Atomic check-and-reserve at the authoritative point only; the non-authoritative node never independently confirms a shared-pool booking |
| Ticket / entitlement redemption (Sports Entrance, Pool, Sports Store release) | **Local** (validation happens physically, at the property) | `TicketRedeemed`/`RentalReleased`/`RentalReturned` sync to Cloud (reporting/audit) | No — contention is between two *local* scanners, not Local vs. Cloud | Local conditional-update on `entitlement_item.qty_redeemed`, exactly as already designed in [architecture/11 §4](11-ticket-validation-model.md#4-preventing-double-redemption--the-concurrency-test-spec-26); Cloud never redeems |
| Memberships — purchase | **Cloud** (online) or **Local** (Reception sells one in person) | Whichever node didn't originate it learns via `MembershipPurchased` | Only if the exact same membership record could be edited on both sides simultaneously (e.g. suspension) | Membership *status changes* (suspend/cancel) go through Cloud as the reporting/administrative authority once synced; a Local-in-person purchase is single-writer at creation |
| Membership — usage/visit tracking | **Local** (a visit happens physically) | `MembershipUsageRecorded` syncs to Cloud | No | Single-writer |
| Staff / roles / permissions | **Local is authoritative for day-to-day assignment** (a manager on-site assigns a shift role); **Cloud is authoritative for the master roster** created/edited remotely by Owner/Manager/Accounts | Two-way, version-checked | **Yes**, for the same staff record edited from both places | Version-counter conflict, per [Conflict Resolution Matrix](sync/conflict-resolution-matrix.md) — never last-writer-wins |
| Facility/product/price configuration | **Cloud is the primary edit point** (remote admin), **Local can also edit** (on-site correction) | Two-way, version-checked | **Yes** | Same version-counter conflict rule; configuration conflicts route to manual review, per [Conflict Resolution Matrix](sync/conflict-resolution-matrix.md) |
| Audit log | **Each node keeps its own append-only log for actions committed on it** | Local's audit entries sync to Cloud for consolidated reporting; never merged into one physical table across nodes | No | Append-only by construction — nothing to contend over |

## Rule of thumb

If a domain's write happens because **someone is physically at the property doing something** (serving food, redeeming a ticket, receiving stock, clocking in), it is Local-authoritative. If it happens because **someone is on the internet, away from the property** (booking online, paying online, browsing the site), it is Cloud-authoritative. The domains that don't fit that split cleanly — bookings, capacity, some configuration — are exactly the ones with an explicit rule above, not left to be inferred.
