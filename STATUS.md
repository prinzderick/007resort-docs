# Project Status

_Last updated: 2026-09-22_

## Completed

- **Phase 0 — repositories & scaffolding**: eight repositories created under `prinzderick`, all `007resort-*`, all with a green CI pipeline on `main`:
  - `007resort-api` — ASP.NET Core / .NET 10 solution, modular skeleton, health/system-info endpoints, Serilog, OpenAPI, unit + integration tests
  - `007resort-pos-desktop` — .NET 10 WPF solution, API client, offline-queue and device-abstraction interfaces with simulated implementations, tests
  - `007resort-mobile` — Flutter/Dart app skeleton, device-mode model, API client, unit + widget tests
  - `007resort-kds` — Vite/TypeScript kiosk client skeleton, SignalR client wiring, ticket store, tests
  - `007resort-admin-web` — Laravel app with no local business database, `R007ApiClient`, feature tests
  - `007resort-booking-web` — Laravel app, same conventions, public-site placeholder
  - `007resort-infrastructure` — dev docker-compose (MySQL 8.4 + Redis), env templates, network segmentation design, runbooks (draft), PowerShell script skeletons
  - `007resort-docs` — this repository
- **Phase 0 — architecture documentation**: full architecture set (`architecture/01`–`20`), 11 ADRs, 4 workflow diagrams, and a draft schema for the highest-risk tables — submitted for review as [PR #1](https://github.com/prinzderick/007resort-docs/pull/1) (open, awaiting merge).
- **Rename**: the project (working name "Otueke") was renamed to **007 Resort & Spa** across all 8 repositories, code identifiers (`R007`/`r007`), and documentation.
- **Branch protection**: `main` is now protected on all 8 repos (pull request required with 1 approval, no force-pushes, no deletions, conversations must be resolved before merge).
- **All open architecture questions resolved** ([architecture/20-open-questions.md](architecture/20-open-questions.md)): payment provider (Paystack, ADR-0009), cloud hosting (budget Windows/.NET shared hosting to start, Azure as the upgrade path, ADR-0010), migration tooling (DbUp, ADR-0004), booking capacity model, online booking availability policy, notification channels, API-client sharing, biometric attendance hardware (ZKTeco), and tax/VAT handling (admin-configurable, ADR-0011) — all confirmed or engineering-decided.
- **Phase 1 — core API implemented**: [PR #1 on 007resort-api](https://github.com/prinzderick/007resort-api/pull/1) — migration (Organization/Identity/Devices/Audit tables, seeded roles/permissions), DbUp migration runner (verified against a real local MySQL 8.4 instance, not just SQLite), staff auth (Argon2id + JWT + revocable sessions), permission-based authorization (not role-name based — tested), device registration, hash-chained audit log, idempotency middleware, module-boundary architecture test. 41/41 tests passing, CI green. Not yet merged.

## ⚠️ Temporary: repositories are currently PUBLIC

All 8 repositories were switched from private to public on 2026-09-22 **at the owner's explicit instruction**, solely because GitHub's branch-protection API (both classic protection and the newer rulesets) refuses to operate on private repositories under this account's current plan ("Upgrade to GitHub Pro or make this repository public"). A secret scan of every tracked file was run immediately before flipping visibility and found nothing sensitive.

This is a deliberate, acknowledged deviation from the client specification's "ALL repositories MUST be private" requirement, made as a stated trade-off to get branch protection working now. **Remember to revert this** — either switch back to private (dropping branch protection, or re-applying it if the plan allows), or upgrade to GitHub Pro / move to a GitHub Organization first, then switch back to private with protection intact.

## In progress

- **Architecture review** ([PR #1](https://github.com/prinzderick/007resort-docs/pull/1)) — open, all content decided, awaiting your merge.
- **Phase 1 core API review** ([PR #1 on 007resort-api](https://github.com/prinzderick/007resort-api/pull/1)) — open, awaiting your merge. One documented follow-up: the DbUp runner itself hasn't been exercised end-to-end against a live server (the raw migration SQL has been, directly).

## Next

- Merge both open PRs.
- Continue Phase 1 per [architecture/19](architecture/19-milestones.md), then Phase 2: Catalog, POS transactions, orders, payments (including the Paystack adapter).

## Blockers

- None.

## Decisions

- See [`adr/`](adr/) — ADR-0001 through ADR-0011. ADR-0009 (Paystack), ADR-0010 (hosting) and ADR-0011 (tax config) are `Accepted`; the rest are `Proposed`, pending your review of PR #1.

## Open questions

- None remaining — see [`architecture/20-open-questions.md`](architecture/20-open-questions.md) for the full resolution record.
