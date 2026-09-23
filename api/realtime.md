# Realtime contract (Laravel Reverb, Pusher protocol)

Status: **v1, contract of record** alongside [`openapi/v1.yaml`](openapi/v1.yaml).

Realtime is a **hint channel**, not a source of truth. Every event tells a client "something changed"; the REST API is the authority. Payloads carry enough to update UI immediately, but a client that misses events must be able to recover by reloading state over REST.

## 1. Connection

| Item | Value |
| --- | --- |
| Server | Laravel Reverb, Pusher protocol 7 |
| WebSocket URL | `ws(s)://{host}:{reverbPort}/app/{appKey}` (local dev: port `8081`; the node exposes host/port/key in `GET /api/v1/system/info` under `realtime`, and in client config) |
| App key | Public key only. The secret never leaves the server |
| Client libs | Flutter: `pusher_channels_flutter` or `laravel_echo`-compatible; TypeScript (KDS): `pusher-js`; C#: `PusherClient`/plain WebSocket implementing the Pusher protocol |
| Channels | All channels are **private** (`private-` prefix). No presence channels in v1 |
| Nodes | Each node (Local, Cloud) runs its own Reverb. Clients on the property LAN connect to Local. Cloud realtime is for online/admin clients only; Local and Cloud do **not** relay socket events to each other (they sync via the outbox) |

## 2. Authorising a channel

`POST /api/v1/broadcasting/auth`

Headers: `Authorization: Bearer <accessToken>`, `X-Device-Token`, `Content-Type: application/json`.

```json
{ "socket_id": "1234.5678", "channel_name": "private-kds.station.0192f6a0-0000-7000-8000-000000000901" }
```

The endpoint accepts `application/json` and `application/x-www-form-urlencoded` (what stock Pusher clients send).

Response `200` (standard Pusher private auth):

```json
{ "auth": "reverbAppKey:hmacsha256signature" }
```

Errors are RFC 7807 problems: `401 unauthenticated`, `403 permission_denied` (caller may not subscribe to that channel). Clients pass this endpoint as the `authEndpoint` and must add both headers.

### Authorisation rules

| Channel | Allowed when |
| --- | --- |
| `private-kds.station.{stationId}` | Staff holds `prep_ticket.view` and the device is a `KDS_SCREEN` (or any device checked out) at the station's facility |
| `private-facility.{facilityId}.orders` | Staff holds `order.view` or `order.create` at that facility scope, and the device is checked out at that facility |
| `private-device.{deviceId}` | The presented `X-Device-Token` belongs to exactly `deviceId` (a device may only listen to itself) |
| `private-site.status` | Staff holds `config.manage` or `report.view`, or the caller is a `KDS_SCREEN`/`POS_TERMINAL` device (health banner) |

Channel authorisation is re-evaluated only at subscribe time. Revoking a session or device also closes its sockets server-side (Reverb `disconnect`), and clients must treat an unexpected close followed by a failed re-auth as "logged out".

## 3. Event envelope

Every event is a JSON object delivered as the Pusher `data` string (JSON-encoded), with these common fields:

```json
{
  "eventId": "0192f6a1-...",
  "occurredAt": "2026-09-23T10:15:30.123456Z",
  "correlationId": "c1f4e7a2-...",
  "data": { }
}
```

| Field | Meaning |
| --- | --- |
| `eventId` | UUID; clients dedupe on it (delivery is at-least-once) |
| `occurredAt` | Commit time of the change on the node |
| `correlationId` | The `X-Correlation-Id` of the request that caused it, for tracing |
| `data` | Event-specific payload below. Money is decimal strings, ids are UUIDs, camelCase, like REST |

Events are broadcast **after** the database transaction commits (`ShouldBroadcast` after-commit), so a client that receives an event and then calls REST will always see the change.

## 4. Channels and events

### `private-kds.station.{stationId}`

| Event | When | `data` |
| --- | --- | --- |
| `prep-ticket.created` | An order containing items routed to this station is sent | `{ "ticket": PrepTicket }` |
| `prep-ticket.updated` | Status change, item change, cancellation (void) | `{ "ticket": PrepTicket, "previousStatus": "NEW" }` |

`PrepTicket` is the same schema as `GET /kds/stations/{id}/tickets` items (OpenAPI `PrepTicket`):

