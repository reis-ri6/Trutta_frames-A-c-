-- PD-009 Financial DDL v0.1
-- Postgres / Supabase-compatible schema (no RLS, no environment-specific settings)
-- Covers: product_costs, product_prices-related config, fx_rates_cache and supporting tables.

-- NOTE: assumes `product_versions(product_version_id)` and `products(product_id)` exist
-- from PD-002-product-domain-model.ddl.sql.


-- =============================
-- 1. ENUM TYPES
-- =============================

CREATE TYPE revenue_model_type AS ENUM (
    'fixed_split',
    'tiered_split',
    'cost_plus'
);

CREATE TYPE pricing_scope_level AS ENUM (
    'global',
    'market',
    'product',
    'segment',
    'experiment'
);

CREATE TYPE price_override_type AS ENUM (
    'market',
    'channel',
    'segment',
    'time_window',
    'experiment'
);

CREATE TYPE pricing_rounding_mode AS ENUM (
    'none',
    'nearest_0_05',
    'nearest_0_10',
    'custom'
);

CREATE TYPE pricing_campaign_type AS ENUM (
    'promo_percent',
    'promo_fixed',
    'voucher'
);

CREATE TYPE fx_pricing_mode AS ENUM (
    'base_then_convert',
    'per_market_price'
);

CREATE TYPE price_quote_status AS ENUM (
    'pending',
    'final',
    'expired',
    'rejected'
);


-- =============================
-- 2. PRODUCT COSTS & REVENUE MODEL
-- =============================

-- Base cost & revenue model per product_version + PPU

CREATE TABLE product_costs (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    product_version_id  text        NOT NULL,
    ppu_code            text        NOT NULL,

    base_currency       text        NOT NULL,

    base_cost_amount    numeric(18,6) NOT NULL, -- expected total cost per PPU in base_currency
    vendor_service_cost numeric(18,6),          -- optional breakdown
    operational_overhead_cost numeric(18,6),

    vat_included        boolean     NOT NULL DEFAULT true,
    vat_rate_percent    numeric(9,4),

    revenue_type        revenue_model_type NOT NULL DEFAULT 'fixed_split',

    -- For simple fixed_split models we keep explicit columns.
    vendor_share_percent    numeric(9,4),
    platform_fee_percent    numeric(9,4),
    partner_fee_percent     numeric(9,4),

    -- For tiered / cost_plus / custom extensions (JSON schema controlled at app level).
    revenue_model_data  jsonb,

    -- Effectivity window
    effective_from      timestamptz NOT NULL DEFAULT now(),
    effective_until     timestamptz,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_costs_non_overlapping_chk CHECK (
        effective_until IS NULL OR effective_until > effective_from
    )
);

CREATE INDEX idx_product_costs_product_version_ppu ON product_costs (product_version_id, ppu_code, effective_from);


-- =============================
-- 3. PRICING PROFILES (CONFIG LAYER)
-- =============================

-- Pricing profile metadata (maps 1:1 to PricingProfile in PD-009)

CREATE TABLE product_pricing_profiles (
    pricing_profile_id  text PRIMARY KEY,  -- e.g. PRF-PRICING-VIEN-COFFEE-PASS

    profile_type        text NOT NULL DEFAULT 'pricing_profile',

    scope_level         pricing_scope_level NOT NULL,
    market_code         text,
    product_id          text,
    product_version_id  text,

    segments            text[] DEFAULT '{}',
    experiment_key      text,
    channel             text,

    base_currency       text NOT NULL,
    base_amount         numeric(18,6) NOT NULL,
    ppu_code            text NOT NULL,
    unit_type           text NOT NULL,
    unit_quantity       numeric(18,6) NOT NULL DEFAULT 1,

    rounding_mode       pricing_rounding_mode NOT NULL DEFAULT 'none',

    min_margin_percent  numeric(9,4),
    max_discount_percent numeric(9,4),
    require_revenue_model_match boolean NOT NULL DEFAULT false,

    billing_price_list_id   text,
    trutta_pricing_ref      text,

    status              text NOT NULL DEFAULT 'active',
    version             integer NOT NULL DEFAULT 1,

    effective_from      timestamptz NOT NULL DEFAULT now(),
    effective_until     timestamptz,

    meta                jsonb,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_pricing_profiles_effective_range_chk CHECK (
        effective_until IS NULL OR effective_until > effective_from
    )
);

CREATE INDEX idx_pricing_profiles_scope ON product_pricing_profiles (scope_level, market_code, product_id, product_version_id);
CREATE INDEX idx_pricing_profiles_status ON product_pricing_profiles (status);


-- Overrides (market/channel/segment/time/experiment) as separate rows.

CREATE TABLE product_pricing_overrides (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    pricing_profile_id  text NOT NULL REFERENCES product_pricing_profiles(pricing_profile_id) ON DELETE CASCADE,

    override_type       price_override_type NOT NULL,

    market_code         text,
    channel             text,
    segment_key         text,
    experiment_key      text,

    -- For time_window overrides
    valid_from          timestamptz,
    valid_until         timestamptz,

    -- adjustment is expressed either as absolute delta or percent
    price_delta_amount  numeric(18,6),
    price_delta_percent numeric(9,4),

    priority            integer NOT NULL DEFAULT 100,

    meta                jsonb,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_pricing_overrides_effective_range_chk CHECK (
        valid_until IS NULL OR valid_until > valid_from
    )
);

