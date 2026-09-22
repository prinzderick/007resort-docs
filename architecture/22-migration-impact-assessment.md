# 22 — Migration Impact Assessment

Status: **DRAFT, awaiting review**. Built on the [Existing System Audit](21-existing-system-audit.md); records the actual sequence and risk of migrating to [ADR-0012](../adr/0012-migrate-backend-to-laravel.md) and [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md).

## 1. Repository-by-repository impact

| Repository | Current state | ASP.NET dependency | Laravel migration impact | Local/Cloud impact | Sync impact | Preserve | Modify | Replace | Risk | Sequence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `007resort-api` | Phase 0 scaffold on `main`; Phase 1 (auth/org/devices/audit) on unmerged PR | **High** — entire host is ASP.NET Core | **Total rewrite of the host application**; the verified MySQL migration SQL and domain *rules* (not code) carry over | Becomes the codebase for **both** Local and Cloud nodes | Gains the outbox/inbox, heartbeat, and domain-authority logic — net-new | `db/migrations/V0001__initial_schema.sql` (as-is), the domain/permission/audit *design* (reimplemented) | — | The ASP.NET Core host, EF Core context, C# module projects | **High** — this is the center of the migration | First: scaffold Laravel app, port `V0001`, port auth/permissions/audit/devices with parity tests before anything else |
| `007resort-pos-desktop` | Phase 0 scaffold, 9 tests | **Low** — thin HTTP client only | None to the app itself; its `ApiBaseUrl`/response DTOs must match whatever Laravel exposes | Talks to whichever node is Local (its normal deployment target) | None directly — POS doesn't sync, it calls the Local API which handles sync | Everything | `IOtuekeApiClient`/`R007ApiClient` response models, once the Laravel contract is confirmed | Nothing | **Low** | After Laravel's auth/device endpoints exist and are contract-verified |
| `007resort-mobile` | Phase 0 scaffold, 8 tests | **Low** — same shape as POS | Same as POS | Same as POS | None directly | Everything | `ApiClient` response models | Nothing | **Low** | Same gate as POS |
| `007resort-kds` | Phase 0 scaffold, 20 tests, SignalR client | **Medium** — real-time transport is ASP.NET-specific | Ticket-state logic (`src/state/tickets.ts`) is transport-agnostic and unaffected; the **connection layer** (`src/realtime/hub.ts`) needs a Reverb/Echo (or Pusher-protocol) client instead of `@microsoft/signalr` | Talks to Local's real-time service | Consumes `PrepTicketStatusChanged`-equivalent broadcasts from Local's Laravel broadcasting, not a sync event | Ticket store, tests, UI | `src/realtime/hub.ts` connection library | Nothing structural | **Medium** — real-time behavior needs re-verification (reconnect/backoff), not just a library swap | After Laravel's Hospitality/KDS module and its broadcasting channel exist |
| `007resort-admin-web` | Phase 0 scaffold, already Laravel, 8 tests | **None** — already Laravel, already an API-only client | **None to its own stack**; its `R007ApiClient` base URL and DTOs must match the new backend's contract | Talks to Cloud (remote instance) or Local (on-site instance) depending on deployment | Consumes `ConfigurationUpdated`/reporting reads; does not itself sync | Everything | `R007ApiClient` response handling as the backend contract solidifies | Nothing | **Low** | Incrementally, as each backend module lands |
| `007resort-booking-web` | Same shape as admin-web | **None** | Same as admin-web | Always talks to Cloud | Booking requests go through Cloud Booking Authority ([Booking Authority & Offline Allocation](sync/booking-authority-and-offline-allocation.md)) | Everything | Same as admin-web | Nothing | **Low** | After Booking module + Booking Authority endpoint exist |
| `007resort-infrastructure` | Phase 0 scaffold — dev compose, env templates, network docs, PowerShell scripts | **Medium** — env var shapes and the Windows service script assume a compiled .NET process | `.env` templates rewritten for Laravel (`APP_*`, `DB_*`, `REDIS_*`, `QUEUE_*`, `BROADCAST_*`); dev compose gains Reverb (or chosen broadcaster) alongside existing MySQL/Redis; Windows service script rewritten for PHP-FPM/Laravel process supervision | Directly encodes the dual-node topology — needs the new [VPS spec](25-vps-production-deployment.md) and [Windows Local Server spec](26-windows-local-server-deployment.md) | Adds outbox/inbox worker process supervision to both node types | Network segmentation doc, runbook structure, backup cadence docs | Env templates, MySQL conf (mostly unaffected), PowerShell scripts | Nothing structurally | **Medium** | Alongside `007resort-api`'s Laravel scaffold, so dev environments match from day one |
| `007resort-docs` | This repository; PR #1 (architecture set) open, unmerged | **N/A** (documentation) | Architecture docs describing ASP.NET-specific detail get superseded (see [21 §8](21-existing-system-audit.md#8-otueke-docs--007resort-docs-this-repository)) | This document set | This document set | Domain model, state machines, database conventions (all backend-agnostic) | `01`, `02`, `04`, `14`, `16`; `ADR-0002`, `ADR-0004` (superseding notes added, not deleted) | `12`, `13` (fully superseded by the sync design in this PR) | **Low** (documentation risk only) | Concurrent with everything else — this PR |

