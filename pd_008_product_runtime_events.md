# PD-008 Product Runtime Events v0.1

**Status:** Draft 0.1  
**Owner:** Platform Runtime & Observability

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md  
- PD-007-product-profiles-spec.md  
- PD-007-product-profiles-links.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Цей документ задає **канонічний список подій продуктового рантайму**:

- `product.runtime.*` — життєвий цикл ProductRuntimeSession;
- `journey.*` — виконання TJM-journey;
- `entitlement.*`, `token.*`, `settlement.*` — Trutta-шар;
- `lem.*` — використання city graph / routing / experience;
- `loyalty.*`, `cx.*` — лояльність та якість;
- `agent.*` — робота AI-агентів;
- допоміжні `runtime.error`, `runtime.degraded`.

### 1.2 Scope

Визначається:

- загальний **envelope** події;  
- обов’язкові correlation-поля;  
- ключові `data.*` поля для кожного типу події;  
- інваріанти та очікувана семантика.

Не визначається:

- конкретна transport-технологія (Kafka/NATS/etc);  
- схеми збереження в DWH;  
- повний список edge-case-полів.

---

## 2. Event Envelope & Conventions

### 2.1 Naming

- `event_type` — snake-case з крапками:
  - `product.runtime.created`
  - `journey.node.completed`
  - `entitlement.redeemed`
  - `agent.recommendation.accepted`

Версії payload’ів несумісні назад відображаються полем `schema_version`, а не зміною `event_type`.

### 2.2 Canonical envelope

Усі події мають спільний envelope (логічна схема):

```json
{
  "event_id": "EVT-ULID-...",
  "event_type": "product.runtime.activated",
  "schema_version": 1,

  "occurred_at": "2025-11-01T10:15:23.123Z",
  "emitted_at": "2025-11-01T10:15:23.456Z",

  "source": "product-runtime-gateway",   
  "producer_instance_id": "prg-1a2b3c",

  "correlation": {
    "product_runtime_session_id": "PRS-000123",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "product_id": "PRD-VIEN-COFFEE-PASS",

    "market_code": "AT-VIE",
    "city_code": "VIE",

    "journey_instance_id": "JRN-000456",
    "user_id": "USR-0001",
    "avatar_id": "AVT-0001",

    "wallet_id": "WAL-USER-0001",
    "vendor_wallet_id": null,

    "trace_id": "TRACE-...",
    "span_id": "SPAN-..."
  },

  "profiles": {
    "token_profile_id": "PRF-TOKEN-VIEN-COFFEE-PASS",
    "loyalty_profile_id": "PRF-LOYALTY-VIEN-COFFEE-PASS",
    "pricing_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",
    "ops_profile_id": "PRF-OPS-VIEN-COFFEE-PASS",
    "safety_profile_id": "PRF-SAFETY-VIEN-COFFEE-PASS",
    "quality_profile_id": "PRF-QUALITY-VIEN-COFFEE-PASS",
    "ui_profile_id": "PRF-UI-VIEN-COFFEE-PASS"
  },

  "data": { /* event-specific payload */ }
}
```

### 2.3 Invariants

- `event_id` — глобально унікальний (ULID);  
- `occurred_at <= emitted_at`;  
- `product_version_id` має існувати в Registry;  
- `product_runtime_session_id` — обов’язковий для всіх рантайм-подій, крім деяких системних (наприклад, глобальний `lem.degraded`).

---

## 3. Product Runtime Events (`product.runtime.*`)

### 3.1 product.runtime.created

Емиться при створенні `ProductRuntimeSession`.

**data:**

```json
{
  "reason": "user_initiated",   
  "client": {
    "channel": "mobile_app",   
    "app_version": "1.2.3"
  },
  "initial_segments": ["tourist", "kidney"],
  "experiment_keys": ["vien_coffee_ab_10off"]
}
```

Інваріанти:

- стан сесії переходить `null → created`.

### 3.2 product.runtime.preflight_ok / preflight_failed

Результат preflight-фази.

`product.runtime.preflight_ok` — успіх;
`product.runtime.preflight_failed` — відмова.

**data (ok):**

