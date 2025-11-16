# PD-012 Tooling: CLI & CI Spec v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Platform Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-api.yaml  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-links.md  
- PD-011-product-authoring-templates.md  
- PD-013-governance-and-compliance-spec.md

Мета — описати **інструментарій навколо Product DSL / Registry**:

- дизайн CLI як єдиного офіційного інтерфейсу між git-репозиторієм DSL та Registry;  
- набір обов’язкових команд CLI (lint, validate, diff, snapshot, publish, inspect);  
- інтеграцію CLI з CI/CD пайплайнами (PR, main/release, preview envs);
- базові нефункціональні вимоги: швидкість, ідемпотентність, безпека.

---

## 1. Design Principles

1. **Single source of truth**  
   Все, що стосується продуктів/профілів/політик, живе у git (Product DSL). Registry синхронізується тільки через CLI.

2. **CLI-first**  
   Ніяких ручних змін у Registry/БД. Усе йде через CLI-команди, які можна запускати локально та в CI.

3. **Idempotent & deterministic**  
   Повторний запуск тієї самої операції (в межах одного snapshot) дає той самий результат.

4. **Fail-fast, safe-by-default**  
   Будь-яка невизначеність = помилка, а не silent збіг. Publish у prod без lint/validate/diff заборонений.

5. **Environment-aware**  
   CLI чітко розділяє `dev / staging / production / preview-*` середовища.

6. **Extensible**  
   Можливість додавати кастомні чекери, плагіни, інтеграції (наприклад, специфічні правила для health-продуктів).

---

## 2. CLI Overview

### 2.1 Binary & invocation

- Робоча назва CLI: `pdsl` (Product DSL).  
- Використання: `pdsl <command> [subcommand] [flags]`.

CLI працює з:

- файловою структурою репозиторію DSL (див. PD-011);  
- конфігом `.pdsl.config.yaml` у root;  
- Registry API (PD-003-registry-api.yaml) — лише через HTTPS, з auth-токенами.

### 2.2 Config

Файл `.pdsl.config.yaml` (або змінні оточення) задає:

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

repo:
  root: .
  products_dir: products
  policies_dir: policies
  cities_dir: cities

validation:
  schema_dir: core/schemas
  severity_threshold: warning   # мін. рівень, який фейлить lint
```

Секрети (tokens) **ніколи не зберігаються** в конфігу, тільки через env.

---

## 3. Command Set

### 3.1 `pdsl lint`

**Призначення:** швидка перевірка синтаксису/схем/базових інваріантів.

**Синтаксис:**

```bash
pdsl lint [--all | --changed-only | --paths <glob,...>] [--format text|json]
```

**Поведение:**

- Парсить YAML/JSON у DSL-репо.  
- Валідуює проти JSON/YAML схем (PD-001/PD-002/PD-007/PD-009/PD-010).  
- Базові інваріанти: унікальність ID, валідні типи профілів, presence обов’язкових полів.

**Exit codes:**

- `0` — success;  
- `1` — validation errors;  
- `2` — internal error/config issue.

### 3.2 `pdsl validate`

**Призначення:** розширена семантична валідація.

```bash
pdsl validate [--all | --paths <glob,...>] [--env dev|staging|production] [--format text|json]
```

Додатково до `lint`:

- звіряє DSL з поточним станом Registry (якщо вказано `--env`);  
- перевіряє перехресні посилання (product ↔ профілі ↔ markets ↔ policies);  
- попереджає про potential breaking changes (згідно PD-003 versioning rules).

### 3.3 `pdsl diff`

**Призначення:** порівняння двох станів DSL або DSL ↔ Registry.

```bash
pdsl diff \
  [--from-ref <git-ref>|--from-snapshot <file>] \
  [--to-ref <git-ref>|--to-snapshot <file>|--to-registry <env>] \
  [--format text|markdown|json]