## 2. What is genuinely new work (no ASP.NET Core equivalent existed)

- Outbox/inbox tables and workers, on both nodes.
- Heartbeat mechanism and `site_health` tracking.
- Booking Authority policy engine (Cloud-authority + offline-allocation modes).
- Domain Authority Matrix enforcement (which module checks "am I authoritative for this write" before committing).
- Conflict recording and the admin-facing resolution UI.

None of this regresses anything — Phase 1's ASP.NET Core work never reached Booking, Catalog, Orders, Payments, or Inventory, so there is no sync-unaware implementation of those domains to unwind.

## 3. What must be ported with equivalent test coverage, not just "rewritten"

From the ASP.NET Core Phase 1 PR ([007resort-api#1](https://github.com/prinzderick/007resort-api/pull/1)), specifically:

1. **Permission-based authorization, not role-name-based** — the "Manager-named role without the specific permission is denied" test must have a Laravel/Pest equivalent before this is considered ported, not just "a policy class exists."
2. **Hash-chained audit log** — the SHA-256 `prev_hash`/`row_hash` chain and its tamper-detection test.
3. **Idempotency-key handling** — the duplicate-request-returns-original-response test.
4. **Argon2id password/PIN hashing** — Laravel's default is bcrypt; Argon2id must be explicitly configured (Laravel supports it natively via `Hash::driver('argon2id')` or PHP's `password_hash` with `PASSWORD_ARGON2ID`) to match the already-decided convention ([architecture/17](17-security-model.md)).
5. **The real-MySQL-verified migration SQL** — reused directly; Laravel's migration runner (Eloquent migrations, or raw SQL run via a migration file) applies the *same* `V0001` DDL, not a re-derived schema, so the verification work already done is not repeated from scratch.

## 4. Migration risk summary

| Risk | Mitigation |
| --- | --- |
| Laravel reimplementation silently drops a security guarantee already proven in C# (e.g. permission-based auth degrading to role-name checks) | Port the exact test scenarios first, as acceptance criteria for each module, per §3 above |
| API contract drift breaks POS/mobile/KDS before they've even started calling real endpoints | Contract is documented and diffed explicitly (per the original spec's endpoint-catalogue requirement) before any client starts integrating against it — low risk today only because no client currently depends on anything beyond `/system/info` |
| Dual-node sync introduces a new, non-trivial class of bugs (race conditions, partial sync, conflict mishandling) that a single-node design would not have | Built and tested against the explicit scenarios in [architecture/18](18-testing-strategy.md) — extended with the dual-node-specific scenarios (duplicate event delivery, out-of-order delivery, stale heartbeat gating) before Phase 2 sign-off, not deferred |
| Shared hosting ([ADR-0010](../adr/0010-cloud-hosting-platform.md)) may not support the WebSocket/broadcasting or queue-worker-as-a-service requirements this architecture needs | Flagged explicitly in [25 — VPS Production Deployment Spec](25-vps-production-deployment.md) §0 — the **Cloud** node specifically needs root/admin VPS access per this migration's own instructions (§17 of the pivot brief), which supersedes the shared-hosting ADR-0010 for the Cloud node; see the note there |
| Windows Local Server running PHP/Laravel reliably, with queue workers and scheduler surviving reboot | Addressed explicitly in [26 — Windows Local Server Deployment Spec](26-windows-local-server-deployment.md) — no "someone SSHs in and runs `artisan queue:work`" |

## 5. Recommended sequence (maps to the cutover steps in the migration brief)

1. Laravel app scaffold in `007resort-api` (new branch there), `V0001` migration ported and re-verified against MySQL 8.4.
2. Auth/permissions/devices/audit ported with parity tests (§3).
3. Organization/facility capability module.
4. Outbox/inbox infrastructure + heartbeat (needed before any domain that syncs).
5. Catalog, Orders, Payments (Local-authoritative path first — this is what POS/KDS need).
6. Inventory.
7. Booking/Ticketing/Membership, including the Booking Authority policy engine.
8. KDS real-time (Reverb/Echo), once Orders/Hospitality exist to broadcast from.
9. Admin/booking web apps switch their `R007ApiClient` base URL to the new backend, module by module, as each lands.
10. Dual-node deployment: stand up the actual Windows Local Server and Cloud VPS per their specs, verify sync end-to-end, run the distributed-system test scenarios.
11. Only after verified parity: close the ASP.NET Core PR, mark [ADR-0001](../adr/0001-api-is-the-single-business-engine.md)/[ADR-0002](../adr/0002-modular-monolith.md) as carried-forward-in-Laravel rather than retired concepts.

## 6. Should `007resort-admin-web` / `007resort-booking-web` merge into the backend?

**Not decided by this assessment — left open**, consistent with [ADR-0012](../adr/0012-migrate-backend-to-laravel.md)'s explicit statement that language proximity must not quietly erode the client/API boundary. Arguments for keeping them separate (as today): [ADR-0007](../adr/0007-php-apps-are-api-clients-without-business-data.md)'s reasoning is about architecture (no shared business data), not language, and still holds. Arguments for merging: real operational simplicity (one Laravel app to deploy instead of three) now that all three would be the same language. This is flagged as a candidate follow-up ADR once the backend's Laravel implementation is far enough along to judge the trade-off concretely, not decided speculatively here.