```json
{
  "checks": {
    "product_status": "ok",
    "effective_window": "ok",
    "limits": "ok",
    "safety": "ok",
    "coverage": "ok",
    "risk": "ok"
  }
}
```

**data (failed):**

```json
{
  "failure_code": "SAFETY_COVERAGE_INSUFFICIENT",
  "failure_message": "Not enough safe service points in requested area.",
  "checks": {
    "product_status": "ok",
    "limits": "ok",
    "safety": "failed",
    "coverage": "failed"
  }
}
```

Інваріанти:

- `preflight_ok` → сесія може перейти в `pending_payment` або одразу в `active` (для free-проодуктів);  
- `preflight_failed` → термінальний стан `preflight_failed`, далі тільки `canceled`.

### 3.3 product.runtime.payment_pending / payment_captured / payment_failed

**data (payment_pending):**

```json
{
  "payment_intent_id": "PAYINT-0001",
  "amount": 1700,
  "currency": "EUR",
  "provider": "stripe",
  "return_url": "https://..."
}
```

**data (payment_captured):**

```json
{
  "payment_intent_id": "PAYINT-0001",
  "amount": 1700,
  "currency": "EUR",
  "provider": "stripe",
  "captured_at": "2025-11-01T10:15:00Z"
}
```

**data (payment_failed):**

```json
{
  "payment_intent_id": "PAYINT-0001",
  "failure_code": "CARD_DECLINED",
  "failure_message": "Insufficient funds."
}
```

### 3.4 product.runtime.activated

Сесія переходить у `active` (успішний preflight + payment/token issue, якщо потрібно).

**data:**

```json
{
  "activation_reason": "payment_captured",
  "entitlement_ids": ["TRT-ENT-0001", "TRT-ENT-0002"],
  "token_ids": []
}
```

### 3.5 product.runtime.degraded

Фіксує перехід у деградований режим (наприклад, LEM/Trutta/agents degraded).

```json
{
  "component": "lem-routing",
  "mode": "fallback_static_routes",
  "reason": "LEM_UNAVAILABLE",
  "details": "Routing timeout > 3s for 80% requests."
}
```

### 3.6 product.runtime.completed / canceled / failed

**completed:**

```json
{
  "completion_status": "success",   
  "journey_status": "completed",   
  "entitlements_summary": {
    "issued": 5,
    "redeemed": 4,
    "expired": 1
  },
  "loyalty_points_earned": 120
}
```

**canceled:**

```json
{
  "cancel_reason": "user_request",   
  "cancel_message": null
}
```

**failed:**

```json
{
  "failure_code": "TRUTTA_PERMANENT_ERROR",
  "failure_message": "Settlement contract reverted.",
  "recoverable": false
}
```

---

## 4. Journey Events (`journey.*`)

### 4.1 journey.started

Старт TJM-journey, прив’язаної до ProductRuntimeSession.

```json
{
  "journey_instance_id": "JRN-000456",
  "journey_doc_id": "TJM-VIEN-COFFEE-PASS-BASE",
  "entry_point": "start",
  "facets": ["coffee_walk"],
  "runtime_overlays": {
    "safety_profile_id": "PRF-SAFETY-VIEN-COFFEE-PASS",
    "ui_profile_id": "PRF-UI-VIEN-COFFEE-PASS"
  }
}
```

### 4.2 journey.node.entered / journey.node.completed / journey.node.skipped

```json
{
  "node_id": "NODE-COFFEE-STOP-1",
  "node_type": "visit_venue",   
  "service_point_id": "SP-VIE-CAFE-0001",
  "step_index": 3,
  "reason": "user_navigation"   
}
```

Для `completed` додається:

```json
{
  "duration_seconds": 900,
  "outcome": "success"   
}
```

Для `skipped`:

```json
{
  "skip_reason": "user_choice"   
}
```

### 4.3 journey.route.generated

Результат LEM-ROUTING.

```json
{
  "route_id": "ROUTE-VIE-COFFEE-0001",
  "service_point_ids": ["SP-VIE-CAFE-0001", "SP-VIE-POI-0001", "SP-VIE-CAFE-0002"],
  "metrics": {
    "total_distance_meters": 1200,
    "total_travel_time_seconds": 900,
    "min_safety_score": 0.85
  }
}
```

