-- PD-005 Trutta Integration DDL v0.1
-- Schema: trutta
-- Purpose: core tables for entitlements, claim_attempts, redemptions, swap_rules
-- Notes: Postgres-compatible, no RLS; IDs are ULID-like text keys.

BEGIN;

-- Optional dedicated schema for Trutta
CREATE SCHEMA IF NOT EXISTS trutta;

-- 1. ENTITLEMENTS ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS trutta_entitlement
(
    entitlement_id          text PRIMARY KEY,

    -- Product linkage
    product_id              text        NOT NULL,
    product_version_id      text        NOT NULL,

    -- Ownership / beneficiary
    beneficiary_id          text        NOT NULL,
    beneficiary_type        text        NOT NULL, -- user | household | community_pool | system

    -- Units & semantics
    units_total             numeric(18,6) NOT NULL CHECK (units_total >= 0),
    units_remaining         numeric(18,6) NOT NULL CHECK (units_remaining >= 0),
    unit_label              text        NOT NULL, -- e.g. "coffee", "day", "ride"

    -- Lifecycle state
    state                   text        NOT NULL, -- issued | reserved | claimed | redeemed | expired | refunded | cancelled
    valid_from              timestamptz NULL,
    valid_until             timestamptz NULL,

    -- Origin (how entitlement was created)
    origin_type             text        NOT NULL, -- product | campaign | sospeso | reward | swap | adjustment
    origin_ref              text        NULL,     -- free-form reference (campaign id, tx id, etc.)

    -- Context
    market_code             text        NULL,
    city_code               text        NULL,

    -- Audit
    issued_at               timestamptz NOT NULL DEFAULT now(),
    issued_by               text        NOT NULL,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by               text        NULL,

    -- Basic invariants
    CHECK (state IN (
        'issued', 'reserved', 'claimed', 'redeemed',
        'expired', 'refunded', 'cancelled'
    )),
    CHECK (beneficiary_type IN (
        'user', 'household', 'community_pool', 'system'
    )),
    CHECK (origin_type IN (
        'product', 'campaign', 'sospeso', 'reward', 'swap', 'adjustment'
    )),
    CHECK (units_remaining <= units_total)
);

-- Common indexes for query patterns
CREATE INDEX IF NOT EXISTS trutta_entitlement_product_idx
    ON trutta_entitlement (product_id, product_version_id);

CREATE INDEX IF NOT EXISTS trutta_entitlement_beneficiary_idx
    ON trutta_entitlement (beneficiary_id, beneficiary_type);

CREATE INDEX IF NOT EXISTS trutta_entitlement_state_idx
    ON trutta_entitlement (state);

CREATE INDEX IF NOT EXISTS trutta_entitlement_market_city_idx
    ON trutta_entitlement (market_code, city_code);


-- 2. CLAIM ATTEMPTS ------------------------------------------------------

CREATE TABLE IF NOT EXISTS trutta_claim_attempt
(
    claim_attempt_id        text PRIMARY KEY,

    entitlement_id          text        NOT NULL,

    -- Who is trying to claim
    requested_by_id         text        NOT NULL,
    requested_by_type       text        NOT NULL, -- user | agent | vendor | system

    -- Vendor / redemption context (optional at attempt time)
    vendor_id               text        NULL,
    market_code             text        NULL,
    city_code               text        NULL,

    -- Geo context (if доступний без PostGIS)
    geo_lat                 numeric(9,6),
    geo_lon                 numeric(9,6),

    -- Result of attempt
    status                  text        NOT NULL, -- pending | accepted | rejected
    fail_reason_code        text        NULL,     -- e.g. LIMIT_EXCEEDED, EXPIRED, FRAUD_FLAG
    fail_reason_details     jsonb       NULL,

    -- Time & audit
    created_at              timestamptz NOT NULL DEFAULT now(),
    processed_at            timestamptz NULL,

    CHECK (status IN ('pending', 'accepted', 'rejected')),
    CHECK (requested_by_type IN ('user', 'agent', 'vendor', 'system'))
);

ALTER TABLE trutta_claim_attempt
    ADD CONSTRAINT trutta_claim_attempt_entitlement_fk
        FOREIGN KEY (entitlement_id)
        REFERENCES trutta_entitlement (entitlement_id)
        ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS trutta_claim_attempt_entitlement_idx
    ON trutta_claim_attempt (entitlement_id, status);

