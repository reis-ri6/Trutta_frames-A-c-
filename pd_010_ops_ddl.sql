-- PD-010 Ops / Safety / Quality DDL v0.1
-- Postgres / Supabase-compatible schema (no RLS, no env-specific settings)
-- Covers: incidents, safety_overrides, quality_scores, ops_policies and supporting enums.

-- NOTE: assumes core product/domain tables (products, product_versions, cities, vendors, routes, service_points)
-- exist from PD-002 / PD-006. FKs are provided as commented hints.


-- =============================
-- 1. ENUM TYPES
-- =============================

CREATE TYPE incident_severity AS ENUM (
    'info',
    'low',
    'medium',
    'high',
    'critical'
);

CREATE TYPE incident_status AS ENUM (
    'open',
    'acknowledged',
    'mitigated',
    'resolved',
    'closed'
);

CREATE TYPE safety_override_scope AS ENUM (
    'global',
    'market',
    'city',
    'product',
    'vendor',
    'route'
);

CREATE TYPE safety_override_action AS ENUM (
    'block',           -- повністю блокувати (stop-sell / no-route)
    'deprioritize',    -- зменшити пріоритет у рекомендаціях/маршрутах
    'fallback',        -- використовувати альтернативний маршрут/вендора
    'alert_only',      -- тільки алерт/логування
    'freeze'           -- заморозити ентайтлменти / сесію
);

CREATE TYPE quality_score_type AS ENUM (
    'rating',          -- середній рейтинг (0–5)
    'nps',             -- Net Promoter Score (-100..100)
    'csat',            -- Customer Satisfaction (1–5 або 1–10)
    'complaint_rate',  -- % скарг
    'content',         -- контентні метрики (повнота/свіжість)
    'custom'           -- інші спеціальні метрики
);

CREATE TYPE ops_policy_scope_level AS ENUM (
    'global',
    'market',
    'city',
    'product',
    'route',
    'vendor'
);

CREATE TYPE ops_policy_type AS ENUM (
    'slo_threshold',   -- політика по SLO (availability, latency тощо)
    'quality_gate',    -- гейт по якості (rating/NPS/контент)
    'safety_rule',     -- safety-правило (LEM/Trutta/route/vendor)
    'runtime_action'   -- прямі runtime-дїї (throttle, stop-sell, degraded mode)
);


-- =============================
-- 2. OPS INCIDENTS
-- =============================

CREATE TABLE ops_incidents (
    incident_id             text PRIMARY KEY,  -- наприклад, OPS-INC-2025-000123 або ULID

    incident_type           text NOT NULL,     -- slo_breach | safety_violation | quality_drop | fraud_signal | system_outage | ...
    severity                incident_severity NOT NULL DEFAULT 'medium',
    status                  incident_status NOT NULL DEFAULT 'open',

    product_id              text,
    product_version_id      text,
    market_code             text,
    city_code               text,
    route_id                text,
    vendor_id               text,
    service_point_id        text,

    journey_instance_id     text,
    product_runtime_session_id text,

    ops_profile_id          text,
    safety_profile_id       text,
    quality_profile_id      text,

    slo_ref                 text,              -- ідентифікатор SLO/definition

    detected_at             timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    resolved_at             timestamptz,

    source_service          text,              -- prg | tjm | trutta | lem | ao | monitoring | ops_console | ...

    title                   text NOT NULL,
    description             text,

    created_by              text,              -- actor id (user/ops/agent/system)
    assigned_team           text,
    oncall_rotation_id      text,

    tags                    text[] DEFAULT '{}',
    meta                    jsonb,

    CONSTRAINT ops_incidents_resolved_after_detected_chk CHECK (
        resolved_at IS NULL OR resolved_at >= detected_at
    )
);

CREATE INDEX idx_ops_incidents_status ON ops_incidents (status);
CREATE INDEX idx_ops_incidents_severity ON ops_incidents (severity);
CREATE INDEX idx_ops_incidents_detected_at ON ops_incidents (detected_at);
CREATE INDEX idx_ops_incidents_product ON ops_incidents (product_id, product_version_id);
CREATE INDEX idx_ops_incidents_market_city ON ops_incidents (market_code, city_code);
CREATE INDEX idx_ops_incidents_vendor ON ops_incidents (vendor_id);


-- =============================
-- 3. SAFETY OVERRIDES
-- =============================

