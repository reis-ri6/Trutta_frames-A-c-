# PD-017 — Trutta Data Platform & Knowledge Graph Blueprint

**ID:** PD-017  
**Назва:** Trutta Data Platform & Knowledge Graph Blueprint  
**Статус:** draft  
**Власники:** arch, data, analytics, eng  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-008 — Trutta Agent & Automation Layer  
- PD-009 — Trutta City & Project Instantiation Model  
- PD-010 — Repositories & Documentation Conventions  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-012 — Runtime & Service Architecture (High-level)  
- PD-013 — Vendor & Service Network Model  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-015 — UX, Channels & Experience Model  
- PD-016 — Analytics, Events & Measurement Model  
- VG-8xx — Data Infrastructure / ETL / Storage / RLS  
- VG-9xx — Analytics / Dashboards

---

## 1. Purpose

Цей документ задає **каркас Data Platform & Knowledge Graph** для Trutta:

- які є **data planes** та сховища;
- як вони підтримують:
  - промислові домени (PD-004),
  - DSL (PD-001/003),
  - TJM/ABC (PD-006/007),
  - токени (PD-005),
  - Vendor Network (PD-013),
  - програми/субсидії (PD-014),
  - аналітику/агентів (PD-016/PD-008);
- як будуються:
  - canonical-дані,
  - knowledge graph,
  - векторні індекси.

Мета — щоб **будь-яке місто/проєкт** розгорталось поверх однієї зрозумілої data-платформи, а не набору ad-hoc БД.

---

## 2. Scope

### 2.1. Входить

- логічні **шари даних** (raw → canonical → analytics → feature/AI/graph);
- базові типи сховищ (OLTP, OLAP, KV, vector, graph);
- модель **knowledge graph** та звʼязок з доменами;
- інтеграція з runtime (PD-012), аналітикою (PD-016) та агентами (PD-008).

### 2.2. Не входить

- вибір конкретних технологій (Postgres/ClickHouse/BigQuery/Neo4j/…);
- детальні схеми таблиць (DOMAIN + schemas/db);
- конкретні ETL-пайплайни (VG-8xx).

---

## 3. Data planes

### 3.1. Overview

Data Platform ділиться на **площини**:

1. **Operational / OLTP Plane**  
   - runtime-сервіси (PD-012);
   - транзакції токенів, journeys, ABC-стан, vendor-ops.

2. **Raw / Landing Plane**  
   - зовнішні джерела:
     - OTA, maps, OSM, Yelp/Google Places;
     - меню, нутрієнтні бази (FDA, локальні);
     - open data від міст/NGO;
   - мінімальна обробка, тільки нормалізація формату.

3. **Canonical Plane**  
   - нормалізовані доменні сутності (PD-004/PD-013):
     - Hotels, ServicePoints, Menus, Dishes, Ingredients, HealthConstraints, City/Zone/Route;
   - глобальні IDs, консистентність між містами/проєктами.

4. **Analytics / Warehouse Plane**  
   - події (PD-016), агрегати, метрики;
   - UE/програми/вендори/міста.

5. **Feature / ML Plane**  
   - підготовлені фічі для моделей:
     - рекомендації місць/маршрутів;
     - scoring vendor/програм/health-friendly опцій;
   - не обовʼязково окреме сховище, але окремий контур.

6. **AI / Knowledge Plane**  
   - knowledge graph;
   - векторні індекси (документи, entity-кластери, TJM-маршрути);
   - RAG-шар для агентів (PD-008).

---

## 4. Core storages (логічно)

### 4.1. Operational Store

- OLTP БД(и) для:
  - token-runtime;
  - journey-engine;
  - ABC;
  - vendor network;
  - program/funding.

Вимоги:

- ACID для критичних операцій;
- RLS/ABAC (PD-011);
- multi-tenant (PD-009/PD-012).

### 4.2. Raw / Staging Store

- object storage (файли, dumps, API-інкременти);
- схема:

  - `raw/<source>/<entity>/<date>/…`

Правило:

- нічого не «масажувати» на вході, крім явної технічної нормалізації (формати, інкапсуляція).

### 4.3. Canonical Store

