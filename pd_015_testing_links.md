# PD-015 Testing Links – CI, Environments, Conformance v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / QA / Platform / Governance

**Related docs:**  
- PD-015-testing-and-conformance-suite.md  
- PD-015-test-fixtures.json  
- PD-014-examples-and-templates-library.md  
- PD-014-generated-samples-json  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-ci-templates.md  
- PD-003-registry-and-versioning-spec.md  
- PD-013-governance-and-compliance-spec.md  
- PD-016-roadmap-and-evolution.md

Мета — зафіксувати **зв’язки тестової системи** (PD-015) з:

- CI-пайплайнами (PR, main, release, nightly);  
- середовищами (local, ephemeral, staging, perf);  
- процесами сертифікації продуктів (conformance L0/L1/L2) та governance-гейтами.

---

## 1. Ролі середовищ

### 1.1 Local / Dev

- розробницьке оточення (локально або dev-кластери);  
- використовується для швидких `pdsl lint/test`;
- не вважається джерелом правди для conformance.

### 1.2 Ephemeral (Preview Environments)

- короткоживучі env, прив’язані до PR/branch;  
- розгортають мінімально необхідні сервіси (Registry + залежні TJM/Trutta/LEM stub/sandbox);  
- дозволяють запускати integration/e2e для конкретних змін;  
- всі дані — тестові, генеруються з EX-XXX/fixtures.

### 1.3 Staging

- довгоживуче середовище, максимально схоже на prod;  
- сюди деплояться з main/develop;  
- тут проходять сертифікаційні e2e сценарії для L1/L2;  
- staging Registry містить повний набір продуктів (з обмеженими токенами/платежами).

### 1.4 Perf / Chaos Environments

- спеціальні env для performance/chaos тестів;  
- можуть бути спільні зі staging при малих навантаженнях, але у ідеалі — окремі кластери;  
- дані генеруються синтетично, базуючись на EX-XXX.

### 1.5 Prod

- **не** є місцем для тестів, окрім строго контрольованих health-check/канарейок;  
- будь-які "тестові" дзвінки повинні бути явними, із маркуванням, і не впливати на користувачів.

---

## 2. Шари CI

### 2.1 PR-level CI

Тригер: будь-який PR, що змінює Product DSL / Registry / tooling.

Основні джоби (деталі в PD-012-ci-templates):

1. **Static / Schema**
   - `pdsl lint` на змінених файлах;  
   - `pdsl test schema --changed-only`.

2. **Semantic**
   - `pdsl test semantic --changed-only`;  
   - якщо змінені EX-XXX → підхопити відповідні `EX-XXX-fixtures.json`.

3. **Integration (опційно → обов’язково для medium+/high)**
   - деплой ephemeral env;  
   - `pdsl test integration --examples <list>` для зачеплених EX-XXX;  
   - використання відповідних `api_calls` + `runtime.event_sequences` із фікстур.

4. **Golden samples regression (schema_change)**
   - `pdsl generate-samples --changed-only`;  
   - структурний diff проти main;  
   - фейл PR, якщо diff неочікуваний/необґрунтований.

PR не можна змерджити, якщо:

- schema/semantic тести падають;  
- для high/critical змін не пройшли необхідні integration тести;  
- golden samples diff не підтверджений рев’ю.

### 2.2 Main / Develop CI

Тригер: merge у `main`/`develop`.

Дії:

- повний `pdsl test schema` + `pdsl test semantic` по всій бібліотеці;  
- набір integration/e2e сценаріїв для ключових EX-XXX (sanity suite);  
- деплой на staging (за умови green build).

### 2.3 Nightly / Weekly CI

- повний прогін integration/e2e по всіх EX-XXX з `status != draft`;  
- performance smoke/chaos для ключових сервісів;  
- conformance audit (перевірка, що активні продукти зберігають свій L0/L1/L2 статус).

Результати зберігаються в окремому логічному шарі (наприклад, `test_reports` та `product_conformance_history`).

---

## 3. Мапа: Тести ↔ Environments

Таблично (high-level):

- **Local**: lint + schema + частина semantic на змінених файлах;  
- **Ephemeral**: targeted integration/e2e для EX-XXX, яких стосується PR;  
- **Staging**: сертифікаційні e2e для L1/L2, regression пакети;  
- **Perf/Chaos**: performance/resilience, як описано в PD-015;  
- **Prod**: тільки read-only health-check / monitoring, без тестових сценаріїв.

Правило: будь-який тест, що змінює стан Registry/TJM/Trutta/LEM, має запускатись **лише** у non-prod середовищах.

---

## 4. Зв’язок з Registry & Publish Flow

### 4.1 Pre-publish Checks

Перед тим, як зміни потраплять у staging/prod Registry:

1. PR-level CI має бути green (schema + semantic +, за потреби, integration);  
2. `pdsl`-команда `pdsl registry dry-run-publish` (опис в PD-003/PD-012) проганяється в CI:
   - перевіряє, що усі продукти/ринкі, яких торкається publish, проходять L0/L1 вимоги;  
   - перевіряє відповідність governance/policy (legal/safety/city/vendor constraints);
   - валідуює узгодженість з Registry-схемами.

### 4.2 Staging Publish

Після merge в main:

- CI виконує `pdsl registry publish --env staging`;  
- запускається набір staging e2e тестів для EX-XXX, що змінились;  
- у разі фейлів:
  - зміни можуть бути автоматично відкочені (якщо це підтримується);  
  - або продукт помічається як `conformance_suspended: true` у staging.

### 4.3 Prod Publish

Prod publish дозволяється лише якщо виконані умови:

- staging e2e green для відповідних продуктів;  
- governance approvals (PD-013) для high/critical або L2;  
- немає відкритих блокуючих інцидентів, пов’язаних із цими змінами.

У CI це виражається як окремий job `prod-release`, який має:

- dependency на успішний staging job;  
- перевірку approvals та стану conformance.

---

## 5. Conformance & CI

### 5.1 Автоматичні conformance-checks

Для запитів на зміну conformance-рівня (L0/L1/L2) запускається спеціальний пайплайн:

- `pdsl test schema` + `pdsl test semantic` для всіх продуктів в scope;  
- `pdsl test integration --examples ...` на staging/ephemeral env;  
- для L2: додаткові negative сценарії + perf smoke.

Результати записуються в:

- таблицю `product_conformance` (частина Registry/ops-шару);  
- audit-log (див. PD-013): `governance.decision` з деталями.

### 5.2 Blocking Rules

- Продукти з `conformance_level < required_level` **не можуть**:
  - бути активовані в prod;  
  - використовуватись у public demo;  
  - бути виставлені як public templates у docs/SDK.

CI реалізує це як **policy-check**:

- перед publish / зміною статусу продукту викликається `pdsl policy-check --product <id>`;  
- якщо правило порушено — job фейлиться.

### 5.3 Degradation

У разі критичних інцидентів:

- OPS/SAFE можуть знизити conformance-рівень продукту або поставити `conformance_suspended: true`;  
- CI при наступних публікаціях враховує цей статус і блокує розгортання, поки не пройдуть повторні тести.

---

## 6. Звітність та Observability

### 6.1 Test Reports

Рекомендується мати централізований storage для результатів тестів:

- `test_reports` (таблиця/індекс):
  - `test_id`, `scope` (schema/semantic/integration/perf), `env`, `example_id`, `product_id`, `status`, `duration`, `artifacts_link`;

- `product_conformance_history`:
  - `product_id`, `version`, `conformance_level_before`, `conformance_level_after`, `changed_by`, `timestamp`, `reason`.

### 6.2 Dashboards

На базі цих даних будуються панелі:

- покриття тестами по продуктах/ринках;  
- поточні conformance-рівні та їх зміни;  
- стабільність тестів (flake rate, середня тривалість, тренди).

Governance використовує ці панелі для прийняття рішень щодо запуску нових продуктів/ринків.

---

## 7. Governance Hooks

### 7.1 PD-013 інтеграція

- Матриця ризиків (PD-013) → визначає, які тести обов’язкові в CI для кожного `change_type` + `risk_level`;  
- Access-matrix визначає, хто може override’ити test failures (якщо взагалі це дозволено);
- Audit-лог (`governance.decision`) фіксує ручні винятки.

### 7.2 Manual Gates

Для особливо чутливих кейсів (health/humanitarian/high FX):

- навіть за green CI необхідні ручні approvals (SAFE/SEC/FIN/GOV);  
- CI чекатиме, поки approvals не будуть виставлені (manual approval step).

---

## 8. Roadmap Links

У PD-016 планується деталізувати:

- повну інтеграцію з **policy-as-code** (OPA/Rego) для test gating;  
- auto-generated test plans з опису `change_type`/`risk_level`;  
- перехід від ручних матриць до декларативних `test_policy` артефактів у DSL;
- інтеграцію з multi-tenant / multi-city сценаріями (різні набори тестів для різних юрисдикцій).

---

## 9. Summary

- PD-015-testing-links зв’язує тестову модель (PD-015) з CI, середовищами та процесами conformance.  
- PR/main/nightly пайплайни мають чіткі обов’язкові тести залежно від типу змін і ризику.  
- Ephemeral/staging/perf env’и використовуються для різних типів тестів, prod залишається чистим від тестових сценаріїв.  
- Conformance-рівні продуктів контролюються через CI + governance, впливають на доступність продуктів у prod/demo/docs.  
- Дані тестів і conformance зберігаються централізовано й використовуються як ще один шар observability та управління ризиками.

