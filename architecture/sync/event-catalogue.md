# Synchronization Event Catalogue

Status: **DRAFT, awaiting review**. Companion to [ADR-0013](../../adr/0013-dual-node-local-cloud-sync.md) and the [Outbox/Inbox Design](outbox-inbox-design.md).

## Envelope (every event, both directions)

| Field | Type | Notes |
| --- | --- | --- |
| `event_id` | UUIDv7 | Generated once, at the originating node. The dedup key at the receiver |
| `event_type` | string | e.g. `OrderCreated` — see catalogue below |
| `entity_type` | string | e.g. `order` |
| `entity_id` | UUIDv7 | The affected row's id |
| `organization_id`, `site_id`, `facility_id` | UUIDv7 (nullable where n/a) | Scoping, per [architecture/03](../03-domain-model.md) |
| `entity_version` | integer | The entity's version *after* this event, for out-of-order safety |
| `source_node` | string | `local` or `cloud` |
| `occurred_at` | UTC datetime(6) | When the originating transaction committed |
| `payload` | JSON | Event-specific data — never the full row, only what the receiver needs to apply the effect |
| `sync_status` | enum | `LOCAL, QUEUED, SYNCING, SYNCED, CONFLICT, FAILED` |
| `retry_count` | integer | |
| `last_attempt_at` | UTC datetime(6), nullable | |
| `error` | JSON, nullable | Last failure detail, for observability |

## Events originated at Local

| Event | Entity | Payload highlights | Consumed by Cloud for |
| --- | --- | --- | --- |
| `OrderCreated` | order | facility, staff, lines summary | Consolidated reporting |
| `OrderUpdated` | order | changed lines/status | Reporting |
| `PaymentCompleted` | payment | amount, tender type, order refs | Reporting, reconciliation |
| `PaymentReversed` | payment/reversal | original payment ref, reason | Reporting, reconciliation |
| `StockReceived` | stock_movement | item, qty, location | Reporting |
| `StockTransferred` | stock_movement (pair) | item, qty, from/to location | Reporting |
| `StockConsumed` | stock_movement | item, qty, order ref | Reporting |
| `StockAdjusted` | stock_movement | item, qty delta, reason, approver | Reporting, audit |
| `TicketRedeemed` | redemption | entitlement item, action, device | Reporting, audit |
| `RentalReleased` / `RentalReturned` | redemption | entitlement item, device, staff | Reporting |
| `StaffClockedIn` / `StaffClockedOut` | attendance_punch | staff, device, timestamp | Reporting, attendance summaries |
| `MembershipUsageRecorded` | membership_usage | membership, facility, timestamp | Reporting |
| `MembershipPurchased` (in-person) | membership | plan, customer, staff, payment ref | Consolidated membership roster |
| `BookingConfirmedLocally` | booking | resource, slot, within offline allocation — see [Booking Authority](booking-authority-and-offline-allocation.md) | Reconciliation of the offline allocation pool |
| `AuditRecorded` | audit_log | actor, action, entity, hash-chain fields | Consolidated audit trail (Cloud keeps its own chain per node, never merges chains — see [Domain Authority Matrix](../23-domain-authority-matrix.md)) |

## Events originated at Cloud

| Event | Entity | Payload highlights | Consumed by Local for |
| --- | --- | --- | --- |
| `OnlineBookingCreated` | booking | resource, slot, customer, entitlement | Creating the corresponding local booking/entitlement record so Reception and on-site validation see it |
| `OnlineBookingCancelled` | booking | booking ref, reason | Releasing the slot locally |
| `BookingRescheduled` | booking | old/new slot | Updating local slot allocation |
| `OnlinePaymentConfirmed` | payment | amount, provider event ref | Local financial reporting; unlocks fulfilment for the linked order/booking |
| `OnlineOrderCreated` | order | facility, lines, fulfilment type | Local order/KDS creation — **only sent if the heartbeat/availability gate in [Booking Authority §4](booking-authority-and-offline-allocation.md#4-immediate-online-orders) passed at Cloud before acceptance** |
| `MembershipPurchased` (online) | membership | plan, customer, payment ref | Local membership validation cache |
| `AppointmentCreated` | booking (appointment) | resource (e.g. spa), slot, customer | Local schedule |
| `ConfigurationUpdated` | facility/product/price/rule | domain, changed fields, new version | Local applies if the incoming version is newer than its local version (see [Conflict Resolution Matrix](conflict-resolution-matrix.md)); otherwise raises a `CONFIGURATION_CONFLICT` |
| `StaffRosterUpdated` | staff/role_assignment | domain, changed fields, new version | Same version-checked apply as configuration |
| `HeartbeatAck` | — | cloud's view of local's last-known state | Diagnostic only, not a business event |

## Events originated at either node (website CMS content)

Website content (settings, home blocks, pages, blog, events, gallery, media) is authoritative on the node where an editor edits it (normally Cloud, where the website reads). The API module `app/Domain/Cms` writes these to the outbox in the change's transaction when `CMS_SYNC_EMIT=true` (default off until the receiving appliers exist; an event type without an applier is stored `FAILED` on the peer). Contract: `007resort-api` `docs/CMS_API.md` section 7. Newsletter subscribers and contact messages originate on the website (Cloud) and are not synced to Local by default.

| Event | Entity | Payload highlights | Consumed for |
| --- | --- | --- | --- |
| `CmsContentPublished` | `cms_page`, `cms_post`, `cms_event`, `cms_gallery_album`, `cms_home_section`, `cms_setting` | `entity`, `id`, `action` (`create`, `update`, `publish`, `unpublish`, `archive`, `delete`), `snapshot` (admin representation) | Version-checked upsert on the peer (same rule as `ConfigurationUpdated`, `entity_version` = `row_version`, last writer wins) |
| `CmsMediaUploaded` | `cms_media` | `id`, `path`, `sha256`, `width`, `height`, `mimeType`, `alt`, `credit`, `sourceUrl`, `tags`, `variants[]` | Peer fetches the binary from the origin's public media URL (verifying `sha256`) or from shared object storage, then registers the row |

## Rules that apply to every event in this catalogue

1. **Idempotent by `event_id`.** A receiver that has already applied `event_id` X treats a redelivery as a no-op and still acknowledges it (so the sender can mark it `SYNCED` and stop retrying).
2. **Applied inside one local transaction**, alongside any inbox bookkeeping — never "apply the effect, then separately record that it was applied" as two commits.
3. **Version-checked where the entity is editable from both nodes** (configuration, staff roster) — an event carrying a stale `entity_version` is rejected into `CONFIGURATION_CONFLICT`/`PERMISSION_CONFLICT`, never silently overwritten (per [ADR-0013](../../adr/0013-dual-node-local-cloud-sync.md) §4 and the [Conflict Resolution Matrix](conflict-resolution-matrix.md)).
4. **Append-only domain events are never edited or deleted** after being queued — a correction is a new event (e.g. `PaymentReversed`, not an edited `PaymentCompleted`), consistent with the immutable-financial-history rule already established for the local schema.
5. New event types are added to this catalogue in the same pull request that implements them — this file is expected to grow through Phase 2–9, not be finished now.
