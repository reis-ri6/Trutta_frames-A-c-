# Trutta Hub

Trutta Hub — канонічний репозиторій документації, схем і темплейтів для всієї екосистеми Trutta (TJM, ABC, токенізація сервісів, доменні моделі, агенти).

Репозиторій побудований так, щоб:
- люди бачили зрозумілу структуру продукту й даних;
- AI-агенти (Codex, repo-ingestion-agent, doc-canonisation-agent) могли безпечно читати, класифікувати й підтримувати артефакти.

---

## 1. Призначення

Trutta Hub використовується для:

- зберігання **canonical**-документації:
  - PD (Product Design), VG (Guides), концепти, домени;
- опису **даних**:
  - схеми БД, події, векторні й графові рівні;
- зберігання **темплейтів**:
  - проектів (Sospeso, BREAD, Vienna Guide), архітектур, UI/UX;
- конфігурації й промптів для **AI-агентів**:
  - ingestion, канонізація, data-raids, data-conveyors.

Будь-який новий проєкт поверх Trutta стартує з цього репозиторію як джерела правди.

---

## 2. Структура репозиторію (top-level)

- `/docs` — продуктова й операційна документація (PD, VG, guides, policies).
- `/concepts` — концепти та фреймворки (TJM, ABC, Trutta tokenization тощо).
- `/domains` — індустріальні домени (tourism, hospitality, services, food, health).
- `/schemas` — фізичні схеми даних (DB, events, vector, graph).
- `/templates` — темплейти:
  - проектів,
  - дизайну,
  - архітектур.
- `/agents` — агенти та агентські системи:
  - patterns (single agents),
  - systems (conveyors/data-raids/macro-teams),
  - templates (шаблони опису агентів/систем).
- `/import` — сирі матеріали для інгесту:
  - `raw/`, `legacy/`, `unknown/`.
- `/ingestion` — правила, індекс та трансформації для `repo-ingestion-agent`.
- `/progress` — статуси артефактів, roadmap, workflows, інтеграції.
- `/monitoring` — метрики, алерти, журнали подій.
- `/infra`, `/tools`, `/config`, `/samples`, `/tests` — інфраструктура, утиліти, приклади.

Деталі по кожній директорії див. у відповідних `README.md`/індексах всередині.

---

## 3. Ролі користувачів

Основні ролі, для яких структуровано репозиторій:

- **Product / архітектори**:
  - працюють з `/docs/pd`, `/docs/vg`, `/concepts`, `/templates/projects`.
- **Data / аналітики**:
  - `/domains`, `/schemas`, `/samples`, `/docs/vg-analytics`.
- **Engineering / DevOps**:
  - `/infra`, `/tools`, `/schemas/db`, `/agents`.
- **AI-ops / prompt engineers**:
  - `/agents/patterns`, `/agents/systems`, `/ingestion`, `/progress`.

AI-агенти розглядаються як повноцінні «користувачі» з чіткими guardrails (див. `ai-guardrails.md`).

---

## 4. Швидкий старт (люди)

1. **Клонувати репо**:
   ```bash
   git clone git@github.com:reis-ri6/Trutta_frames-A-c-.git
   ```
2. Прочитати:

   * `docs/guides/getting-started-trutta.md` — вступ у Trutta.
   * `ai-guardrails.md` — правила для роботи з агентами.
3. Обрати темплейт проекту:

   * `templates/projects/sospeso/`,
   * `templates/projects/bread/`,
   * `templates/projects/vienna-guide/`.
4. Налаштувати інфру:

   * `templates/architecture/infra-supabase-postgres/`,
   * `infra/`, `config/`.

---

## 5. Швидкий старт (AI / Codex)

### 5.1. Ingestion

* Основний агент: `agents/patterns/repo-ingestion-agent/*`.
* Контекст:

  * `ingestion/README.md` — опис ingestion-шару.
  * `ingestion/rules.md` — правила класифікації/скорингу.
  * `ingestion/transforms/*` — опис трансформацій.
* Вихід:

  * `ingestion/ingestion-index.yaml` — індекс усіх файлів репо.

Типовий сценарій:

1. Завантажити системний промпт з
   `agents/patterns/repo-ingestion-agent/repo-ingestion.prompt.md`.
2. Запустити ingestion по всьому репо або по конкретному каталогу (`import/raw/...`).

### 5.2. Canonicalisation (doc pipeline)

* Агент: `agents/patterns/doc-canonisation-agent/*`.
* Система: `agents/systems/doc-pipeline/doc-pipeline.system.yaml`.
* Вхід:

  * `ingestion/ingestion-index.yaml`.
* Вихід:

  * оновлені:

    * `progress/artefacts/artefact-index.yaml`,
    * `progress/artefacts/docs-status.yaml`,
  * створені/оновлені canonical-файли у `docs/`, `concepts/`, `domains/`, `templates/`.

---

## 6. Інтеграція зі старими репозиторіями

* Поточний вихідний репозиторій: `reis-ri6/Trutta_frames-A-c-`.
* Mapping важливих PD/VG/концептів у нову структуру:

  * `progress/integrations/trutta_frames-mapping.yaml`.

Цей файл використовується людьми й/або агентами для поетапної міграції артефактів у canonical-шар Trutta Hub.

---

## 7. Політики та безпека

* Загальні правила для AI-агентів:

  * `ai-guardrails.md`
* Безпека та репорт вразливостей:

  * `SECURITY.md`
* Політика щодо PII/health/FDA даних — у відповідних policy-документах у `docs/policies/` та `domains/health/*`.

---

## 8. Контакти

* Responsible: *to be defined*
* Issues / tasks: GitHub Issues у цьому репозиторії.
