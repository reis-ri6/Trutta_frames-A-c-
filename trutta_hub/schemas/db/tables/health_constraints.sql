-- Domain: health
-- Spec: domains/health/30-schemas-mapping.md
-- Artefact: SCHEMA-HEALTH-CONSTRAINTS

CREATE TABLE IF NOT EXISTS health_constraints (
  id          uuid PRIMARY KEY,
  user_id     uuid NOT NULL,
  constraint  text NOT NULL,
  severity    text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
