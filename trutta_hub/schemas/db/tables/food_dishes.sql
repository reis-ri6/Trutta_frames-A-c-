-- Domain: food
-- Spec: domains/food/30-schemas-mapping.md
-- Artefact: SCHEMA-FOOD-DISHES

CREATE TABLE IF NOT EXISTS food_dishes (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  cuisine     text,
  allergens   text[],
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
