# DOMAIN-FD-004 — Menus & Menu Items Model

**ID:** DOMAIN-FD-004  
**Назва:** Menus & Menu Items Model  
**Статус:** draft  
**Власники:** product (food/hospitality/health), data, arch, analytics  
**Повʼязані документи:**  
- DOMAIN-FD-001 — Food, Dishes & Menus Domain Overview  
- DOMAIN-FD-002 — Ingredients & Nutrient Profiles  
- DOMAIN-FD-003 — Dishes, Recipes & Aggregation Rules  
- PD-001 — Product DSL Blueprint  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-013 — Vendor & Service Network Model  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-015 — UX, Channels & Experience Model  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint

---

## 1. Purpose

Цей документ формалізує **канонічну модель меню**:

- як Trutta описує меню й позиції меню (`Menu`, `MenuItem`);
- як меню привʼязуються до сервіс-поінтів, програм, часу доби;
- як працюють варіанти, модифікатори, канали (dine-in, delivery, room-service, hospital);
- як із цього живляться DSL-продукти й токени.

---

## 2. Scope

### 2.1. Входить

- концепти:
  - `Menu`, `MenuItem`, `MenuSection`, `MenuMode`, `MenuAvailability`;
- звʼязок із:
  - `Dish`/`DishVariant` (DOMAIN-FD-003);
  - `ServicePoint` (DOMAIN-SV);
  - програмами/субсидіями (PD-014);
  - TJM/ABC (PD-006/007);
- базові правила версіонування й локалізації меню.

### 2.2. Не входить

- схеми UI/рендер меню (VG-4xx);
- конкретні формати інжесту (PDF/Excel/API) — це в DOMAIN-FD-006;
- внутрішній бек-офіс вендора (ownerʼs POS/PMS).

---

## 3. Conceptual модель

### 3.1. Menu

Меню = набір позицій, привʼязаний до **власника** й **контексту**.

- `Menu`:
  - `menu_id` (canonical);
  - `owner_type`:
    - `service_point` / `program` / `virtual` (наприклад, city-wide gastro pass);
  - `owner_id`:
    - `service_point_id` (кафе/готель/лікарня, DOMAIN-SV);
    - `program_id` (PD-014);
  - `menu_kind`:
    - `core`, `breakfast`, `lunch`, `dinner`, `kids`, `daily_special`, `hospital_ward`, `room_service`, `bar`, `buffet`, …;
  - `channel_modes[]`:
    - `dine_in`, `take_away`, `delivery`, `room_service`, `hospital_bed`, …;
  - `validity`:
    - `valid_from`, `valid_to` (дата/час, може бути `null` для open-ended);
    - `days_of_week[]` (Mon–Sun);
    - `time_of_day_windows[]` (набір вікон `from`–`to`);
  - `currency` (дефолтна для цін у меню);
  - `status`:
    - `draft`, `active`, `archived`;
  - `version` / `menu_version_group_id` (для історії змін).

### 3.2. MenuSection

Логічні групи всередині меню (для структури й токенів).

- `MenuSection`:
  - `menu_section_id`;
  - `menu_id`;
  - `label` (локалізований заголовок — «Сніданки», «Гарячі страви», …);
  - `sort_order`;
  - `section_tags[]` (наприклад, `kids`, `vegan_corner`, `healthy`, `kidney_friendly`).

### 3.3. MenuItem

Позиція меню = **Dish/Variant + контекст + ціна + канали**.

- `MenuItem`:
  - `menu_item_id`;
  - `menu_id`;
  - `menu_section_id` (nullable);
  - `dish_id` (FK → `Dish`);
  - `dish_variant_id` (FK → `DishVariant`, nullable);
  - `display_name` (те, як бачить гість; може відрізнятися від `Dish.canonical_name`);
  - `display_description` (локалізований опис для UX);
  - `portion_size_amount` (g/ml/unit; може відрізнятися від baseline);
  - `portion_size_unit`;
  - `price` (nullable, якщо це чисто entitlement/програма);
  - `currency` (override або `Menu.currency`);
  - `available_modes[]`:
    - subset `Menu.channel_modes[]` (наприклад лише `dine_in`+`take_away`);
  - `diet_tags[]`, `allergen_tags[]` (override/звуження від `Dish`);
  - `labels[]` (UX-лейбли: `chef_special`, `new`, `popular`, `token_only`, …);
  - `status`:
    - `active`, `hidden`, `deprecated`.

