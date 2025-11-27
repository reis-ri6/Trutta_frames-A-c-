# PD-011 — Trutta Security, Privacy & Data Governance Baseline

**ID:** PD-011  
**Назва:** Trutta Security, Privacy & Data Governance Baseline  
**Статус:** draft  
**Власники:** arch, security, data, legal, ops  
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
- VG-8xx — Engineering & Runtime Guides (RLS/ABAC, infra)  
- VG-9xx — Logging, Auditing & Risk Analytics

---

## 1. Purpose

Цей документ фіксує **базові принципи безпеки, приватності та управління даними** для всієї екосистеми Trutta:

- що таке **критичні дані** й де вони допускаються;
- як розділяються **PII / health / фінансові** дані від DSL/доків;
- як працюють **доступи** (ролі, атрибути, RLS/ABAC);
- які є **мінімальні вимоги** до логування, аудиту, агентів.

Мета — зробити так, щоб:

- будь-який новий сервіс/репо/агент стартував **із правильних дефолтів**;
- складні регуляторні штуки (GDPR/HIPAA/AML) були легше досяжні.

---

## 2. Scope

### 2.1. Входить

- логічна модель класифікації даних;
- принципи зберігання / розділення шарів;
- базова модель доступів (ролі + атрибути);
- вимоги до логування, аудиту, секретів;
- guardrails для AI-/Codex-агентів.

### 2.2. Не входить

- детальні юр-документи (Privacy Policy, ToS, AML/KYC-мануали);
- конкретні технології (конкретний провайдер KMS, SIEM);
- повний threat-model (це окремий VG).

---

## 3. Data classification

### 3.1. Класи даних

1. **Public**  
   - маркетингові сайти, публічні PD/VG/CONCEPT-документи;  
   - анонімізовані агреговані метрики.

2. **Internal (non-sensitive)**  
   - технічна документація;  
   - DSL-конфіги, доменні моделі;  
   - неагреговані, але **анонімізовані** дані (без PII).

3. **Sensitive Business**  
   - внутрішні фінансові моделі;  
   - неагреговані usage-дані без PII, але з бізнес-ризиками;  
   - конфліктні комерційні дані (контракти з вендорами).

4. **Personal / PII**  
   - email/телефон/імʼя/ID-документи;  
   - будь-які звʼязки avatar ↔ реальна особа.

5. **Special / Health / Financial-regulated**  
   - медичні відомості (навіть агреговані, якщо є ризик deanonymization);  
   - платіжні дані, AML/KYC-поля.

### 3.2. Принцип розміщення

- `trutta_hub`, `trutta_city-*`, `trutta_project-*`  
  — **не містять PII/health/платіжних даних**; максимум — абстрактні профілі й агрегати.
- Окремі сервіси:
  - `identity-service`, `payment-service`, `kyc-service`, `health-bridge`  
  — беруть це на себе, з окремими репами, політиками, аудитом.

---

## 4. Avatars, identity & privacy

### 4.1. Аватар vs реальний користувач

- Всі TJM/ABC/DSL-рівні оперують **avatar_id**, а не user_id.
- Відповідність `avatar_id ↔ user_identity`:
  - зберігається **окремо**, в identity-сервісі;
  - недоступна з repos/DSL/data-lake.

### 4.2. Health & diet

- Health-constraints / diet-профілі:
  - описуються як **класи/типи** (`renal-friendly`, `low-sodium`, `gluten-free`);
  - не зберігають первинну медичну інформацію.
- Будь-яка логіка «персональних протоколів»:
  - живе в ізольованому health-сервісі з власним compliance-режимом.

---

## 5. Access control model

### 5.1. Ролі (RBAC)

Мінімальний набір (на концептуальному рівні):

- `viewer` — read-only до Public/Internal;
- `editor` — може редагувати DSL/документи в конкретних репо/проєктах;
- `operator` — доступ до runtime-конфігів, але не до всіх даних;
- `data-analyst` — доступ до агрегованих usage/analytics;
- `security/legal` — доступ до audit-логів, risk-панелей;
- `admin` — мінімально можлива кількість людей.

Ролі **привʼязуються до контексту** (hub / city / project / service).

### 5.2. Атрибути (ABAC)

Крім ролей, доступи визначаються:

- `project_id`, `city_id`;
- `data_class` (Public/Internal/Sensitive/PII/Special);
- `purpose` (ops/analytics/debug/legal).

Вимога: **будь-який доступ до PII/Special** повинен:

- бути явно обмежений по `purpose`;
- логуватися з `who/when/why`.

### 5.3. RLS / Column-level security

Для аналітичних/операційних БД:

- **Row-Level Security (RLS)** — обовʼязково:
  - фільтри по `project_id`, `city_id`, `role`;
- **Column-level security** — для полів, де може бути PII/спецдані:
  - доступ тільки через вьюхи;
  - пряме читання таблиць — лише для технічних служб під сильним контролем.

---

## 6. Data flows & boundaries

### 6.1. Між рівнями Trutta

- `hub` → `city` → `project`:
  - вниз ідуть моделі/схеми/патерни, а не персональні дані;
- `project`/`city` → `hub`:
  - повертаються тільки агреговані патерни, не raw-events з PII.

### 6.2. Зовнішні інтеграції

- Maps/OTA/places/menus/health-refs:
  - інжестяться в raw → canonical без PII;
- Payments/KYC/health-provider:
  - мають окремі контракти та сховища;
  - у Trutta-core потрапляють тільки:
    - `status` (verified / failed),
    - агреговані usage/реферальні дані.

---

## 7. Logging, audit & observability

### 7.1. Принципи

- **Все важливе → лог**, але:
  - зміст токенів/PII **маскується**;
  - повні payload-и PII — тільки в спеціалізованих сервісах.
- Мінімум:
  - `who` (actor/role, не обовʼязково user-id),
  - `what` (операція),
  - `where` (service/repo),
  - `when` (timestamp),
  - `why` (короткий reason для чутливих операцій).

### 7.2. Audit trails

- Окремі audit-стріми:
  - зміни DSL/PD/DOMAIN;
  - зміни у Token runtime (mint/burn/escrow/redeem);
  - доступи до PII/health/financial даних.
- Логи мають бути:
  - immutable;
  - з ретеншном, узгодженим з legal.

---

## 8. Tokens, wallets & fraud

### 8.1. Custody model

- Для кінцевих юзерів:
  - пріоритет — **non-custodial/light-custodial** моделі, де можливо;
- Для програм/грантів/гуманітарки:
  - можливі custody-accounts під чітким governance.

Будь-який custody-сценарій:

- має чіткий separation of duties (хто може:
  - випускати,
  - спалювати,
  - переміщати).

### 8.2. Anti-fraud baseline

- Ліміти:
  - по avatar/group/day/week/geo;
- Моніторинг:
  - аномальна активність (сплески редемпшенів, підозрілі маршрути);
- Escrow/conditional токени:
  - не релізяться без external proof (чекін, оракул, KYC-status).

---

## 9. Agents & AI safety

### 9.1. Доступи агентів

- Кожен агент (`*.agent.yaml`) має:
  - `can_modify` — whitelist директорій/типів файлів;
  - `read_only` — де можна тільки читати;
  - `forbidden` — де взагалі не торкається.

Агент **ніколи**:

- не отримує прямий доступ до PII/Special data;
- не має права змінювати:
  - security-конфіги,
  - secrets.

### 9.2. Prompt / content safety

- Системні промпти:
  - завжди включають посилання на PD-011 як baseline;
  - прямо забороняють:
    - виводити секрети;
    - спроби deanonymization;
    - зміну guardrail-конфігів.
- Doc-/repo-агенти:
  - працюють з документацією, а не з прод-даними;
  - будь-які міграції даних — тільки через визначені пайплайни.

---

## 10. Secrets & environments

### 10.1. Секрети

- Жодних секретів у:
  - Git-репо,
  - DSL-файлах,
  - PD/VG/DOMAIN/TEMPLATE.
- Секрети зберігаються:
  - у KMS/secret-manager;
  - під рознесеними ролями (infra vs app).

### 10.2. Environments

Мінімум:

- `dev` — сіндбокс, з штучними/анонімізованими даними;
- `stage` — максимально наближений до prod, але без реального PII;
- `prod` — реальні дані.

Правило: **ніяких тестів із реальним PII** у dev/stage.

---

## 11. Governance & evolution

### 11.1. Policy lifecycle

- PD-011 — **канонічний baseline**;
- детальні політики:
  - Security Handbook,
  - Data Protection Policy,
  - AML/KYC/Health-appendix  
  — оформлюються як окремі VG/LEGAL-документи.

### 11.2. Зміни

Будь-яка зміна, яка:

- додає новий клас чутливих даних,
- змінює модель доступів,
- відкриває новий клас токенів із регуляторними ризиками,

повинна:

- спочатку пройти через апдейт PD-011 (або додаткового security-PD);
- потім — через оновлення конкретних схем, кодів, пайплайнів.

---

PD-011 — точка відліку для **всіх рішень про дані й безпеку** в Trutta.  
Якщо якась імплементація не сумісна з цим документом — або вона помилкова, або PD-011 має бути явно переглянутий і оновлений.
