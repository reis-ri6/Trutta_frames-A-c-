# PD-008 Product Runtime & Agents Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform Runtime & Agents

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md  
- PD-007-product-profiles-spec.md  
- PD-007-product-profiles-links.md  
- PD-008-product-runtime-events.md (next)  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Формалізувати **runtime-поведінку продуктів** як поєднання:

- ProductDef + Registry + Profiles (PD-001..PD-007);
- execution-пайплайна (від discovery до completion/settlement);
- ролі AI-агентів та orchestrator’а;
- контракту подій (деталі в PD-008-events).

### 1.2 Scope

Входить:

- логічна модель **product runtime session**;
- фази execution-пайплайна;
- типи та ролі AI-агентів;
- state-машини та ключові події (без повного переліку полів);
- degraded/обривні сценарії на рівні продукту.

Не входить:

- фінансові деталі billing/settlement (PD-009);  
- детальний ops/safety/quality control (PD-010);  
- low-level API/DDL (покриті окремими PD-00x документами).

---

## 2. Runtime Components & Responsibilities

### 2.1 Core runtime компоненти

- **Product Runtime Gateway (PRG)**  
  Edge-сервіс/API, через який фронтенд/агенти стартують та супроводжують product runtime session.

- **Registry**  
  Джерело правди для ProductDef, Version, Profiles (PD-003, PD-007). Видає resolved конфіг.

- **TJM Journey Runtime**  
  Виконує journey-doc (TJM), керує нодами/кроками, state-машиною journey, інтегрується з LEM, Trutta.

- **Agent Orchestrator (AO)**  
  Керує AI-агентами (user-facing, system, ops). Планує, маршрутизує, лімітує виклики агентів.

- **Trutta Runtime**  
  Issue/redeem entitlements, токени, swap, settlement.

- **LEM Runtime**  
  Routing, city graph, experience metrics.

- **Wallet & Accounts**  
  Користувацькі/вендорські гаманці, внутрішній ledger.

- **Observability Layer**  
  Логи, метрики, трейсинг, audit (events).

### 2.2 Допоміжні

- **Profile Cache** — кеш resolved profiles з Registry.
- **Risk & Fraud Engine** — окремі правила/моделі, що підписані на runtime events.
- **Support & Ops Console** — UI для інцидентів, overrides, ручних дій.

---

## 3. Core Runtime Concepts

### 3.1 Product Runtime Session

**ProductRuntimeSession** — основна runtime-одиниця:

- `product_runtime_session_id` — глобальний ID;
- прив’язка до:
  - `product_version_id`;
  - `market_code`;
  - `user_id`/avatar_id (або анонімний контекст);
  - сегментів, експериментів;
  - `journey_instance_id` (0..1, може з’явитись не одразу);
  - `wallet_id`(и).

State-машина сесії, high-level:

- `created`  
- `preflight_ok` / `preflight_failed`  
- `pending_payment`  
- `active` (journey running / entitlements issued)  
- `completed`  
- `canceled`  
- `failed` (фатальна помилка).

### 3.2 Ties to other entities

- один **ProductRuntimeSession** може:
  - містити **0..N journey_instance_id** (pre-trip / in-trip / post-trip);  
  - видавати **0..N entitlements/tokens** у Trutta;  
  - генерувати **0..N loyalty events**.

- всі event-потоки мають містити `product_runtime_session_id` для кореляції.

---

## 4. Execution Pipeline (Phases)

### 4.1 Phase 0 — Discovery (pre-runtime)

Не є частиною сесії формально, але задає контекст:

- user/agent запитує список продуктів;  
- BFF витягує ProductDef + UiProfile + Pricing/Loyalty summary;  
- агент/юзер обирає конкретний продукт → стартує `ProductRuntimeSession.create`.

### 4.2 Phase 1 — Preflight

Ціль: перевірити, що продукт **може** бути виконаний у даному контексті.

Кроки (через PRG):

1. **Resolve config:**  
   - Registry → ProductVersion, Profiles (token/loyalty/pricing/ops/safety/quality/ui);  
   - кешування в Profile Cache.