CREATE TABLE safety_overrides (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    scope                   safety_override_scope NOT NULL,

    market_code             text,
    city_code               text,
    product_id              text,
    product_version_id      text,
    route_id                text,
    vendor_id               text,
    service_point_id        text,

    action                  safety_override_action NOT NULL,

    reason                  text,

    created_by              text,              -- actor id
    source                  text,              -- ops_console | auto_rule | safety_agent | ...

    active                  boolean NOT NULL DEFAULT true,
    effective_from          timestamptz NOT NULL DEFAULT now(),
    effective_until         timestamptz,

    meta                    jsonb,

    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT safety_overrides_effective_range_chk CHECK (
        effective_until IS NULL OR effective_until > effective_from
    )
);

CREATE INDEX idx_safety_overrides_scope ON safety_overrides (scope);
CREATE INDEX idx_safety_overrides_active ON safety_overrides (active);
CREATE INDEX idx_safety_overrides_market_city ON safety_overrides (market_code, city_code);
CREATE INDEX idx_safety_overrides_product ON safety_overrides (product_id, product_version_id);
CREATE INDEX idx_safety_overrides_vendor ON safety_overrides (vendor_id);
CREATE INDEX idx_safety_overrides_route ON safety_overrides (route_id);


-- =============================
-- 4. QUALITY SCORES
-- =============================

CREATE TABLE quality_scores (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    score_type              quality_score_type NOT NULL,

    product_id              text,
    product_version_id      text,
    market_code             text,
    city_code               text,
    route_id                text,
    vendor_id               text,

    window_start            timestamptz NOT NULL,
    window_end              timestamptz NOT NULL,

    value                   numeric(18,6) NOT NULL,  -- інтерпретація залежить від score_type
    sample_size             integer NOT NULL DEFAULT 0,

    source                  text,                   -- reviews | surveys | analytics_job | ...

    meta                    jsonb,

    created_at              timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT quality_scores_window_range_chk CHECK (window_end > window_start),
    CONSTRAINT quality_scores_sample_size_chk CHECK (sample_size >= 0)
);

CREATE INDEX idx_quality_scores_type ON quality_scores (score_type);
CREATE INDEX idx_quality_scores_product ON quality_scores (product_id, product_version_id);
CREATE INDEX idx_quality_scores_market_city ON quality_scores (market_code, city_code);
CREATE INDEX idx_quality_scores_vendor ON quality_scores (vendor_id);
CREATE INDEX idx_quality_scores_route ON quality_scores (route_id);
CREATE INDEX idx_quality_scores_window ON quality_scores (window_start, window_end);


-- =============================
-- 5. OPS POLICIES (RULES / GATES)
-- =============================

CREATE TABLE ops_policies (
    policy_id               text PRIMARY KEY,  -- наприклад OPS-POL-SLO-VIEN-AVAIL-99-5

    policy_type             ops_policy_type NOT NULL,
    scope_level             ops_policy_scope_level NOT NULL,

    market_code             text,
    city_code               text,
    product_id              text,
    product_version_id      text,
    route_id                text,
    vendor_id               text,

    name                    text NOT NULL,
    description             text,

    -- condition/action описуються як JSON-структури, валідовані на рівні застосунку
    condition               jsonb NOT NULL,   -- наприклад, опис SLI/SLO: metric, comparator, threshold, window
    action                  jsonb NOT NULL,   -- наприклад, stop_sell, throttle, create_incident, notify_teams

    enabled                 boolean NOT NULL DEFAULT true,

    priority                integer NOT NULL DEFAULT 100,

    effective_from          timestamptz NOT NULL DEFAULT now(),
    effective_until         timestamptz,

    created_by              text,

    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),

    meta                    jsonb,

    CONSTRAINT ops_policies_effective_range_chk CHECK (
        effective_until IS NULL OR effective_until > effective_from
    )
);

CREATE INDEX idx_ops_policies_scope ON ops_policies (scope_level, market_code, city_code, product_id, product_version_id);
CREATE INDEX idx_ops_policies_type ON ops_policies (policy_type);
CREATE INDEX idx_ops_policies_enabled ON ops_policies (enabled);
CREATE INDEX idx_ops_policies_effective ON ops_policies (effective_from, effective_until);


-- =============================
-- 6. OPTIONAL FK HINTS (COMMENTED)
-- =============================

-- ALTER TABLE ops_incidents
--   ADD CONSTRAINT fk_ops_incidents_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);

-- ALTER TABLE safety_overrides
--   ADD CONSTRAINT fk_safety_overrides_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);

-- ALTER TABLE quality_scores
--   ADD CONSTRAINT fk_quality_scores_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);

-- ALTER TABLE ops_policies
--   ADD CONSTRAINT fk_ops_policies_product_version
--   FOREIGN KEY (product_version_id) REFERENCES product_versions(product_version_id);
