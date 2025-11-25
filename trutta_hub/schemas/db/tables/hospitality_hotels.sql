-- Domain: hospitality
-- Spec: domains/hospitality/30-schemas-mapping.md
-- Artefact: SCHEMA-HOSPITALITY-HOTELS

CREATE TABLE IF NOT EXISTS hospitality_hotels (
  id            uuid PRIMARY KEY,
  ext_id        text,                -- external provider id
  name          text NOT NULL,
  city_id       uuid NOT NULL,
  address       text,
  geo_point     geometry(Point, 4326),
  stars         int,
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);
