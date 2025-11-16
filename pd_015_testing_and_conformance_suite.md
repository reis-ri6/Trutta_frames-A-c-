# PD-015 Testing & Conformance Suite v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / QA / Platform / Governance

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-spec.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-ci-templates.md  
- PD-013-governance-and-compliance-spec.md  
- PD-014-examples-and-templates-library.md  
- PD-014-generated-samples-json  
- PD-014-examples-links.md  
- PD-016-roadmap-and-evolution.md

Мета — зафіксувати **єдину тест-стратегію** для Product DSL / Registry / інтеграцій та визначити, як відбувається **сертифікація продуктів** (product conformance).

Фокус:
- схеми (schema);  
- семантика (semantic);  
- інтеграції (integration, contract, e2e);  
- продуктивність і надійність (performance / resilience);  
- conformance-рівні для продуктів.

---

## 1. Scope & Принципи

### 1.1 Scope

Тестування охоплює:

- **DSL-рівень**: ProductDef, профілі, policy-артефакти, схеми;  
- **Registry-рівень**: DDL, міграції, API, snapshot’и;  
- **Інтеграції**: TJM, Trutta, LEM, зовнішні сервіси;  
- **Runtime**: agent-runtime, journey-runtime, settlement-пайплайни;  
- **Governance**: відповідність політикам PD-013, risk-гейтам.

### 1.2 Принципи

- **Shift-left**: максимум перевірок на етапі PR (`pdsl lint/test`) до попадання в Registry.  
- **Single source of truth**: golden samples (PD-014) + schemas (PD-001/PD-002/PD-003/PD-007/PD-009/PD-010).  
- **Risk-based**: глибина тестів залежить від risk-level змін та продукту.  
- **Deterministic**: тести відтворювані, з контрольованими фікстурами (PD-014).  
- **Policy-aware**: тести перевіряють не тільки техніку, а й governance/policy constraints (legal, safety, city/vendor).

---

## 2. Класи тестів

### 2.1 Schema Tests

Ціль: гарантувати, що усі DSL/Registry артефакти відповідають схемам.

Перевіряється:

- ProductDef (core schema + extensions):
  - обов’язкові поля (ID, name, category, markets, profiles.ref тощо);  
  - типи, enum-и, формати (ISO-коди, версії, ULID/UUID);  
  - structure integrity (масиви, об’єкти, вкладені профілі).
- Профілі (PD-007/PD-009/PD-010): token/loyalty/pricing/ops/safety/UI.  
- Registry-моделі (PD-003):
  - JSON-схеми для записів Registry;  
  - OpenAPI/GraphQL контракти (якщо є).  
- DDL/міграції: базові структурні інваріанти (NOT NULL, FK, indexes) синхронізовані з DSL-схемами.

Інструменти:

- `pdsl schema-validate` (див. PD-012):
  - валідація окремого файлу;  
  - валідація всієї бібліотеки продуктів;  
  - валідація golden samples (PD-014-generated-samples-json).

### 2.2 Semantic Tests

Ціль: гарантувати інваріанти доменної моделі й коректну семантику продуктів.

Приклади семантичних перевірок:

- **ID & links**:
  - унікальність `product_id`;  
  - валідність посилань `*_profile_ref`, `journey_templates.ref`, `markets.code`;  
  - consistency між ProductDef та Registry snapshot (product_id / markets / status).

- **Ціноутворення та фінанси** (PD-009):
  - не-негативні ціни й комісії;  
  - сума розподілу revenue-split = 100% (або в межах ε);  
  - валюти узгоджені з ринками (FX-поведінка визначена).

- **Ops / safety / quality** (PD-010):
  - SLO/SLI визначені для продуктів з high/critical risk;  
  - safety thresholds визначені для health/humanitarian;  
  - escalation-політики прив’язані до ринків/міст.

- **Governance & legal** (PD-013):
  - продукти з категоріями, що вимагають KYC/AML/age-restriction, мають відповідні прапори;  
  - legal_entity/jurisdiction задані для продукції з грошовими потоками;  
  - продукти з `risk_level: critical` не мають статусу `public_template` в бібліотеці прикладів.