CREATE INDEX idx_pricing_overrides_profile_type ON product_pricing_overrides (pricing_profile_id, override_type);
CREATE INDEX idx_pricing_overrides_market ON product_pricing_overrides (market_code);
CREATE INDEX idx_pricing_overrides_segment ON product_pricing_overrides (segment_key);
CREATE INDEX idx_pricing_overrides_channel ON product_pricing_overrides (channel);


-- Campaigns & promo attached to pricing profile

CREATE TABLE product_pricing_campaigns (
    campaign_id         text PRIMARY KEY,  -- e.g. CAMP-VIEN-LAUNCH

    pricing_profile_id  text NOT NULL REFERENCES product_pricing_profiles(pricing_profile_id) ON DELETE CASCADE,

    campaign_type       pricing_campaign_type NOT NULL,

    discount_percent    numeric(9,4),
    discount_amount     numeric(18,6),

    channels            text[] DEFAULT '{}',

    valid_from          timestamptz NOT NULL,
    valid_until         timestamptz NOT NULL,

    priority            integer NOT NULL DEFAULT 100,

    meta                jsonb,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_pricing_campaigns_valid_range_chk CHECK (valid_until > valid_from)
);

CREATE INDEX idx_pricing_campaigns_profile ON product_pricing_campaigns (pricing_profile_id);
CREATE INDEX idx_pricing_campaigns_validity ON product_pricing_campaigns (valid_from, valid_until);


-- Coupons / vouchers (can be shared across profiles if needed)

CREATE TABLE product_pricing_coupons (
    coupon_code         text PRIMARY KEY, -- e.g. VIENCOFFEE10

    campaign_type       pricing_campaign_type NOT NULL,

    discount_percent    numeric(9,4),
    discount_amount     numeric(18,6),

    base_currency       text,

    max_redemptions     integer,
    per_user_limit      integer,

    valid_from          timestamptz NOT NULL,
    valid_until         timestamptz NOT NULL,

    allowed_channels    text[] DEFAULT '{}',
    allowed_markets     text[] DEFAULT '{}',

    meta                jsonb,

    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_pricing_coupons_valid_range_chk CHECK (valid_until > valid_from)
);

CREATE TABLE product_pricing_coupon_profiles (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    coupon_code         text NOT NULL REFERENCES product_pricing_coupons(coupon_code) ON DELETE CASCADE,
    pricing_profile_id  text NOT NULL REFERENCES product_pricing_profiles(pricing_profile_id) ON DELETE CASCADE,

    created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_coupon_profiles_coupon ON product_pricing_coupon_profiles (coupon_code);
CREATE INDEX idx_coupon_profiles_profile ON product_pricing_coupon_profiles (pricing_profile_id);


-- =============================
-- 4. FX RATES CACHE
-- =============================

CREATE TABLE fx_rates_cache (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    base_currency       text NOT NULL,
    quote_currency      text NOT NULL,

    rate                numeric(18,8) NOT NULL,
    rate_source         text NOT NULL,         -- e.g. 'ECB', 'custom'

    pricing_mode        fx_pricing_mode NOT NULL DEFAULT 'base_then_convert',

    as_of               timestamptz NOT NULL,  -- timestamp for which rate is valid

    fetched_at          timestamptz NOT NULL DEFAULT now(),

    meta                jsonb,

    CONSTRAINT fx_rates_cache_positive_rate_chk CHECK (rate > 0)
);

CREATE UNIQUE INDEX uq_fx_rates_base_quote_asof ON fx_rates_cache (base_currency, quote_currency, as_of);
CREATE INDEX idx_fx_rates_base_quote ON fx_rates_cache (base_currency, quote_currency);


-- =============================
-- 5. PRICE QUOTES (AUDIT / ANALYTICS)
-- =============================

CREATE TABLE product_price_quotes (
    price_quote_id      text PRIMARY KEY,  -- e.g. PQUOTE-0001 (can mirror event ID)

    product_version_id  text NOT NULL,
    pricing_profile_id  text NOT NULL,

    market_code         text,
    requested_currency  text NOT NULL,

    unit_currency       text NOT NULL,
    unit_price          numeric(18,6) NOT NULL,
    quantity            numeric(18,6) NOT NULL DEFAULT 1,
    total_price         numeric(18,6) NOT NULL,

    original_price      numeric(18,6),
    total_discount_percent numeric(9,4),

    fx_rate             numeric(18,8),
    fx_base_currency    text,
    fx_source           text,

    status              price_quote_status NOT NULL DEFAULT 'final',

    applied_layers      jsonb, -- campaigns, coupons, overrides, experiments

    segments            text[] DEFAULT '{}',
    channel             text,
    experiment_keys     text[] DEFAULT '{}',
    coupon_codes        text[] DEFAULT '{}',

    created_at          timestamptz NOT NULL DEFAULT now(),
    expires_at          timestamptz
);

CREATE INDEX idx_price_quotes_product ON product_price_quotes (product_version_id, pricing_profile_id);
CREATE INDEX idx_price_quotes_market ON product_price_quotes (market_code);
CREATE INDEX idx_price_quotes_created_at ON product_price_quotes (created_at);


-- =============================
-- 6. BASIC FK HINTS (OPTIONAL)
-- =============================

-- These FKs are commented out to avoid hard-coupling if PD-002 DDL is applied separately.
-- Uncomment if product_versions table is present in the same schema.

-- ALTER TABLE product_costs
--   ADD CONSTRAINT fk_product_costs_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);

-- ALTER TABLE product_pricing_profiles
--   ADD CONSTRAINT fk_pricing_profiles_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);

-- ALTER TABLE product_price_quotes
--   ADD CONSTRAINT fk_price_quotes_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);
