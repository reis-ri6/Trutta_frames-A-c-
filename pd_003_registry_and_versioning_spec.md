# PD-003 Registry and Versioning Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-001-product-dsl-core-templates.md  
- PD-001-product-dsl-core-links.md  
- PD-002-product-domain-model.md  
- PD-002-product-domain-model.ddl.sql  
- PD-002-product-domain-model-templates.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry.ddl.sql (next)  
- PD-003-registry-api.yaml (next)  
- PD-003-registry-and-versioning-templates.md (next)

Мета документа — формально описати **Product Registry**: його відповідальність, модель версіонування, lifecycle-протоколи, валідацію та інтеграцію з іншими сервісами.

> PD-002 описує, *що* зберігається в `product.*`. PD-003 — *як* ми цим керуємо в часі.

---

## 1. Purpose

- Зробити Registry єдиним джерелом правди для продуктів і їх версій.
- Забезпечити передбачуваний lifecycle продуктів: від draft до retired.
- Задати правила версіонування (`ProductVersion`, профілі, інтеграційні профілі, journey-доки).
- Визначити протоколи взаємодії Registry з CI/CD, TJM, Trutta, LEM, фронтендами, аналітикою.

---

## 2. Scope

### 2.1 Входить

- Семантика:
  - `Product` vs `ProductVersion` vs `ProductOverlay`;
  - статуси, стани, переходи;
  - політика semver для продуктів, профілів, інтеграцій.
- Поведінка Registry:
  - ingestion ProductDef (PDSL) → нормалізація в доменну модель;
  - управління статусами/оверлеями;
  - емісія подій.

### 2.2 Не входить

- Фізичний DDL Registry (див. PD-003-registry.ddl.sql).
- Повний REST/OpenAPI контракт (див. PD-003-registry-api.yaml).
- Детальні ролі/permission-матриця (див. PD-013-governance-and-compliance-spec.md).

---

## 3. Core Concepts

### 3.1 Product

- Стабільна продуктова лінійка (бренд/концепт).
- Ідентифікується `products.id` + унікальним `code`.
- Має незмінний `product_type`.

### 3.2 ProductVersion

- Конкретна конфігурація продукту в певний момент.
- Відповідає одному `ProductDef` (PDSL документу).
- Ідентифікується `product_versions.id` + `(product_id, version)`.
- Має `status` та `valid_from/valid_until`.

### 3.3 ProductOverlay

- Локальний/тенантний patch (`operator`, `market`, `city`, `vendor`).
- Накладається на `base_product_version_id`.
- Обмежений whitelist полів для зміни (назви, локалізація, валюта, локальні інтеграційні профілі тощо).

### 3.4 Registry

- Сервіс, що відповідає за:
  - зберігання ProductDef (+ DSL refs);
  - зберігання нормалізованої моделі (product.*);
  - lifecycle-операції над версіями/оверлеями;
  - історію та аудити;
  - паблік API/CLI для читання/пошуку.

> DIAGRAM_PLACEHOLDER #1: "C4 Container view for Product Registry"  
> Prompt: "Draw a C4 container diagram showing Product Registry as a service with: API/CLI ingress, DSL storage (S3/GCS), Postgres (product schema), message bus for events, and external systems (TJM, Trutta, LEM, Frontends, Analytics)."

---

## 4. Status & Lifecycle Model

### 4.1 Статуси ProductVersion

- `draft` — чорновик; не видимий зовнішнім системам.
- `review` — проходить рев’ю/автоматичні перевірки; доступний у test/stage середовищах.
- `active` — боєздатна версія для продакшену.
- `deprecated` — версія, що ще обслуговує існуючі об’єкти, але не використовується для нових продажів за замовчуванням.
- `retired` — закрито; не використовується ні для нових, ні для існуючих сценаріїв (винятки визначаються політиками Trutta/TJM).

### 4.2 Допустимі переходи

Базова state-machine:

- `draft → review`
- `review → draft` (якщо рев’ю не пройдено)
- `review → active`
- `active → deprecated`
- `deprecated → active` (обмежено, через governance)
- `deprecated → retired`

Заборонено:

- `retired → *` (тільки архів/читання).

Переходи ініціюються:

- CLI/API командою (людина або агент) + проходженням автоматичних перевірок (CI/bot).

> DIAGRAM_PLACEHOLDER #2: "ProductVersion lifecycle state machine"  
> Prompt: "Draw a state machine diagram showing statuses draft, review, active, deprecated, retired with allowed transitions as defined above."

### 4.3 Активна версія на продукт/ринок

Правило за замовчуванням:

- Для кожного `product_id` і кожного (market, operator, city)-контексту може бути **не більше однієї** ефективної `active` версії.
- Паралельні експерименти реалізуються на рівні Trutta/TJM (feature flags, routing), а не Registry.

---

## 5. Versioning Model (Semver)

### 5.1 Види версій

- `ProductVersion.version` — semver продукту.
- `ProfileVersion.version` — semver профілів.
- `JourneyDocumentRef.version` — semver TJM-доків.
- `IntegrationProfile` може мати власну версію в payload або через id.

### 5.2 Semver для ProductVersion

- `MAJOR` (X.y.z):
  - breaking зміни в journey-поведінці, інтеграціях або економіці, які не можуть бути оброблені старими клієнтами;
  - зміни, що вимагають затвердження governance-радою.
- `MINOR` (x.Y.z):
  - сумісні розширення (нові entry_points, додаткові markets/segments, м’які зміни профілів);
  - зміни, яких не бачать існуючі entitlements/юзерські контракти.
- `PATCH` (x.y.Z):
  - копірайт/локалізація;
  - фікси неузгодженостей, що не змінюють контракту;
  - дрібні корекції UI-профілю.

