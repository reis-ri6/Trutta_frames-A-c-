# PD-012 Tooling Links – Registry, Schema-store, Test Environments v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Platform Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-api.yaml  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-links.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-cli-command-reference.md  
- PD-012-ci-templates.md

Мета цього документа — описати **зв’язки інструментів навколо Product DSL (`pdsl`, CI)** з:

- **Registry** (runtime-facing canonical store),  
- **Schema-store** (джерело правди для схем/контрактів DSL),  
- **тестовими середовищами** (local/dev, integration, staging, preview).

Це glue-док: де що живе, хто в кого що читає і які контракти.

---

## 1. Компоненти та ролі

### 1.1 Tooling

- **`pdsl` CLI** — єдиний інструмент для lint/validate/diff/snapshot/publish (див. PD-012).  
- **CI-пайплайни** — стандартизовані workflows GitHub Actions (PD-012-ci-templates), які викликають `pdsl`.

### 1.2 Registry

- **Product Registry Service** (PD-003):
  - API рівня `registry-api` (OpenAPI в PD-003-registry-api.yaml).  
  - окремі environment-и: `dev`, `staging`, `production`, `preview-*`.  
  - зберігає нормалізовані сутності: product/version/profile/policy/market-mapping/migration-log.

### 1.3 Schema-store

- Джерело правди для **схем DSL**:
  - JSON/YAML-схеми для ProductDef, профілів, фін/ops/safety/quality, policy-структур;  
  - окремі схеми для Registry API (якщо потрібно contract testing).  
- Фізично:
  - або директорія `core/schemas/` у тому ж репо (mono-store варіант);  
  - або окремий репозиторій/артефакт ("schema-store") з версіями.

### 1.4 Test environments

- **Local/dev** — локальний запуск `pdsl` + локальний Registry (docker) для інтеграційних тестів.  
- **Integration** — загальне dev-середовище, де TJM/Trutta/LEM читають із `dev` Registry.  
- **Staging** — наближений до prod стенд для pre-prod перевірок; основне місце для beta-rollout.  
- **Preview** — короткоживучі namespaces per PR (preview_<PR-ID>).  
- **Production** — бойове середовище, не використовується як test env.

---

## 2. Tooling ↔ Schema-store

### 2.1 Розташування схем

Базовий варіант (рекомендований для старту):

- усі схеми DSL живуть у **`core/schemas/`** того самого репо `product-dsl`;  
- `pdsl` за замовчуванням читає їх звідти (див. поле `validation.schema_dir` у `.pdsl.config.yaml`).

Альтернативний варіант (для більшої зрілості):

- схеми винесені в окремий `schema-store` (repo / артефакт),  
- `pdsl` або CI підтягують потрібну версію схем як dependency.

### 2.2 Версіонування схем

- Кожен тип схем має **semver-версію** (наприклад, `productdefSchemaVersion: 1.3.0`).  
- DSL-файли можуть явно посилатися на версію схеми через metadata-поле.

`pdsl lint/validate` повинні:

- перевіряти відповідність DSL заявленій версії схеми;  
- попереджати/фейлити, якщо використовується deprecated версія;  
- забезпечити backward compatibility по принаймні одному major-циклу.

### 2.3 Оновлення схем

Процес оновлення:

1. Зміни у схемі → PR у schema-store (або той самий repo).  
2. PR містить ADR (PD-011 templates) щодо причин змін + класифікацію breaking/non-breaking (узгоджено з PD-003).  
3. Після merge:
   - оновлена версія схем публікується (як тег/реліз schema-store або новий commit в `core/schemas/`);  
   - `pdsl`/CI оновлюють pinned версію (якщо використовують артефакти).

Tooling-правила:

- будь-яка зміна схем **має** пройти через той самий authoring/CI цикл, що й DSL;  
- оновлення схем без оновлення `pdsl` допускається тільки для backward-compatible змін (наприклад, розширення enum’ів).

### 2.4 Contract testing з Registry API

Опційно, schema-store може містити:

- JSON Schema/OpenAPI для Registry API (PD-003-registry-api.yaml);  
- contract-тести, які запускаються окремим CI job:
  - `registry-api` відповідає схемі;  
  - зміни в API позначені як minor/major і скоординовані з CLI-оновленнями.

---

## 3. Tooling ↔ Registry

### 3.1 Інтерфейс interaction

`pdsl` є **єдиним клієнтом**, який пише у Registry. Ключові операції:

- `pdsl validate --env <env>` — читає стан Registry для cross-check;  
- `pdsl diff --to-registry <env>` — порівнює git-стан із Registry;  
- `pdsl publish --env <env>` — застосовує snapshot → Registry.

Весь запис у Registry йде через
- REST API (`/products`, `/profiles`, `/markets`, `/policies`, `/migrations`, …),  
- або спеціалізований `bulk` endpoint, визначений у PD-003-registry-api.

### 3.2 Моделі даних

Функціональний контракт:

- `pdsl snapshot` генерує **портфельний snapshot** у форматі, максимально наближеному до Registry-моделей (PD-003).  
- Registry:
  - приймає snapshot,  
  - обчислює diff проти поточного стану,  
  - зберігає зміни як набір upsert/soft-delete операцій + migration records.

Ідемпотентність:

- publish того самого snapshot’у **не змінює** Registry;  
- підпис snapshot’у (hash) зберігається в migration-log.

### 3.3 Environment mapping

`.pdsl.config.yaml` задає:

```yaml
registry:
  dev:
    base_url: https://registry-dev.example.com
    token_env: PDSL_REGISTRY_DEV_TOKEN
  staging:
    base_url: https://registry-stg.example.com
    token_env: PDSL_REGISTRY_STG_TOKEN
  production:
    base_url: https://registry-prod.example.com
    token_env: PDSL_REGISTRY_PROD_TOKEN
```

