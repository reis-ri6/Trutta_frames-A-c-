# PD-016 — Trutta Analytics, Events & Measurement Model

**ID:** PD-016  
**Назва:** Trutta Analytics, Events & Measurement Model  
**Статус:** draft  
**Власники:** product, data, analytics, eng  
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
- VG-900..904 — Analytics & Growth Guides  
- VG-1400..1401 — UE / Pricing / Experiments

---

## 1. Purpose

Цей документ задає **канонічну модель аналітики, подій і метрик** у Trutta:

- який **event model** вважається основним;
- як події повʼязані з:
  - DSL (продукти/офери/токени),
  - TJM (подорожі),
  - ABC (спільноти/попит),
  - Vendor Network,
  - Programs/Funding;
- як формуються **метрики й дашборди** для product/ops/city/NGO/brand.

Мета — зробити так, щоб для будь-якого нового міста/проєкту/програми:

> інструментація ≈ вибір готових подій/метрик, а не винахід велосипеда.

---

## 2. Scope

### 2.1. Входить

- логічна **класифікація подій**;
- базові **сутності аналітики** (session, journey_instance, token_instance, entitlement, program_exposure);
- **Naming conventions** для подій/властивостей;
- звʼязок з data-layers (PD-004) та runtime (PD-012).

### 2.2. Не входить

- вибір конкретного стеку (Snowflake/BigQuery/ClickHouse тощо);
- деталізація BI-дашбордів (VG-902);
- повний опис UE/експериментів (VG-1400/1401, VG-901).

---

## 3. Measurement principles

1. **Event-first, not table-first**  
   Все важливе в Trutta описується через **події**. Таблиці — похідні.

2. **DSL-generated where possible**  
   Частина подій генерується **автоматично з DSL** (PD-001/003), а не руками.

3. **TJM/ABC-native**  
   Ключові метрики будуються по TJM-етапах і ABC-сегментах, а не довільним етапам/сегментаціям.

4. **Minimal IDs, maximal joins**  
   У кожній події мінімальний, але стабільний набір ключів (`tenant`, `city`, `project`, `program`, `token`, `journey_instance`, `avatar`/`anon`).

5. **Privacy by design**  
   Жодної PII/health-інфи в подіях, які йдуть у core analytics (див. PD-011).

---

## 4. Event taxonomy (логічна)

### 4.1. Основні namespaces

Умовні простори імен подій:

- `trutta.app.*` — UX/клієнтські події;
- `trutta.tjm.*` — події подорожей;
- `trutta.token.*` — токени/ентайтли;
- `trutta.abc.*` — сегменти/пули/групи;
- `trutta.vendor.*` — вендор/сервісна мережа;
- `trutta.program.*` — програми/кампанії/субсидії;
- `trutta.data.*` — інжест/оновлення даних;
- `trutta.system.*` — системні, health/infra (для SRE, не продукт-аналітики).

### 4.2. Приклади ключових подій

**UX / App**

- `trutta.app.session_started`
- `trutta.app.session_ended`
- `trutta.app.view_shown` (екрани/шаблони, а не raw URL)
- `trutta.app.action_clicked` (CTA/кнопки)
- `trutta.app.error_shown`

**TJM**

- `trutta.tjm.journey_started`
- `trutta.tjm.step_entered`
- `trutta.tjm.step_completed`
- `trutta.tjm.journey_completed`
- `trutta.tjm.journey_abandoned`

**Tokens**

- `trutta.token.offer_viewed`
- `trutta.token.entitlement_created` (mint/allocate)
- `trutta.token.entitlement_claimed`
- `trutta.token.entitlement_redeemed`
- `trutta.token.entitlement_expired`
- `trutta.token.entitlement_cancelled`

**ABC**

- `trutta.abc.segment_assigned`
- `trutta.abc.pool_created`
- `trutta.abc.pool_funded`
- `trutta.abc.pool_consumed`
- `trutta.abc.group_created/joined/left`

**Vendors**

- `trutta.vendor.service_point_visited` (в контексті Trutta UX/маршруту)
- `trutta.vendor.token_accepted`
- `trutta.vendor.sla_violation_detected`
- `trutta.vendor.menu_updated`

**Programs**

- `trutta.program.exposure` (користувач бачить офер/програму)
- `trutta.program.opt_in`
- `trutta.program.budget_committed`
- `trutta.program.budget_spent`
- `trutta.program.impact_recorded` (узгоджений набір показників)

---

## 5. Event schema conventions

### 5.1. Обовʼязкові поля

Для більшості продукт/доменно орієнтованих подій:

- `event_id` — унікальний;
- `event_name` — повна назва (`trutta.token.entitlement_redeemed`);
- `event_time` — UTC timestamp;
- `tenant_id` — місто/бренд/проект (PD-009, PD-012);
- `city_id` (якщо релевантно);
- `project_id` (якщо релевантно);
- `program_id` / `campaign_id` (якщо релевантно);
- `source_channel` — chat/app/web/vendor_panel/pos_integration;
- `actor_type` — avatar/vendor/system;
- `actor_id` — `avatar_id` або `vendor_id`/`service_point_id`.

### 5.2. Контекстні поля

Підмножина для:

- **TJM**:
  - `journey_id`, `journey_instance_id`;
  - `tjm_stage`, `tjm_step`;
- **Tokens**:
  - `token_type_id`, `token_instance_id`;
  - `entitlement_value`, `currency`, `token_state_before/after`;
- **ABC**:
  - `segment_ids[]`, `pool_id`, `group_id`;
- **Vendors**:
  - `vendor_id`, `service_point_id`, `zone_id`;
