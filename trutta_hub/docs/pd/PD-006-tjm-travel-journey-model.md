# PD-006 — TJM (Travel Journey Model) for Trutta

**ID:** PD-006  
**Назва:** TJM (Travel Journey Model) — Core Framework for Trutta  
**Статус:** draft  
**Власники:** arch, product, data  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- DOMAIN-tourism, DOMAIN-city, DOMAIN-services  
- VG-8xx — TJM Runtime & Events  
- VG-9xx — Journey Analytics

---

## 1. Purpose

Цей документ фіксує **TJM як канонічну модель подорожі** всередині Trutta:

- які є **стадії**, **кроки**, **події**;
- як TJM повʼязується з:
  - продуктами/оферами/токенами (DSL),
  - індустріальними доменами (tourism, hospitality, services, city),
  - ABC (анонімні спільноти);
- як TJM використовується:
  - у runtime (routing, eligibility, UX-флоу),
  - в аналітиці та оптимізації (funnels, cohorts).

TJM — це **вісь часу і контексту**, навколо якої «вішаються» всі продукти/токени/сервіси.

---

## 2. Scope

### 2.1. Входить

- логічна структура TJM:
  - stages, steps, events, journeys, micro-journeys, routes;
- базові ID/класифікація;
- звʼязок із:
  - DSL (`*.journey.yaml`, `JourneyBinding`),
  - доменами (Trip, Segment, POI, Route),
  - даними (canonical + analytics).

### 2.2. Не входить

- UI/екрани/конкретні сценарії для окремих продуктів;
- низькорівневий runtime (конкретні мікросервіси, черги, інфра);
- детальні схеми БД (це DOMAIN + schemas/db).

---

## 3. High-level TJM model

### 3.1. Основні сутності

- **Journey**  
  повна подорож: від «зародження наміру» до повернення і post-trip досвіду.

- **Stage**  
  великий блок Journey:
  - `pre-trip`, `in-transit`, `arrival`, `in-hotel`, `in-city`, `return`, `post-trip`.

- **Step**  
  конкретний крок у межах Stage:
  - `search`, `booking`, `check-in`, `breakfast`, `city-walk`, `clinic-visit`, `check-out`.

- **Event**  
  атомарна подія:
  - `booking_confirmed`, `token_redeemed`, `meal_served`, `pass_scanned`.

- **Micro-journey**  
  компактна звʼязка кількох Steps/Event навколо однієї задачі:
  - «доїхати з аеропорту в готель»,
  - «провести ранок з кавою і сніданком»,
  - «пройти медичну процедуру + відновлення».

- **Route / City-experience**  
  micro-journey, привʼязана до city-graph:
  - набір POI/ServicePoints з порядком, часом, transit-опціями.

### 3.2. Каркас стадій (canonical stages)

Мінімальний набір:

- `pre-trip` — пошук, планування, бронювання;
- `in-transit` — дорога до/з дестинації;
- `arrival` — перші дії після прибуття;
- `in-hotel` — все, що стосується проживання;
- `in-city` — міські активності, food, транспорт, сервіси;
- `return` — дорога назад;
- `post-trip` — фідбек, follow-up, повторні покупки.

Stages — стабільний каркас; Steps/Micro-journeys можуть деталізуватись під продукт/місто.

---

## 4. TJM ↔ DSL

### 4.1. JourneyBinding як контракт

У DSL:

- `JourneyBinding` (`*.journey.yaml`) описує:

```yaml
apiVersion: trutta.dsl/v1
kind: JourneyBinding
metadata:
  id: "JB-xxxxx"
spec:
  target:
    type: "product" | "offer" | "tokenType"
    id: "PRD-xxxxx"            # або OFF-/TT-
  tjm:
    stages: ["in-city"]
    steps:
      - id: "STEP-MORNING-COFFEE"
        relation: "available"  # available | recommended | required
    microJourneys:
      - id: "MJ-CITY-MORNING-COFFEE"
```

Призначення:

* формалізувати, **де в подорожі** продукт/токен має сенс;
* дозволити агентам:

  * пропонувати релевантні продукти в потрібний момент;
  * будувати коректні флоу (без «кава в аеропорту після check-out»).

### 4.2. Відповідність доменам

* `Journey`, `Stage`, `Step` мапляться на доменні сутності `Trip`, `Segment`, `POI`, `Route` в `DOMAIN-tourism`, `DOMAIN-city`;
* DSL не дублює цю модель, а **референсить** її через ID:

  * `tjm.stageId`, `tjm.stepId`, `tjm.microJourneyId`.

