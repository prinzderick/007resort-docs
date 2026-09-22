# ADR-0001: The ASP.NET Core API is the single business engine

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

Six client applications (POS, mobile, KDS, two Laravel apps) need to share pricing, inventory, ticketing, booking and permission rules. If each client implements its own copy, the copies drift, and a bug fix in one does not fix the others — a well-known failure mode in multi-client retail/hospitality systems.

## Decision

`007resort-api` is the only component that decides prices, validates tickets, allocates booking slots, authorizes actions, and mutates operational data. Every client is a thin presentation layer: it renders data returned by the API and sends user intent to the API as requests. No client independently computes a price, checks a permission, or writes to a business table.

## Alternatives considered

- **Shared business logic library per platform** (a C# library, a Dart library, a PHP library, kept in sync). Rejected: still requires the same rule expressed and tested in four languages, and the network round-trip is unavoidable anyway for state that must be authoritative (stock, slots, entitlements).
- **Each client with its own local database and periodic reconciliation.** Rejected: reconciliation cannot resolve races on scarce resources (last slot, last unit, single-use ticket) after the fact without a much more complex conflict-resolution system than the API-authoritative model requires.

## Consequences

- Every client needs reliable connectivity to *some* API instance (site, normally) to transact — addressed by [ADR-0005](0005-site-authoritative-local-first-with-outbound-sync.md) and [13 — Offline strategy](../architecture/13-offline-strategy.md).
- The API's endpoint surface and OpenAPI contract become the primary integration point and must be versioned carefully ([02](../architecture/02-repository-map.md)).
- Client code stays small and easy to replace; the hard problems concentrate in one well-tested codebase.
