# PD-016 Roadmap & Evolution for Product DSL & Registry v0.1

**Status:** Draft 0.1  
**Owner:** Product Architecture / DevEx / Governance

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-and-versioning-templates.md  
- PD-007-product-profiles-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-ci-templates.md  
- PD-013-governance-and-compliance-spec.md  
- PD-014-* (examples, samples, links)  
- PD-015-* (testing, fixtures, links)

Мета — зафіксувати **дорожню карту розвитку Product DSL / Registry** та формалізувати:

- політику breaking changes;  
- патерни міграцій (E→M→C / Expand→Migrate→Contract);  
- очікувану еволюцію інструментів (`pdsl`, Registry, CI/test-пайплайни);
- зв’язок із governance (PD-013) та conformance (PD-015).

---

## 1. Горизонти розвитку

### 1.1 Horizon 1 (0–6 місяців)

Фокус:

- стабілізація **core DSL-схем** (ProductDef, Profiles, Registry);  
- формалізація **non-breaking / breaking** змін;  
- базова підтримка E→M→C патерну в DDL і Registry;  
- повна інтеграція `pdsl` у PR-level CI (lint/schema/semantic/tests);
- запуск бібліотеки EX-XXX (PD-014) як golden-layer.

### 1.2 Horizon 2 (6–18 місяців)

Фокус:

- розширення DSL (нові типи профілів, advanced pricing/ops/safety);  
- **policy-as-code** інтеграція (governance rules, risk-політики, city/vendor constraints);  
- еволюція Registry до multi-region / multi-tenant режимів;  
- автоматизований **test-plan-as-code** (зв’язок change_type × risk_level → набір тестів);  
- покриття основних продуктів conformance-рівнем L1/L2.

### 1.3 Horizon 3 (18+ місяців)

Фокус:

- формалізація **DSL як публічного стандарту** (external integrators);  
- версіонування й negotiation схем між різними інсталляціями/містами;  
- plug-in DSL-модулі для специфічних доменів (health, humanitarian, mobility);  
- формалізована модель "multi-ledger" фінансових інтеграцій (кілька payment-rail’ів, Trutta/інші протоколи).

---

## 2. Еволюція DSL: версіонування та розширення

### 2.1 Семантичне версіонування DSL-схем

Для **core DSL-схем** (ProductDef, Profiles, Registry records) використовується semver:

- `MAJOR.MINOR.PATCH` (наприклад, `productdef:1.3.0`);
- **PATCH** — несуттєві зміни:
  - виправлення описів/коментарів;  
  - додавання опційних полів із дефолтними значеннями;  
  - уточнення enum-ів без вилучення існуючих значень.

- **MINOR** — backward-compatible розширення:
  - нові опційні поля;  
  - нові enum values, які коректно обробляються старими клієнтами (через default/ignore);  
  - нові типи профілів із чіткою optional semantics.

- **MAJOR** — breaking changes:
  - вилучення/перейменування полів;  
  - робота опційного поля обов’язковим без дефолта;  
  - зміна типу поля (string→object, int→string тощо);  
  - звуження enum (видалення значень);  
  - зміни, що змінюють базові інваріанти.

### 2.2 Правила безпечних змін

Non-breaking (дозволені в Minor/Patch):

- додати поле з чітким default (або optional) і без зміни meaning існуючих;  
- додати новий enum value, якщо відсутність підтримки в старих клієнтів безпечна (наприклад, вони його ігнорують);  
- додати новий тип профілю, який optional для поточного runtime.

Breaking (потребують MAJOR + migration):

- змінити meaning чи одиниці виміру існуючого поля;  
- зробити обов’язковим поле без дефолтів;  
- видалити або перейменувати поле;  
- видалити enum value, що реально використовується в продуктах;  
- вводити нові жорсткі constraints без кроку "expand".

### 2.3 DSL Extensions

На Horizon 2+ планується підтримка **DSL extensions**:

- модулі, що додають доменно-специфічні поля/об’єкти (наприклад, `health_constraints`, `humanitarian_kpi` тощо);  
- кожен модуль має власний `module_id` і `module_schema_version`;  
- core DSL залишається стабільним, модулі можуть еволюціонувати окремо.

---

## 3. Еволюція Registry

### 3.1 Data model & layering

Поступовий перехід до структури:

- **Core Registry** — master записів `product_id`, версій, статусів, базових markets;  
- **Profile Store** — normalized таблиці профілів (pricing, ops/safety, loyalty, token);  
- **Policy Store** — governance/policy rules (PD-013 + policy-as-code);  
- **History / Events** — audit-log, зміни, publish-івенти;
- **Caches** — materialized views/JSON snapshots для runtime.

### 3.2 Multi-region / multi-tenant

Horizon 2–3:

- логічний поділ Registry по city/region/tenant;  
- механізм **federated registry**: локальний Registry для міста + central coordination;  
- політики data residency (де зберігається фінансова/health інформація).

### 3.3 Event-sourcing / CDC

Поступово:

- усі зміни Registry продукують події `registry.event` (create/update/deprecate/publish);  
- CDC-стрім із реєстру використовується runtime-агентами, аналітикою, city dashboards;  
- версіонування продуктів та профілів відслідковується і в подіях, і в audit-log.

---

## 4. Breaking Changes Policy

### 4.1 Загальні правила

1. **No silent breaking**: жодних змін, що ламають існуючі продукти/клієнти без чіткої MAJOR-позначки і міграцій.  
2. **Deprecation-first**: будь-яке видалення/зміна semantics проходить через фазу deprecation.  
3. **Guarded rollout**: breaking changes спочатку тестуються на EX-XXX + internal продукти в non-prod env.

### 4.2 Deprecation lifecycle

Для полів/enum/value/feature:

- **Phase 0 – Introduce**: додати нове поле/enum з backward-compatible semantics.  
- **Phase 1 – Dual-write**: новий формат/поле заповнюється паралельно зі старим; тести перевіряють консистентність.  
- **Phase 2 – Deprecate**: старе поле позначене `deprecated: true` у схемах; `pdsl lint` видає попередження; нові продукти не можуть використовувати deprecated-конструкції.  
- **Phase 3 – Remove (MAJOR)**: старе поле прибирається зі схем; Registry/DB проходять E→M→C міграцію; всі продукти мігрують.

Тривалість фаз залежить від ризику (див. PD-013).

### 4.3 Compatibility Windows

- Кожна MAJOR-версія DSL має **підтримуване вікно** (наприклад, 12–18 місяців);  
- Registry/runtime можуть підтримувати **2 сусідні MAJOR-версії** (N та N+1) з чіткими правилами negotiation;  
- старші версії позначаються як EOL, продукти на них мають бути мігрувані.

---

## 5. Migration Patterns (E→M→C)

### 5.1 Базовий патерн Expand→Migrate→Contract

Використовується для **DB-схем**, **Registry records** і **DSL-схем**:

1. **Expand**
   - додати нові поля/таблиці/enum-значення;  
   - зробити їх optional або з дефолтами;  
   - оновити `pdsl`/runtime, щоб підтримували обидві версії.

2. **Migrate**
   - заповнити нові поля з історичних даних;  
   - мігрувати продукти/EX-XXX;  
   - `pdsl` тести перевіряють консистентність старих/нових структур.

3. **Contract**
   - оголосити старі поля deprecated (Phase 2 deprecation);  
   - видалити їх після періоду grace (Phase 3);  
   - очистити код/DDL від legacy-конструкцій.

### 5.2 Приклад: зміна pricing моделі

Сценарій: перехід від `price` до `base_price + price_modifiers[]`.

- Expand:
  - додати `base_price` і `price_modifiers[]`;  
  - відображати `price` → `base_price` із тривіальним modifier;  
  - runtime читає нові поля, але підтримує `price`.

- Migrate:
  - прогнати міграцію з `price` у `base_price + modifiers` для всіх продуктів;  
  - EX-XXX оновлені;  
  - тести гарантують, що результат математично еквівалентний.

- Contract:
  - позначити `price` як deprecated;  
  - заблокувати створення нових продуктів зі старим полем;  
  - у наступній MAJOR — видалити `price` з DSL/DDL.

### 5.3 Migration Descriptors

PD-003-* вводить **migration descriptors** (`migration-descriptor.yml`):

- `id`, `from_version`, `to_version`;  
- scope (DSL/Registry/DB/Profiles);  
- опис трансформацій;  
- тестові сценарії/EX-XXX, які мають пройти.

`pdsl migrate plan/apply` може використовувати ці дескриптори для напівавтоматичних міграцій.

---

## 6. Тулінг та автоматизація

### 6.1 `pdsl` roadmap (ескіз)

Horizon 1–2:

- `pdsl diff schema` — порівняння версій схем, класифікація змін (breaking/non-breaking);  
- `pdsl migrate plan` — генерація плану міграцій для заданого переходу версії;  
- `pdsl policy-check` — інтеграція з governance/policy rules (PD-013);  
- глибша інтеграція з test-fixtures (PD-015) для auto test-plan.

### 6.2 Test-plan-as-code

Horizon 2–3:

- декларативний артефакт `test_policy.yml` на рівні репо/міста/тенанта, який описує:
  - які тести обов’язкові для яких `change_type`;  
  - мінімальні conformance-рівні перед publish;  
  - мапу `risk_level → required tests`.

CI читає `test_policy.yml` і автоматично обирає набір тестів.

---

## 7. Governance & Процес змін

### 7.1 RFC / ADR Flow

Будь-які MAJOR/значущі MINOR зміни в DSL/Registry:

- описуються в RFC/ADR (шаблони в PD-011-product-authoring-templates.md);  
- проходять review в Product Architecture + Governance;  
- мають явну секцію "Migration / Deprecation Plan".

### 7.2 Role of Governance Board

Governance Board (див. PD-013):

- затверджує MAJOR зміни схем;  
- затверджує policy-as-code правила, що впливають на DSL;  
- встановлює мінімальні conformance-вимоги до продуктів по категоріях/юрисдикціях;  
- контролює deprecation/EOL.

---

## 8. Multi-city / Multi-domain еволюція

На Horizon 2–3 Product DSL/Registry мають підтримувати:

- **multi-city**: різні конфігурації markets, політик, профілів, але спільне ядро DSL;  
- **multi-domain**: однакові базові патерни для travel, F&B, health, humanitarian, mobility;  
- можливість зовнішніх міст/партнерів під’єднуватися як federated registry clients.

Це впливатиме на:

- структуру Registry (tenant/city awareness);  
- способи версіонування/міграцій (можливі staggered upgrades по містах);  
- policy-as-code (різні правила для різних юрисдикцій з єдиною DSL-базою).

---

## 9. Summary

- PD-016 фіксує high-level roadmap еволюції Product DSL/Registry та політику змін.  
- DSL-схеми розвиваються за semver, із чітким поділом non-breaking vs breaking та обов’язковим deprecation-процесом.  
- Міграції будуються на патерні Expand→Migrate→Contract, з формальними migration descriptors.  
- Registry еволюціонує до multi-region/multi-tenant, із подіями, policy store та federated-патернами.  
- `pdsl` і CI поступово отримують функції diff/migrate/policy-check/test-plan-as-code.  
- Governance Board керує MAJOR/ризиковими змінами, встановлює вікна підтримки та conformance-вимоги.

