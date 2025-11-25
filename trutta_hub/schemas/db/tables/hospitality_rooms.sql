-- Domain: hospitality
-- Spec: domains/hospitality/30-schemas-mapping.md
-- Artefact: SCHEMA-HOSPITALITY-ROOMS

CREATE TABLE IF NOT EXISTS hospitality_rooms (
  id         uuid PRIMARY KEY,
  hotel_id   uuid NOT NULL,
  name       text NOT NULL,
  capacity   int,
  price      numeric,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
