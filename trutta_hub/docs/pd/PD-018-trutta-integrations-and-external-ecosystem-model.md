# PD-018 — Trutta Integrations & External Ecosystem Model

**ID:** PD-018  
**Назва:** Trutta Integrations & External Ecosystem Model  
**Статус:** draft  
**Власники:** arch, eng, data, legal, ops  
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
- PD-010 — Repositories & Documentation Conventions  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-012 — Runtime & Service Architecture (High-level)  
- PD-013 — Vendor & Service Network Model  
- PD-014 — Programs, Subsidies & Funding Flows  
- PD-015 — UX, Channels & Experience Model  
- PD-016 — Analytics, Events & Measurement Model  
- PD-017 — Data Platform & Knowledge Graph Blueprint  
- VG-801 — OpenAPI/GraphQL Contracts  
- VG-1500..1502 — Integrations (Maps/Routing, Reservations/Events, Transit & City Data)

---

## 1. Purpose

Цей документ задає **канонічну модель інтеграцій Trutta** з зовнішнім світом:

- які є **класи інтеграцій**;
- через які **шари/сервіси** вони проходять;
- які **data & security межі** застосовуються;
- як інтеграції співвідносяться з:
  - DSL (PD-001/003),
  - Token runtime (PD-005/012),
  - Data Platform (PD-017),
  - TJM/ABC (PD-006/007),
  - Vendor Network (PD-013),
  - Programs/Funding (PD-014).

Мета — щоб будь-яке нове місто/проєкт могло підключати карти, OTA, POS/PMS/HIS, payments, KYC, блокчейн тощо **однаково структуровано**, а не як набір спеціальних кейсів.

---

## 2. Scope

### 2.1. Входить

- логічна класифікація інтеграцій;
- integration-planes та типові патерни;
- high-level контракти (inbound/outbound);
- принципи безпеки/даних для інтеграцій.

### 2.2. Не входить

- конкретний вибір провайдерів (Google vs Mapbox, Stripe vs Adyen тощо);
- деталізовані OpenAPI/GraphQL схеми (йдуть у VG-801, VG-1500+);
- деталі конкретних ETL-пайплайнів (VG-8xx).

---

## 3. Integration planes

Інтеграції групуються в **площини**:

1. **Maps, Routing & City Data Plane**  
   - карти, геокодинг, маршрути, транспорт, open-data міст.

2. **Travel & Hospitality Supply Plane**  
   - OTA/GDS/канальні менеджери, екскурсії, події.

3. **Vendor Backend Plane**  
   - POS, PMS, HIS, інші системи вендорів.

4. **Payments, Wallets & Settlement Plane**  
   - фіатні платежі, стейблкоїни, payout-вендорам.

5. **Identity, KYC/KYB & Compliance Plane**  
   - auth, соціальний логін, KYC/KYB, санкційні/AML-перевірки.

6. **Messaging & Channels Plane**  
   - месенджери, email/SMS/push, нотифікації.

7. **Health & Sensitive Domains Plane**  
   - медичні/нутрієнтні джерела, клініки, страхові (на рівні, сумісному з PD-011).

8. **Blockchain & Token Infrastructure Plane**  
   - ланцюги, смарт-контракти, мости, custody/кошельки.

9. **AI & Tooling Plane**  
   - LLM/embeddings/векторні сервіси, зовнішні AI-інструменти.

Кожна інтеграція має:

- свій plane;
- тип (inbound/outbound/bidirectional);
- контракт (data contract + SLA);
- policy (що дозволено/заборонено).

---

## 4. Principles

1. **Adapter-first**  
   Немає «raw SDK у коді». Все — через адаптери/edge-сервіси, описані в VG/DOMAIN.

2. **Data minimization**  
   Trutta забирає тільки те, що потрібно:
   - без зайвого PII/health/платіжних полів (PD-011).

3. **Contracts over hacks**  
   Кожна інтеграція має явно описаний:
   - формат, частоту, SLA, error-handling, retry-полісі.

4. **Separation of planes**  
   Maps ≠ Payments ≠ KYC ≠ OTA. Мікс нестабільних залежностей в одному сервісі — заборонений.

5. **Replaceable providers**  
   Жоден провайдер не закодований в бізнес-логіку. Все — через конфіг/адаптер; зміна провайдера не ламає доменну модель.

