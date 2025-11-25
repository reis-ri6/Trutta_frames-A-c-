-- Domain: services
-- Spec: domains/services/30-schemas-mapping.md
-- Artefact: SCHEMA-SERVICES-POI

CREATE TABLE IF NOT EXISTS services_poi (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  category    text,
  address     text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
