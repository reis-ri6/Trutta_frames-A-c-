# DOMAIN-FD-002 — Ingredients & Nutrient Profiles

**ID:** DOMAIN-FD-002  
**Назва:** Ingredients & Nutrient Profiles  
**Статус:** draft  
**Власники:** data, arch, product (food/health), analytics  
**Повʼязані документи:**  
- DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview  
- PD-001 — Product DSL Blueprint  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint  
- PD-018 — Integrations & External Ecosystem Model  
- DOMAIN-HL-*** — Health & Diet Constraints (коли буде)

---

## 1. Purpose

Формалізувати **інгредієнти й нутрієнтні профілі**:

- canonical-модель `Ingredient`, `NutrientProfile`, `NutrientDefinition`;
- маппінг на зовнішні джерела (FDA/локальні довідники);
- правила агрегації нутрієнтів для страв;
- базові quality-правила.

Це база для:

- health-/diet-лейблів;
- програм харчування (в т.ч. медичних/соціальних);
- аналітики по нутрієнтах.

---

## 2. Scope

### 2.1. Входить

- логічна модель:
  - інгредієнтів;
  - нутрієнтних профілів;
  - довідника нутрієнтів;
- правила:
  - одиниць виміру;
  - конвертацій;
  - агрегації по страві/порції;
- ingestion з довідників (FDA/локальні).

### 2.2. Не входить

- детальні рецептури й технологічні карти (це в DOMAIN-FD-003);
- персональні медичні рекомендації (DOMAIN-HL + PD-011);
- UI/лейаут відображення нутрієнтів (VG-4xx).

---

## 3. Conceptual модель

### 3.1. NutrientDefinition

Довідник типів нутрієнтів.

- `NutrientDefinition`:
  - `nutrient_code` (canonical, короткий ID, напр. `energy_kcal`, `protein_g`);
  - `name` (людинозрозуміла назва);
  - `unit` (g, mg, μg, kcal, kJ, IU, …);
  - `category` (macro, vitamin, mineral, other);
  - `is_primary` (чи показуємо в «короткій» картці);
  - `source_refs[]` (FDA code, EU code, локальні).

### 3.2. NutrientProfile

Набір значень нутрієнтів для інгредієнта/страви.

- `NutrientProfile`:
  - `nutrient_profile_id`;
  - `base_amount` (число);
  - `base_unit` (g/ml/unit);
  - `source` (fda / eu / local_table / lab / vendor_declared);
  - `confidence_level` (0–1 або low/medium/high);
  - `values[]`:
    - `nutrient_code`;
    - `amount_per_base_unit` (float);
    - опціонально:
      - `source_amount_raw`;
      - `source_unit`.

Профіль може бути:

- *прямий* (з довідника);
- *агрегований* (обчислений з інгредієнтів).

### 3.3. Ingredient

Як у DOMAIN-FD-001, але точніше.

- `Ingredient`:
  - `ingredient_id` (canonical);
  - `canonical_name`;
  - `alt_names[]` (локальні назви, мови, синоніми);
  - `category` (grain, meat, veg, fruit, dairy, fat/oil, sweetener, beverage, other);
  - `nutrient_profile_id`;
  - `allergen_tags[]` (nut, gluten, lactose, egg, soy, fish, shellfish, …);
  - `diet_tags[]` (vegan-compatible, vegetarian-compatible, …);
  - `source_refs[]`:
    - `source`, `external_id`.

---

## 4. Data model (logical → db)

### 4.1. Таблиці canonical (логіка)

У canonical-шарі (PD-017):

- `canonical.nutrient_definitions`
- `canonical.nutrient_profiles`
- `canonical.nutrient_profile_values`
- `canonical.ingredients`

**canonical.nutrient_definitions**

- `nutrient_code` PK  
- `name`  
- `unit`  
- `category`  
- `is_primary`  
- `source_refs` (jsonb)

**canonical.nutrient_profiles**

- `nutrient_profile_id` PK  
- `base_amount`  
- `base_unit`  
- `source`  
- `confidence_level`  
- `created_at`, `updated_at`

**canonical.nutrient_profile_values**

- `nutrient_profile_id` FK  
- `nutrient_code` FK  
- `amount_per_base_unit`  
- (опц.) `source_amount_raw`, `source_unit`

**canonical.ingredients**

- `ingredient_id` PK  
- `canonical_name`  
- `lang_default`  
- `category`  
- `nutrient_profile_id` FK  
- `allergen_tags` (jsonb/array)  
- `diet_tags` (jsonb/array)  
- `source_refs` (jsonb)

Локалізація назв:

- окрема таблиця `canonical.ingredient_localized_names` або generic `localized_labels`.

---

## 5. Джерела даних (reference)

### 5.1. Типи джерел

- глобальні нутрієнтні таблиці (FDA, EU, ін.);
- локальні довідники країн/міст;
- лабораторні виміри партнерів;
- декларації вендорів (низький рівень довіри).

### 5.2. Mapping layer

Для кожного джерела:

- мапимо:

  - code нутрієнта → `nutrient_code`;
  - одиниці → canonical unit;

- оформлюємо в `data/reference/fd/nutrients/<source>/mapping.yaml`.

Приклад:

```yaml
source: "fda"
nutrient_mapping:
  "208": "energy_kcal"
  "203": "protein_g"
  "204": "fat_g"
  "205": "carbs_g"
unit_mapping:
  "g": "g"
  "kcal": "kcal"
  "mg": "mg"
```

---

## 6. Агрегація нутрієнтів

### 6.1. Ingredient → Dish

У DOMAIN-FD-003 деталізується, тут — базове правило:

Для порції страви:

* беремо рецепт:

  * інгредієнти з кількостями `q_i` (в g/ml/unit);
* для кожного інгредієнта:

  * від масштабуємо його профіль до `q_i`;
* сумуємо по нутрієнт-кодах;
* результат → `Dish.nutrient_profile_id` (агрегований).

Формула:

```
amount_dish(nutrient_code) =
  Σ_i ( amount_profile_i(nutrient_code) * (q_i / base_amount_i) )
```

Результат округляємо й нормуємо за внутрішніми правилами (VG-?).

### 6.2. Dish → MenuItem → Portion

Якщо `MenuItem` має іншу порцію, ніж `Dish.baseline_portion`:

```
amount_menu_item(nutrient_code) =
  amount_dish(nutrient_code) * (portion_size / baseline_portion)
```

---

## 7. Health/ Diet binding (без PII)

FD дає лише **технічний профіль їжі**.

Лейбли типу:

* `low_sodium`, `low_potassium`, `high_fiber`, `diabetes_friendly` тощо

присвоюються:

* або в процесі нормалізації (агент + правила з DOMAIN-HL);
* або вручну/напів-автоматично (через tooling).

Приклад (схематично):

```yaml
diet_tags:
  - "kidney-friendly"
health_constraints_refs:
  - "HL:low-potassium-tier-2"
  - "HL:low-sodium-tier-1"
```

Алгоритм присвоєння — в DOMAIN-HL, FD лише тримає результат.

---

## 8. Ingestion & normalization

### 8.1. Nutrient tables

Пайплайн (PD-017 / ingestion/):

1. **landing**:

   * кладе raw-таблиці у `raw/fd/<source>/nutrients/...`;
2. **parsing**:

   * приводить до проміжного формату:

     * `external_food_id`, `nutrient_id`, `amount`, `unit`;
3. **mapping**:

   * через `mapping.yaml` → `nutrient_code`, canonical unit;
4. **profile-building**:

   * для кожного `external_food_id` створюється/оновлюється `NutrientProfile`;
5. **ingredient-linking**:

   * або склеюється з existing `Ingredient`;
   * або створюється новий `Ingredient`-candidate.

### 8.2. Ingredients lists (vendor / recipes)

* парсимо списки інгредієнтів (текстові/структуровані);
* робимо entity resolution до canonical `Ingredient`:

  * лінгвістика + маппінг + ручні override-и;
* якщо не знайшли — створюємо `ingredient_candidate` з `nutrient_profile_id = null`:

  * окремий тулінг для доповнення профілю.

---

## 9. Quality & anomalies

Базові перевірки:

* **Completeness**:

  * % інгредієнтів із заповненим `nutrient_profile_id`;
  * % нутрієнтів по primary-категоріях, які присутні в профілі.

* **Consistency**:

  * калорії ≈ розрахунок із макросів (груба перевірка);
  * діапазони значень в межах очікуваних (outlier detection).

* **Source priority**:

  * якщо є кілька джерел:

    * вибираємо профіль із highest confidence;
    * зберігаємо інші як альтернативні (для аналізу).

Реалізація метрик — у VG-8xx/9xx, тут — лише модель.

---

## 10. Repos & файловий layout

У `trutta_hub`:

```txt
docs/domain/
  DOMAIN-FD-001-food-and-menu-domain-overview.md
  DOMAIN-FD-002-ingredients-and-nutrient-profiles.md

schemas/db/
  canonical/fd_ingredients.dbml
  canonical/fd_nutrients.dbml
  warehouse/fd_nutrients_agg.dbml

data/reference/fd/
  nutrients/
    global/
      nutrient_definitions.yaml
      nutrient_unit_mapping.yaml
    fda/
      mapping.yaml
      samples.md
    <local_source>/
      mapping.yaml
  allergens/
    allergen_tags.yaml
  diet_tags/
    diet_tags.yaml
```

У city/project-репах:

```txt
data/fd/
  ingredients_local_overrides.yaml
  nutrient_overrides.yaml   # локальні лабораторні дані
docs/domain/
  DOMAIN-FD-1xx-<city>-fd-ingredient-localization.md
```

---

## 11. Відношення до інших FD/PD

* DOMAIN-FD-001 — задає frame; DOMAIN-FD-002 її конкретизує на шарі інгредієнтів/нутрієнтів.
* DOMAIN-FD-003 — поверх цієї моделі описує страви/рецепти/агрегації.
* DOMAIN-FD-005 — описує, як із нутрієнтів/алергенів формуються diet-/health-лейбли.
* PD-017 — каже, де це живе технічно (canonical/warehouse/vector/graph).
* PD-014/HL — спираються на FD для health-/program логіки.

DOMAIN-FD-002 є **канонічним описом того, як Trutta розуміє «з чого зроблена їжа» і які в неї нутрієнтні властивості**.

```
::contentReference[oaicite:0]{index=0}
```
