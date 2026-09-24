# Project Status

_Last updated: 2026-09-24_

## Summary

The 007 Resort & Spa platform MVP is built and merged into `main` across all eight repositories. The Laravel backend is verified end to end on a running local node; the mobile app, KDS, POS client layer, admin portal and booking website have each been run against that real backend. Remaining work is deployment to real hardware, hardware verification on Windows, and go-live configuration.

## Completed (all merged to `main`)

| Repository | What it is now |
| --- | --- |
| `007resort-api` | Laravel 13 backend (PHP, MySQL 8.4, Redis, Reverb). Modules: identity/auth/permissions/audit, organization and facility configuration, devices, catalog, orders/tabs/tables/approvals, KDS routing and realtime, payments (cash, split, Paystack, refunds/reversals, cash sessions, receipts), waiter bill/collection/confirmation/cash handover, inventory, booking/ticketing/entitlements, membership, attendance (ZKTeco), reporting, customer/public API, local-cloud sync engine (outbox/inbox/heartbeat/conflicts). About 690 tests on real MySQL plus a 107-check end-to-end smoke script. The earlier ASP.NET reference is kept under `legacy/` and tag `pre-laravel-migration-2026-09-22`. |
| `007resort-mobile` | Flutter Android app: enrolment, staff login, tablet checkout, attendant orders, supervisor approvals, Sports Entrance and Store, offline order queue, waiter bill and payment collection. Verified on an emulator against the real node. |
| `007resort-pos-desktop` | WPF POS: sell, tabs, split payments, approvals, receipts, Reception ticket/booking flow, encrypted offline queue, cashier-side confirmation of waiter collections. 25 real-node harness scenarios pass. **WPF screens not yet seen on Windows.** |
| `007resort-kds` | Browser KDS on Reverb/Echo, verified against the real node. |
| `007resort-admin-web` | Laravel admin portal: grouped sidebar shell, dashboard, tables, setup (facilities wizard, rules, catalog, roles, tickets, memberships, booking), waiter-collection admin, form-control library (toggles, sliders, ranges, money, etc.). 53 screens verified against the real API. |
| `007resort-booking-web` | Public website and customer portal on the real customer API. |
| `007resort-infrastructure` | Windows local-server installer (services, scheduler, backups), macOS/Linux demo-node script, Ubuntu VPS bootstrap/deploy/backup scripts, env templates, runbooks. **Not yet run on real Windows Server or a real VPS.** |
| `007resort-docs` | Architecture set, ADRs 0001–0014, OpenAPI contract, sync design, deployment specs, team brief. |

## Decisions (see `adr/`)

- Laravel backend, dual-node Local (Windows Server) and Cloud (Linux VPS) with transactional outbox/inbox sync — ADR-0012, ADR-0013, ADR-0014.
- Paystack as the payment provider (ADR-0009); tax/VAT admin-configurable (ADR-0011); ZKTeco biometric attendance.
- Waiters collect with a manual bank card machine for now, behind a terminal-adapter interface for a future integration. Waiter cash holding is configurable per facility and per waiter (default off). A waiter can never mark a bill paid; collections are pending until the cashier confirms or the provider auto-confirms.

## In progress / next

1. **Release:** tag `v0.1.0-mvp` on every repository once `main` CI is green on the merged code.
2. **Windows verification** of the POS (touch layout, printer, cash drawer, scanner, NFC) and a packaged installer.
3. **Property server:** install the local node on the real Windows Server with the infrastructure scripts; run the offline drills.
4. **Cloud VPS:** provision (owner action: account and billing), then bootstrap, deploy, TLS, backups and the local-to-cloud sync handshake.
5. **Go-live configuration:** real Paystack keys and webhook URL, real facility/product/price/staff data through the admin, staff NFC cards, device enrolment, training.
6. **Restore repositories to private** once branch protection is available (GitHub Pro or an Organization).

## Blockers and owner actions

- VPS purchase and account details (owner).
- Paystack live keys (owner).
- Real Windows hardware for POS verification.

## Known gaps

- Cloud-side appliers for some sync events (the newest waiter-collection events) are not yet built.
- Paystack refunds are recorded but not automatically called through the provider API.
- Guest checkout, e-mailed tickets and wallet passes are not built.
- Several configuration rules are stored and audited but not yet enforced by any runtime module (marked `planned` in the rule catalogue).

## Open questions

- None blocking.
