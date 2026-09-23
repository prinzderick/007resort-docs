# 21 — Existing System Audit

Status: **snapshot as of 2026-09-22**, immediately before the Laravel backend migration and dual-node sync architecture pivot ([ADR-0012](../adr/0012-migrate-backend-to-laravel.md), [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md)). Every repository was tagged `pre-laravel-migration-2026-09-22` at the commit referenced below before this audit was written, so this state is always recoverable regardless of what happens next.

This audit is the source of truth for "what actually exists" going into the migration — it was produced by inspecting each repository directly (branches, commits, open PRs, file contents), not from memory of the plan.

## 1. otueke-api → `007resort-api` (ASP.NET Core — being replaced)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `71c1266` (main) |
| Open work | `feature/phase1-core-api` branch, [PR #1](https://github.com/prinzderick/007resort-api/pull/1) (open, not merged) |
| Stack | .NET 10, ASP.NET Core, EF Core + Dapper, DbUp migrations, MySQL 8.4 |

**On `main`:** Phase 0 scaffold only — host project, health/system-info endpoints, Serilog, OpenAPI/Scalar, `SharedKernel` (Result/Error/IClock), empty `Contracts`/`Infrastructure` projects, module-placeholder README. No business logic.

**On `feature/phase1-core-api` (unmerged):** a real, tested implementation —

- `db/migrations/V0001__initial_schema.sql`: Organization, Identity, Devices, Audit table groups (21 tables). Verified to apply cleanly against a real local MySQL 8.4 instance (not just the SQLite used in the PR's own test suite) — see the PR comment thread. Seeds 22 `capability_type` rows, 11 roles, 42 permissions, 122 role-permission bundle rows.
- DbUp migration runner, auto-applying in dev/site mode.
- `R007.Modules.Organization`: facility/capability read model, `GET /api/v1/facilities/{id}/capabilities`.
- `R007.Modules.Identity`: Argon2id password hashing, JWT access tokens + rotating refresh tokens in a revocable `session` table, permission-based `IAuthorizationHandler` (not role-name-based — has a passing test proving a "Manager"-named role without the specific permission is denied), login/step-up/session-revoke endpoints, role-assignment grant/revoke endpoints.
- `R007.Modules.Devices`: device registration with its own JWT credential, one worked example of combined staff+device authorization.
- `R007.Modules.Audit`: hash-chained `audit_log` (SHA-256 `prev_hash`/`row_hash` chain, with a tamper-detection test), wired into every mutation above.
- Idempotency-key middleware, applied to device registration and role-assignment endpoints.
- A NetArchTest module-boundary test.
- 41/41 tests passing (23 unit + 18 integration), CI green.

**API contracts actually implemented and consumed nowhere yet** (no client currently calls them — `007resort-pos-desktop`/`007resort-mobile`/`007resort-kds` only call the Phase 0 `GET /api/v1/system/info` stub): `POST /api/v1/auth/staff/login`, `POST /api/v1/auth/staff/step-up`, `POST /api/v1/auth/sessions/{id}/revoke`, `POST /api/v1/devices/register`, `GET /api/v1/devices/{id}`, `POST /api/v1/role-assignments` (grant/revoke), `GET /api/v1/facilities/{id}/capabilities`, `GET /api/v1/audit`.

**Reusable independent of backend language:** the migration SQL (`db/migrations/V0001__initial_schema.sql`) is portable — it's MySQL DDL, not EF Core-generated, so it survives a backend-language change essentially as-is (see [Migration Impact Assessment](22-migration-impact-assessment.md)). The domain rules it encodes (permission-based authorization model, hash-chained audit, seeded roles/permissions) are backend-agnostic and are exactly what Laravel needs to reimplement, just in PHP.

## 2. otueke-pos-desktop → `007resort-pos-desktop` (C#/.NET WPF — KEEP)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `a477980` (main) |
| Open work | none — all on `main` |
| Stack | .NET 10 WPF |

Phase 0 scaffold: placeholder `MainWindow`, `IOtuekeApiClient`/`R007ApiClient` calling only `GET /api/v1/system/info`, `IOfflineQueue` interface (unimplemented), five hardware device interfaces (`IReceiptPrinter`, `INfcReader`, `IBarcodeScanner`, `ICashDrawer`, `ICustomerDisplay`) each with a `Simulated*` implementation, 9 tests. **No order/payment/catalog logic exists yet** — nothing here depends on ASP.NET Core beyond the thin HTTP client, which only needs its base URL and response shapes preserved once Laravel exposes the same contract.

## 3. otueke-mobile → `007resort-mobile` (Flutter/Dart — KEEP)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `d1f9e2a` (main) |
| Open work | none |
| Stack | Flutter 3.44 / Dart, Android only |

Phase 0 scaffold: `DeviceMode` enum (unregistered/attendant/supervisor/sportsEntrance/sportsStore) parsed from an API string, `ApiClient` calling only `GET /api/v1/system/info`, one placeholder screen per mode, 8 tests. No attendant/order/QR logic implemented yet.

## 4. otueke-kds → `007resort-kds` (TypeScript/Vite kiosk — KEEP)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `605fa86` (main) |
| Open work | none |
| Stack | Vite + TypeScript, SignalR JS client |

Phase 0 scaffold: SignalR connection factory (`src/realtime/hub.ts`) pointed at a placeholder `/hubs/kds` path, a client-side ticket store applying upsert/remove events, config parsing, idempotency-key generation helper, 20 tests. **Uses SignalR specifically** — this is the one piece of Phase 0 work most directly tied to the ASP.NET/.NET real-time stack; Laravel's equivalent is Reverb (Laravel's first-party WebSocket server) or a compatible broadcasting driver, which changes the client's connection library, not its state-management logic (see [ADR-0013 §](../adr/0013-dual-node-local-cloud-sync.md)).

## 5. otueke-admin-web → `007resort-admin-web` (Laravel — no change needed, becomes closer to the backend)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `4e378af` (main) |
| Open work | none |
| Stack | Laravel 13, PHP 8.4+ |

Already Laravel, already has **no local business database** by design ([ADR-0007](../adr/0007-php-apps-are-api-clients-without-business-data.md)) and an `R007ApiClient` HTTP wrapper calling the (previously ASP.NET) API. `GET /health` endpoint, a dashboard placeholder, `NoBusinessTablesTest` enforcing the no-local-schema rule, 8 tests. **This repository requires no technology change** — it was always going to call "the API" over HTTP; only the thing on the other end of that HTTP call changes from ASP.NET Core to the (new) Laravel backend. Whether this admin app eventually merges into the backend Laravel codebase or stays a separate consuming app is an open question addressed in the [Migration Impact Assessment](22-migration-impact-assessment.md#6-should-007resort-admin-web--007resort-booking-web-merge-into-the-backend).

## 6. otueke-booking-web → `007resort-booking-web` (Laravel — same situation as admin-web)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `d65a143` (main) |
| Open work | none |
| Stack | Laravel 13, PHP 8.4+ |

Same shape as admin-web: no local business database, `R007ApiClient`, `GET /health`, a static facility-list placeholder home page, 8 tests. Same "no technology change required" conclusion.

## 7. otueke-infrastructure → `007resort-infrastructure` (config/scripts — needs the most rework)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `39def77` (main) |
| Open work | none |
| Stack | Docker Compose, PowerShell, YAML |

`compose/dev/docker-compose.yml`: MySQL 8.4 + Redis + Mailpit — **already includes Redis**, which the new architecture needs more heavily (queues, real-time coordination, sync coordination) rather than "where operationally justified" as originally scoped. `mysql/conf.d/r007.cnf` tuning. `env/site.env.example` / `env/cloud.env.example` assume an ASP.NET Core API process and IIS/Kestrel-shaped config keys (`R007__DeploymentMode`, `ConnectionStrings__R007`) — these need Laravel-shaped equivalents (`.env` `APP_ENV=local|cloud`, `DB_*`, `REDIS_*`, `QUEUE_CONNECTION`, `BROADCAST_CONNECTION`). `network/logical-segmentation.md` and the runbooks are backend-language-agnostic (VLANs, backup cadence, incident response) and mostly survive as-is. `scripts/windows/install-api-service.ps1` was written assuming a compiled .NET Windows Service — needs to become a PHP-FPM/Laravel-on-Windows service story (see [Windows Local Server Deployment Spec](26-windows-local-server-deployment.md)).

## 8. otueke-docs → `007resort-docs` (this repository)

| | |
| --- | --- |
| Tag | `pre-laravel-migration-2026-09-22` @ `6662f8b` (main) |
| Open work | [PR #1](https://github.com/prinzderick/007resort-docs/pull/1) — the full architecture set (`architecture/01`–`20`, `adr/0001`–`0011`, workflows, draft schema), decided and CI-green, **not yet merged** |

The architecture set in PR #1 was written assuming ASP.NET Core as the backend and a single-node-with-cloud-replica topology. Most of it is still valid (facility capability model, permission model, payment/order/booking/ticket state machines, domain model, database conventions) because those are business-domain decisions independent of backend language. What changes: [01](01-architecture-overview.md) §5-6 (backend stack, modular monolith framing), [02](02-repository-map.md) (stack column for `007resort-api`), [04](04-database-schema.md) (EF Core/DbUp references become Eloquent/Laravel migrations, though the actual DDL conventions — UUIDv7, DECIMAL money, `CHECK` constraints, hash-chained audit — are unaffected), [12](12-sync-strategy.md)/[13](13-offline-strategy.md) (superseded by the new dual-node event-sync design), [14](14-api-module-map.md) (module layout becomes Laravel `app/Domain/*`), [16](16-deployment-topology.md) (superseded by the VPS + Windows Local Server specs), [ADR-0002](../adr/0002-modular-monolith.md) (still valid as a *pattern*, now expressed in Laravel), [ADR-0004](../adr/0004-schema-migrations-and-data-access.md) (DbUp/EF Core → Laravel migrations/Eloquent + query builder).

## 9. Raw database replication / naive sync assumptions found

**None found as implemented code** — the only "sync" work that exists is the design in the (still-unmerged) [architecture/12-sync-strategy.md](12-sync-strategy.md), which already specified an outbox/inbox pattern with UUIDs and explicit conflict states, not raw MySQL master/master mirroring. [ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md) already rejected bidirectional replication in favor of an application-level channel. **This means the new dual-node event-sync design ([ADR-0013](../adr/0013-dual-node-local-cloud-sync.md)) is an extension and refinement of an already-correct direction, not a course correction from a wrong one** — no code exists yet that assumed naive mirroring, so there is nothing to unwind there.

## 10. Booking concurrency risk assessment

The `slot_allocation` table design ([architecture/04 §3.1](04-database-schema.md#31-slot_allocation--prevents-double-booking), draft DDL) already uses a unique constraint `(resource_id, unit_no, slot_start)` as the actual double-booking guard, and [architecture/10 §3](10-booking-state-model.md#3-preventing-the-two-users-one-final-slot-race) already required Reception and the booking website to share **one** booking engine and **one** table for this exact reason. This table does not yet exist in any implemented migration (Phase 1's `V0001` only covers Organization/Identity/Devices/Audit). **Risk**: once the dual-node architecture exists, this single-table-single-authority guarantee only holds if bookings have one authoritative node — which is exactly the domain-authority question [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md) and the [Domain Authority Matrix](23-domain-authority-matrix.md) resolve explicitly, rather than leaving to be discovered during Phase 6 implementation.

## 11. Online-order / local-offline risk assessment

No online-ordering code exists yet (Phase 8 in the original milestone plan). The risk this instruction flags — a cloud website accepting an "immediate fulfilment" order the property cannot actually act on during an outage — has no implemented code to audit, but is now addressed at the design level before that phase starts: see [Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md) §4 (Immediate Online Orders) and the [Heartbeat / Node Health spec](sync/heartbeat-and-node-health.md).

## 12. Existing Redis/queue/real-time work

`007resort-infrastructure`'s dev compose already runs Redis. No queue jobs, scheduled tasks, or broadcasting channels are implemented anywhere yet (nothing to port — this is greenfield for the Laravel backend). `007resort-kds`'s SignalR client is the only real-time *client* code that exists; it needs a new connection library (Laravel Echo + Reverb, or Pusher-protocol-compatible) but its internal ticket-store/state-application logic (`src/state/tickets.ts`) is transport-agnostic and does not need to change.

## 13. Tests that must survive the migration

| Test suite | Count | Migration impact |
| --- | --- | --- |
| `007resort-api` unit + integration (on `feature/phase1-core-api`) | 41 | **Scenarios must be ported to PHPUnit/Pest against the new Laravel implementation** — especially the "Manager without permission is denied" authorization test, the audit hash-chain + tamper-detection tests, and the idempotent-replay test. These are the highest-value tests in the whole codebase and are called out explicitly so they are not silently dropped |
| `007resort-pos-desktop` | 9 | Survive unchanged — they test the C#/.NET client, not the backend |
| `007resort-mobile` | 8 | Survive unchanged |
| `007resort-kds` | 20 | Survive unchanged, except any test asserting SignalR-specific connection behavior, which needs an Echo/Reverb-equivalent test |
| `007resort-admin-web` | 8 | Survive unchanged |
| `007resort-booking-web` | 8 | Survive unchanged |

See the [Migration Impact Assessment](22-migration-impact-assessment.md) for the repository-by-repository migration sequence and risk rating.
