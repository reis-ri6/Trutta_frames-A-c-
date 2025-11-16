# PD-002 Product Domain Model Links v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-001-product-dsl-core-links.md  
- PD-002-product-domain-model.md  
- PD-002-product-domain-model.ddl.sql  
- PD-002-product-domain-model-templates.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md

Мета документа — зафіксувати, **як логічна продуктова доменна модель зв’язується з іншими шарами системи**: Product DSL (PDSL), Registry, TJM, Trutta, LEM, аналітика, governance.

> PD-001 відповідає за контракт `ProductDef` (DSL). PD-002 — за нормалізовану модель у базі/Registry. Цей документ описує клей між ними.

---

## 1. ProductDef ⇄ Domain Model ⇄ Registry

### 1.1 Слої

- **DSL (`ProductDef`)** — YAML/JSON документ (PD-001), що описує один продукт.
- **Domain Model (PD-002)** — нормалізовані сутності в БД/Registry.
- **Registry API/CLI (PD-003)** — інтерфейс для запису/читання.

### 1.2 Основний мапінг

| ProductDef блок         | Domain Model сутність / поле                      |
|-------------------------|---------------------------------------------------|
| `identity.product_id`   | `product.products.id`                             |
| `identity.product_code` | `product.products.code`                           |
| `identity.slug`         | `product.products.slug_base` (без версії)        |
| `identity.version`      | `product.product_versions.version`                |
| `meta.*`                | `product.product_versions.*` + технічні поля      |
| `classification.*`      | `product.product_versions` + N:M до taxonomy      |
| `lifecycle.*`           | `product.product_versions.status/valid_*`         |
| `journey.*`             | `product.journey_bindings` + `journey_document_refs` |
| `profiles.*`            | `product.product_profile_bindings` + `profile_versions` |
| `integrations.*`        | `product.product_integration_bindings` + `integration_profiles` |

### 1.3 Flow ingestion’у ProductDef

1. CLI/API відправляє `ProductDef` → Registry ingestion service.
2. Ingestion:
   - валідатор схеми (PD-001);
   - семантичний валідатор (інваріанти PD-002);
   - резолвер референсів (JourneyClass/Profiles/Integrations/Taxonomy).
3. Після успіху ingestion створює/оновлює:
   - `products` (якщо новий product_id);
   - `product_versions` (нова версія);
   - зв’язки в `product_version_*`, `journey_bindings`, `product_profile_bindings`, `product_integration_bindings`.
4. `dsl_document_ref` вказує на сирий артефакт у сховищі (S3/GCS).

> DIAGRAM_PLACEHOLDER #1: "Ingestion pipeline ProductDef → Domain Model"  
> Prompt: "Draw a flow diagram: ProductDef submitted via CLI → schema validation → domain validation → reference resolution → DB upsert into Product, ProductVersion, bindings tables → emit product.version.updated event."

---

## 2. Domain Model ⇄ TJM (Journeys)

### 2.1 Хто owner чого

- **TJM** — owner семантики JourneyClass та їхніх TJM-доків.
- **Product/Registry** — owner того, **який продукт до якого JourneyClass/доку прив’язаний**.

### 2.2 Конкретні зв’язки

- `product.journey_classes` — реєстр доступних journey-класів (копія/кеш TJM-kind registry).  
- `product.journey_document_refs` — мапа версій TJM-доків.
- `product.journey_bindings` — зв’язок `ProductVersion` → `JourneyDocumentRef`.

Інваріанти:

- `journey_bindings.product_version_id` ↔ `product.product_versions.id`.
- `journey_bindings.journey_document_ref_id` ↔ `product.journey_document_refs.id`.
- `journey_document_refs.journey_class_id` ↔ `product.journey_classes.id`.
- `product.product_versions.product_type` ∈ `journey_class_product_types.product_type` для зв’язаного JourneyClass.

### 2.3 Runtime використання

- TJM читає доменну модель через Registry API:
  - запит: «дай всі active продукти для ринку X з JourneyClass = Y»;
  - join: `product_versions` + `product_version_markets` + `journey_bindings` + `journey_document_refs`.
- Після цього TJM кешує runtime-конфіг.

> DIAGRAM_PLACEHOLDER #2: "Query TJM for active products by journey class"  
> Prompt: "Draw a query-level diagram showing TJM calling Registry to fetch active ProductVersions bound to a given JourneyClass in a given Market, using journey_bindings and product_version_markets."

---

## 3. Domain Model ⇄ Trutta (Tokens & Entitlements)

### 3.1 Зони відповідальності

- **Trutta** — owner токенів, entitlementів, протоколів мінтингу/свопів.
- **Product/Registry** — описує, які продукти продаються через Trutta і з якими інтеграційними профілями.

### 3.2 Конкретні зв’язки

