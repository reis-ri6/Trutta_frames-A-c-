# PD-012 CLI Command Reference v0.1

**Status:** Draft 0.1  
**Owner:** DevEx / Platform Architecture

**Related docs:**  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-links.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-api.yaml

Цей документ є **референсом по CLI `pdsl`**. Див. PD-012-tooling-cli-and-ci-spec.md для концептів та принципів.

---

## 0. Конвенції

- `pdsl` — виконуваний файл CLI.  
- `[...]` — опціональні параметри.  
- `|` — варіанти (один із).  
- `UPPER_SNAKE_CASE` — значення, що треба підставити.

За замовчуванням CLI працює з поточною директорією як коренем репо DSL.

---

## 1. Глобальний синтаксис

```bash
pdsl [GLOBAL OPTIONS] <command> [subcommand] [OPTIONS] [ARGS]
```

### 1.1 Global options

```text
--config <path>        # Шлях до .pdsl.config.yaml (якщо не в root)
--env <env>           # dev|staging|production|preview-*, дефолт: dev
--log-level <level>   # trace|debug|info|warn|error, дефолт: info
--no-color            # Вимкнути кольоровий вивід
--json                # Форсувати JSON вивід (де підтримується)
--help, -h            # Допомога по CLI або окремій команді
--version, -V         # Версія CLI
```

Приклад:

```bash
pdsl --env staging --log-level debug lint --changed-only
```

---

## 2. Огляд команд

| Команда        | Опис                                           |
|----------------|------------------------------------------------|
| `lint`         | Схемна/структурна валідація DSL-файлів        |
| `validate`     | Розширена семантична валідація                |
| `diff`         | Порівняння станів DSL/Registry                |
| `snapshot`     | Створення/інспекція snapshot’ів портфелю      |
| `publish`      | Публікація snapshot’у в Registry              |
| `inspect`      | Читання стану Registry                        |
| `doctor`       | Діагностика конфігів/оточення                 |
| `plugins`      | Управління плагінами (опційно)                |

Далі — детально по кожній команді.

---

## 3. `pdsl lint`

Базова схемна та структурна валідація DSL.

### 3.1 Synopsis

```bash
pdsl lint [--all | --changed-only | --paths <glob,...>] \
          [--format text|json] \
          [--severity-threshold error|warning] \
          [--ignore <rule-id,...>]
```

### 3.2 Options

- `--all` — лінтити весь репозиторій.  
- `--changed-only` — лінтити тільки змінені файли (за git diff проти main або origin/main).  
- `--paths` — явний список шляхів/глобів (`products/PRD-*/**/*.yaml`).  
- `--format` — `text` (людино-читаємий) або `json` (для CI/скриптів).  
- `--severity-threshold` — мінімальний рівень, який веде до non-zero exit code (наприклад, `warning` або `error`).  
- `--ignore` — список rule-id, які слід ігнорувати (для тимчасових обходів, небажано).

### 3.3 Exit codes

- `0` — без помилок вище `severity-threshold`.  
- `1` — знайдені порушення (lint errors/warnings згідно порогу).  
- `2` — системна помилка (I/O, некоректний конфіг і т.д.).

### 3.4 Приклади

```bash
# Лінтити тільки змінені файли (рекомендовано для локальної роботи)
pdsl lint --changed-only

# Повна перевірка репо з JSON-виводом
pdsl lint --all --format json > lint-report.json
```

---

## 4. `pdsl validate`

Розширена семантична валідація + звірка з Registry (якщо задано `--env`).

### 4.1 Synopsis

```bash
pdsl validate [--all | --paths <glob,...>] \
              [--env dev|staging|production] \
              [--format text|json] \
              [--strict]
```

### 4.2 Options

- `--all` / `--paths` — так само, як у `lint`.  
- `--env` — якщо задано, валідатор додатково звіряє DSL з поточним станом Registry в цьому env.  
- `--format` — `text` або `json`.  
- `--strict` — перевести деякі warnings у errors (наприклад, підозрілі breaking changes).

### 4.3 Що перевіряє

- перехресні посилання (продукт ↔ профілі ↔ markets ↔ policies);  
- дублюючі ID / конфлікти версій;  
- несумісні зміни згідно PD-003 (major/minor/breaking);  
- неконсистентні числові діапазони (ціни, пороги, SLO тощо).

