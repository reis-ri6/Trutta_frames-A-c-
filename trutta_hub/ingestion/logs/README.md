# Ingestion Logs

Ця директорія містить журнали запусків `repo-ingestion-agent`.

Мета логів:
- мати просту історію прогонів ingestion;
- бачити, скільки файлів оброблено, які рішення приймались;
- швидко виявляти аномалії (різкі стрибки `promote_candidate`, падіння, помилки).

---

## 1. Структура файлів логів

Кожен запуск створює **окремий** файл:

- формат імені:  
  `ingestion-YYYYMMDD-HHMM.md` (UTC або зафіксована таймзона).

Приклад:

- `ingestion-20251125-0930.md`
- `ingestion-20251125-1805.md`

---

## 2. Мінімальний вміст логу

```md
# Ingestion run — 2025-11-25T09:30:00Z

## Summary
- repo: reis-ri6/Trutta_frames-A-c-
- agent: repo-ingestion-agent
- index_file: ingestion/ingestion-index.yaml

## Files
- processed: 123
- new_entries: 15
- updated_entries: 40

## Decisions
- ignore: 10
- archive: 80
- compress_clean: 20
- promote_candidate: 13

## Notes
- короткі коментарі про нетипові ситуації:
  - "found legacy pitch deck -> compress_clean"
  - "new Sospeso mint example -> promote_candidate (linked_artefact_id=TEMPLATE-SOSPESO)"
```

Вимоги:

* один лог = один запуск агента;
* якщо запуск не завершився (помилка) — це також фіксується в Notes.

---

## 3. Хто має право писати в `logs/`

* тільки `repo-ingestion-agent` або людина вручну;
* інші агенти **не** створюють файлів у `ingestion/logs/`.

---

## 4. Використання логів

* для людини:

  * зрозуміти, коли востаннє оновлювався `ingestion-index.yaml`;
  * побачити тренди по `decision`;
  * відловити надлишковий `promote_candidate` або занадто агресивний `archive`.

* для інших агентів:

  * опційно читати останній лог, щоб розуміти, чи є сенс запускати ingestion ще раз (але не змінювати його).
