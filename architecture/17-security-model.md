# 17 — Security Model

Status: **DRAFT, awaiting review**

## 1. Authentication

| Principal | Mechanism |
| --- | --- |
| Staff, fixed POS | NFC card **+** PIN/password. Never NFC alone ([spec §16, §24](../spec/)) |
| Staff, shared/supervisor tablets | Sign-in per checkout/session; step-up PIN for sensitive actions |
| Staff, remote (admin-web) | Password (Argon2id hashing) + MFA (TOTP) for Owner/Manager/Accounts/IT where practical ([spec §24](../spec/)) |
| Customers | Password or passwordless (magic link/OTP) via `007resort-booking-web`, separate identity space from staff |
| Devices (POS/tablet/KDS) | Device registration issuing a device credential (client cert or rotating secret) bound to the device record; requests carry both the staff session and the device identity |
| Site ↔ Cloud sync | Mutual TLS or a signed, rotating pre-shared credential issued at commissioning; never a static long-lived shared secret without rotation |
| Payment provider webhooks | Provider signature verification; failed-signature requests are rejected and logged as a security event, never processed |

No shared administrative credentials — every account is individual ([spec §14](../spec/)).

## 2. Authorization

Permission-based, scoped, described fully in [06](06-roles-permissions.md). Every mutating endpoint declares the permission(s) it requires; a policy handler resolves `staff × permission × scope (organization/site/facility)` against `role_assignment`, with `requires_approval` escalation where configured. A role name alone never grants an action.

## 3. Sessions and device management

- Access tokens are short-lived (JWT, ~15 min) with a rotating refresh token; refresh tokens are revocable server-side (`session` table), so "sign out everywhere" and lost-device revocation are immediate, not just a client-side token expiry.
- Device registration can be revoked independently of staff sessions (a stolen tablet is disabled at the device level even if a valid staff session token is cached on it).
- Session/device revocation and security events are visible to IT/Admin in `007resort-admin-web` ([spec §9, §24](../spec/)).

## 4. Transport and data protection

- HTTPS/TLS for all online services (cloud, and the site's own LAN traffic where practical) — no plaintext credentials or payment data on the wire ([spec §14](../spec/)).
- Passwords: one-way hashing (Argon2id). PINs: hashed, not stored reversibly.
- Backups are protected from ordinary staff access (encrypted at rest, access restricted to IT/Admin — [spec §14](../spec/), [16](16-deployment-topology.md)).
- Public cloud services never expose the local database directly — enforced by the outbound-only sync topology ([12](12-sync-strategy.md)).

## 5. Audit and observability

- Every sensitive action ([06](06-roles-permissions.md)) writes an `audit_log` row: actor, facility, operating point, terminal/device, action, timestamp, old/new value, approver where applicable — append-only and hash-chained ([04 §3.5](04-database-schema.md#35-audit_log--tamper-evident)).
- Structured JSON logs (Serilog) capture API errors, failed payment callbacks, sync failures, booking conflicts, device connectivity issues, background worker failures, and authentication/security events — **never** plaintext passwords, payment secrets, private keys, or unnecessary personal data ([spec §27](../spec/)).
- OpenTelemetry traces/metrics with correlation IDs flowing from client request through to the database call, for diagnosing production incidents without needing to reproduce them.

## 6. Secrets management

- No secret (password, API key, payment credential, DB credential, certificate, signing key) is ever committed to any repository — enforced by `.gitignore` patterns and a `gitleaks` CI job on every repository ([ADR pending: secret-scanning policy is already applied from day one, formalized as needed]).
- Local/site secrets live in environment variables or a Windows-protected configuration store (e.g. DPAPI-protected `secrets.json`, or a proper secrets manager if hosting allows); cloud secrets live in the hosting provider's secret manager.
- `.env.example` / configuration templates document every required variable with placeholder values only.

## 7. Network security

Covered in [16 §1](16-deployment-topology.md#1-on-site): logical VLAN separation (SERVER, POS/OPERATIONS, CCTV, STAFF, GUEST), Guest Wi-Fi isolated from all operational systems, CCTV pre-existing and isolated ([spec §21](../spec/)).

## 8. Hardware abstraction and vendor neutrality

Printers, NFC readers, barcode/QR scanners, biometric attendance and payment integrations sit behind interfaces (`IReceiptPrinter`, `INfcReader`, `IBarcodeScanner`, a biometric adapter, a payment provider adapter) so no business logic is coupled to one manufacturer, and a vendor swap does not touch application logic ([spec §22](../spec/)).
