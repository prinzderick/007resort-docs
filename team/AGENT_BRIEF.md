# Engineering brief — read this first (all agents)

Project: **007 Resort & Spa Integrated Facility Operations Platform (IFOP)**. Real property, real money, tight deadline. **MVP goal: a live working Flutter mobile app talking to a Local Laravel node (offline-capable), with the Cloud node following.** Correctness of money/inventory/booking/tickets beats polish, but speed matters: ship working vertical slices.

## Where things are

Parent dir of all clones (quote it, it has spaces):
`/Users/macbook/Library/Application Support/Claude/scratch-workspaces/e0176c13-e709-48ba-8517-6927ae9add0b/ab706bee-d994-4bed-8c3c-7768ba920e60/scratch-2026-09-22-c8bda7/repos/`

Clones: `007resort-api` (Laravel backend — being migrated from ASP.NET), `007resort-pos-desktop` (C#/.NET WPF), `007resort-mobile` (Flutter), `007resort-kds` (TypeScript), `007resort-admin-web` and `007resort-booking-web` (Laravel UIs, no business DB), `007resort-infrastructure`, `007resort-docs`. GitHub: `prinzderick/<same name>`.

Design docs live in `007resort-docs` (its local clone is checked out on `architecture/laravel-migration`; **do not switch its branch** — read it in place, or `git show origin/<branch>:path`). Read what your scope needs: `architecture/01, 03, 04, 05, 06, 07–11, 15, 23`, `architecture/sync/*`, `adr/0001–0014` (esp. 0012, 0013), `database/schema-draft-v0.sql`, `workflows/*`. The spec PDF is in `spec/`. API contract (when present): `api/openapi/v1.yaml` + `api/realtime.md`.

The ASP.NET Core reference implementation (auth, permissions, audit, idempotency, devices; 41 tests) is on branch `feature/phase1-core-api` of `007resort-api` and its verified MySQL DDL is `db/migrations/V0001__initial_schema.sql` there (`git show origin/feature/phase1-core-api:db/migrations/V0001__initial_schema.sql`). It is the behavioural parity target.

## Non-negotiable engineering rules

- Backend = **Laravel (latest stable), PHP 8.4-compatible code**, MySQL 8.4, Redis. Clients never write business data except through the API. Business rules live only in the backend.
- Money `DECIMAL(19,4)` + currency (NGN); API sends money as **decimal strings**. Never float. UTC `DATETIME(6)`. IDs: UUIDv7 as `BINARY(16)` in DB, canonical string in API. Enums = `VARCHAR` + `CHECK`.
- Financial rows immutable (reversal/refund records, never edits). Sensitive actions audited (append-only hash-chained `audit_log`, same transaction as the change) and permission-checked (permission-based, never role-name-based).
- Mutating endpoints take an `Idempotency-Key` header; a replay returns the original result. Scarce-resource operations (slots, tickets, stock, payments) use DB constraints / conditional updates / row locks and have **real concurrent tests against real MySQL** (not SQLite).
- Two-node model (ADR-0013): `APP_NODE=local|cloud`, same codebase. State-changing domain events that must reach the other node are written to the **outbox in the same DB transaction** (see `architecture/sync/`). Redis is never authoritative storage.
- API style: `/api/v1`, camelCase JSON, RFC 7807 problem+json errors with stable `code`, cursor pagination, ISO-8601 UTC.
- No secrets in git, ever. Only `.env.example` with placeholders. Do not print or log secrets.

## Shared local environment (already running — do NOT stop or restart)

- PHP 8.5 + Composer on PATH; .NET SDK at `~/.dotnet` (`export DOTNET_ROOT=$HOME/.dotnet PATH=$HOME/.dotnet:$PATH`); Flutter on PATH; Node 24.
- MySQL 8.4: `export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"`; `mysql -u root` (no password), TCP 127.0.0.1:3306. **Use your own database name** (`r007_<yourscope>`, plus `_test`) so agents don't collide. Never drop databases you didn't create.
- Redis on 127.0.0.1:6379 — use a distinct Redis DB index / key prefix per agent.
- Do not bind common ports blindly; pick a port derived from your scope and say which in your report.

## Git workflow (IMPORTANT — several agents work concurrently)

1. **Never work in the shared clone's checkout.** Create your own worktree: `git -C <clone> worktree add ../work/<scope> -b <branch> <base>` and work only there. (Create the `work/` dir next to the clones.) Remove nothing that isn't yours.
2. `main` is protected. **Merging to main is currently blocked by the environment** — do NOT try to merge PRs into main and do NOT try to bypass this. Instead: push your feature branch, open a PR (`gh pr create`) with a clear body, get CI green, and **stack on other agents' branches when you depend on them** (base your branch on theirs; say so in the PR). Where your instructions name a base branch, use it.
3. Commits: Conventional Commits, each ending with the trailer line `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Commit early and often; push often. Never force-push shared branches.
4. Check for secrets before committing (`git diff --cached`); `.env` files are git-ignored.
5. CI: check with `gh run list -R prinzderick/<repo> --branch <branch> --limit 3`; block on a specific run with `gh run watch <id> -R prinzderick/<repo> --exit-status` (foreground). Fix failures. If something is genuinely un-fixable (e.g. needs a paid GitHub feature), record it and move on.
6. **Do the work yourself. Do NOT spawn sub-agents or background jobs and then return early.** Do not end your turn until your scope is implemented, tested, pushed, and you have written the final report. Long tasks are fine.

## Decisions

Make the best call for this project yourself (record it in code comments/PR body, and in a short ADR under `007resort-docs/adr/` only if it is architecture-level). **Stop and ask only for a genuinely critical engineering decision that cannot be reasonably defaulted.** Owner-confirmed already: Paystack (ADR-0009), VAT admin-settable default off (ADR-0011), ZKTeco biometric terminal, Laravel + dual-node (ADR-0012/13), VPS for Cloud (ADR-0014), NGN currency, timezone Africa/Lagos.

## Definition of done for your scope

Schema/migration + business rules + authorization + audit (where applicable) + validation + failure states + tests (incl. concurrency tests for scarce resources) + docs (README/CONTRIBUTING/OpenAPI where relevant) + pushed + CI green. End with a report: what shipped (files/endpoints), test results, PR URL(s), decisions made, what is left, and anything the next agent must know (ports, seeded credentials for dev, env vars).