- узгоджені таблиці/колекції:

  - `canonical.hotels`,
  - `canonical.service_points`,
  - `canonical.menus`,
  - `canonical.dishes`,
  - `canonical.ingredients`,
  - `canonical.health_constraints`,
  - `canonical.cities/zones/routes`,
  - `canonical.vendors/networks`.

Мапиться на DOMAIN-документи (PD-004, PD-013).

### 4.4. Warehouse / Analytics Store

- схеми під аналітику (див. PD-016):
  - `events.*` (події);
  - `facts.*` (transactions/redemptions);
  - `dims.*` (cities, programs, vendors, segments, token_types);
- сюди стікаються:

  - runtime-events;
  - агрегати з canonical/operational.

### 4.5. Vector Store

- індекси:

  - `vec.docs` — документація, PD/VG/DOMAIN, city-content;
  - `vec.entities` — embeddings сутностей (сервайси, місця, страви, програми);
  - `vec.journeys` — TJM-templates, patterns.

Використовується агентами:

- для semantic search;
- для рекомендацій/навігації.

### 4.6. Knowledge Graph Store

- граф сутностей і звʼязків (див. розд. 6):

  - вузли: City, Zone, ServicePoint, Hotel, Route, Dish, Ingredient, Program, TokenType, ABC-Segment, JourneyPattern;
  - ребра: «розташований у», «подає», «відповідає health-профілю», «включений у програму», «зʼєднаний маршрутом», «затребуваний сегментом».

---

## 5. IDs & глобальна адресація

### 5.1. Canonical IDs

Кожна сутність, що потрапляє в canonical/graph, має:

- глобальний `canonical_id` (тип + namespace + локальний id);
- `source_ids[]` — посилання на джерела:
  - OTA_id, Maps_id, internal_city_id тощо.

Приклад:

```yaml
canonical_id: "svcpoint:vienna:SP-00123"
source_ids:
  - source: "google_places"
    id: "ChIJN1t_tDeuEmsRUsoyG83frY4"
  - source: "city_registry"
    id: "W-12345"
```

### 5.2. ID policy

* одна сутність = один canonical_id;
* merge та split-сценарії описуються в DOMAIN/VG-доках:

  * хто/як вирішує колізії.

---

## 6. Knowledge Graph Model

### 6.1. Node types (прикладний мінімум)

* `City`, `Zone`, `Route`, `Cluster`;
* `Vendor`, `ServicePoint`, `Network`;
* `Hotel`, `RoomType`;
* `Dish`, `Ingredient`, `Menu`, `Cuisine`;
* `HealthConstraint`, `DietProfile` (абстрактні, без PII);
* `Program`, `FundingPool`, `Campaign`;
* `TokenType`, `TokenArchetype`;
* `TJMStage`, `TJMStep`, `JourneyPattern`;
* `ABCSegment`, `DemandPool`, `Group`.

### 6.2. Edge types

* географія:

  * `City` → `Zone`, `Zone` → `ServicePoint`;
* операційні:

  * `Vendor` → `ServicePoint`;
  * `ServicePoint` → `Menu` → `Dish` → `Ingredient`;
* health:

  * `Dish` → `HealthConstraint` (via нутрієнтні профілі);
* програми:

  * `Program` → `FundingPool` → `TokenType`;
  * `Program` → `ServicePoint` (eligible участь);
* TJM:

  * `JourneyPattern` → `TJMStep`;
  * `TJMStep` → `ServicePoint` / `Route` / `Program`;
* ABC:

  * `ABCSegment` → `DemandPool` → `Program`/`TokenType`.

### 6.3. Graph usage

* для агентів:

  * пошук «найкоротного» або «найкращого» шляху:

    * між аватаром/TJM-етапом і релевантними сервісами/токенами;
  * відповіді на складні питання:

    * «які програми дають здорове харчування у цій зоні для такого профілю?».

* для аналітики:

  * структурування coverage;
  * виявлення «дір» (міста/зони/категорії без покриття).

---

## 7. Ingestion & normalization patterns

### 7.1. External data ingestion

Sources:

* Maps/POI;
* OTA/booking;
* меню (файли, API);
* нутрієнтні бази (FDA/локальні);
* city open data.

