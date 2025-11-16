-- PD-002 Product Domain Model DDL (normalized)
-- Target: PostgreSQL 15+ / Supabase
-- Schema: product

CREATE SCHEMA IF NOT EXISTS product;

-- =========================================================
-- 1. Taxonomy & Segmentation
-- =========================================================

CREATE TABLE IF NOT EXISTS product.categories (
    id         text PRIMARY KEY,
    code       text NOT NULL,
    parent_id  text NULL,
    title      text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT categories_code_unique UNIQUE (code),
    CONSTRAINT categories_parent_fk
        FOREIGN KEY (parent_id) REFERENCES product.categories(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS product.tags (
    id         text PRIMARY KEY,
    code       text NOT NULL,
    title      text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tags_code_unique UNIQUE (code)
);

CREATE TABLE IF NOT EXISTS product.markets (
    id         text PRIMARY KEY,
    code       text NOT NULL,
    geo_scope  text NOT NULL,   -- country | region | city | custom
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT markets_code_unique UNIQUE (code),
    CONSTRAINT markets_geo_scope_valid
        CHECK (geo_scope IN ('country', 'region', 'city', 'custom'))
);

CREATE TABLE IF NOT EXISTS product.segments (
    id          text PRIMARY KEY,
    code        text NOT NULL,
    description text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT segments_code_unique UNIQUE (code)
);

-- =========================================================
-- 2. Product Core
-- =========================================================

CREATE TABLE IF NOT EXISTS product.products (
    id           text PRIMARY KEY,  -- ULID/UUID-like, generated in app/Registry
    code         text NOT NULL,
    slug_base    text NOT NULL,
    product_type text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    created_by   text NOT NULL,
    CONSTRAINT products_code_unique UNIQUE (code),
    CONSTRAINT products_slug_base_unique UNIQUE (slug_base),
    CONSTRAINT products_product_type_nonempty CHECK (length(trim(product_type)) > 0)
);

CREATE TABLE IF NOT EXISTS product.product_versions (
    id               text PRIMARY KEY,
    product_id       text NOT NULL,
    version          text NOT NULL,   -- semver
    status           text NOT NULL,   -- draft | review | active | deprecated | retired
    title_default    text NOT NULL,
    category_id      text NULL,
    product_type     text NOT NULL,   -- denormalized copy from products
    valid_from       timestamptz NULL,
    valid_until      timestamptz NULL,
    dsl_document_ref text NOT NULL,   -- storage ref to YAML/JSON ProductDef
    created_at       timestamptz NOT NULL DEFAULT now(),
    created_by       text NOT NULL,
    updated_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_versions_product_fk
        FOREIGN KEY (product_id) REFERENCES product.products(id) ON DELETE CASCADE,
    CONSTRAINT product_versions_category_fk
        FOREIGN KEY (category_id) REFERENCES product.categories(id),
    CONSTRAINT product_versions_unique_per_product UNIQUE (product_id, version),
    CONSTRAINT product_versions_status_valid
        CHECK (status IN ('draft', 'review', 'active', 'deprecated', 'retired')),
    CONSTRAINT product_versions_product_type_nonempty CHECK (length(trim(product_type)) > 0),
    CONSTRAINT product_versions_valid_range
        CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until >= valid_from)
);

-- Localized titles (BCP-47 locales)
CREATE TABLE IF NOT EXISTS product.product_version_titles (
    product_version_id text NOT NULL,
    locale             text NOT NULL,
    title              text NOT NULL,
    CONSTRAINT product_version_titles_pk
        PRIMARY KEY (product_version_id, locale),
    CONSTRAINT product_version_titles_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE
);

-- Overlays (operator / market / city / vendor)
CREATE TABLE IF NOT EXISTS product.product_overlays (
    id                      text PRIMARY KEY,
    base_product_version_id text NOT NULL,
    overlay_kind            text NOT NULL,  -- operator | market | city | vendor
    operator_code           text NULL,
    market_code             text NULL,
    city_code               text NULL,
    patch_payload           jsonb NOT NULL,
    created_at              timestamptz NOT NULL DEFAULT now(),
    created_by              text NOT NULL,
    CONSTRAINT product_overlays_product_version_fk
        FOREIGN KEY (base_product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_overlays_overlay_kind_valid
        CHECK (overlay_kind IN ('operator', 'market', 'city', 'vendor'))
);

-- ProductVersion ↔ Category (N:M, though на практиці зазвичай 1:N)
CREATE TABLE IF NOT EXISTS product.product_version_categories (
    product_version_id text NOT NULL,
    category_id        text NOT NULL,
    CONSTRAINT product_version_categories_pk
        PRIMARY KEY (product_version_id, category_id),
    CONSTRAINT product_version_categories_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_version_categories_category_fk
        FOREIGN KEY (category_id) REFERENCES product.categories(id)
);

-- ProductVersion ↔ Tag (N:M)
CREATE TABLE IF NOT EXISTS product.product_version_tags (
    product_version_id text NOT NULL,
    tag_id             text NOT NULL,
    CONSTRAINT product_version_tags_pk
        PRIMARY KEY (product_version_id, tag_id),
    CONSTRAINT product_version_tags_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_version_tags_tag_fk
        FOREIGN KEY (tag_id) REFERENCES product.tags(id)
);

-- ProductVersion ↔ Market (N:M)
CREATE TABLE IF NOT EXISTS product.product_version_markets (
    product_version_id text NOT NULL,
    market_id          text NOT NULL,
    CONSTRAINT product_version_markets_pk
        PRIMARY KEY (product_version_id, market_id),
    CONSTRAINT product_version_markets_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_version_markets_market_fk
        FOREIGN KEY (market_id) REFERENCES product.markets(id)
);

-- ProductVersion ↔ Segment (N:M)
CREATE TABLE IF NOT EXISTS product.product_version_segments (
    product_version_id text NOT NULL,
    segment_id         text NOT NULL,
    CONSTRAINT product_version_segments_pk
        PRIMARY KEY (product_version_id, segment_id),
    CONSTRAINT product_version_segments_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_version_segments_segment_fk
        FOREIGN KEY (segment_id) REFERENCES product.segments(id)
);

-- =========================================================
-- 3. Journeys & Runtime
-- =========================================================

CREATE TABLE IF NOT EXISTS product.journey_classes (
    id          text PRIMARY KEY,  -- e.g. 'city.coffee.pass'
    description text NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Allowed product_types for each JourneyClass
CREATE TABLE IF NOT EXISTS product.journey_class_product_types (
    journey_class_id text NOT NULL,
    product_type     text NOT NULL,
    CONSTRAINT journey_class_product_types_pk
        PRIMARY KEY (journey_class_id, product_type),
    CONSTRAINT journey_class_product_types_class_fk
        FOREIGN KEY (journey_class_id) REFERENCES product.journey_classes(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS product.journey_document_refs (
    id               text PRIMARY KEY,
    journey_class_id text NOT NULL,
    version          text NOT NULL,
    document_ref     text NOT NULL,  -- e.g. 'TJM-JOURNEY-COFFEE-PASS@1.0.0'
    status           text NOT NULL,  -- draft | active | deprecated
    created_at       timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT journey_document_refs_class_fk
        FOREIGN KEY (journey_class_id) REFERENCES product.journey_classes(id) ON DELETE CASCADE,
    CONSTRAINT journey_document_refs_unique_per_class_version
        UNIQUE (journey_class_id, version),
    CONSTRAINT journey_document_refs_status_valid
        CHECK (status IN ('draft', 'active', 'deprecated'))
);

CREATE TABLE IF NOT EXISTS product.journey_bindings (
    id                      text PRIMARY KEY,
    product_version_id      text NOT NULL,
    journey_document_ref_id text NOT NULL,
    entry_points            text[] NOT NULL DEFAULT '{}',
    state_map               jsonb  NOT NULL,
    created_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT journey_bindings_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT journey_bindings_doc_ref_fk
        FOREIGN KEY (journey_document_ref_id) REFERENCES product.journey_document_refs(id),
    CONSTRAINT journey_bindings_unique_per_product_version
        UNIQUE (product_version_id)
);

-- =========================================================
-- 4. Profiles Subdomain
-- =========================================================

CREATE TABLE IF NOT EXISTS product.profiles (
    id          text PRIMARY KEY,
    profile_type text NOT NULL,  -- financial | token | loyalty | ops | safety | quality | ui | ...
    scope        text NOT NULL,  -- global | operator | market | city | vendor
    owner_org    text NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT profiles_profile_type_nonempty CHECK (length(trim(profile_type)) > 0),
    CONSTRAINT profiles_scope_valid
        CHECK (scope IN ('global', 'operator', 'market', 'city', 'vendor'))
);

CREATE TABLE IF NOT EXISTS product.profile_versions (
    id         text PRIMARY KEY,
    profile_id text NOT NULL,
    version    text NOT NULL,
    status     text NOT NULL,  -- draft | active | deprecated | retired
    payload    jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT profile_versions_profile_fk
        FOREIGN KEY (profile_id) REFERENCES product.profiles(id) ON DELETE CASCADE,
    CONSTRAINT profile_versions_unique_per_profile_version
        UNIQUE (profile_id, version),
    CONSTRAINT profile_versions_status_valid
        CHECK (status IN ('draft', 'active', 'deprecated', 'retired'))
);

CREATE TABLE IF NOT EXISTS product.product_profile_bindings (
    id                 text PRIMARY KEY,
    product_version_id text NOT NULL,
    profile_version_id text NOT NULL,
    profile_type       text NOT NULL,  -- denormalized copy from profiles.profile_type
    role               text NOT NULL,  -- primary | fallback | campaign_override | ...
    created_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_profile_bindings_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_profile_bindings_profile_version_fk
        FOREIGN KEY (profile_version_id) REFERENCES product.profile_versions(id),
    CONSTRAINT product_profile_bindings_unique_pair
        UNIQUE (product_version_id, profile_version_id)
);

-- Один primary-профіль на (product_version, profile_type)
CREATE UNIQUE INDEX IF NOT EXISTS product_profile_bindings_one_primary_per_type
    ON product.product_profile_bindings (product_version_id, profile_type)
    WHERE role = 'primary';

-- =========================================================
-- 5. Integrations Subdomain
-- =========================================================

CREATE TABLE IF NOT EXISTS product.integration_endpoints (
    id                 text PRIMARY KEY,
    kind               text NOT NULL,  -- trutta | lem | reservation_system | host_system | billing | ...
    external_system_id text NOT NULL,
    config_ref         text NULL,      -- ref to secrets/config store
    created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS product.integration_profiles (
    id                     text PRIMARY KEY,
    integration_endpoint_id text NOT NULL,
    name                   text NOT NULL,
    payload                jsonb NOT NULL,
    created_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT integration_profiles_endpoint_fk
        FOREIGN KEY (integration_endpoint_id) REFERENCES product.integration_endpoints(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS product.product_integration_bindings (
    id                     text PRIMARY KEY,
    product_version_id     text NOT NULL,
    integration_profile_id text NOT NULL,
    purpose                text NOT NULL,  -- entitlement | settlement | city_graph | reservation | host_mapping | ...
    created_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT product_integration_bindings_product_fk
        FOREIGN KEY (product_version_id) REFERENCES product.product_versions(id) ON DELETE CASCADE,
    CONSTRAINT product_integration_bindings_profile_fk
        FOREIGN KEY (integration_profile_id) REFERENCES product.integration_profiles(id),
    CONSTRAINT product_integration_bindings_unique
        UNIQUE (product_version_id, integration_profile_id, purpose)
);

-- =========================================================
-- 6. Indexes for common access patterns
-- =========================================================

-- Product versions by product & status
CREATE INDEX IF NOT EXISTS product_versions_product_status_idx
    ON product.product_versions (product_id, status);

-- Active product versions by validity window
CREATE INDEX IF NOT EXISTS product_versions_status_valid_from_idx
    ON product.product_versions (status, valid_from, valid_until);

-- Journey bindings by journey_document_ref
CREATE INDEX IF NOT EXISTS journey_bindings_doc_ref_idx
    ON product.journey_bindings (journey_document_ref_id);

-- Profile bindings by product_version
CREATE INDEX IF NOT EXISTS product_profile_bindings_product_idx
    ON product.product_profile_bindings (product_version_id);

-- Integration bindings by product_version
CREATE INDEX IF NOT EXISTS product_integration_bindings_product_idx
    ON product.product_integration_bindings (product_version_id);

-- Taxonomy reverse lookups
CREATE INDEX IF NOT EXISTS product_version_tags_tag_idx
    ON product.product_version_tags (tag_id);

CREATE INDEX IF NOT EXISTS product_version_markets_market_idx
    ON product.product_version_markets (market_id);

CREATE INDEX IF NOT EXISTS product_version_segments_segment_idx
    ON product.product_version_segments (segment_id);
