# PD-019 — Trutta Environments, Deployment & DevOps Blueprint

**ID:** PD-019  
**Назва:** Trutta Environments, Deployment & DevOps Blueprint  
**Статус:** draft  
**Власники:** arch, platform, sre, eng  
**Повʼязані документи:**  
- PD-001 — Product DSL Blueprint  
- PD-002 — Concepts & Glossary  
- PD-003 — DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-008 — Agent & Automation Layer  
- PD-009 — City & Project Instantiation Model  
- PD-010 — Repositories & Docs Conventions  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-012 — Runtime & Service Architecture  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint  
- PD-018 — Integrations & External Ecosystem Model  
- VG-800+ — Engineering / C4 / Contracts  
- VG-1000+ — Ops, SRE, Backups, Incidents

---

## 1. Purpose

Цей документ задає **канонічну модель середовищ, деплою та DevOps** для Trutta:

- які є **рівні середовищ** (hub / shared / city / project);
- як працюють:
  - CI/CD pipelines;
  - release- та rollout-стратегії;
  - observability, SLO/SLI, error budgets;
- як усе це підвʼязано під:
  - runtime-сервіси (PD-012),
  - data-платформу (PD-017),
  - аналітику/евенти (PD-016),
  - безпеку (PD-011).

Мета — зробити так, щоб:

> будь-який сервіс/місто/проєкт Trutta деплоївся й спостерігався **однаково**, без «ручної магії».

---

## 2. Scope

### 2.1. Входить

- модель середовищ (environments);
- базові DevOps-принципи;
- CI/CD та release-патерни;
- observability / SRE-базис;
- підхід до city/project-інстансів (PD-009) на рівні інфри.

### 2.2. Не входить

- конкретні YAML/PIPELINE-конфіги (йдуть у VG-8xx/VG-1000);
- детальна інструкція по хмарному провайдеру;
- окремі runbooks по інцидентам (VG-1000).

---

## 3. Environment model

### 3.1. Логічні рівні

1. **Hub Environments**  
   - `hub-dev`, `hub-stg`, `hub-prod`  
   - ядро Trutta: DSL, Token runtime, ABC, TJM, Data-платформа, Integrations-гейтвеї.

2. **Shared / Sandbox Environments**  
   - `sandboxes/*` — тимчасові/персональні/фічеві середовища:
     - PR-preview для frontend/сервісів;
     - експериментальні пайплайни/агенти.

3. **City Environments** (PD-009)  
   - `city-<code>-dev`, `city-<code>-stg`, `city-<code>-prod`  
   - логіка й інфра для конкретного міста/кластеру.

4. **Project Environments**  
   - `project-<code>-dev/stg/prod`  
   - Sospeso/BREAD/health-пілоти як інстанси поверх hub+city.

### 3.2. Мінімальний набір середовищ

Для будь-якого важливого контуру:

- `dev` — швидка розробка, relaxed безпека;
- `stg` — максимально близька до prod, інтеграційні тести;
- `prod` — бойове, жорсткі політики, SLO/SLI.

Sandbox-и — додатково, але не заміна `dev/stg/prod`.

---

## 4. DevOps principles

1. **Infrastructure as Code (IaC)**  
   Вся інфра (кластери, БД, черги, secrets-менеджмент) — описана кодом.

2. **Trunk-based development + feature flags**  
   Мінімум довгоживучих гілок; поведінка — через фіче-флаги, а не форки коду.

3. **GitOps для середовищ**  
   Стан середовищ визначається Git-репами з декларативними маніфестами.

4. **Immutable artifacts**  
   Один і той самий артефакт (контейнер / image) йде через dev → stg → prod; ніяких «збираємо заново для prod».

5. **Progressive delivery**  
   Blue/green, canary, per-city/per-tenant rollout, а не «одним махом на весь світ».

6. **Observability first**  
   Логування, метрики, трейси — не «додаткова опція», а частина design-стейджа.

---

## 5. CI/CD pipelines

### 5.1. CI (Build & Test)

Для кожного сервісу/пакету:

- **triggers**:
  - PR → повний CI (lint, unit, basic контрактні тести);
  - push в main → збірка артефакту + smoke-тести.

- **stages**:
  1. Lint & static analysis  
  2. Unit tests  
  3. Contract/API tests (де можливо)  
  4. Build artifacts (container/image/package)  
  5. Security scans (dependencies, образи)  

Вихід: **immutable artifact**, з мітками:

- git commit / tag;
- PD/VG версія (де релевантно);
- environment compatibility.

### 5.2. CD (Deploy)

Мінімальний патерн:

- merge в main → автоматичний деплой в `dev` (hub/city/project);
- manual/controlled promotion → `stg`;
- перевірка health/SLO gates → промо в `prod`.

GitOps-вʼю:

- зміна версії/конфіга = PR у репо маніфестів;
- merge → оператор застосовує зміни в кластері.

---

## 6. Release & rollout strategy

### 6.1. Release units

Реліз — не обовʼязково «весь моноліт». Виділяємо:

- **Core Hub Release**:
  - DSL, Token runtime, ABC, TJM, базова Data/Analytics інфра;
- **City Release**:
  - city-graph, вендор-мережа, city-програми;
