# PD-014 — Trutta Programs, Subsidies & Funding Flows

**ID:** PD-014  
**Назва:** Trutta Programs, Subsidies & Funding Flows  
**Статус:** draft  
**Власники:** product, finance, ops, legal, data  
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
- VG-1400..1401 — Unit Economics & Pricing  
- VG-500..504 — Vendor & Network Ops

---

## 1. Purpose

Цей документ задає **канонічну модель програм, субсидій та фінансових потоків** у Trutta:

- як описуються **програми** (Sospeso, гуманітарка, міські/health-програми, промо-кампанії);
- як формуються й витрачаються **бюджети** (funding pools);
- як повʼязуються:
  - токени/ваучери (PD-005),
  - продукти DSL (PD-001),
  - ABC-попит (PD-007),
  - Vendor Network (PD-013),
  - міста/проєкти (PD-009).

Мета — мати одну рамку, в якій Sospeso, BREAD, city-pass, health-пакети й корпоративні/грантові програми — просто різні **конфігурації** однієї моделі.

---

## 2. Scope

### 2.1. Входить

- логічні сутності: `FundingSource`, `Program`, `FundingPool`, `Campaign`, `Policy`, `Allocation`, `RedemptionFlow`;
- моделі потоків:
  - донор → програмний пул → токени → вендори/користувачі;
- інтеграція з DSL, токенами, ABC, Vendor Network.

### 2.2. Не входить

- юридичні документи (Grant Agreement, Terms & Conditions);
- деталізовані бухгалтерські процедури;
- реалізація білінгу/інвойсингу (це side-системи).

---

## 3. Design principles

1. **Program-first, token-second**  
   Токени/ваучери завжди існують **в контексті програми** чи продукту, а не самі по собі.

2. **Separation of funding & entitlements**  
   Гроші/бюджети йдуть у **funding pools**, токени — у **entitlements**. Кожен entitlement має прозору мапу на pool/програму.

3. **Explicit policies**  
   Усі субсидії, ліміти, eligibility, anti-fraud — формалізовані у `Policy`.

4. **Multi-source funding**  
   Один Program/FundingPool може мати кілька джерел: місто, NGO, бренд, корпоративний спонсор, комʼюніті.

5. **Auditable by design**  
   Будь-який рух коштів/ентайтлів має бути:
   - трасований до програми/джерела;
   - перевіряльний ex-post.

---

## 4. Core entities

### 4.1. FundingSource

**FundingSource** — джерело фінансування:

- місто/муніципалітет;
- NGO/фонд;
- бренд/корпорація;
- Trutta internal (операційні бюджети, промо).

Основні атрибути:

- `funding_source_id`;
- `kind`: municipal | ngo | corporate | brand | internal | community;
- `constraints`:
  - гео, категорії сервісів, типи бенефіціарів;
- `reporting_requirements`:
  - що очікують бачити у звітах.

### 4.2. Program

**Program** — високорівнева рамка:

- «Vienna Sospeso Coffee Program»;
- «Kidney-friendly meal subsidy»;
- «City winter hospitality support».

Атрибути:

- `program_id`;
- `scope`: city / multi-city / project / global;
- `objectives`: соціальні/економічні/маркетингові;
- `allowed_domains`: food/hospitality/health/transport;
- `timeframe`: start/end;
- посилання на:
  - FundingSource(s),
  - Policies,
  - DSL-продукти й токени.

### 4.3. FundingPool

**FundingPool** — конкретний пул коштів у рамках програми:

- базовий обʼєм (в фіаті/стейблкоїні);
- валюта;
- джерела (1+ FundingSource);
- `allocation_rules`:
  - як перетворюється пул у токен-ентайтли.

Типи:

- `direct_subsidy_pool` — програма повністю оплачує токени;
- `co-pay_pool` — часткове субсидування;
- `guarantee_pool` — покриває ризики/невикористання.

### 4.4. Campaign

