# Workflow: Sports booking, ticketing and equipment

Reception handles payment for Pool, Sports Arena, Sports Store, equipment rental and Pool Bar ([spec §6](../spec/)); neither Sports Arena nor Sports Store has its own payment terminal.

```mermaid
sequenceDiagram
  actor R as Reception cashier (POS)
  participant API as otueke-api
  actor SE as Sports Entrance tablet
  actor SS as Sports Store tablet

  R->>API: POST /bookings/hold {resource, slot}
  API-->>R: 201 HELD (or 409 if slot just taken)
  R->>API: add optional equipment rental / Sports Store items
  R->>API: POST /payments (capture)
  API->>API: POST /bookings/{id}/confirm -> issue entitlement (ACCESS + RENTAL + GOODS items)
  API-->>R: QR / entitlement reference
  R->>R: Print receipt with QR

  Note over SE: Later, at the gate
  SE->>API: POST /entitlements/{id}/redeem {action: ENTRY}
  API-->>SE: VALID | USED | EXPIRED | WRONG_FACILITY | NOT_YET_VALID | CANCELLED

  Note over SS: Customer proceeds to Sports Store
  SS->>API: GET /entitlements/{id}
  API-->>SS: exactly what was paid/rented
  SS->>API: POST /entitlements/{id}/release
  API-->>SS: confirmed (or rejected if already released)
```

See [10 Booking state model](../architecture/10-booking-state-model.md) and [11 Ticket / entitlement validation model](../architecture/11-ticket-validation-model.md) for the full state machines and the double-redemption concurrency guard.
