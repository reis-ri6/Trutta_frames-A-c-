# PD-001 Product DSL Core Specification v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture  
**Scope:** TJM / Trutta / LEM / mpt.tours ecosystem  

---

## 1. Purpose

Product DSL (PDSL) — це формальна мова для опису продуктів, які продаються, виконуються та аналізуються в екосистемі.  
Мета:
- Дати єдину, машино‑читабельну **ProductDef**, яку можуть споживати TJM, Trutta, LEM, фронтенди, агенти й аналітика.
- Мінімізувати "ручні" угоди між командами через централізований опис контрактів продукту.
- Забезпечити керовану еволюцію продуктової моделі через реєстр та чітке версіонування.

---

## 2. Scope

### 2.1 Що входить
- Структура та інваріанти **ProductDef** і пов’язаних структур верхнього рівня.
- Базові типи та семантика полів (без глибоких доменних деталей).
- Життєвий цикл DSL‑артефактів: Draft → Released → Deprecated → Retired.
- Модель сумісності версій для споживачів (TJM, Trutta, LEM, агенти, UI).

### 2.2 Що не входить
- Фізична доменна модель БД (див. PD-002).
- Деталі API та протоколів реєстру (див. PD-003).
- Конкретні профілі (financial, ops, loyalty, safety) — лише каркас (деталі в PD-007, PD-009, PD-010).

---

## 3. Design Goals

1. **Single Source of Truth.** Один ProductDef повинен описувати продукт для всіх сервісів.
2. **Schema‑first.** Усі артефакти валідовані через версію схеми (JSON Schema / OpenAPI‑сумісно).
3. **Composability.** Продукти збираються з профілів, journey‑шаблонів та інтеграційних блоків.
4. **Predictable Evolution.** Чіткі правила breaking/non‑breaking змін.
5. **Multi‑tenant & multi‑region.** Можливість наслідування/override від глобальної до локальної версії.
6. **AI‑friendly.** Структури оптимізовані для LLM‑агентів: стабільні ключі, мінімум двозначностей.

---

## 4. Conceptual Layers

PDSL описує продукт у трьох шарах:

1. **Core Product Layer** — що це за продукт, для кого, які базові характеристики (id, назва, категорія, ринок, міста, сегменти).
2. **Runtime & Journey Layer** — як продукт виконується: journey‑класи, стани, події, взаємодія з TJM та агентами.
3. **Profiles & Integration Layer** — як продукт включений у фінанси, токени, безпеку, якість, міський граф.

Кожен ProductDef повинен чітко вказувати, які блоки/профілі він використовує.

---

## 5. Core Top‑Level Structure

Топ‑рівень ProductDef (логічна модель, не конкретна серіалізація):

- `meta`: службова інформація DSL.
- `identity`: стабільні ідентифікатори продукту.
- `classification`: таксономія та таргетинг.
- `lifecycle`: стани продукту та вікно дії.
- `journey`: посилання на TJM‑моделі та runtime‑поведінку.
- `profiles`: набір профілів (token, loyalty, financial, ops, ui тощо).
- `integrations`: інтеграційні блоки з Trutta, LEM, іншими сервісами.

### 5.1 `meta`

Обов’язкові поля:
- `spec_version: string` — версія цієї специфікації (semver, напр. `1.0.0`).
- `created_at: datetime` — ISO‑8601, UTC.
- `updated_at: datetime` — ISO‑8601, UTC.
- `author: string` — технічний owner (e‑mail/slug).
- `source_repo: string` — посилання на репозиторій/шлях.

Інваріанти:
- `spec_version` **не** може бути null.
- `created_at` залишається незмінним.

### 5.2 `identity`

Обов’язкові поля:
- `product_id: string` — глобальний стабільний ідентифікатор (ULID/UUID, видає Registry).
- `product_code: string` — читабельний код (напр. `VG-VIEN-COFFEE-PASS`), унікальний у рамках організації.
- `slug: string` — URL‑френдлі ідентифікатор, унікальний у рамках ринку/домену.
- `version: string` — semver, контролюється Registry.
- `title: object` — локалізовані назви, ключі як BCP‑47 (`en`, `de-AT`, `uk-UA`).

Інваріанти:
- `(product_id, version)` — глобально унікальна пара.
- `product_id` не змінюється між версіями, `version` змінюється завжди.

### 5.3 `classification`

