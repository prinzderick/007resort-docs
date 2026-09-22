# Project Status

_Last updated: 2026-09-22_

## Completed

- **Phase 0 — repositories & scaffolding**: eight private repositories created under `prinzderick`, all `007resort-*`, all with a green CI pipeline on `main`:
  - `007resort-api` — ASP.NET Core / .NET 10 solution, modular skeleton, health/system-info endpoints, Serilog, OpenAPI, unit + integration tests
  - `007resort-pos-desktop` — .NET 10 WPF solution, API client, offline-queue and device-abstraction interfaces with simulated implementations, tests
  - `007resort-mobile` — Flutter/Dart app skeleton, device-mode model, API client, unit + widget tests
  - `007resort-kds` — Vite/TypeScript kiosk client skeleton, SignalR client wiring, ticket store, tests
  - `007resort-admin-web` — Laravel app with no local business database, `R007ApiClient`, feature tests
  - `007resort-booking-web` — Laravel app, same conventions, public-site placeholder
  - `007resort-infrastructure` — dev docker-compose (MySQL 8.4 + Redis), env templates, network segmentation design, runbooks (draft), PowerShell script skeletons
  - `007resort-docs` — this repository
- **Phase 0 — architecture documentation**: full architecture set (`architecture/01`–`20`), 8 ADRs, 4 workflow diagrams, and a draft schema for the highest-risk tables — submitted for review as [PR #1](https://github.com/prinzderick/007resort-docs/pull/1) (open, awaiting approval).
- **Rename**: the project (working name "Otueke") was renamed to **007 Resort & Spa** across all 8 repositories, code identifiers (`R007`/`r007`), and documentation. See `git log` on each repo for the rename commits.
- **Branch protection**: `main` is now protected on all 8 repos (pull request required with 1 approval, no force-pushes, no deletions, conversations must be resolved before merge), per [spec §1](../spec/) / [spec §22](../spec/) ("protect main from accidental direct development once initial scaffolding has been committed").

## ⚠️ Temporary: repositories are currently PUBLIC

All 8 repositories were switched from private to public on 2026-09-22 **at your explicit instruction**, solely because GitHub's branch-protection API (both classic protection and the newer rulesets) refuses to operate on private repositories under this account's current plan ("Upgrade to GitHub Pro or make this repository public"). A secret scan of every tracked file was run immediately before flipping visibility and found nothing sensitive (only Laravel's default `env('AWS_SECRET_ACCESS_KEY')`-style config references, no real values).

This is a deliberate, acknowledged deviation from the client specification's "ALL repositories MUST be private" / "Do not make any repository public" requirement, made as a stated trade-off to get branch protection working now. **Remember to revert this** — either:

- switch the repos back to private (branch protection will then need to be re-applied via GitHub's web UI's org-level free tier if applicable, or dropped), or
- upgrade the `prinzderick` account to GitHub Pro (or move the repos to a GitHub Organization, which gets branch protection on private repos on the free tier) and then switch back to private with protection intact.

## In progress

- **Architecture review** ([PR #1](https://github.com/prinzderick/007resort-docs/pull/1)) — open, pending your approval. Per the spec's own governance, this should be reviewed before treating any of its decisions as final, but implementation of the first, least-ambiguous slice of Phase 1 (auth, organization/facility model, staff/roles/permissions, device registration, audit framework — none of which depend on the still-open questions in [architecture/20](architecture/20-open-questions.md)) has started in parallel so review and implementation aren't serialized unnecessarily.
- **Phase 1 — core API**: see `007resort-api` for the current feature branch/PR implementing the first migration and the Organization/Identity/Devices/Audit modules.

## Next

- Merge PR #1 once reviewed (or request changes / open follow-up ADRs for anything that should change).
- Close out the Phase-1-blocking open questions ([architecture/20](architecture/20-open-questions.md), Q1–Q4): payment provider selection, cloud hosting provider, EF Core/SQL split and migration runner, individual-capacity booking representation.
- Continue Phase 1 per [architecture/19](architecture/19-milestones.md): Catalog, POS transactions, orders, payments (Phase 2) follow once Phase 1's core API lands.

## Blockers

- None. The Phase-1-blocking open questions above are decisions to make, not external blockers.

## Decisions

- See [`adr/`](adr/) — ADR-0001 through ADR-0008, all currently `Proposed`, pending review sign-off.

## Open questions

- See [`architecture/20-open-questions.md`](architecture/20-open-questions.md).
