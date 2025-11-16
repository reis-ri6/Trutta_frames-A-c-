# PD-004 TJM Integration Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Journey Runtime Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-001-product-dsl-core-templates.md  
- PD-002-product-domain-model.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-api.yaml  
- PD-004-tjm-integration-templates.md (next)  
- PD-004-tjm-integration-links.md (next)

**External references (TJM):**  
- TJM-SPEC-core.md — базова модель JourneyClass, JourneyDoc, micro-journey.  
- TJM-RUNTIME.md — рантайм та state machine користувацьких journeys.  
- TJM-COMPILER.md — компіляція/вальдація journey-доків.

Мета документа — формально описати **інтеграцію між Product DSL / Registry та TJM**: мапінг ProductDef → TJM-документи, lifecycle станів, події та точки інтеграції на рантаймі.

> PD-002/003 описують продукт та Registry. PD-004 — як цей продукт стає керованим journey у TJM.

---

## 1. Purpose & Scope

### 1.1 Purpose

- Задати **стабільний контракт** між ProductDef/Registry та TJM:
  - як продукт підключається до JourneyClass;
  - як посилатися на TJM-документи з ProductDef;
  - як TJM читає/оновлює конфіг на основі Registry.

### 1.2 Scope

Входить:

- логічний мапінг `ProductDef.journey` → `JourneyClass/JourneyDoc`;
- lifecycle-стани продукту vs journey-конфігів;
- події product.version.* → TJM;
- точки читання Registry з боку TJM.

Не входить:

- внутрішня структура TJM-доків (див. TJM-SPEC-core.md);
- UX/UI опис journeys;
- деталі state machine користувача (TJM-RUNTIME.md).

---

## 2. Core Concepts (з точки зору інтеграції)

### 2.1 JourneyClass

- Логічний тип journey (напр. `city.coffee.pass`, `hotel.stay`, `kidney.support.trip`).
- Визначається та підтримується у TJM (TJM-kind registry).
- У Registry зберігається як копія/кеш у таблиці `product.journey_classes`.

### 2.2 JourneyDoc (Journey Document)

- Конкретна реалізація JourneyClass:
  - граф станів, micro-journeys, переходи, guards;
  - ID: `journey_doc_id` + `version` (semver).
- У Registry представлений через `product.journey_document_refs`.

### 2.3 JourneyBinding

- Зв’язок між `ProductVersion` та `JourneyDoc`.
- У Registry: `product.journey_bindings`.
- Містить:
  - `product_version_id`;
  - `journey_document_ref_id`;
  - `entry_points` (список логічних entry-поінтів, які може використовувати BFF/фронтенд);
  - опційно — mapping подій (`product.runtime_events` → TJM runtime events).

---

## 3. Mapping ProductDef → TJM Structures

### 3.1 ProductDef.journey блок

У ProductDef (PD-001) блок `journey` мінімально містить:

```yaml
journey:
  journey_class_id: city.coffee.pass
  journey_doc_ref: TJM-JOURNEY-COFFEE-PASS@1.0.0
  entry_points:
    - app.home.hero
    - city.vienna.offers
  state_map:
    product_started:   journey.started
    product_completed: journey.completed
    product_cancelled: journey.cancelled
```

### 3.2 Мапінг на Registry та TJM

| ProductDef поле            | Registry сутність / поле               | TJM сутність                         |
|----------------------------|----------------------------------------|--------------------------------------|
| `journey.journey_class_id` | `product.journey_classes.code`         | `TJM.JourneyClass.id`                |
| `journey.journey_doc_ref`  | `product.journey_document_refs.ref`    | `TJM.JourneyDoc.id@version`         |
| `journey.entry_points[]`   | `product.journey_bindings.entry_points`| TJM entry-points / launch nodes      |
| `journey.state_map.*`      | `product.journey_bindings.state_map`   | mapping product events → TJM events  |

### 3.3 Reference resolution

Ingestion (`registerProductDef`) робить:

1. Перевіряє, що `journey_class_id` існує в `product.journey_classes` (кеш TJM-kind registry).
2. Перевіряє, що `journey_doc_ref` існує в `product.journey_document_refs` або може бути створений/оновлений через sync job з TJM.
3. Створює/оновлює `journey_bindings` для даної `product_version_id`.

У випадку помилок:

- відсутня JourneyClass → `REF_ERROR: JOURNEY_CLASS_NOT_FOUND`;
- відсутній JourneyDoc → `REF_ERROR: JOURNEY_DOC_NOT_FOUND` або soft-warning у non-prod.

---

## 4. Lifecycle: ProductVersion vs JourneyConfig

### 4.1 Логіка узгодження станів

- Registry має стани ProductVersion: `draft/review/active/deprecated/retired`.
- TJM має стани JourneyConfig (для конкретного продукту в конкретному env):
  - `inactive` — конфіг відомий, але не використовується;
  - `live` — конфіг застосовується для нових journeys;
  - `frozen` — конфіг застосовується тільки для існуючих journeys (ті, що вже стартували);
  - `archived` — конфіг більше не використовується.

Мінімальне правило:

| ProductVersion.status | JourneyConfig.state (рекомендація) |
|-----------------------|-------------------------------------|
| `draft`               | `inactive`                          |
| `review`              | `inactive`                          |
| `active`              | `live`                              |
| `deprecated`          | `frozen`                            |
| `retired`             | `archived`                          |

### 4.2 Події для синхронізації