CREATE INDEX IF NOT EXISTS trutta_claim_attempt_vendor_idx
    ON trutta_claim_attempt (vendor_id, status);

CREATE INDEX IF NOT EXISTS trutta_claim_attempt_created_at_idx
    ON trutta_claim_attempt (created_at);


-- 3. REDEMPTIONS ---------------------------------------------------------

CREATE TABLE IF NOT EXISTS trutta_redemption
(
    redemption_id           text PRIMARY KEY,

    entitlement_id          text        NOT NULL,
    claim_attempt_id        text        NULL,

    vendor_id               text        NOT NULL,
    vendor_location_id      text        NULL, -- конкретна точка/venue-node

    -- Units actually redeemed (може бути < units_remaining для часткового погашення)
    units_redeemed          numeric(18,6) NOT NULL CHECK (units_redeemed > 0),

    market_code             text        NULL,
    city_code               text        NULL,

    redeemed_at             timestamptz NOT NULL DEFAULT now(),
    redeemed_by             text        NOT NULL, -- оператор, пристрій, system id

    -- Settlement linkage (може бути NULL поки не потрапило в batch)
    settlement_batch_id     text        NULL,

    -- Additional metadata
    metadata                jsonb       NULL
);

ALTER TABLE trutta_redemption
    ADD CONSTRAINT trutta_redemption_entitlement_fk
        FOREIGN KEY (entitlement_id)
        REFERENCES trutta_entitlement (entitlement_id)
        ON DELETE RESTRICT;

ALTER TABLE trutta_redemption
    ADD CONSTRAINT trutta_redemption_claim_attempt_fk
        FOREIGN KEY (claim_attempt_id)
        REFERENCES trutta_claim_attempt (claim_attempt_id)
        ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS trutta_redemption_entitlement_idx
    ON trutta_redemption (entitlement_id);

CREATE INDEX IF NOT EXISTS trutta_redemption_vendor_idx
    ON trutta_redemption (vendor_id, redeemed_at);

CREATE INDEX IF NOT EXISTS trutta_redemption_settlement_idx
    ON trutta_redemption (settlement_batch_id);


-- 4. SWAP RULES ----------------------------------------------------------

CREATE TABLE IF NOT EXISTS trutta_swap_rule
(
    swap_rule_id            text PRIMARY KEY,

    -- Assets: можуть бути entitlements, токени, інші логічні активи
    base_asset_type         text        NOT NULL, -- entitlement | token | other
    base_asset_id           text        NOT NULL,

    quote_asset_type        text        NOT NULL, -- entitlement | token | other
    quote_asset_id          text        NOT NULL,

    -- Pricing model
    pricing_model_type      text        NOT NULL, -- fixed | oracle | amm
    fixed_rate              numeric(30,12) NULL,  -- base → quote, якщо fixed
    oracle_source_id        text        NULL,     -- ref до цінового оракула
    amm_pool_id             text        NULL,     -- id AMM-пула

    -- Fee model (basis points: 10000 = 100%)
    protocol_fee_bps        integer     NOT NULL DEFAULT 0,
    operator_fee_bps        integer     NOT NULL DEFAULT 0,
    city_fund_fee_bps       integer     NOT NULL DEFAULT 0,

    -- Constraints / policy
    max_per_user_per_day    numeric(18,6) NULL,
    max_per_tx              numeric(18,6) NULL,
    allowed_cities          text[]      NULL,
    allowed_markets         text[]      NULL,

    -- Lifecycle
    is_active               boolean     NOT NULL DEFAULT true,

    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              text        NOT NULL,
    updated_at              timestamptz NOT NULL DEFAULT now(),
    updated_by              text        NULL,

    CHECK (base_asset_type IN ('entitlement', 'token', 'other')),
    CHECK (quote_asset_type IN ('entitlement', 'token', 'other')),
    CHECK (pricing_model_type IN ('fixed', 'oracle', 'amm')),
    CHECK (
        protocol_fee_bps >= 0 AND operator_fee_bps >= 0 AND city_fund_fee_bps >= 0
    ),
    CHECK (
        protocol_fee_bps + operator_fee_bps + city_fund_fee_bps <= 10000
    )
);

CREATE INDEX IF NOT EXISTS trutta_swap_rule_assets_idx
    ON trutta_swap_rule (base_asset_type, base_asset_id, quote_asset_type, quote_asset_id);

CREATE INDEX IF NOT EXISTS trutta_swap_rule_active_idx
    ON trutta_swap_rule (is_active);


COMMIT;

