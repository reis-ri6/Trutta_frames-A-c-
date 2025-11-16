# PD-002 Product Domain Model v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture  

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-001-product-dsl-core-templates.md  
- PD-001-product-dsl-core-links.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004/005/006 (TJM/Trutta/LEM інтеграції)

Мета документа — описати **логічну доменну модель** продуктової системи: які сутності існують, як вони пов’язані, які інваріанти забезпечують коректність екосистеми (TJM, Trutta, LEM, mpt.tours, агенти).

> PD-001 описує логічну структуру одного `ProductDef` (DSL‑документ). PD-002 описує **світ об’єктів**, усередині якого живуть всі ці `ProductDef`.

---

## 1. Purpose

- Визначити **ядро продуктової доменної моделі**: Product, ProductVersion, Profile, JourneyClass, IntegrationProfile, Overlay тощо.
- Забезпечити базу для:
  - SQL DDL (PD-002-product-domain-model.ddl.sql),
  - Registry‑специфікації (PD-003),
  - інтеграцій TJM/Trutta/LEM (PD-004/005/006).
- Зробити модель достатньо універсальною, щоб:
  - підтримувати багато доменів (туризм, F&B, wellness, medical);
  - бути сумісною з AI‑орієнтованими воркфлоу та швидкою еволюцією продуктів.

---

## 2. Scope

### 2.1 Що входить

- Логічні сутності:
  - **Product**, **ProductVersion**, **ProductOverlay**;
  - **JourneyClass**, **JourneyDocumentRef**, **JourneyBinding**;
  - **Profile**, **ProfileVersion**, **ProductProfileBinding**;
  - **IntegrationEndpoint**, **IntegrationProfile**, **ProductIntegrationBinding**;
  - **Taxonomy**: Category, Tag, Market, Segment;
  - допоміжні сутності для статусів, типів, lifecycle.
- Інваріанти та зв’язки між цими сутностями.

### 2.2 Що не входить

- Фізична схема БД (див. PD-002-product-domain-model.ddl.sql).
- Протоколи реєстру (API, CLI) — PD-003.
- Деталі доменів TJM/Trutta/LEM — їхні власні моделі.
- Аналітичні вітрини й event‑sourcing — окремі документи.

---

## 3. Domain Overview

Доменно модель розбиваємо на кілька піддоменів:

1. **Product Core** — концептуальні продукти, версії, оверлеї, статуси.
2. **Journeys & Runtime** — journey‑класи, TJM‑документи, binding продуктів.
3. **Profiles** — financial, token, loyalty, ops, safety, ui тощо.
4. **Integrations** — зв’язки з Trutta, LEM, зовнішніми системами.
5. **Taxonomy & Segmentation** — категорії, теги, ринки, сегменти.

> DIAGRAM_PLACEHOLDER #1: "Domain overview: subdomains and core entities"  
> Prompt: "Draw a high-level domain diagram with subdomains (Product Core, Journeys, Profiles, Integrations, Taxonomy) and core entities in each, indicating main relationships (e.g., ProductVersion → JourneyBinding, ProductVersion → ProductProfileBinding)."

---

## 4. Product Core Subdomain

### 4.1 Entity: Product

**Product** — концептуальна продуктова лінійка, що об’єднує всі версії та оверлеї.

Ключові атрибути:
- `id` — стабільний глобальний ідентифікатор (ULID/UUID).
- `code` — читабельний код (напр. `VG-VIEN-COFFEE-PASS`).
- `slug_base` — базова частина slug без прив’язки до версії.
- `product_type` — enum (`PASS`, `SINGLE_SERVICE`, `PACKAGE`, `ADDON`, ...).
- `created_at`, `created_by`.

Зв’язки:
- `Product 1 — N ProductVersion`.
- `Product 1 — N ProductOverlay`.

Інваріанти:
- `code` унікальний у рамках організації.
- `product_type` фіксований для Product (зміна потребує нового Product).

### 4.2 Entity: ProductVersion

**ProductVersion** — конкретна версія продукту, яка відповідає одному DSL‑документу (`ProductDef`).

