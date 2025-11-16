# PD-015 Test Fixtures JSON – Structure & Conventions v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / QA / Platform

**Related docs:**  
- PD-015-testing-and-conformance-suite.md  
- PD-014-examples-and-templates-library.md  
- PD-014-generated-samples-json  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-012-tooling-cli-and-ci-spec.md

Мета — формалізувати **JSON-структуру тестових фікстур**, які використовуються у PD-015 як вхід для schema/semantic/integration/e2e тестів.

Фокус: один уніфікований формат `*-fixtures.json`, який легко читати `pdsl` та CI.

---

## 1. Розміщення

Фікстури живуть у каталозі:

```text
examples/
  fixtures/
    EX-001-fixtures.json
    EX-002-fixtures.json
    EX-003-fixtures.json
    ...
```

- один файл на `example_id` (EX-XXX);
- опціонально — глобальні фікстури `global-fixtures.json` для крос-продуктових тестів.

---

## 2. Загальна структура файлу

Базовий skeleton:

```json
{
  "_meta": {
    "example_id": "EX-001-vien-geist-city-guide",
    "product_id": "PRD-EX-001-VIEN-GEIST",
    "schema_version": "fixtures:1.0.0",
    "generated_by": "pdsl 0.2.0",
    "generated_at": "2025-01-01T12:34:56Z"
  },
  "dsl": {
    "valid_products": [],
    "invalid_products": [],
    "valid_profiles": [],
    "invalid_profiles": []
  },
  "runtime": {
    "event_sequences": [],
    "negative_scenarios": []
  },
  "integration": {
    "api_calls": [],
    "registry_states": []
  }
}
```

Кожен блок деталізовано нижче.

---

## 3. DSL Fixtures

Секція `dsl` описує валідні й невалідні DSL-документи.

### 3.1 `valid_products`

Список посилань на валідні ProductDef (як правило — на golden samples):

```json
"valid_products": [
  {
    "id": "prd-valid-base",
    "path": "examples/generated/json/EX-001-vien-geist-city-guide/v1.0.0/productdef.base.json",
    "description": "Базовий валідний ProductDef для vien.geist"
  }
]
```

### 3.2 `invalid_products`

Список невалідних ProductDef з очікуваним типом помилки.

```json
"invalid_products": [
  {
    "id": "prd-missing-pricing",
    "path": "examples/tests/payloads/EX-001/productdef.missing-pricing.json",
    "expected_error_code": "PRICING_PROFILE_MISSING",
    "description": "Відсутній pricing_profile_ref для платного продукту"
  },
  {
    "id": "prd-bad-market-code",
    "path": "examples/tests/payloads/EX-001/productdef.bad-market-code.json",
    "expected_error_code": "MARKET_CODE_INVALID"
  }
]
```

### 3.3 `valid_profiles` / `invalid_profiles`

Аналогічно для профілів:

```json
"valid_profiles": [
  {
    "id": "pricing-standard-eu",
    "path": "examples/products/EX-001-vien-geist-city-guide/profiles/pricing.eu.yaml",
    "description": "Стандартний pricing-профіль для AT-VIE"
  }
],
"invalid_profiles": [
  {
    "id": "pricing-negative-price",
    "path": "examples/tests/payloads/EX-001/profile.pricing.negative.json",
    "expected_error_code": "PRICE_NEGATIVE"
  }
]
```

- Вміст може жити окремо (в `examples/tests/payloads/...`), фікстура тільки посилається шляхами.

---

## 4. Runtime Fixtures

Секція `runtime` описує послідовності подій для e2e/semantic тестів.

### 4.1 `event_sequences`

Позитивні (expected success) сценарії.

