# PD-014 Generated Samples JSON – Catalog & Conventions v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Platform / QA

**Related docs:**  
- PD-014-examples-and-templates-library.md  
- PD-015-testing-and-conformance-suite.md  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-012-tooling-cli-and-ci-spec.md

Мета документа — формалізувати **каталог із реально згенерованими ProductDef JSON/YAML прикладами**, який використовується як:

- «золотий стандарт» (golden samples) для schema/semantic/integration тестів (PD-015);  
- джерело прикладів для документації, UI-демо, SDK;  
- референтний шар для сумісності версій DSL/Registry.

---

## 1. Структура каталогу

### 1.1 Фізична структура

Рекомендований layout у репозиторії:

```text
examples/
  generated/
    json/
      EX-001-vien-geist-city-guide/
        v1.0.0/
          productdef.base.json
          productdef.full.json
          profiles.merged.json
          registry.snapshot.json
        v1.1.0/
          ...
      EX-002-vienna-city-pass/
        v1.0.0/
          ...
      EX-003-spa-weekend-budapest/
        ...
    yaml/                      # опційно, якщо потрібно
      EX-001-vien-geist-city-guide/
        v1.0.0/
          productdef.base.yaml
```

Особливості:

- один каталог на **example_id** (`EX-XXX-slug`);  
- усередині — підкаталоги за **версіями продукту** (`vX.Y.Z`);  
- для кожної версії — фіксований набір файлів (див. нижче).

### 1.2 Типи файлів

Мінімальний набір для `vX.Y.Z`:

- `productdef.base.json` — «базовий» ProductDef без розгортання посилань;  
- `productdef.full.json` — повністю розгорнутий ProductDef (усі профілі / посилання inline);  
- `profiles.merged.json` — злитий view усіх профілів, які застосовуються до продукту/ринку;  
- `registry.snapshot.json` — фрагмент snapshot’у Registry, що стосується даного продукту.

Опційні файли:

- `events.example-sequences.json` — приклади подій runtime для цього продукту;  
- `ops.expected-metrics.json` — очікувані базові метрики для e2e;
- `notes.generated.md` — auto-summary змін/структури.

---

## 2. Генерація семплів

### 2.1 Джерело правди

Семпли **ніколи не редагуються вручну**. Єдиним джерелом правди є:

- DSL-артефакти в `examples/products/EX-XXX-...` (product.yml, journeys.yml, profiles.yml);  
- Registry/схеми (PD-002/PD-003/PD-007/PD-009/PD-010).

### 2.2 CLI-команда

Генерація виконується через `pdsl`:

```bash
pdsl generate-samples \
  --example EX-001-vien-geist-city-guide \
  --output examples/generated/json/EX-001-vien-geist-city-guide \
  --version 1.0.0
```

Рекомендовані параметри:

- `--format json|yaml` — формат виходу;  
- `--include` — які view генерувати (`base`, `full`, `profiles`, `registry`);  
- `--env` — для якого env будувати registry snapshot (dev/staging/prod-like).

### 2.3 Деталізація трансформацій

`productdef.base.json`:

- пряме перетворення ProductDef з YAML у JSON;  
- посилання (`*_profile_ref`) залишаються як є.

`productdef.full.json`:

- всі references (`*_profile_ref`, journeys) розгорнуті до inline-структур;  
- додаються derived-поля (наприклад, precomputed tags/indices), якщо такі передбачені в PD-002.

`profiles.merged.json`:

- злиття відповідних профілів за правилами PD-007/PD-009/PD-010 (precedence, overrides);  
- view «що бачить runtime» для конкретного продукту/ринку.

`registry.snapshot.json`:

- частковий export згідно з PD-003 (тільки записи, пов’язані з product_id / example_id);  
- може містити додатковий metadata-блок про env та версію Registry.

---

## 3. Naming & Versioning

### 3.1 Версія продукту

Кожен каталог `vX.Y.Z` відповідає **версії продукту** з ProductDef (`version: "X.Y.Z"`).