### 4.4 Приклади

```bash
# Семантична валідація змінених файлів
pdsl validate --paths "products/PRD-VIEN-COFFEE-PASS/**" --format text

# Строга валідація проти staging Registry
pdsl validate --all --env staging --strict --format json
```

---

## 5. `pdsl diff`

Порівняння двох станів: git↔git, git↔snapshot, git↔Registry, snapshot↔Registry.

### 5.1 Synopsis

```bash
pdsl diff \
  [--from-ref <git-ref> | --from-snapshot <file>] \
  [--to-ref <git-ref> | --to-snapshot <file> | --to-registry <env>] \
  [--product-id <PRD-ID>] \
  [--market <MARKET-CODE>] \
  [--only-breaking] \
  [--format text|markdown|json]
```

### 5.2 Options

- `--from-ref` / `--to-ref` — git refs (branch, tag, commit).  
- `--from-snapshot` / `--to-snapshot` — файли snapshot (див. `pdsl snapshot`).  
- `--to-registry` — порівняти DSL (з from-ref) із станом Registry у вказаному env.  
- `--product-id` — обмежити diff конкретним продуктом.  
- `--market` — обмежити diff конкретним ринком.  
- `--only-breaking` — показати тільки потенційно breaking changes.  
- `--format` — `text` (клієнт), `markdown` (для PR-коментарів), `json` (для автоматизації).

### 5.3 Приклади

```bash
# Diff HEAD проти main, markdown для PR
pdsl diff --from-ref origin/main --to-ref HEAD --format markdown > pdsl-diff.md

# Перевірити дрейф між git(main) та staging Registry
pdsl diff --from-ref main --to-registry staging --format text

# Подивитись тільки breaking changes по конкретному продукту
pdsl diff --from-ref v1.0.0 --to-ref v2.0.0 \
  --product-id PRD-KIDNEY-MPT --only-breaking --format json
```

---

## 6. `pdsl snapshot`

Керує логічними snapshot’ами портфелю.

### 6.1 Subcommands

```bash
pdsl snapshot create --env <env> [--output <file>] [--ref <git-ref>]
pdsl snapshot inspect --file <file> [--format text|json]
```

### 6.2 `snapshot create`

**Options:**

- `--env` — target env для snapshot (`dev|staging|production|preview`).  
- `--output` — шлях до файлу snapshot (JSON). Якщо не задано — stdout.  
- `--ref` — git ref, з якого читати DSL (дефолт — поточний HEAD).

**Вміст snapshot’у** (узагальнено):

- список продуктів, версій, профілів, політик;  
- metadata: git commit, дата, env, автор.

Приклади:

```bash
# Snapshot для staging з поточного HEAD
pdsl snapshot create --env staging --output snapshot-stg.json

# Snapshot для production з тега релізу
pdsl snapshot create --env production --ref v1.5.0 --output snapshot-prod.json
```

### 6.3 `snapshot inspect`

Перегляд snapshot’у без публікації.

```bash
pdsl snapshot inspect --file snapshot-stg.json --format text
```

---

## 7. `pdsl publish`

Публікує snapshot до Registry.

### 7.1 Synopsis

```bash
pdsl publish \
  --env dev|staging|production \
  [--snapshot <file>] \
  [--dry-run] \
  [--force] \
  [--yes]
```

### 7.2 Options

- `--env` — цільове середовище Registry.  
- `--snapshot` — вхідний snapshot; якщо не задано, CLI створить його сам (`snapshot create`).  
- `--dry-run` — тільки diff проти Registry, без запису.  
- `--force` — дозволяє певні операції, заблоковані за замовчуванням (тільки для dev/preview, не для prod).  
- `--yes` — автоматично підтверджувати prompt’и (обов’язково для CI).

### 7.3 Поведінка

1. Читає snapshot (або генерує).  
2. Обчислює diff проти поточного стану Registry.  
3. Виводить summary змін.  
4. Якщо не `--dry-run` — застосовує зміни (idempotent upsert + migration records).  
5. Логує publish-івент із metadata (commit, env, snapshot-id).

### 7.4 Приклади

