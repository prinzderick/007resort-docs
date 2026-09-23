# Conflict Resolution Matrix

Status: **DRAFT, awaiting review**. Companion to [ADR-0013](../../adr/0013-dual-node-local-cloud-sync.md).

## Principle

"Conflict" is not one thing — different domains fail in different ways and need different resolutions. Every conflict is recorded (never silently dropped or silently overwritten) and is one of the categories below, never an ad hoc "last write wins."

| Category | When it happens | Resolution | Who resolves |
| --- | --- | --- | --- |
| `CONFIGURATION_CONFLICT` | A `ConfigurationUpdated` event (product, price, facility rule) arrives carrying an `entity_version` older than the receiver's current version | The incoming event is **rejected, not applied**; recorded for review | Manager/IT reviews in `007resort-admin-web` and re-applies the intended change against the current version |
| `PERMISSION_CONFLICT` | A `StaffRosterUpdated` event (role assignment) arrives stale, same version-check as configuration | Rejected, recorded | Manager/IT reviews and re-applies |
| `BOOKING_CONFLICT` | Does not occur under normal operation — the atomic unique-constraint mechanism at the single Booking Authority ([Booking Authority & Offline Allocation](booking-authority-and-offline-allocation.md)) prevents it by construction. Can occur only if an offline-allocation pool is exceeded (a manual override was used beyond the configured reserve) | Not auto-resolved — the overrun booking(s) are flagged for Reception/Management to manually contact the affected customer(s) and resolve (reschedule, refund, or honor with an operational accommodation) | Manager, with customer contact |
| `INVENTORY_CONFLICT` | Does not occur under normal operation — stock movements are Local-authoritative and single-writer ([Domain Authority Matrix](../23-domain-authority-matrix.md)). Could occur only from a data-entry error synced from two systems in a hypothetical future integration | Flagged for manual stock count/adjustment | Storekeeper/Manager |
| `ENTITY_VERSION_CONFLICT` | Generic case: any versioned entity's event arrives with a version gap larger than 1 (an intermediate event was missed or is still in flight) | The event is **deferred and retried** (not treated as a hard conflict) until the intermediate version arrives or a timeout elapses, at which point it escalates to a genuine conflict for review | IT, if it escalates |

## Rules

1. **Financial conflicts are never resolved by deleting or replacing a transaction.** If a genuine financial discrepancy is found (which the design above should make rare-to-never, since payments are single-writer per [Domain Authority Matrix](../23-domain-authority-matrix.md)), the resolution is a new reversal/correction record, exactly as the existing immutable-financial-history rule already requires ([architecture/07](../07-payment-state-model.md)) — never an edit to the original row.
2. **Every conflict is visible** in the sync observability views ([Heartbeat / Node Health §4](heartbeat-and-node-health.md#4-observability-requirements)), with enough detail (entity, both versions, both payloads) for a human to actually resolve it — a conflict that just says "conflict" is not useful.
3. **Automatic resolution is used only where it is provably safe** — the offline-allocation pool split is "automatic" in the sense that reconciliation merges disjoint ranges without human input, but that safety comes from the ranges never overlapping in the first place, not from a clever merge algorithm resolving an actual clash.