Registry не інтерпретує семантику semver, але **вимагає** його послідовного використання й фіксує тип змін у audit-логах (через metadata поля, визначені в PD-003-templates).

### 5.3 Зв’язок ProductVersion та ProfileVersion

- ProductVersion може використовувати кілька профілів (financial/token/ops/ui) з власними версіями.
- При оновленні профілю:
  - або створюється новий ProductVersion (жорсткий режим);
  - або оновлюється тільки binding (м’який режим), якщо governance-політики дозволяють.

Рекомендація:

- Для `financial`/`token` профілів — переважно створювати нову ProductVersion.
- Для `ui`/`ops` — допускається оновлення binding’ів без зміни версії продукту.

---

## 6. Ingestion & Validation

### 6.1 Ingestion pipeline

1. **Input**: ProductDef (`ProductDef` YAML/JSON) + metadata (target env, tenant).
2. **Schema validation**: проти PDSL-схеми (PD-001).
3. **Domain validation**: інваріанти PD-002 (типи, зв’язки, допустимі комбінації).
4. **Reference resolution**:
   - JourneyClass / JourneyDocumentRef;
   - ProfileVersion (financial/token/ops/ui...);
   - IntegrationProfile (Trutta/LEM/інші);
   - Taxonomy (Category/Tag/Market/Segment).
5. **Write**: транзакційний upsert у `product.*` + збереження сирого DSL (`dsl_document_ref`).
6. **Emit events**: `product.version.created` або `product.version.updated`.

Усі кроки повинні бути ідемпотентними за `(product_id, version)`.

### 6.2 Типи помилок

- `SCHEMA_ERROR` — невідповідність PDSL-схемі.
- `DOMAIN_ERROR` — порушення доменних інваріантів (PD-002).
- `REF_ERROR` — невирішені посилання (journey/profile/integration/taxonomy).
- `POLICY_ERROR` — невідповідність governance-політикам (мінімальні профілі, таксономія, markets).

Для `REF_ERROR` допускається режим soft-fail у non-prod середовищах (warning), але в prod — hard-fail.

---

## 7. Operations & APIs (логічно)

> Повний список endpoint’ів — в PD-003-registry-api.yaml. Тут фіксуються лише операційні класи.

### 7.1 Write APIs

- `registerProductDef` — створити/оновити ProductVersion з PDSL-документу.
- `setProductVersionStatus` — змінити статус (draft/review/active/deprecated/retired) з валідацією.
- `createOverlay` / `updateOverlay` — керування ProductOverlay.

### 7.2 Read APIs

- `getProductById / getProductByCode`.
- `getProductVersionById / (product_id, version)`.
- `getActiveProductVersion(product_id, context)` — з урахуванням overlays/markets.
- `searchProducts` — по category/tags/markets/segments/status.
- `resolveProductForContext` — повертає `{ base, overlay, resolved }` зріз для конкретного (tenant, market, city).

### 7.3 Events

Рекомендований набір подій на шину повідомлень:

- `product.version.created`
- `product.version.updated`
- `product.version.status_changed`
- `product.overlay.created`
- `product.overlay.updated`

Споживачі: TJM, Trutta, LEM, фронтенди, аналітика, governance-боти.

---

## 8. Overlays & Context Resolution

### 8.1 Контекст

Контекст для резолюції продукту:

- `tenant` / `operator_code`
- `market_code`
- `city_code`

### 8.2 Алгоритм резолюції

1. Знайти базову `active` ProductVersion для `product_id`.
2. Застосувати overlays у порядку пріоритету:
   - `operator` → `market` → `city` → `vendor`.
3. Для кожного overlay застосувати `patch_payload` поверх попереднього стану (whitelist полів задається в PD-001/PD-007/PD-009/PD-010).
4. Повернути `base`, список застосованих overlay’їв і `resolved` view.

### 8.3 Інваріанти overlay

- Overlay не може змінити `product_type`, базові JourneyBinding та обов’язкові Trutta/LEM binding’и.
- Overlay не може змінити `product_id`/`version`.
- Для одного `(base_product_version_id, overlay_kind, operator_code/market_code/city_code)` може існувати не більше одного активного overlay.

---

## 9. Environments & Promotion

### 9.1 Середовища

Мінімум три logical env:

- `dev` — вільні експерименти, слабкі політики.
- `stage` — повний набір валідаторів, підготовка до prod.
- `prod` — жорсткі політики, лише схвалені зміни.

Registry може бути:

- або один із env-атрибутом у записах;
- або окремі інстанси per env (рекомендація для продакшену).

### 9.2 Promotion

- Promotion визначається як копія/реплікація ProductDef + доменного стану з нижчого env у вищий.
- Слідкуємо за тим, щоб `product_id`/`version` зберігалися ідентичними між env (юридичний контракт).

---

## 10. Security & Audit (оглядово)

- Усі write-операції логуються з:
  - `actor_id` (людина або агент),
  - `change_type` (create/update/status_change/overlay),
  - `reason` / посилання на PR/ADR.
- Audit-зорієнтований log може зберігатися окремо від продуктивної БД.
- Детальна модель доступу (хто може які переходи/операції) — PD-013.

---

## 11. Summary

- Registry — це шар, який забезпечує:
  - канонічні ProductVersion/overlays;
  - строгий lifecycle і semver-правила;
  - предиктивний ingestion/validation;
  - подієвий обмін з TJM/Trutta/LEM.
- Всі зовнішні системи читають лише через Registry/API, не минаючи доменну модель.
- Для кожного продукту й контексту існує чітко визначена ефективна версія, яку Registry може віддати як `base + overlays → resolved`.

