# ADR-0010: Cloud hosting platform — budget Windows/.NET shared hosting to start

Status: Superseded by [ADR-0014](0014-cloud-node-requires-vps-supersedes-shared-hosting.md)
Date: 2026-09-22 (superseded same day, once the dual-node Laravel architecture was decided)
Deciders: 007 Resort & Spa (owner), engineering recommendation

> **Superseded.** This ADR was written for a single ASP.NET Core Cloud-mode instance, before the dual-node Laravel architecture ([ADR-0012](0012-migrate-backend-to-laravel.md), [ADR-0013](0013-dual-node-local-cloud-sync.md)) was decided. That architecture needs root-level control (queue workers, real-time broadcasting, process supervision) that shared hosting cannot provide, so the owner's follow-up instruction requires a VPS instead — see [ADR-0014](0014-cloud-node-requires-vps-supersedes-shared-hosting.md). Kept below as the historical record of the original reasoning.

## Problem

[Architecture/16 §2](../architecture/16-deployment-topology.md#2-cloud) deliberately described the cloud topology in a provider-agnostic way, leaving the actual hosting provider open as [Q2](../architecture/20-open-questions.md), pending "final hosting budget and operational requirements" ([spec §13](../spec/)).

## Decision

**Start on a budget Windows/.NET-capable shared hosting plan** (e.g. SmarterASP.NET or an equivalent ASP.NET Core + MySQL shared host), not a full managed cloud platform. This was chosen explicitly for cost, on the understanding that it can be upgraded later without a redesign.

- **Compute**: the shared host's IIS/ASP.NET Core Module (ANCM) hosting for `007resort-api` (Cloud mode) and, if the same host offers PHP hosting, `007resort-admin-web` (remote instance) and `007resort-booking-web`; otherwise the two Laravel apps go on a companion budget PHP host (many providers, including SmarterASP.NET-style hosts, offer both under one account).
- **Database**: the shared host's included MySQL (confirm it offers 8.4 or the closest available 8.x with InnoDB and `utf8mb4`; if the host is capped at an older MySQL version, note the gap and treat it as a reason to move up a tier before Phase 8 go-live rather than degrading the schema design to match).
- **Real-time (SignalR)**: shared IIS hosts vary in WebSocket support. SignalR degrades automatically to Server-Sent Events / long-polling when WebSockets aren't available, so this does not block functionality — **but confirm WebSocket support with the specific plan chosen**, since long-polling adds latency the KDS boards would rather not have.
- **Secrets**: shared hosting typically has no equivalent of a cloud secret manager. Store secrets in the host's environment-variable/App Settings panel (most ASP.NET-capable shared hosts have one) — never in a committed `appsettings.*.json`. This is a real step down from Key Vault-style rotation/least-privilege secret access; document it as an accepted trade-off of this tier, not silently.
- **TLS**: use the host's included free TLS (most offer Let's Encrypt or similar) for `007resort-booking-web` and the remote `007resort-admin-web`.
- **CI/CD**: deploy via the host's supported mechanism (commonly FTPS/Web Deploy for ASP.NET shared hosts) from a GitHub Actions workflow, rather than the OIDC-to-cloud pattern a full platform would offer.

## Alternatives considered

- **Microsoft Azure** (App Service + Azure Database for MySQL Flexible Server + Key Vault + Front Door) — the original engineering recommendation. Rejected for the starting tier on cost grounds, explicitly accepted here as the **upgrade path**: the deployment topology in [architecture/16](../architecture/16-deployment-topology.md) was written to be portable, so moving to Azure later is a re-deployment, not a redesign.
- **DigitalOcean App Platform + Managed MySQL.** Also cheaper than Azure, but doesn't natively host ASP.NET Core as simply as a Windows/.NET-oriented shared host or Azure App Service (would need a Linux container build), so it's a worse fit for "cheapest option that still runs the existing .NET stack directly."
- **Literal cPanel/LAMP shared hosting.** Rejected: cannot run ASP.NET Core at all; would force the Cloud-mode API onto a different host from day one and complicate the single-binary-both-modes design ([architecture/01 §4](../architecture/01-architecture-overview.md#4-deployment-modes-of-the-api)).

## Consequences

- **Known limitations of this tier, accepted deliberately**: weaker secret management than a cloud KMS, likely no autoscaling (a real constraint if the booking site gets a traffic spike — e.g. a promoted event), possibly-older MySQL version, no built-in observability (Application Insights equivalent) — structured logs still work ([architecture/17 §5](../architecture/17-security-model.md#5-audit-and-observability)), just without a hosted log aggregator until one is added.
- **Upgrade trigger**: move to Azure (or DigitalOcean) once any of the following happens — the booking site's traffic outgrows a shared instance, the business wants managed backups/DR beyond what the shared host provides, or the secret-management gap becomes a real operational pain point. No schema or application-code change is needed to move; only the deployment/infrastructure layer changes.
- `007resort-infrastructure` gains the specific shared-host deployment scripts (FTPS/Web Deploy workflow, App Settings documentation) as the next infrastructure task, rather than the Azure Bicep/Terraform originally planned — that work is deferred until the upgrade actually happens.
