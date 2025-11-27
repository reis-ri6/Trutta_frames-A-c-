# PD-013 — Trutta Vendor & Service Network Model

**ID:** PD-013  
**Назва:** Trutta Vendor & Service Network Model  
**Статус:** draft  
**Власники:** product, bizdev, data, ops, legal  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-008 — Trutta Agent & Automation Layer  
- PD-009 — Trutta City & Project Instantiation Model  
- PD-010 — Repositories & Documentation Conventions  
- PD-011 — Security, Privacy & Data Governance Baseline  
- PD-012 — Runtime & Service Architecture (High-level)  
- VG-500..504 — Vendor & Network Ops (онбординг, DSA, меню, токени, SLA)

---

## 1. Purpose

Цей документ фіксує **канонічну модель Vendor & Service Network** у Trutta:

- хто такі `Vendor`, `ServicePoint`, `Network`, `Cluster`, `Zone`;
- як вони привʼязані до:
  - продуктів/оферів/токенів (PD-001, PD-005),
  - TJM (де в подорожі вмикається сервіс) (PD-006),
  - ABC (попит, комʼюніті, пул покупців) (PD-007),
  - індустріальних даних (PD-004);
- як працює **рівнева модель інтеграції** вендорів та SLA.

Мета — зробити один стабільний каркас, на якому сидять:

- city-репи (`trutta_city-*`),
- проектні програми (Sospeso/BREAD/vien.geist/health-пілоти),
- VG-500..504 (операційні гіди).

---

## 2. Scope

### 2.1. Входить

- логічні сутності: `Vendor`, `ServicePoint`, `Network`, `Cluster`, `Zone`, `Menu`, `Offering`;
- рівні інтеграції вендора (L0–L3);
- взаємозвʼязок із DSL, токенами, TJM, ABC;
- базові принципи SLA/quality/даних.

### 2.2. Не входить

- детальні договори / DSA / шаблони SLA (VG-501, VG-504);
- повні схеми БД (DOMAIN + schemas/db);
- конкретні процеси онбордингу (VG-500).

---

## 3. Core entities

### 3.1. Vendor

**Vendor** — юридична/операційна одиниця, яка надає послуги/товари:

- кафе, ресторан, бар;
- готель/хостел/апарт-отель;
- клініка/санаторій;
- транспортний оператор;
- інші сервісні бізнеси.

Основні атрибути:

- `vendor_id` (canonical);
- `legal_profile` (мінімальний набір для комплаєнсу — окремий домен/сервіс);
- `business_profile`:
  - категорії (food/hospitality/health/services);
  - рівень/тип (independent/chain/NGO/municipal);
- `trutta_integration_level` (див. L0–L3).

### 3.2. ServicePoint

**ServicePoint** — конкретна фізична або цифрова точка надання сервісу:

- локація закладу (кавʼярня, ресторан);
- ресепшн/frontdesk готелю;
- конкретний кабінет/відділення клініки;
- онлайн-сервіс, привʼязаний до міста/зони.

Привʼязка:

- `service_point_id`;
- `vendor_id`;
- `city_id`, `zone_id`, `geo_point`;
- `service_types` (coffee, breakfast, lunch, check-in, treatment, etc.).

У city-репах (PD-009) `ServicePoint` — ключова сутність city-graph для сервісів.

### 3.3. Network & Cluster

**Network** — логічне обʼєднання вендорів/точок:

- мережа кавʼярень / готельний бренд / медична мережа;
- Trutta-партнерська мережа в місті/країні;
- municipal/NGO програма.

**Cluster** — підмножина вендорів/ServicePoint-ів у спільному контексті:

- «центр міста»;
- «навколо конкретного готелю»;
- «health-friendly мережа».

Network/Cluster використовуються для:

- таргетування токенів і продуктів (city-pass, coffee-pass, health-pass);
- розподілу навантаження й субсидій.

### 3.4. Zone

**Zone** — частина міста (див. PD-004/DOMAIN-city):

