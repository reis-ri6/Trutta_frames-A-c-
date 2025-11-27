# PD-012 — Trutta Runtime & Service Architecture (High-level)

**ID:** PD-012  
**Назва:** Trutta Runtime & Service Architecture (High-level)  
**Статус:** draft  
**Власники:** arch, eng, ops  
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
- PD-010 — Trutta Repositories & Documentation Conventions  
- PD-011 — Trutta Security, Privacy & Data Governance Baseline  
- VG-800+ — C4-архітектура, сервіси, OpenAPI/GraphQL  
- VG-8xx — Deployment, observability, RLS/ABAC

---

## 1. Purpose

Цей документ описує **верхньорівневу runtime-архітектуру Trutta**:

- які є **bounded contexts** та сервіси;
- як вони реалізують:
  - DSL (PD-001),
  - токени (PD-005),
  - TJM (PD-006),
  - ABC (PD-007),
  - data-layers (PD-004);
- як у це вбудовуються:
  - міста/проєкти (PD-009),
  - агенти/ппайплайни (PD-008),
  - security baseline (PD-011).

Мета — мати чітку модель: **що живе в коді й сервісах**, на яку потім «сідають» C4-діаграми й конкретні API в VG-800+.

---

## 2. Scope

### 2.1. Входить

- логічні bounded contexts;
- основні сервіси/рантайм-шари;
- потоки:
  - запити користувача,
  - управління продуктами/містами/проєктами,
  - дані/аналітика/події.

### 2.2. Не входить

- конкретні технології (Postgres vs ClickHouse, Kafka vs NATS);
- детальні C4-діаграми, OpenAPI/GraphQL-контракти (VG-800/801);
- конкретні deployment-патерни (монорепо vs polyrepo, k8s/nomad).

---

## 3. Runtime views

### 3.1. Core runtime planes

1. **Product & DSL Plane**  
   - керує продуктами/оферами/токенами/конфігами DSL.

2. **Journey & Community Plane (TJM + ABC)**  
   - живий контекст подорожей та попиту.

3. **Token & Settlement Plane**  
   - токени, стани, редемпшен, взаєморозрахунки.

4. **Data & Knowledge Plane**  
   - raw → canonical → analytics → AI/knowledge.

5. **Agent & Automation Plane**  
   - Codex/LLM-агенти, pipelines, doc/data-інфраструктура.

6. **Edge & UX Plane**  
   - фронти: app, бот, vendor-панелі, адмінки.

Кожен plane = кілька bounded contexts + сервіси.

---

## 4. Bounded contexts & core services

### 4.1. Product & DSL

**Bounded context: `product-dsl`**

Основні сервіси:

- `dsl-registry-service`  
  зберігає та валідуює DSL-артефакти (`product/offer/token/journey/constraints`).

- `product-catalog-service`  
  матеріалізує активні продукти/офери для runtime:
  - читає DSL,
  - будує read-model для UX/ордерингу.

- `config-versioning-service`  
  історія версій DSL/конфігів, привʼязка до релізів.

Взаємодія:

- приймає зміни з:
  - адмінок / project-реп / агентів;
- публікує:
  - події про зміни (`product_config_changed`, `token_type_updated`).

### 4.2. Journey & Community

**Bounded context: `journey-tjm`**

- `journey-engine-service`  
  runtime-машина TJM:
  - веде state подорожей/steps;
  - створює TJM-події (`step_entered`, `step_completed`).

- `city-routing-service`  
  працює з city-graph:
  - будує маршрути/мікро-journeys;
  - дає рекомендації по сервісних точках.

**Bounded context: `abc-community`**

- `avatar-profile-service`  
  зберігає avatar-профілі, не PII.

- `segment-engine-service`  
  рахує сегменти/пули попиту.

- `demand-pool-service`  
  менеджить DemandPools, Group-и, GroupTokens (в рамках PD-007 + PD-005).

---

### 4.3. Token & Settlement

**Bounded context: `token-runtime`**

- `token-engine-service`  
  реалізує lifecycle токенів (PD-005):
  - `issued/allocated/activated/escrow_pending/...`;
  - тригери (TJM-події, чекін, оракул).

- `token-ledger-service`  
  пише фактичні стани/баланси:
  - on-chain інтеграції,
  - off-chain ledger.

**Bounded context: `settlement & billing`** (може бути окремою системою/партнером)

- `settlement-service`  
  розрахунок вендорів, програм, грантів.

- `billing-service`  
  рахунки, інвойсинг (скоріше поза core Trutta, інтеграція).

---

### 4.4. Data & Knowledge

**Bounded context: `data-platform`**

- `data-ingestion-service`  
  ETL/ELT з зовнішніх джерел (maps/OTA/menus/FDA/міські open-data).

