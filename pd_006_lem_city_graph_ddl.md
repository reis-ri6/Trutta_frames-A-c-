-- PD-006 LEM City Graph DDL v0.1
-- Schema: lem
-- Purpose: core tables for city graph: service_points, service_edges, experience_snapshots
-- Notes: Postgres-compatible, no RLS; IDs are ULID-like text keys. Geo kept as numeric(lat/lon) + optional geojson.

BEGIN;

-- Optional dedicated schema for LEM
CREATE SCHEMA IF NOT EXISTS lem;

-- 1. SERVICE POINTS ------------------------------------------------------

CREATE TABLE IF NOT EXISTS lem_service_point
(
    service_point_id    text PRIMARY KEY,

    -- City / market context
    city_code           text        NOT NULL,
    market_code         text        NULL,

    -- Classification
    class_id            text        NOT NULL, -- e.g. cafe.coffee_partner, hotel.partner

    -- Basic geo
    geo_lat             numeric(9,6)    NOT NULL,
    geo_lon             numeric(9,6)    NOT NULL,

    -- Optional structured geo / address
    address_line1       text        NULL,
    address_line2       text        NULL,
    postal_code         text        NULL,
    neighborhood        text        NULL,

    -- External references
    vendor_id           text        NULL, -- REIS/Trutta vendor ref, if applicable
    external_refs       jsonb       NULL, -- google_places_id, foursquare_id, yelp_id, etc.

    -- Capabilities / tags
    tags                text[]      NULL, -- e.g. {"coffee", "kidney_safe", "family_friendly"}
    attributes          jsonb       NULL, -- arbitrary attribute bag (opening_hours, price_level, etc.)

    -- Operational state
    status              text        NOT NULL DEFAULT 'active', -- active | inactive | closed | draft

    -- Audit
    created_at          timestamptz NOT NULL DEFAULT now(),
    created_by          text        NOT NULL,
    updated_at          timestamptz NOT NULL DEFAULT now(),
    updated_by          text        NULL,

    CHECK (status IN ('active', 'inactive', 'closed', 'draft'))
);

CREATE INDEX IF NOT EXISTS lem_service_point_city_idx
    ON lem_service_point (city_code, status);

CREATE INDEX IF NOT EXISTS lem_service_point_vendor_idx
    ON lem_service_point (vendor_id);

CREATE INDEX IF NOT EXISTS lem_service_point_class_idx
    ON lem_service_point (class_id, city_code);


-- 2. SERVICE EDGES -------------------------------------------------------

CREATE TABLE IF NOT EXISTS lem_service_edge
(
    service_edge_id     text PRIMARY KEY,

    -- Endpoints
    from_service_point_id  text    NOT NULL,
    to_service_point_id    text    NOT NULL,

    -- Classification
    edge_class_id       text        NOT NULL, -- walk | transit | recommended_path | unsafe_edge | cluster_link | ...

    -- Metrics (logical)
    distance_meters     numeric(12,2)   NULL,
    travel_time_seconds integer         NULL,
    elevation_up_m      numeric(8,2)    NULL,
    elevation_down_m    numeric(8,2)    NULL,

    -- Scores [0..1]
    safety_score        numeric(3,2)    NULL CHECK (safety_score BETWEEN 0 AND 1),
    comfort_score       numeric(3,2)    NULL CHECK (comfort_score BETWEEN 0 AND 1),
    scenic_score        numeric(3,2)    NULL CHECK (scenic_score BETWEEN 0 AND 1),

    -- Cost / constraints
    cost_score          numeric(3,2)    NULL CHECK (cost_score BETWEEN 0 AND 1),
    is_bidirectional    boolean         NOT NULL DEFAULT true,

    -- City context (denormalized for fast filtering)
    city_code           text            NOT NULL,
    market_code         text            NULL,

    -- Operational state
    status              text            NOT NULL DEFAULT 'active', -- active | inactive | closed | draft

    -- Optional metadata (e.g. transit line, route id)
    metadata            jsonb           NULL,

    created_at          timestamptz     NOT NULL DEFAULT now(),
    created_by          text            NOT NULL,
    updated_at          timestamptz     NOT NULL DEFAULT now(),
    updated_by          text            NULL,

    CHECK (status IN ('active', 'inactive', 'closed', 'draft'))
);

ALTER TABLE lem_service_edge
    ADD CONSTRAINT lem_service_edge_from_sp_fk
        FOREIGN KEY (from_service_point_id)
        REFERENCES lem_service_point (service_point_id)
        ON DELETE CASCADE;

ALTER TABLE lem_service_edge
    ADD CONSTRAINT lem_service_edge_to_sp_fk
        FOREIGN KEY (to_service_point_id)
        REFERENCES lem_service_point (service_point_id)
        ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS lem_service_edge_city_idx
    ON lem_service_edge (city_code, status);

CREATE INDEX IF NOT EXISTS lem_service_edge_from_to_idx
    ON lem_service_edge (from_service_point_id, to_service_point_id);

CREATE INDEX IF NOT EXISTS lem_service_edge_class_idx
    ON lem_service_edge (edge_class_id, city_code);


-- 3. EXPERIENCE SNAPSHOTS -----------------------------------------------

-- Aggregated experience/metrics per city/cluster/facet/time window.

CREATE TABLE IF NOT EXISTS lem_experience_snapshot
(
    experience_snapshot_id    text PRIMARY KEY,

    -- Context
    city_code                 text        NOT NULL,
    market_code               text        NULL,

    -- Target (what the snapshot refers to)
    target_type               text        NOT NULL, -- city | cluster | service_point | route
    target_id                 text        NOT NULL, -- cluster_id / service_point_id / route_id

    -- Facet / layer
    facet_id                  text        NULL,     -- e.g. coffee_walk, kidney_safe

    -- Time window
    window_start              timestamptz NOT NULL,
    window_end                timestamptz NOT NULL,

    -- Aggregated metrics (normalized 0..1 or domain-specific)
    safety_score_avg          numeric(3,2)    NULL CHECK (safety_score_avg BETWEEN 0 AND 1),
    safety_score_p10          numeric(3,2)    NULL CHECK (safety_score_p10 BETWEEN 0 AND 1),

    comfort_score_avg         numeric(3,2)    NULL CHECK (comfort_score_avg BETWEEN 0 AND 1),
    scenic_score_avg          numeric(3,2)    NULL CHECK (scenic_score_avg BETWEEN 0 AND 1),

    price_level_avg           numeric(4,2)    NULL, -- domain specific (e.g. 1..5)

    volume_visits             bigint          NULL,
    volume_redemptions       bigint          NULL,

    -- Additional metrics bucket
    metrics_extra             jsonb           NULL,

    -- Source info (for audit)
    source                    text            NULL, -- analytics job id, pipeline id
    computed_at               timestamptz     NOT NULL DEFAULT now(),

    CHECK (target_type IN ('city', 'cluster', 'service_point', 'route')),
    CHECK (window_end > window_start)
);

CREATE INDEX IF NOT EXISTS lem_experience_snapshot_city_idx
    ON lem_experience_snapshot (city_code, target_type, target_id);

CREATE INDEX IF NOT EXISTS lem_experience_snapshot_facet_idx
    ON lem_experience_snapshot (facet_id);

CREATE INDEX IF NOT EXISTS lem_experience_snapshot_window_idx
    ON lem_experience_snapshot (window_start, window_end);


COMMIT;

