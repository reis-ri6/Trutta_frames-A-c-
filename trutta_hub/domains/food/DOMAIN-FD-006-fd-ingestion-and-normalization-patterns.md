# DOMAIN-FD-006 — FD Ingestion & Normalization Patterns

**ID:** DOMAIN-FD-006  
**Назва:** FD Ingestion & Normalization Patterns  
**Статус:** draft  
**Власники:** data, arch, infra, analytics  
**Повʼязані документи:**  
- DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview  
- DOMAIN-FD-002 — Ingredients & Nutrient Profiles  
- DOMAIN-FD-003 — Dishes, Recipes & Aggregation Rules  
- DOMAIN-FD-004 — Menus & Menu Items Model  
- DOMAIN-FD-005 — Allergens, Diet Tags & Health Constraints Binding  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint  
- PD-018 — Integrations & External Ecosystem Model

---

## 1. Purpose

Зафіксувати **патерни інжесту й нормалізації FD-даних**:

- які джерела ми тягнемо (меню, рецепти, нутрієнтні таблиці);
- які шари даних (`raw` → `staging` → `canonical` → `warehouse`);
- як робимо entity resolution:
  - ingredients, dishes, menu items;
- які правила якості й контроль.

Це не «конкретні пайплайни в Airflow/DBT», а **контракт для їх проєктування**.

---

## 2. Scope

### 2.1. Входить

- ingestion:
  - reference-дані (FDA/локальні нутрієнти, allergens, diet-tags);
  - vendor/city меню;
  - рецептури (коли доступні);
- normalization:
  - mapping до canonical FD-моделі (DOMAIN-FD-001…005);
  - entity resolution;
  - quality-check-и.

### 2.2. Не входить

- повні data-platform деталі (в PD-017);
- user-level events/consumption (це вже runtime);
- UI/інтерфейси завантаження (окремі VG/інтеграційні доки).

---

## 3. Джерела даних

### 3.1. Reference sources

- нутрієнтні таблиці:
  - FDA;
  - EU / локальні державні реєстри;
  - клінічні довідники (для HL);
- allergen/diet словники:
  - стандарти (EU_14, US_FDA, локальні);
  - внутрішні розширення (diet-tags, HL-refs).

### 3.2. Vendor / City sources

- меню:
  - файли (PDF/Excel/CSV/Google Sheets);
  - API (OTA/POS/PMS/вендорські);
  - ручний ввід через tooling;
- рецептури:
  - технологічні карти (якщо доступні);
  - спрощені списки інгредієнтів.

### 3.3. Program / health sources

- програмні меню (школи, лікарні, соціальні програми);
- клінічні/дієтичні шаблони (абстрактні, без PII).

---

## 4. Data layers (FD-specific view)

### 4.1. Raw layer

Призначення: **мінімально оброблена копія** вмісту джерел.

Приклади:

- `raw_fd_reference_nutrients_<source>`:
  - «як прийшло» з FDA/локальної таблиці;
- `raw_fd_menu_<source>`:
  - сирий експорт меню;
- `raw_fd_recipe_<source>`:
  - сирі рецептури.

Правила:

- змінюємо тільки для технічної сумісності (типи колонок);
- не чистимо/не нормалізуємо;
- зберігаємо source-metadata (timestamp, file hash, endpoint, версії).

### 4.2. Staging layer

Призначення: **привести дані до уніфікованого проміжного формату**.

- `stg_fd_reference_nutrients_<source>`:
  - `external_food_id`, `external_nutrient_id`, `amount`, `unit`, `lang`, metadata;
- `stg_fd_menu_<source>`:
  - `external_menu_id`, `external_item_id`, `raw_name`, `raw_description`, `raw_price`, `raw_section`, …
- `stg_fd_recipe_<source>`:
  - `external_recipe_id`, `external_food_id`, `ingredient_text`, `parsed_ingredient_id`, `quantity_raw`, `unit_raw`, …

На цьому шарі:

- парсимо текстові поля в базові колонки;
- розбиваємо списки інгредієнтів;
- але ще **не** мапимо на canonical IDs.

### 4.3. Canonical FD layer

Призначення: **єдина truth-модель для FD** (див. DOMAIN-FD-001…005):

- `canonical.ingredients`
- `canonical.nutrient_profiles`
- `canonical.dishes`
- `canonical.menus`, `canonical.menu_items`  
та інші.

Інжест на цьому шарі:

- створення/оновлення canonical-ентіті;
- entity resolution;
- обчислення агрегованих нутрієнтів/тегів.

### 4.4. Warehouse / analytics

Призначення: **зручні таблиці для звітів/ML**.

Приклади:

- `wh_fd_dish_nutrition_daily_snapshot`  
- `wh_fd_menu_coverage_by_city`  
- `wh_fd_program_health_compliance`  

Структура визначається PD-016 + DOMAIN-FD-007.

---

## 5. Entity resolution (ER)

### 5.1. Ingredients

Задача: `raw/stg` → `canonical.ingredients`.

Кроки:

1. **Standardization**:
   - нормалізуємо назви (lowercase, trim, без брендів/форматів «™», …);
2. **Blocking**:
   - приблизний пошук по:
     - normalized name,
     - category,
     - нутрієнтному профілю (якщо є);
3. **Matching**:
   - rule-based + ML:
     - exact/near-exact match → auto-link;
     - ambiguous → candidate list + ручний/агентний review;
4. **Creation**:
   - якщо не знайдено match із достатньою confidence:
     - створюємо `Ingredient` з прапорцем `is_candidate = true`.

Всі рішення трекаються:

- `fd_ingredient_match_log` з:
  - source, external_id, matched_ingredient_id, method, confidence.

### 5.2. Dishes

Задача: `raw/stg menus/recipes` → `canonical.dishes`.

- якщо є явний mapping (від вендора/інтеграції) → використовуємо;
- інакше:

  1. нормалізуємо назву страви;
  2. використовуємо:
     - name;
     - ingredients list;
     - category/section;
     - іноді price pattern;
  3. поведінка аналогічна інгредієнтам:
     - auto-match, candidate-list, creation.

### 5.3. Menu items

Меню — більш «локальна» сущність:

- `MenuItem` завжди створюється для кожного `external_item_id`;
- звʼязуємо з canonical `Dish`/`DishVariant` через ER (вище);
- зберігаємо:

  - `source_item_name`, `source_section`, `source_price` для аудиту.

---

## 6. Normalization rules (high-level)

### 6.1. Units & measures

- нутрієнти → standard units (g, mg, μg, kcal) згідно reference-мепінгів;
- ваги/обʼєми:
  - `g`, `ml`, `kg`, `l` → нормалізуємо;
- порції:
  - якщо джерело дає «1 piece» → звʼязуємо з базовою масою (або зберігаємо як unit).

### 6.2. Currencies & prices

- нормалізуємо в локальну валюту міста/сервіс-поінта;
- зберігаємо source-currency + курс конвертації;
- для аналітики виділяємо «reference_price» (без знижок/купонів, якщо можливо).

### 6.3. Languages & labels

- назви/описи зберігаються з `lang` (`en`, `de`, `uk`, …);
- canonical має дефолтну мову + локалізації.

---

## 7. Quality & validation

### 7.1. Structural checks

На `staging`:

- обовʼязкові поля не пусті;
- типи даних валідні;
- дублікати (`external_*_id`) в рамках джерела не допускаються або логуються.

### 7.2. Semantic checks

На переході `staging` → `canonical`:

- нутрієнти:
  - калорії приблизно відповідають макросам;
  - no negative values;
- алергени:
  - consistency: не може бути `gluten_free`, якщо є ingredient з `gluten`;
- дієтичні теги:
  - не може бути `vegan` з `milk`/`egg`/`meat`.

### 7.3. Source trust levels

Кожне джерело має `trust_level`:

- `high` (офіційні довідники, лабораторії);
- `medium` (вендорські таблиці, перевірені партнери);
- `low` (угаданий/автоматичний парсинг без підтвердження).

При конфліктах:

- higher trust level має пріоритет;
- альтернативні значення зберігаються в окремих таблицях як history/alt profiles.

---

## 8. Агенти та автоматизація

### 8.1. FD-specific agents

Мінімальний набір:

- `fd-ingestion-agent`:
  - стежить за новими файлами/API;
  - запускає пайплайни `raw` → `staging`;
  - логування статусів.

- `fd-er-agent` (entity resolution):
  - пропонує match’і для ingredients/dishes;
  - формує candidate-списки;
  - може автоприймати match при високому confidence.

- `fd-quality-agent`:
  - гоняє правила якості;
  - формує звіти по аномаліях.

### 8.2. Interaction з global ingestion

Загальний ingestion-шар (описаний у PD-017 / ingestion/README.md) бачить FD як:

- набір пайплайнів:
  - `fd_reference_ingest`;
  - `fd_menu_ingest`;
  - `fd_recipe_ingest`.

FD-документи задають **domain-specific** правила, але технічний рантайм — спільний.

---

## 9. Безпека та privacy

FD інжест:

- працює з **продуктовими даними**, не з PII;
- health-/diet дані — **абстрактні** (через теги/констрайнти);
- будь-які user-level consumption-івенти — в окремому домені (PD-011).

Треба:

- сегментація сховища:
  - FD-таблиці окремо від user/PII;
- ACL/RLS:
  - технічні юзери FD не мають доступу до персональних health-профілів.

---

## 10. Repos & configs

У `trutta_hub`:

```txt
docs/domain/
  DOMAIN-FD-001-food-and-menu-domain-overview.md
  DOMAIN-FD-002-ingredients-and-nutrient-profiles.md
  DOMAIN-FD-003-dishes-recipes-and-aggregation-rules.md
  DOMAIN-FD-004-menus-and-menu-items-model.md
  DOMAIN-FD-005-allergens-diet-tags-and-health-constraints-binding.md
  DOMAIN-FD-006-fd-ingestion-and-normalization-patterns.md

ingestion/fd/
  README.md                    # короткий опис пайплайнів FD
  pipelines.yaml               # декларації пайплайнів FD
  mappings/
    nutrients/
      fda.yaml
      eu.yaml
      <local_source>.yaml
    menus/
      <source>.yaml
  rules/
    er_ingredients.yaml
    er_dishes.yaml
    normalization.yaml
  quality/
    checks_fd.yaml
    thresholds_fd.yaml
```

У city/project-репах:

```txt
data/fd/source_configs.yaml       # які джерела підключені по місту
ingestion/fd/local_overrides.yaml # локальні правила мепінгу/ER
```

---

## 11. Відношення до інших FD/PD

* DOMAIN-FD-001…005 описують **логіку моделі** FD;
* **DOMAIN-FD-006 описує, як реальний хаос джерел приводиться до цієї моделі**:

  * шари даних;
  * ER;
  * quality;
  * агенти.

Далі:

* DOMAIN-FD-007 сфокусується на аналітичних метриках/quality KPI для FD;
* PD-017 визначає загальний технічний стек і реалізацію пайплайнів.

```
::contentReference[oaicite:0]{index=0}
```
