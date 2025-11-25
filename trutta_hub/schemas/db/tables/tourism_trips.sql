-- Domain: tourism
-- Spec: domains/tourism/30-schemas-mapping.md
-- Artefact: SCHEMA-TOURISM-TRIPS

CREATE TABLE IF NOT EXISTS tourism_trips (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  city_id     uuid,
  description text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
