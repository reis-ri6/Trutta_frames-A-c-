# PD-010 Ops Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform Ops / Safety / Architecture

**Related docs:**  
- PD-008-product-runtime-and-agents-spec.md  
- PD-008-product-runtime-events.md  
- PD-009-financial-links.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-010-ops.ddl.sql  
- PD-010-ops-templates.md  
- PD-004-tjm-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md  
- PD-006-lem-city-graph-links.md  
- PD-005-trutta-links.md

Мета — описати **як Ops/Safety/Quality-шар (PD-010) зв’язаний з:**

- TJM Operational Layer (journey runtime, operational state machine);
- LEM safety- та coverage-метриками;
- Trutta компенсаціями (compensation flows, goodwill tokens).

Фокус — **контракти та подієві цикли**, не детальний код.

---

## 1. Components & Boundaries

### 1.1 Components

- **TJM Operational Layer (TJM-OPS)**  
  - відповідає за execution journey: ноди, стани, retries, fallbacks;  
  - емить `journey.*`, `journey.node.*`, `runtime.*` події.

- **Ops/Safety/Quality Engine (OPS-ENG)**  
  - зберігає профілі (Ops/Safety/Quality) через Registry;  
  - трекає SLI/SLO;  
  - застосовує `ops_policies` і `safety_overrides`;  
  - створює `ops_incidents`.

- **LEM (City Graph & Safety)**  
  - джерело `safety_score`, `coverage_score`, `night_risk_score` для service_point/route/cluster;  
  - емить `lem.*` події (coverage/safety degradation, incidents на рівні міста).

- **Trutta Core (Entitlements & Settlement & Compensation)**  
  - управляє entitlements/tokens, redemption, settlement та compensation-tokens;  
  - емить `entitlement.*`, `token.*`, `settlement.*`, `compensation.*` події.

- **Billing / Customer Care / Vendor Ops**  
  - платіжні повернення (refund);  
  - ручні компенсації, dispute-менеджмент.

### 1.2 Boundaries

- TJM не зберігає політик — лише виконує їх, читаючи профілі / overrides / policies.  
- LEM не приймає кінцевих рішень щодо блокувань продуктів — він дає сигнали, OPS-ENG застосовує політики.  
- Trutta не вирішує, коли робити компенсацію — він виконує затверджену компенсацію як технічний протокол.

---

## 2. TJM Operational Layer ↔ Ops/Safety/Quality

### 2.1 Preflight

Перед створенням `product.runtime.session` TJM-OPS виконує preflight:

1. Отримує `OpsProfile`, `SafetyProfile`, `QualityProfile` для product_version/market (через Registry).  
2. Запитує OPS-ENG:

```json
{
  "type": "preflight_check",
  "product_version_id": "PRDV-...",
  "market_code": "AT-VIE",
  "city_code": "VIE",
  "user_context": {"segments": ["tourist"], "risk_flags": []},
  "journey_blueprint_id": "JRNY-VIEN-COFFEE"
}
```

3. OPS-ENG:
   - застосовує `ops_policies` (slo_threshold/runtime_action) + `safety_overrides`;  
   - повертає рішення:

```json
{
  "status": "ok|degraded|blocked",
  "reason": "SLO_BREACH|SAFETY_RISK|QUALITY_LOW|NONE",
  "actions": ["use_degraded_mode", "fallback_routes_only"],
  "applied_policy_ids": ["OPS-POL-SAFETY-ROUTE-VIEN"],
  "effective_overrides": [
    {"scope": "route", "route_id": "ROUTE-VIEN-COFFEE-01", "action": "fallback"}
  ]
}
```

4. TJM-OPS або створює сесію (можливо в degraded режимі), або відхиляє старт (preflight_failed) і емить подію з причиною.

### 2.2 Runtime supervision

Під час виконання journey TJM-OPS:

- додає до кожної ноди контекст safety/quality (через LEM/OPS-ENG);  
- при помилках/аномаліях викликає OPS-ENG для оцінки:

```json
{
  "type": "runtime_event",
  "event": "journey.node.failed",
  "product_runtime_session_id": "PRS-...",
  "journey_node_id": "NODE-123",
  "error": {"code": "VENDOR_NO_SHOW", "vendor_id": "VEN-123"}
}
```

OPS-ENG може:

- створити/оновити `ops_incidents` (PD-010-ops.ddl);  
- записати `safety_overrides` (наприклад, `block` цього маршруту);  
- повернути TJM-OPS рекомендації (fallback route, stop journey).

### 2.3 Lifecycle & quality gates

Переходи product_version / product_profile між статусами (design → beta → prod → retired) проходять через quality gates з PD-010.  
TJM та Registry взаємодіють через PD-003/PD-007, але рішення про **дозвіл launch / stop-sell** приймаються OPS-ENG згідно `ops_policies`.

---

## 3. LEM Safety Metrics ↔ Ops/Safety/Quality

### 3.1 Metrics flow

LEM підтримує для service_point/route:

- `safety_score` (0–1),  
- `night_risk_score` (0–1),  
- `coverage_score` (0–1),  
- списки recent incidents та risk tags.

Ці метрики:

- зберігаються в таблицях city-graph (PD-006-lem-city-graph.ddl.sql);  
- агрегуються в `quality_scores` (типи `content`, `custom`) для подальших політик;  
- використовуються під час preflight/runtime як частина SafetyProfile.

### 3.2 LEM → OPS-ENG events

LEM емить події, наприклад:

```json
{
  "event": "lem.route.safety_degraded",
  "route_id": "ROUTE-VIEN-COFFEE-01",
  "city_code": "VIE",
  "previous_score": 0.82,
  "current_score": 0.71,
  "threshold": 0.80
}
```

OPS-ENG:

- шукає відповідні `ops_policies` (тип `safety_rule`, scope `city/route`);  
- якщо спрацьовує умова, створює `safety_overrides` (`fallback` або `block`), `ops_incidents` і нотифікації в Ops console;  
- опціонально оновлює агреговані `quality_scores`.

### 3.3 TJM consumption

При побудові маршрутів TJM-OPS:

- читає актуальні `safety_overrides` для route/vendor/service_point;  
- фільтрує/переплановує маршрути згідно action (`block`, `deprioritize`, `fallback`).

Важливо: LEM не блокує маршрути сам — він тільки знижує score та емить події; фактична заборона йде через `safety_overrides` та TJM-OPS.

---

## 4. Trutta Compensation Flows ↔ Ops & Quality

### 4.1 When compensation is considered

Компенсації включаються при:

- **SLO/SLA breach:** availability / journey success / safety / quality SLO порушені.  
- **Vendor/service failure:** no-show, poor service, значні скарги.  
- **System failures:** баги платформи, що зіпсували досвід.

OPS-ENG детектує такі кейси через:

- `ops_incidents` (source: prg/tjm/lem/trutta/monitoring);  
- аналітичні джоби (slo-breach, high complaint rate, etc.).

### 4.2 Compensation decision flow

1. Інцидент створено в `ops_incidents` з severity, причиною та контекстом (product_version, vendor, journey_instance).  
2. Запускається **compensation policy** (часто окремий `ops_policy` або зовнішній rules-engine):
   - перевіряється тип інциденту, вина (vendor/platform/mixed), рівень сервісу;
   - перевіряється історія користувача (частота компенсацій, fraud flags з Trutta).
3. Формується `compensation_proposal`:

```json
{
  "incident_id": "OPS-INC-...",
  "user_id": "USR-...",
  "product_version_id": "PRDV-...",
  "vendor_id": "VEN-123",
  "proposed_channel": "trutta_token|refund|mixed",
  "proposed_value": {
    "type": "percentage_of_amount",
    "value": 100,
    "cap": 50.00,
    "currency": "EUR"
  },
  "requires_approval": true
}
```

4. Залежно від політики governance (PD-013), рішення може бути:
   - автоматичне (low/medium severity, прості правила);  
   - з ручним approval у Ops/Vendor Ops / Customer Care.

### 4.3 Trutta as compensation rail