- `canonical-store-service`  
  шар canonical-даних (PD-004):
  - `Hotel`, `ServicePoint`, `Dish`, `Ingredient`, `HealthConstraint`, `City`, `Route`.

- `analytics-store-service`  
  агрегати, витрати, токен/подорож/вендор-статистика.

**Bounded context: `ai-knowledge`**

- `embedding-index-service`  
  векторні індекси (city-/service-/food-/journey-/docs-графи).

- `knowledge-graph-service`  
  графи сутностей та звʼязків на базі canonical/analytics.

---

### 4.5. Agent & Automation

**Bounded context: `agent-orchestration`**

- `agent-hub-service`  
  реєстр агентів (PD-008), їх manifesти/правила.

- `pipeline-orchestrator-service`  
  виконує agent-systems (`doc-pipeline`, `city-onboarding`, `project-bootstrap`).

- `codex-bridge-service`  
  інтеграція з Codex/LLM:
  - прокидає контекст (репо/документи);
  - застосовує guardrails (PD-011);
  - мапить IO на файлову структуру (PD-010).

---

### 4.6. Edge & UX

**Bounded context: `experience`**

- `user-app-gateway`  
  API-шлюз для мобіль/web/бота:
  - токен-операції,
  - рекомендації,
  - подорожі.

- `vendor-portal-service`  
  онбординг і операційні панелі вендорів.

- `ops/admin-console-service`  
  конфіг Trutta: DSL, міста, проєкти, ABC-сегменти, токени.

Всі edge-сервіси:

- використовують read-model-и з product/journey/token/data;
- не зберігають критичні дані локально (крім кешів).

---

## 5. Multi-tenant / City / Project модель у runtime

### 5.1. Tenant модель

- **Tenant** = логічне поєднання:
  - `city_id` (опціонально),
  - `project_id`,
  - `brand_id` (в white-label кейсах).

Сервіси повинні:

- мати multi-tenant-aware схеми (RLS + tenant-keys);
- відділяти:
  - hub-глобальні речі,
  - city-/project-специфіку.

### 5.2. Layering

- Hub-рівень — тільки моделі/схеми/пресети;
- City-рівень — реальні сутності (місто, вендори);
- Project-рівень — конфіг продуктів/кампаній.

У коді:

- `product-catalog-service`:
  - вміє вираховувати effective-config = hub + city + project;
- `journey-engine`, `token-engine`:
  - завжди працюють із конкретним `tenant`.

---

## 6. Event model & integration fabric

### 6.1. Події як клей

Ключові доменні події (логічно):

- `product_config_changed`
- `token_lifecycle_event` (mint/allocate/activate/escrow/redeem/expire)
- `tjm_step_event` (entered/completed)
- `abc_event` (segment/ demand pool / group updates)
- `vendor_event` (onboarding/ SLA / status)
- `data_ingestion_event` (import/refresh/failure)

Всі сервіси:

- пишуть у спільну event-fabric (message bus/event-stream);
- аналітика/моніторинг будуються на цих подіях (VG-9xx).

### 6.2. Інтеграції назовні

- Maps/OTA/places — через окремі adapters (`data-ingestion-service`);
- Payments/KYC/health — через ізольовані сервіси з власними репами;
- Blockchain — через `token-ledger-service` + chain-adapters.

---

## 7. Security & governance hooks (runtime)

- Всі сервіси:
  - інтегровані з єдиним IAM (ролі/атрибути, PD-011);
  - дотримуються data-class (Public/Internal/Sensitive/PII/Special).

- `user-app-gateway`, `admin-console`, `vendor-portal`:
  - роблять authz на вході;
  - пробивають у сервіси claims (tenant, role, purpose).

- Логування:
  - event-level + audit для чутливих операцій;
  - маскування критичних полів.

---

## 8. Взаємозвʼязок з PD/VG

- PD-001–007  
  — дають «що» (DSL, токени, TJM, ABC, дані).  
- PD-008  
  — дає «як працюють агенти».  
- PD-009  
  — дає модель інстансів (hub/city/project).  
- PD-010  
  — говорить як це все лежить у репах.  
- PD-011  
  — задає рамку безпеки й даних.

**PD-012**:

- дає **runtime-картинку**:
  - які bounded contexts і сервіси потрібні,
  - як вони мають взаємодіяти,
  - де саме «живуть» PD/DSL/дані в рантаймі.

Деталізація:

- C4-діаграми — у VG-800;
- OpenAPI/GraphQL — у VG-801;
- конкретні deployment-/infra-патерни — у VG-8xx.

Будь-який новий сервіс/функціонал має чітко вказати:

1. До якого bounded context він належить.
2. Які PD/DOMAIN-артефакти він реалізує.
3. Які події він слухає/генерує.