### 4.4 journey.completed / journey.abandoned

```json
{
  "status": "completed",             
  "completion_reason": "all_nodes_completed",
  "total_duration_seconds": 5400,
  "nodes_completed": 7,
  "nodes_skipped": 1
}
```

Для `abandoned` — `completion_reason` = `user_abandoned` або `timeout`.

---

## 5. Trutta Events (`entitlement.*`, `token.*`, `settlement.*`)

### 5.1 entitlement.issued

```json
{
  "trutta_entitlement_id": "TRT-ENT-0001",
  "entitlement_profile_id": "TRT-ENT-VIEN-COFFEE-PASS",
  "token_profile_id": "TRT-TKN-VIEN-COFFEE-PASS",

  "units": 5,
  "valid_from": "2025-11-01T10:15:00Z",
  "valid_until": "2025-11-03T10:15:00Z",

  "wallet_id": "WAL-USER-0001",
  "vendor_id": null
}
```

### 5.2 entitlement.redeemed

```json
{
  "trutta_entitlement_id": "TRT-ENT-0001",
  "redemption_id": "RED-0001",
  "units_redeemed": 1,

  "service_point_id": "SP-VIE-CAFE-0001",
  "vendor_id": "VEN-VIE-CAFE-0001",

  "redeemed_at": "2025-11-01T11:05:00Z",
  "client": {
    "channel": "vendor_app"
  }
}
```

### 5.3 entitlement.expired / entitlement.canceled

```json
{
  "trutta_entitlement_id": "TRT-ENT-0001",
  "reason": "valid_until_passed"   
}
```

### 5.4 token.issued / token.transferred / token.burned

Мінімальний payload:

```json
{
  "token_id": "TKN-0001",
  "network": "polygon",
  "contract": "0x...",
  "standard": "erc20|erc721|erc1155|spl",

  "from_wallet": null,
  "to_wallet": "WAL-USER-0001",
  "amount": "1"
}
```

### 5.5 settlement.performed

```json
{
  "settlement_batch_id": "SETB-0001",
  "trutta_settlement_profile_id": "TRT-SET-VIEN-COFFEE-PASS",

  "vendor_id": "VEN-VIE-CAFE-0001",
  "currency": "EUR",
  "gross_amount": 120.0,
  "net_amount": 100.0,
  "fees_amount": 20.0,

  "period_start": "2025-11-01T00:00:00Z",
  "period_end": "2025-11-01T23:59:59Z"
}
```

---

## 6. LEM Events (`lem.*`)

### 6.1 lem.route.requested / lem.route.failed

```json
{
  "request_id": "LEM-REQ-0001",
  "city_code": "VIE",
  "origin_service_point_id": "SP-VIE-CAFE-0001",
  "target": {
    "type": "class",
    "class_ids": ["cafe.coffee_partner"],
    "count": 3
  },
  "constraints": {
    "min_safety_score": 0.7,
    "max_walk_time_minutes": 20
  }
}
```

`lem.route.failed` додає `failure_code` / `failure_message`.

### 6.2 lem.route.generated

Дублює payload `journey.route.generated`, але на стороні LEM як system-event (без прямої прив’язки до product_runtime_session, якщо це pre-compute).

### 6.3 lem.coverage.degraded

```json
{
  "city_code": "VIE",
  "service_point_class_id": "cafe.coffee_partner",
  "facet_id": "coffee_walk",

  "coverage_before": 0.9,
  "coverage_after": 0.6,

  "threshold": 0.8
}
```

### 6.4 lem.degraded

Глобальний статус LEM.

```json
{
  "component": "lem-routing",
  "status": "degraded",
  "reason": "UPSTREAM_MAP_PROVIDER_LIMIT",
  "fallback_mode": "static_routes_only"
}
```

---

## 7. Loyalty & CX Events (`loyalty.*`, `cx.*`)

### 7.1 loyalty.points_earned / loyalty.points_redeemed

```json
{
  "loyalty_account_id": "LOY-ACC-0001",
  "currency_code": "COFFEE_POINTS",

  "points_delta": 10,
  "balance_after": 120,

  "reason": "entitlement_redeemed",
  "linked_event_id": "EVT-..."
}
```

