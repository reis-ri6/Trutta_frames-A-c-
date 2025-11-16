# PD-004 TJM Integration Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Journey Runtime Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-004-tjm-integration-spec.md  
- PD-004-tjm-integration-templates.md  
- PD-008-product-runtime-and-agents-spec.md

**External (TJM):**  
- TJM-SPEC-core.md — модель JourneyClass / JourneyDoc / micro-journey.  
- TJM-COMPILER.md — сервіс компіляції journey-доків.  
- TJM-RUNTIME.md — рантайм, state machine, інстанси journeys.  
- TJM-AGENTS.md — агентний шар поверх TJM (orchestrator, planners, copilots).

Мета документа — описати **зв’язки між Product DSL / Registry та TJM-шаром**:

- як JourneyClass/JourneyDoc рухаються через TJM-COMPILER до Registry;
- як Registry та TJM-RUNTIME синхронізують конфіг;
- як агентний шар використовує обидва — Registry і TJM.

---

## 1. Компоненти та їх ролі

### 1.1 Product Registry

- Зберігає Product/Version/Overlay + JourneyBinding (див. PD-002/003/004-spec).
- Є єдиним джерелом правди: **який продукт на який JourneyClass/JourneyDoc зав’язаний**.

### 1.2 TJM-SPEC / kind-registry

- Описує типи journeys (`JourneyClass`), їх allowed markets/segments, runtime-контракт.
- Використовується TJM-COMPILER’ом і кешується в Registry (`product.journey_classes`).

### 1.3 TJM-COMPILER

- Приймає TJM-доки (YAML/JSON) → валідований `JourneyDoc` + артефакти:
  - нормалізований граф станів;
  - runtime-політики;
  - семантичні індекси.
- Публікує їх у TJM-kind registry та, опціонально, синхронізує референси в Registry.

### 1.4 TJM-RUNTIME

- Виконує journeys (інстанси), працює з event stream.
- Потребує **ProductJourneyConfig** (див. PD-004-templates) для кожного продукту.

### 1.5 Agent Layer (TJM-AGENTS)

- Orchestrator, planning/assistant-агенти:
  - читають продукт/journey-конфіг з Registry + TJM;
  - тригерять/супроводжують journeys згідно ролей (travel copilot, city guide, ops-agent тощо).

---

## 2. Потік: Journey-дизайн → TJM-COMPILER → Registry

### 2.1 Authoring TJM-доку

- TJM-команда або продуктова команда створює `JourneyDoc`:
  - репозиторій `tjm/journeys` (YAML);
  - CI-валидація проти TJM-SPEC; юніт/інтеграційні тести.

### 2.2 Компіляція

- CI викликає TJM-COMPILER API:
  - `POST /compiler/journeys` з сирим YAML;
  - отримує валідований `JourneyDoc` (canonical JSON) + метаданні.
- TJM-COMPILER:
  - записує `JourneyDoc` в TJM-kind registry;
  - створює/оновлює `journey_classes` record (якщо потрібно).

### 2.3 Синхронізація з Registry

- Periodic sync job (або webhook) з TJM → Registry:
  - `journey_classes` → `product.journey_classes` (ід, версія, allowed_product_types/markets);
  - `journey_docs` → `product.journey_document_refs` (ід+версія, статус, compat-range).
- ProductDef ingestion (PD-003) використовує це як reference-таблиці.

> DIAGRAM_PLACEHOLDER #1: "TJM authoring & compiler → Registry"  
> Prompt: "Draw flow: Git (JourneyDoc) → TJM-COMPILER → TJM kind-registry → sync job → Product Registry (journey_classes, journey_document_refs)."

---

## 3. Потік: ProductDef → Registry → TJM-RUNTIME

### 3.1 Ingestion ProductDef

При `registerProductDef`:

1. Registry читає `ProductDef.journey` блок.
2. Валідує `journey_class_id` та `journey_doc_ref` проти кешу TJM (journey_classes/journey_document_refs).
3. Створює/оновлює `JourneyBinding` (`product.journey_bindings`).
4. Емить `product.version.created` (і пізніше `product.version.status_changed`).

### 3.2 Споживання TJM-RUNTIME

TJM-RUNTIME:

- на `product.version.created` / `status_changed`:
  - тягне `ProductJourneyConfig` через Registry API (`resolveProductForContext` + binding);
  - оновлює внутрішній `JourneyConfig` (inactive/live/frozen/archived).
- на старті сервісу:
  - робить bootstrap через `searchProducts + resolve` для потрібних markets.

### 3.3 Інваріанти

- Не може існувати live JourneyConfig без валідного ProductVersion/binding у Registry.
- У prod env ProductVersion `active` **має** мати валідний `JourneyBinding`, інакше ingestion відхиляється (`REF_ERROR` / `POLICY_ERROR`).