### 3.4. MenuItemOptions / Modifiers (спрощено)

Окремий шар опцій:

- `MenuItemOptionGroup`:
  - **наприклад:** вибір типу молока, гарніру, додаткових інгредієнтів.

Мінімальна модель:

- `MenuItemOptionGroup`:
  - `option_group_id`;
  - `menu_item_id`;
  - `label`;
  - `selection_type` (`single`, `multiple`);
  - `min_choices`, `max_choices`.

- `MenuItemOption`:
  - `option_id`;
  - `option_group_id`;
  - `label`;
  - `price_delta` (може бути 0);
  - `linked_ingredient_id` або `linked_dish_variant_id` (опц., для нутрієнтів);
  - `diet_tags_delta`, `allergen_tags_delta`.

---

## 4. Data model (canonical layer)

У canonical (PD-017):

- `canonical.menus`
- `canonical.menu_sections`
- `canonical.menu_items`
- `canonical.menu_item_option_groups`
- `canonical.menu_item_options`

Схеми спрощено:

**canonical.menus**

- `menu_id` PK  
- `owner_type`  
- `owner_id`  
- `menu_kind`  
- `channel_modes` (jsonb)  
- `valid_from`, `valid_to`  
- `days_of_week` (jsonb)  
- `time_of_day_windows` (jsonb)  
- `currency`  
- `status`  
- `version`  
- `menu_version_group_id`  
- timestamps  

**canonical.menu_sections**

- `menu_section_id` PK  
- `menu_id` FK  
- `label`  
- `sort_order`  
- `section_tags` (jsonb)  

**canonical.menu_items**

- `menu_item_id` PK  
- `menu_id` FK  
- `menu_section_id` FK (nullable)  
- `dish_id` FK  
- `dish_variant_id` FK (nullable)  
- `display_name`  
- `display_description`  
- `portion_size_amount`  
- `portion_size_unit`  
- `price` (nullable)  
- `currency`  
- `available_modes` (jsonb)  
- `diet_tags` (jsonb)  
- `allergen_tags` (jsonb)  
- `labels` (jsonb)  
- `status`  
- timestamps  

**canonical.menu_item_option_groups**

- `option_group_id` PK  
- `menu_item_id` FK  
- `label`  
- `selection_type`  
- `min_choices`  
- `max_choices`  

**canonical.menu_item_options**

- `option_id` PK  
- `option_group_id` FK  
- `label`  
- `price_delta`  
- `linked_ingredient_id` (nullable)  
- `linked_dish_variant_id` (nullable)  
- `diet_tags_delta` (jsonb)  
- `allergen_tags_delta` (jsonb)  

---

## 5. Меню в різних контекстах

### 5.1. Hospitality / HoReCa

- `owner_type = service_point` (кафе, ресторан, готельний ресторан);
- стандартні `menu_kind`:
  - `breakfast`, `lunch`, `dinner`, `à_la_carte`, `bar`, `kids`, `room_service`.

### 5.2. Health / Hospitals

- `owner_type = service_point` (лік., відділення) **або** `program` (дієтична програма);
- типові `menu_kind`:
  - `hospital_ward_standard`, `hospital_ward_kidney`, `hospital_ward_diabetes`, …
- сильна привʼязка до DOMAIN-HL:
  - `diet_tags`, `health_constraints_refs`.

### 5.3. Programs / Subsidies / Sospeso

- `owner_type = program`;
- `menu_kind`:
  - `subsidized_menu`, `token_only_menu`, `community_menu`;
- `MenuItem.price` може бути `null` (чи = reference price), а реальна економіка йде через PD-014/токени.

---

## 6. DSL / Tokens / TJM / ABC

### 6.1. DSL Product binding

DSL-чекає на `dish_id` / `menu_item_id`:

```yaml
product_id: "FD:vienna:hotelX:breakfast-buffet-plate"
kind: "food_item"
source:
  menu_item_id: "menuitem:hotelX:buffet-plate"
```

Або — група через `menu_section_id` чи `menu_id` + criteria.

### 6.2. Token binding

Приклади:

1. **Simple meal token**:

```yaml
token_type: "meal_token"
entitlement:
  scope:
    menu_id: "menu:vienna:hotelX:breakfast"
```

2. **Vegan lunch token**:

```yaml
token_type: "meal_token"
entitlement:
  scope:
    menu_id: "menu:vienna:hotelX:lunch"
  filters:
    diet_tags: ["vegan"]
    max_price: 15.0
```

3. **City coffee pass**:

```yaml
token_type: "coffee_pass"
entitlement:
  scope:
    dish_category: ["coffee"]
    menu_kinds: ["bar", "cafe_main"]
  city_zone_ids: ["inner-1", "inner-2"]
```

Меню = ключовий шар, через який DSL/Token накладаються на реальні пропозиції.

### 6.3. TJM

Для TJM (PD-006):

* `Menu` + `MenuItem` позначаються **binding-ом до стадій подорожі**:

```yaml
tjm_binding:
  stages: ["in-hotel"]
  events_closed: ["need_breakfast"]
  events_opened: ["after_breakfast_ready_for_city"]
```

Звʼязок може жити:

* або в окремих binding-файлах (DSL-level);
* або як метадані меню/секцій/позицій (для швидкого доступу).

### 6.4. ABC

Для ABC (PD-007):

* спільноти оперують пулями попиту в термінах:

  * `menu_kind` (cheap lunch / coffee route);
  * `diet_tags` (`vegan`, `kidney_friendly`);
  * `price`/`zone`.

FD-меню дають нормалізований просвіт: що реально доступно під цими параметрами.

---

## 7. Версіонування меню

### 7.1. Version groups

Мінімальна модель:

* `menu_version_group_id`:

  * логічно однакове меню (наприклад, «Breakfast menu Hotel X»);
* кожна зміна ≈ новий `menu_id` з тим же `menu_version_group_id` + інкремент версії.

Для даних/аналітики:

* можна відновити стан меню на дату `t`:

  * «які були опції, коли користувач редемпив токен».

### 7.2. Minor vs major change

* **Minor**:

  * корекція описів, цін, незначні правки позицій;
* **Major**:

  * зміна структури, секцій, суттєве розширення/скоротення;
  * може вимагати оновлення повʼязаних DSL/Token-конфігів.

---

## 8. Аналітика / quality

На базі меню:

* події:

  * `menu_published`, `menu_item_added`, `menu_item_removed`, `menu_item_price_changed`;
* метрики:

  * coverage:

    * % страв, які мають валідний `dish_id`/`dish_variant_id`;
    * % позицій із заповненими `diet_tags`/`allergen_tags`;
  * program coverage:

    * скільки позицій в меню покривається токенами/програмами;
  * city coverage:

    * diversity страв/дієт у різних зонах.

Реалізація → PD-016 + DOMAIN-FD-007.

---

## 9. Repos & layout

У `trutta_hub`:

```txt
docs/domain/
  DOMAIN-FD-001-food-and-menu-domain-overview.md
  DOMAIN-FD-002-ingredients-and-nutrient-profiles.md
  DOMAIN-FD-003-dishes-recipes-and-aggregation-rules.md
  DOMAIN-FD-004-menus-and-menu-items-model.md

schemas/db/
  canonical/fd_menus.dbml
  canonical/fd_menu_sections.dbml
  canonical/fd_menu_items.dbml
  canonical/fd_menu_item_options.dbml
```

У city/project-репах:

```txt
data/fd/
  menus_raw/...
  menus_canonical_overrides.yaml
docs/domain/
  DOMAIN-FD-1xx-<city>-fd-menus-localization.md
```

---

## 10. Відношення до інших FD/PD

* DOMAIN-FD-002/003 — відповідають «що це за їжа» (інгредієнти, страви).
* **DOMAIN-FD-004 — «як ця їжа представлена в конкретному місці/контексті як меню»**.
* PD-001/005 — будують DSL-продукти/токени поверх `Menu`/`MenuItem`.
* PD-013/014/015/016 — використовують меню для вендорської логіки, програм, UX та аналітики.

DOMAIN-FD-004 — канонічний спосіб думати про меню в Trutta, незалежно від того, чи це кафе в центрі Відня, лікарняна дієта чи community-меню Sospeso.

```
::contentReference[oaicite:0]{index=0}