Правила:

- зміна ProductDef → оновлення версії;  
- семпли завжди генеруються **після** успішного lint/validate;  
- для кожної версії семпли мають бути детермінованими (Hash залежить тільки від DSL + схем).

### 3.2 Версія схем / Registry

Рекомендується додавати у файли верхній блок metadata:

```json
{
  "_meta": {
    "generated_by": "pdsl 0.2.0",
    "generated_at": "2025-01-01T12:34:56Z",
    "schema_version": "productdef:1.3.0, profiles:1.1.0",
    "registry_version": "1.4.0",
    "example_id": "EX-001-vien-geist-city-guide",
    "product_version": "1.0.0"
  },
  "product": { /* ... */ }
}
```

### 3.3 Hashing

Для контрольної цілісності:

- обчислюється hash (наприклад, SHA-256) для кожного файлу;  
- хеші записуються в окремий маніфест:

```json
{
  "example_id": "EX-001-vien-geist-city-guide",
  "product_version": "1.0.0",
  "files": {
    "productdef.base.json": "sha256:...",
    "productdef.full.json": "sha256:...",
    "profiles.merged.json": "sha256:...",
    "registry.snapshot.json": "sha256:..."
  }
}
```

Маніфест може зберігатися як `manifest.json` у каталозі версії.

---

## 4. Використання семплів

### 4.1 Тести (PD-015)

- **Schema tests** працюють по `productdef.base.json` як золотому стандарту;  
- **Semantic tests** можуть використовувати `productdef.full.json` та `profiles.merged.json` для перевірки інваріантів;  
- **Integration/e2e tests** — використовують `registry.snapshot.json` як очікуваний стан Registry для продукту.

### 4.2 Документація / SDK

- Документація може посилатися на конкретні файли, наприклад:  
  `examples/generated/json/EX-002-vienna-city-pass/v1.0.0/productdef.base.json` як готовий sample для SDK;  
- SDK-генератори можуть брати структури з semver-мічених семплів для побудови типів/клієнтів.

### 4.3 Diff & Regression

При зміні DSL/схем:

- `pdsl generate-samples --all` оновлює семпли;  
- окремий CI job рахує diff старих/нових семплів (структурний, не тільки текстовий);  
- будь-які несподівані зміни (наприклад, зниклі поля, змінені типи) сигналять про потенційні breaking changes.

---

## 5. Правила безпеки та комплаєнсу

- Семпли **не повинні містити PII** чи реальних конфіденційних даних (контакти, договори, real booking IDs);  
- Усі реальні назви вендорів/локацій або узагальнені, або використовуються тільки за згодою й у публічних прикладах;  
- Для health/financial сценаріїв (типу `EX-004-kidney-mpt-city-trip`) семпли використовуються лише з позначкою `internal` / `restricted` і ніколи не публікуються без review SEC/SAFE.

---

## 6. CI-пайплайн для семплів

Рекомендований job (може бути частиною PD-012-ci-templates):

1. Запустити `pdsl lint/validate` для всіх examples.  
2. Запустити `pdsl generate-samples --changed-only` для EX-XXX з модифікованими DSL-файлами.  
3. Оновити `examples/generated/json/...` і маніфести.  
4. Запустити regression-diff проти попереднього стану;  
5. Якщо diff ок — коміт/артефакти проходять, інакше — fail з детальним diff-репортом.

Можливий окремий nightly job для повної регенерації всіх семплів.

---

## 7. Summary

- `PD-014-generated-samples-json/` — це **стандартизований каталог golden samples**, синхронізований з бібліотекою прикладів (PD-014) та тест-сюїтами (PD-015).  
- Семпли генерує виключно `pdsl` через формалізовані команди, версіонуються по продукту та схемах, контролюються хешами та CI-diff’ами.  
- Вони слугують одночасно опорою для тестів, документації, SDK та сумісності версій DSL/Registry, без ризику витоку реальних даних.