---

## 4. Потік: Agents ⇄ TJM ⇄ Registry

### 4.1 Orchestrator Agent

- Orchestrator (див. PD-008) має два основні шари читання:
  - **каталог продуктів і профілів** — Registry;
  - **journey state / transitions** — TJM-RUNTIME.

Типовий сценарій:

1. Агент отримує задачу: "створити journey для Vienna Coffee Day Pass".
2. Через Registry знаходить `product_version_id` + `ProductJourneyConfig`.
3. Через TJM API створює `journey_instance` з відповідним `journey_class_id` і `journey_doc_ref`.
4. Веде користувача, емлячи product runtime events, які мапляться на TJM events.

### 4.2 Planning-агенти

- Використовують Registry для:
  - пошуку релевантних продуктів по фільтрах (місто, сегмент, тип);
  - читання journey entry_points/micro_journeys.
- Використовують TJM для:
  - симуляції можливих journeys ("what-if" planning);
  - отримання маршруту/послідовності кроків для конкретного продукту.

### 4.3 Ops/Support-агенти

- Через Registry: бачать, яка саме ProductVersion/JourneyBinding зараз live для користувача.
- Через TJM: бачать поточний journey state, останні події, можливі переходи/розв’язки.

---

## 5. Посилання на TJM-SPEC/COMP (контрактні точки)

### 5.1 Contract рівня JourneyClass

ProductDef/Registry **не можуть** створювати/редагувати JourneyClass. Вони лише:

- посилаються на `journey_class_id`;
- кешують обмеження (allowed_product_types/markets, required_events);
- використовують їх у валідації ProductDef.

Всі зміни у JourneyClass проходять через TJM-SPEC + TJM-COMPILER.

### 5.2 Contract рівня JourneyDoc

- Registry тримає тільки референс `journey_doc_ref` + можливий compat-range.
- Реальний зміст/граф — у TJM-доміні.
- TJM-COMPILER відповідає за:
  - повну валідацію графа;
  - backwards-compatible оновлення;
  - маркування `deprecated/retired`.

Registry валідує, що ProductDef не посилається на `retired` JourneyDoc (через sync-метадані).

---

## 6. Event Links: від Registry до TJM і назад

### 6.1 Event-потік Registry → TJM

Основні типи подій, які TJM споживає:

- `product.version.created`
- `product.version.status_changed`
- `product.overlay.created/updated`

Використання:

- оновлення кешів ProductJourneyConfig;
- оновлення доступності journeys для ринків/міст;
- переключення state JourneyConfig (live/frozen/archived).

### 6.2 Event-потік TJM → інші шари

TJM емить:

- `journey.started / completed / cancelled`;
- `journey.node.*` (entitlement_claimed, vendor_issue, safety_alert, …).

Ці події:

- підхоплюються аналітикою як факти `fact_journey`;
- можуть бути трансльовані у product runtime events (через state_map) для Trutta/ops.

---

## 7. Observability, Debuggability

### 7.1 Trace ланцюжки

Ключові ідентифікатори для наскрізного трейсингу:

- `product_id`, `product_version_id` (Registry);
- `journey_class_id`, `journey_doc_ref`, `journey_instance_id` (TJM);
- `user_id`, `entitlement_id`, `city_code`, `market_code`.

Логи/події Registry і TJM мають включати спільний `correlation` блок (див. PD-004-templates).

### 7.2 Debug сценарій

При інциденті:

1. По `journey_instance_id` знайти в TJM події/стани.
2. По `product_version_id` в Registry — ProductDef, JourneyBinding, статуси.
3. Відновити повний шлях: ProductDef → Registry events → TJM config → runtime events.

> DIAGRAM_PLACEHOLDER #2: "End-to-end trace"  
> Prompt: "Show correlation of identifiers: product_version_id ↔ journey_doc_ref ↔ journey_instance_id ↔ entitlement_id across Registry, TJM, Trutta, Analytics."

---

## 8. Summary

- TJM-SPEC/COMP визначають **що таке journey і як він компілюється**.
- Registry визначає **який journey прив’язаний до якого продукту, в яких ринках і станах**.
- TJM-RUNTIME виконує journeys, опираючись на ProductJourneyConfig та події з Registry/Trutta/BFF.
- Агентний шар використовує обидві системи: Registry — як каталог/контекст, TJM — як engine для фактичної оркестрації шляхів користувачів.

Ці зв’язки мають залишатися стабільними попри еволюцію окремих компонентів (нові JourneyClass, оновлення TJM-COMPILER, поява нових агентів), доки не буде MAJOR-зміни контрактів у PD-004 або TJM-SPEC.