- **Programs**:
  - `funding_pool_id`, `subsidy_amount`, `user_copay_amount`.

### 5.3. Властивості з DSL

Події, повʼязані з продуктами/оферами/токенами, мають:

- `product_id`, `offer_id`, `dsl_version`;
- `constraints_refs[]` — посилання на набори constraint-ів (час/гео/health).

Це дозволяє:

- робити backfill/атрибуцію навіть при зміні DSL;
- порівнювати behavior до/після зміни версій.

---

## 6. From DSL/TJM/ABC to events

### 6.1. Автоматична генерація подій з DSL

PD-001/003:

- кожен `*.product.yaml` / `*.offer.yaml` / `*.token.yaml` може містити:

```yaml
analytics:
  events:
    on_view: "trutta.token.offer_viewed"
    on_accept: "trutta.token.entitlement_created"
    on_redeem: "trutta.token.entitlement_redeemed"
  properties:
    product_category: "coffee"
    program_tags: ["sospeso", "vienna"]
```

Runtime (PD-012):

* при підключенні продукту в UX/сервіс:

  * автоматично привʼязує події;
  * забороняє «локальні» кастомні назви.

### 6.2. TJM-driven instrumentation

PD-006:

* визначає стандартні events для stages/steps;
* `journey-engine-service`:

  * емитить `trutta.tjm.*` події;
  * події UX/Token/Program можуть містити `tjm_step` для лінкування.

### 6.3. ABC-driven segmentation

PD-007:

* `segment-engine-service`:

  * пише `trutta.abc.segment_assigned`;
* у всі наступні події актор отримує:

  * `segment_ids[]`;
* аналітика:

  * може завжди робити зрізи “за сегментами”, не повторюючи логіку сегментації.

---

## 7. Metrics framework

### 7.1. Core metric families

1. **Activation & Adoption**

   * `journeys_started`, `journeys_completed`;
   * `first_token_claim_time`, `first_redeem_time`;
   * `% users with ≥1 redeem`.

2. **Engagement**

   * події TJM по стадіях;
   * depth / breadth маршруту;
   * повторні візити/редемпшени.

3. **Token & Program Performance**

   * `tokens_issued`, `tokens_redeemed`, `breakage_rate`;
   * `subsidy_spent`, `co-pay_volumes`;
   * `cost_per_redeemed_entitlement`.

4. **Vendor & Network Health**

   * `coverage` (по зонах/категоріях);
   * `vendor_active_share`, `redemption_latency`;
   * SLA-порушення, NPS/UGC-метрики.

5. **City / System Impact**

   * для програм: кількість унікальних бенефіціарів (на рівні аватарів/сегментів);
   * агреговані health/соціальні індикатори (де дозволено).

### 7.2. Metric definitions & ownership

Кожна метрика:

* описана як артефакт (VG-900/902):

  * `id`, `name`, `definition`, `formula`, `grain`, `dimensions`, `owner`;
* reference на PD (що вона вимірює);
* привʼязка до event-схеми:

  * які `event_name + filters` використовуються.

---

## 8. Experiments & growth

### 8.1. A/B / feature flags

* експерименти живуть поверх event model:

  * `experiment_id`, `variant_id` — додаються в події;
* будь-яке A/B:

  * працює з тими ж events;
  * не вводить нових event-імен.

### 8.2. Growth loops

VG-903:

* використовує PD-016 як **джерело подій** для:

  * реферальних лупів (share → new journey → redemption);
  * UGC/контентних лупів;
  * партнерських програм.

---

## 9. Data lifecycle & storage

### 9.1. Data flow

Логічний pipeline:

1. **Collection** — runtime сервіси емитять events;
2. **Ingestion** — delivery у raw-event storage;
3. **Normalization** — маппінг у canonical схеми:

   * пристиковка до PD-004 (domains), PD-005 (tokens), PD-006/007 (TJM/ABC);
4. **Semantic layer**:

   * готові таблиці/вʼюхи для BI/agentів;
5. **Derived models**:

   * фічі для ML/рекомендацій;
   * knowledge-graph звʼязки (PD-004).

### 9.2. Privacy & retention

PD-011:

* PII/health — або не потрапляє в event-layer, або йде в окремі потоки з іншими правилами;
* ретеншн:

  * аналітичні події знеособлені/агреговані після заданого періоду;
* доступ:

  * через вьюхи з RLS/ABAC.

---

## 10. Repos & docs

У `trutta_hub`:

```txt
docs/pd/
  PD-016-trutta-analytics-events-and-measurement-model.md

docs/vg/
  VG-900-tracking-plan-core.md
  VG-901-funnels-and-cohorts.md
  VG-902-dashboards-and-schema-examples.md
  VG-903-growth-loops-and-referrals.md
```

У city/project-репах:

```txt
docs/vg/
  VG-9xx-<city>-tracking-plan.md
  VG-9xx-<project>-tracking-plan.md

data/analytics/
  events-schema-overrides.yaml (якщо є локальна специфіка)
  dashboards/...
```

---

## 11. Відношення до інших PD

* PD-001/003 — кажуть, що саме є продуктами/токенами, PD-016 — як їх міряти.
* PD-004 — дає data-layers; PD-016 — як через events їх наповнювати.
* PD-006/007 — дають TJM/ABC; PD-016 — метрики/події по них.
* PD-009/013/014 — міста, мережі, програми; PD-016 — вимірювання їх ефективності.
* PD-011 — ставить обмеження, що можна і що не можна логувати.

PD-016 фіксує, що **аналітика в Trutta — це не «один трекінг-план на проєкт», а єдина модель подій/метрик, на якій сидять всі міста, програми й продукти**.
