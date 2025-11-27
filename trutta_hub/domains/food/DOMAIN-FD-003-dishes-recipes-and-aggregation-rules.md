# DOMAIN-FD-003 — Dishes, Recipes & Aggregation Rules

**ID:** DOMAIN-FD-003  
**Назва:** Dishes, Recipes & Aggregation Rules  
**Статус:** draft  
**Власники:** data, arch, product (food/health), analytics  
**Повʼязані документи:**  
- DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview  
- DOMAIN-FD-002 — Ingredients & Nutrient Profiles  
- PD-001 — Product DSL Blueprint  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint

---

## 1. Purpose

Фіксує **канонічну модель страв (Dish/Recipe)**:

- як з інгредієнтів (DOMAIN-FD-002) формується страва;
- як рахується порція/нутрієнти/алергени;
- як працюють варіанти, модифікатори, групи страв;
- як це підʼєднується до DSL/Token/меню.

---

## 2. Scope

### 2.1. Входить

- логічні сутності:
  - `Dish`, `Recipe`, `RecipeStep`, `DishVariant`, `DishGroup`;
- порції та агрегація нутрієнтів;
- базові правила трансформації (готування);
- звʼязок із DSL-продуктами та токенами.

### 2.2. Не входить

- виробничий кухонний / складський облік (інший домен);
- UI/UX-подача страв (VG-4xx);
- конкретні health-алгоритми (DOMAIN-HL).

---

## 3. Conceptual модель

### 3.1. Dish

Логічна страва, абстрагована від конкретного меню/ціни.

- `Dish`:
  - `dish_id` (canonical);
  - `canonical_name`;
  - `alt_names[]`;
  - `dish_category` (main, side, soup, dessert, drink, snack, …);
  - `description_short`, `description_long`;
  - `baseline_portion_amount` (число);
  - `baseline_portion_unit` (g/ml/unit);
  - `recipe_id` (опц., якщо є структурована рецептура);
  - `nutrient_profile_id` (агрегований профіль, якщо рахуємо наперед);
  - `allergen_tags[]`;
  - `diet_tags[]`;
  - `source_refs[]` (вендорські/OTA/локальні id).

### 3.2. Recipe

Опис «як зробити страву» для обчислення нутрієнтів та consistency.

- `Recipe`:
  - `recipe_id`;
  - `dish_id`;
  - `yield_portions` (скільки порцій дає базова рецептура);
  - `yield_portion_amount` (g/ml/units per portion);
  - `ingredients[]`:
    - `ingredient_id`;
    - `quantity` (float);
    - `unit` (g/ml/unit/pcs);
  - `steps[]` (структурований текст, опц.).

**Норма:**  
`Dish.baseline_portion_amount` = `yield_portion_amount` для основної рецептури, якщо не вказано інше.

### 3.3. DishVariant

Варіація базової страви (розмір, опції інгредієнтів).

- `DishVariant`:
  - `dish_variant_id`;
  - `dish_id`;
  - `label` (small/medium/large, double-shot, lactose-free, etc.);
  - `portion_multiplier` (множник до baseline-порції);
  - `ingredient_adjustments[]`:
    - `ingredient_id`;
    - `delta_quantity` (±);
    - `unit` (як у базовій рецептурі);
  - `additional_diet_tags[]`, `removed_diet_tags[]`;
  - `additional_allergen_tags[]`, `removed_allergen_tags[]`.

### 3.4. DishGroup

Логічна група страв (для токенів/програм).

- `DishGroup`:
  - `dish_group_id`;
  - `name`;
  - `criteria` (rule-based опис, напр. «будь-які vegan-main страви до 500 kcal»);
  - `explicit_members[]` (опц. список `dish_id`);
  - `excluded_members[]`.

Приклад `criteria` (yaml):

```yaml
criteria:
  include:
    dish_categories: ["main"]
    diet_tags: ["vegan"]
    max_kcal_per_baseline_portion: 500
  exclude:
    allergen_tags: ["nuts"]
```

---

## 4. Data model (canonical layer)

У canonical-шарі (PD-017):

* `canonical.dishes`
* `canonical.recipes`
* `canonical.recipe_ingredients`
* `canonical.dish_variants`
* `canonical.dish_groups`

Схеми спрощено:

**canonical.dishes**

* `dish_id` PK
* `canonical_name`
* `dish_category`
* `baseline_portion_amount`
* `baseline_portion_unit`
* `recipe_id` FK (nullable)
* `nutrient_profile_id` FK (nullable)
* `diet_tags` (jsonb)
* `allergen_tags` (jsonb)
* `source_refs` (jsonb)
* timestamps

**canonical.recipes**

* `recipe_id` PK
* `dish_id` FK
* `yield_portions`
* `yield_portion_amount`
* `yield_portion_unit`
* `steps` (jsonb/text, опц.)
* timestamps

**canonical.recipe_ingredients**

* `recipe_id` FK
* `ingredient_id` FK
* `quantity`
* `unit` (g/ml/unit/pcs)

**canonical.dish_variants**

* `dish_variant_id` PK
* `dish_id` FK
* `label`
* `portion_multiplier`
* `ingredient_adjustments` (jsonb)
* `diet_tag_diff` (jsonb)
* `allergen_tag_diff` (jsonb)

**canonical.dish_groups**

* `dish_group_id` PK
* `name`
* `criteria` (jsonb)
* `explicit_members` (jsonb)
* `excluded_members` (jsonb)

---

## 5. Агрегація нутрієнтів

### 5.1. Base Dish (baseline portion)

Налаштування:

* `Recipe` задає:

  * `yield_portions`;
  * `yield_portion_amount` (g/ml);
* `Dish.baseline_portion_amount` = `yield_portion_amount`, або окремо визначена.

