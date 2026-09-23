# ADR-0011: VAT/tax status is an admin-configurable setting, not a fixed build decision

Status: Accepted
Date: 2026-09-22
Deciders: 007 Resort & Spa (owner), engineering recommendation

## Problem

[Q7](../architecture/20-open-questions.md) asked whether the property is VAT-registered and whether receipts need a VAT breakdown — a fact that affects the Catalog/Pricing module's tax handling and receipt rendering ([architecture/03](../architecture/03-domain-model.md), Catalog & Pricing: `tax_rate`, `product_facility`). The owner's answer was that this should be **admin-settable**, not hard-decided now.

## Decision

Tax handling is configuration, following the same "configure, don't hardcode" principle already used for facility capabilities ([ADR-0008](0008-facility-capability-engine.md)):

- An **organization-level setting** `vat_registered` (boolean, default `false`) and `default_vat_rate` (percentage, default `7.5` — the Nigeria standard rate, inactive until `vat_registered` is turned on), plus a `tax_identification_number` (TIN) field for printing on receipts/invoices once registered.
- These live in the Organization module (a small `organization_tax_setting` table or columns on `organization`, decided at migration-review time) and are editable from `007resort-admin-web`'s Configuration screens by Owner/Manager/Accounts roles ([architecture/06](../architecture/06-roles-permissions.md)) — never by editing code or config files on a server.
- The existing `tax_rate` / product-tax association mechanism ([architecture/03](../architecture/03-domain-model.md)) already supports per-product or per-category overrides of the organization's default rate (e.g. a VAT-exempt item), so turning VAT on organization-wide does not force every product onto the same rate.
- Receipt and invoice rendering (POS receipts, booking confirmations, settlement reports) checks `vat_registered` at render time: when `false`, receipts show gross totals with no tax line; when `true`, they show the VAT line and the TIN. No separate "VAT edition" of the receipt template — one template, data-driven.
- Changing this setting is itself a configuration change and therefore audited like any other sensitive configuration edit ([architecture/17](../architecture/17-security-model.md)), since it affects every receipt and financial report going forward.

## Alternatives considered

- **Decide VAT status now, bake it into the schema/build.** Rejected: the owner explicitly asked for it to be admin-settable, and Nigerian small-business VAT-registration status can change (e.g. crossing a revenue threshold), so hardcoding it would force a redeploy for what should be an admin action.
- **A build-time feature flag** (compiled in/out per environment). Rejected: same inflexibility as hardcoding, just moved to build config instead of the database; also inconsistent with every other facility/business-rule setting in this system being runtime configuration.

## Consequences

- Phase 2 (Catalog & Pricing) implementation must include this setting and the receipt-rendering branch from the start, rather than adding it as an afterthought once real transactions exist.
- Because the default is `vat_registered = false`, the system is usable immediately without VAT complexity, and can be switched on the moment the business registers — without an engineering change.