```json
{
  "ticket": {
    "id": "0192f6a0-0000-7000-8000-000000000a01",
    "number": "K-042",
    "stationId": "0192f6a0-0000-7000-8000-000000000901",
    "orderId": "0192f6a0-0000-7000-8000-000000000601",
    "orderNumber": "RST1-000123",
    "facilityId": "0192f6a0-0000-7000-8000-000000000101",
    "tableLabel": "T12",
    "status": "NEW",
    "items": [{ "orderLineId": "0192f6a0-0000-7000-8000-000000000701", "name": "Jollof Rice & Chicken", "quantity": 2, "notes": "no pepper", "status": "NEW" }],
    "createdAt": "2026-09-23T10:15:30.123456Z",
    "acceptedAt": null,
    "readyAt": null,
    "waiterStaffId": "0192f6a0-0000-7000-8000-000000000401",
    "waiterName": "Amaka O.",
    "rowVersion": 1
  }
}
```

A ticket whose `status` becomes `DISPENSED` or `CANCELLED` is removed from the board after the event; clients should drop it from the active list.

### `private-facility.{facilityId}.orders`

| Event | When | `data` |
| --- | --- | --- |
| `order.updated` | Any order state/line/totals/payment change at the facility | `{ "order": OrderSummary, "changed": ["status","lines","payment"], "rowVersion": 4 }` |
| `order.ready` | All routed items of an order are READY (attendant should serve) | `{ "orderId", "orderNumber", "tableId", "tableLabel", "stationIds": [], "waiterStaffId", "readyAt" }` |
| `table.updated` | Table status or occupancy changed | `{ "table": DiningTable }` |

`order.updated` carries the lightweight `OrderSummary`, not lines. A client holding the order open should refetch `GET /orders/{id}` when `rowVersion` is greater than its cached one.

```json
{ "orderId": "0192f6a0-0000-7000-8000-000000000601", "orderNumber": "RST1-000123", "tableId": "0192f6a0-0000-7000-8000-000000000201", "tableLabel": "T12", "stationIds": ["0192f6a0-0000-7000-8000-000000000901"], "waiterStaffId": "0192f6a0-0000-7000-8000-000000000401", "readyAt": "2026-09-23T10:31:02Z" }
```

### `private-device.{deviceId}`

| Event | When | `data` |
| --- | --- | --- |
| `approval.requested` | A sensitive action needs a decision from a supervisor **on this device** (sent to the supervisor's checked-out device and to any device where the supervisor is logged in; also to devices at the facility whose staff hold the approve permission) | `{ "approval": Approval }` |
| `approval.decided` | An approval requested by this device's staff was approved/rejected/expired | `{ "approval": Approval, "applied": true, "orderId": "..." }` |
| `device.command` | Admin/system commands | `{ "command": "FORCE_LOGOUT\|REFRESH_STATE\|LOCK\|REVOKE", "payload": {} }` (OpenAPI `DeviceCommand`) |

Supervisor devices also receive `approval.requested` on the facility's `private-device.{supervisorDeviceId}` channels only for supervisors currently checked out. Unsubscribed or offline supervisors find pending items via `GET /approvals?scope=approvable`.

### `private-site.status`

| Event | When | `data` |
| --- | --- | --- |
| `site.health` | Node health changes, and every 30 s as a keep-alive | `{ "status": "ONLINE\|DEGRADED\|OFFLINE", "checks": { "database": "ok", "redis": "ok", "queue": "ok", "cloudLink": "degraded" }, "outboxDepth": 0, "serverTime": "..." }` |

`site.health` doubles as a **server liveness signal**: if a client sees no `site.health` for 75 s while connected, it treats the socket as stale and reconnects.

## 5. Reconnect and recovery (mandatory client behaviour)

1. Delivery is at-least-once with no replay. **Events missed during a disconnect are lost.**
2. After every (re)connect and re-subscribe, the client MUST reload full state over REST before trusting the live stream:
   - KDS: `GET /kds/stations/{id}/tickets`
   - Attendant app: `GET /orders?filter[facilityId]=...&filter[status]=...`, `GET /tables?facilityId=...`, and `GET /approvals?scope=mine`
   - Supervisor: `GET /approvals?scope=approvable`
   - Any device: `GET /devices/{id}` (pending commands via `GET /devices/{id}/commands`)
3. Use exponential backoff with jitter (1 s to 30 s cap) and re-authorise each channel on reconnect (the socket id changes).
4. Apply events idempotently: ignore an event whose `eventId` was seen, and ignore an entity update whose `rowVersion` is not greater than the cached one.
5. When the socket is down for longer than 10 s, show an "offline / reconnecting" indicator and fall back to REST polling every 10 s for the screen in view (KDS board, order status).
6. Never mutate business state on receiving an event; only update local view caches.