---

## 5. Maps, Routing & City Data

### 5.1. Що інтегруємо

- базові карти/геокодинг;
- POI/places;
- маршрути (пішки, транспорт, вело тощо);
- GTFS/transport feeds;
- city open-data (зони, парки, обмеження, safety).

### 5.2. Роль у Trutta

- TJM (маршрути/мікро-journeys) (PD-006);
- Vendor Network (ServicePoint гео, зони, кластеризація) (PD-013);
- city-graph (PD-004/017);
- UX-карти (PD-015).

### 5.3. Патерн

- окремі `maps-adapter-*` сервіси:
  - `maps-routing-adapter`,
  - `city-data-adapter`,
  - `transit-data-adapter`.
- Ingestion → raw → canonical (PD-017);
- query API для:
  - journey-engine;
  - city-routing-service;
  - UX.

---

## 6. Travel & Hospitality Supply

### 6.1. Що інтегруємо

- OTA/GDS (hotels, tours);
- локальні агрегатори (екскурсії, активності, events);
- власні city- або партнёрські каталоги.

### 6.2. Роль

- seed/оновлення canonical Hotels/Rooms/Events (PD-004/017);
- candidate-вендори для онбордингу (PD-013);
- комбінація з Trutta-продуктами (мікс OTA-резервацій і токенів).

### 6.3. Патерн

- `supply-adapter-*`:
  - інжест даних → raw → canonical;
  - no direct runtime coupling для критичних journey-операцій (тільки через свої сервіси).

---

## 7. Vendor Backend (POS/PMS/HIS)

### 7.1. Що інтегруємо

- POS/касові системи;
- PMS (property management);
- HIS/медичні системи;
- інші бізнес-системи вендора.

### 7.2. Роль

- підтвердження редемпшену;
- звірка транзакцій;
- capacity/availability (опційно для dynamic-патернів);
- медичні/процедурні «слоти» (health сценарії).

### 7.3. Патерн

- `vendor-integration-gateway`:
  - мости між `vendor-portal-service` / `token-engine-service` (PD-012) і backend вендора;
  - contracts:
    - confirm/reject token redemption;
    - optional usage stats.

PD-011:

- жорсткі межі для health/POS-даних;
- Trutta не зберігає «все», а тільки агреговані або строго обмежені дані.

---

## 8. Payments, Wallets & Settlement

### 8.1. Що інтегруємо

- PSP (карти, е-wallets);
- стейблкоїни/крипто-процесори;
- payout-платформи вендорам;
- внутрішні/зовнішні гаманці.

### 8.2. Роль

- оплата co-pay частини токенів (PD-014);
- settlement вендорів (після редемпшенів);
- поповнення FundingPool-ів.

### 8.3. Патерн

- `payment-gateway-service`:
  - прийом платежів від користувачів/донорів;
- `settlement-gateway-service`:
  - виплати вендорам/партнерам;
- чіткий поділ фінансових і entitlement-операцій:
  - Token-операції не «гуляють» напряму по PSP;
  - PSP бачить тільки суми/контракти, не повну DSL/entitlement-структуру.

---

## 9. Identity, KYC/KYB & Compliance

### 9.1. Що інтегруємо

- auth-провайдери (social, email, SSO);
- KYC/KYB-сервіси;
- AML/sanctions-screening.

### 9.2. Роль

- верифікація реальної особи/бізнесу;
- підтвердження eligibility для спец-програм (де це необхідно за законом);
- мінімізація дублювання AML/KYC по містах та програмах.

### 9.3. Патерн

- окремий `identity-service` + `kyc-service`:
  - PD-011: PII/KYC дані не потрапляють у Trutta core/аналітику;
  - core бачить тільки статус:
    - `kyc_status`, `kyb_status`, `risk_flags`.

---

## 10. Messaging & Channels

### 10.1. Що інтегруємо

- Telegram/WhatsApp/інші месенджери;
- email/SMS/push-провайдери;
- webhook-и/подієві шини.

### 10.2. Роль

- канали для UX (PD-015);
- нотифікації про токени, програми, маршрути;
- інтерфейс для ops/міст/вендорів.

### 10.3. Патерн

- `channel-gateway-service`:
  - один вхідний API (для UX/агентів);
  - під капотом — адаптери під месенджери/канали;
