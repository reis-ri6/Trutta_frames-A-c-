# PD-001 — Trutta Product DSL Blueprint

**ID:** PD-001  
**Назва:** Trutta Product DSL — Blueprint  
**Статус:** draft  
**Власники:** arch, product, data  
**Повʼязані концепти:** TJM (Travel Journey Map), ABC (Anonymous Buyers Community), Trutta Tokenization, міські/індустріальні домени (tourism, hospitality, services, food, health)

---

## 1. Purpose

Цей документ фіксує **верхньорівневу модель Trutta Product DSL** (далі — DSL):

- навіщо потрібна окрема мова опису продуктів і сервісів;
- які шари даних/моделей вона покриває;
- як DSL повʼязана з:
  - TJM (travel journey),
  - ABC (анонімні спільноти покупців),
  - токенізацією страв/сервісів,
  - індустріальними доменами (туризм, готелі, кафе, медичні сервіси, рецепти, нутрієнти, FDA тощо);
- як DSL живе в рантаймі:
  - з чого складається pipeline «опис → валідація → деплой → моніторинг».

Детальні схеми, приклади й темплейти виносяться в окремі PD/VG/DOMAIN/TEMPLATE-документи. Тут — «мапа території».

---

## 2. Scope

### 2.1. Що входить у DSL

DSL описує:

- **Продукти й сервіси**:
  - atomic (страва, кава, поїздка, ніч у готелі);
  - composite (пакет проживання + харчування, тур-пакет, медичний пакет).
- **Право на споживання (entitlement)**:
  - які права дає токен/ваучер;
  - коли, де, ким і як вони можуть бути використані.
- **Контексти використання**:
  - travel-journey (TJM) — стадії й кроки подорожі;
  - ABC-комʼюніті — анонімні профілі, групові потреби, спільні покупки;
  - міські/індустріальні домени — готелі, ресторани, сервісні точки, транспорт, клініки.
- **Constraints та політики**:
  - часові (коли можна використати);
  - географічні (де можна використати);
  - health/диєтичні обмеження (на рівні моделі, без PII);
  - регуляторні/комплаєнс (FDA, локальні регуляції).

### 2.2. Що НЕ входить

DSL **не** описує:

- внутрішню реалізацію API/сервісів;
- бізнес-процеси юридичних осіб (бухгалтерія, податки);
- UI/UX-мокапи (лише референси й семантика);
- індивідуальні медичні рекомендації (тільки абстрактні моделі обмежень).

---

## 3. Звʼязок із TJM, ABC та Trutta Tokenization

### 3.1. TJM (Travel Journey Map)

DSL повинна вміти описувати:

- які продукти/сервіси доступні на кожній стадії подорожі;
- як токени/ваучери «привʼязуються» до:
  - кроків TJM (pre-trip, on-trip, in-hotel, in-city, post-trip);
  - мікро-маршрутів (routes, city experiences).

TJM дає **вісь часу та контексту**, DSL — **формальний опис того, що доступно і як це працює**.

### 3.2. ABC (Anonymous Buyers Community)

DSL повинна підтримувати:

- опис продуктів/сервісів для групової/анонімної купівлі;
- моделювання:
  - анонімних сегментів і «пулів» попиту;
  - групових токенів/ваучерів;
  - правил розподілу й редемпшена між учасниками.

ABC дає **фреймворк попиту й спільнот**, DSL описує **пропозицію та правила використання**.

### 3.3. Trutta Tokenization

DSL є **джерелом правди** для:

- типів токенів (coffee cup, meal, night, city-pass, health-friendly-meal тощо);
- процесів:
  - mint / remint / burn;
  - claim / redeem / transfer / escrow;
- привʼязки до реального сервісу й постачальника (vendor, venue, route).

---

## 4. Шари DSL

DSL розкладається на кілька шарів.

### 4.1. Canonical Domain Layer

- Модель доменів: tourism, hospitality, services, food, health.
- Доменні сутності:
  - `Trip`, `Segment`, `POI`, `Hotel`, `RoomType`, `Menu`, `Dish`, `Ingredient`,
    `HealthConstraint`, `Vendor`, `ServicePoint` тощо.
- Технічна опора: `domains/` і `schemas/db/`.

### 4.2. Product DSL Schema Layer

- Формальні схеми YAML/JSON (`schemas/dsl/`):
  - `product.manifest.yaml` — опис продукту/сервісу;
  - `offer.yaml` — умови продажу;
  - `token.yaml` — типи токенів/ваучерів;
  - `journey-binding.yaml` — звʼязок з TJM;
  - `constraints.yaml` — health/час/гео/регуляторика.
- Структури незалежні від конкретної БД чи API.

### 4.3. Runtime / Execution Layer

- Як DSL-конфіги:
  - валідуються;
  - зберігаються (registry/БД);
  - розгортаються в:
    - API-маршрути;
    - токенові контракти (on-chain/off-chain);
    - аналітичні події.

### 4.4. Analytics & Governance Layer

- Які події/метрики народжуються з DSL:
  - `product_view`, `offer_shown`, `token_minted`, `token_redeemed`,
    `journey_step_completed` тощо.
- Як відстежуються:
  - ефективність продуктів/оферів;
  - health-compliance;
  - city/venue performance.

---

## 5. Базові сутності DSL

