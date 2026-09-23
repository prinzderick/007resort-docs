# ADR-0006: Client technology per platform (POS: WPF, KDS: browser kiosk)

Status: Proposed
Date: 2026-09-22
Deciders: Architecture review (pending)

## Problem

The specification mandates C#/.NET for the Windows POS and Flutter/Dart for the mobile app, but leaves the specific UI framework for POS and the exact technology for the KDS client open ("lightweight" is the only constraint for KDS).

## Decision

- **POS** ([007resort-pos-desktop](../architecture/02-repository-map.md)): WPF on .NET 10. WPF is a mature, well-supported native Windows UI framework with good touchscreen support, low resource use appropriate for 10 fixed terminals of modest hardware, and native access to Windows-specific device APIs (serial/USB printers, NFC readers) without a bridging layer.
- **KDS** ([007resort-kds](../architecture/02-repository-map.md)): a browser-based kiosk client (Vite + TypeScript, no framework), connected to the API via a WebSocket client (originally SignalR; now Laravel Echo/Reverb-compatible, per [ADR-0012](0012-migrate-backend-to-laravel.md) — the connection library changed, this decision's reasoning did not). A browser kiosk avoids installing and updating a native app on 4 fixed-purpose displays, is trivially updated by refreshing/redeploying static files, and matches "lightweight" — the client holds only a display/state-transition model, no business logic ([08](../architecture/08-order-state-model.md)).

## Alternatives considered

- **POS as a web app (browser kiosk) instead of WPF.** Considered, since it would unify tooling with KDS. Rejected: the spec explicitly requires the POS to be a native Windows C#/.NET application, and native access to receipt printers/NFC/cash drawers is more direct outside a browser sandbox.
- **KDS as a native Windows/.NET app** for consistency with POS. Rejected: KDS displays are simpler (a board of tickets, a few status buttons) and a browser kiosk is materially cheaper to build, update and deploy across 4 stations, with no hardware-integration need beyond an optional keyboard-wedge scanner/NFC reader.
- **MAUI instead of WPF for POS.** A reasonable alternative; not chosen for Phase 1 because the POS targets Windows only (no cross-platform requirement) and WPF's touch/peripheral ecosystem is more mature today for this specific device class. Revisit if a POS form factor beyond Windows is ever needed.

## Consequences

- Two different client technology stacks for POS and KDS (native vs. web) rather than one, in exchange for each matching its device class better.
- The KDS's real-time model must be resilient to the connection dropping and resuming without losing board state ([13 §4](../architecture/13-offline-strategy.md#4-what-the-kds-and-sports-entrancestore-do-offline)).
