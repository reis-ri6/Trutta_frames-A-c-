# PD-001 Product DSL Core Links v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture  

**Related docs:**  
- PD-001-product-dsl-core-spec.md — структурна та інваріантна модель ProductDef.  
- PD-001-product-dsl-core-templates.md — шаблони ProductDef для різних типів продуктів.  
- PD-002/003/004/005/006 — доменна модель, реєстр, інтеграції з TJM/Trutta/LEM.

Мета документа — зафіксувати, **хто** і **як** споживає ProductDef, які поля є контрактними для кожної системи, та які гарантії дає Product DSL як ядро.

---

## 1. System Map

Product DSL / Registry є центральним джерелом правди про продукти. Основні споживачі:

1. **TJM (Travel Journey Model)** — компіляція та виконання journey‑логіки.
2. **Trutta** — токени, entitlements, claim/settlement‑флоу.
3. **LEM (City Graph)** — сервісні точки, маршрути, experience‑класи.
4. **mpt.tours / фронтенди** — UI, каталоги, фільтри, пошук.
5. **AI‑агенти** — рекомендації, конфігурація, моніторинг.
6. **Аналітика / Observability** — вітрини даних, unit‑economics, quality/ops.
7. **Registry infra / CI/CD** — валідація, публікація, rollout.

> DIAGRAM_PLACEHOLDER #1: "System context diagram Product DSL core"
> Prompt: "Draw a C4 Level 1 system context diagram where Product DSL / Registry is the central system, and TJM, Trutta, LEM, mpt.tours frontend apps, AI agents, Analytics and CI/CD pipelines are external systems/actors. Show main read/write relationships."

---

## 2. Responsibility & Contract Matrix

### 2.1 High-level responsibilities

- **Product DSL / Registry**
  - Веде канонічний `ProductDef` та його версії.
  - Гарантує відповідність ProductDef схемі (PD-001) та доменним інваріантам (PD-002).
  - Забезпечує стабільні референси для інтеграцій (TJM/Trutta/LEM/інші).

- **Споживачі**
  - Читають ProductDef як read‑only контракт.
  - Не змінюють ProductDef напряму; будь‑які зміни — через git+Registry workflow (PD-011/PD-012).

### 2.2 Contract matrix (спрощений)

| Consumer        | Role                           | Critical ProductDef paths                                          | Contract type |
|-----------------|--------------------------------|--------------------------------------------------------------------|---------------|
| TJM             | Journey compilation & runtime  | `journey.*`, `classification.product_type`, `lifecycle.status`     | hard          |
| Trutta          | Tokens & entitlements          | `integrations.trutta.*`, `classification.product_type`, `profiles.token_profile` | hard |
| LEM             | City graph linkage             | `integrations.lem.*`, `classification.markets`, `segments`         | hard          |
| mpt.tours UIs   | Catalog & rendering            | `identity.*`, `classification.*`, `profiles.ui_profile`             | soft+hard     |
| AI agents       | Reasoning & orchestration      | `identity.*`, `classification.*`, `journey.*`, `profiles.*`         | soft          |
| Analytics       | Metrics & UE                   | `identity.*`, `classification.*`, `profiles.financial_profile`      | soft+hard     |

- **Hard contract** — breaking change потребує major‑версію ProductDef/спеки.
- **Soft contract** — допускається еволюція через optional поля, backward‑compatible.

---

## 3. Link to TJM (Travel Journey Model)

### 3.1 Основні поля ProductDef → TJM

TJM покладається на такі поля ProductDef:

- `journey.journey_class` — ідентифікатор класу journey (напр. `city.coffee.pass`).
- `journey.tjm_document_ref` — версія TJM‑документа, який описує state‑machine.
- `journey.entry_points[]` — дозволені точки старту в клієнтських застосунках.
- `journey.states{}` — логічний каркас станів продукту.
- `classification.product_type` — визначає дозволені journey‑класи.
- `lifecycle.status` + `lifecycle.valid_from/valid_until` — доступність продукту в runtime.