Алгоритм (псевдо):

1. Для кожного інгредієнта в рецепті:

   * беремо `Ingredient.nutrient_profile_id` (DOMAIN-FD-002);
   * масштабуючи профіль до `quantity` (через `base_amount`).
2. Сумуємо по `nutrient_code`.
3. Нормуємо до `baseline_portion_amount` (якщо відрізняється від `yield_portion_amount`).
4. Результат пишемо у `NutrientProfile` з `source = "aggregated_from_recipe"`.

Формула:

```text
amount_dish_baseline(nutrient_code) =
  Σ_i amount_profile_i(nutrient_code) * (quantity_i / base_amount_i)
```

якщо `yield_portion_amount != baseline_portion_amount`:

```text
amount_per_baseline =
  amount_per_yield_portion * (baseline_portion_amount / yield_portion_amount)
```

### 5.2. Variants

Для `DishVariant`:

1. Починаємо з baseline-профілю страви.
2. Коригуємо інгредієнти згідно `ingredient_adjustments[]`:

   * перераховуємо різницю нутрієнтів (додаємо/віднімаємо).
3. Застосовуємо `portion_multiplier`.

Формула:

```text
amount_variant(nutrient_code) =
  (amount_baseline(nutrient_code) + Δ_ingredients(nutrient_code))
  * portion_multiplier
```

де `Δ_ingredients` — сумарний внесок +/- інгредієнтів.

---

## 6. Effects of cooking (heat transformations)

Модель **спрощена**, не ліземо в повну біохімію:

* кожен `Recipe` може мати `cooking_effects`:

```yaml
cooking_effects:
  energy_retention_factor: 0.95
  vitamin_c_retention_factor: 0.6
  generic_mineral_retention_factor: 0.9
```

* при агрегації:

```text
amount_after_cooking(nutrient_code) =
  amount_before_cooking(nutrient_code) * retention_factor(nutrient_code)
```

де `retention_factor`:

* або з таблиці за типом нутрієнта;
* або з `cooking_effects` рецептури.

Якщо нічого не задано — retention = 1.0 (no-op).

---

## 7. DSL / Token binding

### 7.1. DSL products

У DSL (PD-001/003) страва виступає **джерелом даних** для food-продуктів.

Приклади:

1. Продукт «конкретна страва»:

```yaml
product_id: "FD:vienna:hotel-X:oatmeal-porridge"
kind: "food_item"
source:
  dish_id: "dish:oatmeal-porridge"
portion:
  mode: "baseline"   # або explicit
```

2. Продукт «варіант»:

```yaml
product_id: "FD:vienna:coffee-latte-large-oat"
kind: "food_item"
source:
  dish_id: "dish:coffee-latte"
  variant_id: "variant:large-oat-milk"
```

3. Продукт «груповий»:

```yaml
product_id: "FD:vienna:any-vegan-lunch"
kind: "food_group"
source:
  dish_group_id: "dish_group:vienna:vegan-lunch"
```

### 7.2. Token archetypes

Токени (PD-005) для їжі:

* `meal_token`, `coffee_token`, `hospital_meal_token`, `healthy_meal_token`;
* вказують:

  * або `dish_group_id`;
  * або `dish_category` + `diet_tags` + межі по калоріях.

FD/DSL забезпечують:

* правильне звʼязування конкретного редемпшену з canonical `Dish`/`DishGroup`.

---

## 8. Взаємодія з менюшками (DOMAIN-FD-004)

DOMAIN-FD-003 оперує **логікою страв**.
DOMAIN-FD-004 описує **меню/позиції меню**.

Звʼязок:

* `MenuItem` має FK на:

  * `dish_id`;
  * опц. `dish_variant_id`.

`MenuItem` може мати власну порцію (і тоді нутрієнти масштабуються) — це вже зона DOMAIN-FD-004, але логіка агрегації базується на моделях цього документу.

---

## 9. Аналітика й quality

На базі цієї моделі:

* будуємо аналітику:

  * consumption by dish/dish_category;
  * consumption by `diet_tags`, `allergen_tags`;
  * калорійність/нутрієнти по програмах/містах/вендорах;

* quality-чек:

  * чи всі `Dish` мають валідний `baseline_portion`;
  * % страв із валідним агрегованим `nutrient_profile_id`;
  * consistency між variants і baseline.

Реалізація → DOMAIN-FD-007 + PD-016.

---

## 10. Repos & layout

У `trutta_hub`:

```txt
docs/domain/
  DOMAIN-FD-001-food-and-menu-domain-overview.md
  DOMAIN-FD-002-ingredients-and-nutrient-profiles.md
  DOMAIN-FD-003-dishes-recipes-and-aggregation-rules.md

schemas/db/
  canonical/fd_dishes.dbml
  canonical/fd_recipes.dbml
  canonical/fd_dish_variants.dbml
  canonical/fd_dish_groups.dbml
```

У city/project-репах:

```txt
data/fd/
  dishes_local_overrides.yaml       # локальні назви/опції
  recipes_local_overrides.yaml      # локальні рецептури/adjustments
docs/domain/
  DOMAIN-FD-1xy-<city>-fd-dish-localization.md
```

---

## 11. Відношення до інших FD/PD

* DOMAIN-FD-001 — рамка;
* DOMAIN-FD-002 — атоми (інгредієнти/нутрієнти);
* **DOMAIN-FD-003 — як ці атоми збираються в страви/варіанти/групи**;
* DOMAIN-FD-004 — як страви потрапляють у меню;
* DOMAIN-FD-005/HL — як з цього ліпляться health/diet-констрайнти;
* PD-001/005/017 — DSL, токени, data-платформа.

Цей документ — центральний для будь-якої логіки **«що саме людина отримала в тарілці/чашці»** на рівні канонічних даних.
