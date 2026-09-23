# ADR-0005: Site is authoritative for operations; sync is outbound-only from site to cloud

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

The property must keep operating — payments, orders, KDS, ticket validation, staff auth, inventory, bookings made at Reception, attendance — when the public internet is unavailable. It must also offer secure remote management, a public website, and online booking without exposing the on-site server or database to the internet.

## Decision

The on-site MySQL database is the system of record for on-site operational data. The site's `007resort-api` instance opens an **outbound-only**, mutually authenticated connection to the cloud to push its operational history and pull commands (online bookings, remote configuration edits). No inbound connection from the internet ever reaches the site server or database. See [01 §3](../architecture/01-architecture-overview.md#3-system-context) and [12 — Sync strategy](../architecture/12-sync-strategy.md).

## Alternatives considered

- **Cloud-authoritative with a local cache.** Rejected: this is the opposite of what "must not depend entirely on internet availability" requires — a cloud outage would degrade or halt on-site operations, which is the one failure mode the spec is most explicit about avoiding ([spec §19](../spec/)).
- **Site server reachable from the internet via port-forward/VPN for management.** Rejected: this reintroduces exactly the attack surface the spec forbids ("must not expose the property server directly without a secure architecture" — [spec §20](../spec/)); the outbound-initiated channel achieves the same remote-management goal without opening an inbound port.
- **Bidirectional real-time replication (e.g. MySQL Group Replication across site and cloud).** Rejected for Phase 1: true multi-master replication over an unreliable WAN link is a materially harder operational problem than an application-level outbox/inbox sync with clear conflict states, for a benefit (sub-second cross-site consistency) the business does not need.

## Consequences

- Online bookings/payments have to travel to the site (or be provisionally held in the cloud, see [20 Q6](../architecture/20-open-questions.md)) before they are truly confirmed against the shared `slot_allocation` table — a small latency cost in exchange for one true booking ledger with no cross-node double-booking risk ([10 §3](../architecture/10-booking-state-model.md#3-preventing-the-two-users-one-final-slot-race)).
- Remote reporting and remote admin at the cloud read a **replica** of site data with sync latency, not a live view — acceptable for management reporting, called out explicitly wherever it applies ([01 §4](../architecture/01-architecture-overview.md#4-deployment-modes-of-the-api)).
- This shapes the entire sync/offline design in [12](../architecture/12-sync-strategy.md) and [13](../architecture/13-offline-strategy.md).
