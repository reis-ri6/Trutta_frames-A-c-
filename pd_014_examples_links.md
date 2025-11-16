# PD-014 Examples Links – Demo & Docs Integration v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Docs / Product

**Related docs:**  
- PD-014-examples-and-templates-library.md  
- PD-014-generated-samples-json  
- PD-015-testing-and-conformance-suite.md  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-013-governance-and-compliance-spec.md

Мета документа — описати, **як бібліотека прикладів EX-XXX** під’єднується до:

- демо-середовищ (playground, інтеграційні sandboxes);  
- документаційного порталу (docs-сайт, туторіали, гайдлайни);  
- SDK / API-доків (code samples).

Фокус: conventions, не конкретна реалізація фронтенду.

---

## 1. Базові артефакти

### 1.1 Catalog & Index

Ключові файли з PD-014:

- `examples/catalog/examples-catalog.md` — людський опис EX-XXX;  
- `examples/catalog/examples-index.json` — машинний індекс;
- `examples/products/EX-XXX-...` — вихідні DSL-артефакти;  
- `examples/generated/json/EX-XXX-.../vX.Y.Z/*.json` — golden samples.

`examples-index.json` — єдиний вхід для demo/docs/SDK-шару (single index).

### 1.2 Структура examples-index.json (скелет)

```json
{
  "examples": [
    {
      "example_id": "EX-001-vien-geist-city-guide",
      "product_id": "PRD-EX-001-VIEN-GEIST",
      "name": "vien.geist – Vienna city gastro guide",
      "category": "city_guide",
      "vertical": "travel_fnb",
      "primary_stack": ["TJM", "Trutta", "LEM"],
      "complexity": "high",
      "risk_level": "medium",
      "status": "public_template",
      "current_version": "1.0.0",
      "paths": {
        "product_source": "examples/products/EX-001-vien-geist-city-guide/product.yml",
        "samples_root": "examples/generated/json/EX-001-vien-geist-city-guide/",
        "docs_notes": "examples/products/EX-001-vien-geist-city-guide/notes.md"
      }
    }
  ]
}
```

Цей індекс використовується всюди як точка входу.

---

## 2. Підключення до демо-середовищ

### 2.1 Типи демо-середовищ

- **Authoring Playground** — UI для редагування ProductDef/профілів на базі EX-XXX.  
- **Runtime Demo** — pre-configured середовища з TJM/Trutta/LEM sandbox, де продукти можна "прокрутити" end-to-end.  
- **Integration Sandbox** — середовище для SDK/інтеграторів (API-кейси).

### 2.2 Конфігураційний шар

Окремий файл, наприклад `examples/env-map.json`:

```json
{
  "envs": {
    "dev_demo": {
      "tjm_base_url": "https://tjm-dev-demo.example.com",
      "trutta_base_url": "https://trutta-dev-demo.example.com",
      "lem_base_url": "https://lem-dev-demo.example.com"
    },
    "public_demo": {
      "tjm_base_url": "https://tjm-public-demo.example.com",
      "trutta_base_url": "https://trutta-public-demo.example.com",
      "lem_base_url": "https://lem-public-demo.example.com"
    }
  },
  "examples": {
    "EX-001-vien-geist-city-guide": ["dev_demo", "public_demo"],
    "EX-004-kidney-mpt-city-trip": ["dev_demo"]
  }
}
```

Сенс:

- прив’язати кожен EX-XXX до дозволених демо-env (з урахуванням `risk_level`/`status`);  
- для кожного env — знати базові URL стеків.

### 2.3 Потік у Authoring Playground

1. UI запитує `examples-index.json`.  
2. Користувач обирає приклад (фільтр по category/vertical/stack).  
3. UI завантажує:
   - або `product_source` (YAML) для редагування;  
   - або `productdef.base.json` з `examples/generated/json/...` для read-only.
4. Зміни можна зберегти як локальний варіант (не впливаючи на golden samples).

### 2.4 Потік у Runtime Demo

1. Користувач обирає EX-XXX у демо-UI.  
2. Додаток читає mapping з `env-map.json` → визначає, чи доступний приклад у цьому env.  
3. Для дозволених прикладів UI показує кнопки типу "Run journey", "Simulate claim".  
4. Під капотом UI використовує:
   - `registry.snapshot.json` для перевірки конфігів;  
   - відповідні TJM/Trutta/LEM endpoints у sandbox env’і.

