# PD-016 Roadmap Links – Impact on Teams, Cities, Vendors & Integrators v0.1

**Status:** Draft 0.1  
**Owner:** Product Architecture / Governance / City Ops

**Related docs:**  
- PD-016-roadmap-and-evolution.md  
- PD-015-* (testing, fixtures, links)  
- PD-014-* (examples, samples, links)  
- PD-013-governance-and-compliance-spec.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-003-registry-and-versioning-spec.md  
- PD-001/PD-002/PD-007/PD-009/PD-010

Мета — описати, **як roadmap еволюції Product DSL / Registry (PD-016)** впливає на:

- внутрішні команди;  
- міста / кластери (local operators, city nodes);  
- вендорів;  
- SDK / зовнішніх інтеграторів.

Фокус — на процесах, контрактних очікуваннях і "operating model" для різних стейкхолдерів.

---

## 1. Stakeholder Map

Основні групи:

- **Internal Core**:
  - Product / Product Architecture;  
  - Platform / DevEx / Registry / Data;  
  - QA / SRE / Security / Legal;  
  - City Operations / Network Expansion / BizDev.

- **External**:
  - City-level operators (franchise / партнери / municipal);  
  - Vendors (кафе, готелі, сервісні мережі, гуманітарні партнери);  
  - SDK consumers (мобільні/веб-команди, white-label клієнти);  
  - Third-party інтегратори (агрегатори, OTA, фінансові партнери, міські платформи).

Roadmap PD-016 визначає:

- що для них стабільне (backward-compat гарантії);  
- що може змінюватися (feature flow);  
- як виглядають вікна оновлень та процеси міграції.

---

## 2. Вплив на внутрішні команди

### 2.1 Product / Product Architecture

Обов’язки:

- формувати **H1/H2/H3 roadmap** для DSL/Registry;  
- описувати MAJOR / значущі MINOR зміни через RFC/ADR (PD-011);  
- визначати **deprecation / migration plans** (PD-016) разом із Platform/DevEx;  
- підтримувати **матрицю ризиків** (PD-013) для нових фіч.

Практичний ефект:

- Product-спеки мають явно вказувати:
  - чи зміна потребує DSL/Registry змін;  
  - чи це PATCH/MINOR/MAJOR;  
  - бажане вікно rollout по містах/кластерах;  
  - які продукти/EX-XXX виступають референтними кейсами.

### 2.2 Platform / DevEx / Registry

Обов’язки:

- розвивати `pdsl` і Registry відповідно до PD-016 (diff/migrate/policy-check);  
- реалізовувати **E→M→C міграції** для DB/Registry/DSL;  
- підтримувати **multi-region / multi-tenant** топологію Registry;  
- надавати city-командам tooling для локальних rollout’ів.

Практичний ефект:

- кожний roadmap-ітем PD-016 трансформується в:
  - набір CLI-можливостей (`pdsl diff/migrate/...`);  
  - CI jobs (PD-012, PD-015);  
  - migration descriptors (PD-003-templates);  
  - оновлення internal SDK / admin tooling.

### 2.3 QA / SRE / Security / Legal

- QA: мапить roadmap → оновлення **test-plan-as-code** / fixtures / coverage по EX-XXX (PD-015).  
- SRE: закладає в capacity & SLO плани врахування нових флоу (наприклад, multi-ledger settlement чи heavy city graphs).  
- Security/Legal: оцінюють ризики нових DSL-модулів (health/humanitarian/finance), задають додаткові conformance вимоги для L2.

### 2.4 City Operations / BizDev

- City Ops: планують rollout features / версій Registry **по містах/кластерах**;  
- BizDev: працюють із вендорами та партнерами по оновленню ToS/SLA/договорів, де roadmap змінює продуктову поведінку (наприклад, нові типи токенів, змінена логіка loyalty).

---

## 3. Вплив на міста / кластери

### 3.1 Version Trains per City

Roadmap PD-016 означає, що кожне місто живе в одному з **release-трейнів**:

- `City Train A` — "early adopters" (першими отримують новий MINOR/MAJOR);  
- `City Train B` — "standard" (після стабілізації);  
- `City Train C` — "conservative" (оновлюються лише при потребі / коли EOL).

Кожен city node має:

- поточну підтримувану `DSL major/minor` версію;  
- плановане вікно оновлення (H1/H2);  
- облікову політику EOL: коли місто більше не може залишатися на N-1.

### 3.2 City Registry & Policy

- Local Registry інстанс у місті синхронізується з центральним через **federated-патерн**;  
- Roadmap визначає, коли в місті з’являються:
  - нові типи профілів (наприклад, advanced ops для safety city);  
  - нові policy-модулі (health constraints, humanitarian flows);  
  - нові інтеграції (city data, mobility, payment rails).

### 3.3 Regional Constraints

- Для різних юрисдикцій roadmap може задавати різні **policy-as-code** набори (PD-013):
  - ЄС vs non-EU data residency;  
  - розбіжності в AML/KYC вимогах;  
  - локальні правила щодо health/food safety.

Це впливає на те, який subset DSL features може бути активований у конкретному місті.

---

## 4. Вплив на вендорів

### 4.1 Що стабільне для вендорів

З roadmap випливають **гарантії** для вендорів:

- типи токенів (entitlements, passes, loyalty points) мають стабільні контракти на рівні API/UX;  
- settlement-модель (як Trutta розраховується із вендорами) — стабільна в межах MAJOR-версії;
- звітність/експорт даних (формати, ключові поля) — змінюються лише через deprecation/E→M→C.