- `product.integration_endpoints.kind = 'trutta'` — логічні Trutta endpoints.
- `product.integration_profiles` (endpoint=trutta) — інтеграційні профілі (entitlement, settlement, fraud-config).
- `product.product_integration_bindings.purpose = 'entitlement' | 'settlement'` — прив’язка ProductVersion до Trutta-профілю.
- `product.product_profile_bindings.profile_type = 'token' | 'financial'` — профілі, які Trutta може читати/інтерпретувати.

Мапінг з PDSL:

- `integrations.trutta.entitlement_profile_id` → `product.integration_profiles.id` (purpose = 'entitlement').
- `profiles.token_profile.*` → `profiles/profile_versions` (profile_type='token').

### 3.3 Потік даних

- Registry на подію `product.version.activated` емить message для Trutta:

```json
{
  "event": "product.version.activated",
  "product_version_id": "PRDV-...",
  "product_id": "PRD-...",
  "integration_bindings": [
    { "purpose": "entitlement", "integration_profile_id": "TRT-ENT-..." }
  ],
  "profile_bindings": [
    { "profile_type": "token", "profile_version_id": "TP-..." },
    { "profile_type": "financial", "profile_version_id": "FP-..." }
  ]
}
```

- Trutta будує внутрішні конфіги на основі цих binding’ів та власних схем (DOC-02x у Trutta).

---

## 4. Domain Model ⇄ LEM (City Graph)

### 4.1 Зв’язки

- `product.integration_endpoints.kind = 'lem'` — LEM endpoints.
- `product.integration_profiles` (endpoint=lem) — city-graph профілі.
- `product.product_integration_bindings.purpose = 'city_graph'` — прив’язка продукту до LEM-профілю.
- `product.product_version_markets` ↔ `product.markets` — території, в яких продукт доступний.

Мапінг з PDSL:

- `integrations.lem.city_graph_profile_id` → `product.integration_profiles.id` (purpose='city_graph').
- `classification.markets[]` → `product.markets.code` через `product_version_markets`.

### 4.2 Використання з боку LEM

- LEM отримує snapshot продуктів:
  - join: `product_versions` + `product_version_markets` + `product_integration_bindings (city_graph)` + `integration_profiles`.
- На основі `payload` в `integration_profiles` LEM створює/оновлює:
  - `service_point_class`/кластер;
  - дефолтні маршрути/edges.

---

## 5. Domain Model ⇄ Analytics / Data Layer

### 5.1 Ідентифікатори в fact-таблицях

- Всі транзакційні й подієві таблиці (не частина PD-002) використовують:
  - `product_id` (стабільний);
  - `product_version_id` (для точного стану конфігу);
  - інколи `integration_profile_id` (entitlement/settlement профілі).

Рекомендація:

- Збирати аналітичні вітрини, які join’ять факти з:
  - `product.product_versions` (назва, категорія, ринок, тип);
  - `product_version_*` (tags/markets/segments);
  - профільними таблицями (financial/token/ops) через binding’и.

> DIAGRAM_PLACEHOLDER #3: "Star schema around ProductVersion"  
> Prompt: "Draw a star schema where ProductVersion is a dimension table joined with fact tables (transactions, entitlements, journeys), and taxonomy (Category, Market, Segment) as additional dimensions."

### 5.2 Еволюція

- При зміні профілів/інтеграцій потреби аналітики не змінюються: `product_version_id` завжди залишається ключем для прив’язки до конкретної конфігурації.

---

## 6. Domain Model ⇄ Governance / CI / Multi-tenant

### 6.1 Governance

- Governance-політики (PD-013) оперують доменною моделлю:
  - мінімальні вимоги до профілів/інтеграцій для переходу у `status = active`;
  - обмеження на overlay (що можна патчити, що ні);
  - перевірки таксономії (обов’язкові категорії, мін. кількість ринків/сегментів).

- CI-пайплайни (PD-012) працюють на рівні DSL, але валідацію завершують на рівні доменної моделі (мок-інжекція/транзакційний ingest у тестову БД).

### 6.2 Multi-tenant / overlays

- **Global Product** — `products` + базова `product_versions`.
- **Operator/market/city overlays** — `product_overlays` + overlay-specific профілі/інтеграційні профілі.

Принцип:

- overlay **не створює новий ProductVersion**, а накладається на існуючу версію;
- у runtime Registry може видавати "resolved" view:

```json
{
  "product_version_id": "PRDV-...",
  "base": { ... },
  "overlay": { ... },
  "resolved": { ... }   
}
```

де `resolved` = `base` + застосовані patch’і з `product_overlays`.

---

## 7. Summary

- PD-002 доменна модель — це нормалізований кістяк, на який насаджується DSL (`ProductDef`), TJM/Trutta/LEM, аналітика та governance.
- ProductDef завжди проходить ingestion → нормалізується в сутності `product.*` → стає єдиним джерелом правди для всіх сервісів.
- Всі інтеграції (journey, tokens, city graph, зовнішні системи) реалізовані через binding-таблиці до відповідних профілів/endpoint’ів.
- Multi-tenant і локальні варіації працюють через overlays та scoped-профілі, без дублювання базових ProductVersion.