### 7.2 cx.survey.sent / cx.survey.completed

```json
{
  "survey_template_id": "SURV-VIEN-COFFEE-PASS-01",
  "survey_instance_id": "SURVINST-0001",
  "channel": "email|push|in_app"
}
```

Для `cx.survey.completed`:

```json
{
  "survey_instance_id": "SURVINST-0001",
  "nps_score": 9,
  "csat_score": 5,
  "responses": {
    "q1": "Great coffee selection.",
    "q2": "Would recommend."
  }
}
```

### 7.3 cx.review.created / cx.review.updated

```json
{
  "review_id": "REV-0001",
  "target_type": "service_point|product",
  "target_id": "SP-VIE-CAFE-0001",

  "rating": 5,
  "title": "Amazing coffee",
  "body": "...",
  "language": "en"
}
```

---

## 8. Agent Events (`agent.*`)

### 8.1 agent.task.created / agent.task.completed / agent.task.failed

```json
{
  "agent_task_id": "ATASK-0001",
  "agent_type": "trip_planner|journey_guide|support|pricing|safety|growth",
  "agent_name": "trip_planner.v1",

  "input_context_hash": "ctx-hash-...",
  "ttl_ms": 5000
}
```

Для `completed`:

```json
{
  "agent_task_id": "ATASK-0001",
  "duration_ms": 1200,
  "output_summary": "Planned 3-stop coffee route.",
  "output_size_bytes": 4096
}
```

Для `failed`:

```json
{
  "agent_task_id": "ATASK-0001",
  "failure_code": "LLM_TIMEOUT",
  "failure_message": "Upstream LLM did not respond in time.",
  "retry_suggested": true
}
```

### 8.2 agent.recommendation.shown / accepted / rejected

```json
{
  "recommendation_id": "AREC-0001",
  "agent_task_id": "ATASK-0001",

  "recommendation_type": "route_change|upsell_product|tip",
  "payload_hash": "payload-hash-..."
}
```

Для `accepted`/`rejected`:

```json
{
  "recommendation_id": "AREC-0001",
  "decision": "accepted",
  "decision_at": "2025-11-01T11:20:00Z"
}
```

---

## 9. Error & Degraded Events (`runtime.*`, `ops.*`)

### 9.1 runtime.error

Універсальна помилка на рівні рантайму.

```json
{
  "error_code": "TJM_UNEXPECTED_EXCEPTION",
  "error_message": "Null reference at node XYZ.",

  "component": "tjm-runtime",
  "severity": "high",

  "stack_trace_hash": "hash-..."
}
```

### 9.2 runtime.degraded

Загальний сигнал деградації (дублює компонент-специфічні події типу `lem.degraded`).

```json
{
  "component": "product-runtime-gateway",
  "status": "degraded",
  "reason": "DEPENDENCY_TIMEOUT",
  "details": "Trutta latency > 2s p95"
}
```

### 9.3 ops.incident.created / updated / resolved

```json
{
  "incident_id": "INC-0001",
  "severity": "high",
  "status": "created|acknowledged|resolved",

  "primary_component": "trutta-runtime",
  "related_event_ids": ["EVT-..."],

  "summary": "High error rate on entitlement.issue",
  "runbook_ref": "VG-1001-TRUTTA-ENTITLEMENT-ISSUE"
}
```

---

## 10. Storage, Transport & Idempotency (Logical)

- Події доставляються з **at-least-once** гарантією → усі consumers мають бути idempotent (ключ — `event_id`).
- Повинна існувати **DLQ / quarantine** для подій із невалідними payload’ами.
- PII-поля мають бути обмежені/анонімізовані у системних темах (окремі канали для повних payload’ів, доступні тільки обмеженим системам).

---

## 11. Summary

- PD-008-events задає **єдину подійну мову** для продуктового рантайму: product runtime, journey, Trutta, LEM, loyalty, CX, агенти, ops.  
- Всі сервіси повинні емити/споживати події через цей спільний контракт; нові події додаються через governance-процес із версіонуванням `schema_version`.  
- Це основа для спостережуваності (observability), аналітики, fraud/risk моделей і роботи AI-агентів поверх платформи.

