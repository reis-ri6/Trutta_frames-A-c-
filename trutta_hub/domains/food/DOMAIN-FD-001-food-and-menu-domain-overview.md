# DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview

**ID:** DOMAIN-FD-001  
**Назва:** Food, Dishes & Menus Domain Overview  
**Статус:** draft  
**Власники:** data, arch, product (food/health), analytics  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Concepts & Glossary  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint  
- PD-018 — Integrations & External Ecosystem Model  
- DOMAIN-HL-*** — Health & Diet Constraints (буде)  
- DOMAIN-SV-*** — Services & Service Points (буде)

---

## 1. Purpose

Цей документ описує **канонічний домен їжі, страв та меню (Food Domain, FD)**:

- які сутності існують (Dish, Ingredient, Menu, MenuItem, NutrientProfile тощо);
- як вони звʼязані між собою;
- як FD взаємодіє з:
  - Product DSL (PD-001),
  - токенами типу meal/food (PD-005),
  - health/diet constraints (DOMAIN-HL),
  - сервісними точками/вендорами (DOMAIN-SV),
  - TJM (коли/де відбувається споживання).

Мета — мати **єдину нормалізовану модель їжі**, яку:

- використовують всі міста/вендори/проекти;
- може переварити інжест із різних джерел (меню, рецептури, FDA/ін. таблиці);
- можуть безпечно використовувати health-/аналітичні сценарії без PII.

---

## 2. Scope

### 2.1. Що входить

- **Їжа як домен**:
  - інгредієнти;
  - страви/рецептури;
  - меню та позиції меню;
  - нутрієнтні профілі й агрегати.
- **Звʼязок їжі з сервісом**:
  - які страви доступні в яких сервіс-поінтах/меню;
  - варіанти порцій, модифікатори.
- **Звʼязок їжі з health/diet**:
  - алергени;
  - абстрактні дієтичні профілі;
  - лінки на нутрієнтні довідники (FDA/локальні).
- **Binding до DSL/Token**:
  - як із доменних сутностей збираються DSL-продукти й токени.

### 2.2. Що НЕ входить

- процес приготування як технологічна карта кухні (це окремий виробничий/кулінарний домен, якщо знадобиться);
- внутрішній облік складу/складів/закупівель;
- персональні медичні рекомендації (ліве на DOMAIN-HL + PD-011, лише агрегатні моделі);
- UX-копі/фото/брендінг (йдуть у VG-4xx контентний шар).

---

## 3. Ключові сутності (conceptual рівень)

> Це логічна модель. Фізичні таблиці/граф/DSL-файли — в PD-017 + schemas/db.

### 3.1. Ingredient

Базова «атомарна» сутність їжі.

- `Ingredient`:
  - `ingredient_id` (canonical);
  - `name` (canonical/локалізований);
  - `category` (зернові, мʼясо, овочі, спеції, напої тощо);
  - `allergen_tags[]` (gluten, nuts, lactose, shellfish, ...);
  - `nutrient_profile_id` (звʼязок з нутрієнтами);
  - `source_refs[]` (FDA code, local DB code, vendor source, …).

### 3.2. NutrientProfile

Агрегований набір нутрієнтів (загалом на 100 g / 100 ml / «unit»).

- `NutrientProfile`:
  - `nutrient_profile_id`;
  - `base_unit` (g/ml/unit);
  - перелік нутрієнтів:
    - `kcal`, `protein_g`, `fat_g`, `carbs_g`, `sugar_g`, `fiber_g`, `salt_g`, `…`;
  - джерело:
    - `source` (FDA / EU / локальна база / лабораторія);
    - `confidence_level`.

Може привʼязуватись як:

- до `Ingredient`;
- до `Dish` (агрегований із інгредієнтів) — опційно, якщо треба зберігати precomputed.

### 3.3. Dish

Логічна страва (незалежна від конкретного меню/ціни).

- `Dish`:
  - `dish_id` (canonical);
  - `name`, `alt_names[]` (локальні назви, синоніми);
  - `description_short`, `description_long`;
  - `dish_category` (суп, основна, десерт, напій, снек тощо);
  - `ingredients[]`:
    - `ingredient_id`, `quantity`, `unit` (якщо відома рецептура);
  - `baseline_portion` (типова порція в g/ml);
  - `diet_tags[]` (vegan, vegetarian, halal, kosher, low_sodium, low_potassium, …);
  - `allergen_tags[]` (агрегат із інгредієнтів);
  - `nutrient_profile_id` (агрегований або посилання на обчислення).

### 3.4. Recipe (опційна деталізація)

