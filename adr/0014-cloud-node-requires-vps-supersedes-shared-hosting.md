# ADR-0014: Cloud node requires a VPS with root access — supersedes the shared-hosting starting tier

Status: Accepted
Date: 2026-09-22
Deciders: 007 Resort & Spa (owner)

## Existing decision

[ADR-0010](0010-cloud-hosting-platform.md) (Accepted, 2026-09-22, same day) chose budget Windows/.NET shared hosting as the Cloud tier to start, explicitly to minimize cost, with Azure as the named upgrade path once traffic/secrets/DR needs grew.

## Problem

The dual-node architecture ([ADR-0013](0013-dual-node-local-cloud-sync.md)) requires the Cloud node to run: Laravel, MySQL 8.4, Redis, queue workers, a scheduler, a WebSocket/real-time broadcasting service (Reverb or equivalent), background sync workers, and process supervision that survives restarts — none of which a shared hosting plan reliably provides root-level control over. The owner's own migration brief is explicit and unambiguous on this point: **"The core production cloud environment MUST use a VPS/cloud server with administrative/root-level control. Do NOT design the core operational platform around ordinary shared hosting."**

This is not a case of engineering re-litigating an already-settled decision — it is the owner directly overriding it with a firmer, more specific requirement than existed when ADR-0010 was written (ADR-0010 predates the dual-node/Laravel architecture entirely; it was written when the plan was still a single ASP.NET Core Cloud-mode instance).

## Decision

The Cloud node runs on a **Linux VPS with root/administrative access**, sized initially at approximately 4 vCPU / 8 GB RAM / 100–160 GB SSD-NVMe (an initial target, not a ceiling — scale when actual load requires it). Full specification in [25 — VPS Production Deployment Spec](../architecture/25-vps-production-deployment.md).

**[ADR-0010](0010-cloud-hosting-platform.md) is superseded by this ADR for the Cloud node's hosting tier.** ADR-0010's reasoning about *budget-consciousness* is preserved — a modestly-sized VPS from a budget-friendly provider (e.g. DigitalOcean, Hetzner, Vultr, Contabo — final selection is an implementation choice, not re-litigated here) is still materially cheaper than Azure App Service, so this is not a reversal back to ADR-0010's original Azure recommendation; it is a different budget-conscious choice that actually meets the dual-node architecture's technical requirements, which shared hosting cannot.

Shared hosting is not entirely abandoned as a concept: per the owner's brief, "shared hosting may only be used for isolated non-critical public content where appropriate" — e.g. a purely static marketing page unrelated to the operational platform, if one is ever wanted. It must never constrain the core platform's architecture.

## Alternatives considered

- **Keep shared hosting, accept the WebSocket/queue-worker limitations.** Rejected outright by the owner's explicit instruction, and independently weak on the merits: SignalR/Reverb-equivalent real-time and durable queue workers are core to the KDS and sync design, not optional extras that can gracefully degrade away.
- **Azure App Service (ADR-0010's original recommendation).** Still valid as a *future* upgrade path once the VPS tier is outgrown, per ADR-0010's own consequences section — just not the starting tier, since a right-sized VPS meets the same technical requirements at materially lower cost for a single-property system.
- **Split the Cloud node across two hosts** (e.g. shared hosting for the website, a small VPS just for queue/broadcast). Rejected: reintroduces the "one Laravel codebase, one deployment per node" principle's violation that [ADR-0012](0012-migrate-backend-to-laravel.md)/[ADR-0013](0013-dual-node-local-cloud-sync.md) specifically avoid, and adds an internal network hop for no real benefit at this scale.

## Consequences

- [architecture/16 §2](../architecture/16-deployment-topology.md#2-cloud) and [architecture/25](../architecture/25-vps-production-deployment.md) are updated to describe the VPS topology as the Cloud node's actual starting tier, not the shared-host diagram written under ADR-0010.
- Provisioning the VPS (account, billing, initial hardening) is still a step requiring the owner's action (payment details, account creation) — not something performed autonomously; `007resort-infrastructure` gains the provisioning runbook and deploy scripts as implementation work once an actual provider/account is confirmed.
- ADR-0010 is not deleted — its status is updated to `Superseded by 0014` per this project's ADR governance ([CONTRIBUTING.md](../CONTRIBUTING.md)), and it remains readable as the historical record of the original (now superseded) reasoning.
- No change to the **Local** node's hosting (`007resort-api`'s Local mode still runs on the property's Windows Server, per [26 — Windows Local Server Deployment Spec](../architecture/26-windows-local-server-deployment.md)) — this ADR is scoped to the Cloud node only.
