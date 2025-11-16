# PD-012 CI Templates (GitHub Actions, Pre-commit, Validation Configs) v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Platform Architecture

**Related docs:**  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-cli-command-reference.md  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-links.md  
- PD-003-registry-and-versioning-spec.md

Мета — дати **готові темплейти CI-шарів** навколо Product DSL / Registry:

- GitHub Actions workflow-и для PR, main/staging, release/production, preview-env;  
- pre-commit конфіг для локальної розробки;  
- базові конфіги лінтерів/валідації, які використовуються разом із `pdsl` CLI.

---

## 1. Передумови

### 1.1 Припущення щодо репо

- Репозиторій: `product-dsl` (може бути окремим або директорією в монорепо).  
- Структура: див. PD-011 (core/schemas, products, policies, cities).  
- CLI `pdsl` доступний як:
  - або попередньо зібраний binary (release),  
  - або npm/go/bazel-пакет (адаптувати install step).

### 1.2 Secrets & env

У GitHub / CI налаштовані секрети:

- `PDSL_REGISTRY_DEV_TOKEN`  
- `PDSL_REGISTRY_STG_TOKEN`  
- `PDSL_REGISTRY_PROD_TOKEN`

та, за потреби, окремі `*_URL` (якщо не зашито в `.pdsl.config.yaml`).


---

## 2. GitHub Actions: PR Validation Workflow

Файл: `.github/workflows/pdsl-pr.yml`

```yaml
name: Product DSL – PR Validation

on:
  pull_request:
    branches: [ main, develop ]
    paths:
      - 'products/**'
      - 'policies/**'
      - 'cities/**'
      - 'core/schemas/**'
      - '.pdsl.config.yaml'
      - 'pdsl/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  pdsl-pr-validate:
    name: Lint / Validate / Diff
    runs-on: ubuntu-latest

    concurrency:
      group: pdsl-pr-${{ github.event.pull_request.number }}
      cancel-in-progress: true

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      # TODO: замінити на фактичний спосіб встановлення CLI
      - name: Install pdsl CLI
        uses: ./.github/actions/install-pdsl

      - name: Lint changed files
        run: |
          pdsl lint --changed-only --format text

      - name: Semantic validate changed files
        run: |
          pdsl validate --changed-only --format json

      - name: Generate diff vs main
        run: |
          pdsl diff \
            --from-ref origin/main \
            --to-ref HEAD \
            --format markdown > pdsl-diff.md

      - name: Upload diff as artifact
        uses: actions/upload-artifact@v4
        with:
          name: pdsl-diff
          path: pdsl-diff.md

      - name: Comment diff to PR (optional)
        if: ${{ github.event_name == 'pull_request' }}
        uses: marocchino/sticky-pull-request-comment@v2
        with:
          path: pdsl-diff.md
```

**Рекомендації:**

- Зробити цей workflow **required check** у GitHub branch protection для `main`.  
- На рівні governance (PD-013) визначити, що merge без green `pdsl-pr-validate` заборонений.

---

## 3. GitHub Actions: Main → Staging Publish Workflow

Файл: `.github/workflows/pdsl-main-staging.yml`

```yaml
name: Product DSL – Main → Staging

on:
  push:
    branches: [ main ]
    paths:
      - 'products/**'
      - 'policies/**'
      - 'cities/**'
      - 'core/schemas/**'
      - '.pdsl.config.yaml'

permissions:
  contents: read

jobs:
  pdsl-main-staging:
    name: Lint / Validate / Publish to Staging
    runs-on: ubuntu-latest

    concurrency:
      group: pdsl-main-staging
      cancel-in-progress: true

    env:
      PDSL_REGISTRY_STG_TOKEN: ${{ secrets.PDSL_REGISTRY_STG_TOKEN }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install pdsl CLI
        uses: ./.github/actions/install-pdsl

      - name: Lint full repo
        run: |
          pdsl lint --all --format text

      - name: Semantic validate full repo
        run: |
          pdsl validate --all --env staging --strict --format json

      - name: Create staging snapshot
        run: |
          pdsl snapshot create \
            --env staging \
            --output snapshot-stg.json

      - name: Publish to staging
        run: |
          pdsl publish \
            --env staging \
            --snapshot snapshot-stg.json \
            --yes

      - name: Upload snapshot as artifact
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-stg
          path: snapshot-stg.json
```

**Зауваги:**

- Публікація в `staging` може бути повністю автоматичною для більшості змін.  
- Для high-risk змін governance (PD-013) може вимагати ручний gate перед публікацією в prod, але staging лишається auto.

---

## 4. GitHub Actions: Release / Production Publish Workflow

Файл: `.github/workflows/pdsl-release-prod.yml`

Варіант 1 — реліз із тега `v*`.

```yaml
name: Product DSL – Release → Production

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read
  deployments: write

jobs:
  pdsl-release-prod:
    name: Release → Production (Manual Gate)
    runs-on: ubuntu-latest

    concurrency:
      group: pdsl-release-prod
      cancel-in-progress: true

    environment:
      name: production
      url: https://registry-prod.example.com

    env:
      PDSL_REGISTRY_PROD_TOKEN: ${{ secrets.PDSL_REGISTRY_PROD_TOKEN }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install pdsl CLI
        uses: ./.github/actions/install-pdsl

      - name: Lint full repo
        run: |
          pdsl lint --all --format text

      - name: Semantic validate full repo (strict)
        run: |
          pdsl validate --all --env production --strict --format json

      - name: Create production snapshot
        run: |
          pdsl snapshot create \
            --env production \
            --ref ${{ github.ref }} \
            --output snapshot-prod.json

      - name: Upload snapshot artifact
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-prod
          path: snapshot-prod.json

      - name: Wait for manual approval
        uses: chrnorm/deployment-action@v2
        with:
          environment: production
          description: 'Approve Product DSL publish to production'

      - name: Publish to production
        run: |
          pdsl publish \
            --env production \
            --snapshot snapshot-prod.json \
            --yes
```

