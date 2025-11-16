# PD-004 TJM Integration Templates v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Journey Runtime Architecture

**Related docs:**  
- PD-004-tjm-integration-spec.md  
- PD-003-registry-api.yaml  
- PD-003-registry-and-versioning-templates.md  
- PD-002-product-domain-model-templates.md

Мета документа — дати **еталонні шаблони** для інтеграції Product DSL / Registry з TJM:

- TJM JourneyClass / JourneyDoc (логічні структури);
- Registry-side JourneyBinding;
- runtime event envelopes (product ↔ journey ↔ integration);
- кеш-конфіг TJM для продукту.

Усі приклади — на базі умовного продукту **Vienna Coffee Day Pass** (`city.coffee.pass`).

---

## 1. JourneyClass Template (TJM side)

> Це живе у TJM (TJM-kind registry), але Registry кешує важливі поля.

### 1.1 `city.coffee.pass` — JourneyClass (YAML)

```yaml
id: city.coffee.pass
version: 1.0.0
kind: journey-class
meta:
  title: "City Coffee Day Pass"
  description: "One-day coffee pass journey in a city (e.g. Vienna)."
  owner: "tjm-core@reis.agency"

classification:
  category: "city-pass"
  tags:
    - coffee
    - food-and-beverage
    - vienna

entry_points:
  - app.home.hero
  - city.vienna.offers

micro_journeys:
  - pre_trip
  - in_city
  - post_trip

allowed_product_types:
  - PASS

allowed_markets:
  - AT-VIE
  - AT-*

runtime_contract:
  required_events:
    - journey.started
    - journey.completed
    - journey.cancelled
  optional_events:
    - journey.node.entitlement_claimed
    - journey.node.vendor_issue

versioning:
  compatibility:
    min_spec_version: "1.0.0"
    max_spec_version: "1.x"
```

---

## 2. JourneyDoc Template (TJM side)

> Спрощений приклад графа станів для `city.coffee.pass`. Реальна TJM-специфікація може бути складнішою.

### 2.1 JourneyDoc YAML

```yaml
id: TJM-JOURNEY-COFFEE-PASS
version: 1.0.0
class_id: city.coffee.pass
kind: journey-doc

meta:
  title: "Vienna Coffee Day Pass Journey"
  description: "Day-long journey with multiple coffee shop visits in Vienna."
  owner: "tjm-vienna@reis.agency"

micro_journeys:
  pre_trip:
    description: "User purchases and prepares for the pass."
    entry_nodes:
      - pre_trip_start
  in_city:
    description: "User is in city and redeems coffees."
    entry_nodes:
      - in_city_start

nodes:
  pre_trip_start:
    type: start
    micro_journey: pre_trip
    transitions:
      - event: journey.started
        target: pre_trip_confirmed

  pre_trip_confirmed:
    type: state
    micro_journey: pre_trip
    actions:
      - kind: notify
        channel: app
        template: "journey_pre_trip_confirmed"
    transitions:
      - event: journey.payment_confirmed
        target: in_city_start

  in_city_start:
    type: state
    micro_journey: in_city
    actions:
      - kind: notify
        channel: app
        template: "journey_in_city_start"
    transitions:
      - event: journey.node.entitlement_claimed
        target: in_city_active

  in_city_active:
    type: state
    micro_journey: in_city
    transitions:
      - event: journey.node.entitlement_claimed
        target: in_city_active
      - event: journey.completed
        target: completed
      - event: journey.cancelled
        target: cancelled

  completed:
    type: terminal
  cancelled:
    type: terminal

runtime_policies:
  max_duration_hours: 48
  allow_resume: true
  allow_reopen: false
```

---

## 3. Registry-side JourneyBinding Template

> Це — як Registry зберігає зв’язок `ProductVersion → JourneyDoc`.

### 3.1 JSON snapshot `product.journey_bindings`

```json
{
  "id": "JBN-PRDV-VIEN-COFFEE-PASS-1.0.0",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "journey_class_id": "city.coffee.pass",
  "journey_doc_ref": "TJM-JOURNEY-COFFEE-PASS@1.0.0",
  "entry_points": [
    "app.home.hero",
    "city.vienna.offers"
  ],
  "micro_journeys": [
    "pre_trip",
    "in_city"
  ],
  "state_map": {
    "product_started": "journey.started",
    "product_completed": "journey.completed",
    "product_cancelled": "journey.cancelled",
    "entitlement_claimed": "journey.node.entitlement_claimed"
  },
  "created_at": "2025-11-15T10:05:00Z",
  "created_by": "product-arch@reis.agency"
}
```

### 3.2 Витяг з ProductDef.journey (еталон)

```yaml
journey:
  journey_class_id: city.coffee.pass
  journey_doc_ref: TJM-JOURNEY-COFFEE-PASS@1.0.0
  entry_points:
    - app.home.hero
    - city.vienna.offers
  micro_journeys:
    - pre_trip
    - in_city
  state_map:
    product_started:   journey.started
    product_completed: journey.completed
    product_cancelled: journey.cancelled
    entitlement_claimed: journey.node.entitlement_claimed
```