- CLI **ніколи** не hardcode-ить URL-и/токени.  
- У production-публікації використовуються тільки CI-токени з обмеженими правами.

### 3.4 Drift detection

Рекомендований періодичний job (наприклад, nightly):

- `pdsl diff --from-ref main --to-registry staging`;  
- `pdsl diff --from-ref main --to-registry production` (тільки read-only).

Якщо diff ≠ 0 (поза відомими релізами) → сигнал інфраструктурній команді: хтось обійшов tooling або Registry в дрейфі.

---

## 4. Tooling ↔ Test Environments

### 4.1 Local/dev

Мінімальний цикл розробника:

- `pdsl lint --changed-only` локально;  
- `pdsl validate --paths ...` локально;  
- опційно — запуск локального Registry у docker з тестовою БД;  
- `pdsl publish --env dev` в локальний Registry (з локальним токеном/конфігом).

Local Registry не має ніякого доступу до staging/prod даних, працює із синтетичними/анонімізованими тест-датасетами.

### 4.2 Integration env

- **dev/integration** — перше середовище, де TJM/Trutta/LEM читають Registry.  
- CI може мати окремий job для інтеграційних тестів:
  - `pdsl publish --env dev` (dev Registry).  
  - запуск інтеграційних тестів TJM/Trutta/LEM проти цього env.  
- Ці тести мають бігати **до** staging/publish.

### 4.3 Staging

- Staging Registry — основний pre-prod рубіж.  
- `pdsl-main-staging.yml` автоматично публікує snapshot у staging після merge в `main`.  
- Інші сервіси (TJM, Trutta, LEM, frontend) мають стабільні staging-URL-и, які читають саме `staging` Registry.

На staging запускаються:

- smoke/регресійні тести;  
- продуктивні/навантажувальні тести;  
- beta-пілоти з обмеженими реальними користувачами.

### 4.4 Preview namespaces

- Для великих змін/нових продуктів: `pdsl-preview.yml` створює snapshot `--env preview` з namespace `preview_<PR-ID>`.  
- Registry має підтримувати логічні namespaces всередині env або окремий env `preview`.

Застосування:

- інтеграційні тести, що не зачіпають основний staging;  
- demo/UX-review нових продуктів без впливу на інших.

### 4.5 Production

Tooling-політика:

- локальні `pdsl publish --env production` заборонені (ACL на токенах + відсутність prod-токенів локально);  
- тільки CI з prod-secret’ами + manual gate.  

Будь-який publish у prod логиться з:

- env, snapshot-id, git-ref, автором (PR author + CI user).

---

## 5. Tooling ↔ Runtime Test Stacks (TJM / Trutta / LEM)

### 5.1 Контракт

- TJM/Trutta/LEM **ніколи не читають DSL напряму**.  
- Вони працюють тільки з Registry (і, за потреби, з TJM/Trutta/LEM-специфічними БД).

Tooling для e2e-тестів:

1. `pdsl snapshot/publish` готує тестовий стан продуктів у Registry (dev/staging/preview).  
2. Автоматизовані тест-сьюти для TJM/Trutta/LEM піднімають свій runtime проти відповідного env.  
3. Усі e2e тести визначені як частина **тестових ранбуків** відповідних продуктів (див. PD-015-testing-and-conformance-suite, коли він з’явиться).

### 5.2 Seed-дані та фікстури

- Для інтеграційних тестів рекомендується окремий набір **seed-сценаріїв**:
  - невеликий портфель продуктів (vien.geist, city-pass, kidney.mpt, тощо);  
  - мінімальні валідні профілі та політики;  
  - synthetic vendors/cities, щоб не світити реальні дані.

`pdsl` може мати окрему команду/плагін для генерації або завантаження таких seed-фікстур.

---

## 6. Сумісність версій Tooling ↔ Registry ↔ Schema-store

### 6.1 Version matrix

Рекомендується підтримувати **матрицю сумісності**:

- `pdsl` version (CLI)  
- schema-store version  
- registry API version

Ця матриця живе або в окремому doc, або як частина PD-016-roadmap.

### 6.2 Захист від несумісностей

- `pdsl doctor` перевіряє:
  - чи поточна версія CLI підтримується registry API;  
  - чи schema-store версія не новіша, ніж підтримує CLI.  
- Registry API може відхиляти publish від занадто старих CLI-версій.

### 6.3 Deprecation

- Deprecation для schema/CLI/API має бути узгоджена з PD-016-roadmap:  
  - попередження в lint/validate;  
  - дедлайни і плани міграцій;  
  - заборона певних deprecated-фіч після T0.

---

## 7. Security / Compliance boundaries

- Права доступу будуються **по середовищах**:
  - dev/staging tokens мають ширші можливості, але не містять реальних персональних даних;  
  - production-token має найжорсткіші обмеження й використовується тільки CI.  
- Schema-store може бути read-only для більшості ролей; write-доступ тільки через authoring-процес з ADR/PR.  
- Audit trail на публікації: кожен publish у Registry (будь-який env) має бути відтрасований до конкретного git commit/PR.

---

## 8. Summary

- Tooling (`pdsl` + CI) — єдиний місток між git-DSL, Registry, schema-store та тестовими середовищами.  
- Schema-store задає контракти для DSL/Registry, `pdsl` забезпечує enforce цих контрактів.
- Registry — runtime-facing store; усі сервіси (TJM/Trutta/LEM) працюють тільки з ним.  
- Test envs (local/dev/integration/staging/preview) будуються так, щоб повторювати production-патерни без ризику для прод-даних.  
- Сумісність версій tooling/registry/schema-store, дрейф-детекція та audit trail — обов’язкові умови для безпечної еволюції DSL/Registry.