2. **Availability checks:**  
   - статус продукту (`active`), версія, effective_from/until;  
   - квоти/ліміти (per_user/per_wallet, global caps).
3. **Safety & coverage checks:**  
   - SafetyProfile → min_safety_score, allowed cities/clusters;  
   - LEM → coverage (service_point_classes, кластери), city availability;  
   - у разі деградації — або відмова, або fallback-режим.
4. **Risk/fraud pre-screen:** (опційно)  
   - Risk Engine оцінює ризики (аномальні патерни покупок, гео, історія).

Результат:

- `preflight_ok` → можна продовжувати;  
- `preflight_failed` → сесія закінчується з поясненням (UI-friendly codes).

### 4.3 Phase 2 — Purchase & Tokenisation

Якщо продукт платний / токенізований:

1. **Pricing resolution:**  
   - Billing/rating ← PricingProfile (PD-009) → фінальна ціна, валюта.
2. **Payment flow:**  
   - інтеграція з PSP/внутрішнім балансом;  
   - у випадку успіху → `payment.captured` event.
3. **Entitlement/Token issue (Trutta):**  
   - TokenProfile → selection EntitlementProfile/TokenProfile;  
   - Trutta issue → `entitlement.issued`/`token.issued` events.
4. **Wallet update:**  
   - відображення активів у user/vendor wallets.

Сесія переходить у `active` після успішного payment+issue (або одразу, якщо продукт без оплати).

### 4.4 Phase 3 — Journey Setup (TJM)

1. **JourneyDoc selection:**  
   - ProductDef → посилання на TJM-doc (або шаблон);  
   - Profiles (safety, ops, ui) → overlay для journey-конфігів.
2. **Journey instance create:**  
   - TJM створює `journey_instance_id`, базовий state;  
   - прив’язка до `product_runtime_session_id`, `user_id`, профілів.
3. **Initial agent plan:**  
   - Agent Orchestrator може попросити planner-агента побудувати початковий план/route (через LEM).

### 4.5 Phase 4 — In-journey Runtime

Центральна фаза, де грають роль TJM + LEM + Trutta + агенти.

Основні цикли:

- **Context loop:**
  - TJM тримає поточний нод journey;  
  - LEM надає маршрути/контекст (service points, кластерні метрики);  
  - Trutta слідкує за станом entitlements (redeemable/expired);  
  - Observability логує events.

- **Agent loop:**
  - Agent Orchestrator отримує контекст (journey state, LEM, wallet, профілі);  
  - обирає агент(ів): planner, guide, support, growth;  
  - агенти пропонують кроки (recommendations, зміну маршруту, upsell/cross-sell) у межах політик.

User interaction:

- користувач (або зовнішній UI-агент) підтверджує/відхиляє пропозиції;  
- TJM переходить до наступних нодів, емить події (`journey.node.*`).

### 4.6 Phase 5 — Completion & Settlement

Умови завершення:

- journey досягла кінцевого стану (success / partial / abandoned);  
- всі entitlements використані/expired або закінчився час дії продукту.

Кроки:

1. **Final Trutta settlement:**  
   - завершення фінальних розрахунків з вендорами/трезорі;  
   - можливі компенсації (ops/safety-triggered).
2. **Loyalty finalisation:**  
   - Loyalty Engine по подіях `journey.completed`, `entitlement.redeemed` нараховує/викуповує points.
3. **Quality & CX:**  
   - QualityProfile → тригер post-journey survey;  
   - збір фідбеку, NPS, рев’ю.
4. **Session closure:**  
   - ProductRuntimeSession переходить у `completed`/`canceled`/`failed`.

---

## 5. AI Agents — Types & Roles

### 5.1 User-facing agents

- **Trip Planner Agent**  
  Планує продуктову конфігурацію + маршрути (LEM), може пропонувати конкретні продукти/комбінації.

- **Journey Guide Agent**  
  Супроводжує користувача під час виконання продукту: підказки, next best action, локальні рекомендації.

- **Support Agent**  
  Допомагає при інцидентах, питаннях, edge-кейсах.

### 5.2 System-level agents

- **Pricing & Revenue Agent**  
  Аналізує performance продукту, пропонує зміни в PricingProfile/кампаніях.

