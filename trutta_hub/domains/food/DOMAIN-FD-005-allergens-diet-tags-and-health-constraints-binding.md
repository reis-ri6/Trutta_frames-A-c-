# DOMAIN-FD-005 — Allergens, Diet Tags & Health Constraints Binding

**ID:** DOMAIN-FD-005  
**Назва:** Allergens, Diet Tags & Health Constraints Binding  
**Статус:** draft  
**Власники:** product (food/health), data, clinical/health advisor, compliance  
**Повʼязані документи:**  
- DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview  
- DOMAIN-FD-002 — Ingredients & Nutrient Profiles  
- DOMAIN-FD-003 — Dishes, Recipes & Aggregation Rules  
- DOMAIN-FD-004 — Menus & Menu Items Model  
- DOMAIN-HL-*** — Health & Diet Constraints Model  
- PD-001 — Product DSL Blueprint  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint

---

## 1. Purpose

Фіксує **як Trutta маркує їжу алергенами, дієтичними тегами й health-лейблами**:

- словники `AllergenTag` та `DietTag`;
- лінк між FD (інгредієнти/страви/меню) та DOMAIN-HL (абстрактні health-констрайнти);
- правила присвоєння тегів (rule-based, vendor-declared, curated, ML/агенти);
- мінімальні гарантії якості для health-/program use case’ів.

---

## 2. Scope

### 2.1. Входить

- концепти:
  - `AllergenTag`, `DietTag`, `HealthConstraintRef`;
- модель:
  - як ці теги зберігаються та привʼязуються до:
    - `Ingredient`, `Dish`, `DishVariant`, `MenuItem`;
- правила:
  - пріоритетів (інгредієнт → страва → меню);
  - взаємодії з DOMAIN-HL;
  - консистентності.

### 2.2. Не входить

- медичні протоколи/рекомендації (DOMAIN-HL);
- персональні health-профілі (PD-011, окремий user-domain);
- UX/візуалізація (VG-4xx).

---

## 3. Conceptual модель тегів

### 3.1. AllergenTag

Канонічний тег алергену.

- `AllergenTag`:
  - `code`:
    - `gluten`, `nuts`, `peanuts`, `soy`, `egg`, `fish`, `shellfish`, `lupin`, `sesame`, `milk`, `mustard`, `celery`, `sulphites`, …;
  - `name`;
  - `description`;
  - `severity_hint` (high/medium/low — для пріоритизації, не медична оцінка);
  - `regime` (EU_14, US_FDA, local_extra, …).

### 3.2. DietTag

Канонічний тег дієтичної/харчової приналежності.

- `DietTag`:
  - `code`:
    - `vegan`, `vegetarian`, `pescetarian`, `halal`, `kosher`,  
      `gluten_free`, `lactose_free`,  
      `kidney_friendly`, `diabetes_friendly`,  
      `low_sodium`, `low_potassium`, `low_phosphorus`,  
      `high_fiber`, `high_protein`, …
  - `name`;
  - `description`;
  - `category`:
    - `ethical`, `religious`, `allergen_avoidance`, `clinical_abstract`;
  - `hl_constraint_refs[]`:
    - посилання на DOMAIN-HL (наприклад, діапазони натрію/калію).

### 3.3. HealthConstraintRef

Abstraction-level посилання на health-констрайнт (із DOMAIN-HL).

- `HealthConstraintRef`:
  - `code`:
    - `HL:low-sodium-tier-1`, `HL:low-potassium-tier-2`, …;
  - `source`:
    - `domain-hl:clinical-protocol-vX.Y`;
  - `description_short`.

У FD ми **не описуємо**, що саме значить `low-sodium-tier-1` у ммоль/добу — це в DOMAIN-HL.  
FD лише посилається.

---

## 4. Where tags live in FD

### 4.1. Ingredient

- `Ingredient.allergen_tags[]` — **джерело істини** для structural алергенів;
- `Ingredient.diet_tags[]` — базова сумісність (наприклад, `vegan_compatible`).

Правила:

- якщо інгредієнт містить алерген → тег **обовʼязковий**;
- інгредієнт може мати позитивні або негативні diet-теги (через HL).

### 4.2. Dish

- `Dish.allergen_tags[]` — агрегат:
  - union алергенів інгредієнтів;
