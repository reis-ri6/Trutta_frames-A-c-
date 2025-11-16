# PD-008 Product Runtime Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform Runtime & Ops

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-004-tjm-integration-links.md  
- PD-005-trutta-links.md  
- PD-006-lem-city-graph-links.md  
- PD-007-product-profiles-links.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-008-product-runtime-events.md  
- PD-010-ops-safety-and-quality-spec.md

Мета — описати **зв’язки runtime-шару** з:

- Agent Orchestrator (AO);
- TJM journey-runtime;
- Ops / Support console;
- Observability-шаром.

Фокус — **контракти та потоки**. Мінімум дубляжу з інших PD.

---

## 1. Product Runtime Gateway (PRG) як хаб

PRG — єдиний edge-вхід у runtime:

- приймає запити від Frontend / зовнішніх агентів;
- створює/керує `ProductRuntimeSession`;
- викликає Registry, TJM, Trutta, LEM, AO;
- емить `product.runtime.*` події.

### 1.1 PRG → Registry

- `GET /runtime/config` (логічно)
  - вхід: `product_id|product_version_id`, `market_code`, `user_id|avatar_id`, segments, experiment keys;
  - вихід: resolved ProductVersion + Profiles (PD-007-links).

PRG **ніколи не тримає** конфіг у собі жорстко — тільки cache поверх Registry.

### 1.2 PRG → TJM / Trutta / LEM / AO (огляд)

- TJM: створення/контроль journey instance.
- Trutta: issue/redeem entitlements/tokens, settlement-trigger’и.
- LEM: routing, coverage, experience.
- AO: виклик AI-агентів у контрольованому режимі (policy, rate, budget).

---

## 2. Runtime ↔ Agent Orchestrator

### 2.1 Контракт PRG/TJM → AO

Всі AI-виклики йдуть через AO.

Логічний запит на агентну задачу:

```json
{
  "agent_task_id": "ATASK-...",        
  "invoker": "prg|tjm|ops_console",    

  "context": {
    "product_runtime_session_id": "PRS-000123",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "journey_instance_id": "JRN-000456",

    "user_id": "USR-0001",
    "avatar_id": "AVT-0001",

    "market_code": "AT-VIE",
    "city_code": "VIE",

    "profiles": {
      "token_profile_id": "PRF-TOKEN-VIEN-COFFEE-PASS",
      "loyalty_profile_id": "PRF-LOYALTY-VIEN-COFFEE-PASS",
      "pricing_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",
      "safety_profile_id": "PRF-SAFETY-VIEN-COFFEE-PASS",
      "ui_profile_id": "PRF-UI-VIEN-COFFEE-PASS"
    },

    "runtime_snapshot_ref": "SNAP-..."  
  },

  "task": {
    "agent_type": "trip_planner|journey_guide|support|pricing|safety|growth",
    "intent": "suggest_next_stop|build_initial_route|explain_limits|offer_upsell",
    "constraints": {
      "max_tokens": 4000,
      "timeout_ms": 5000,
      "max_suggestions": 3
    }
  }
}
```

AO повертає **agent_task.result** у тому ж кореляційному контексті + емить `agent.task.*` events (див. PD-008-events).

### 2.2 Allowed / forbidden actions

- Агенти **не виконують**:
  - payment;
  - прямий Trutta issue/redeem;
  - зміни в Registry/Profiles;
  - low-level LEM mutation.

- Агенти **можуть пропонувати**:
  - зміни маршруту (списком service_point_ids / LEM-constraints);
  - вибір продукту/варіанта (product_id/variant_id);
  - рекомендації по часу/локації/вендору;
  - текстові пояснення користувачу.

PRG/TJM **перетворюють пропозиції** агентів у реальні дії, проходячи:

1. policy-фільтрацію (чи дозволено це в даному статусі/ролі);  
2. повторну валідацію через Profiles (safety/ops/quality);  
3. idempotent виконання;  
4. емісію runtime events (`agent.recommendation.*`, `journey.node.*`, `entitlement.*`).

### 2.3 Budgeting & rate-limiting

AO відповідальний за:

- ліміти на **LLM-витрати** (per session / per user / per org);
- concurrency та rate (щоб агенти не DDOS’или runtime та зовнішні API);
- circuit-breakers при деградації агрегатів (LLM, external APIs).

Runtime бачить AO як **один сервіс** з чіткими SLO (PD-010).

---

## 3. Runtime ↔ TJM Journey Runtime

### 3.1 Створення journey instance

PRG викликає TJM після успішного preflight / purchase:

```json
{
  "product_runtime_session_id": "PRS-000123",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",

  "journey_doc_id": "TJM-VIEN-COFFEE-PASS-BASE",
  "entry_point": "start",

  "profiles": {
    "safety_profile_id": "PRF-SAFETY-VIEN-COFFEE-PASS",
    "ui_profile_id": "PRF-UI-VIEN-COFFEE-PASS"
  },

  "user": {
    "user_id": "USR-0001",
    "segments": ["tourist", "kidney"]
  }
}
```