**Campaign** — конкретна активація/хвиля в рамках програми:

- `campaign_id`;
- таргет:
  - ABC-сегменти / demand pools;
  - міста/зони/вендор-кластери;
- набір DSL-продуктів/TokenTypes;
- KPI:
  - кількість токенів,
  - очікуваний GMV,
  - соціальний/health impact.

### 4.5. Policy

**Policy** — набір правил:

- **Eligibility policy**:
  - хто й коли може отримати entitlement (ABC-сегменти, TJM-контекст, health-/age-constraints);
- **Limit policy**:
  - скільки токенів/вартість на:
    - avatar/group/day/week/program;
- **Subsidy policy**:
  - %/сума субсидії;
  - макс. обʼєм на вендора/кластер/зону;
- **Fraud & abuse policy**:
  - тригери для додаткових перевірок;
  - автоматичне блокування.

### 4.6. Allocation & RedemptionFlow

**Allocation**:

- як FundingPool → стає **пакетами ентайтлів**:
  - заздалегідь (pre-minted пакет);
  - on-demand (mint при клеймі, резерви у пулі).

**RedemptionFlow**:

- конкретний сценарій:
  - хто отримує entitlement (avatar/group/vendor/city);
  - хто виконує сервіс (Vendor/ServicePoint);
  - як і куди списується вартість:
    - з FundingPool;
    - з користувача (якщо є co-pay);
    - що йде в fee Trutta.

---

## 5. Funding flows (логічні патерни)

### 5.1. Classic Sospeso (donor → unknown beneficiary)

- FundingSource: NGO/бренд/комʼюніті;
- Program: Sospeso Coffee/Meal;
- FundingPool: direct_subsidy_pool;
- Allocation:
  - mint `coffee_cup_token` / `meal_token` на **program account** або **group token**;
- Redemption:
  - avatar/група клеймить entitlement;
  - ServicePoint надає сервіс;
  - FundingPool списує суму, vendor отримує виплату.

### 5.2. City-pass / City-support

- FundingSource: місто + бренди;
- Program: City Winter Support / City Coffee Pass;
- Можливий mix:
  - частина вартості покривається пулом;
  - частина — користувачем (co-pay);
- Структура:
  - TokenType: `city_pass_token` (bundle);
  - Policy:
    - ліміти по днях, зонах, сервісах.

### 5.3. Health-focused subsidy

- FundingSource: health-organization/страхова/NGO;
- Program: kidney-friendly meal/travel support;
- Політики:
  - eligibility через абстрактні health-профілі (PD-004/011);
  - суворі ліміти на fraud (неможливо «фармити» health-субсидії).

---

## 6. Programs ↔ DSL, Tokens, TJM, ABC, Vendors

### 6.1. Programs ↔ DSL

Кожна Program/Campaign має:

- `linked_dsl_products`: список `product_id` / `offer_id`;
- `linked_token_types`: `token_type_id` з PD-005;
- `constraints_ref`: на `constraints.yaml` (час/гео/health).

DSL-артефакти містять:

- посилання на `program_id`/`campaign_id` у метаданих;
- маркування:
  - `is_subsidised: true/false`;
  - `subsidy_model_ref`.

### 6.2. Programs ↔ Tokens

PD-005:

- задає архетипи токенів, які мають `funding_link`:

  - `subsidised_entitlement_token`;
  - `group_funding_token`;
  - `escrow_token` для conditional програм.

Token runtime:

- знає:
  - з якого FundingPool походить кожен токен;
  - як рахувати резерви та breakage.

### 6.3. Programs ↔ TJM

Програма може бути **привʼязана** до stages TJM:

- додаткові токени в конкретні моменти подорожі;
- специфічні Campaign-и на певні TJM-steps:

  - `arrival`, `check-in`, `in-city-morning`, `post-trip-feedback`.

Це дає можливість:

- будувати сценарії типу:
  - «кава по приїзду»;
  - «здоровий сніданок перед процедурою».

