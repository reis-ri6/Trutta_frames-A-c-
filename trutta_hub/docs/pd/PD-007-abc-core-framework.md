# PD-007 — ABC (Anonymous Buyers Community) Core Framework

**ID:** PD-007  
**Назва:** ABC (Anonymous Buyers Community) — Core Framework for Trutta  
**Статус:** draft  
**Власники:** product, arch, data, legal  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- DOMAIN-* — домени avatar/profiles, cohorts, segments  
- VG-9xx — Analytics & Cohorts

---

## 1. Purpose

Цей документ задає **канонічну модель ABC — Anonymous Buyers Community** у Trutta:

- як ми представляємо користувача **через аватар**, а не через PII;
- як агрегується **попит**: сегменти, пул попиту, групи, кампанії;
- як ABC інтегрується з:
  - TJM (подорож як контекст),
  - Product DSL (продукти/офери/токени),
  - індустріальними доменами;
- які **обмеження по privacy, комплаєнсу й фроду**.

Це «рамка попиту» в екосистемі, симетрична до пропозиції, описаної в DSL.

---

## 2. Scope

### 2.1. Входить

- логічні сутності ABC: `Avatar`, `DemandPool`, `Segment`, `Group`, `GroupToken`;
- звʼязок з TJM, DSL, токенами;
- базові правила анонімності й даних.

### 2.2. Не входить

- детальна реалізація профайлингу/рекомендацій (AI-моделі → окремі VG/ML-доки);
- повні схеми БД (DOMAIN + schemas/db);
- конкретні community-продукти (Sospeso, BREAD, Goliaf) → окремі PD/CONCEPT.

---

## 3. Design principles (ABC)

1. **Avatar-first, no raw PII**  
   У всіх шарів Trutta працюємо з аватарами та агрегованими даними. PII, якщо взагалі потрібні, живуть ізольовано й не потрапляють у ABC.

2. **Demand-first**  
   Перший клас громадян — **попит** (потреби, патерни, таймінг), а не історія покупок.

3. **Contextual**  
   Попит завжди розглядається в контексті:
   - TJM (де в подорожі),
   - доменів (місто, тип сервісу, health-constraints).

4. **Privacy-preserving**  
   Мінімізуємо ризик deanonymization:
   - ніяких сирих ідентифікаторів;
   - агрегація й k-анонімність на рівні даних.

5. **Composable with DSL & tokens**  
   ABC не дублює продуктові моделі, а **підключається** до них:
   - сегменти → tarгетування оферів/токенів;
   - demand pools → групові токени, Sospeso-патерни.

---

## 4. Core entities

### 4.1. Avatar

**Avatar** (`domain-entity`):

- абстрактний «носій поведінки»:
  - Travel-патерни (TJM usage);
  - food/health preferences (через абстрактні профілі/constraints);
  - канали взаємодії (app, бот).
- не має явних PII-полів (імʼя, email, паспорт тощо);
- може лінкуватися до реального юзера через **ізольований auth/identity шар** (поза ABC).

Основні компоненти:

- `avatar_id`;
- `preference_profile_id` (food/health/city/style);
- `behavior_profile` (агреговані патерни: ранкові активності, нічні, т.п.);
- `tjm_history_ref` (агрегована історія подорожей/steps).

### 4.2. Segment

**Segment** (`domain-entity`, `analytics-concept`):

- формальний опис групи аватарів з близькими характеристиками:
  - `TJM`-патерн (наприклад: «weekend city-break»);
  - budget/price-sensitivity;
  - food/health profiles.

Зберігається як:

- правила/фільтри (query over canonical data);
- або як матеріалізований набір `avatar_id` (для швидкого таргетингу).

### 4.3. DemandPool

**DemandPool** (`business-concept`):

- агрегований попит заданого сегменту/групи в конкретному **контексті**:

```yaml
demand_pool_id
segment_id | explicit avatar_ids
tjm_context:
  stage: "in-city"
  step: "STEP-MORNING-COFFEE"
  city_id: "CITY-VIENNA"
need_descriptor:
  type: "coffee|breakfast|city-pass|medical"
  constraints: ["renal-friendly", "low-sodium"]
time_window:
  from: ...
  to: ...
size_estimate: ~N avatars
```

* використовується для:

  * конструювання оферів;
  * торгу із supply (DC2SC патерн — demand consolidation → supply competition).

### 4.4. Group / Community

**Group** (`domain-entity`):

* контейнер, який обʼєднує аватарів:

  * постійні community (travel-клуб, health community);
  * тимчасові групи (ранішній кавовий рейд, спільний тур).

Може мати:

* власний `GroupToken` (див. PD-005 — Group Token as archetype);
* правила входу/виходу;
* governance-параметри (хто приймає рішення, як розподіляються ентайтли).

### 4.5. GroupToken

**GroupToken** (`runtime-object`):

* токен, що представляє право групи/пулу на пакет сервісів;
* привʼязаний до:

  * `DemandPool` (або Group),
  * набору продуктів/оферів,
  * правил розподілу (share/allocate).

DSL описує тип GroupToken (`*.token.yaml`); ABC — **кому** він реально належить і як розподіляється.

