# PD-004 — Industrial Data & Knowledge Layers

**ID:** PD-004  
**Назва:** Industrial Data & Knowledge Layers for Trutta  
**Статус:** draft  
**Власники:** arch, data, product  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- DOMAIN-* — доменні моделі (tourism, hospitality, services, food, health, city)  
- VG-8xx — Data Pipelines & Storage  
- VG-9xx — Analytics & Metrics

---

## 1. Purpose

Цей документ задає **єдину модель шарів даних та знань** у Trutta для індустрій:

- tourism / travel / hospitality;
- services (кафе, ресторани, лікарні, сервіси);
- food & recipes;
- health-constraints;
- city & logistics.

Мета:

- чітко розділити **шари даних** (raw → canonical → аналітика → AI/knowledge);
- зафіксувати **де живе яка правда**;
- показати, як це все підживлює **DSL**, **токенізацію** і **TJM/ABC**.

---

## 2. Scope

У фокусі:

- логічні шари даних;
- базові директорії й registry;
- звʼязок із DSL та доменами.

Не входить:

- фізичний дизайн конкретної БД (це `schemas/db/*` + VG-8xx);
- конкретні ETL-джоби (це runbooks VG-8xx).

---

## 3. Layer Model

### 3.1. Логічні шари

1. **Raw Layer**  
   - все, що прийшло «як є» з зовнішніх джерел;  
   - мінімальні трансформації (timestamp, source-id).

2. **Reference Layer**  
   - стабільні довідники:  
     - FDA tables, офіційні нутрієнтні дані;  
     - класифікатори міст, країн, валют;  
     - класифікатори health-constraints.

3. **Canonical Layer**  
   - нормалізовані сутності Trutta:  
     - `Hotel`, `ServicePoint`, `Dish`, `Ingredient`, `HealthConstraint`, `City`, `Zone`, `Route`, `Vendor` тощо;  
   - одна «істина» на сутність.

4. **Analytical Layer**  
   - агрегати, витрати, usage-профілі:  
     - `vendor_stats`, `city_pass_usage`, `meal_redemption_patterns`, `health_profile_coverage`.

5. **AI / Knowledge Layer**  
   - векторні індекси, графи, distilled knowledge:  
     - city-graph, service-graph, dish-graph;  
     - embedding-и описів, маршрутів, відгуків.

### 3.2. Директорна схема (логічна)

```txt
data/
  raw/
    tourism/
    hospitality/
    services/
    food/
    health/
    city/
  reference/
    fda/
    iso-codes/
    health-constraints/
  canonical/
    tourism/
    hospitality/
    services/
    food/
    health/
    city/
  analytics/
    vendor/
    city/
    product/
  ai/
    vectors/
    graphs/
    models/
```

---

## 4. Industrial Domains & Registries

### 4.1. Tourism & Hospitality

Основні сутності:

* `Trip`, `Segment`, `Itinerary`, `Stay`;
* `Hotel`, `RoomType`, `Amenity`, `Reservation`.

Джерела:

* OTA (Expedia/Booking/інші),
* власні інтеграції готелів,
* ручний онбординг.

Canonical registry:

* `data/canonical/tourism/*`, `data/canonical/hospitality/*`;
* доменні схеми: `domains/tourism/*`, `domains/hospitality/*`, `schemas/db/*`.

### 4.2. Services (кафе, ресторани, лікарні, інші сервіси)

Сутності:

* `ServicePoint` (універсальна модель точки сервісу);
* `Service`, `OpeningHours`, `BookingSlot`.

Джерела:

* Google Places, Yelp, Foursquare, локальні каталоги;
* vendor self-onboarding.

Canonical registry:

* `data/canonical/services/service_points.*`,
* `domains/services/*`.

### 4.3. Food & Recipes

Сутності:

* `Dish`, `Recipe`, `Ingredient`, `Menu`, `Portion`;
* звʼязок з нутрієнтами.

Джерела:

* vendor-меню (CSV/API/скрепінг);
* внутрішня бібліотека рецептів;
* мапінг на FDA-таблиці.

Canonical registry:

* `data/canonical/food/dishes.*`, `ingredients.*`, `menus.*`;
* `domains/food/*`.

### 4.4. Health & Constraints

Сутності:

* `HealthConstraint` (класи обмежень, не персональні дані);
* `DietProfile` (набори constraints).

Джерела:

* FDA/ESFA/ін. офіційні довідники;
* протоколи клінік (у форматі, очищеному від PII);
* внутрішні моделі.

