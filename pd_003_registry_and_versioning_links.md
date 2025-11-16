# PD-003 Registry and Versioning Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-001-product-dsl-core-links.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-ddl.sql  
- PD-003-registry-api.yaml  
- PD-003-registry-and-versioning-templates.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md

Мета документа — зафіксувати **зв’язки Registry та моделі версіонування** з іншими шарами системи: authoring/CI, TJM, Trutta, LEM, frontend, аналітика, governance, multi-tenant.

> PD-003-spec описує поведінку Registry. Цей документ описує, як інші сервіси її використовують.

---

## 1. Authoring / CI / Schema-store

### 1.1 Ланцюжок authoring → CI → Registry

- **Authoring** (Notion/Figma/Git + PDSL-файли):
  - продакт/архітектор редагує `ProductDef` (`.yaml/.json`) у репозиторії;
  - PDSL-схеми живуть у `schema-store` (окремий репозиторій/сервіс).
- **CI-level**:
  - jobs запускають валідацію проти PDSL-схеми (PD-001) + семантичні тести (фікстури з PD-002/003);
  - при успіху CI має право викликати `registerProductDef` у target env.
- **Registry**:
  - приймає лише документи, що пройшли CI або мають спеціальний override-флаг (карантин/experiments);
  - зберігає сирий ProductDef у `product.product_defs_raw` + пише нормалізовану модель.

> DIAGRAM_PLACEHOLDER #1: "Authoring → CI → Registry"  
> Prompt: "Draw a lifecycle showing: Git repo (ProductDef) → CI pipeline (lint, schema validation, tests) → Registry API (registerProductDef) → Postgres (product schema) + outbox events."

### 1.2 Джерела правди

- **Семантика ProductDef** — PD-001 + schema-store.
- **Стан у часі** (версії/статуси/overlays) — Registry + PD-003.
- CI не тримає тривалого state, лише перевіряє консистентність між цими джерелами.

---

## 2. Registry ⇄ TJM (Journey Runtime)

### 2.1 Зв’язки

- TJM читає дані з Registry:
  - `searchProducts` / `listProductVersions` з фільтрами по `journey_class`, `market`, `status=active`;
  - `resolveProductForContext` для побудови runtime-конфігів.
- Registry не викликає TJM напряму, взаємодія — через події та pull-запити з боку TJM.

### 2.2 Event-driven інтеграція

- Registry емить:
  - `product.version.created`;
  - `product.version.status_changed`;
  - `product.overlay.created/updated`.
- TJM-підписники:
  - оновлюють свої кеші та index-и;
  - при необхідності, роблять додатковий `GET` до Registry по `product_version_id`.

### 2.3 Ownership

- **Registry**:
  - owner lifecycle-протоколу ProductVersion/overlays;
  - не знає деталей TJM state machine.
- **TJM**:
  - owner семантики JourneyClass, TJM-доків та runtime state;
  - не може змінювати ProductVersion/overlays, лише читати.

---

## 3. Registry ⇄ Trutta (Token / Entitlement Layer)

### 3.1 Read-side інтеграція

- Trutta читає з Registry:
  - список активних продуктів по markets/segments (`searchProducts`);
  - details по `product_version_id` для map-інгу в entitlements;
  - інтеграційні binding’и (`integration_profiles`, `product_integration_bindings`) через окремі API/в’юшки.

### 3.2 Event-side інтеграція

- Критичні події для Trutta:
  - `product.version.created` (чернетка — підготовка конфігу);
  - `product.version.status_changed` → `active`/`deprecated`;
  - `product.overlay.created/updated` (локальні зміни цін/валют/параметрів, що впливають на токени).

Trutta-воркфлоу:

1. Отримати `product.version.status_changed` (`review → active`).
2. Через API Registry забрати "resolved" конфіг (`resolveProductForContext`).
3. Синхронізувати entitlement-профіль/пули/ліміти у Trutta.

### 3.3 Кордони відповідальності

- **Registry** забезпечує:
  - стабільні ID продуктів та версій;
  - консистентні binding’и до Trutta-профілів.
- **Trutta** вирішує:
  - як саме реалізувати токени, свопи, fraud-патерни;
  - не має write-доступу до Registry.

---

## 4. Registry ⇄ LEM (City Graph)

### 4.1 Використання Registry

- LEM використовує Registry для:
  - переліку продуктів, доступних у city/cluster (`market_code`, `segment_code`);
  - резолюції інтеграційних профілів `city_graph`.

Запити LEM:

- `searchProducts?market_code=AT-VIE&status=active`;
- `resolveProductForContext?market_code=AT-VIE&city_code=VIE`.

### 4.2 Event-потік

- Важливі події для LEM:
  - `product.version.status_changed` (активація/депрекація продуктів у місті);
  - `product.overlay.created/updated` з `overlay_kind=city/market`.

LEM на основі цих подій:

- оновлює кластеризацію service points;
- оновлює "доступні продукти" у вузлах графу;
- може перераховувати маршрути/loops.

