# PD-003 — DSL File Types & Schemas

**ID:** PD-003  
**Назва:** Trutta DSL File Types & Schemas  
**Статус:** draft  
**Власники:** arch, product, data, eng  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- DOMAIN-* — доменні моделі  
- VG-8xx — Engineering: DSL Runtime  
- VG-9xx — Analytics & Events from DSL

---

## 1. Purpose

Цей документ:

- фіксує **набір типів DSL-файлів** (artefacts) у Trutta;
- задає **конвенції назв, директорій та версій**;
- описує **мінімальний обовʼязковий набір полів** для кожного типу;
- визначає **звʼязок схем (YAML/JSON) з доменними та runtime-моделями**.

Мета — щоб будь-який продукт/інтеграція/агент міг:

- однозначно зрозуміти, що за файл перед ним;
- валідувати його проти схем;
- зʼєднати з доменними сутностями та runtime.

---

## 2. Scope

У фокусі:

- логічні типи DSL-файлів;
- схема метаданих для кожного типу;
- файлові/директорні конвенції.

Не входить:

- повний опис усіх полів (це окремі schema-файли в `schemas/dsl/*.schema.yaml`);
- конкретні приклади для міст/кампаній (це project-level артефакти).

---

## 3. Типи DSL-артефактів

### 3.1. Product Manifest

**Файл:** `*.product.yaml`  
**Призначення:** опис логічного продукту (atomic/composite).

Мінімальні поля:

```yaml
apiVersion: trutta.dsl/v1
kind: Product
metadata:
  id: "PRD-xxxxx"          # стабільний ID продукту
  name: "Human-readable name"
  labels:                  # довільні теги
    domain: ["tourism", "hospitality"]
spec:
  type: "atomic" | "composite"
  domainRefs:              # посилання на доменні сутності
    - kind: "Hotel"
      ref: "HOTEL-xxxxx"
  description: "Short neutral description"
  components: []           # якщо composite
```

### 3.2. Offer Manifest

**Файл:** `*.offer.yaml`
**Призначення:** опис як продукт продається.

Мінімальні поля:

```yaml
apiVersion: trutta.dsl/v1
kind: Offer
metadata:
  id: "OFF-xxxxx"
  productId: "PRD-xxxxx"
  channels: ["app", "bot"]
spec:
  pricing:
    currency: "EUR"
    amount: 100.0
  availability:
    validFrom: "2025-01-01"
    validTo: "2025-12-31"
  limits:
    minQty: 1
    maxQty: 10
  tokens:
    - tokenTypeId: "TT-COFFEE-CUP"
      quantityPerUnit: 1
```

### 3.3. Token Type Manifest

**Файл:** `*.token.yaml`
**Призначення:** опис класу токенів (entitlement type).

Мінімальні поля:

```yaml
apiVersion: trutta.dsl/v1
kind: TokenType
metadata:
  id: "TT-xxxxx"
  name: "Coffee cup token"
spec:
  entitlementKind: "meal" | "night" | "pass" | "service" | "custom"
  domainRefs:
    - kind: "ServicePoint"
  lifecycle:
    states: ["issued", "activated", "redeemed", "expired"]
    initialState: "issued"
  constraintsRef: "CONSTR-xxxxx"   # опціонально
```

### 3.4. Journey Binding

**Файл:** `*.journey.yaml`
**Призначення:** маппінг продуктів/оферів/токенів на TJM.

Мінімальні поля:

```yaml
apiVersion: trutta.dsl/v1
kind: JourneyBinding
metadata:
  id: "JB-xxxxx"
spec:
  target:
    type: "product" | "offer" | "tokenType"
    id: "PRD-xxxxx"
  tjm:
    stages:
      - "pre-trip"
      - "in-city"
    steps:
      - id: "TJM-STEP-COFFEE"
        relation: "available"
```

### 3.5. Constraints Manifest

**Файл:** `constraints/*.yaml`
**Призначення:** опис наборів обмежень для продуктів/токенів.

Мінімальні поля:

```yaml
apiVersion: trutta.dsl/v1
kind: Constraints
metadata:
  id: "CONSTR-xxxxx"
spec:
  time:
    validFrom: null
    validTo: null
    blackout: []
  geo:
    allowedZones: []
    blockedZones: []
  health:
    profiles: ["renal-friendly", "low-sodium"]
  regulatory:
    minAge: 18
    notes: ""
```

### 3.6. Route / City Product

**Файл:** `*.route.yaml` / `*.city-product.yaml`
**Призначення:** опис маршрутів / міських продуктів поверх city-graph.

Мінімальні поля (route):