### 4.2 Що може змінюватися (керовано)

- конфігурації loyalty/promo;  
- рівні деталізації звітів;  
- додаткові атрибути у API (наприклад, параметри safety, geo, категорії);  
- типи сценаріїв (наприклад, нові journey-класи для типів гостей).

Це зміни **MINOR/PATCH** рівня, які не ламають базові флоу вендора.

### 4.3 Комунікація & вікна змін

Для MAJOR/сильної MINOR зміни, що зачіпають вендорів:

- вводиться **"Vendor Change Window"**:
  - pre-announcement (T-60/T-90 днів) з описом змін;  
  - тестове sandbox-середовище;  
  - onboarding матеріали (updated Vendor Onboarding Playbooks, див. VG-500 для Trutta);
- вендори отримують чіткий список:
  - що треба змінити (якщо вони інтегровані по API);  
  - які нові можливості з’являються;  
  - які features/старі схеми будуть відключені й коли.

---

## 5. Вплив на SDK та інтеграторів

### 5.1 Support Matrix

Roadmap задає **support matrix** для SDK/API:

- які версії DSL/Registry API підтримуються SDK (TS/Python/Go/...);  
- які MAJOR DSL/Registry версії ще віконі підтримки;  
- які deprecated features не рекомендується використовувати.

Ця матриця повинна бути публічно видимою (наприклад, у SDK docs) і регулярно оновлюватися.

### 5.2 Semver & Compatibility

Для інтеграторів формується чіткий контракт:

- SDK використовують semver, жорстко прив’язаний до:
  - DSL schema versions (`productdef:X.Y.Z`);  
  - Registry API версій;  
- **MINOR/PATCH** SDK-оновлення не повинні ламати існуючі інтеграції;  
- **MAJOR** оновлення SDK можуть вимагати змін у payload’ах/флоу, але зі зрозумілою migration guide.

### 5.3 Golden Samples & Contract Testing

Roadmap PD-016 + PD-014/PD-015 означає для SDK/інтеграторів:

- golden samples (EX-XXX) стають **еталоном payload’ів**;  
- інтегратори можуть будувати свої тести, опираючись на EX-XXX-fixtures та generated samples;
- при релізах SDK/Registry MAJOR:
  - golden samples вважаються джерелом правди;  
  - будь-який змістовний diff у семплах має migration guide.

### 5.4 External Integrators & Certification

На Horizon 2–3 roadmap підкріплює модель **сертифікації інтеграторів**:

- набір обов’язкових тестів (PD-015) на інтеграцію з Registry/TJM/Trutta/LEM;  
- conformance-рівень інтеграції (наприклад, `INTEGRATOR_L0/L1/L2`);  
- підтримка "approved integrator" списку.

---

## 6. Процеси комунікації змін

### 6.1 Release Channels

Roadmap PD-016 вимагає чітких каналів для змін:

- **Internal Release Notes** (для команд/міст):
  - перелік DSL/Registry змін (semver), impact, migration status;  
  - вказівка, які міста/тенанти затронуті;  
  - лінки на RFC/ADR, migration descriptors, test-плани.

- **Vendor Release Notes**:
  - тільки те, що зачіпає вендорів: UX/API/звітність/settlement;  
  - чіткі дедлайни й дії.

- **SDK / Integrator Release Notes**:
  - список змін у API і DSL, які важливі для інтеграторів;  
  - міграційні гіди, версійні таблиці, expected EOL дат.

### 6.2 Change Calendar

Під Governance (PD-013) ведеться **"Change Calendar"**:

- усі MAJOR/критичні MINOR зміни по DSL/Registry/API;  
- прив’язка до місяців/кварталів;  
- windows для cities/vendors/integrators;  
- status (planned/in-progress/completed/deferred).

---

## 7. Decision Rights & Escalation

Roadmap PD-016 інтегрується з governance (PD-013):

- **Product Architecture** вирішує: model/DSL design, первинну класифікацію зміни (PATCH/MINOR/MAJOR).  
- **Governance Board**:
  - затверджує MAJOR DSL/Registry зміни;  
  - встановлює мінімальні conformance-вимоги по сегментах продуктів/міст/вендорів;  
  - затверджує high-risk feature rollout по містах.

- **City Ops Leads**:
  - приймають рішення, коли місто переходить на новий train, у рамках глобальних вікон;  
  - відповідають за локальні комунікації з вендорами.

- **SDK / Integrations Lead**:
  - відповідальний за support matrix;  
  - управляє EOL SDK/ API версій для інтеграторів.

---

## 8. Summary

- PD-016-roadmap-and-evolution задає технічну еволюцію DSL/Registry; PD-016-roadmap-links показує, як це виливається в конкретні правила для команд, міст, вендорів та інтеграторів.  
- Команди отримують чіткі зони відповідальності: Product/Arch формують зміни, Platform/DevEx дають інструменти, QA/SRE/Legal замикають ризики, City Ops/BizDev керують rollout’ом.  
- Міста та вендори живуть у контрольованих release-трейнах з передбачуваними вікнами змін, SDK та інтегратори — у прозорій semver/ support matrix моделі.  
- Єдиний change calendar, release notes і governance-процеси роблять roadmap передбачуваним і керованим для всіх стейкхолдерів.

