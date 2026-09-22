# ADR-0010: Cloud hosting platform — Microsoft Azure

Status: Proposed
Date: 2026-09-22
Deciders: Engineering recommendation, pending budget confirmation from the client (see Consequences)

## Problem

[Architecture/16 §2](../architecture/16-deployment-topology.md#2-cloud) deliberately described the cloud topology in a provider-agnostic way, leaving the actual hosting provider open as [Q2](../architecture/20-open-questions.md), pending "final hosting budget and operational requirements" ([spec §13](../spec/)).

## Decision

Recommend **Microsoft Azure** as the cloud environment for `007resort-api` (Cloud mode), `007resort-admin-web` (remote instance) and `007resort-booking-web`:

- **Compute**: Azure App Service (Linux, containerized) for the API and both Laravel apps — first-class GitHub Actions deploy support, built-in TLS, and straightforward horizontal scaling if the booking site gets a traffic spike (e.g. a promotion).
- **Database**: Azure Database for MySQL — Flexible Server (MySQL 8.4-compatible), matching the on-site MySQL 8.4/InnoDB choice exactly, so there is one dialect to target across both environments.
- **Secrets**: Azure Key Vault, referenced by App Service's managed identity — no cloud credential ever needs to live in a repo or in GitHub Actions secrets beyond a short-lived deployment credential.
- **Edge/TLS**: Azure Front Door (or App Service's built-in TLS termination alone, if Front Door's cost isn't justified at Phase 1 traffic levels) in front of `007resort-booking-web`.
- **CI/CD**: GitHub Actions using OIDC federation to Azure (no long-lived cloud secret stored in GitHub at all), extending the CI already scaffolded in each repo.

Rationale for Azure specifically over other providers: the stack is already Microsoft-centric (ASP.NET Core, C#/.NET WPF for POS, Windows for the on-site server), so Azure gives the tightest first-party tooling integration (Application Insights for the observability requirements in [architecture/17 §5](../architecture/17-security-model.md#5-audit-and-observability), `dotnet` deploy tooling, Azure AD if staff/owner SSO is ever wanted for the admin portal) and a single vendor relationship for support.

## Alternatives considered

- **DigitalOcean App Platform + Managed MySQL.** Materially cheaper at small scale and simpler to operate. A reasonable choice if budget is the dominant constraint; explicitly named as the fallback below.
- **AWS (Elastic Beanstalk/ECS + RDS for MySQL).** Broadest ecosystem and the most third-party familiarity, but has the least natural fit with the .NET-heavy stack compared to Azure, and a steeper operational learning curve for a small team than App Service.
- **Self-managed VPS (e.g. a single larger Linux box running everything via the existing Docker Compose from `007resort-infrastructure`).** Cheapest option; rejected as the primary recommendation because it pushes patching, backup automation and TLS renewal onto the team instead of a managed platform, which cuts against the "operational simplicity" principle already used to justify the modular monolith ([ADR-0002](0002-modular-monolith.md)).

## Consequences

- **This is a recommendation pending your budget sign-off**, not a provisioned environment — no Azure resources have been created; doing so requires billing details only the client can provide.
- If budget rules out Azure, the fallback recommendation is **DigitalOcean App Platform + Managed MySQL**, which needs no architectural change (the deployment topology in [architecture/16](../architecture/16-deployment-topology.md) was deliberately written to be portable across either).
- Once a provider is confirmed, `007resort-infrastructure` gains provider-specific IaC/deploy scripts (e.g. Bicep/Terraform for Azure) as a follow-up piece of work — not built yet, since provisioning without a confirmed account would be wasted effort.
