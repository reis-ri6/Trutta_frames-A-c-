# Repo Ingestion Agent — Overview

**Name:** `repo-ingestion-agent`  
**Repo:** `reis-ri6/Trutta_frames-A-c-` (Trutta Hub)

---

## 1. Purpose

`repo-ingestion-agent` — це агент першого шару, який:

- сканує весь репозиторій;
- класифікує файли:
  - `kind` (`doc | code | data | media | other`);
  - `subtype` (marketing/spec/note/template/infra/test/...);
- оцінює:
  - `relevance_score` — наскільки файл про Trutta/TJM/ABC/домени;
  - `novelty_score` — наскільки файл відрізняється від вже наявних;
  - `actuality_score` — наскільки стек/факти актуальні;
- виставляє `decision`:
  - `ignore | archive | compress_clean | promote_candidate`;
- створює очищені версії маркетингових текстів:
  - `*.clean.md`, `*.summary.md`;
- підтримує в актуальному стані:
  - `ingestion/ingestion-index.yaml`;
  - `ingestion/logs/*`.

Він **не приймає рішень про канон** і не змінює canonical-документи.

---

## 2. Scope

### Read

Агент має право **читати**:

- увесь репозиторій, крім технічних директорій:
  - `.git/`, `node_modules/`, `dist/`, `build/`, кеші тощо;
- спеціальні файли конфігурації:
  - `ingestion/rules.md`;
  - `ingestion/transforms/marketing-cleaning.md`;
  - `ingestion/transforms/code-classification.md`;
  - поточний `ingestion/ingestion-index.yaml`;
  - `progress/artefacts/artefact-index.yaml` (для `linked_artefact_id`).

### Write

Має право **писати тільки**:

- `ingestion/ingestion-index.yaml`;
- `ingestion/logs/ingestion-YYYYMMDD-HHMM.md`;
- `*.clean.md`, `*.summary.md` поруч з вихідними doc/marketing файлами.

---

## 3. Guardrails

Агент **не має права змінювати**:

- `docs/`
- `concepts/`
- `domains/`
- `schemas/`
- `templates/`
- `agents/`
- `infra/`
- `progress/`
- `monitoring/`

Будь-які зміни в цих директоріях допускаються тільки спеціалізованими агентами (типу `doc-canonisation-agent`) або руками.

---

## 4. Main outputs

1. `ingestion/ingestion-index.yaml`
   - список усіх файлів репозиторію з метаданими:
     - `kind`, `subtype`;
     - скоринги;
     - `decision`;
     - `linked_artefact_id`;
     - `clean_output_paths` (для маркетингових текстів).

2. `*.clean.md` / `*.summary.md`
   - структурована, обезводнена версія маркетингових текстів;
   - швидкий вхід для `doc-canonisation-agent` і людей.

3. `ingestion/logs/ingestion-YYYYMMDD-HHMM.md`
   - історія запусків:
     - скільки файлів оброблено;
     - розподіл по `decision`;
     - примітки про аномалії/edge-cases.

---

## 5. Relation to other agents

- Працює **до** `doc-canonisation-agent`:
  - готує йому сигнал: що взагалі є в репо, що варто розглядати як кандидата в канон.
- Не змінює артефакт-індекси напряму:
  - тільки читає `artefact-index.yaml`, щоб заповнювати `linked_artefact_id`, якщо це очевидно.
- Може бути викликаний:
  - вручну (batch run),
  - частиною системи `doc-pipeline` (`agents/systems/doc-pipeline/doc-pipeline.system.yaml`).

---

## 6. Config & prompts

- Маніфест агента:
  - `agents/patterns/repo-ingestion-agent/repo-ingestion.agent.yaml`
- Системний промпт:
  - `agents/patterns/repo-ingestion-agent/repo-ingestion.prompt.md`

Ці файли описують точні правила:
- які директорії читати;
- куди можна писати;
- як саме агент має поводитись під час запуску.
