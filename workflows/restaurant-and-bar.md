# Workflow: Restaurant / Bar service

Facilities: Restaurant, Indoor Club, Pool Bar, Bush Bar / Event Centre (varying `payment_timing` per [05](../architecture/05-facility-capability-model.md)).

```mermaid
sequenceDiagram
  actor W as Wait staff (tablet/POS)
  participant API as 007resort-api
  participant KDS as KDS station
  actor K as Kitchen/bar staff
  actor C as Cashier

  W->>API: Staff login (NFC/PIN)
  W->>API: POST /orders (table/tab)
  W->>API: POST /orders/{id}/lines (add items)
  W->>API: POST /orders/{id}/send
  API->>API: Route lines by prep_route (product x facility -> station)
  API->>KDS: SignalR: new prep_ticket
  K->>KDS: Accept -> In progress -> Ready
  KDS->>API: POST /prep-tickets/{id}/transition
  API->>W: SignalR: ready status
  W->>API: mark served / dispensed
  alt Pay-on-exit (Indoor Club, tab facilities)
    Note over W,API: More orders may be added to the same tab
    C->>API: POST /tabs/{id}/settle (payment)
  else Pay-per-order
    C->>API: POST /payments (settle this order)
  end
  API->>API: Post stock_movement (SALE), record audit
```

See [08 Order state model](../architecture/08-order-state-model.md) and [09 Inventory movement model](../architecture/09-inventory-movement-model.md) for the underlying state machines.