Інструменти:

- `pdsl semantic-validate`:
  - проганяє набір правил над ProductDef/профілями/Registry snapshot;  
  - використовує golden samples як контрольні кейси.

### 2.3 Integration & Contract Tests

Ціль: гарантувати, що Registry / TJM / Trutta / LEM інтегруються згідно контрактів.

Типи:

- **Contract tests** для API:
  - Registry API (PD-003-registry-api.yaml);  
  - TJM API (journey runtime / compiler);  
  - Trutta API (entitlements, claim, redemption, swap);  
  - LEM API (city graph, routing, service_points).

- **Integration сценарії**:
  - обрані EX-XXX (PD-014) виконуються end-to-end в dev/staging env;  
  - приклад: `vien.geist`: create journey → issue meal token → claim → redeem → record satisfaction → завершення.

Конвенції:

- для кожного EX-XXX з `status: public_template` визначено мінімум 1 e2e сценарій;  
- для high/critical risk продуктів — додаткові негативні сценарії (failure/retry, partial availability, vendor failure).

### 2.4 Performance & Resilience Tests

Ціль: перевірити, що ключові сервіси тримають навантаження й відповідають SLO (PD-010).

Основні мішені:

- Registry (read/write, publish, snapshot);  
- TJM runtime (start/completion journeys);  
- Trutta (entitlement issue/claim/redeem);  
- LEM (routing, city graph lookups);  
- `pdsl` як сервіс (якщо винесений).

Метрики:

- latency p50/p95/p99;  
- throughput (ops/sec, events/sec);  
- error rate;  
- degradation behavior (graceful vs hard fail).

Режими тестів:

- baseline load;  
- stress / burst;  
- soak (довгі прогони);  
- chaos / fault injection (вимкнення залежностей, часткові фейли).

---

## 3. Навантаження по типу змін

### 3.1 Типи змін

Типи змін (див. PD-011/PD-013):

- `product_change` — зміни в ProductDef без впливу на фінанси/ops/safety;  
- `pricing_change` — зміни цін, revenue-split, FX;  
- `ops_safety_change` — SLO/SLI/SLA, thresholds, escalation;  
- `policy_change` — governance/legal/policy;  
- `schema_change` — DSL schema / Registry contracts / DDL.

### 3.2 Матриця: change_type × risk_level → required tests

Скетч (high-level):

- **Low + product_change**:
  - schema + semantic (локальні);  
  - smoke integration (1–2 key flows, якщо продукт активний).

- **Medium + будь-який change_type**:
  - повний schema + semantic;  
  - contract tests для релевантних API;  
  - targeted integration сценарії для зачеплених EX-XXX.

- **High / Critical**:
  - повний schema + semantic;  
  - повний набір contract tests по торканих сервісах;  
  - e2e сценарії (включно з негативними);  
  - performance smoke (мінімальний load-рівень);  
  - для schema_change — regression по golden samples (PD-014-generated-samples-json).

Ця матриця деталізується в PD-012-ci-templates та PD-013-templates.

---

## 4. Test Data & Fixtures

### 4.1 Джерела тест-даних

- **EX-XXX** бібліотека (PD-014): канонічні продукти.  
- **fixtures** (PD-014): валідні/невалідні DSL, sequences подій.  
- **generated samples** (PD-014-generated-samples-json): базовий/повний/merged/profiles/registry view.

### 4.2 Принципи

- без PII та реальних контрактних даних;  
- health/finance кейси — лише internal/restricted env;  
- жорстке розділення test/seed data від production data.

### 4.3 Використання EX-XXX

- кожен EX-XXX має пов’язаний набір тестів:  
  - schema/semantic;  
  - integration/e2e;  
  - за потреби — performance micro-scenarios.

---

## 5. Tooling & CI Integration

### 5.1 CLI-команди `pdsl`

Базовий набір (скиця інтерфейсу, деталі в PD-012):

