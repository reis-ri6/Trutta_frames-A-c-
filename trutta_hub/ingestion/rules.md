# Ingestion Rules

Цей документ визначає правила роботи `repo-ingestion-agent`:
- як класифікувати файли (`kind`, `subtype`),
- які рішення (`decision`) приймати,
- які поля потрібно заповнювати в `ingestion/ingestion-index.yaml`.

## 1. Таксономія файлів
- **doc/marketing** — пітчі, презентації, тексти для сайту, прес-релізи.
- **doc/narrative** — довгі описи продукту, процесів, маніфести.
- **doc/spec** — специфікації, RFC, архітектурні нотатки.
- **doc/note** — чернетки, особисті нотатки, фріформ.
- **data/sample** — семпли YAML/JSON/CSV без коду.
- **code/snippet** — дрібні фрагменти коду, що вимагають класифікації.
- **code/project** — повні модулі/пакети/скрипти.
- **config/infra** — terraform/k8s/docker, інфраструктурні конфіги.
- **config/app** — налаштування застосунків, CLI, шаблони.

## 2. Оцінки (0..1)
- **relevance_score** — наскільки файл відповідає Trutta Hub (0 = сторонній шум, 1 = ядро).
- **novelty_score** — чи містить нову інформацію щодо вже існуючих матеріалів.
- **actuality_score** — наскільки файл актуальний/несвіжий (1 = свіже, 0 = застаріле).

Швидкі евристики:
- Маркетинг із датою < 2023 → actuality 0.3–0.5.
- Код із посиланням на чинні модулі → relevance 0.8–1.0.
- Чернетки без контексту → relevance 0.2–0.5, novelty 0.2–0.4.

## 3. Decision matrix
- **ignore** — службові файли, бінарні артефакти, `.gitkeep`, індекси.
- **archive** — неактуальні або дубльовані чернетки/замітки.
- **compress_clean** — маркетингові тексти для стиснення та виділення фактів.
- **promote_candidate** — код, специфікації, конфіги, що потенційно йдуть у канон.

## 4. linked_artefact_id
- Заповнюй, якщо файл явно належить до артефакту (наприклад, `TEMPLATE-SOSPESO`, `PD-001`).
- Якщо немає явного відповідника — залишай `null`.

## 5. Поля запису
Кожен запис у `files:` має вигляд:
```yaml
- path: "path/from/repo/root"
  kind: "doc|code|data|config"
  subtype: "marketing|narrative|spec|note|sample|snippet|project|infra|app"
  size_bytes: <int>
  created_at: "<ISO8601>"          # якщо недоступно — залишити порожнім
  detected_language: "uk|en|..."   # для тексту/коду
  relevance_score: 0.0
  novelty_score: 0.0
  actuality_score: 0.0
  decision: "ignore|archive|compress_clean|promote_candidate"
  linked_artefact_id: null
  last_ingestion_run: "<ISO8601>"
```

## 6. Виключення зі сканування
Не індексуй:
- `.git/`, `node_modules/`, `dist/`, `build/`, тимчасові/бінарні файли,
- згенеровані `.clean.md` та `.summary.md` (щоб не дублювати).

## 7. Логи
Кожен прогін пише короткий звіт у `ingestion/logs/ingestion-<label>-YYYYMMDD-HHMM.md`:
- кількість знайдених файлів;
- розподіл по decision (`archive`, `compress_clean`, `promote_candidate`);
- помітні винятки.