**Інваріанти для TJM:**

1. Продукт не може бути `active`, якщо `journey.journey_class` або `journey.tjm_document_ref` не задано.
2. `journey.journey_class` повинен бути реєстрованим у TJM `kind_registry` (див. PD-004).
3. `journey.tjm_document_ref` повинен існувати та бути валідним для вказаного `journey_class`.

### 3.2 Flow: підготовка до виконання

1. Registry публікує ProductDef з `status = active`.
2. TJM periodic‑poll/подія `product.updated` завантажує нові/змінені ProductDef.
3. TJM валідатор перевіряє узгодженість `journey.*` з TJM‑schema.
4. На основі ProductDef TJM формує internal runtime config (кешований snapshot).

> DIAGRAM_PLACEHOLDER #2: "Sequence: ProductDef activation → TJM runtime update"  
> Prompt: "Draw a sequence diagram: Developer commits ProductDef → Registry validates & activates → TJM pulls updated ProductDef → TJM validates journey_class/tjm_document_ref → TJM updates runtime config."

### 3.3 Failure modes

- Якщо `journey_class` невідомий → ProductDef не буде прийнятий TJM; Registry може позначити `status = review_failed` (механіка в PD-003).
- Якщо `tjm_document_ref` не сумісний → TJM відхиляє оновлення й продовжує використовувати останній валідний snapshot.

---

## 4. Link to Trutta (Entitlements & Tokens)

### 4.1 Основні поля ProductDef → Trutta

Trutta споживає:

- `classification.product_type` — визначає шаблон entitlementів (PASS / PACKAGE / ADDON тощо).
- `integrations.trutta.entitlement_profile_id` — профіль entitlements/token‑поведінки.
- `profiles.token_profile.profile_id` — логіка токена/пула/обмежень.
- `profiles.financial_profile.profile_id` — модель revenue split, ціноутворення.

**Інваріанти:**

1. Якщо продукт продається через Trutta, `integrations.trutta.entitlement_profile_id` обов’язковий.
2. `product_type` має бути допустимим для обраного типу entitlementів у Trutta.
3. `token_profile` та `financial_profile` мусять існувати в відповідних реєстрах Trutta.

### 4.2 Flow: продаж та погашення

1. mpt.tours / інший frontend викликає checkout на основі ProductDef (`product_id`, `version`).
2. Billing/Trutta‑інтеграція читає ProductDef, визначає entitlement‑профіль.
3. Trutta мінтить entitlement‑токен/запис з посиланням на `product_id` і `entitlement_profile_id`.
4. При погашенні (claim) Trutta перевіряє, що продукт все ще `active` або `deprecated`, але не `retired`.

### 4.3 Failure modes

- Відсутній або невалідний `integrations.trutta.entitlement_profile_id` → продукт не може бути проданий через Trutta.
- Продукт `retired` → нові entitlements не мінтяться; існуючі можуть мати окремі правила (policy в PD-005/PD-013).

---

## 5. Link to LEM (City Graph)

### 5.1 Основні поля ProductDef → LEM

LEM споживає:

- `integrations.lem.city_graph_profile_id` — профіль зв’язку продукту з міським графом.
- `classification.markets[]` — країна/регіон/місто (напр. `AT-VIE`).
- `segments[]` — таргетинг аудиторій (kidney, family, etc.).

Через профіль `city_graph_profile_id` продукт зв’язується з:

- `service_points` (кафе, готелі, клініки тощо).
- `service_edges` (маршрути, зв’язки між точками).
- `experience_snapshots` (агреговані враження/метрики).

### 5.2 Семантика посилань

- ProductDef **не містить** сирі списки venue‑id/edge‑id; це належить до LEM.
- ProductDef визначає **класи досвіду** та **гео/сегментні обмеження**.

### 5.3 Failure modes

- Відсутній `city_graph_profile_id` для продукту, який вимагає гео‑прив’язки → LEM не може коректно будувати маршрути; продукт може бути обмежений до non‑graph режиму (fallback, див. PD-006).