- `pdsl lint` — швидка перевірка форматів/схем;  
- `pdsl test schema` — schema-валидація всіх або змінених артефактів;  
- `pdsl test semantic` — семантичні перевірки;  
- `pdsl test integration --example EX-XXX` — інтеграційні сценарії для конкретного прикладу;  
- `pdsl test all` — агрегований запуск.

### 5.2 CI-рівні

- **PR-level**:
  - lint + schema + semantic на змінених файлах;  
  - integration tests для зачеплених EX-XXX;  
  - регресія golden samples, якщо є schema_change.

- **Branch-level (main / develop)**:
  - повний прогін schema + semantic по всій бібліотеці;  
  - вибіркові e2e сценарії;  
  - smoke performance.

- **Nightly / weekly**:
  - повний e2e набір для обраних EX-XXX;  
  - повні performance / chaos сценарії;  
  - audit conformance (перевірка, що всі active продукти сертифіковані).

---

## 6. Product Conformance & Сертифікація

### 6.1 Рівні conformance

Пропонується 3 рівні (назви можна уточнити):

- **L0 – Basic**
  - пройдені schema + базові semantic тести;  
  - мінімальні integration smoke-сценарії;  
  - дозволено обмежене використання (beta / internal).

- **L1 – Standard**
  - повний набір schema + semantic для продукту та його профілів;  
  - contract tests для Registry + релевантних стеків (TJM/Trutta/LEM);  
  - хоча б 1 успішний e2e сценарій в staging;
  - використовується як стандарт для більшості продуктів.

- **L2 – Critical**
  - все, як L1;  
  - розширені e2e (включно з негативними, failure/retry кейсами);  
  - performance smoke під цільове навантаження;  
  - додаткові governance-перевірки (legal/safety/city/vendor constraints).

Рівень conformance залежить від `risk_level` продукту (див. PD-013).

### 6.2 Сертифікаційний процес

1. **Запит сертифікації**
   - PO/PA ініціює підвищення рівня (L0→L1, L1→L2) через PR / ticket.  
2. **Автоматичний прогін тестів**
   - CI запускає відповідний набір для цільового рівня.  
3. **Review результатів**
   - QA/DevEx переглядає фейли, робить рекомендації.  
4. **Governance approve**
   - для L2 потрібні додаткові approvals (SAFE/SEC/GOV).  
5. **Запис у Registry**
   - у Registry/DSL додається поле `conformance_level: L0|L1|L2`;  
   - це поле може впливати на доступність продукту в певних env/каналах.

### 6.3 Degradation / Revocation

- При критичних інцидентах продукт може:
  - бути тимчасово знижений з L2→L1 або L1→L0;  
  - отримати прапор `conformance_suspended: true`.

- Після фіксу і повторного прогону тестів — conformance може бути відновлений.

---

## 7. Спостережність (Observability) та тестування

Тести повинні бути інтегровані з observability-шаром:

- кожен integration / e2e / performance тест генерує марковані події/метрики;  
- можна співставити тестові прогін-и з runtime-метриками (latency, error rate, saturations);  
- для критичних EX-XXX будується історія conformance-over-time.

Ідея: тестові сценарії = ще одне "джерело правди" про очікувану поведінку системи.

---

## 8. Roadmap-зв’язки (ескіз)

Деталізація в PD-016, але high-level напрямки:

- перехід до **policy-as-code aware tests** (перевірка OPA/правил governance разом із DSL);  
- property-based testing для окремих інваріантів (pricing, caps, safety thresholds);  
- все більша автоматизація mapping `change_type × risk_level → test_plan`;  
- "contract-first" підхід для нових інтеграцій (спочатку контракт/тести, потім реалізація).

---

## 9. Summary

- PD-015 визначає **повний стек тестових практик** для Product DSL / Registry / інтеграцій.  
- Тести структуровані по шарах: schema → semantic → integration/contract → performance/resilience.  
- Риск-базований підхід задає, які тести обов’язкові для кожного типу змін.  
- Conformance-рівні (L0/L1/L2) стають видимими атрибутами продукту й впливають на те, де і як продукт може бути запущений.  
- Наступний крок (PD-016) — зафіксувати еволюцію цих практик, інтеграцію з policy-as-code та rule engines.