- канали не мають доступу до доменної логіки:
  - тільки передачі повідомлень і callback-ів.

---

## 11. Health & Sensitive Domains

### 11.1. Що інтегруємо

- нутрієнтні бази (FDA/локальні);
- health guidelines (клініки, асоціації);
- (опціонально) клініки/санаторії/страхові — на окремих умовах.

### 11.2. Роль

- побудова health-friendly продуктів (PD-004/005/014);
- рекомендації з харчування/процедур для health-програм;
- довідниковий шар, не медична система.

### 11.3. Патерн

- **тільки довідкові/агреговані дані** в Trutta core;
- будь-який персональний health-контекст:
  - або залишається на стороні health-провайдера;
  - або йде через окремий health-сервіс з власним compliance-контуром.

PD-011:

- обмеження на те, що можна інтегрувати й де зберігати.

---

## 12. Blockchain & Token Infrastructure

### 12.1. Що інтегруємо

- блокчейн-мережі (L1/L2);
- смарт-контракти токенів;
- мости/бриджі;
- custody/мультисиг.

### 12.2. Роль

- ончейн-репрезентація певних TokenTypes (PD-005);
- прозорість програм/фондів (PD-014);
- потенційне міст між Trutta-програмами та зовнішнім DeFi/DAO-світом.

### 12.3. Патерн

- `token-ledger-service` (PD-012):
  - єдиний клієнт блокчейн-інфри;
  - перекладає доменні стани Token runtime ↔ ончейн-стани;
- **домени Trutta не залежать від конкретного ланцюга**:
  - blockchain — лише implementation detail для частини TokenTypes.

---

## 13. AI & Tooling

### 13.1. Що інтегруємо

- LLM/embeddings/vector API;
- зовнішні AI-інструменти (переклад, класифікація, vision);
- developer tooling (Codex, CI/CD hooks, issue-трекери).

### 13.2. Роль

- агентний шар (PD-008);
- допоміжні інструменти для контенту, аналізу, перекладів, нормалізації;
- DevEx: автоматизація інфри/реп/доків (PD-010).

### 13.3. Патерн

- `ai-gateway-service`:
  - єдина точка доступу до LLM/vector/AI-сервісів;
  - застосовує guardrails (PD-011);
- агенти отримують **лише результат**, а не raw-доступ до зовнішніх API.

---

## 14. Integration contracts & repos

### 14.1. Contracts

Для кожної інтеграції описується:

- `use_case` (навіщо);
- `plane` (з п.3);
- `direction` (inbound/outbound/bidirectional);
- `frequency` (real-time/batch/near-real-time);
- `data_contract`:
  - поля, типи, обмеження;
- `security_contract`:
  - auth method, scopes, rate-limits;
- `SLA`:
  - latency, availability, деградація при збоях.

### 14.2. Repos

У `trutta_hub`:

```txt
docs/pd/
  PD-018-trutta-integrations-and-external-ecosystem-model.md

docs/vg/
  VG-1500-maps-and-routing-integrations.md
  VG-1501-reservations-and-events-integrations.md
  VG-1502-transit-and-city-data-integrations.md
  VG-15xx-payments-and-wallets-integrations.md
  VG-15xx-identity-and-kyc-integrations.md
  VG-15xx-blockchain-and-token-infra-integrations.md
```

У city/project-репах:

```txt
integrations/
  maps/
    config.yaml
  ota/
    config.yaml
  payments/
    config.yaml
  vendor-backend/
    <vendor-name>/
      adapter-config.yaml
docs/vg/
  VG-15xx-<city>-integrations-overview.md
```

---

## 15. Відношення до інших PD

* PD-012 — каже, які є runtime-сервіси; PD-018 — з ким саме вони інтегруються назовні.
* PD-017 — визначає data-площини; PD-018 — через які адаптери дані потрапляють/виходять.
* PD-011 — ставить рамки безпеки й приватності; PD-018 — застосовує їх до інтеграцій.
* PD-004/013/014 — домени (індустріальні, вендорські, програмні); PD-018 — як ці домени живуть у екосистемі API/партнерів.

PD-018 фіксує: **Trutta — не замкнута система, а хаб, який інтегрується з міськими/комерційними/соціальними стеками за чіткими правилами, з мінімумом сюрпризів і максимумом контрольованості.**