---

## 4. Runtime Event Envelopes

> Мета — зробити єдиний формат подій, які можуть споживати TJM, Registry, Trutta, аналітика.

### 4.1 Product Runtime Event

```json
{
  "event_type": "product.started",
  "source": "bff.app",
  "occurred_at": "2025-12-01T08:05:00Z",
  "correlation": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "journey_instance_id": "JRN-00012345",
    "user_id": "USR-0001",
    "entitlement_id": null,
    "city_code": "VIE",
    "market_code": "AT-VIE"
  },
  "payload": {
    "channel": "mobile_app",
    "locale": "en",
    "device_id": "device-xyz"
  }
}
```

### 4.2 Journey Runtime Event (TJM internal)

```json
{
  "event_type": "journey.node.entitlement_claimed",
  "source": "tjm.runtime",
  "occurred_at": "2025-12-01T10:15:00Z",
  "correlation": {
    "journey_instance_id": "JRN-00012345",
    "journey_class_id": "city.coffee.pass",
    "journey_doc_ref": "TJM-JOURNEY-COFFEE-PASS@1.0.0",
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "user_id": "USR-0001",
    "entitlement_id": "ENT-123456",
    "node_id": "in_city_active"
  },
  "payload": {
    "vendor_id": "VEN-CAFE-001",
    "location": {
      "lat": 48.2082,
      "lon": 16.3738
    }
  }
}
```

### 4.3 Integration Event (Trutta → TJM)

```json
{
  "event_type": "entitlement.claimed",
  "source": "trutta.core",
  "occurred_at": "2025-12-01T10:15:00Z",
  "correlation": {
    "entitlement_id": "ENT-123456",
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "user_id": "USR-0001"
  },
  "payload": {
    "vendor_id": "VEN-CAFE-001",
    "city_code": "VIE",
    "market_code": "AT-VIE"
  }
}
```

TJM-настройки (або BFF) маплять `entitlement.claimed` → `journey.node.entitlement_claimed` згідно `state_map` з JourneyBinding.

---

## 5. TJM Product Journey Config Cache

> Який кеш-конфіг TJM може тримати для конкретного ProductVersion.

### 5.1 `ProductJourneyConfig` (JSON)

```json
{
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "product_id": "PRD-VIEN-COFFEE-PASS",
  "journey_class_id": "city.coffee.pass",
  "journey_doc_ref": "TJM-JOURNEY-COFFEE-PASS@1.0.0",
  "entry_points": [
    "app.home.hero",
    "city.vienna.offers"
  ],
  "micro_journeys": [
    "pre_trip",
    "in_city"
  ],
  "state_map": {
    "product_started": "journey.started",
    "product_completed": "journey.completed",
    "product_cancelled": "journey.cancelled",
    "entitlement_claimed": "journey.node.entitlement_claimed"
  },
  "runtime_policies": {
    "max_duration_hours": 48,
    "allow_resume": true,
    "allow_reopen": false
  }
}
```

Цей об’єкт TJM будує на основі даних з:

- Registry (`journey_bindings`, `ProductVersion`);
- TJM-kind registry (JourneyClass/JourneyDoc runtime_policies, compatibility).

---

## 6. Bootstrap & Sync Templates

### 6.1 Bootstrap TJM cache (псевдо-code)

```text
1. GET /v1/products/search?status=active&market_code=AT-VIE
2. Для кожного product_id:
   2.1 GET /v1/products/{productId}/resolve?market_code=AT-VIE
   2.2 Витягнути journey_binding з resolved/config
   2.3 Зібрати ProductJourneyConfig (див. розд. 5)
   2.4 Закешувати в TJM
```

### 6.2 Reaction to product.version.status_changed (подія)

```json
{
  "event_type": "product.version.status_changed",
  "aggregate_type": "product_version",
  "aggregate_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "payload": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "env": "prod",
    "old_status": "review",
    "new_status": "active"
  }
}
```

TJM handler (логічно):

```text
1. Отримати event
2. Якщо new_status = active:
   - pull ProductJourneyConfig з Registry
   - встановити JourneyConfig.state = live
3. Якщо new_status = deprecated:
   - встановити JourneyConfig.state = frozen
4. Якщо new_status = retired:
   - встановити JourneyConfig.state = archived
```

---

## 7. Summary

Цей документ задає опорні шаблони для:

- опису JourneyClass та JourneyDoc у TJM;
- зберігання JourneyBinding у Registry;
- уніфікованих runtime event envelopes з кореляційними ключами;
- кеш-конфігів TJM для продуктів та базових флоу bootstrap/sync.

На практиці ці шаблони використовуються як канонічні приклади в SDK, тест-фікстурах та documentation portal для команд, що інтегрують продукти з TJM.

