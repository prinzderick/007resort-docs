# 007resort-docs

Architecture, API contracts, workflows, Architecture Decision Records (ADRs), operational documentation and project status for the **007 Resort & Spa Integrated Facility Operations Platform (IFOP)**.

> Private repository. Never commit secrets, credentials, customer data or production configuration here.

## Contents

| Path | What it holds |
| --- | --- |
| [`STATUS.md`](STATUS.md) | Living project status: completed, in progress, next, blockers, decisions, open questions |
| [`architecture/`](architecture/) | Architecture set (overview, domain model, state models, sync/offline, security, testing, milestones) |
| [`database/`](database/) | Database design notes and the **draft** DDL used for design review. The authoritative schema and migrations live in `007resort-api` only. |
| [`api/`](api/) | API conventions and endpoint map. The generated OpenAPI document from `007resort-api` is the contract of record. |
| [`adr/`](adr/) | Architecture Decision Records |
| [`workflows/`](workflows/) | End-to-end operational workflows (restaurant, sports, inventory, staff) |
| [`spec/`](spec/) | The client system specification (source requirements) |

## Repository map

| Repository | Stack | Responsibility |
| --- | --- | --- |
| `007resort-api` | Laravel / PHP 8.4+ ([ADR-0012](adr/0012-migrate-backend-to-laravel.md)), deployed as two nodes (Local + Cloud, [ADR-0013](adr/0013-dual-node-local-cloud-sync.md)) | The business engine. Owns the MySQL schema and migrations, business rules, authentication and authorization, sync and integrations |
| `007resort-pos-desktop` | C# / .NET (WPF) | One configurable Windows POS for all 10 fixed terminals |
| `007resort-mobile` | Flutter / Dart | Android app for 18 tablets: attendants, supervisors, Sports Entrance, Sports Store |
| `007resort-admin-web` | PHP / Laravel | Owner, management, accounts, IT, reporting and configuration portal |
| `007resort-booking-web` | PHP / Laravel | Public website and online booking/customer portal |
| `007resort-kds` | TypeScript (browser kiosk) | Kitchen and bar display/dispensing client |
| `007resort-infrastructure` | Config / scripts | Environment templates, deployment scripts, network design, runbooks |
| `007resort-docs` | Markdown / Mermaid | This repository |

## Conventions

- Diagrams are written in Mermaid so they render on GitHub and stay diffable.
- A decision that changes an approved architecture **must** go through a new ADR (see [`adr/0000-template.md`](adr/0000-template.md)). Approved decisions are never silently edited.
- See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the branching and review workflow.
