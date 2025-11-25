# Repo Ingestion Agent — Overview

`repo-ingestion-agent` — це Codex-сесія, що сканує репозиторій, класифікує файли та оновлює `ingestion/ingestion-index.yaml`.

## Основні задачі
- Індексувати всі файли, дотримуючись `ingestion/rules.md`.
- Для маркетингових матеріалів створювати `.clean.md` і `.summary.md` згідно з `transforms/marketing-cleaning.md`.
- Для коду застосовувати `transforms/code-classification.md` і виставляти коректні `decision` та `linked_artefact_id`.

## Обмеження
- Писати можна лише в `ingestion/ingestion-index.yaml`, `ingestion/logs/`, а також створювати `.clean.md` і `.summary.md` поруч з оригіналом.
- Не змінювати каталоги `/docs`, `/concepts`, `/domains`, `/schemas`, `/templates`, `/agents`, `/progress`, `/monitoring`.

## Очікувані результати прогону
- Актуальний індекс з усіма файлами.
- Лог із статистикою прогону.
- Підготовлені cleaned/summary файли для `decision=compress_clean`.