---

## 5. ABC ↔ TJM ↔ DSL

### 5.1. ABC і TJM

* Кожен DemandPool/Group має **TJM-контекст**:

  * `stage`, `step`, `micro_journey`, `city`.
* Це дозволяє:

  * розуміти «коли саме» попит активний;
  * будувати продуктивний matching з продуктами/оферами.

### 5.2. ABC і DSL

* Product/Offer в DSL мають:

  * target segments (через labels/filters);
  * target TJM-контекст;
* ABC надає **конкретні пулі попиту**, DSL — **формальну пропозицію**;
* Match-механізми (агенти/сервіси) працюють по:

  * constraints (time/geo/health),
  * segment/demand_pool характеристикам.

---

## 6. Data model (логічний)

### 6.1. Рівні даних ABC

Перетин PD-004 (layers) з ABC:

* **Raw:** сирі події поведінки (clicks, views, messages, редемпшени).
* **Canonical ABC:**

  * `avatars`, `segments`, `demand_pools`, `groups`, `group_tokens`.
* **Analytics:**

  * `segment_performance`, `demand_pool_match_rate`, `group_redemption_stats`.
* **AI / Knowledge:**

  * embeddings preferences, travel styles, micro-journeys patterns.

Логічна структура каталогів:

```txt
data/
  canonical/
    abc/
      avatars.*
      segments.*
      demand_pools.*
      groups.*
      group_tokens.*
  analytics/
    abc/
      segments_stats.*
      pools_stats.*
      group_usage.*
  ai/
    abc/
      avatar_embeddings.*
      segment_embeddings.*
```

---

## 7. Privacy & Compliance

### 7.1. Що **не** живе в ABC

* явні ідентифікатори: імʼя, email, телефон, паспорт;
* сирі медичні дані (аналізи, діагнози);
* сирі платіжні дані.

Це все — в окремих, жорстко ізольованих системах.

### 7.2. Що живе в ABC

* абстрактні профілі:

  * `DietProfile` (кластери обмежень, PD-004/health);
  * `TravelStyleProfile` (weekend vs long stay, city vs nature);
* агреговані патерни:

  * «часто кавʼярні з 8:00–10:00»;
  * «часті вечірні ресторани в центрі».

### 7.3. Анонімність і k-анонімність

* сегменти й demand pools повинні:

  * мати мінімальний розмір (k-порог);
  * не давати можливості легко deanonymize конкретного аватара.
* будь-який API/аналітика, що повертає ABC-дані:

  * працює із сегментами/пулами, а не з одиничними ID.

---

## 8. Fraud & Abuse (ABC-рівень)

Мета — **не допустити використання ABC для:

* маніпуляцій,
* фальшивого попиту,
* «фармлення» токенів.

### 8.1. Fake demand

* сигнали:

  * перегріті demand pools без реального редемпшена;
  * аномальна кореляція між новими аватарами та високими entitlement-обсягами.
* механізми:

  * throttling на створення/роздування demand_pool;
  * привʼязка до довгострокових TJM-патернів, а не лише одноразових дій.

### 8.2. Sybil / multi-avatar

* можлива поява багатьох аватарів, що фактично представляють одного юзера.
* mitigation:

  * поведінковий аналіз (не зберігаючи PII);
  * ліміти на користування субсидованими токенами по «мʼяких» групових ознаках.

---

## 9. Agents & Operations

### 9.1. Типи агентів навколо ABC

* **ABC Profiler Agent**
  будує/оновлює `preference_profile`, `behavior_profile` для аватарів.

* **Segment Builder Agent**
  допомагає продактам формувати/перевіряти сегменти:

  * пропонує фільтри;
  * оцінює розмір/якість.

* **DemandPool Orchestrator**
  створює demand pools з урахуванням TJM/міста/доменів;
  готує вхідні дані для оферів.

* **ABC Analytics Agent**
  аналізує performance сегментів, пулів, групових токенів.

### 9.2. Операційні процеси

* регулярний **re-segmentation**:

  * оновлення сегментів за новими даними;
* **pool lifecycle**:

  * `planned → active → matched → closed` (успішно / без матчу);
* **group lifecycle**:

  * створення → використання токенів → розпуск/архівація.

---

## 10. Звʼязок із іншими PD/VG

* PD-001/003
  DSL описує **пропозицію**, ABC — **попит**; звʼязок йде через labels/filters/constraints.
* PD-004
  ABC шар сидить поверх canonical/analytics, не торкаючись raw PII.
* PD-005
  GroupToken, Status/Soulbound токени (амбасадори, вендори) — основні токенові патерни для ABC.
* PD-006
  TJM — часово-просторовий каркас; ABC — «хто що хоче і коли».
* VG-9xx
  визначає метрики: segment lift, pool match ratio, group redemption efficiency.

PD-007 — **референсна рамка для всієї логіки попиту/комʼюніті**.
Усі майбутні ABC-продукти (Sospeso, BREAD, Goliaf, health-комʼюніті) мають описувати себе як конкретні конфігурації й розширення цього фреймворку, а не вигадувати нові моделі з нуля.
