# PD-009 — Trutta City & Project Instantiation Model

**ID:** PD-009  
**Назва:** Trutta City & Project Instantiation Model  
**Статус:** draft  
**Власники:** arch, product, data, ops  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-008 — Trutta Agent & Automation Layer  
- VG-8xx — Engineering & Runtime Guides  
- VG-9xx — Analytics & Metrics

---

## 1. Purpose

Цей документ описує **модель інстансів Trutta**:

- як з **канонічного шару** (`trutta_hub`) робляться:
  - city-level інстанси (місто/регіон),
  - project-level інстанси (Sospeso, BREAD, Vienna guide, health-пілоти);
- які є **рівні конфігурації й кастомізації**;
- як розподіляються:
  - DSL-артефакти,
  - індустріальні дані,
  - TJM/ABC-конфігурації,
  - токени.

Мета — мати чітку картину: **що універсальне, що city-specific, що project-specific** і як це все зʼєднується через репозиторії та пайплайни.

---

## 2. Scope

### 2.1. Входить

- логічна модель **трьох рівнів**:

  1. **Core / Hub (canonical)** — `trutta_hub`;
  2. **City Layer** — `trutta_city-*`;
  3. **Project Layer** — `trutta_project-*` (Sospeso, BREAD, vien.geist, тощо);

- правила наслідування/override;
- базова структура репозиторіїв/конфігів.

### 2.2. Не входить

- конкретні репи для міст/проєктів (це окремі PD/VG/project-docs);
- деталі CI/CD (VG-8xx);
- юридичні/компанійні структури.

---

## 3. Three-layer model: Hub → City → Project

### 3.1. Hub Layer (Canonical)

**Hub (Core)** — `trutta_hub`:

- містить **канонічні**:
  - PD-001..PD-00x (концепти, глосарії, токени, TJM, ABC);
  - DOMAIN-* (доменні моделі);
  - DSL-схеми (`schemas/dsl/*`);
  - шаблони (templates) продуктів/міст/проєктів;
- не привʼязаний до конкретного міста чи бренду;
- є **єдиним джерелом правди** для:
  - типів токенів;
  - структур DSL-файлів;
  - глобальних TJM stages/steps;
  - ABC-концептів;
  - індустріальних шарів.

### 3.2. City Layer

**City Layer** — набір інстансів на рівні міста/регіону:

- приклади: `trutta_city-vienna`, `trutta_city-lviv`, `trutta_city-dubai`;
- містить:
  - city-graph (zones, routes, POI, service_points);
  - city-specific TJM micro-journeys;
  - локальні каталоги вендорів/меню;
  - локальні constraints (регуляторика, податки, часові зони).

City Layer **наслідує**:

- структуру й схеми з `trutta_hub`;
- глобальні домени й DSL, але додає локальні інстанси.

### 3.3. Project Layer

**Project Layer** — конкретні продукти/програми:

- приклади:
  - `trutta_project-sospeso-vienna`,
  - `trutta_project-bread-lviv`,
  - `trutta_project-vien.geist`,
  - health-пілот для kidney-friendly travel;
- містить:
  - набір продуктів/оферів/токенів;
  - проектні правила (кампанії, бюджети, ролі);
  - інтеграції із зовнішніми партнерами (гранти, гуманітарні програми, white-label).

Проєкт сидить:

- на 1+ City Layer;
- завжди **поважає** canonical-шар (PD-001..008).

---

## 4. Repository & directory model (логічно)

### 4.1. Hub repo

```txt
trutta_hub/
  docs/pd/...
  docs/domain/...
  dsl/schemas/...
  templates/
    city/
    project/
  data/
    reference/
    canonical/* (глобальні)
  agents/
  progress/
```

### 4.2. City repo (pattern)

```txt
trutta_city-<city>/
  city/
    city-profile.yaml          # основні параметри міста
    zones/*.yaml
    routes/*.route.yaml
    tjm/city-micro-journeys/*.yaml
  vendors/
    service_points/*.yaml
    menus/*.yaml
  dsl/
    products/                  # city-specific продукти
    token-types/               # якщо є city-local token types (мінімум)
  data/
    canonical/city/*
    canonical/services/*
    canonical/food/*
  configs/
    integration/*.yaml         # ключі, ендпоінти, мапінги
  progress/
    status-city-onboarding.yaml
```

### 4.3. Project repo (pattern)

```txt
trutta_project-<name>/
  project/
    profile.yaml               # опис проєкту, owner-и, цілі
    scope.yaml                 # географія, домени
  dsl/
    products/
    offers/
    token-types/
    journey/
    constraints/
  abc/
    segments/*.yaml
    demand_pools/*.yaml
    groups/*.yaml
  ops/
    runbooks/*.md
    playbooks/*.md
  configs/
    trutta-hub-link.yaml       # відсилки до canonical-артефактів
    city-links.yaml            # які city-репи/міста використовує
  progress/
    roadmap.yaml
    artefact-status.yaml
```

---

## 5. Inheritance & override rules

### 5.1. Canonical vs local

Принцип:

* **Hub** визначає **типи й каркаси**;
* **City/Project** працюють лише в рамках цих каркасів.

Правила:

* City/Project **не змінюють** канонічні PD/DOMAIN/схеми;
* якщо потрібно змінити концепт:

  * робиться PR у `trutta_hub` (оновлення PD-001..008);
  * після цього City/Project оновлюють свої конфіги.

### 5.2. Типи override

1. **Pure configuration**
   Проєкт/місто задають значення для вже існуючих схем:

   * продукти з canonical TokenTypes;
   * локальні constraints (час, гео).

2. **Extension**
   Додання локальних сутностей/мікро-journeys/segments:

   * city-specific micro-journeys;
   * project-specific segments/demand pools.

3. **Fork & merge (exceptional)**
   Якщо тимчасово потрібна локальна зміна моделі:

   * створюється локальний PD/DOMAIN-doc з поміткою `local_override: true`;
   * ставиться таска/PR у `trutta_hub` на оновлення канону;
   * після merge canonical-версії локальний override прибирається.

---

## 6. Data & DSL flows між рівнями

### 6.1. Вниз: Hub → City → Project

* **Hub → City**:

  * DSL-схеми, глосарії, токен-архетипи;
  * базові TJM stages/steps;
  * індустріальні доменні моделі.

* **City → Project**:

  * конкретні city-graph-дані (zones, routes, POI, service_points);
  * локальні меню, vendors;
  * micro-journeys.

Проєкт **не тягне** сирі зовнішні джерела напряму, а користується:

* canonical city/service/food/health даними;
* ABC-сегментами, які можуть бути city-scoped.

### 6.2. Вверх: Project → City → Hub

* **Project → City**:

  * usage/analytics (redemptions, flows);
  * локальні продукти/роути, які варто зробити city-standard.

* **Project/City → Hub**:

  * нові патерни:

    * токени,
    * TJM micro-journeys,
    * ABC-сегменти;
  * lessons learned, які переходять у canonical PD/VG.

---

## 7. TJM & ABC at City/Project levels

### 7.1. TJM

* **Hub**:

  * визначає global TJM stages/типи steps;
* **City**:

  * додає city-level micro-journeys (`MJ-VIE-MORNING-COFFEE`);
* **Project**:

  * використовує конкретні micro-journeys і, при потребі, пропонує нові.

### 7.2. ABC

* **Hub**:

  * базові типи сегментів/профілів;
* **City**:

  * city-specific сегменти (наприклад, «Vienna weekenders»);
* **Project**:

  * створює demand pools/groups під свої сценарії.

Всі сегменти/demand pools мають чіткий `city_id`/`project_id` у метаданих.

---

## 8. Token model per layer

### 8.1. Hub tokens

* canonical TokenTypes:

  * base entitlement, bundle, pass, escrow, group token, status;
* максимально chain-agnostic та регуляторно безпечні;
* використовуються як **базові building blocks**.

### 8.2. City tokens

* мінімум власних токенів:

  * city-pass, city-local bundles;
* як правило, компонується з hub TokenTypes,

  * але може додати локальні constraints (local taxes/regulation).

### 8.3. Project tokens

* конкретні продукти:

  * Sospeso tokens,
  * BREAD meal tokens,
  * спеціальні health-friendly bundles;
* мусять бути:

  * маплені на hub/core archetypes (PD-005),
  * описані в DSL (`*.token.yaml`) з чітким `project_id` і посиланням на city.

---

## 9. Agents & pipelines for instantiation

### 9.1. City onboarding pipeline

Типова система (`city-onboarding.system.yaml`):

* читає:

  * canonical PD/DOMAIN з `trutta_hub`;
  * external city data sources;
* створює:

  * `trutta_city-<city>` структуру;
  * initial city-graph / service_points / TJM micro-journeys;
  * initial vendors/menus (якщо є).

### 9.2. Project bootstrapping pipeline

Типова система (`project-bootstrap.system.yaml`):

* використовує:

  * templates із `trutta_hub/templates/project`;
  * дані з city-repo;
* створює:

  * базові DSL-артефакти для продуктів/оферів/токенів;
  * ABC-сегменти/пули;
  * базовий ops-набір (runbooks, status-файли).

---

## 10. Governance & rollout strategy

### 10.1. Рівні зрілості

Для кожного City/Project:

* `bootstrap` — структура створена, мінімальні дані;
* `pilot` — обмежене використання, ручний контроль;
* `rollout` — масштабування, стабільні пайплайни;
* `deprecated` — поетапне згортання.

Статуси фіксуються в:

* `progress/status-city-onboarding.yaml`;
* `progress/roadmap.yaml` у project-репах.

### 10.2. Внесення змін

Зміни, які зачіпають:

* **лише Project**:

  * робляться локально;
  * при виявленні повторюваності → кандидат у шаблон або hub.

* **City-level патерни**:

  * описуються в city-docs;
  * при кількох містах з однаковим патерном — кандидат у hub (canonical).

* **Core модель**:

  * PR у `trutta_hub` + оновлення PD-00x.

---

PD-009 фіксує **рамку інстансів** Trutta.
Будь-який реальний деплой (місто, продуктова програма, white-label інстанс) має бути зрозумілий як:

> Hub-концепти + City-специфіка + Project-конфіг.

Якщо це не так — спочатку уточнюється PD-009, потім будуються/рефакторяться репозиторії.