Патерн:

1. **Landing в raw** (`raw/<source>/…`);
2. **Source-normalization**:

   * базові поля, timestamps, гео;
3. **Entity-matching**:

   * мапа на canonical-id;
4. **Domain-normalization**:

   * приведення до DOMAIN-моделей (PD-004/PD-013).

### 7.2. Runtime → warehouse

* events (PD-016) — єдине джерело behavior;
* snapshot-таблиці з OLTP (token balances, journeys, ABC-state).

ETL/ELT:

* інкрементальний;
* data contracts між сервісами та data-платформою.

---

## 8. AI / Agents integration

### 8.1. Data access for agents

Агенти (PD-008):

* **не ходять напряму в OLTP**;
* працюють через:

  * `data-api` (read-only endpoints до canonical/warehouse/graph);
  * `search-api` (vector/graph + filters).

Базові режими:

* `semantic_docs` — PD/VG/DOMAIN/міський контент;
* `semantic_entities` — ServicePoints, маршрути, страви, програми;
* `graph_queries` — шлях/сусіди/кластеризація;
* `analytics_queries` — агрегації по подіях/фактам.

### 8.2. Guardrails

* застосовуються політики PD-011:

  * жодного PII/health-raw в агентах загального призначення;
* специфічні health-/legal-/city-агенти:

  * мають окремі правила доступу (в маніфестах `.agent.yaml`).

---

## 9. Multitenancy: hub/city/project у Data Platform

### 9.1. Логічні ключі

У всіх шарах:

* `tenant_id`, `city_id`, `project_id`, `brand_id` (де релевантно).

Моделі:

* **shared schema, tenant key**:

  * одна БД, multi-tenant таблички з RLS;
* або **separate schema per city/project**:

  * але з однаковими DOMAIN-/PD-конвенціями.

### 9.2. Hub vs City vs Project

* Hub:

  * зберігає **еталонні словники** + тестові/демо-дані;
* City:

  * свої ServicePoints/Vendors/Routes/Programs;
* Project:

  * свої Program/Campaign-конфіги, аналітику, ABC-конструкції.

---

## 10. Data quality, lineage, governance

### 10.1. Data quality

Ключові показники:

* completeness (набір обовʼязкових полів);
* consistency (без колізій у canonical-id);
* freshness (оновлення maps/OTA/меню/health-даних);
* accuracy (перевірка проти ground truth, де є).

### 10.2. Lineage

* для основних таблиць:

  * опис походження в `data-lineage.yaml`:

    * джерела, ETL-джоби, залежності;
* в ідеалі — автоматично згенерована lineage-діаграма.

### 10.3. Governance

Ролі:

* `data_owner` — відповідальний за конкретний домен (food, hospitality, health, city);
* `data_steward` — операційний контроль якості;
* `data_engineer` — ETL/інфра;
* `analytics` — валідація метрик і запитів.

---

## 11. Repositories & docs

У `trutta_hub`:

```txt
docs/pd/
  PD-017-trutta-data-platform-and-knowledge-graph-blueprint.md

docs/domain/
  DOMAIN-*-*.md             # домен-моделі
docs/vg/
  VG-8xx-data-platform-*.md # конкретні стек/архітектура/ETL-патерни
schemas/db/
  canonical/*.dbml
  warehouse/*.dbml
  graph/*.md | *.schema
```

У city/project-репах:

```txt
data/
  canonical-overrides/...
  warehouse-views/...
  graph-overrides/...

docs/vg/
  VG-8xx-<city>-data-model.md
  VG-8xx-<project>-data-model.md
```

---

## 12. Відношення до інших PD

* PD-004 — каже «які» індустріальні шари й домени існують.
* PD-017 — каже «як» їх реалізувати на data-платформі й у графі.
* PD-012 — runtime-сервіси; PD-017 — як їх дані осідають і повʼязуються.
* PD-016 — events/метрики; PD-017 — куди це все лягає й як стає доступним агентам.

PD-017 фіксує, що **Trutta — це не тільки токени/UX, а повноцінна міська data/knowledge-платформа**, на яку можуть опиратись і travel-продукти, і міські програми, і медичні/соціальні кейси.
