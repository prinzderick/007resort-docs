# 14 — API Module Map

Status: **DRAFT, awaiting review**. See [01 §5](01-architecture-overview.md#5-logical-architecture-a-modular-monolith) for the module diagram and [ADR-0002](../adr/0002-modular-monolith.md).

## 1. Solution/project layout (proposed)

```text
otueke-api/
  src/
    Otueke.Api/                # Host: composition root, routing, middleware, OpenAPI
    Otueke.SharedKernel/       # Result/Error, IClock, ids, money value objects
    Otueke.Contracts/          # Public DTOs shared with generated clients
    Otueke.Infrastructure/     # EF Core DbContext(s), Dapper helpers, outbox, migrations runner
    Modules/
      Otueke.Modules.Organization/
      Otueke.Modules.Identity/
      Otueke.Modules.Devices/
      Otueke.Modules.Catalog/
      Otueke.Modules.Orders/
      Otueke.Modules.Payments/
      Otueke.Modules.Hospitality/      # prep tickets / KDS routing
      Otueke.Modules.Inventory/
      Otueke.Modules.Booking/
      Otueke.Modules.Ticketing/
      Otueke.Modules.Membership/
      Otueke.Modules.Attendance/
      Otueke.Modules.Audit/
      Otueke.Modules.Sync/
      Otueke.Modules.Reporting/
  db/migrations/               # versioned SQL, single authoritative schema owner
  tests/
    Otueke.UnitTests/
    Otueke.IntegrationTests/   # WebApplicationFactory + Testcontainers MySQL
```

Each module exposes:

- **Application services** (the only entry point other modules or the host may call) — no cross-module repository access.
- **Its own EF Core mapping / tables** — another module never queries another module's tables directly; it calls the service, or reads a published **reporting view** for cross-cutting queries.
- **Integration events** published to the transactional outbox (e.g. `OrderSettled`, `StockDepleted`, `EntitlementRedeemed`) that other modules or SignalR hubs subscribe to, keeping modules decoupled while staying inside one process/deployment.

A module boundary is enforced by a lightweight architecture test (e.g. NetArchTest) in `Otueke.UnitTests`, failing CI if a module references another module's internals.

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
| KDS hub | `/hubs/kds?station={id}` | otueke-kds | Push new/changed prep tickets, status changes |
| Ops hub | `/hubs/ops?facilityUnitId={id}` | otueke-pos-desktop, otueke-mobile, otueke-admin-web (dashboard) | Order/table status, booking availability changes, device status |

Both hubs are thin notification channels — every mutation still goes through the REST API; SignalR never carries a state-changing command.

## 4. Hosting the two deployment modes

`Otueke.Api` reads `Otueke:DeploymentMode` (`Site` | `Cloud`) at startup and conditionally registers module services per [01 §4](01-architecture-overview.md#4-deployment-modes-of-the-api). This is a startup composition concern in the host project, not a fork of the codebase.