Canonical registry:

* `data/reference/health-constraints/*.yaml`;
* `data/canonical/health/*`;
* `domains/health/*`.

Тверда границя: **жодних персональних медичних даних** у цих шарах. Лише моделі, класи, профілі.

### 4.5. City & Logistics

Сутності:

* `City`, `Zone`, `POI`, `Route`, `Stop`, `TransitOption`.

Джерела:

* OSM, GTFS, міські open-data портали;
* власні city-raids.

Canonical registry:

* `data/canonical/city/*`;
* `domains/city/*`.

---

## 5. External Data Sources & Ingestion

### 5.1. Основні категорії джерел

* **Maps & Places:** Google Places, Yelp, Foursquare, OSM.
* **Hospitality & Tourism:** OTA API dumps, готельні PMS/CRS.
* **Food & Nutrition:** FDA, локальні нутрієнтні бази, vendor-меню.
* **Health Constraints:** офіційні гайдлайни, клінічні протоколи (агреговані).

### 5.2. Data Raids vs Conveyors

* **Data Raid:**
  разовий/серійний забіг по локації/домену:

  * наповнити базову карту (city, service_points, hotels, dishes).
* **Data Conveyor:**
  регулярне оновлення:

  * дельти по vendor-меню;
  * зміни у city/transport;
  * оновлення reference-таблиць (FDA).

Політика: raid створює «seed» canonical-шару, conveyor його підтримує.

---

## 6. Звʼязок Data Layers ↔ DSL

### 6.1. ID & References

* У canonical-рівні кожна сутність має стабільний `id`:

  * `HOTEL-xxxxx`, `SP-xxxxx`, `DISH-xxxxx`, `CITY-xxxxx`, `HC-xxxxx`.
* DSL-файли посилаються **тільки на canonical-ID**, не на «raw IDs».

Приклади:

* `product.manifest.yaml`:

  * `domainRefs[*].ref: "HOTEL-xxxxx"`.
* `token.yaml`:

  * `domainRefs[*].kind: "ServicePoint"`.

### 6.2. Синхронізація

* Ingestion-пайплайни мають:

  * мапити raw → canonical;
  * тримати таблиці відповідностей (source-id ↔ canonical-id).
* AI-/Codex-агенти при генерації DSL:

  * не придумують IDs;
  * або:

    * використовують наявний registry,
    * або створюють таску на створення canonical-сутності.

---

## 7. Data Governance & Quality

### 7.1. Ownership

* Tourism/hospitality data — `data-team + product (travel)`
* Services & food — `data-team + product (local services)`
* Health-constraints — `data-team + medical advisors`
* City & logistics — `data-team + city-ops`

Кожен шар/registry має:

* owner-роль;
* політики оновлення;
* SLO по якості/свіжості.

### 7.2. Quality Signals

Мінімум:

* completeness (% заповнених ключових полів);
* consistency (відсутність конфліктів ID / дубльованих записів);
* freshness (час від останнього оновлення);
* trust score джерела.

---

## 8. AI / Knowledge Layer

### 8.1. Векторні індекси

* окремі індекси для:

  * city-graph (POI, routes, zones),
  * service-graph (service_points, vendors),
  * food-graph (dishes, ingredients, menus).

Вихідні дані — із canonical/analytics шарів.

### 8.2. Graphs

* `city-graph`: вузли — POI/Zone/Route/Stop, ребра — відстань/доступність/звʼязки;
* `service-graph`: vendor ↔ service_point ↔ city/zones;
* `food-graph`: dish ↔ recipe ↔ ingredient ↔ health-constraint.

Графи не дублюють БД — вони **похідні knowledge-представлення**.

---

## 9. Стосунок до інших PD/VG

* PD-001–003 задають DSL та терміни.
* PD-004 фіксує **дані/знання**, які DSL використовує.
* Наступні документи:

  * **DOMAIN-*:** деталізація кожного домену (ER-моделі, таблиці).
  * **PD-00x (DSL↔DB Mapping):** формальний маппінг сутностей на таблиці.
  * **VG-8xx:** конкретні пайплайни, storage, RLS/ABAC.
  * **VG-9xx:** метрики/дашборди на базі canonical/analytics шарів.

Будь-які зміни в бізнес-розумінні доменів мають спочатку відбиватися в PD-004 + DOMAIN-*, а вже потім — у схемах, пайплайнах і DSL.
