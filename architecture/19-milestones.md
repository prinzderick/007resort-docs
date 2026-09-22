# 19 — Implementation Milestones

Status: **DRAFT, awaiting review**. Phase numbering matches the client specification's development order ([spec §28](../spec/)).

| Phase | Scope | Definition of done (per [spec §31](../spec/) and [18](18-testing-strategy.md)) |
| --- | --- | --- |
| **0** | Repositories, architecture docs, database design, API contracts skeleton, dev environment, CI | This document set reviewed and approved; all 8 repos scaffolded with green CI; `otueke-infrastructure/compose/dev` runs MySQL 8.4 locally |
| **1** | Core API: auth, organization/facility model, staff/roles/permissions, device registration, audit framework | Endpoints tested (unit + integration + authorization); every mutation audited; OpenAPI published |
| **2** | Catalog, POS transactions, orders, payments, receipt/device abstractions | Concurrency tests C-4/C-5/C-6 pass; `otueke-pos-desktop` v1 processes a real sale end-to-end against a test API |
| **3** | Inventory: Main Store, transfers, facility stock, movement audit | Balance reconciles to movement ledger; C-6 passes against real transfer/sale flows |
| **4** | Hospitality: tables, tabs, KDS, real-time routing, waiter workflow | `otueke-kds` receives and transitions tickets in real time; routing tests green |
| **5** | `otueke-mobile`: attendants, supervisors, Sports Entrance, Sports Store | Widget tests for each mode; tablet checkout tracked end-to-end |
| **6** | Bookings, sports, ticketing, QR validation, memberships, appointments | C-1/C-2/C-3 pass; booking-web and Reception share one availability read |
| **7** | `otueke-admin-web`: finance, inventory reporting, staff, configuration, dashboards | Reporting reconciles to transactions/audit; no direct business-table writes from PHP |
| **8** | `otueke-booking-web`: public site, online booking, online payment, customer history | Payment provider integration tested with webhook idempotency (C-4) |
| **9** | Offline resilience, cloud synchronization, conflict handling, backup/recovery | Simulated internet-outage and LAN-outage tests pass ([13](13-offline-strategy.md)); backup restore tested |
| **10** | Full integration testing, pilot deployment, training environment, production deployment prep | Acceptance criteria ([18 §4](18-testing-strategy.md#4-acceptance-testing-property-level-pre-go-live)) all pass; staff trained; handover documentation complete |

Each phase closes with: schema/migration reviewed, business rule + authorization + audit implemented, client implementation working, validation and failure states tested, tests green in CI, documentation updated, no secrets committed — the Definition of Done in [spec §31](../spec/), tracked per feature in [`STATUS.md`](../STATUS.md).

Phase 0 is complete once this architecture set is approved (see [`STATUS.md`](../STATUS.md) for live status); Phase 1 does not start until that review closes out the items in [20](20-open-questions.md) that block it.