- `Dish.diet_tags[]`:
  - агрегат + / −:
    - якщо всі інгредієнти vegan-compatible → `vegan`/`vegetarian`;
    - якщо є мʼясо → `non_vegetarian`;
    - health-теги через DOMAIN-HL (на основі нутрієнтів, DOMAIN-FD-002/003).

### 4.3. DishVariant

- `DishVariant` може:
  - додати/прибрати інгредієнти;
  - відповідно змінювати `diet_tags`/`allergen_tags` через `*_delta`.

### 4.4. MenuItem

- `MenuItem.diet_tags[]`, `MenuItem.allergen_tags[]`:
  - за замовчуванням наслідують від `Dish`/`DishVariant`;
  - можуть:
    - **звузити** (`vegan` → `vegetarian`; забрати тег, якщо локальний варіант інший);
    - **додати** UX-лейбли (`chef_healthy_choice` з привʼязкою до HL).

---

## 5. Data model (reference & binding)

### 5.1. Reference tables

У canonical:

- `reference.allergen_tags`
- `reference.diet_tags`

**reference.allergen_tags**

- `code` PK  
- `name`  
- `description`  
- `severity_hint`  
- `regime`  
- `metadata` (jsonb)  

**reference.diet_tags**

- `code` PK  
- `name`  
- `description`  
- `category`  
- `hl_constraint_refs` (jsonb)  

### 5.2. Binding tables (якщо не зберігаємо в jsonb)

Опційно (якщо потрібна нормалізація):

- `fd_ingredient_allergen_tags`
- `fd_ingredient_diet_tags`
- `fd_dish_allergen_tags`
- `fd_dish_diet_tags`
- `fd_menu_item_allergen_tags`
- `fd_menu_item_diet_tags`

У базовому варіанті в canonical-таблицях:

- `allergen_tags` та `diet_tags` — масиви `code`.

---

## 6. Tag assignment rules

### 6.1. Allergen flow

1. **Reference → Ingredient:**

   - мапимо alergen-словник під локальні стандарти (EU_14, US_FDA, etc.);
   - для кожного інгредієнта:
     - вручну/через tooling позначаємо `allergen_tags`.

2. **Ingredient → Dish:**

   - автоматично:  
     `Dish.allergen_tags = union(allergen_tags інгредієнтів)`  
   - опційно:
     - додаткова валідація (chefs / nutritionists).

3. **Dish/DishVariant → MenuItem:**

   - за замовчуванням:
     - `MenuItem.allergen_tags = Dish/DishVariant.allergen_tags`;
   - локальні override-и:
     - якщо готують **без** певного інгредієнта:
       - можна явно прибрати тег, але тільки якщо це відображено в рецептурі/варіанті.

### 6.2. Diet-tag flow (high level)

1. **Ingredient level:**

   - тегуємо базову сумісність:
     - `vegan_compatible`, `vegetarian_compatible`,  
       `contains_meat`, `contains_fish`, `contains_alcohol`, …

2. **Dish level:**

   - rule-based engine:

     - якщо всі інгредієнти `vegan_compatible` & немає `contains_animal_derived`:
       - `Dish.diet_tags += ["vegan", "vegetarian"]`;
     - якщо містить мʼясо:
       - `Dish.diet_tags += ["non_vegetarian"]`;
     - якщо нутрієнти в межах профілю HL:
       - `Dish.diet_tags += ["low_sodium"]` тощо;
       - `Dish.health_constraint_refs += ["HL:low-sodium-tier-1"]`.

3. **DishVariant/MenuItem:**

   - застосовуємо ті самі правила після модифікацій порцій/інгредієнтів;
   - локальні override-и:
     - наприклад, етичні/релігійні сертифікації (halal/kosher) на рівні сервіс-поінта.

---

## 7. FD ↔ DOMAIN-HL

### 7.1. Layering

- FD знає:
  - **що в страві** (інгредієнти, нутрієнти, алергени, diet_tags, HL refs);
- DOMAIN-HL знає:
  - **що дозволено** для конкретних абстрактних health-профілів.

FD обмежується:

- `diet_tags` та `health_constraint_refs` **без привʼязки до конкретної людини**.

### 7.2. Contract

