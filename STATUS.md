# Project Status

_Last updated: 2026-09-22_

## Completed

- **Phase 0 — repositories & scaffolding**: eight repositories under `prinzderick`, all `007resort-*`, all tagged `pre-laravel-migration-2026-09-22` (recoverable snapshot before the architecture pivot below).
- **Phase 0 — architecture documentation**: full architecture set (`architecture/01`–`20`), 11 ADRs, 4 workflow diagrams, draft schema — [PR #1](https://github.com/prinzderick/007resort-docs/pull/1) (open, awaiting merge).
- **Rename**: "Otueke" → **007 Resort & Spa** across all 8 repositories, code identifiers, and documentation.
- **Branch protection**: `main` protected on all 8 repos.
- **All Phase-0 open architecture questions resolved**: payment provider (Paystack, [ADR-0009](adr/0009-payment-provider-selection.md)), tax/VAT handling (admin-configurable, [ADR-0011](adr/0011-tax-configuration-is-admin-settable.md)), biometric hardware (ZKTeco), and others — see [architecture/20](architecture/20-open-questions.md).
- **Phase 1 — core API, ASP.NET Core reference implementation**: [PR #1 on 007resort-api](https://github.com/prinzderick/007resort-api/pull/1) — auth (Argon2id + JWT), permission-based authorization (tested), hash-chained audit, idempotency middleware, 41/41 tests, migration verified against real MySQL 8.4. **This PR will not be merged as ASP.NET Core** — see the architecture pivot below. It remains open, tagged, and is the behavioral reference the Laravel port must match (per-scenario parity, not just "a Laravel app exists").
- **Architecture pivot documented** ([ADR-0012](adr/0012-migrate-backend-to-laravel.md), [ADR-0013](adr/0013-dual-node-local-cloud-sync.md), [ADR-0014](adr/0014-cloud-node-requires-vps-supersedes-shared-hosting.md)): backend changes from ASP.NET Core to **Laravel/PHP + MySQL 8.4 + Redis**; deployment becomes **dual-node** (Local: Windows Server on-property; Cloud: Linux VPS with root access, superseding the shared-hosting plan in [ADR-0010](adr/0010-cloud-hosting-platform.md)), synchronized by a transactional outbox/inbox event pattern — never raw database mirroring. Full audit, migration impact assessment, domain authority matrix, sync event catalogue, outbox/inbox design, booking authority & offline allocation strategy, heartbeat/node health spec, conflict resolution matrix, failure mode matrix, VPS deployment spec, and Windows Local Server deployment spec are all written — see [architecture/21](architecture/21-existing-system-audit.md) through [26](architecture/26-windows-local-server-deployment.md) and `architecture/sync/`.

## ⚠️ Temporary: repositories are currently PUBLIC

Switched from private to public on 2026-09-22 at the owner's explicit instruction, to unblock GitHub branch protection (unavailable for private repos on this account's plan). Secret-scanned clean before the flip. **Remember to revert** — private + branch protection needs GitHub Pro or an Organization.

## In progress

- **Architecture review** ([PR #1](https://github.com/prinzderick/007resort-docs/pull/1)) — open, awaiting merge.
- **Phase 1 ASP.NET Core reference PR** ([007resort-api#1](https://github.com/prinzderick/007resort-api/pull/1)) — open, not merged, kept as the behavioral reference for the Laravel port (see above).
- **Laravel migration architecture PR** ([architecture/laravel-migration branch](https://github.com/prinzderick/007resort-docs/tree/architecture/laravel-migration)) — this pivot's documentation, submitted for review before any Laravel implementation code is written, per the owner's explicit instruction not to start rewriting code until the audit and design documents exist.

## Next

1. Owner reviews and merges the architecture PRs (Phase 0 set + this Laravel/dual-node pivot).
2. Begin the actual Laravel implementation in `007resort-api` on a new branch, following the sequence in [22 — Migration Impact Assessment §5](architecture/22-migration-impact-assessment.md#5-recommended-sequence-maps-to-the-cutover-steps-in-the-migration-brief): scaffold → port `V0001` migration → port auth/permissions/audit/devices with parity tests against the ASP.NET Core reference → outbox/inbox + heartbeat infrastructure → Catalog/Orders/Payments → Inventory → Booking/Ticketing/Membership (incl. Booking Authority) → KDS real-time → client cutover → dual-node deployment → distributed-system test scenarios.
3. Provision the actual VPS (owner action — billing/account) once ready to deploy Cloud for real, per [25 — VPS Production Deployment Spec](architecture/25-vps-production-deployment.md).
4. Close the ASP.NET Core reference PR (not delete — close with a pointer) once the Laravel implementation reaches verified parity.

## Blockers

- None. VPS provisioning requires the owner's billing action when that step is reached — not a blocker today.

## Decisions

- See [`adr/`](adr/) — ADR-0001 through ADR-0014.
- **Superseded**: [ADR-0010](adr/0010-cloud-hosting-platform.md) (shared hosting) → superseded by [ADR-0014](adr/0014-cloud-node-requires-vps-supersedes-shared-hosting.md) (VPS). [ADR-0004](adr/0004-schema-migrations-and-data-access.md) (DbUp/EF Core specifics) → partially superseded by [ADR-0012](adr/0012-migrate-backend-to-laravel.md) (principle carried forward, tools now Laravel-native).
- **New, Accepted**: [ADR-0012](adr/0012-migrate-backend-to-laravel.md) (Laravel backend), [ADR-0013](adr/0013-dual-node-local-cloud-sync.md) (dual-node sync), [ADR-0014](adr/0014-cloud-node-requires-vps-supersedes-shared-hosting.md) (VPS for Cloud).

## Open questions

- None blocking — see [architecture/20](architecture/20-open-questions.md) for the Phase 0 record. The Laravel/dual-node pivot introduces no new _open_ questions; all its design decisions are made (see ADRs 12–14 and `architecture/sync/`).