Мінімальний набір:
- `product_type: enum` — напр. `PASS`, `PACKAGE`, `SINGLE_SERVICE`, `ADDON`.
- `category: string` — таксономія високого рівня (food, city-pass, wellness, medical, etc.).
- `tags: string[]` — вільні теги для пошуку.
- `markets: string[]` — ISO country/region codes (напр. `AT-VIE`).
- `segments: string[]` — логічні сегменти аудиторії (напр. `kidney`, `vegan`, `family`).

Інваріанти:
- `product_type` визначає дозволені профілі та інтеграції (див. PD-002/PD-007).

### 5.4 `lifecycle`

Базова модель станів:
- `status: enum` — `draft | review | active | deprecated | retired`.
- `valid_from: datetime | null`.
- `valid_until: datetime | null`.
- `replaces: string | null` — посилання на попередню версію (product_id+version або product_code+version).
- `superseded_by: string | null` — зворотнє посилання (опційно, скоріше розраховується Registry).

Інваріанти:
- `active` ⇒ `valid_from != null`.
- `retired` ⇒ всі нові продажі заборонені, але історія виконання зберігається.

### 5.5 `journey`

Верхній рівень зв’язку з TJM:
- `journey_class: string` — ID/slug класу подорожі (напр. `city.day.pass`).
- `tjm_document_ref: string` — посилання на TJM journey‑документ / версію.
- `entry_points: string[]` — ключі/скоупи, з яких може стартувати продукт.
- `states: object` — карта логічних станів продукту на рівні DSL (spine для TJM state‑machine).

Мінімальна вимога: **ProductDef не може бути `active`, якщо не вказано `journey_class` та `tjm_document_ref`**.

### 5.6 `profiles`

`profiles` — словник, де ключ — тип профілю, значення — референс або inlined‑конфіг.
Приклади ключів:
- `token_profile`
- `loyalty_profile`
- `pricing_profile`
- `financial_profile`
- `ops_profile`
- `safety_profile`
- `quality_profile`
- `ui_profile`

Інваріанти:
- Набір обов’язкових профілів залежить від `product_type`.
- Значення кожного профілю повинні відповідати власній схемі (PD-007, PD-009, PD-010).

### 5.7 `integrations`

Структура верхнього рівня:
- `trutta: object | null` — інтеграція з токенами/entitlements.
- `lem: object | null` — інтеграція з міським графом.
- `external: object` — інші інтеграції (резервації, квитки, медичні сервіси тощо).

Інваріанти:
- Якщо поле інтеграції не використовується — воно **омітиться**, а не заповнюється порожніми об’єктами.

---

## 6. Types & Validation

### 6.1 Примітиви

- `string` — UTF‑8, довжина `1..1024` за замовчуванням (конкретні поля можуть мати інші обмеження).
- `text` — довгі описи, до `10_000` символів.
- `integer` — 64‑біти, без плаваючої коми.
- `decimal` — рядкове представлення десяткового числа з фіксованою точністю (напр. `"10.25"`).
- `boolean` — `true | false`.
- `datetime` — ISO‑8601, завжди з часовою зоною (UTC).
- `money` — `{"amount": "decimal", "currency": "ISO-4217"}`.

### 6.2 Enum‑и

Усі enum‑и повинні бути задекларовані в централізованому **Enum Registry** (окремий артефакт, не частина PD-001). ProductDef може посилатися лише на enum‑значення з цього реєстру.

### 6.3 Референси

- `Ref<T>` — строкове значення, яке валідується Registry (напр. `product_id`, `journey_class`, `profile_id`).
- У DSL заборонені "вільні" посилання, які не можуть бути перевірені на момент публікації.

---

## 7. Lifecycle & Versioning Rules

### 7.1 Статуси

- `draft` — локальні зміни, можуть бути невалідні відносно повної схеми.
- `review` — повна валідація, потрібні всі обов’язкові поля.
- `active` — дозволений продаж, версія зафіксована, зміни лише через нову версію.
- `deprecated` — нові продажі дозволені, але рекомендовано мігрувати на нову версію.
- `retired` — нові продажі заборонені.

### 7.2 Типи змін

- **Patch (x.y.z → x.y.(z+1))** — не впливає на контракти з клієнтом (копірайт, опис, незначні UI‑поля); backward‑compatible.
- **Minor (x.y.z → x.(y+1).0)** — додає нові опційні поля або профілі; споживачі, які не знають про них, можуть ігнорувати.
- **Major ((x.y.z → (x+1).0.0))** — потенційно breaking зміни; потребує явної міграції в Registry.

Інваріант:
- ProductDef **не може** перейти з `active` в `draft`; лише в `deprecated` / `retired`.

---

## 8. Multi‑Tenant & Localisation Model

