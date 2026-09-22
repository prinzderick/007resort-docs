# 14 — API Module Map

Status: **DRAFT, awaiting review**. See [01 §5](01-architecture-overview.md#5-logical-architecture-a-modular-monolith) for the module diagram and [ADR-0002](../adr/0002-modular-monolith.md).

## 1. Solution/project layout (proposed)

```text
007resort-api/
  src/
    R007.Api/                # Host: composition root, routing, middleware, OpenAPI
    R007.SharedKernel/       # Result/Error, IClock, ids, money value objects
    R007.Contracts/          # Public DTOs shared with generated clients
    R007.Infrastructure/     # EF Core DbContext(s), Dapper helpers, outbox, migrations runner
    Modules/
      R007.Modules.Organization/
      R007.Modules.Identity/
      R007.Modules.Devices/
      R007.Modules.Catalog/
      R007.Modules.Orders/
      R007.Modules.Payments/
      R007.Modules.Hospitality/      # prep tickets / KDS routing
      R007.Modules.Inventory/
      R007.Modules.Booking/
      R007.Modules.Ticketing/
      R007.Modules.Membership/
      R007.Modules.Attendance/
      R007.Modules.Audit/
      R007.Modules.Sync/
      R007.Modules.Reporting/
  db/migrations/               # versioned SQL, single authoritative schema owner
  tests/
    R007.UnitTests/
    R007.IntegrationTests/   # WebApplicationFactory + Testcontainers MySQL
```

Each module exposes:

- **Application services** (the only entry point other modules or the host may call) — no cross-module repository access.
- **Its own EF Core mapping / tables** — another module never queries another module's tables directly; it calls the service, or reads a published **reporting view** for cross-cutting queries.
- **Integration events** published to the transactional outbox (e.g. `OrderSettled`, `StockDepleted`, `EntitlementRedeemed`) that other modules or SignalR hubs subscribe to, keeping modules decoupled while staying inside one process/deployment.

A module boundary is enforced by a lightweight architecture test (e.g. NetArchTest) in `R007.UnitTests`, failing CI if a module references another module's internals.

## 2. Module responsibilities

| Module | Owns | Publishes (integration events) | Depends on |
| --- | --- | --- | --- |
| Organization | Org/site/facility tree, capabilities, operating rules, operating points, resources | `FacilityConfigured` | — |
| Identity | Staff, accounts, credentials, roles, permissions, sessions, customers | `StaffAuthenticated`, `PermissionDenied` (security event) | Organization (scope) |
| Devices | Device registration, bindings, tablet checkout | `DeviceRegistered`, `DeviceRevoked` | Organization, Identity |
| Catalog | Products, prices, tax, availability, prep routes | `PriceChanged` | Organization |
| Orders | Orders, lines, tabs, shifts, voids/adjustments | `OrderSent`, `OrderSettled`, `OrderVoided` | Catalog, Identity, Devices |
| Payments | Payments, refunds, reversals, provider events, cash sessions, settlement | `PaymentCaptured`, `PaymentRefunded` | Orders |
| Hospitality | Prep tickets, KDS stations, SignalR hub `/hubs/kds` | `PrepTicketStatusChanged` | Orders, Catalog |
| Inventory | Items, locations, balances, movements, transfers, receipts, counts, rentals | `StockMovementPosted`, `StockBelowThreshold` | Organization, Catalog |
| Booking | Rules, availability, blackout, bookings, slot allocation | `BookingConfirmed`, `SlotReleased` | Organization, Orders |
| Ticketing | Ticket types, entitlements, redemptions, validation | `EntitlementRedeemed` | Booking, Orders |
| Membership | Plans, coverage, memberships, usage, member cards | `MembershipStatusChanged` | Organization |
| Attendance | Devices, biometric links, punches, derived days | `AttendanceRecorded` | Identity |
| Audit | Append-only audit log, approvals, security events | (consumer of all modules' events) | — |
| Sync | Outbox/inbox, checkpoints, conflicts, idempotency records | — | (infrastructure-level, used by all) |
| Reporting | Read-only views/materializations over the above | — | Reads only, via views |

## 3. Real-time (SignalR)

| Hub | Path | Consumers | Purpose |
| --- | --- | --- | --- |
| KDS hub | `/hubs/kds?station={id}` | 007resort-kds | Push new/changed prep tickets, status changes |
| Ops hub | `/hubs/ops?facilityUnitId={id}` | 007resort-pos-desktop, 007resort-mobile, 007resort-admin-web (dashboard) | Order/table status, booking availability changes, device status |

Both hubs are thin notification channels — every mutation still goes through the REST API; SignalR never carries a state-changing command.

## 4. Hosting the two deployment modes

`R007.Api` reads `R007:DeploymentMode` (`Site` | `Cloud`) at startup and conditionally registers module services per [01 §4](01-architecture-overview.md#4-deployment-modes-of-the-api). This is a startup composition concern in the host project, not a fork of the codebase.