---

## 6. Link to mpt.tours & Frontend Apps

### 6.1 Поля для UI

Frontends (mpt.tours, white‑label застосунки) споживають:

- `identity.title.*` — назви для вітрин.
- `identity.slug`, `product_code` — URL/маркетингові ідентифікатори.
- `classification.category`, `tags`, `markets`, `segments` — фільтри/фасети.
- `profiles.ui_profile.profile_id` — детальна UI‑конфігурація (див. PD-007).
- `lifecycle.status`, `valid_from`, `valid_until` — контроль показу/продажу.

### 6.2 Мінімальний контракт

1. Без `title.en` продукт не відображається в каталозі.
2. Без `category` продукт може бути доступний лише через прямий лінк (не індексується в загальні вітрини).
3. Без `ui_profile` UI використовує дефолтні шаблони рендерингу.

---

## 7. Link to AI Agents

### 7.1 Типи агентів

- **Discovery/Recommendation агенти** — підбір продуктів під контекст юзера.
- **Configuration агенти** — допомагають операторам визначати параметри ProductDef.
- **Ops/Safety агенти** — моніторять метрики performance/quality та ініціюють зміни.

### 7.2 Які поля читають агенти

- `identity.*` — для пояснювальних відповідей.
- `classification.*` — фільтри, сегментація.
- `journey.*` — розуміння життєвого циклу продукту.
- `profiles.*` — обмеження (safety, financial, token).
- `integrations.*` — розуміння каналів погашення/інтеграцій.

Агенти **ніколи не змінюють ProductDef напряму**. Будь‑які зміни генеруються як пропозиції (PR‑шаблони, ADR‑драфти), що проходять через людський review (див. PD-011/PD-013).

---

## 8. Link to Analytics & Observability

### 8.1 Ключові ідентифікатори

Аналітика використовує:

- `identity.product_id` — основний ключ для fact‑tables.
- `identity.version` — зв’язок з конкретними конфігураціями в часі.
- `product_code`, `category`, `tags`, `markets`, `segments` — вимірювання та групування.
- `profiles.financial_profile.profile_id` — мапінг до фінансових моделей/UE.

### 8.2 Принципи

- Fact‑таблиці (transactions, entitlements, journeys) зберігають `product_id` + іноді `version`.
- Аналітичні вітрини join’ять ці факти з snapshot‑ами ProductDef станом на момент події.

---

## 9. Link to Registry Infra & CI/CD

### 9.1 Registry

- Зберігає всі версії ProductDef.
- Забезпечує API/CLI для:
  - пошуку продуктів;
  - отримання конкретної версії;
  - отримання актуальної (`active`) версії.
- Веде історію статусів (`draft`, `review`, `active`, `deprecated`, `retired`).

### 9.2 CI/CD

Пайплайни (див. PD-012) виконують:

- Валідацію проти схеми DSL (PD-001).
- Валідацію доменної моделі (PD-002).
- Валідацію посилань (TJM/Trutta/LEM/Enums).
- Публікацію в Registry при успішному проходженні.

---

## 10. Versioning & Backward Compatibility Across Systems

1. `meta.spec_version` визначає версію DSL‑спеки.  
2. `identity.version` визначає версію конкретного продукту.

Правила:

- Minor‑/patch‑зміни ProductDef, які не чіпають hard‑контракти, не вимагають синхронних оновлень TJM/Trutta/LEM.
- Major‑зміни повинні узгоджуватись через RFC‑процес (див. PD-016, PD-013) з усіма core‑споживачами.

---

## 11. Summary

- Product DSL / Registry — один контракт для всіх учасників екосистеми.
- TJM, Trutta, LEM, фронтенди, агенти та аналітика читають різні зрізи одного й того ж ProductDef.
- Всі зміни проходять через керований lifecycle і CI/CD; прямого запису в ProductDef з боку споживачів немає.
- Hard/soft контракти чітко позначають, які поля можна еволюціонувати без узгодження, а які — ні.

