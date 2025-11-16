# PD-013 Governance & Compliance Spec v0.1

**Status:** Draft 0.1  
**Owner:** Governance Council / Platform Architecture / Legal & Compliance

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-links.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-cli-command-reference.md  
- PD-012-ci-templates.md  
- PD-012-tooling-links.md

Мета документа — визначити **модель governance та комплаєнсу** для Product DSL / Registry:

- ролі й зони відповідальності;  
- класифікацію змін та risk-модель;  
- approval-процеси (стандартні та emergency);  
- політики комплаєнсу, audit trail і retention;  
- базові принципи безпеки та розподілу доступів.

Фокус: **governance навколо DSL/Registry і пов’язаних runtime-ефектів**, а не повний корпоративний GRC.

---

## 1. Принципи Governance

1. **Single source of truth**  
   Усі продукти/профілі/політики описані в Product DSL (git). Registry — синхронізований, read-оптимізований шар.

2. **Change is code**  
   Будь-яка зміна продукту = зміна в DSL (код/конфіг) + PR + CI → Registry. Ніяких ad-hoc змін у проді.

3. **Risk-based governance**  
   Рівень контролю залежить від ризику зміни (low/medium/high/critical), а не від внутрішніх політик команди.

4. **Segregation of duties (SoD)**  
   Одна людина не має повного контролю над change lifecycle: author ≠ sole approver ≠ deployer.

5. **Audit by design**  
   Кожна зміна трасується до PR, commit’а, snapshot’а, publish-івенту та, за потреби, до інцидентів.

6. **Compliance by default**  
   Стандарти privacy/PII, юридичні та фінансові вимоги вбудовані в DSL/Registry-процеси.

---

## 2. Ролі та зони відповідальності

### 2.1 Основні ролі

Назви можуть мапитися на реальні посади, тут — логічні ролі governance.

- **PO (Product Owner)**  
  Власник бізнес-логіки продукту, відповідальний за цінність та scope змін.

- **PA (Product Architect / Solution Architect)**  
  Відповідає за архітектурну цілісність продукту, сумісність з DSL/Registry, non-functional вимоги.

- **DA (Data Architect / Analytics Lead)**  
  Відповідає за data-модель, аналітику, unit economics, коректність фінансових/метричних ефектів.

- **FIN (Finance / Revenue Ops)**  
  Контролює фінансові моделі, ціноутворення, revenue-split, дискрунти/промо.

- **OPS (Operations / SRE)**  
  Власник SLO/SLI/SLA, incident management, capacity/availability ризиків.

- **SAFE (Safety & Quality / Risk)**  
  Відповідає за safety-пороги, якість сервісу, спеціально для health/safety-критичних продуктів.

- **SEC (Security / Privacy / Legal)**  
  Контролює privacy, PII, AML/KYC boundary, юридичні обмеження (включаючи локальні).

- **GOV (Governance Council)**  
  Мета-рівень: затверджує правила governance, політики risk-класифікації, розв’язує конфлікти між ролями.

- **DevEx / Platform**  
  Власник `pdsl` tooling, CI шаблонів, Registry інтерфейсу (у частині DSL-контрактів).

### 2.2 Ролі по артефактах

- **Product Spec / ProductDef** — PO (owner), PA/DA (co-owner).  
- **Pricing / Financial Profiles** — FIN (owner), PO/DA (co-owner).  
- **Ops/Safety/Quality Profiles** — OPS/SAFE (owners), PO/PA (co-owner).  
- **Policies (ops_policies, safety_overrides, quality_gates)** — OPS/SAFE/SEC (co-owners).  
- **DSL Schemas / Registry contracts** — DevEx/Platform, з GOV-оверсайтом.

---

## 3. Класифікація змін (Change Types & Risk Levels)

### 3.1 Типи змін

1. **Product-level changes**
   - новий продукт;  
   - нова версія існуючого продукту;  
   - зміна composition/experience (journeys, включені послуги).

2. **Pricing & Financial changes**
   - базові ціни, тарифи;  
   - промокампанії та знижки;  
   - revenue-split, комісії, fee-структури.

3. **Ops / Safety / Quality changes**
   - SLO/SLI/SLA;  
   - safety thresholds;  
   - якісні гейти, escalation-політики.

4. **Policy / Compliance changes**
   - зміни в privacy-рівнях;  
   - AML/KYC boundary;  
   - PII-обмеження;  
   - whitelist/blacklist по географіях/сегментах.