Якщо потрібен глибокий рівень:

- `Recipe`:
  - `recipe_id`;
  - `dish_id`;
  - `steps[]` (текстові/структуровані кроки);
  - `yield_portions`;
  - `yield_per_portion_g/ml`.

### 3.5. Menu

Меню як набір доступних позицій у певному сервіс-поінті / програмі.

- `Menu`:
  - `menu_id`;
  - `type` (main, breakfast, room-service, kids, daily-special, hospital-ward, …);
  - `owner_type` (service_point / program / virtual);
  - `owner_id` (звʼязок на `ServicePoint` чи програму);
  - `valid_from`, `valid_to`;
  - `time_of_day_constraints[]` (breakfast/lunch/dinner/night).

### 3.6. MenuItem

Конкретна позиція меню.

- `MenuItem`:
  - `menu_item_id`;
  - `menu_id`;
  - `dish_id` (звʼязок з canonical Dish);
  - `display_name` (те, як бачить гість; може відрізнятися від canonical `Dish.name`);
  - `portion_size` (g/ml/unit);
  - `price` (може бути null, якщо це суто токен/програма);
  - `currency`;
  - `available_modes[]` (dine_in, take_away, delivery, room_service, hospital_bed);
  - `variants[]` (small/medium/large, extra shots, milk type, side-dish опції);
  - `diet_tags[]`, `allergen_tags[]` (можуть перевизначати/звужувати canonical).

### 3.7. MenuProgramBinding / ProgramMeal

Звʼязок меню з програмами/субсидіями.

- `ProgramMeal`:
  - `program_meal_id`;
  - `program_id` (PD-014);
  - `menu_item_id` або `dish_id`;
  - `entitlement_type` (повністю покривається / часткова компенсація / пакет);
  - `max_per_period` (раз на день/тиждень/місяць).

---

## 4. Логічні шари даних у FD

### 4.1. Raw → Canonical → Local

1. **Raw layer (PD-017)**:
   - сирі меню/рецепти з:
     - PDF/Excel/Google Sheets;
     - API вендорів/екосистем;
     - нутрієнтні таблиці (FDA/локальні).

2. **Canonical FD layer**:
   - нормалізовані:
     - `canonical.ingredients`;
     - `canonical.dishes`;
     - `canonical.nutrient_profiles`;
     - `canonical.menus` (або окремо для hub/city);
   - global `ingredient_id`/`dish_id`.

3. **Local (city/vendor) overrides**:
   - aliases, локальні назви/фото/ціни;
   - локальні відхилення в рецептурі/складі.

### 4.2. Entity matching

- `Ingredient`/`Dish` з різних джерел мапляться:
  - за назвою, нутрієнтами, категоріями, джерелами;
  - процес описаний у VG-8xx (ETL/quality) і окремих DOMAIN-FD-*.

---

## 5. FD ↔ Product DSL / Tokens

### 5.1. DSL Product Binding

У DSL (PD-001/003):

- `product.manifest.yaml` для food:

```yaml
product_id: "FD:vienna:coffee-latte-small"
kind: "food_item"
source:
  dish_id: "dish:coffee-latte"
  menu_item_id: "menuitem:xyz" # опціонально
portion_size:
  amount: 250
  unit: "ml"
diet_tags: ["vegetarian"]
constraints_ref:
  - "constraints/time/breakfast-only.yaml"
  - "constraints/health/low-sodium-tier-1.yaml"
```

FD виступає **джерелом truth** для:

* `dish_id`/`menu_item_id`;
* порцій/нутрієнтів.

### 5.2. Token Types

У PD-005:

* токени типу `meal_token`, `coffee_token`, `hospital_meal_token` мають:

  * посилання на FD:

    * або через `dish_category` (будь-яка кава до 250 ml);
    * або через конкретні `dish_id`/`menu_item_id`.

Це дозволяє:

* будувати токени «1 будь-яка веганська страва з цього меню» без жорсткого хардкоду конкретних позицій.

---

## 6. FD ↔ Health & Diet (DOMAIN-HL)

FD не містить PII/персональних health-даних. Він:

* описує **страви/інгредієнти/нутрієнти**;
* маркує їх абстрактними **diet_tags** і **HealthConstraintRef**.

Приклад:

* `Dish` або `MenuItem` мають:

```yaml
diet_tags: ["kidney-friendly", "low-potassium"]
health_constraints_refs:
  - "HL:low-potassium-tier-2"
  - "HL:low-sodium-tier-1"
```

DOMAIN-HL визначає:

* що таке `low-potassium-tier-2` у цифрах;
* які профілі пацієнтів можуть його споживати.