### 2.5 Обмеження доступу

- `status: internal` / `risk_level: high|critical` → тільки dev_demo/internal env.  
- `status: public_template` + `risk_level: low|medium` → можуть бути показані в public_demo.  
- Governance (PD-013) визначає правила фільтрації.

---

## 3. Підключення до документаційного порталу

### 3.1 Конвенції лінків

Кожен EX-XXX має canonical docs-URL, наприклад:

```text
/docs/examples/EX-001-vien-geist-city-guide
/docs/examples/EX-002-vienna-city-pass
```

У тексті: "див. приклад **EX-002-vienna-city-pass**" → завжди посилання на відповідну сторінку.

### 3.2 Docs-компоненти

Для MDX/док-порталу вводяться стандартні компоненти, наприклад:

```jsx
<ExampleCard id="EX-002-vienna-city-pass" />
<ExampleCode id="EX-002-vienna-city-pass" view="productdef.base" />
<ExampleCode id="EX-002-vienna-city-pass" view="profiles.merged" />
```

У build-час:

- `ExampleCard` читає `examples-index.json` + `notes.md`;  
- `ExampleCode` читає golden sample з `examples/generated/json/...` і рендерить код-блок.

### 3.3 Автоматичний індекс у доках

Docs-генератор може будувати сторінку "Examples Library" автоматично:

- читає `examples-index.json`;  
- групує EX-XXX по `category`, `vertical`, `primary_stack`;  
- фільтрує по `status` (наприклад, на публічному сайті не показувати `internal`).

### 3.4 Синхронізація з версіями

- Документація на версію X.Y DSL працює з відповідною гілкою репо;  
- `examples-index.json` на цій гілці відповідає стану DSL;  
- docs-сайт завжди лінкує на семпли з тієї ж гілки (semver alignment).

---

## 4. SDK / API Docs

### 4.1 Code samples з golden samples

SDK-доки можуть використовувати ту саму базу:

- для запитів/відповідей Registry API — шматки з `registry.snapshot.json`;  
- для прикладів ProductDef у клієнтських бібліотеках — `productdef.base.json`.

Приклад шаблону (псевдо):

```yaml
# openapi-extension
x-examples:
  vienna_city_pass:
    externalValue: examples/generated/json/EX-002-vienna-city-pass/v1.0.0/productdef.base.json
```

### 4.2 Генерація мовних прикладів

Generator може брати JSON й робити:

- TypeScript, Python, Go snippets з тим самим payload.  
- Це гарантує, що всі SDK-доки використовують один і той самий "ground truth".

---

## 5. CI-зв’язки

### 5.1 Перевірка доків проти бібліотеки

Окремий CI-джоб:

1. Парсить docs (MD/MDX) і витягує всі `EX-XXX` references.  
2. Валідуює, що кожен `EX-XXX` існує в `examples-index.json`.  
3. Перевіряє, що для кожного вживаного `view` (base/full/profiles/registry) є відповідний файл.  
4. Фейлить білд, якщо є дрейф (биті лінки, відсутні семпли).

### 5.2 Перевірка демо-конфігів

Інший джоб перевіряє `env-map.json`:

- що всі `example_id` з env-map існують в `examples-index.json`;  
- що приклади з `status: internal` не потрапили в `public_demo`;
- що health/critical-кейси мають тільки dev/internal env.

---

## 6. Governance & Visibility Rules

- Правила видимості (`status`, `risk_level`) з PD-014+PD-013 застосовуються в трьох місцях:
  - демо-UI (фільтрація EX для користувача),  
  - docs-портал (що публічне, що тільки internal),  
  - SDK-доки (які приклади можна виносити назовні).

- Зміна `status` / `risk_level` EX-XXX в `examples-index.json` автоматично змінює:
  - набір прикладів у public_demo;  
  - набір прикладів на публічному docs-сайті;  
  - набір доступних external code samples.

---

## 7. Summary

- `examples-index.json` + golden samples (`examples/generated/json/...`) — єдиний шар правди для demo/docs/SDK.  
- Демо-середовища використовують EX-XXX як сценарії для authoring та runtime-плейграундів, з обмеженнями по env.  
- Документаційний портал та SDK-доки інкапсулюють EX-XXX через стандартні компоненти і посилання на golden samples.  
- CI гарантує, що посилання з доків/демо на EX-XXX завжди валідні й узгоджені з governance-правилами.