5. **Schema / DSL / Registry contract changes**
   - зміни структур DSL (нові поля, типи, enums);  
   - зміни API contracts Registry.

### 3.2 Risk Levels

Базова градація (може деталізуватися GOV):

- **Low**  
  Косметичні зміни, що не впливають на гроші, безпеку чи права користувача. Приклади: опис/копірайт, не публічні флаги.

- **Medium**  
  Обмежений фінансовий/операційний вплив, без істотних ризиків безпеки. Приклади: невеликі зміни цін, зміни не-критичних SLO.

- **High**  
  Значний фінансовий вплив, зміни SLA, зміни unit economics, нетривіальні поведінкові зміни, комплекси профілів.

- **Critical**  
  Зміни, що можуть:  
  - вплинути на safety/health користувача;  
  - створити істотний фінансовий/юридичний ризик;  
  - порушити регуляторні вимоги;  
  - масово вплинути на активні продукти/користувачів/міста.

### 3.3 Мапа Type → мінімальний Risk

- Новий продукт (pilot, обмежений ринок) → medium.  
- Новий продукт (масовий rollout) → high.  
- Зміна цін <±5% на обмеженому сегменті → medium.  
- Масова зміна цін / FX-поведінки → high/critical.  
- Зміни safety thresholds, SLA → high/critical.  
- Зміни в privacy/AML/KYC політиках → critical.  
- Breaking changes у схемах/Registry API → high/critical.

---

## 4. Approval-процеси

### 4.1 Стандартний approval flow

Кожна зміна йде через:

1. **Authoring** — PR у DSL-репо (див. PD-011), з:
   - product-spec;  
   - ADR (за потреби);  
   - diff (auto з PD-012);  
   - risk-level (оцінка автора).

2. **Auto-classification** (опційно) — tooling може підказувати ризик за евристиками.  
3. **Approvals по ролях** залежно від risk-level.

### 4.2 Матриця approvals (мінімальні вимоги)

#### Low risk

- Required: PO + PA або DA.  
- Optional: FIN/OPS залежно від типу зміни.  
- GOV не залучається.

#### Medium risk

- Required:  
  - PO  
  - PA  
  - один із: FIN або DA (залежно від фінансового впливу)  
- OPS/SAFE — за потреби (для ops-affecting змін).  
- SEC — не обов’язковий, якщо немає privacy/AML/SLA компонентів.

#### High risk

- Required:  
  - PO  
  - PA  
  - FIN  
  - OPS  
- SAFE — обов’язково, якщо продукт health/safety-критичний.  
- SEC — обов’язково, якщо зміни торкаються даних, privacy, AML/KYC.  
- GOV — пасивний oversight (може вимагати ескалацію).

#### Critical

- Required:  
  - усі, як для High (PO, PA, FIN, OPS, SAFE/SEC де релевантно);  
  - GOV (або його делегат) як останній approval.  
- Можливий окремий change advisory board (CAB) для затвердження.

### 4.3 SoD правила

- Автор PR **не може бути єдиним approver’ом**.  
- Для High/Critical змін мінімум **двоє незалежних approver’ів** із різних ролей.  
- Publish у production виконується **тільки CI**, а не локальний користувач (див. PD-012).

### 4.4 Change windows

Для High/Critical змін:

- визначаються дозволені часові вікна розгортання (поза піками навантаження);  
- план релізів публікується заздалегідь (особливо якщо зачіпає оплату або доступність сервісу);  
- OPS має право накласти freeze.

---

## 5. Emergency-процеси

### 5.1 Типи emergency

1. **Safety emergency** — ризик для здоров’я/безпеки користувачів.  
2. **Financial emergency** — некоректні тарифи/FX, що можуть призвести до великих втрат.  
3. **Operational emergency** — масові фейли/інциденти через некоректну конфігурацію продуктів.

### 5.2 Emergency actions

- `stop-sell` для конкретних продуктів/ринків;  
- тимчасові `safety_overrides`;  
- вимкнення промокампаній;  
- зміна дефолтних маршрутів/профілів у runtime.

### 5.3 Правила

- Emergency зміни можуть **обходити стандартний PR-цикл**, але:
  - всі emergency-actions логуються як окремий тип подій у Registry/ops-логах;  
  - після стабілізації **обов’язковий** follow-up PR у DSL, який кодифікує постійні зміни;  
  - CAB / GOV розглядає інцидент пост-фактум (post-mortem).