### 4.3 Ownership

- Registry не знає структури city graph;
- LEM не має write-доступу в Registry, лише read + реакція на події.

---

## 5. Registry ⇄ Frontend / BFF / API Gateway

### 5.1 BFF-патерн

- Frontend (apps / portals) **не говорить напряму** з Registry у складних кейсах — працює через BFF/GraphQL-шар.
- BFF об’єднує:
  - Registry (product catalogue);
  - TJM (journey/runtime);
  - Trutta (wallet/entitlements);
  - LEM (міський граф, рекомендації).

### 5.2 Типові сценарії

- "Показати список продуктів у місті":
  - BFF → Registry `searchProducts` (фільтри по `market_code`, `status=active`, `segment`);
  - BFF збагачує дані з TJM/LEM.
- "Показати деталі продукту":
  - BFF → Registry `resolveProductForContext`;
  - BFF → TJM/Trutta для поточного стану journey/entitlements.

Registry залишається **канонічним каталогом**, але ніколи не стає монолітним "Backend-for-all".

---

## 6. Registry ⇄ Analytics / DWH / ML

### 6.1 Dimension source

- Registry — **джерело dimension-таблиць** `dim_product`, `dim_product_version`, `dim_market`, `dim_segment`.
- DWH-пайплайни:
  - читають snapshot-и (через read-only репліку/в’юшки);
  - або споживають події (`product.version.*`) для CDC/streaming.

### 6.2 Зв’язок з фактами

- Факт-таблиці (транзакції, journeys, entitlements) використовують:
  - `product_id`;
  - `product_version_id`;
  - інколи `integration_profile_id`.

Резолюція в аналітиці:

- join fact → `dim_product_version` → таксономія/markets/segments;
- overlay-ефекти можна або розкручувати як окремий dimension, або застосовувати на етапі побудови "resolved" dim.

### 6.3 ML / рекомендації

- ML-сервіси використовують Registry як:
  - каталог фічей продуктів (через в’ю `product_version_features_view`);
  - джерело списку доступних продуктів/версій для таргетингу.

---

## 7. Registry ⇄ Governance / Legal / Ops

### 7.1 Governance-процеси

- Council/комітети працюють на рівні Registry:
  - затверджують переходи `review → active`;
  - задають політики, що інкапсульовані у валідаторах (PD-013).

Інструменти:

- Ops/Legal UI, який показує:
  - історію статусів (`product_version_status_history`);
  - audit-log (`registry_audit_log`).

### 7.2 Legal / тарифи

- Юридичні документи (ToS, SLA, тарифні плани) посилаються на `product_id`/`product_version_id` як на стабільні ідентифікатори оферт.
- Registry гарантує, що semver/статуси узгоджені з юридичними політиками (через POLICY_ERROR).

---

## 8. Multi-tenant / White-label / Syndication

### 8.1 Multi-tenant модель

- Один глобальний Registry-сервіс може обслуговувати кілька tenant’ів:
  - tenant як `operator_code`/`org_id` на рівні Product/Overlay;
  - або як окрема колонка в schema (out-of-scope для PD-003, але важливо концептуально).

### 8.2 White-label каталоги

- White-label партнери використовують:
  - або власний logical env (`X-Env: partner-X`);
  - або фільтрацію по `operator_code` в `resolveProductForContext` / `searchProducts`.

### 8.3 Syndication

- Registry → партнери через:
  - read-only API ключі з обмеженнями по markets/segments;
  - snapshot-дистрибуцію (`export catalog` job у DWH/файли).

---

## 9. Environments / Promotion / Topology

### 9.1 Env-модель

- Мінімум `dev/stage/prod`; опційно — окремі env для великих партнерів.
- Registry може бути:
  - окремим інстансом per env;
  - або єдиним з env-колонкою (рекомендовано — розділення prod від інших).

### 9.2 Promotion links

- Promotion job при переході `stage → prod`:
  - читає ProductDef/стан з `stage`;
  - перевіряє компатибільність (semver/gov-політики);
  - викликає `registerProductDef` у `prod`;
  - синхронізує статуси/overlays за політиками.

> DIAGRAM_PLACEHOLDER #2: "Promotion flow stage → prod"  
> Prompt: "Draw a flow diagram: Stage Registry (product_id, version) → Promotion job → Prod Registry (registerProductDef) → product.version.created/status_changed events to external systems."

---

## 10. Summary

- Registry — центральний шар, через який усі сервіси бачать каталог продуктів і їх еволюцію.
- Зв’язки побудовані за принципом **read-heavy + event-driven**, без прямих write-операцій у Registry з боку TJM/Trutta/LEM.
- Аналітика, governance, ML, frontend-шари опираються на стабільні `product_id/product_version_id` і lifecycle-протоколи, визначені в PD-003.
- Multi-tenant і white-label патерни реалізуються через overlays, контексти та env/policy-рівень, не ламаючи базове ядро Registry.