Ключові атрибути:
- `id` — технічний id версії.
- `product_id` — FK → Product.
- `version` — semver (`1.0.0`, `1.1.0` тощо).
- `status` — enum (`draft`, `review`, `active`, `deprecated`, `retired`).
- `title` (min локалізація `en`).
- `category` — FK/enum (див. Taxonomy).
- `product_type` (копія з Product для денормалізації).
- `valid_from`, `valid_until`.
- `dsl_document_ref` — посилання на сирий DSL‑файл (YAML/JSON) в сховищі.

Зв’язки:
- `ProductVersion N — 1 Product`.
- `ProductVersion 1 — N ProductProfileBinding`.
- `ProductVersion 1 — N ProductIntegrationBinding`.
- `ProductVersion 1 — 1 JourneyBinding` (логічно, але може бути опційним для `draft`).

Інваріанти:
- `(product_id, version)` унікальна пара.
- Для `status = active` обов’язкові валідні JourneyBinding + мінімальний набір профілів.
- `product_type` версії збігається з `product_type` Product.

### 4.3 Entity: ProductOverlay

**ProductOverlay** — локальна варіація глобального продукту (operator / market / city / vendor).

Ключові атрибути:
- `id`.
- `base_product_version_id` — FK → ProductVersion (на яку версію накладається оверлей).
- `overlay_kind` — enum (`operator`, `market`, `city`, `vendor`).
- `operator_code` — напр. `MPT-TOURS`, `TRUTTA-VIEN` (для operator).
- `market_code` — напр. `AT`, `AT-VIE`.
- `city_code` — напр. `AT-VIE`.
- `patch_payload` — структурований JSON/YAML‑diff (обмежений whitelist полів).

Зв’язки:
- `ProductOverlay N — 1 ProductVersion`.

Інваріанти:
- Оверлей не може змінювати тип продукту (`product_type`) або ключові інтеграційні binding’и; дозволено лише локальні overrides (title, валюта, UI‑деталі, локальні інтеграційні профілі).
- На момент застосування оверлею базова ProductVersion повинна бути не `retired`.

---

## 5. Journeys & Runtime Subdomain

### 5.1 Entity: JourneyClass

**JourneyClass** — тип життєвого сценарію, що визначає allowed стани й події.

Ключові атрибути:
- `id` — напр. `city.coffee.pass`, `weekend.package`.
- `description`.
- `product_types_allowed[]` — список типів продуктів, які можуть використовувати цей клас.

Зв’язки:
- `JourneyClass 1 — N JourneyDocumentRef`.
- `JourneyClass 1 — N JourneyBinding`.

### 5.2 Entity: JourneyDocumentRef

**JourneyDocumentRef** — версія TJM‑документа для певного JourneyClass.

Ключові атрибути:
- `id` — технічний id.
- `journey_class_id` — FK → JourneyClass.
- `version` — semver.
- `document_ref` — напр. `TJM-JOURNEY-COFFEE-PASS@1.0.0`.
- `status` — `draft`, `active`, `deprecated`.

Інваріанти:
- Для кожного `journey_class_id` може бути кілька активних версій, але ProductVersion має посилатися на **одну** конкретну.

### 5.3 Entity: JourneyBinding

**JourneyBinding** — зв’язок між ProductVersion і конкретним JourneyDocumentRef.

Ключові атрибути:
- `id`.
- `product_version_id` — FK → ProductVersion.
- `journey_document_ref_id` — FK → JourneyDocumentRef.
- `entry_points[]` — набір ключів (app scopes), де доступний старт продукту.
- `state_map` — JSON‑карта логічних станів продукту (`created`, `issued`, `redeemed` …) на стани TJM‑машини.

Інваріанти:
- `product_type` ProductVersion ∈ `product_types_allowed[]` JourneyClass.
- Для `status = active` у ProductVersion повинен існувати рівно один валідний JourneyBinding.

---

## 6. Profiles Subdomain

### 6.1 Entity: Profile

**Profile** — абстрактний профіль (financial, token, loyalty, ops, safety, ui, etc.).

Ключові атрибути:
- `id`.
- `profile_type` — enum (`financial`, `token`, `loyalty`, `ops`, `safety`, `quality`, `ui`, ...).
- `scope` — `global`, `operator`, `market`, `city`, `vendor` (аналог оверлеїв).
- `owner_org` — хто створив/володіє профілем.

