# Workflow: Inventory receipt through sale

```mermaid
sequenceDiagram
  actor P as Procurement / Storekeeper
  participant API as 007resort-api
  actor F as Facility POS/workstation
  actor M as Manager

  P->>API: POST /inventory/purchase-receipts (Main Store)
  API->>API: stock_movement RECEIPT -> stock_balance +qty (Main Store)
  P->>API: POST /inventory/transfers (Main Store -> Facility)
  API->>API: stock_movement TRANSFER_OUT (Main Store), TRANSFER_IN (Facility)
  F->>API: Order sent/settled (per facility payment_timing)
  API->>API: stock_movement SALE -> stock_balance -qty (Facility, guarded update)
  opt Wastage / correction
    F->>API: POST /inventory/adjustments (requires stock-adjustment permission)
    API->>API: approval check -> stock_movement WASTAGE|ADJUSTMENT
  end
  M->>API: POST /inventory/counts (physical count)
  API->>API: compute variance vs stock_balance -> post COUNT movement
  M->>API: GET /reports/inventory-variance
```

Every movement records item, source, destination, quantity, actor, timestamp and reason/reference — see [09 Inventory movement model](../architecture/09-inventory-movement-model.md).