- **Project/Program Release**:
  - конфіги Sospeso/BREAD/health-програм, UX-специфіка.

Кожний release unit має:

- changelog;
- affected PD/VG/DOMAIN-документи;
- список міграцій (база/DSL/конфіги).

### 6.2. Rollout patterns

- **Canary**:
  - випускаємо на обмежену підмножину:
    - 1–2 міста;
    - subset tenant-ів;
  - моніторимо ключові SLI/бізнес-метрики.

- **Blue/Green** (для критичних компонентів):
  - паралельні версії, перемикання трафіку після валідації.

- **Per-city staged rollout**:
  - продовжуємо відкочувати/оновлювати по містах/проєктах, а не глобально.

---

## 7. Observability & SRE

### 7.1. Сигнали

Три основні стовпи:

1. **Logs**:
   - структуровані;
   - кореляція з request-id / journey-id / token-instance-id.

2. **Metrics**:
   - технічні (latency, error rate, saturation);
   - продукт/бізнес (tokens redeemed, journeys completed, SLA виконання).

3. **Traces**:
   - наскрізні трейси через сервіси:
     - особливо для token-runtime, journey-engine, payment/integration gateways.

### 7.2. SLO / SLI

Ключові SLO:

- для **end-user UX**:
  - доступність core-UX (chat/gateway);
  - latency ключових операцій (claim, redeem, journey-step).

- для **Token runtime / Program flows**:
  - % успішних операцій;
  - час до фінального confirm/reject.

- для **Integrations**:
  - карта SLO по plane-ам (maps, payments, KYC, OTA).

VG-1001 деталізує формат SLO/SLA-доків.

### 7.3. Error budgets & інциденти

- для кожного SLO — визначений error budget;
- порушення → зміна пріоритетів:
  - менше feature work, більше reliability work;
- інциденти:
  - оформлюються через стандартні runbooks (VG-1000 series);
  - постмортеми — обовʼязкові для серйозних збоїв.

---

## 8. Data & migrations

### 8.1. Expand → Migrate → Contract

Для схем БД / DSL / graph / events:

1. **Expand** — додаємо нові поля/таблиці/події, joint-compatible;
2. **Migrate** — backfill/двошаровий runtime, агенти/сервіси вміють працювати з обома версіями;
3. **Contract** — чистимо старі поля/шляхи тільки після повного переходу.

### 8.2. Міграції по рівнях

- **Hub**:
  - спочатку hub-сервіси (DSL, tokens, ABC);
  - далі — city/project-конфіги.

- **City/Project**:
  - локальні таблиці/graph/shards;
  - міграції повинні бути:
    - поетапні;
    - з можливістю перервати/повторити.

---

## 9. Security & secrets

### 9.1. Secrets management

- ніяких секретів у репо;
- окремий secrets-store:
  - інтеграційні ключі;
  - credentials для БД/PSP/KYC.

Привʼязка:

- через service accounts / OIDC;
- мінімальні scopes (need-to-know).

### 9.2. Hardening

- базові політики:
  - TLS скрізь;
  - mutual TLS/zero-trust усередині кластера (де має сенс);
  - регулярні scans/patching (частина CI/CD).

PD-011 задає рамки, VG-1002/1003 — деталізують.

---

## 10. City & Project instantiation (infra side)

### 10.1. City template

Кожне нове місто:

- створюється з **темплейту інфри**:

```txt
infra/city-template/
  cluster-config/
  db-instances/
  data-pipelines/
  observability-dashboards/
  access-policies/
```

* параметризується:

  * `city_code`, `region`, обʼєм;
  * інтеграційні параметри (maps/OTA/payments).

### 10.2. Project template

Аналогічно для Sospeso/BREAD/health-проектів:

* типові сервіси/конфіги;
* підключення до hub+city.

---

## 11. Repositories & documentation

У `trutta_hub`:

```txt
docs/pd/
  PD-019-trutta-environments-deployment-and-devops-blueprint.md

docs/vg/
  VG-800-c4-architecture-and-services-map.md
  VG-802-db-migrations-and-rls.md
  VG-1000-ops-and-incidents-runbook.md
  VG-1001-slo-sli-and-alerting.md
  VG-1003-backup-and-dr.md
  VG-8xx-ci-cd-and-gitops-patterns.md
```

У city/project-репах:

```txt
infra/
  envs/
    dev/
    stg/
    prod/
  ci-cd/
    pipelines.yaml
docs/vg/
  VG-8xx-<city>-infra-and-environments.md
  VG-1000-<city>-ops-runbook.md
```

---

## 12. Відношення до інших PD

* PD-012 каже, **які** runtime-сервіси існують; PD-019 — **де та як** вони живуть у середовищах.
* PD-017 описує data-planes; PD-019 — як їх деплоїти, мігрувати й моніторити.
* PD-016 визначає події/метрики; PD-019 — як вони використовуються в observability/SRE.
* PD-009 визначає city/project-інстанси; PD-019 — шаблони їх інфри та циклів релізів.

PD-019 фіксує: **Trutta розгортається як керований продукт з передбачуваними середовищами й релізами, а не як набір разових деплоїв у різних містах.**