```yaml
apiVersion: trutta.dsl/v1
kind: Route
metadata:
  id: "ROUTE-xxxxx"
  cityId: "CITY-xxxxx"
spec:
  waypoints:
    - poiId: "POI-xxxxx"
      order: 1
  bindings:
    offers: ["OFF-xxxxx"]
```

---

## 4. Директорна структура DSL

Базовий layout:

```txt
dsl/
  products/
    PRD-*/                 # каталог продукту
      main.product.yaml
      offers/
        OFF-*.offer.yaml
      journey/
        *.journey.yaml
      constraints/
        *.yaml
  token-types/
    TT-*.token.yaml
  routes/
    *.route.yaml
  city-products/
    *.city-product.yaml
  constraints/
    global-*.yaml
schemas/
  dsl/
    product.schema.yaml
    offer.schema.yaml
    token-type.schema.yaml
    journey-binding.schema.yaml
    constraints.schema.yaml
    route.schema.yaml
    city-product.schema.yaml
```

Принципи:

* `dsl/` — інстанси (живі артефакти);
* `schemas/dsl/` — схеми (валидація).

---

## 5. Метадані та обовʼязкові поля

### 5.1. Загальний каркас

Усі DSL-файли дотримуються каркасу:

```yaml
apiVersion: trutta.dsl/v1
kind: <KindName>
metadata:
  id: "<ID>"
  name: "<Human name>"        # опційно, але бажано
  labels: {}                  # вільні теги
spec:
  ...                         # типоспецифічна частина
```

Вимоги:

* `apiVersion` — завжди присутній;
* `kind` — одна зі значень, відомих схемі;
* `metadata.id` — стабільний ID, використовується в посиланнях;
* `spec` — лише те, що описано в відповідній schema.

### 5.2. Посилання між артефактами

Посилання тільки за `metadata.id`, не по шляхах файлів.

Приклади:

* Offer → Product: `metadata.productId`;
* Product → Domain entity: `domainRefs[*].ref`;
* TokenType → Constraints: `spec.constraintsRef`;
* JourneyBinding → Product/Offer/TokenType: `spec.target`.

---

## 6. Валідація та linting

### 6.1. Схеми

Кожен тип файлу має схему в `schemas/dsl/*.schema.yaml`:

* визначає обовʼязкові поля;
* типи значень;
* дозволені `kind`/`enum` значення.

### 6.2. Linting правила

Крім схем:

* перевірка унікальності `metadata.id` в усьому DSL-шарі;
* перевірка, що всі `ref` → існуючі ID:

  * domain entities (через domain registry),
  * інші DSL-артефакти;
* семантичні перевірки:

  * `offer` не може посилатись на неіснуючий `product`;
  * `journey-binding` тільки на відомі TJM-stages/steps.

---

## 7. Версіонування DSL-артефактів

### 7.1. Версія схеми

`apiVersion`:

* `trutta.dsl/v1`, `v2` тощо;
* MAJOR змінюється при некомпатибельних змінах.

### 7.2. Версія конкретного артефакта

Опційно:

```yaml
metadata:
  ...
  version: 1
  revisionNotes: "Short note"
```

Політика:

* для core-артефактів (типу city-products, ключові токен-тайпи) versioning бажаний;
* міграції між версіями описуються в окремих VG-документах.

---

## 8. Звʼязок з доменами та БД

* DSL-файли — **джерело правди** для конфігів;
* доменні сутності (Hotel, Dish, Route) описані окремо в `domains/*` + `schemas/db/*`;
* для кожного типу DSL-файлу вказується:

  * які таблиці/колекції в БД він наповнює;
  * які події runtime мають створюватися.

Це описується в:

* PD-0xx (DSL ↔ DB mapping),
* VG-8xx (runtime implementation).

---

## 9. Використання агентами

AI-/Codex-агенти повинні:

* розпізнавати тип файлу по:

  * `kind` + `apiVersion`;
  * директорії та суфіксу (`*.product.yaml` тощо);
* не ламати каркас `metadata`/`spec`;
* при генерації нових файлів:

  * завжди заповнювати `apiVersion`, `kind`, `metadata.id`;
  * дотримуватись схем.

---

## 10. Подальші кроки

На базі PD-003:

* створити/уточнити `schemas/dsl/*.schema.yaml` (окремий PD/ENG-док);
* додати VG-8xx runtime-гайди:

  * як інжестити DSL-файли;
  * як деплоїти зміни;
* додати VG-9xx аналітичні гайди:

  * які події зʼявляються автоматично для кожного типу DSL-файлу.

Цей документ вважається **референсом** для всіх, хто створює/редагує DSL-файли або пише інструменти над ними.