(Детальна формалізація — в окремих PD/DOMAIN-доках; тут — список верхнього рівня.)

- **Product**  
  Логічний продукт:
  - atomic (одна дія/страва/ніч),
  - composite (пакет, маршрут, subscription).

- **Offer**  
  Як продукт доступний на ринку:
  - ціна, валюта, обмеження в часі;
  - канали продажу (app, бот, OTA, офлайн);
  - мін/макс кількість, які токени виникають.

- **Token / Voucher**  
  Формалізований entitlement:
  - тип токена;
  - правила mint/remint/burn;
  - правила claim/redeem;
  - escrow/умовні права.

- **Journey Binding (TJM Binding)**  
  Як продукт/токен лягає на TJM:
  - на яких стадіях доступний;
  - які події закриває/відкриває;
  - як впливає на наступні кроки подорожі.

- **Constraints**  
  Глобальні й локальні обмеження:
  - час (valid from/to, blackout dates);
  - гео (city/region/zone/route);
  - health/диєтичні (алергени, нутрієнти, профілі);
  - регуляторні (вік, алкоголь, медичні сервіси).

---

## 6. Формат артефактів DSL

Артефакти DSL зберігаються як **YAML/JSON + MD**, читаються людьми й машинами.

### 6.1. Маніфести

- Продукти/офери/токени:
  - `*.product.yaml`
  - `*.offer.yaml`
  - `*.token.yaml`
- Маршрути/міські продукти:
  - `*.journey.yaml`
  - `*.route.yaml`
- Constraints:
  - `constraints/*.yaml` (health, geo, time, regulatory).

Кожен файл:

- мапиться на доменну модель (`domains/*`, `schemas/db/*`);
- має owner (product/arch/data);
- має свій життєвий цикл: `draft → in_review → active → deprecated`.

---

## 7. Інтеграція з доменами

DSL не дублює домени — вона **посилається на них**.

### 7.1. Приклади

- **Продукт «3 ночі у готелі + сніданок»**
  - посилання:
    - `domains/hospitality/Hotel`, `RoomType`;
    - `domains/food/Dish`, `Menu`;
  - токени: `night_token`, `breakfast_token`.

- **Продукт «City coffee pass»**
  - посилання:
    - `domains/services/ServicePoint` (кафе, кавʼярні);
    - `domains/city/Zone` (зони міста);
  - токен: `coffee_cup_token`.

- **Продукт «Kidney-friendly meal pack»**
  - посилання:
    - `domains/food/Dish`, `Ingredient`;
    - `domains/health/HealthConstraint` (моделі, а не персональні дані);
    - FDA/нутрієнтні довідники.

---

## 8. Governance та версіонування DSL

### 8.1. Ролі

- **Архітектори**
  - змінюють структуру DSL (схеми, нові типи артефактів).
- **Продакти**
  - створюють/оновлюють конкретні продукти/офери/токени.
- **Data/analytics**
  - узгоджують івенти, метрики, вимоги до даних.
- **Legal/Compliance**
  - перевіряють constraints (особливо health/FDA/регуляторика).

AI-агенти можуть:

- нормалізувати/структуризувати текст;
- виявляти конфлікти/дублікати;
- генерувати чернетки артефактів.

Остаточне рішення — за людьми.

### 8.2. Versioning

- Семантичне версіонування DSL-схем:
  - `MAJOR.MINOR.PATCH`:
    - MAJOR — некомпатибельні зміни структури;
    - MINOR — нові поля/типи без поломки існуючих;
    - PATCH — уточнення описів/правил без зміни структури.
- Міграції:
  - кожна зміна схеми має план:
    - як перетворюються старі файли;
    - як мігруються дані;
    - які API змінюються.

---

## 9. High-level runtime

Пайплайн «DSL → виконання»:

1. **Design**  
   - люди/агенти створюють/редагують DSL-файли в репозиторії або через UI-редактор, який пише сюди.

2. **Validation & Linting**  
   - перевірка:
     - відповідності схемам;
     - коректності посилань на домени;
     - consistency constraints.

3. **Compilation / Deployment**  
   - генерація:
     - конфігів для API/сервісів;
     - налаштувань токенів/контрактів;
     - аналітичних схем (events, dashboards).

4. **Monitoring & Feedback**  
   - збір метрик;
   - виявлення помилок у DSL;
   - пропозиції змін через окремі PD/VG/DOMAIN-документи й таски.

---

## 10. Roadmap (DSL-рівень)

PD-001 задає каркас. Наступні кроки:

- **PD-002 — Concepts & Glossary**  
  формалізація термінів DSL, TJM, ABC, доменів.
- **PD-0xx — DSL File Types & Schemas**  
  схеми для:
  - `product.manifest.yaml`,
  - `offer.yaml`,
  - `token.yaml`,
  - `journey-binding.yaml`,
  - `constraints.yaml`.
- **VG-8xx — Engineering: DSL Runtime**  
  runtime/валідація/деплой.
- **VG-9xx — Analytics & Events from DSL**  
  події та аналітика з DSL.
- **DOMAIN-***  
  деталізація доменів: tourism/hospitality/services/food/health, city graph.

Будь-які наступні PD/VG/DOMAIN/TEMPLATE-документи повинні розвивати цю картину.  
Якщо нові вимоги суперечать PD-001, спочатку оновлюється PD-001, потім — похідні документи.