TJM повертає `journey_instance_id` + початковий state і емить `journey.started`.

### 3.2 TJM → PRG

TJM інформує PRG про важливі зміни стану:

- `journey.completed/abandoned` — PRG може закрити сесію або перевести у post-journey фазу;  
- критичні помилки → `runtime.error` + можливий перехід session у `failed`.

PRG **не втручається в деталі нод**, але має право:

- зупинити journey (`force_abort`) у разі глобальних інцидентів (safety/ops/risk);  
- оновити overlays (наприклад, safety-пороги) при зміні профілів *між* сесіями (не під час поточної journey).

### 3.3 TJM ↔ AO

- TJM може ініціювати задачі для AO (наприклад, «порадь наступну зупинку»).  
- AO → рекомендації; TJM → транслює їх у зміну маршруту/нодів, якщо пройшли policy/runtime-перевірки.

---

## 4. Runtime ↔ Ops / Support Console

### 4.1 Observability feed

Ops console живиться з:

- подій `product.runtime.*`, `journey.*`, `entitlement.*`, `lem.*`, `agent.*`, `ops.incident.*`;  
- агрегованих метрик (SLO/SLA, latency, error rate, success rate).

Console працює **read-mostly**, mutate-операції йдуть через PRG.

### 4.2 Control actions (manual overrides)

Дозволені типи дій з консолі:

- **Session-level:**
  - cancel/force-complete сесію (з логом причини);
  - позначити сесію як підозрілу (risk-flag).

- **Journey-level:**
  - force-skip node;
  - force-complete node;
  - тимчасово заблокувати/відфільтрувати service_point/cluster.

- **Trutta-level (через окремі playbook-и):**
  - ручний re-issue/compensating entitlement;
  - запуск ad-hoc settlement корекцій.

Усі дії:

- йдуть через PRG/TJM/Trutta API (не напряму з UI до backend-сервісів);
- логуються як окремі події `ops.incident.updated/resolved` + audit trail.

### 4.3 Ops ↔ AO

Ops-агенти можуть запускатися:

- автоматично (trigger від SLO-брейку / `runtime.degraded` / `ops.incident.created`);
- вручну з консолі ("explain incident", "suggest mitigation").

AO у цьому кейсі працює як **аналітичний шар**, runtime-модифікації все одно проходять через PRG/Trutta/TJM.

---

## 5. Runtime ↔ Observability Stack

### 5.1 Events → Logs → Metrics → Traces

- **Events:** PD-008-events — канонічне джерело правди для бізнес-стейту.
- **Logs:** деталізовані записи на рівні компонентів (PRG/TJM/Trutta/LEM/AO).
- **Metrics:** SLI/SLO-метрики, агреговані з events+logs (PD-010).
- **Traces:** розподілений трейсинг (`trace_id`, `span_id` в envelope).

Інваріант:

- будь-який інцидент, який видно у console, має лінк до **event_id/trace_id**.

### 5.2 Idempotency & replay

- Consumer-и подій (особливо агенти, аналітика, risk) повинні бути **idempotent по event_id**;  
- дозволяється **replay** подій для аналізу/симуляцій, але тільки в sandbox-оточеннях;
- runtime-компоненти не повинні дублювати бізнес-акторів при replay (окремий канал / flag для "replay-only").

---

## 6. Boundaries & Responsibilities

### 6.1 PRG

- Контракт із зовнішнім світом (API, auth, rate-limit);
- Стейт-машина ProductRuntimeSession;
- Координація TJM/Trutta/LEM/AO;
- Емісія ключових `product.runtime.*` подій.

### 6.2 TJM

- Відповідальний заjourney state machine;  
- Коректну інтеграцію з LEM/Trutta в контексті нод;  
- Емісію `journey.*` подій.

### 6.3 AO

- Керування агентами як pure compute-layer;  
- Без прямого доступу до критичних mutation API;  
- Audit усіх рекомендацій і їхнього впливу.

### 6.4 Ops Console

- Read-mostly UI по events/metrics/traces;  
- Обмежений набір control actions через PRG;  
- Повний audit trail.

---

## 7. Summary

- PD-008-runtime-links фіксує **як саме** runtime інтегрується з AO, TJM та Ops-консоллю: через PRG як єдиний хаб, чіткі подійні контракти та policy-layer між агентами й мутаціями.  
- Агенти залишаються "розумним шаром над даними", а не джерелом небезпечних side-effects; Ops отримує повний visibility та контроль без обходу runtime-інваріантів.  
- Це дозволяє безпечно масштабувати кількість агентів, продуктів і міст, не розвалюючи керованість системи.

