-- PD-003 Registry DDL
-- Scope: registry-specific tables and extensions around product domain model
-- Target: PostgreSQL 15+ / Supabase
-- Schema: product

CREATE SCHEMA IF NOT EXISTS product;

-- =========================================================
-- 1. Raw ProductDef Storage / Ingestion Artifacts
-- =========================================================

-- Canonical reference to submitted ProductDef documents (PDSL)
-- One row per ingestion attempt for a given (product_id, version).

CREATE TABLE IF NOT EXISTS product.product_defs_raw (
    id                  text PRIMARY KEY,   -- ULID/UUID
    product_id          text NOT NULL,
    product_version_id  text NULL,          -- may be NULL before successful ingest
    version             text NOT NULL,      -- semver from ProductDef
    env                 text NOT NULL,      -- dev | stage | prod | ...
    spec_version        text NOT NULL,      -- meta.spec_version
    format              text NOT NULL,      -- yaml | json | other
    storage_ref         text NOT NULL,      -- s3://... or gcs://... or git ref
    content_hash        text NOT NULL,      -- SHA-256 or similar
    submitted_by        text NOT NULL,      -- user/agent id
    submitted_at        timestamptz NOT NULL DEFAULT now(),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT product_defs_raw_env_valid
        CHECK (env IN ('dev', 'stage', 'prod')),
    CONSTRAINT product_defs_raw_format_valid
        CHECK (format IN ('yaml', 'json', 'other'))
);

CREATE INDEX IF NOT EXISTS product_defs_raw_product_env_idx
    ON product.product_defs_raw (product_id, version, env);

CREATE INDEX IF NOT EXISTS product_defs_raw_hash_idx
    ON product.product_defs_raw (content_hash);

-- =========================================================
-- 2. Ingestion Runs & Errors
-- =========================================================

-- One ingestion run corresponds to a concrete attempt to process ProductDef
-- into normalized domain model. This is the unit for retries and monitoring.

CREATE TABLE IF NOT EXISTS product.product_ingestion_runs (
    id                  text PRIMARY KEY,
    product_defs_raw_id text NOT NULL,
    product_id          text NULL,
    product_version_id  text NULL,
    env                 text NOT NULL,      -- dev | stage | prod
    source              text NOT NULL,      -- cli | api | import | other
    status              text NOT NULL,      -- pending | running | succeeded | failed
    error_type          text NULL,          -- SCHEMA_ERROR | DOMAIN_ERROR | REF_ERROR | POLICY_ERROR
    error_message       text NULL,
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    started_at          timestamptz NOT NULL DEFAULT now(),
    finished_at         timestamptz NULL,
    CONSTRAINT product_ingestion_runs_raw_fk
        FOREIGN KEY (product_defs_raw_id) REFERENCES product.product_defs_raw(id) ON DELETE CASCADE,
    CONSTRAINT product_ingestion_runs_env_valid
        CHECK (env IN ('dev', 'stage', 'prod')),
    CONSTRAINT product_ingestion_runs_status_valid
        CHECK (status IN ('pending', 'running', 'succeeded', 'failed')),
    CONSTRAINT product_ingestion_runs_error_type_valid
        CHECK (error_type IS NULL OR error_type IN ('SCHEMA_ERROR', 'DOMAIN_ERROR', 'REF_ERROR', 'POLICY_ERROR'))
);

CREATE INDEX IF NOT EXISTS product_ingestion_runs_status_env_idx
    ON product.product_ingestion_runs (env, status, started_at);

CREATE INDEX IF NOT EXISTS product_ingestion_runs_product_idx
    ON product.product_ingestion_runs (product_id, product_version_id);

-- =========================================================
-- 3. Status History for ProductVersion & Overlays
-- =========================================================

-- History of status transitions for ProductVersion

CREATE TABLE IF NOT EXISTS product.product_version_status_history (
    id                 text PRIMARY KEY,
    product_version_id text NOT NULL,
    old_status         text NULL,
    new_status         text NOT NULL,
    actor_id           text NOT NULL,
    actor_type         text NOT NULL,   -- user | service | agent
    reason             text NULL,
    metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
    changed_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_version_status_history_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_version_status_history_actor_type_valid
        CHECK (actor_type IN ('user', 'service', 'agent'))
);

CREATE INDEX IF NOT EXISTS product_version_status_history_product_idx
    ON product.product_version_status_history (product_version_id, changed_at DESC);

-- Extend product_overlays with status field for lifecycle management

ALTER TABLE product.product_overlays
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';  -- active | disabled

