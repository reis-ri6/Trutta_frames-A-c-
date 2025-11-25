# PD-002 — Trutta Concepts & Glossary

**ID:** PD-002  
**Назва:** Trutta Concepts & Glossary  
**Статус:** draft  
**Власники:** arch, product, data  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- DOMAIN-* — доменні моделі (tourism, hospitality, services, food, health, city)  
- VG-8xx — Engineering: DSL Runtime  
- VG-9xx — Analytics & Events from DSL

---

## 1. Purpose

Цей документ:

- фіксує **єдину термінологію** для Trutta-екосистеми;
- дає **формальні визначення** ключових понять:
  - Trutta, DSL, TJM, ABC, токени, ваучери, домени;
- уточнює **рівень абстракції** кожного терміна:
  - де це бізнес-концепт,
  - де — технічна сутність (entity/artefact/state machine);
- служить **референсом для інших PD/VG/DOMAIN/TEMPLATE-доків** та агентів.

Тут немає повних схем чи алгоритмів — тільки чіткі визначення і звʼязки між поняттями.

---

## 2. Як читати й використовувати глосарій

- **Bold** — термін, який визначається.  
- У дужках: `тип`:
  - `business-concept` — бізнесове поняття;
  - `domain-entity` — сутність доменної моделі;
  - `dsl-artefact` — файл/конфіг у DSL;
  - `runtime-object` — обʼєкт у виконанні (БД/контракт/сервіс);
  - `governance` — термін управління/процесів.

Якщо термін співпадає з доменною сутністю (`domain-entity`), деталі структури й полів описуються у відповідному `DOMAIN-*` документі. Тут — стисле визначення й роль у DSL.

---

## 3. Ядро Trutta

### 3.1. Trutta

**Trutta** (`business-concept`) — екосистема сервісів токенізації продуктів і послуг:

- перетворює продукти/сервіси на **формальні entitlements** (токени/ваучери);
- працює поверх різних доменів:
  - tourism, hospitality, services, food, health;
- підтримує:
  - анонімних покупців (ABC),
  - travel-journeys (TJM),
  - міські/індустріальні дані.

### 3.2. Product DSL

**Trutta Product DSL** (`dsl-artefact`) — формальна мова опису:

- продуктів і сервісів;
- оферів і токенів;
- звʼязків з TJM та доменами;
- constraint-ів (час/гео/health/регуляторика).

Фізично — набір схем і конфігів (`*.product.yaml`, `*.offer.yaml`, `*.token.yaml`, `*.journey.yaml`, `*.constraints.yaml`) плюс супровідна документація (MD).

### 3.3. Trutta Runtime

**Trutta Runtime** (`runtime-object`) — сукупність сервісів і компонентів, які:

- валідують DSL-файли;
- зберігають їх у registry/БД;
- компілюють у:
  - API-конфігурації,
  - токенові контракти,
  - аналітичні події/схеми.

---

## 4. TJM (Travel Journey Map)

### 4.1. Travel Journey

**Travel Journey (TJM)** (`business-concept`) — модель подорожі як послідовності:

- **stages** (pre-trip, on-trip, in-hotel, in-city, post-trip);
- **steps** та **events** у межах кожної стадії.

### 4.2. TJM Node

**TJM Node** (`domain-entity`) — елемент карти подорожі:

- може бути stage, step, micro-journey, route-point;
- має:
  - тип (наприклад, `booking`, `arrival`, `check-in`, `meal`, `activity`);
  - контекст (час, гео, канал, учасники).

### 4.3. TJM Binding

**TJM Binding** (`dsl-artefact`) — опис того, як **продукт/офер/токен** привʼязаний до TJM:

- на яких stages/steps доступний;
- які події він ініціює/закриває;
- які умови (constraints) застосовуються.

Фізично — `journey-binding.yaml` у DSL.

---

## 5. ABC (Anonymous Buyers Community)

### 5.1. ABC

**ABC — Anonymous Buyers Community** (`business-concept`) — модель спільнот, де:

- користувачі представлені **аватарами**, а не персональними профілями;
- попит агрегується **колективно/анонімно**;
- акцент — на:
  - поведінці,
  - деклараціях,
  - історії взаємодії,
  - а не на PII.

### 5.2. Avatar

**Avatar** (`domain-entity`) — абстрактне представлення користувача:

- має профіль уподобань;
- може належати до кількох ABC-комʼюніті;
- не містить PII, лише:
  - декларації (preferences, constraints),
  - історію взаємодій (токени, маршрути, фідбек).

### 5.3. Demand Pool

**Demand Pool** (`business-concept`) — агрегований попит групи аватарів:

- описує спільну потребу (наприклад: «кава в центрі Відня зранку», «3 ночі в готелі з окремою дієтою»);
- використовується для:
  - формування групових оферів;
  - торгу із постачальниками (supply competition).

### 5.4. Group Token

**Group Token** (`runtime-object`) — токен, що представляє:

- право групи на певний пакет сервісів;
- розподіл прав між учасниками;
- правила входу/виходу з групи (join/leave).

DSL описує структуру й правила; реалізація — в runtime.

---

## 6. Токени, ваучери, entitlement

### 6.1. Entitlement

**Entitlement** (`business-concept`) — право аватара/групи на отримання конкретного сервісу/ресурсу:

- завжди привʼязане до:
  - **продукту/оферу**, 
  - **контексту** (час/гео/health/регуляторика),
  - **субʼєкта** (avatar/group).

### 6.2. Token

**Token** (`runtime-object`) — технічна репрезентація entitlement:

- може бути:
  - on-chain (блокчейн-токен),
  - off-chain (запис у БД, signed-ваучер);
- має:
  - `token_type` (визначається в DSL),
  - state machine (issued, claimed, redeemed, expired, revoked тощо).

### 6.3. Voucher

**Voucher** (`runtime-object`) — окремий випадок токена:

- орієнтований на «одноразове право»:
  - чашка кави, прийом їжі, один вхід, одна поїздка;
- часто має короткий життєвий цикл і прості правила.

### 6.4. Token Type

**Token Type** (`dsl-artefact`) — опис класу токенів у DSL:

- що саме представляє (meal, night, city-pass, health-pack);
- які стани й переходи дозволені;
- які constraints застосовуються.

Фізично — `*.token.yaml`.

### 6.5. Token State Machine

**Token State Machine** (`runtime-object`) — модель життєвого циклу токена:

- стани: `issued`, `activated`, `claimed`, `redeemed`, `expired`, `cancelled`, `refunded` тощо;
- переходи:
  - хто/що може змінювати стан;
  - які події породжуються (для аналітики/моніторингу).

---

## 7. Продукти, офери, бандли

### 7.1. Product

**Product** (`business-concept`, `dsl-artefact`) — логічний товар/послуга:

- atomic або composite;
- описується в DSL (`*.product.yaml`);
- посилається на доменні сутності (Hotel, Dish, Route, ServicePoint тощо).

### 7.2. Offer

**Offer** (`business-concept`, `dsl-artefact`) — як продукт продається:

- ціна/валюта;
- умови (мін/макс, період дії, канали);
- які токени створюються при купівлі.

Фізично — `*.offer.yaml`.

### 7.3. Bundle / Package

**Bundle / Package** (`business-concept`) — композиція кількох продуктів:

- наприклад:
  - 3 ночі в готелі + сніданок + city-pass;
- на рівні DSL може:
  - бути окремим продуктом,
  - або агрегувати кілька продуктів під один офер.

---

## 8. Доменні категорії (індустріальні шари)

### 8.1. Tourism

**Tourism Domain** (`domain-entity set`) — все, що повʼязано з подорожами:

- `Trip`, `Segment`, `Itinerary`, `POI`, `Activity`, `TourOperator`.

### 8.2. Hospitality

**Hospitality Domain**:

- `Hotel`, `RoomType`, `Stay`, `Reservation`, `Amenity`.

### 8.3. Services

**Services Domain**:

- `ServicePoint` (кафе, ресторан, клініка, салон, сервісний центр);
- `Service`, `BookingSlot`, `Queue`.

### 8.4. Food

**Food Domain**:

- `Dish`, `Recipe`, `Ingredient`, `Menu`, `Portion`;
- звʼязок із нутрієнтними даними (див. `Health/Food Data`).

### 8.5. Health / Medical Constraints

**Health Domain**:

- `HealthConstraint` (умовна модель: низька сіль, без калію, без фосфору тощо);
- `DietProfile` (патерни обмежень, не PII);
- джерела даних:
  - FDA-таблиці нутрієнтів,
  - інші авторитетні бази (моделюються як reference data).

Жодних персональних медичних даних у DSL — тільки **типи обмежень** й **класи продуктів**.

### 8.6. City / Logistics

**City & Logistics Domain**:

- `City`, `Zone`, `Route`, `Stop`, `TransitOption`;
- використовується для:
  - маршрутизації,
  - доступності сервісів,
  - привʼязки token usage до гео.

---

## 9. Constraints & Policies

### 9.1. Time Constraint

**Time Constraint** (`dsl-artefact`) — обмеження на час:

- valid-from / valid-to;
- дні тижня;
- blackout dates.

### 9.2. Geo Constraint

**Geo Constraint** (`dsl-artefact`) — обмеження на географію:

- міста, райони, зони;
- радіус від конкретної точки;
- whitelist/blacklist зон.

### 9.3. Health Constraint

**Health Constraint** (`dsl-artefact`, `domain-entity`) — абстрактна модель обмежень:

- типове формулювання:
  - «low sodium», «low potassium», «renal-friendly», «no alcohol»;
- використовується для:
  - позначення продуктів/страв/оферів;
  - фільтрації в рекомендаціях.

Не містить персональних даних — тільки **кластери вимог**.

### 9.4. Regulatory Constraint

**Regulatory Constraint** (`dsl-artefact`) — обмеження, повʼязані з законом:

- мінімальний вік;
- заборона/дозвіл алкоголю;
- локальні обмеження на медичні сервісні пакети;
- специфіка країни/регіону (локальний legal layer).

---

## 10. Governance & Processes

### 10.1. Canonical Artefact

**Canonical Artefact** (`governance`) — документ/конфіг, який:

- визнаний «джерелом правди» для певного фрагменту знань;
- має `id` (PD/VG/CONCEPT/DOMAIN/TEMPLATE);
- відслідковується через:
  - `artefact-index.yaml`,
  - `docs-status.yaml`.

### 10.2. Draft / In Review / Canonical / Deprecated

**Document Status** (`governance`):

- `draft` — чернетка;
- `in_review` — у процесі верифікації;
- `canonical` — затверджений референс;
- `deprecated` — визнаний застарілим, лишається для історії;
- `conflict` — суперечлива інформація, потребує ручного вирішення.

### 10.3. Data Raids / Data Conveyors

**Data Raid** (`governance`, `runtime-process`) — інтенсивний забіг по збору/очищенню/структуризації даних для окремої області (місто, домен, продукт).

**Data Conveyor** — стабільний конвеєр оновлення:

- регулярне підживлення DSL/domains новими даними;
- інкрементальні оновлення замість ручного re-import.

---

## 11. Подальший розвиток глосарію

PD-002 — «ядро» термінів. Розширення:

- кожен новий PD/VG/DOMAIN-док, який вводить термін, має:
  - або посилатися на PD-002,
  - або доповнювати PD-002 чітким визначенням;
- AI-агенти при виявленні нових стабільних термінів:
  - пропонують зміни до PD-002 (через таски/PR),
  - не вводять «локальні синоніми» без синхронізації.

Будь-яка неузгодженість термінів між документами розглядається як **signal для конфлікту** в документації, а не як «норма».
