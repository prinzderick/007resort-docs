# 26 — Windows Local Server Deployment Specification (Local Node)

Status: **DRAFT, awaiting review**. Per [ADR-0012](../adr/0012-migrate-backend-to-laravel.md) (Laravel) and [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md) (dual-node). Supersedes the "Windows service running a compiled .NET binary" framing in [architecture/16 §1](16-deployment-topology.md#1-on-site) and `007resort-infrastructure/scripts/windows/install-api-service.ps1`, which assumed ASP.NET Core.

## 1. Why Windows, still

The property's local server hardware and OS choice ([architecture/16 §1](16-deployment-topology.md#1-on-site), spec hardware baseline) is unchanged by the backend language decision — this spec describes running PHP/Laravel reliably on that same Windows Server, not a hardware change.

## 2. Software stack

| Layer | Choice |
| --- | --- |
| Web server | IIS with a FastCGI handler to PHP, **or** a lightweight reverse-proxy setup (e.g. `nginx-for-windows` or Caddy) in front of PHP-FPM-for-Windows, whichever proves more reliable in practice — decided during implementation with a documented rationale, not fixed here |
| PHP runtime | PHP for Windows (thread-safe build if using IIS's FastCGI, non-thread-safe if using a proxy + PHP-FPM), version matching the Cloud node exactly (same Laravel release, same PHP version on both nodes — a version mismatch between Local and Cloud is exactly the kind of divergence [ADR-0012](../adr/0012-migrate-backend-to-laravel.md) exists to avoid) |
| Application | Laravel (`APP_NODE=local`) |
| Database | MySQL 8.4 Community Server for Windows, InnoDB, `utf8mb4` |
| Cache/queue/broadcasting | Redis for Windows (via Memurai or WSL2-hosted Redis — native Windows Redis builds are unmaintained upstream; this choice is made explicitly rather than assumed) |
| Real-time | Laravel Reverb (or the chosen broadcaster), run as a Windows service |
| Process supervision | **Windows Services**, not manual `php artisan queue:work` — see §3 |

## 3. Process supervision — nothing runs by a human remembering to start it

The migration brief is explicit: "Do not depend on someone manually running `php artisan queue:work` after reboot." Every long-running process is registered as a Windows Service, auto-start, with failure-recovery configured (restart on crash):

| Process | Windows Service | Recovery on crash |
| --- | --- | --- |
| Web server (IIS or the chosen proxy) | Native Windows service (IIS) or NSSM-wrapped | IIS: built-in; proxy: NSSM auto-restart |
| PHP-FPM (if not using IIS's own FastCGI process manager) | NSSM-wrapped | Auto-restart |
| Queue worker(s) (`artisan queue:work`) | NSSM-wrapped, one service per queue where separation is useful (e.g. a dedicated sync-outbox queue vs. general jobs) | Auto-restart; Laravel's own `--tries`/backoff still applies per job |
| Scheduler (`artisan schedule:run`) | Windows Task Scheduler, triggered every minute (this is the standard Laravel pattern even on Linux via cron — Windows Task Scheduler is the direct equivalent, not a workaround) | Task Scheduler's own retry/history |
| Reverb (real-time) | NSSM-wrapped | Auto-restart |
| Sync outbox/inbox worker | Covered by the general queue worker(s) above, since sync jobs are ordinary Laravel queue jobs | Same |
| MySQL, Redis | Their own native Windows service installers | Native service recovery |

[NSSM](https://nssm.cc/) (or an equivalent Windows service wrapper) is named because it's the standard, well-understood way to run an arbitrary long-lived process (like `php artisan queue:work`, which has no native Windows service mode) as a properly supervised Windows Service — this is an implementation detail worth naming so the requirement ("must survive reboot, must auto-restart on crash") has one concrete, provable way to be satisfied, not left as "somehow make it a service."

`007resort-infrastructure/scripts/windows/install-api-service.ps1` (currently written for a compiled .NET binary) is rewritten to install this Laravel/PHP process set instead — tracked as implementation work once the Laravel app exists to install.

## 4. Network exposure

Unchanged from [architecture/16 §1](16-deployment-topology.md#1-on-site) — logical VLAN separation (SERVER, POS/OPERATIONS, CCTV, STAFF, GUEST), the Local server is reachable from the property LAN/Wi-Fi only, and its **only** outbound-to-internet traffic is the sync channel to Cloud and routine OS/package updates. Nothing on Local is ever directly reachable from the public internet ([ADR-0005](../adr/0005-site-authoritative-local-first-with-outbound-sync.md), [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md)).

## 5. Backup

Independent of sync, per [ADR-0013](../adr/0013-dual-node-local-cloud-sync.md) consequences and [architecture/16](16-deployment-topology.md)'s existing backup requirement: automated local MySQL backup to the backup NAS, with an additional off-site/cloud copy (which may itself travel over the same sync channel's transport, but is a distinct backup artifact, not "backup via sync").

## 6. Commissioning checklist (summary)

Install Windows Server prerequisites (IIS/proxy, PHP, MySQL, Redis-for-Windows) → deploy Laravel application files → configure `.env` for `APP_NODE=local` → run `artisan migrate` (applying the same versioned migrations as Cloud) → install all long-running processes as Windows Services per §3 → configure the backup job → configure the sync channel's outbound credential → verify the heartbeat reaches Cloud → verify a full order-to-payment-to-audit flow locally → verify the property continues operating with the local server's internet connection pulled ([architecture/18](18-testing-strategy.md) offline test).