ALTER TABLE product.product_overlays
    ADD CONSTRAINT product_overlays_status_valid
        CHECK (status IN ('active', 'disabled'));

-- Track overlay status transitions (enable/disable)

CREATE TABLE IF NOT EXISTS product.product_overlay_status_history (
    id             text PRIMARY KEY,
    overlay_id     text NOT NULL,
    old_status     text NULL,
    new_status     text NOT NULL,
    actor_id       text NOT NULL,
    actor_type     text NOT NULL,  -- user | service | agent
    reason         text NULL,
    metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
    changed_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_overlay_status_history_overlay_fk
        FOREIGN KEY (overlay_id) REFERENCES product.product_overlays(id) ON DELETE CASCADE,
    CONSTRAINT product_overlay_status_history_actor_type_valid
        CHECK (actor_type IN ('user', 'service', 'agent'))
);

CREATE INDEX IF NOT EXISTS product_overlay_status_history_overlay_idx
    ON product.product_overlay_status_history (overlay_id, changed_at DESC);

-- =========================================================
-- 4. Registry Audit Log
-- =========================================================

-- Generic audit log for registry write operations.

CREATE TABLE IF NOT EXISTS product.registry_audit_log (
    id             text PRIMARY KEY,
    resource_type  text NOT NULL,   -- product | product_version | overlay | profile | integration_profile | ...
    resource_id    text NOT NULL,
    action         text NOT NULL,   -- create | update | status_change | overlay_create | overlay_update | delete
    actor_id       text NOT NULL,
    actor_type     text NOT NULL,   -- user | service | agent
    reason         text NULL,
    diff           jsonb NULL,      -- optional structured diff
    metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT registry_audit_log_action_valid
        CHECK (action IN ('create','update','status_change','overlay_create','overlay_update','delete')),
    CONSTRAINT registry_audit_log_actor_type_valid
        CHECK (actor_type IN ('user','service','agent'))
);

CREATE INDEX IF NOT EXISTS registry_audit_log_resource_idx
    ON product.registry_audit_log (resource_type, resource_id, created_at DESC);

CREATE INDEX IF NOT EXISTS registry_audit_log_actor_idx
    ON product.registry_audit_log (actor_id, created_at DESC);

-- =========================================================
-- 5. Outbox for Domain Events
-- =========================================================

-- Transactional outbox to integrate Registry with message bus.

CREATE TABLE IF NOT EXISTS product.registry_events_outbox (
    id              text PRIMARY KEY,
    aggregate_type  text NOT NULL,     -- product | product_version | overlay | ...
    aggregate_id    text NOT NULL,
    event_type      text NOT NULL,     -- product.version.created | ...
    payload         jsonb NOT NULL,
    status          text NOT NULL,     -- pending | published | failed
    attempt_count   integer NOT NULL DEFAULT 0,
    last_error      text NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    published_at    timestamptz NULL,
    CONSTRAINT registry_events_outbox_status_valid
        CHECK (status IN ('pending','published','failed'))
);

CREATE INDEX IF NOT EXISTS registry_events_outbox_status_idx
    ON product.registry_events_outbox (status, created_at);

CREATE INDEX IF NOT EXISTS registry_events_outbox_aggregate_idx
    ON product.registry_events_outbox (aggregate_type, aggregate_id);

-- =========================================================
-- 6. Promotion Jobs (Env-to-Env)
-- =========================================================

-- Track promotion of products/versions between environments

CREATE TABLE IF NOT EXISTS product.registry_promotion_jobs (
    id                  text PRIMARY KEY,
    product_id          text NOT NULL,
    version             text NOT NULL,
    source_env          text NOT NULL,   -- dev | stage | other
    target_env          text NOT NULL,   -- stage | prod | other
    status              text NOT NULL,   -- pending | running | succeeded | failed
    initiated_by        text NOT NULL,
    initiated_at        timestamptz NOT NULL DEFAULT now(),
    finished_at         timestamptz NULL,
    error_message       text NULL,
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT registry_promotion_jobs_env_valid
        CHECK (source_env IN ('dev','stage','prod') AND target_env IN ('dev','stage','prod')),
    CONSTRAINT registry_promotion_jobs_status_valid
        CHECK (status IN ('pending','running','succeeded','failed'))
);

CREATE INDEX IF NOT EXISTS registry_promotion_jobs_product_idx
    ON product.registry_promotion_jobs (product_id, version, source_env, target_env);

CREATE INDEX IF NOT EXISTS registry_promotion_jobs_status_idx
    ON product.registry_promotion_jobs (status, initiated_at);