- транспортні/географічні/функціональні зони;
- можуть бути використані для:
  - тарифікації;
  - токен-constraints (де дійсний entitlement);
  - планування маршрутів.

`ServicePoint` завжди привʼязаний до `Zone` (через city-graph).

### 3.5. Menu & Offering

**Menu** — набір `Offering` для конкретного ServicePoint (або Vendor):

- FOOD: страви/напої;
- SERVICES: послуги (ніч у номері певного типу, процедура, пакет);
- кожен `Offering`:
  - має мапу на DSL-продукт/entitlement (PD-001, PD-005);
  - може мати кілька **режимів**:
    - звичайний продаж;
    - продаж через Trutta-чек (токен);
    - прихований/спец-меню для програм.

---

## 4. Integration levels (L0–L3)

Щоб стандартизувати, як вендори входять у Trutta, вводиться **рівнева модель інтеграції**.

### 4.1. L0 — Discovery / Directory-only

- Vendor/ServicePoint є в міському каталозі:
  - мінімальна інформація (назва, адреса, категорія);
  - джерело: OTA/Maps/OSM/Yelp/інші (PD-004).
- Немає:
  - прямих домовленостей із Trutta;
  - гарантій якості/доступності.

Використовується:

- для рекомендацій/оновлення карти;
- як кандидати для онбордингу (L1+).

### 4.2. L1 — Data-only / Menu-level integration

- Підписаний базовий DSA (VG-501):
  - vendor дає доступ до меню/графіку/статусу;
- Меню нормалізовано (VG-502) в canonical FOOD/Services-слої (PD-004);
- Trutta може:
  - будувати рілевантні рекомендації;
  - оцінювати потенціал для токенізацій.

Немає:

- токенів/ваучерів;
- фінансових зобовʼязань.

### 4.3. L2 — Token Acceptance / Program integration

- Vendor приймає Trutta-токени (PD-005);
- Є:
  - Data Sharing Agreement;
  - Token Acceptance Guide (VG-503);
  - SLA по редемпшену та сервісу (VG-504);
- Runtime:

  - ServicePoint підключений до токен-runtime (PD-012);
  - tokens: `coffee_cup`, `meal_token`, `night_token`, `city-pass` etc.

Використовується в:

- Sospeso/meal-програмах;
- city-pass/coffee-pass;
- health-friendly bundles.

### 4.4. L3 — Deep Integration / Co-designed Products

- Vendor/Network співдизайнить продукти/програми з Trutta:

  - спеціальні меню/пакети;
  - динамічні ціни, capacity-based офери;
  - спільні ABC-комьюніті.

- Присутні:

  - інтеграція з внутрішніми системами вендора (POS/PMS/HIS);
  - двосторонні дані (якість сервісу, capacity, load);
  - кастомні TokenTypes (на базі PD-005).

L3 — базовий рівень для довгострокових міських або health-програм.

---

## 5. Vendor Network ↔ DSL, Tokens, TJM, ABC

### 5.1. Vendor ↔ Product DSL

Кожен `Offering` на ServicePoint:

- мапиться на DSL-продукт/entitlement:

```yaml
offering_id: "OFF-COFFEE-001"
service_point_id: "SP-123"
dsl:
  product_id: "PRD-COFFEE-SINGLE"
  token_type_id: "TT-COFFEE-CUP"
  constraints_ref: ["CONSTR-TIME-MORNING"]
```

Product DSL (PD-001, PD-003):

* використовує Vendor/ServicePoint/Zone як **targets** для продуктів;
* city-/project-рівні DSL-конфіги посилаються на canonical Vendor/ServicePoint.

### 5.2. Vendor ↔ Tokens

Для L2/L3-вендорів:

* Token runtime знає:

  * які токени приймає конкретний ServicePoint;
  * які правила редемпшену/escrow;
* PD-005 (token archetypes) використовується як **мова договору**:

  * що таке base entitlement;
  * що таке bundle/pass/group token;
  * які обмеження по fraud/лимітах.