Зв’язки:
- `Profile 1 — N ProfileVersion`.

### 6.2 Entity: ProfileVersion

**ProfileVersion** — конкретна версія профілю.

Ключові атрибути:
- `id`.
- `profile_id` — FK → Profile.
- `version` — semver.
- `status` — `draft`, `active`, `deprecated`, `retired`.
- `payload` — JSON схеми конкретного типу профілю (див. PD-007/PD-009/PD-010).

Інваріанти:
- Payload валідований проти відповідної схеми профілю.

### 6.3 Entity: ProductProfileBinding

**ProductProfileBinding** — прив’язка профілю до ProductVersion.

Ключові атрибути:
- `id`.
- `product_version_id` — FK → ProductVersion.
- `profile_version_id` — FK → ProfileVersion.
- `role` — логічна роль профілю для продукту (напр. `primary`, `fallback`, `campaign_override`).

Інваріанти:
- Для кожної комбінації (`product_version_id`, `profile_type`) має бути не більше одного `primary` профілю.
- Набір required profile_type залежить від `product_type` (матриця в PD-007/PD-009/PD-010).

---

## 7. Integrations Subdomain

### 7.1 Entity: IntegrationEndpoint

**IntegrationEndpoint** — абстракція інтеграції із зовнішньою/внутрішньою системою.

Ключові атрибути:
- `id`.
- `kind` — enum (`trutta`, `lem`, `reservation_system`, `host_system`, `billing`, ...).
- `external_system_id` — технічний ідентифікатор системи (напр. `TRUTTA-CORE`, `LEM-HQ`, `STR-BOOKING`).
- `config_ref` — посилання на конфігурацію/секрети (не зберігаються в продуктовій БД).

### 7.2 Entity: IntegrationProfile

**IntegrationProfile** — логічний профіль інтеграції, який може бути застосований до кількох продуктів.

Ключові атрибути:
- `id`.
- `integration_endpoint_id` — FK → IntegrationEndpoint.
- `name` — логічна назва.
- `payload` — JSON (mapping кодів, правила, routing).

### 7.3 Entity: ProductIntegrationBinding

**ProductIntegrationBinding** — зв’язок ProductVersion з IntegrationProfile.

Ключові атрибути:
- `id`.
- `product_version_id` — FK → ProductVersion.
- `integration_profile_id` — FK → IntegrationProfile.
- `purpose` — напр. `entitlement`, `settlement`, `city_graph`, `reservation`, `host_mapping`.

Інваріанти:
- Для Trutta/LEM контракти жорсткі: певні `purpose` вимагають наявності binding’ів (див. PD-001-links + PD-005/PD-006).

---

## 8. Taxonomy & Segmentation Subdomain

### 8.1 Entity: Category

**Category** — дерево категорій продуктів.

Ключові атрибути:
- `id`.
- `code` — унікальний код (напр. `food-and-beverage`, `city-pass`).
- `parent_id` — FK → Category (опційно).
- `title` (локалізований).

Інваріанти:
- Дерево без циклів.

### 8.2 Entity: Tag

**Tag** — вільна або напівкерована таксономія тегів.

Ключові атрибути:
- `id`.
- `code` — унікальний технічний код (напр. `vienna`, `coffee`, `kidney-friendly`).
- `title`.

Зв’язки:
- `ProductVersion N — M Tag`.

### 8.3 Entity: Market

**Market** — формалізований ринок (країна/регіон/місто).

Ключові атрибути:
- `id`.
- `code` — напр. `AT`, `AT-VIE`.
- `geo_scope` — `country`, `region`, `city` тощо.

Зв’язки:
- `ProductVersion N — M Market` (множинна доступність).

### 8.4 Entity: Segment

**Segment** — опис таргетованих аудиторій.

Ключові атрибути:
- `id`.
- `code` — напр. `traveler`, `family`, `kidney`.
- `description`.

Зв’язки:
- `ProductVersion N — M Segment`.

---

## 9. Relationships Overview

Стислий опис ключових зв’язків:

- `Product` ←1—N→ `ProductVersion`.
- `ProductVersion` ←1—N→ `ProductOverlay`.
- `ProductVersion` ←1—1→ `JourneyBinding` →1—1→ `JourneyDocumentRef` →N—1→ `JourneyClass`.
- `ProductVersion` ←1—N→ `ProductProfileBinding` →N—1→ `ProfileVersion` →N—1→ `Profile`.
- `ProductVersion` ←1—N→ `ProductIntegrationBinding` →N—1→ `IntegrationProfile` →N—1→ `IntegrationEndpoint`.
- `ProductVersion` ←M—N→ `Tag` / `Market` / `Segment` / `Category` (через відповідні зв’язувальні таблиці).

> DIAGRAM_PLACEHOLDER #2: "Logical ER diagram for Product domain"  
> Prompt: "Draw a logical ER diagram with tables: Product, ProductVersion, ProductOverlay, JourneyClass, JourneyDocumentRef, JourneyBinding, Profile, ProfileVersion, ProductProfileBinding, IntegrationEndpoint, IntegrationProfile, ProductIntegrationBinding, Category, Tag, Market, Segment. Show cardinalities and main foreign keys."

---

## 10. Invariants & Business Rules (Summary)

1. **Product vs ProductVersion**
   - `Product.product_type` незмінний; версія не може змінити тип.
   - Для кожного Product може існувати нуль або одна `active` версія одночасно в рамках конкретного ринку/оверлею (деталі — PD-003).

2. **JourneyBinding**
   - Для `active` ProductVersion має існувати рівно один валідний JourneyBinding.
   - JourneyClass повинен дозволяти `product_type` продукту.

3. **Profiles**
   - Для кожного `product_type` визначений список required `profile_type`.
   - Для кожної пари (`product_version_id`, `profile_type`) не більше одного primary профілю.

4. **Integrations**
   - Для продуктів, що продаються через Trutta, обов’язкові binding’и до відповідних Trutta‑профілів.
   - Для продуктів, які інтегруються в міський граф, обов’язковий LEM‑binding.

5. **Overlays**
   - Overlay не може змінювати критичний контракт (journey, product_type, базові інтеграції); лише уточнення.

6. **Taxonomy**
   - Кожна ProductVersion повинна мати хоча б одну Category.
   - Tag/Market/Segment можуть бути порожніми на ранніх стадіях, але для `active` версій мінімальні вимоги задаються governance‑політиками (PD-013).

---

## 11. Mapping to ProductDef (PD-001)

Взаємозв’язок між DSL‑структурою `ProductDef` та доменною моделлю:

- `Product` ≈ стабільні частини `identity` (`product_id`, `product_code`, `slug` без версії) + `classification.product_type`.
- `ProductVersion` ≈ один цілий `ProductDef` з `meta`, `identity`, `classification`, `lifecycle`, `journey`, `profiles`, `integrations`.
- `JourneyBinding` ≈ `journey.*` секція ProductDef, після нормалізації на JourneyClass/JourneyDocumentRef.
- `ProductProfileBinding` ≈ `profiles.*` секція ProductDef (кожен ключ → binding до конкретного ProfileVersion).
- `ProductIntegrationBinding` ≈ `integrations.*` секція ProductDef (кожен блок → binding до IntegrationProfile).
- Taxonomy (Category/Tag/Market/Segment) ≈ `classification.*`.

Принцип:

> DSL (`ProductDef`) — це **декларативний документ**, доменна модель — **нормалізований операційний зріз**. Між ними завжди існує детермінований мапінг, що виконується Registry/ingestion‑шаром.

---

## 12. Extension Points

- Нові `product_type` — додаються через зміну enum та оновлення матриці вимог до профілів/інтеграцій.
- Нові `profile_type` — додаються через розширення Profile‑субдомена та відповідних схем.
- Нові види інтеграцій — через нові `kind` для IntegrationEndpoint та окремі IntegrationProfile‑схеми.
- Нові виміри таксономії (напр. `Theme`, `Season`) — додаються як окремі сутності, що зв’язуються з ProductVersion.

Ця доменна модель є канонічною основою для подальшого проектування фізичної схеми (PD-002-product-domain-model.ddl.sql) та реєстрової логіки (PD-003).

