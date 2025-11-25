# Ingestion Layer (`ingestion/`)

Ingestion-шар — це передканонічний індекс усіх файлів репозиторію.  
Тут працює `repo-ingestion-agent`: він сканує репо, класифікує файли, рахує скоринги й записує результат у `ingestion-index.yaml`.  
Canonical-документи тут **не живуть** — тільки метадані й логи.

---

## 1. Призначення

Ingestion-шар відповідає за:

- **повний список файлів** репозиторію;
- **класифікацію** (`kind`, `subtype`);
- **оцінку**:
  - `relevance_score` — наскільки файл про Trutta/TJM/ABC/домени;
  - `novelty_score` — чи не дубль це;
  - `actuality_score` — наскільки сучасний стек/факти;
- **рішення**:
  - `ignore` | `archive` | `compress_clean` | `promote_candidate`;
- створення:
  - `*.clean.md`, `*.summary.md` — очищені/стислі версії маркетингових текстів;
- підготовку даних для `doc-canonisation-agent`.

Ingestion **нічого не вирішує про канон** — він тільки готує сигнал.

---

## 2. Структура директорії

- `ingestion-index.yaml`  
  Головний індекс усіх файлів (machine-readable).

- `rules.md`  
  Правила класифікації (`kind/subtype`) та вибору `decision`.

- `transforms/`  
  Специфікації перетворень, які виконують агенти:
  - `marketing-cleaning.md` — як із маркетингу робити структурований `.clean.md` + `.summary.md`;
  - `code-classification.md` — як визначати `subtype` і `decision` для коду.

- `logs/`  
  Логи прогонів ingestion-агента:
  - `ingestion-YYYYMMDD-HHMM.md` — стислий підсумок кожного запуску.

---

## 3. Контракт `ingestion-index.yaml`

Файл — валідний YAML з полями:

```yaml
version: 1
updated_at: "<ISO8601>"

files:
  - path: "relative/path/to/file.ext"
    kind: "doc|code|data|media|other"
    subtype: "marketing|spec|note|legal|snippet|script|template|infra|test|..." 
    size_bytes: <int>
    created_at: "<ISO8601>|null"
    detected_language: "en|uk|..."
    relevance_score: <0.0–1.0>
    novelty_score:   <0.0–1.0>
    actuality_score: <0.0–1.0>
    decision: "ignore|archive|compress_clean|promote_candidate"
    linked_artefact_id: "PD-001|VG-500|CONCEPT-TJM|TEMPLATE-SOSPESO|null"
    clean_output_paths: ["path/to/file.clean.md", "path/to/file.summary.md"]
    last_ingestion_run: "<ISO8601>"
```

Вимоги:

* **Одна** записи на файл (`path` унікальний).
* `decision` обирається консервативно:

  * сумнів → краще `archive`, ніж `promote_candidate`.
* `linked_artefact_id` заповнюється тільки коли це очевидно (і є запис у `artefact-index.yaml`).

Редагувати `ingestion-index.yaml` має право **тільки** `repo-ingestion-agent` (або людина руками, але не інші агенти).

---

## 4. Роль `repo-ingestion-agent`

Основні дії агента:

1. Прочитати:

   * `ingestion/rules.md`;
   * `ingestion/transforms/*`;
   * поточний `ingestion-index.yaml`.
2. Побудувати список файлів репо (без `.git`, `node_modules`, `dist`, бінарних артефактів).
3. Для кожного файла:

   * визначити `kind`, `subtype`;
   * порахувати `relevance_score`, `novelty_score`, `actuality_score`;
   * обрати `decision`;
   * при потребі — `linked_artefact_id`.
4. Оновити `ingestion-index.yaml`:

   * додати нові файли;
   * оновити записи для змінених файлів.
5. Для `doc/marketing` із `decision=compress_clean`:

   * створити `*.clean.md` і `*.summary.md`;
   * записати шляхи в `clean_output_paths`.
6. Записати лог прогону в `ingestion/logs/`.

Шлях до маніфеста й промпта агента:

* `agents/patterns/repo-ingestion-agent/repo-ingestion.agent.yaml`
* `agents/patterns/repo-ingestion-agent/repo-ingestion.prompt.md`

---

## 5. Хто ще читає ingestion-шар

* `doc-canonisation-agent`:

  * читає `ingestion/ingestion-index.yaml`;
  * використовує `decision=promote_candidate` та `linked_artefact_id` як сигнал для створення/оновлення canonical-артефактів.

* Інші агенти (data-raids / data-conveyors):

  * можуть використовувати `ingestion-index.yaml` як карту репозиторію, але **не змінюють** його.

---

## 6. Обмеження для агентів

* Писати можна **тільки**:

  * `ingestion/ingestion-index.yaml`;
  * `ingestion/logs/*`;
  * `*.clean.md`, `*.summary.md` біля вхідних файлів.
* Заборонено:

  * редагувати canonical-директорії;
  * видаляти записи з індексу без реального видалення файла з репо;
  * вигадувати дані про PII/health; усе таке маркується як доменні/абстрактні моделі, а не індивідуальні кейси.

Ingestion — це шар «що в нас є і наскільки це релевантне/живе». Усі рішення про канон/структуру поверх цього шару приймає наступний етап пайплайну.