FD лише **маркує** їжу цими ярликами.

---

## 7. FD ↔ Services & City (DOMAIN-SV, DOMAIN-CT)

### 7.1. Звʼязок із сервісними точками

Через DOMAIN-SV:

* `ServicePoint` (кафе, ресторан, лікарня, готельна кухня …) має:

  * `service_point_id`;
  * `menu_ids[]` (доступні меню).

Menu:

* `owner_type = service_point` + `owner_id = service_point_id`.

### 7.2. Звʼязок із city-graph

Через DOMAIN-CT:

* `ServicePoint` має:

  * `zone_id`, `route_ids[]`, координати;
* це дозволяє:

  * шукати страви в контексті маршрутів/кластерів:

    * «веган сніданки в межах 10 хв від готелю»;
    * «kidney-friendly страви в радіусі 2 км».

---

## 8. FD ↔ TJM / ABC / Programs

### 8.1. TJM (Travel Journey)

У PD-006:

* кроки подорожі (pre-trip, in-flight, in-hotel, in-city, post-trip);
* FD дозволяє привʼязати:

  * меню до стадій (сніданки в готелі, dinner у місті);
  * конкретні страви до micro-journeys (coffee route, gastro route).

Binding:

* DSL / TJM Binding файл:

```yaml
journey_binding:
  applies_to:
    dish_categories: ["coffee", "breakfast"]
  tjm_stages: ["in-city", "in-hotel"]
  zones: ["inner-city-1"]
```

### 8.2. ABC (Anonymous Buyers Community)

Через PD-007:

* групи/сегменти можуть:

  * формувати спільний попит на типи страв:

    * «cheap lunch», «vegan dinners», «kidney-friendly packs»;
  * брати участь у спільних програмах.

FD дає:

* нормалізовані категорії/теги;
* можливість будувати пули попиту не «по назвах у чеку», а по canonical Dish/Ingredient/Tag.

### 8.3. Programs & subsidies

Через PD-014:

* програми можуть працювати з:

  * `dish_category` (кожен день одна гаряча страва);
  * `diet_tag` (тільки healthy/kidney-friendly);
  * `menu_id`/`service_point_id` (обмеження по точках).

FD — центральний домен для опису **що саме фактично зʼїв/отримав користувач**.

---

## 9. Аналітика в FD

Через PD-016:

* події типу:

  * `trutta.token.entitlement_redeemed` із FD-контекстом:

    * `dish_id`, `dish_category`, `diet_tags[]`;
  * `trutta.vendor.menu_updated`:

    * кількість змін, нові страви, зміни нутрієнтів.

Ключові метрики:

* споживання за:

  * категоріями;
  * diet_tags/health-constraints;
  * програмами/зонами/вендорами.

FD-defines:

* як агрегувати;
* як уникати дублювання (одна страва під різними назвами).

---

## 10. Repos & файловий layout

У `trutta_hub`:

```txt
docs/domain/
  DOMAIN-FD-001-food-and-menu-domain-overview.md
  DOMAIN-FD-0xx-*.md              # деталізація FD (ingredients, allergens, menus, recipes, nutrition)
schemas/db/
  canonical/fd_*.dbml             # фізичні схеми FD у canonical БД
  warehouse/fd_*.dbml             # аналітичні таблиці по FD
data/
  reference/fd/nutrients/...
  reference/fd/allergens/...
  reference/fd/diet_tags/...
```

У city/project-репах:

```txt
data/fd/
  menus_raw/...
  menus_canonical_overrides/...
docs/domain/
  DOMAIN-FD-1xx-<city>-fd-localization.md
  DOMAIN-FD-1xy-<project>-fd-programs-binding.md
```

---

## 11. Подальші DOMAIN-FD документи

Цей док — **оглядовий**. Далі:

* `DOMAIN-FD-002-ingredients-and-nutrient-profiles.md`
* `DOMAIN-FD-003-dishes-recipes-and-aggregation-rules.md`
* `DOMAIN-FD-004-menus-and-menu-items-model.md`
* `DOMAIN-FD-005-allergens-diet-tags-and-health-constraints-binding.md`
* `DOMAIN-FD-006-fd-ingestion-and-normalization-patterns.md`
* `DOMAIN-FD-007-fd-analytics-and-quality-metrics.md`

DOMAIN-FD-001 задає «рамку», в межах якої всі наступні FD-документи деталізують модель, але не суперечать їй.
Якщо якась пропозиція ламає цю модель — вона або оновлює DOMAIN-FD-001 через RFC, або відхиляється.