```

**Приклади:**

- `pdsl diff --from-ref main --to-ref HEAD --format markdown` — для PR.  
- `pdsl diff --from-ref v1.0.0 --to-ref v1.1.0` — для релізу.  
- `pdsl diff --from-ref main --to-registry staging` — виявити дрейф між git і Registry.

Результат — summary по:

- доданих/змінених/видалених продуктах/версіях/профілях/політиках;  
- виявлених breaking changes.

### 3.4 `pdsl snapshot`

**Призначення:** зібрати консистентний snapshot DSL для конкретного environment/сценарію.

```bash
pdsl snapshot create \
  --env dev|staging|production|preview \
  [--output snapshot.json]

pdsl snapshot inspect --file snapshot.json
```

Snapshot містить:

- нормалізований список продуктів/версій/профілів/політик;  
- метадані (git commit, дата, автор, target env).  

Snapshot — основний input для `pdsl publish`.

### 3.5 `pdsl publish`

**Призначення:** публікація snapshot в Registry.

```bash
pdsl publish \
  --env dev|staging|production \
  [--snapshot snapshot.json] \
  [--dry-run] [--force]
```

Поведение:

- Без `--snapshot` автоматично викликає `snapshot create`.  
- Робить diff проти поточного стану Registry;  
- Показує summary змін і просить підтвердження (локально) або логить у CI.

`--dry-run` — тільки diff, без запису.  
`--force` — дозволяє деякі операції, які зазвичай блокуються (наприклад, у dev).

Ідемпотентність: повторний `publish` з тим самим snapshot не змінює Registry.

### 3.6 `pdsl inspect`

**Призначення:** читання стану Registry через CLI.

```bash
pdsl inspect product --id PRD-... --env staging
pdsl inspect version --product-id PRD-... --env production
pdsl inspect policy --id OPS-POL-... --env production
```

Використовується для дебагу та sanity-checkів, але **не** для модифікації.

### 3.7 `pdsl doctor`

**Призначення:** діагностика конфігів та середовища.

- Перевірка доступу до Registry;  
- Перевірка версій схем;  
- Попередження про несумісні версії CLI vs Registry.

---

## 4. CI Integration Patterns

### 4.1 PR pipeline

Для кожного PR у репозиторії DSL:

1. **Lint & validate**

```bash
pdsl lint --changed-only --format text
pdsl validate --changed-only --format json
```

2. **Diff report**

```bash
pdsl diff --from-ref origin/main --to-ref HEAD --format markdown > pdsl-diff.md
```

- Файл `pdsl-diff.md` публікується як артефакт або коментар до PR.

3. **Optional preview snapshot**

- Для великих або high-risk змін:  

```bash
pdsl snapshot create --env staging --output snapshot-preview.json
```

- Може бути використаний для розгортання тимчасового preview Registry namespace.

CI-пайплайн відмічається як **required** у репозиторії. PR не можна мерджити при помилках lint/validate.

### 4.2 Main / Release pipeline

При merge в `main` або релізну гілку:

1. Повторна валідація (`lint + validate`) для захисту main.  
2. Створення snapshot’у для `staging`:

```bash
pdsl snapshot create --env staging --output snapshot-stg.json
pdsl publish --env staging --snapshot snapshot-stg.json
```

3. Для `production` можливі два варіанти:

- **Auto-promote (low/medium risk):**

```bash
pdsl snapshot create --env production --output snapshot-prod.json
pdsl publish --env production --snapshot snapshot-prod.json
```

- **Manual gate (high/critical risk):**
  - CI зупиняється після генерації snapshot’у;  
  - відповідальні (Ops/SAFE/FIN) підтверджують deployment через manual approval step;  
  - після approve — `pdsl publish --env production`.

4. Оновлення release manifest / changelog (частково автоматизовано):

- генерація JSON manifest (див. PD-011-product-authoring-templates);  
- апдейт `CHANGELOG.md` через скрипт або напівручний крок.

### 4.3 Preview environments

Для великих фіч/продуктів:

- окремий CI-джоб створює snapshot `--env preview` з тегом `preview/<PR-ID>`;  
- Registry підтримує окремий namespace `preview_<PR-ID>`;  
- TJM/Trutta/LEM можуть піднімати окремі стейдж-оточення, які читають саме цей namespace.

Після закриття PR preview-namespace очищається.

---

## 5. Multi-repo / Monorepo Integration

### 5.1 Варіант 1: окремий DSL-репо

- `product-dsl/` як самостійний репозиторій.  
- CI в ньому робить lint/validate/diff/snapshot/publish.  
- Інші сервіси (TJM/Trutta/LEM) просто споживають Registry.

Плюси: чіткий separation of concerns, простіші права доступу.  
Мінуси: окремі пайплайни, більше координації.

### 5.2 Варіант 2: монорепо

- DSL живе в `apps/` або `config/` частині монорепо з кодом.  
- `pdsl` використовується тільки в DSL-пайплайнах (по шляху).  
- Потрібне акуратне кешування залежностей у CI.

### 5.3 Крос-репо зв’язки

У будь-якому варіанті:

- PR у кодових репо **не можуть** напряму змінювати Registry;  
- зміни в поведінці runtime, які потребують нових продуктів/профілів, мають посилатися на відповідні PR у DSL-репо.

---

## 6. Extensibility & Plugins

CLI має підтримувати плагіни/розширення:

- custom validators (наприклад, для health-продуктів: додаткові дієтичні/медичні обмеження);  
- інтеграції з сторонніми системами (Notion, JIRA, Confluence) для auto-linking;  
- генерацію документації (markdown/HTML) з ProductDef/профілів.

Пропонується простий плагін-API:

- конфіг `.pdsl.plugins.yaml` із переліком плагінів;  
- кожен плагін експортує набір hook’ів: `before_lint`, `after_lint`, `before_publish`, `after_publish` тощо;  
- плагіни можуть лише читати дані snapshot/DSL, модифікації — через чітко задокументовані API.

---

## 7. Security & Compliance

1. **Secrets**  
   - Registry tokens, API-ключі та інші секрети — тільки в CI secrets / env vars;  
   - CLI не логує токени;  
   - підтримка masked logging для будь-яких чутливих значень.

2. **Access control**  
   - різні токени/ролі для `dev/staging/production`;  
   - публікація в production можлива тільки з CI-сервісів, не з локальних машин.

3. **Audit**  
   - кожен `publish` логиться в Registry з:
     - git commit SHA;  
     - author (CI user + PR author);  
     - snapshot ID;  
     - diff summary.  
   - логи зберігаються мінімум N років (див. PD-013).

4. **Compliance**  
   - можливість експорту повного стану продуктового портфелю на дату (regulator/audit request) через `pdsl snapshot` + Registry.

---

## 8. Non-functional Requirements

- **Performance:**  
  - `pdsl lint --changed-only` для типового PR має працювати < 10 c;  
  - full-repo lint/validate — < 1–2 хвилин для портфелю до ~1000 продуктів.

- **Stability:**  
  - Backward-compatible CLI протягом мінімум одного major-циклу;  
  - deprecation policy для команд/флагів.

- **Observability:**  
  - метрики запусків CLI в CI (успіхи/фейли, час виконання);  
  - алерти при частих фейлах lint/validate/publish.

---

## 9. Summary

- `pdsl` CLI — обов’язковий прошарок між git-DSL та Registry, який забезпечує валідацію, diff, snapshot та publish.  
- CI-пайплайни PR/main/release будуються навколо `pdsl` і блокують merge/релізи при порушенні правил.  
- Registry отримує тільки затверджені snapshot’и, немає ручних правок.  
- Плагінна модель дозволяє еволюцію перевірок без поломки базового флоу.  
- Безпека та audit закладені у дизайн: tokens тільки в env, повний слід publish-операцій, чітке розділення env’ів.