```bash
# Локальна перевірка diff без оновлення Registry
pdsl publish --env staging --dry-run

# CI-крок: публікація staging snapshot з автоматичним підтвердженням
pdsl publish --env staging --snapshot snapshot-stg.json --yes

# Заборонений патерн (публікація в production локально) — має бути відрізаний правами
pdsl publish --env production
```

---

## 8. `pdsl inspect`

Читання стану Registry через CLI (тільки read-only).

### 8.1 Subcommands

```bash
pdsl inspect product --id <PRD-ID> [--env <env>] [--format text|json]
pdsl inspect version --product-id <PRD-ID> [--env <env>] [--format text|json]
pdsl inspect profile --id <PROFILE-ID> [--env <env>] [--format text|json]
pdsl inspect policy --id <POLICY-ID> [--env <env>] [--format text|json]
```

### 8.2 Приклади

```bash
# Подивитись продукт у staging Registry
pdsl inspect product --id PRD-VIEN-COFFEE-PASS --env staging --format text

# Список версій продукту в production
pdsl inspect version --product-id PRD-KIDNEY-MPT --env production --format json

# Перевірити конкретну ops-політику
pdsl inspect policy --id OPS-POL-SAFETY-VIE --env production
```

---

## 9. `pdsl doctor`

Діагностика середовища та конфігів.

### 9.1 Synopsis

```bash
pdsl doctor [--env dev|staging|production] [--format text|json]
```

### 9.2 Що перевіряє

- наявність і валідність `.pdsl.config.yaml`;  
- доступ до Registry (ping + auth);  
- відповідність версій CLI та Registry (протокол);  
- попередження щодо відсутніх/застарілих схем.

### 9.3 Приклад

```bash
pdsl doctor --env staging
```

---

## 10. `pdsl plugins`

Опційний набір команд для управління плагінами.

### 10.1 Subcommands

```bash
pdsl plugins list
pdsl plugins info <name>
pdsl plugins enable <name>
pdsl plugins disable <name>
```

- Фактичне завантаження плагінів описується в `.pdsl.plugins.yaml`.  
- CLI показує, які плагіни активні, та їхні hook’и.

### 10.2 Приклад

```bash
pdsl plugins list
pdsl plugins info health-constraints
```

---

## 11. Exit codes (загальні правила)

- `0` — успіх.
- `1` — бізнес-помилки / validation errors / diff з порушеннями правил.
- `2` — конфігураційні/системні помилки (I/O, network, некоректний config).  
- `>2` — зарезервовано для специфічних сценаріїв (наприклад, несумісна версія CLI vs Registry).

CI має трактувати `1` як очікуваний fail (проблема в DSL), `2+` — як інфраструктурний інцидент.

---

## 12. Типові сценарії використання

### 12.1 Локальна робота автора

```bash
# Перед комітом
git status
pdsl lint --changed-only
pdsl validate --paths "products/PRD-XXX/**" --format text
```

### 12.2 PR pipeline (CI)

```bash
pdsl lint --changed-only --format text
pdsl validate --changed-only --format json
pdsl diff --from-ref origin/main --to-ref HEAD --format markdown > pdsl-diff.md
```

### 12.3 Публікація в staging (CI main)

```bash
pdsl snapshot create --env staging --output snapshot-stg.json
pdsl publish --env staging --snapshot snapshot-stg.json --yes
```

### 12.4 Публікація в production (manual gate)

```bash
# Крок генерує snapshot\ npdsl snapshot create --env production --output snapshot-prod.json
# Після ручного approve\ npdsl publish --env production --snapshot snapshot-prod.json --yes
```

### 12.5 Дебаг дрейфу

```bash
pdsl diff --from-ref main --to-registry staging --format text
```

---

## 13. Summary

Цей референс фіксує **фактичний контракт CLI `pdsl`**:

- синтаксис, параметри та коди виходу для всіх ключових команд;  
- рекомендовані патерни використання локально й у CI/CD;  
- чіткий поділ: `lint/validate/diff` для перевірки, `snapshot/publish` для змін, `inspect/doctor` для читання/діагностики.

Будь-які зміни в CLI (нові команди, флаги, semantics) мають оновлювати як цей референс, так і PD-012-tooling-cli-and-ci-spec.md.