- Registry емить:
  - `product.version.created` → TJM створює/оновлює JourneyConfig (inactive).
  - `product.version.status_changed` → TJM оновлює стан:
    - `review → active` → `inactive → live`;
    - `active → deprecated` → `live → frozen`;
    - `deprecated → retired` → `frozen → archived`.

TJM не змінює статус ProductVersion — лише свій JourneyConfig.

---

## 5. Runtime: Events & Micro-journeys

### 5.1 Product Runtime Events

PD-008 визначає канонічні події продуктового рантайму (`product.started`, `product.completed`, ...).

У контексті TJM інтеграції ми фіксуємо mapping:

```yaml
journey:
  state_map:
    product_started:   journey.started
    product_completed: journey.completed
    product_cancelled: journey.cancelled
    entitlement_claimed: journey.node.entitlement_claimed
```

- Ліва частина — product-level подія, що емиться з Trutta/TJM/BFF;
- Права частина — TJM runtime event/transition.

### 5.2 Micro-journeys

- Micro-journey — логічний підграф у TJM (напр. `pre_trip`, `in_city`, `post_trip`).
- ProductDef може опціонально вказувати, які micro-journeys активні:

```yaml
journey:
  micro_journeys:
    - pre_trip
    - in_city
```

- У Registry це зберігається в `journey_bindings.micro_journey_flags` (jsonb, array of enum).
- TJM читає ці флаги та або:
  - активує/деактивує відповідні підграфи;
  - або використовує як runtime-фільтри (feature flags).

---

## 6. TJM Read Patterns (як TJM користується Registry)

### 6.1 Bootstrap cache

Під час старту або періодично TJM:

1. Викликає `GET /v1/products/search?status=active&market_code=...`.
2. По кожному продукту викликає `GET /v1/products/{productId}/resolve?...` для контекстів, що його цікавлять.
3. Створює локальний кеш `ProductJourneyConfig`:

```json
{
  "product_version_id": "PRDV-...",
  "journey_class_id": "city.coffee.pass",
  "journey_doc_ref": "TJM-JOURNEY-COFFEE-PASS@1.0.0",
  "entry_points": ["app.home.hero", "city.vienna.offers"],
  "micro_journeys": ["pre_trip", "in_city"],
  "state_map": {
    "product_started": "journey.started",
    "product_completed": "journey.completed"
  }
}
```

### 6.2 Reaction to events

На події `product.version.status_changed` TJM:

1. Перевіряє, чи продукт належить підтримуваному JourneyClass.
2. Оновлює локальний кеш (pull `ProductVersion`/`JourneyBinding` із Registry).
3. Змінює state JourneyConfig відповідно до таблиці з розд. 4.1.

---

## 7. Error Handling & Fallbacks

### 7.1 Неконсистентність між Registry та TJM

Сценарії:

- ProductVersion посилається на `journey_doc_ref`, якого TJM ще не знає.
- JourneyDoc видалено/змінено у TJM без оновлення Registry.

Правила:

- У prod env Registry має повертати `REF_ERROR` на ingestion при неконсистентності (жорсткий режим).
- У dev/stage допускається soft-warning, але TJM повинен явно логувати такі кейси.

### 7.2 Неактуальні JourneyDocs

- Якщо TJM позначає певний JourneyDoc як deprecated/retired, TJM-kind registry реплікується в Registry.
- При наступному ingestion ProductDef з таким `journey_doc_ref` Registry відхиляє зміни (POLICY_ERROR: JOURNEY_DOC_RETIRED).

---

## 8. Versioning & Compatibility

### 8.1 Semver узгодження

- `ProductVersion.version` — семантика продукту.
- `JourneyDoc.version` — семантика journey-графа.

Рекомендації:

- MAJOR bump у JourneyDoc (1.x.x → 2.0.0) потребує або:
  - нової ProductVersion (MAJOR/MINOR),
  - або окремих binding’ів тільки для нових ринків.
- MINOR/PATCH зміни в JourneyDoc можуть бути допустимі для reuse без зміни ProductVersion, якщо governance це дозволяє.

### 8.2 Locking

ProductDef може явно зафіксувати діапазон версій JourneyDoc, з якими він сумісний:

```yaml
journey:
  journey_doc_ref: TJM-JOURNEY-COFFEE-PASS@1.0.0
  journey_doc_compat:
    min:  "1.0.0"
    max:  "1.x"
```

Registry не перевіряє повністю semver TJM-доків, але зберігає `journey_doc_compat` для tooling/analysis.

---

## 9. Security & Isolation

- TJM **ніколи** не має write-доступу в Registry; тільки:
  - читає API;
  - слухає події.
- Registry **не** виконує TJM-документи; він лише зберігає референси й binding’и.
- Access control:
  - окремі scopes/API-keys для TJM (`registry.tjm.read`);
  - можливе обмеження per-market/per-tenant в multi-tenant сценаріях.

---

## 10. Summary

- PD-004 фіксує контракт між ProductDef/Registry та TJM:
  - як заповнювати `journey` блок у ProductDef;
  - як це перетворюється на `journey_classes` / `journey_document_refs` / `journey_bindings` у Registry;
  - як ProductVersion lifecycle синхронізується з JourneyConfig state у TJM;
  - як runtime події продукту мапляться на TJM runtime events/micro-journeys.
- Registry залишається єдиним джерелом правди для того, **який journey** прив’язаний до продукту; TJM — єдиним джерелом правди **як саме** цей journey виконується.