```json
"event_sequences": [
  {
    "id": "day-tour-basic",
    "description": "Стандартна денна прогулянка з одним прийомом їжі",
    "initial_state": {
      "market": "AT-VIE",
      "user_segment": "traveler",
      "version": "1.0.0"
    },
    "events": [
      { "type": "journey.started" },
      { "type": "journey.checkpoint_reached", "checkpoint_id": "LUNCH-SPOT-1" },
      { "type": "meal.token_claimed", "entitlement_id": "ENT-123" },
      { "type": "meal.token_redeemed", "venue_id": "VEN-456" },
      { "type": "journey.completed" }
    ],
    "expected_outcome": {
      "status": "success",
      "final_journey_state": "completed",
      "tokens_redeemed": 1
    }
  }
]
```

### 4.2 `negative_scenarios`

Негативні/edge-кейси, де очікується помилка/partial success.

```json
"negative_scenarios": [
  {
    "id": "double-redeem",
    "description": "Спроба повторного рідемпшену того самого entitlement",
    "steps": [
      { "type": "meal.token_redeemed", "entitlement_id": "ENT-123" },
      { "type": "meal.token_redeemed", "entitlement_id": "ENT-123" }
    ],
    "expected_error_code": "ENTITLEMENT_ALREADY_REDEEMED",
    "expected_http_status": 409
  }
]
```

---

## 5. Integration Fixtures

Секція `integration` описує API-виклики та очікувані стани Registry/сервісів.

### 5.1 `api_calls`

Структура для contract/integration tests.

```json
"api_calls": [
  {
    "id": "registry-get-product",
    "service": "registry",
    "method": "GET",
    "url": "/v1/products/PRD-EX-001-VIEN-GEIST",
    "query": {},
    "headers": {
      "X-Env": "staging"
    },
    "expected_response": {
      "status": 200,
      "body_match": {
        "product_id": "PRD-EX-001-VIEN-GEIST",
        "markets": ["AT-VIE"]
      }
    }
  },
  {
    "id": "trutta-claim-entitlement",
    "service": "trutta",
    "method": "POST",
    "url": "/v1/entitlements/claim",
    "body": {
      "entitlement_id": "ENT-123",
      "user_id": "USR-TEST-1"
    },
    "expected_response": {
      "status": 200,
      "body_match": {
        "status": "claimed"
      }
    }
  }
]
```

`body_match` може інтерпретуватися як partial-match (JSONPath/"contains").

### 5.2 `registry_states`

Опис очікуваних станів Registry до/після сценаріїв.

```json
"registry_states": [
  {
    "id": "post-publish-state",
    "description": "Стан Registry після publish v1.0.0",
    "snapshot_path": "examples/generated/json/EX-001-vien-geist-city-guide/v1.0.0/registry.snapshot.json"
  }
]
```

У тестах цей snapshot порівнюється із фактичним станом (з допустимими відхиленнями типу timestamps).

---

## 6. Глобальні фікстури

За потреби може існувати `examples/fixtures/global-fixtures.json` для крос-продуктових кейсів:

- міграції схем;  
- performance-профілі;  
- chaos-сценарії (вимкнення сервісу, деградація мережі).

Структура аналогічна, але без `_meta.example_id`.

---

## 7. Використання `pdsl` та CI

### 7.1 `pdsl`

Очікується, що CLI матиме команди на кшталт:

- `pdsl fixtures validate --example EX-001` — валідація структури `EX-001-fixtures.json`;  
- `pdsl test integration --example EX-001` — прогін `api_calls` + `runtime` сценаріїв;  
- `pdsl test semantic --fixtures EX-001-fixtures.json` — семантичні перевірки з опорою на фікстури.

### 7.2 CI

- PR-level: валідуюються фікстури для EX-XXX, в яких були зміни;  
- main/nightly: повний прогін по всіх EX-XXX-фікстурах, що закривають бібліотеку прикладів.

---

## 8. Summary

- `PD-015-test-fixtures.json` задає **єдиний формат** `EX-XXX-fixtures.json` для валідних/невалідних DSL, runtime-послідовностей та інтеграційних сценаріїв.  
- Фікстури живуть окремо від golden samples, але посилаються на них шляхами.  
- Цей формат споживають `pdsl` та CI, забезпечуючи відтворювані schema/semantic/integration/e2e тести для кожного прикладу продукту.