### 5.3. Vendor ↔ TJM

TJM (PD-006):

* розуміє, на яких stages/steps/micro-journeys:

  * актуальні конкретні ServicePoint;
  * які продукти (через menu/offering) логічні.

Приклади:

* `arrival` → «кава поблизу готелю»;
* `in-hotel` → room-service/спа/процедура;
* `in-city` → маршрути через кластер ServicePoint-ів.

### 5.4. Vendor ↔ ABC

ABC (PD-007):

* агрегує попит (DemandPools) за:

  * типами вендорів/сервайсів;
  * зонами/кластерами;
  * TJM-контекстом.

Vendor Network:

* дає «supply side»: де та хто потенційно може цей попит закрити;
* L2/L3 — де supply легально/операційно готовий до токенів.

---

## 6. Data model & layers (звʼязок з PD-004)

### 6.1. Canonical Vendor/Service data

У canonical-слоях (PD-004):

* `vendors` — **нормалізований довідник**:

  * злиття кількох джерел (OTA/Maps/списки від міст/партнерів);
* `service_points`:

  * координати, зони, категорії;
* `menus`, `offerings`:

  * нормалізована їжа/послуги;
  * мапа на нутрієнти/FDA (для food/health кейсів).

### 6.2. Analytics

Аналітичні вʼюхи:

* `vendor_token_stats`:

  * редемпшени, breakage, час, чеки;
* `vendor_quality_metrics`:

  * NPS/UGC/рейтинги;
* `zone_coverage`:

  * де Trutta має/не має покриття по категоріях сервісів.

VG-9xx деталізує структури й метрики.

---

## 7. Quality, SLA & network health

### 7.1. SLA-блоки

Базові осі якості (реферують на VG-504):

* **Service SLA**:

  * час обслуговування;
  * виконання умов токена/офера;
* **Data SLA**:

  * актуальність меню/годин роботи;
  * достовірність capacity/статусу;
* **Token SLA**:

  * коректне сканування/прийом токенів;
  * handling помилок/фрод-підозр.

### 7.2. Network health

Показники:

* покриття (coverage) по місту/зонам/категоріям;
* баланс попиту/пропозиції:

  * є попит, немає вендорів (гепи);
  * є вендори, немає попиту (overcapacity);
* якість виконання програм (Sospeso, health).

Ці метрики використовуються:

* в ABC-агентах (пропозиції для розширення/скорочення мережі);
* у city/project-ops (які вендори/зони треба підсилити).

---

## 8. Governance & evolution

### 8.1. Хто керує Vendor Network

* **BizDev**:

  * онбординг, переговори, DSA/SLA;
* **Data**:

  * нормалізація й якість data-layer;
* **Product**:

  * використання вендорів у продуктах/програмах;
* **Legal**:

  * контракти, регуляторика, відповідальність.

### 8.2. Зміни моделі

Будь-яка зміна, яка:

* додає новий тип вендора/сервайсу;
* змінює модель інтеграцій L0–L3;
* додає/змінює ключові сутності (`Vendor`, `ServicePoint`, `Network`, `Cluster`, `Zone`),

повинна:

1. Бути оформлена як апдейт PD-013 (або нового PD, якщо сутність велика).
2. Потім — оновлення DOMAIN- та VG-доків, схем БД, пайплайнів.

---

## 9. Відношення до VG-500..504

PD-013 — **концептуальний каркас** Vendor & Network.

VG-500..504:

* розкладають це на:

  * конкретні кроки онбордингу (VG-500),
  * шаблони DSA (VG-501),
  * мапінг меню (VG-502),
  * гайд по прийому токенів (VG-503),
  * SLA-рамку (VG-504).

Будь-який city/project, що працює з вендорами, повинен:

* тримати доменні моделі сумісними з PD-013;
* користуватись VG-500..504 як операційними книжками.

PD-013 закріплює: Vendor & Service Network — такий же «першокласний» шар Trutta, як DSL, TJM, ABC та токени.
