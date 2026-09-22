# ADR-0009: Payment provider — Paystack primary, behind a provider adapter

Status: Accepted
Date: 2026-09-22
Deciders: 007 Resort & Spa (owner), engineering recommendation

## Problem

The Payments module ([architecture/07](../architecture/07-payment-state-model.md)) needs a concrete card/mobile-money provider to integrate against for `AUTHORIZING`/`CAPTURED` transitions and webhook-driven confirmation ([architecture/04 §3.3](../architecture/04-database-schema.md#33-provider_event-and-idempotency_record--duplicate-payment-protection)). This was left open as [Q1](../architecture/20-open-questions.md).

## Decision

Build the `Payments` module's provider integration behind a small `IPaymentProviderAdapter` interface (initiate/capture, verify, refund, and a webhook-signature-verification method), and implement the first concrete adapter for **Paystack**. Paystack is chosen as the initial, default-configured provider because:

- It is one of the two dominant providers for Nigerian card, bank transfer and USSD payments (the property's currency and locale conventions already assume NGN and `Africa/Lagos`, per [architecture/16](../architecture/16-deployment-topology.md) and the infrastructure scaffolding).
- Its REST API and webhook model map cleanly onto the `provider_event` dedup pattern already designed ([architecture/04 §3.3](../architecture/04-database-schema.md#33-provider_event-and-idempotency_record--duplicate-payment-protection)): each webhook carries a unique event reference, and transaction verification is a simple secondary GET, which lets the adapter double-check a webhook's claim before trusting it (defense in depth against a spoofed callback).
- It supports split settlement/subaccounts, which may be useful later for reconciliation reporting ([architecture/16 finance reporting](../architecture/16-deployment-topology.md)), without being required for Phase 2.

**Flutterwave** is the designed-for second adapter (same interface), not built in the first pass, so the property is not single-vendor-locked and a provider outage or a commercial renegotiation does not require an architecture change — only a new adapter implementation and a configuration flip.

## Alternatives considered

- **Flutterwave as primary.** Comparable coverage and API quality; Paystack is chosen first mainly because its webhook/verification model was slightly simpler to map onto the idempotency design above. This is a close call and easily revisited — hence the adapter pattern rather than a hard-coded integration either way.
- **A payment orchestration platform** (e.g., a provider-agnostic aggregator) to avoid picking one now. Rejected for Phase 1/2: adds a third-party dependency and cost for a single-property system where a direct integration is simple enough, and the adapter interface already gives most of the switching benefit without that cost.
- **Deferring provider choice entirely** until Phase 2 begins. Rejected: the `Payments` module's webhook/idempotency plumbing needs a concrete shape to implement and test against now; a null/simulated adapter would leave the highest-risk concurrency test (C-4, duplicate payment callbacks — [architecture/18 §3](../architecture/18-testing-strategy.md#3-critical-concurrency-tests-mandatory-tracked-to-completion-before-phase-2-sign-off)) untested against a realistic webhook shape.

## Consequences

- **This is an engineering recommendation, not a signed commercial decision.** Actually opening a Paystack merchant account, agreeing settlement terms, and obtaining live API keys is a business step for the client/owner, not something performed here. Development proceeds against Paystack's test/sandbox keys.
- Live API keys, webhook secrets and any merchant credentials are never committed — they follow the existing secrets convention ([architecture/17 §6](../architecture/17-security-model.md#6-secrets-management)): environment variables / secret store only, documented as placeholders in `.env.example`.
- If the client's finance team has an existing provider relationship or a regulatory reason to prefer a different provider, that overrides this ADR — file a new ADR superseding this one; the adapter pattern means the cost of that change is one new adapter class, not a redesign.