PDSL підтримує нашарування продуктів:

- **Global Base Product** — канонічний опис.
- **Operator Overlay** — доповнення/override для конкретного оператора/бренду (логотипи, політики, канали).
- **Market Overlay** — країна/регіон (валюта за замовчуванням, юридичні дисклеймери).
- **City/Vendor Overlay** — локальні обмеження, канали погашення, географія.

Технічно оверлеї реалізуються як окремі ProductDef‑артефакти або delta‑patchі (конкретний механізм описується в PD-003/PD-007). PD-001 фіксує принцип:

> Базовий продукт не може посилатися на поля, які можуть бути визначені лише в оверлеї (напр. конкретні адреси точок погашення).

---

## 9. Security & Compliance Constraints

- ProductDef **не може** містити PII (персональні дані конкретних користувачів).
- В ProductDef **не зберігаються** секрети (API keys, приватні URI, паролі).
- Всі посилання на зовнішні системи повинні бути через абстрактні ідентифікатори інтеграцій (`integration_id`), а не прямі секрети.
- Для полів, пов’язаних з регульованими доменами (медицина, фінанси), обов’язкові посилання на відповідні policy‑документи.

---

## 10. Extensibility

### 10.1 Custom Extensions

Локальні розширення дозволені лише через нейтральні неймспейси:

- `x_<namespace>_*` для технічних флагів.
- `custom_*` для продуктово‑специфічних полів.

Інваріанти:
- Розширення не можуть змінювати семантику обов’язкових полів.
- В стандартну схему можуть бути включені лише після формального RFC‑процесу (див. PD-013).

### 10.2 AI‑Friendly Design

- Ключі мають бути стабільними, короткими та однозначними.
- Тексти опису (`description`, `copy.*`) зберігаються окремо від технічних полів, щоб спростити prompt‑інженерію.
- Заборонено "вбудовувати" інструкції для агентів у довгі вільні тексти без структурованих полів.

---

## 11. Operational Requirements

- Будь‑який ProductDef повинен бути валідований проти актуальної схеми до публікації в Registry.
- Усі зміни проходять через git‑based workflow (PR, review, approvals).
- CI повинна забезпечувати:
  - schema‑validation;
  - enum‑validation;
  - reference‑validation (journey, profiles, integrations);
  - базовий semantic‑lint (min/max, consistency checks).

Деталі реалізації — в PD-011 та PD-012.

---

## 12. Minimal Example (Normative)

Нормативний мінімальний приклад у YAML (повніші приклади — в PD-001-product-dsl-core-templates.md):

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "2025-11-15T10:00:00Z"
  updated_at: "2025-11-15T10:00:00Z"
  author: "product-arch@reis.agency"
  source_repo: "git@github.com:ri6/product-dsl.git#examples/vien-coffee-pass.yaml"

identity:
  product_id: "01HXYZABCD1234EFGH5678JKL"
  product_code: "VG-VIEN-COFFEE-PASS"
  slug: "vienna-coffee-day-pass"
  version: "1.0.0"
  title:
    en: "Vienna Coffee Day Pass"

classification:
  product_type: "PASS"
  category: "food-and-beverage"
  tags: ["vienna", "coffee", "day-pass"]
  markets: ["AT-VIE"]
  segments: ["traveler", "coffee-lover"]

lifecycle:
  status: "active"
  valid_from: "2025-12-01T00:00:00Z"
  valid_until: null
  replaces: null
  superseded_by: null

journey:
  journey_class: "city.coffee.pass"
  tjm_document_ref: "TJM-JOURNEY-COFFEE-PASS@1.0.0"
  entry_points: ["app.home.hero", "city.vienna.offers"]
  states:
    created: {}
    issued: {}
    redeemed: {}
    expired: {}

profiles:
  token_profile: { profile_id: "TP-VIEN-COFFEE-PASS" }
  financial_profile: { profile_id: "FP-VIEN-COFFEE-PASS" }
  ops_profile: { profile_id: "OP-VIEN-COFFEE-PASS" }
  ui_profile: { profile_id: "UI-VIEN-COFFEE-PASS" }

integrations:
  trutta:
    entitlement_profile_id: "TRT-ENT-VIEN-COFFEE-PASS"
  lem:
    city_graph_profile_id: "LEM-CITY-VIE-COFFEE-PASS"
  external: {}
```

Цей приклад вважається нормативним для мінімально валідного `PASS`‑типу продукту. Усі майбутні схеми й приклади мають залишатися з ним сумісними або проходити через формальний процес breaking‑змін (PD-016).