### 6.4. Programs ↔ ABC

ABC (PD-007):

- використовується для таргетингу програм:

  - які сегменти/пули мають право/пріоритет на субсидію;
  - як розподіляються group tokens/entitlements.

DemandPool:

- може мати пряме посилання на `program_id`/`campaign_id`:
  - щоб розуміти, які програми змагаються за цей попит.

### 6.5. Programs ↔ Vendor Network

Vendor Network (PD-013):

- визначає, які вендори/ServicePoint беруть участь у програмі;
- рівні інтеграції:
  - min — L2 (Token Acceptance);
  - L3 — для co-designed програм (special menus, health-friendly).

Program/Campaign:

- містить список/фільтри:
  - `eligible_vendors` / `eligible_service_points` / `eligible_clusters/zones`.

---

## 7. Data, analytics, unit economics

### 7.1. Data model (логічно)

Аналітичні таблиці:

- `program_funding_stats`:
  - внески по FundingSource;
  - використання по часу/містам/сегментам;
- `program_redemption_stats`:
  - скільки токенів погашено;
  - GMV, breakage, fraud-флаг;
- `vendor_program_stats`:
  - розподіл субсидій між вендорами/мережами/зонами;
- `beneficiary_stats` (на рівні сегментів/аватарів, без PII).

### 7.2. Unit economics

VG-1400/1401 деталізують:

- LTV/CAC/GMV по Program/Campaign;
- ефективність субсидій:
  - cost per redeemed entitlement;
  - spillover-effects (додаткові покупки, повторні візити);
- соціальний/health impact:
  - де можливо, через агреговані індикатори.

---

## 8. Governance & risk

### 8.1. Roles

- **Program Owner** (product/ops):
  - відповідає за дизайн Program/Campaign;
- **Funding Owner** (finance/legal):
  - контракт з FundingSource; контроль пулів;
- **Data/Analytics**:
  - моделі impact/ефективності;
- **Security/Compliance**:
  - контроль fraud/зловживань, регуляторна відповідність.

### 8.2. Risk & fraud контроль

Основні осі:

- штучне роздування попиту (fake avatars/groups);
- аномалії у вендорів (надто високі обʼєми, дивні патерни часу/гео);
- misuse program funds (витрата не на цільові сервіси/групи).

Контрміри:

- ліміти в Policy;
- anomaly detection;
- audit trails (PD-011, Token runtime).

---

## 9. Repository & config conventions

У `trutta_hub`:

- концептуальні PD/VG про програми/юніт-економіку;
- templates:

```txt
templates/
  program/
    TEMPLATE-program-profile.yaml
    TEMPLATE-funding-pool.yaml
    TEMPLATE-campaign.yaml
    TEMPLATE-program-policy.yaml
```

У city/project-репах:

```txt
dsl/programs/
  <program-id>/
    program.profile.yaml
    funding-pools.yaml
    campaigns.yaml
    policies.yaml
```

Агенти:

* **program-designer-agent**:

  * генерує/оновлює program-configи;
* **program-analytics-agent**:

  * збирає статистику, пропонує зміни policy/budget.

---

## 10. Відношення до інших PD

* PD-001/003 — описують, як Program/Campaign привʼязуються до DSL-артефактів (продукти/офери/токени).
* PD-005 — задає типи токенів, потрібних для субсидій.
* PD-006/007 — дають контекст (TJM, ABC), у якому програми працюють.
* PD-009 — визначає, як Program живе в city/project-інстансах.
* PD-011 — рамка безпеки/даних для всіх фінансових потоків.
* PD-013 — визначає, хто саме на supply-стороні виконує ці програми.

PD-014 фіксує: **будь-який сценарій «хтось платить за чиюсь каву/їжу/подорож/процедуру» в Trutta — це Program + FundingPool + Policies + Tokens + Vendors**, а не ад-хок логіка в коді.