- `DietTag.hl_constraint_refs`:
  - показує, які health-констрайнти цей тег задовольняє/передбачає;
- `Dish.health_constraint_refs`:
  - перелік HL-констрайнтів, які страва не порушує або прямо таргетує.

Приклад:

```yaml
 diet_tags:
   - "kidney_friendly"
 health_constraint_refs:
   - "HL:ckd-stage3-potassium-tier-2"
   - "HL:ckd-stage3-sodium-tier-1"
```

Звідси:

* клінічна логіка → DOMAIN-HL;
* FD — тільки маркування.

---

## 8. Tokens / Programs / UX

### 8.1. Token scopes

Токени можуть посилатись на diet/allergen контекст:

```yaml
 token_type: "kidney_friendly_meal_token"
 entitlement:
   scope:
     diet_tags: ["kidney_friendly"]
   excluded_allergens: ["nuts", "shellfish"]
```

FD забезпечує:

* що ці теги **канонічні й консистентні** для Dish/MenuItem.

### 8.2. Programs (PD-014)

Програми:

* «healthy school lunches», «heart-friendly menu», «CKD-моделі»:

  * задають у DSL:

    * які `diet_tags`/`health_constraint_refs` **мають бути обовʼязкові**;
    * які алергени **мають бути виключені**;
  * FD дає набір страв/позицій, які проходять ці фільтри.

### 8.3. UX / TJM / ABC

* **TJM (PD-006):**

  * на окремих стадіях подорожі можна пропонувати:

    * тільки `vegan`/`healthy` опції;
* **ABC (PD-007):**

  * спільноти можуть формувати попит:

    * «cheap vegan dinners без nuts»;
* **UX:**

  * виводить маркери:

    * `contains nuts`, `gluten free`, `kidney-friendly` — з FD-гарантіями.

---

## 9. Quality / governance

### 9.1. Ownership

* Food/health product:

  * бізнес-логіка тегів;
* Data:

  * consistency/ETL;
* Clinical advisor / HL team:

  * які diet_tags / HL refs допустимі;
* Compliance:

  * відповідність локальним законам (маркування алергенів).

### 9.2. Quality metrics

* % інгредієнтів з валідними `allergen_tags`;
* % страв:

  * з агрегованими `allergen_tags`;
  * з валідними `diet_tags`;
* колізії:

  * страва з тегом `vegan`, але в інгредієнтах є `milk`/`egg`;
* consistency між містами/вендорами:

  * одна й та сама canonical `Dish` має однаковий базовий набір тегів.

---

## 10. Repos & layout

У `trutta_hub`:

```txt
 docs/domain/
   DOMAIN-FD-001-food-and-menu-domain-overview.md
   DOMAIN-FD-002-ingredients-and-nutrient-profiles.md
   DOMAIN-FD-003-dishes-recipes-and-aggregation-rules.md
   DOMAIN-FD-004-menus-and-menu-items-model.md
   DOMAIN-FD-005-allergens-diet-tags-and-health-constraints-binding.md

 data/reference/fd/
   allergens/
     allergen_tags.yaml
   diet_tags/
     diet_tags.yaml
   mappings/
     ingredient_allergen_mapping_rules.yaml
     diet_tag_derivation_rules.yaml
```

У city/project-репах:

```txt
 data/fd/
   local_allergen_overrides.yaml
   local_diet_tag_overrides.yaml
 docs/domain/
   DOMAIN-FD-1xy-<city>-fd-allergens-and-diet-tags-localization.md
```

---

## 11. Відношення до інших FD/PD

* DOMAIN-FD-002 — визначає нутрієнти;
* DOMAIN-FD-003 — визначає страви/порції;
* DOMAIN-FD-004 — ставить страви в меню;
* **DOMAIN-FD-005 — каже, як усе це маркувати алергенами, дієтами й health-refs**.

Далі:

* DOMAIN-HL-*** деталізує медичні моделі;
* PD-005/014/016 будують токени, програми та аналітику на базі цих тегів.

Цей документ — канонічний місток між **«що в тарілці»** і **«для кого це безпечно/рекомендовано в абстрактних health-термінах»**, без заходу на персональні медичні дані.

```
::contentReference[oaicite:0]{index=0}
```