Якщо обрано канал `trutta_token`:

1. OPS-ENG або Customer Care викликає Trutta API `compensation.issue`:

```json
{
  "incident_id": "OPS-INC-...",
  "user_id": "USR-...",
  "compensation_profile_id": "COMP-VIEN-COFFEE-100",
  "value": {
    "amount": 20.00,
    "currency": "EUR"
  },
  "meta": {
    "reason": "VENDOR_NO_SHOW",
    "notes": "Full compensation as tokens for Vienna Coffee Pass."
  }
}
```

2. Trutta створює спеціальний entitlement/token (compensation entitlement), емить `compensation.issued` / `entitlement.issued`.  
3. Цей entitlement можна використати як:
   - знижку на майбутній продукт;  
   - безкоштовний продукт;  
   - частину пакетної компенсації.
4. Всі compensation-транзакції відображаються в DWH / unit economics як окремий вид cost.

### 4.4 Refund flow (Billing)

Якщо потрібно **грошове повернення**:

- OPS-ENG передає рішення в Billing: `refund.requested` з посиланням на incident/compensation_policy.  
- Billing робить refund через PSP, емить `billing.refund.succeeded/failed`.  
- Trutta може (опційно) анулювати пов’язані entitlements/tokens (`entitlement.revoked`) або перевести їх у спеціальний статус.

---

## 5. Data & Analytics Links

### 5.1 From incidents to P&L

У DWH ми лінкуємо:

- `ops_incidents` → `fact_orders` / `fact_redemptions` / `fact_settlements`;  
- `compensation.*` події з Trutta → `fact_compensations`;  
- refund events з Billing → `fact_refunds`.

Це дозволяє:

- рахувати **вартість інцидентів** (compensation cost + refunds + lost revenue);  
- бачити розподіл інцидентів по product/market/vendor/route;  
- оцінювати ефективність preventive policies (менше інцидентів при зміні порогів).

### 5.2 Feedback loop в профілі

- Зростання complaint rate / incident rate → через аналітику оновлюються `quality_scores`.  
- Оновлені `quality_scores` стають частиною входу для:
  - QualityProfile thresholds;  
  - `ops_policies` типу `quality_gate`;  
  - SafetyProfile для vendor/route.

Таким чином утворюється **замкнений контур**:  
"runtime → інциденти/фідбек → аналітика → профілі/політики → runtime".

---

## 6. Governance & Roles

### 6.1 Who owns what

- **Product / City Teams:**
  - визначають цільові SLO/threshold-и, якість контенту, acceptable risk;  
  - погоджують compensation-політики для своїх продуктів/міст.

- **Platform Ops / SRE:**
  - формують глобальні `ops_policies`;  
  - відповідають за OpsProfile, доступність, інцидент-процес.

- **Safety / Risk:**
  - формують SafetyProfile;  
  - визначають пороги LEM/Trutta fraud/safety;
  - власники safety_overrides на глобальному рівні.

- **Finance / Legal:**
  - узгоджують SLA/credits;  
  - визначають рамки compensation budget та типи компенсацій.

### 6.2 Change workflow

Будь-які зміни, що впливають на TJM-OPS / LEM / Trutta:

1. Оформляються як зміни профілів/ops_policies в конфіг-репозиторії.  
2. Проходять review/approval (PD-013-governance).  
3. Деплой через CI (PD-012-tooling).  
4. Моніторимо ефект (зміна incident rate, NPS, compensation cost).

---

## 7. Summary

- TJM-OPS використовує Ops/Safety/Quality профілі та `ops_policies` для preflight і runtime-рішень;  
- LEM постачає safety/coverage метрики, а фактичні блокування/фолбеки реалізуються через OPS-ENG та `safety_overrides`;  
- Trutta використовується як **універсальний рейл компенсацій** (tokens/entitlements), синхронізований з інцидентами, SLA та фінансовою аналітикою;  
- Увесь цикл "досвід → інциденти → компенсації → аналітика → політики" формалізований як частина Product DSL, без ручної магії в окремих продуктах/містах.