- Право запуску emergency-actions має вузький список ролей (наприклад, Duty OPS / SAFETY lead), регламентований окремо.

---

## 6. Compliance-політики

### 6.1 Data & Privacy

- Product DSL **не повинен містити PII** чи конфіденційних персональних даних.  
- Усі посилання на користувачів/сегменти — агреговані/анонімізовані профілі.  
- Registry зберігає конфіг і профілі, але не персональні журнали/сесії.

SEC/Legal контролюють:

- відповідність локальним законам (GDPR, інші privacy-режими);  
- обмеження щодо використання геоданих та health-related атрибутів;  
- списки заборонених країн/юрисдикцій.

### 6.2 AML/KYC boundary

- Product DSL може описувати **типи продуктів**, що вимагають KYC/KYB/AML-check, але не деталі користувачів.  
- Реальні AML/KYC процеси — в окремих системах, які тільки читають конфіг з Registry (наприклад, прапорець `requires_kyc`).

### 6.3 Legal terms / jurisdiction

- Для продуктів, чутливих до локального законодавства, DSL/Registry тримає:
  - jurisdiction / legal-entity;  
  - посилання на актуальні terms/policies;  
  - обмеження для віку/категорій користувачів.

SEC/Legal мають право блокувати publish продуктів без валідних легальних атрибутів.

### 6.4 Logging & Monitoring

- Усі publish-операції фіксуються з metadata: commit, автор, env, snapshot-id, diff-summary.  
- Доступ до audit-логів обмежений, але самі логи мають тривалий retention (напр., 5+ років або за вимогами регулятора).

---

## 7. Audit Trail & Retention

### 7.1 Audit Trail

Комбінується як мінімум з трьох джерел:

1. **Git / PR** — історія DSL змін.  
2. **Registry migration-log** — історія publish’ів (env, snapshot-id, diff-summary).  
3. **Runtime incidents / analytics** — опціонально лінкується до версій продуктів.

Кожен запис у migration-log посилається на:

- git commit SHA;  
- PR ID;  
- env;  
- timestamp;  
- авторів/approver’ів.

### 7.2 Retention

Мінімальний базовий рівень (може бути підвищений Legal):

- DSL-репозиторій — повна історія (без видалень гілок main/tags).  
- migration-log / publish events — ≥ 5 років або довше (регуляторні вимоги).  
- audit-логи доступу до Registry (хто що читав/писав) — ≥ 2 роки.

---

## 8. Security & Access Control

### 8.1 Доступ до DSL-репо

- Використовується role-based доступ (GitHub Teams або аналог):  
  - Autoren (PO/PA/DA/FIN/OPS/SAFE/SEC) мають write/PR доступ.  
  - Read-only для ширшого кола.  
- Protected branches (main/release) — тільки через PR, з обов’язковими checks.

### 8.2 Доступ до Registry

- Публікація в env → тільки через CI service accounts.  
- Read-доступ до prod Registry обмежений, можливе шифрування на рівні БД.  
- dev/staging/preview можуть мати ширший read-доступ, але без реальних PII.

### 8.3 Secrets management

- Токени Registry зберігаються тільки в secrets менеджері CI (GitHub Secrets, Vault і т.п.).  
- `pdsl` не логує токени, консольний вивід проходить маскування.

---

## 9. Еволюція Governance

- Будь-які зміни в governance-моделі (цей документ) проходять через той самий цикл: PR, risk-оцінка, approvals, ADR.  
- PD-016-roadmap міститиме етапи еволюції governance (наприклад, перехід до policy-as-code, OPA, автоматизованих risk-скористів).  
- GOV щонайменше раз на рік проводить review політик, risk-моделі та фактичних інцидентів.

---

## 10. Summary

- Governance навколо Product DSL / Registry побудований як **risk-based, code-centric, audit-friendly**.  
- Ролі (PO/PA/DA/FIN/OPS/SAFE/SEC/GOV) мають чіткі зони відповідальності та матрицю approvals по рівнях ризику.  
- Всі зміни проходять через PR + CI + Registry, emergency-процеси допускаються, але завжди закриваються DSL-оновленнями.  
- Compliance-політики (privacy, AML/KYC, legal terms) інтегровані в DSL/Registry-модель і контролюються SEC/Legal.  
- Audit trail, retention, SoD та контроль доступу роблять еволюцію DSL/Registry прозорою та керованою, без хаотичних змін у проді.

