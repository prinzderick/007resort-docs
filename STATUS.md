# Project Status

_Last updated: 2026-09-22_

## Completed

- **Phase 0 — repositories & scaffolding**: eight private repositories created under `prinzderick`, all with a green CI pipeline on `main`:
  - `otueke-api` — ASP.NET Core / .NET 10 solution, modular skeleton, health/system-info endpoints, Serilog, OpenAPI, unit + integration tests
  - `otueke-pos-desktop` — .NET 10 WPF solution, API client, offline-queue and device-abstraction interfaces with simulated implementations, tests
  - `otueke-mobile` — Flutter/Dart app skeleton, device-mode model, API client, unit + widget tests
  - `otueke-kds` — Vite/TypeScript kiosk client skeleton, SignalR client wiring, ticket store, tests
  - `otueke-admin-web` — Laravel app with no local business database, `OtuekeApiClient`, feature tests
  - `otueke-booking-web` — Laravel app, same conventions, public-site placeholder
  - `otueke-infrastructure` — dev docker-compose (MySQL 8.4 + Redis), env templates, network segmentation design, runbooks (draft), PowerShell script skeletons
  - `otueke-docs` — this repository
- **Phase 0 — architecture documentation**: full architecture set (`architecture/01`–`20`), 8 ADRs, 4 workflow diagrams, and a draft schema for the highest-risk tables — submitted for review as [PR #1](https://github.com/prinzderick/otueke-docs/pull/1).

## In progress

- Architecture review (PR #1) — pending approval before Phase 1 implementation work begins in earnest, per the client specification's requirement to review the design before irreversible architectural decisions are made.

## Next

- Close out the Phase-1-blocking open questions ([architecture/20](architecture/20-open-questions.md), Q1–Q4): payment provider selection, cloud hosting provider, EF Core/SQL split and migration runner, individual-capacity booking representation.
- Once PR #1 is approved, write the first real migration in `otueke-api/db/migrations/` (Organization, Identity, Devices, Audit — Phase 1 scope) and begin Phase 1 per [architecture/19](architecture/19-milestones.md).

## Blockers

- None. The Phase-1-blocking open questions above are decisions to make, not external blockers.

## Decisions

- See [`adr/`](adr/) — ADR-0001 through ADR-0008, all currently `Proposed`, pending review sign-off.

## Open questions

- See [`architecture/20-open-questions.md`](architecture/20-open-questions.md).
