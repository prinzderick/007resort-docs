# otueke-docs

Architecture, API contracts, workflows, Architecture Decision Records (ADRs), operational documentation and project status for the **Otueke Integrated Facility Operations Platform (IFOP)**.

> Private repository. Never commit secrets, credentials, customer data or production configuration here.

## Contents

| Path | What it holds |
| --- | --- |
| [`STATUS.md`](STATUS.md) | Living project status: completed, in progress, next, blockers, decisions, open questions |
| [`architecture/`](architecture/) | Architecture set (overview, domain model, state models, sync/offline, security, testing, milestones) |
| [`database/`](database/) | Database design notes and the **draft** DDL used for design review. The authoritative schema and migrations live in `otueke-api` only. |
| [`api/`](api/) | API conventions and endpoint map. The generated OpenAPI document from `otueke-api` is the contract of record. |
| [`adr/`](adr/) | Architecture Decision Records |
| [`workflows/`](workflows/) | End-to-end operational workflows (restaurant, sports, inventory, staff) |
| [`spec/`](spec/) | The client system specification (source requirements) |

## Repository map

| Repository | Stack | Responsibility |
| --- | --- | --- |
| `otueke-api` | ASP.NET Core / C# | The business engine. Owns the MySQL schema and migrations, business rules, authentication and authorization, sync and integrations |
| `otueke-pos-desktop` | C# / .NET (WPF) | One configurable Windows POS for all 10 fixed terminals |
| `otueke-mobile` | Flutter / Dart | Android app for 18 tablets: attendants, supervisors, Sports Entrance, Sports Store |
| `otueke-admin-web` | PHP / Laravel | Owner, management, accounts, IT, reporting and configuration portal |
| `otueke-booking-web` | PHP / Laravel | Public website and online booking/customer portal |
| `otueke-kds` | TypeScript (browser kiosk) | Kitchen and bar display/dispensing client |
| `otueke-infrastructure` | Config / scripts | Environment templates, deployment scripts, network design, runbooks |
| `otueke-docs` | Markdown / Mermaid | This repository |

## Conventions

- Diagrams are written in Mermaid so they render on GitHub and stay diffable.
- A decision that changes an approved architecture **must** go through a new ADR (see [`adr/0000-template.md`](adr/0000-template.md)). Approved decisions are never silently edited.
- See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the branching and review workflow.