- **Safety & Risk Agent**  
  Аналізує safety/geo/usage, пропонує зміни до SafetyProfile, блокує ризикові сесії.

- **Ops & SLO Agent**  
  Моніторить SLO/alerts (OpsProfile), пропонує масштабування/mitigation.

- **Growth & Loyalty Agent**  
  Використовує LoyaltyProfile для персоналізації промо, рефералок, UGC.

### 5.3 Agent Orchestrator (AO)

Відповідає за:

- policy-based routing викликів (який агент коли можна викликати);
- rate limiting, бюджет (LLM tokens/time);
- audit trail — хто що порадив і до чого це призвело;
- безпечне виконання (никаких directly destructive дій без явних чеків з боку Runtime).

---

## 6. State Machines & Key Events (Overview)

> Детальні payload’и — у PD-008-product-runtime-events.md.

### 6.1 ProductRuntimeSession state machine

Стани:

- `created`  
- `preflight_ok` / `preflight_failed`  
- `pending_payment`  
- `active`  
- `completed`  
- `canceled`  
- `failed`

Події переходів (приклади):

- `product.runtime.created`  
- `product.runtime.preflight_ok` / `product.runtime.preflight_failed`  
- `product.runtime.payment_pending` / `product.runtime.payment_captured`  
- `product.runtime.activated`  
- `product.runtime.completed`  
- `product.runtime.canceled`  
- `product.runtime.failed`

### 6.2 Journey state machine

Ключові події (прив’язка до runtime):

- `journey.started`  
- `journey.node.entered` / `journey.node.completed` / `journey.node.skipped`  
- `journey.route.generated` (LEM)  
- `journey.completed` / `journey.abandoned`.

### 6.3 Trutta & Wallet events

- `entitlement.issued`, `entitlement.redeemed`, `entitlement.expired`;  
- `token.issued`, `token.transferred`, `token.burned`;  
- всі з посиланнями на `product_runtime_session_id`, `product_version_id`, профілі.

### 6.4 Agent events

- `agent.task.created`, `agent.task.completed`, `agent.task.failed`;  
- `agent.recommendation.shown`, `agent.recommendation.accepted/rejected`.

---

## 7. Degradation & Failure Modes

### 7.1 Degraded LEM / routing

- Fallback:
  - статичні маршрути;  
  - зменшений набір фасетів;  
  - обмеження продукту по місту/кластерах.

- Події: `lem.degraded`, `product.runtime.degraded`.

### 7.2 Degraded Trutta

- Можливі моделі:
  - тимчасова зупинка issue, але дозволені redeem існуючих entitlements;  
  - режим лише локальних (offchain) прав без оновлення onchain.

- Події: `trutta.degraded`, вплив на TokenProfile (тимчасові overrides).

### 7.3 Degraded Agents / LLM

- fallback до rule-based логіки;  
- вимкнення не-критичних growth/rec agents;  
- user-facing агенти можуть бути замінені статичними flows.

---

## 8. Security, Governance & Permissions (Runtime View)

- Всі runtime-операції мають виконуватись від імені **service principals**/суб’єктів із явними правами:
  - PRG, TJM, Trutta, LEM, AO, агенти.

- AI-агенти **ніколи не виконують прямі mutation-запити** до Trutta/Registry/LEM:  
  вони пропонують дії, які підтверджуються Runtime (PRG/TJM) згідно з policy.

- Governance-рівень контролює:
  - хто може змінювати ProductDef і профілі;  
  - хто може запускати експерименти;  
  - які агенти мають доступ до яких даних (PII boundary).

---

## 9. Summary

- PD-008 описує **стандартний execution-пайплайн** для будь-якого продукту: від preflight до completion, з чіткими state-машинами й подіями.  
- AI-агенти вбудовані як допоміжний шар над цим пайплайном, але не порушують інваріанти безпеки й governance.  
- Registry + Profiles залишаються єдиним конфіг-джерелом; Trutta, TJM, LEM, BFF та агенти — виконавці, які читають узгоджений runtime-контекст.

Наступний документ **PD-008-product-runtime-events.md** деталізує повний каталог подій та їх payload’и.