---

## 5. TJM ↔ Tokens

### 5.1. Споживання токенів у TJM

Кожен `TokenType` має:

* `defaultStages` — де логічно його споживати;
* `allowedStages` — де це дозволено;
* `forbiddenStages` — де цього не повинно бути.

Приклад (coffee token):

```yaml
spec:
  entitlementKind: "meal"
  tjmUsage:
    defaultStages: ["in-city"]
    allowedStages: ["arrival", "in-city"]
    forbiddenStages: ["pre-trip", "return", "post-trip"]
```

### 5.2. Подійна модель

Ключові події:

* `tjm_step_entered`
* `tjm_step_completed`
* `token_redeemed_at_tjm_step`
* `micro_journey_started/completed`

В аналітиці це збирається у funnels:

* «скільки користувачів з pre-trip booking дійшли до in-city coffee redemption»;
* «які micro-journeys реально відбуваються».

---

## 6. TJM ↔ ABC (комʼюніті)

### 6.1. Групові потреби в TJM

Для ABC:

* `DemandPool` може бути привʼязаний до Stage/Step:

```yaml
tjmContext:
  stage: "in-city"
  step: "STEP-MORNING-COFFEE"
  cityId: "CITY-VIENNA"
```

Це дозволяє:

* агрегувати попит «по розкладу подорожі»;
* робити групові офери, які логічні в цьому контексті.

### 6.2. Micro-journeys як одиниці планування

Micro-journey з точки зору ABC:

* зручно агрегувати попит не на один продукт, а на **патерн**:

  * «ранок у місті»,
  * «вечірній ресторан + бар»,
  * «медичний ранковий слот + обід».

TJM задає структуру цих micro-journeys, DSL описує продукти, які їх наповнюють.

---

## 7. Data & Storage

### 7.1. Canonical TJM registry

Розміщення (логічно):

```txt
data/canonical/tourism/journeys.*
data/canonical/city/routes.*
domains/tourism/tjm-*.md
domains/city/city-graph-*.md
```

Вимоги:

* стабільні ID для stages/steps/micro-journeys;
* можливість розширювати:

  * city-специфічні micro-journeys;
  * domain-специфічні steps (наприклад, medical).

### 7.2. Аналітичний шар

Основні таблиці/види (логічно):

* `tjm_events` — всі події;
* `tjm_funnels` — агреговані переходи між steps;
* `tjm_micro_journey_stats` — performance micro-journeys.

PD-006 тільки фіксує **що** повинно бути; фізичні схеми — у DOMAIN + VG-9xx.

---

## 8. Governance & Versioning

### 8.1. Зміни в TJM

Будь-яка зміна:

* нового Stage/Step/Micro-journey;
* зміна семантики існуючого;

повинна:

* бути задокументована в PD-006 / DOMAIN-tourism;
* мати:

  * migration plan для DSL (JourneyBinding),
  * вплив на аналітику (funnels).

### 8.2. City-specific extensions

Правило:

* **Global TJM** — фіксує базові stages/типи steps;
* **City-level доповнення**:

  * додають micro-journeys, routes, але не ламають глобальні дефініції.

Формат:

* global: `tjm/stages.yaml`, `tjm/steps.yaml`;
* per-city: `tjm/cities/Vienna/*.yaml`.

---

## 9. Використання агентами

AI-/Codex-агенти:

* при генерації продуктів/оферів:

  * повинні запитувати TJM-контекст (stage/step/micro-journey);
* при рекомендаціях:

  * використовують TJM як constraint:

    * не пропонувати «невчасні» продукти;
* при аналізі:

  * читати аналітичні дані через «TJM-мову»:

    * «на етапі pre-trip → …»,
    * «на micro-journey MJ-CITY-MORNING-COFFEE → …».

---

## 10. Подальші документи

На базі PD-006:

* **DOMAIN-tourism-tjm-core.md** — формальні схеми TJM-entity (ER/DBML).
* **VG-8xx — TJM Runtime & Events** — як події формуються в коді / event bus.
* **VG-9xx — Journey Analytics** — canonical funnels, когорти, метрики.
* City-specific PD/VG — Vienna, інші міста.

PD-006 — це **референсний каркас TJM**. Усі продуктові сценарії мають узгоджуватись із ним; якщо ні — спочатку оновлюється PD-006, потім DSL та runtime.