**Ключові моменти:**

- Використовується GitHub Environments (`environment: production`) з manual approval.  
- Publish в `production` можливий **тільки з CI** (через secrets), локально має бути заблоковано ролями.

---

## 5. GitHub Actions: Preview Environments (опційно)

Файл: `.github/workflows/pdsl-preview.yml`

```yaml
name: Product DSL – Preview Snapshot

on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [ main, develop ]

permissions:
  contents: read

jobs:
  pdsl-preview:
    name: Generate Preview Snapshot
    runs-on: ubuntu-latest

    concurrency:
      group: pdsl-preview-${{ github.event.pull_request.number }}
      cancel-in-progress: true

    env:
      PDSL_REGISTRY_STG_TOKEN: ${{ secrets.PDSL_REGISTRY_STG_TOKEN }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install pdsl CLI
        uses: ./.github/actions/install-pdsl

      - name: Create preview snapshot
        run: |
          pdsl snapshot create \
            --env preview \
            --output snapshot-preview.json

      - name: Publish preview snapshot (namespace per PR)
        run: |
          # Припускається, що Registry підтримує preview namespace (наприклад, preview_<PR-ID>)
          export PDSL_PREVIEW_NAMESPACE="preview_${{ github.event.pull_request.number }}"
          pdsl publish \
            --env preview \
            --snapshot snapshot-preview.json \
            --yes

      - name: Upload preview snapshot
        uses: actions/upload-artifact@v4
        with:
          name: snapshot-preview
          path: snapshot-preview.json
```

Фронтенд / TJM / Trutta / LEM можуть підхоплювати цей preview namespace для інтеграційного тестування конкретного PR.

---

## 6. Reusable Action: Install `pdsl` CLI

Для уникнення дубляжу варто зробити локальний composite action.

Файл: `.github/actions/install-pdsl/action.yml`

```yaml
name: Install pdsl CLI

inputs:
  version:
    description: 'pdsl version'
    required: false
    default: 'latest'

runs:
  using: composite
  steps:
    - name: Download pdsl binary
      shell: bash
      run: |
        VERSION="${{ inputs.version }}"
        # TODO: замінити URL на реальний release storage
        if [ "$VERSION" = "latest" ]; then
          VERSION="v0.1.0"  # fallback
        fi
        echo "Installing pdsl $VERSION"
        curl -sSL "https://example.com/pdsl/releases/$VERSION/pdsl-linux-amd64" -o /usr/local/bin/pdsl
        chmod +x /usr/local/bin/pdsl

    - name: Verify pdsl
      shell: bash
      run: |
        pdsl --version
```

У реальному проєкті URL замінюється на GitHub Releases, Artifactory або інший registry.

---

## 7. Pre-commit Config

Файл: `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: check-merge-conflict
      - id: end-of-file-fixer
      - id: trailing-whitespace

  - repo: https://github.com/adrienverge/yamllint
    rev: v1.35.1
    hooks:
      - id: yamllint
        files: '\.(yml|yaml)$'

  # Опційно: форматування markdown/json
  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0
    hooks:
      - id: prettier
        files: '\.(md|json|yml|yaml)$'

  # Локальний хук для pdsl lint/validate
  - repo: local
    hooks:
      - id: pdsl-lint
        name: pdsl lint (changed files)
        entry: pdsl
        args: ["lint", "--changed-only"]
        language: system
        pass_filenames: false

      - id: pdsl-validate
        name: pdsl validate (for affected products)
        entry: pdsl
        args: ["validate", "--all"]
        language: system
        pass_filenames: false
```

**Заувага:**

- pre-commit має встановлюватися як dev-dependency в документації репо.  
- На практиці можна розбити `pdsl-validate` на менш важкий (наприклад, за шляхами) для швидкості локальної роботи.

---

## 8. Lint / Validation Configs

### 8.1 `.pdsl.config.yaml` (нагадування)

Орієнтовна структура (див. PD-012-tooling-cli-and-ci-spec):

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
  severity_threshold: warning
```

### 8.2 `.yamllint.yaml` (мінімальний приклад)

```yaml
extends: default

rules:
  line-length:
    max: 120
    level: warning
  truthy:
    level: warning
```

### 8.3 `.markdownlint.yaml` (опційно)

```yaml
default: true

MD013:  # line length
  line_length: 120
  code_block_line_length: 150

MD033: false  # allow inline HTML
```

---

## 9. Branch Protection & Required Checks

Рекомендований мінімум для `main` (або основної DSL-гілки):

- Обов’язкові статуси:
  - `Product DSL – PR Validation` (pdsl-pr.yml)  
- Required reviews від CODEOWNERS (узгоджено з PD-013).  
- Заборонений прямий push (тільки через PR).

Для тегів / релізів:

- `Product DSL – Release → Production` має бути зеленим перед тим, як реліз вважається валідним.

---

## 10. Summary

Цей документ дає **готовий стартовий набір CI-шаблонів** для:

- валідації будь-яких змін у Product DSL (PR workflow);  
- автоматичної публікації в staging при змінах у main;  
- контрольованої публікації у production через release-теги та manual gate;  
- опційних preview середовищ per PR;  
- pre-commit хуків, які тримають DSL у валідному стані ще до пушу.

Усі темплейти треба адаптувати під конкретну інфраструктуру (URL-и Registry, спосіб інсталяції CLI, назви secrets), але загальна форма відповідає вимогам PD-012 та PD-011.

