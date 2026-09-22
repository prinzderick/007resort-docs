-- Otueke IFOP — draft schema for design review (NOT a migration; see database/README.md)
-- MySQL 8.4, InnoDB, utf8mb4. Only the highest-risk tables are modeled here in full;
-- see architecture/03-domain-model.md and architecture/04-database-schema.md for the complete table list.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- ============================================================================
-- Organization / facility hierarchy
-- ============================================================================

CREATE TABLE organization (
  id          BINARY(16) NOT NULL PRIMARY KEY,
  name        VARCHAR(200) NOT NULL,
  created_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at  DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE site (
  id               BINARY(16) NOT NULL PRIMARY KEY,
  organization_id  BINARY(16) NOT NULL,
  name             VARCHAR(200) NOT NULL,
  time_zone        VARCHAR(64) NOT NULL DEFAULT 'Africa/Lagos',
  created_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_site_org FOREIGN KEY (organization_id) REFERENCES organization(id)
) ENGINE=InnoDB;

CREATE TABLE facility_unit (
  id               BINARY(16) NOT NULL PRIMARY KEY,
  organization_id  BINARY(16) NOT NULL,
  site_id          BINARY(16) NOT NULL,
  parent_id        BINARY(16) NULL,
  code             VARCHAR(64) NOT NULL,
  name             VARCHAR(200) NOT NULL,
  is_active        TINYINT(1) NOT NULL DEFAULT 1,
  deleted_at       DATETIME(6) NULL,
  row_version      INT UNSIGNED NOT NULL DEFAULT 1,
  created_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_fu_site FOREIGN KEY (site_id) REFERENCES site(id),
  CONSTRAINT fk_fu_parent FOREIGN KEY (parent_id) REFERENCES facility_unit(id),
  CONSTRAINT uq_fu_code UNIQUE (site_id, code)
) ENGINE=InnoDB;

CREATE TABLE capability_type (
  code         VARCHAR(48) NOT NULL PRIMARY KEY,   -- POS, TICKETING, BOOKING, INVENTORY, ...
  description  VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE facility_capability (
  id                BINARY(16) NOT NULL PRIMARY KEY,
  facility_unit_id  BINARY(16) NOT NULL,
  capability_code   VARCHAR(48) NOT NULL,
  is_enabled        TINYINT(1) NOT NULL DEFAULT 1,
  CONSTRAINT fk_fc_facility FOREIGN KEY (facility_unit_id) REFERENCES facility_unit(id),
  CONSTRAINT fk_fc_capability FOREIGN KEY (capability_code) REFERENCES capability_type(code),
  CONSTRAINT uq_fc UNIQUE (facility_unit_id, capability_code)
) ENGINE=InnoDB;

CREATE TABLE operating_rule (
  id                     BINARY(16) NOT NULL PRIMARY KEY,
  facility_capability_id BINARY(16) NOT NULL,
  rule_key               VARCHAR(64) NOT NULL,     -- payment_timing, validation_mode, slot_granularity_minutes, ...
  rule_value              VARCHAR(255) NOT NULL,
  CONSTRAINT fk_or_fc FOREIGN KEY (facility_capability_id) REFERENCES facility_capability(id),
  CONSTRAINT uq_or UNIQUE (facility_capability_id, rule_key)
) ENGINE=InnoDB;

-- ============================================================================
-- Sync / idempotency infrastructure (referenced by every module below)
-- ============================================================================

CREATE TABLE idempotency_record (
  scope            VARCHAR(64) NOT NULL,
  idempotency_key  VARCHAR(128) NOT NULL,
  request_hash     CHAR(64) NOT NULL,
  response_status  SMALLINT UNSIGNED NOT NULL,
  response_body    JSON NOT NULL,
  created_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (scope, idempotency_key)
) ENGINE=InnoDB;

CREATE TABLE outbox_message (
  id             BINARY(16) NOT NULL PRIMARY KEY,
  message_type   VARCHAR(128) NOT NULL,
  payload        JSON NOT NULL,
  sync_state     VARCHAR(16) NOT NULL DEFAULT 'LOCAL'
                   CHECK (sync_state IN ('LOCAL','QUEUED','SYNCING','SYNCED','CONFLICT','FAILED')),
  origin_node_id BINARY(16) NOT NULL,
  created_at     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  synced_at      DATETIME(6) NULL,
  INDEX ix_outbox_state (sync_state, created_at)
) ENGINE=InnoDB;

-- ============================================================================
-- Booking — see architecture/10-booking-state-model.md
-- ============================================================================

CREATE TABLE bookable_resource (
  id                BINARY(16) NOT NULL PRIMARY KEY,
  facility_unit_id  BINARY(16) NOT NULL,
  name              VARCHAR(200) NOT NULL,
  capacity          INT UNSIGNED NOT NULL DEFAULT 1,
  deleted_at        DATETIME(6) NULL,
  CONSTRAINT fk_br_facility FOREIGN KEY (facility_unit_id) REFERENCES facility_unit(id)
) ENGINE=InnoDB;

CREATE TABLE booking (
  id           BINARY(16) NOT NULL PRIMARY KEY,
  site_id      BINARY(16) NOT NULL,
  customer_id  BINARY(16) NULL,
  status       VARCHAR(20) NOT NULL DEFAULT 'HELD'
                 CHECK (status IN ('HELD','PENDING_PAYMENT','CONFIRMED','RESCHEDULED','CANCELLED','EXPIRED','COMPLETED')),
  hold_expires_at DATETIME(6) NULL,
  row_version  INT UNSIGNED NOT NULL DEFAULT 1,
  created_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE booking_item (
  id           BINARY(16) NOT NULL PRIMARY KEY,
  booking_id   BINARY(16) NOT NULL,
  resource_id  BINARY(16) NOT NULL,
  slot_start   DATETIME(6) NOT NULL,
  slot_end     DATETIME(6) NOT NULL,
  qty          DECIMAL(14,3) NOT NULL DEFAULT 1,
  CONSTRAINT fk_bi_booking FOREIGN KEY (booking_id) REFERENCES booking(id) ON DELETE CASCADE,
  CONSTRAINT fk_bi_resource FOREIGN KEY (resource_id) REFERENCES bookable_resource(id)
) ENGINE=InnoDB;

-- The double-booking guard: see architecture/04-database-schema.md §3.1 and §10 §3.
CREATE TABLE slot_allocation (
  id               BINARY(16) NOT NULL PRIMARY KEY,
  organization_id  BINARY(16) NOT NULL,
  site_id          BINARY(16) NOT NULL,
  resource_id      BINARY(16) NOT NULL,
  unit_no          SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  slot_start       DATETIME(6) NOT NULL,
  slot_end         DATETIME(6) NOT NULL,
  booking_item_id  BINARY(16) NOT NULL,
  status           VARCHAR(16) NOT NULL DEFAULT 'HELD'
                     CHECK (status IN ('HELD','CONFIRMED','CANCELLED')),
  hold_expires_at  DATETIME(6) NULL,
  created_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_sa_resource FOREIGN KEY (resource_id) REFERENCES bookable_resource(id),
  CONSTRAINT fk_sa_item FOREIGN KEY (booking_item_id) REFERENCES booking_item(id) ON DELETE CASCADE,
  CONSTRAINT uq_slot UNIQUE (resource_id, unit_no, slot_start)
) ENGINE=InnoDB;

-- ============================================================================
-- Ticketing / entitlements — see architecture/11-ticket-validation-model.md
-- ============================================================================

CREATE TABLE ticket_type (
  id             BINARY(16) NOT NULL PRIMARY KEY,
  name           VARCHAR(200) NOT NULL,
  format         VARCHAR(16) NOT NULL DEFAULT 'INDIVIDUAL'
                   CHECK (format IN ('INDIVIDUAL','COMBINED')),
  validation_mode VARCHAR(20) NOT NULL DEFAULT 'SINGLE_USE'
                   CHECK (validation_mode IN ('NONE','SINGLE_USE','MULTIPLE_ENTRY','TIME_LIMITED','ENTRY_EXIT','STAFF_APPROVAL'))
) ENGINE=InnoDB;

CREATE TABLE entitlement (
  id           BINARY(16) NOT NULL PRIMARY KEY,
  booking_id   BINARY(16) NULL,
  order_id     BINARY(16) NULL,
  customer_id  BINARY(16) NULL,
  status       VARCHAR(16) NOT NULL DEFAULT 'ACTIVE'
                 CHECK (status IN ('ACTIVE','CANCELLED')),
  created_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE entitlement_item (
  id               BINARY(16) NOT NULL PRIMARY KEY,
  entitlement_id   BINARY(16) NOT NULL,
  kind             VARCHAR(16) NOT NULL CHECK (kind IN ('ACCESS','RENTAL','GOODS','SERVICE')),
  facility_unit_id BINARY(16) NULL,
  ticket_type_id   BINARY(16) NULL,
  qty              DECIMAL(14,3) NOT NULL,
  qty_redeemed     DECIMAL(14,3) NOT NULL DEFAULT 0,
  valid_from       DATETIME(6) NULL,
  valid_until      DATETIME(6) NULL,
  CONSTRAINT fk_ei_entitlement FOREIGN KEY (entitlement_id) REFERENCES entitlement(id) ON DELETE CASCADE,
  CONSTRAINT fk_ei_ticket_type FOREIGN KEY (ticket_type_id) REFERENCES ticket_type(id),
  CONSTRAINT chk_ei_qty CHECK (qty_redeemed <= qty)
) ENGINE=InnoDB;

-- Append-only. See architecture/11-ticket-validation-model.md §4 for the concurrency pattern.
CREATE TABLE redemption (
  id                   BINARY(16) NOT NULL PRIMARY KEY,
  entitlement_item_id  BINARY(16) NOT NULL,
  action               VARCHAR(16) NOT NULL CHECK (action IN ('ENTRY','EXIT','RELEASE','RETURN')),
  qty                  DECIMAL(14,3) NOT NULL,
  device_id            BINARY(16) NOT NULL,
  staff_id             BINARY(16) NULL,
  created_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_rd_item FOREIGN KEY (entitlement_item_id) REFERENCES entitlement_item(id)
) ENGINE=InnoDB;

CREATE TABLE validation_event (
  id                   BINARY(16) NOT NULL PRIMARY KEY,
  entitlement_id       BINARY(16) NOT NULL,
  device_id            BINARY(16) NOT NULL,
  result               VARCHAR(20) NOT NULL
                         CHECK (result IN ('VALID','USED','EXPIRED','NOT_YET_VALID','WRONG_FACILITY','CANCELLED')),
  created_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_ve_entitlement FOREIGN KEY (entitlement_id) REFERENCES entitlement(id)
) ENGINE=InnoDB;

-- ============================================================================
-- Payments — see architecture/07-payment-state-model.md
-- ============================================================================

CREATE TABLE payment (
  id             BINARY(16) NOT NULL PRIMARY KEY,
  site_id        BINARY(16) NOT NULL,
  tender_type    VARCHAR(24) NOT NULL,   -- CASH, CARD, MOBILE_MONEY, ...
  amount         DECIMAL(19,4) NOT NULL,
  currency_code  CHAR(3) NOT NULL DEFAULT 'NGN',
  status         VARCHAR(20) NOT NULL DEFAULT 'INITIATED'
                   CHECK (status IN ('INITIATED','AUTHORIZING','CAPTURED','FAILED','CANCELLED','PARTIALLY_REFUNDED','REFUNDED','REVERSED')),
  change_given   DECIMAL(19,4) NOT NULL DEFAULT 0,
  cash_session_id BINARY(16) NULL,
  created_at     DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  row_version    INT UNSIGNED NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE payment_allocation (
  id          BINARY(16) NOT NULL PRIMARY KEY,
  payment_id  BINARY(16) NOT NULL,
  order_id    BINARY(16) NOT NULL,
  amount      DECIMAL(19,4) NOT NULL,
  CONSTRAINT fk_pa_payment FOREIGN KEY (payment_id) REFERENCES payment(id)
) ENGINE=InnoDB;

CREATE TABLE refund (
  id           BINARY(16) NOT NULL PRIMARY KEY,
  payment_id   BINARY(16) NOT NULL,
  amount       DECIMAL(19,4) NOT NULL,
  reason       VARCHAR(255) NOT NULL,
  approval_id  BINARY(16) NULL,
  created_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_rf_payment FOREIGN KEY (payment_id) REFERENCES payment(id)
) ENGINE=InnoDB;

-- Duplicate provider callback protection — see architecture/04-database-schema.md §3.3
CREATE TABLE provider_event (
  id                BINARY(16) NOT NULL PRIMARY KEY,
  provider          VARCHAR(32) NOT NULL,
  provider_event_id VARCHAR(128) NOT NULL,
  payload_hash      CHAR(64) NOT NULL,
  received_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  payment_id        BINARY(16) NULL,
  CONSTRAINT uq_provider_event UNIQUE (provider, provider_event_id)
) ENGINE=InnoDB;

-- ============================================================================
-- Inventory — see architecture/09-inventory-movement-model.md
-- ============================================================================

CREATE TABLE inventory_item (
  id    BINARY(16) NOT NULL PRIMARY KEY,
  sku   VARCHAR(64) NOT NULL,
  name  VARCHAR(200) NOT NULL,
  unit  VARCHAR(16) NOT NULL DEFAULT 'EACH',
  CONSTRAINT uq_item_sku UNIQUE (sku)
) ENGINE=InnoDB;

CREATE TABLE stock_location (
  id                BINARY(16) NOT NULL PRIMARY KEY,
  facility_unit_id  BINARY(16) NULL,     -- NULL = Main Store (central)
  name              VARCHAR(200) NOT NULL,
  allow_negative    TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE stock_balance (
  item_id      BINARY(16) NOT NULL,
  location_id  BINARY(16) NOT NULL,
  qty_on_hand  DECIMAL(14,3) NOT NULL DEFAULT 0,
  row_version  INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (item_id, location_id),
  CONSTRAINT fk_sb_item FOREIGN KEY (item_id) REFERENCES inventory_item(id),
  CONSTRAINT fk_sb_location FOREIGN KEY (location_id) REFERENCES stock_location(id)
) ENGINE=InnoDB;

-- Append-only ledger — the source of truth; stock_balance is a guarded projection of this.
CREATE TABLE stock_movement (
  id               BINARY(16) NOT NULL PRIMARY KEY,
  item_id          BINARY(16) NOT NULL,
  location_id      BINARY(16) NOT NULL,
  qty_delta        DECIMAL(14,3) NOT NULL,
  reason           VARCHAR(24) NOT NULL
                     CHECK (reason IN ('RECEIPT','TRANSFER_OUT','TRANSFER_IN','SALE','WASTAGE','ADJUSTMENT','COUNT','RENTAL_OUT','RENTAL_IN')),
  reference_type   VARCHAR(32) NOT NULL,
  reference_id     BINARY(16) NOT NULL,
  actor_staff_id   BINARY(16) NULL,
  created_at       DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_sm_item FOREIGN KEY (item_id) REFERENCES inventory_item(id),
  CONSTRAINT fk_sm_location FOREIGN KEY (location_id) REFERENCES stock_location(id),
  INDEX ix_sm_item_location (item_id, location_id, created_at)
) ENGINE=InnoDB;

-- ============================================================================
-- Audit — see architecture/04-database-schema.md §3.5. Insert-only at the grant level.
-- ============================================================================

CREATE TABLE approval (
  id                BINARY(16) NOT NULL PRIMARY KEY,
  requested_by       BINARY(16) NOT NULL,
  approved_by        BINARY(16) NULL,
  status             VARCHAR(16) NOT NULL DEFAULT 'PENDING'
                       CHECK (status IN ('PENDING','APPROVED','REJECTED')),
  reason             VARCHAR(255) NULL,
  created_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  decided_at         DATETIME(6) NULL
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  id                  BINARY(16) NOT NULL PRIMARY KEY,
  occurred_at         DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  actor_staff_id      BINARY(16) NULL,
  facility_unit_id    BINARY(16) NULL,
  operating_point_id  BINARY(16) NULL,
  device_id           BINARY(16) NULL,
  action              VARCHAR(64) NOT NULL,
  entity_type         VARCHAR(64) NOT NULL,
  entity_id           BINARY(16) NOT NULL,
  old_value           JSON NULL,
  new_value           JSON NULL,
  approval_id         BINARY(16) NULL,
  prev_hash           CHAR(64) NOT NULL,
  row_hash            CHAR(64) NOT NULL,
  CONSTRAINT fk_al_approval FOREIGN KEY (approval_id) REFERENCES approval(id),
  INDEX ix_al_entity (entity_type, entity_id)
) ENGINE=InnoDB;

-- Application DB user grants (documented here; applied by deployment scripts, not by this file):
--   REVOKE UPDATE, DELETE ON otueke.audit_log FROM 'otueke_app'@'%';
--   REVOKE UPDATE, DELETE ON otueke.stock_movement FROM 'otueke_app'@'%';
--   REVOKE UPDATE, DELETE ON otueke.redemption FROM 'otueke_app'@'%';
--   REVOKE UPDATE, DELETE ON otueke.payment, otueke.provider_event FROM 'otueke_app'@'%';
