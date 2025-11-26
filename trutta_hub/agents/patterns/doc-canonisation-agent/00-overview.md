# Doc Canonisation Agent — Overview

**Name:** `doc-canonisation-agent`  
**Repo:** `reis-ri6/Trutta_frames-A-c-` (Trutta Hub)

---

## 1. Purpose

`doc-canonisation-agent` — другий шар пайплайну документації.

Він:

- бере вхід з `ingestion/ingestion-index.yaml`:
  - файли з `decision = promote_candidate`;
- зіставляє їх із canonical-артефактами:
  - `PD`, `VG`, `CONCEPT`, `DOMAIN`, `TEMPLATE`;
- створює або оновлює canonical-документи у:
  - `docs/`, `concepts/`, `domains/`, `templates/`;
- підтримує індекси:
  - `progress/artefacts/artefact-index.yaml`;
  - `progress/artefacts/docs-status.yaml`.

Коротко: перетворює «кандидатів» з ingestion на формалізовані, відстежувані артефакти.

---

## 2. Scope

### Read

Агент має право читати:

- `ingestion/ingestion-index.yaml` — список файлів і рішень ingestion-шару;
- `docs/` — існуючі PD/VG/guides/policies;
- `concepts/` — концепти (TJM, ABC, токенізація тощо);
- `domains/` — доменні моделі;
- `templates/` — темплейти проектів/архітектур/дизайну;
- `progress/artefacts/artefact-index.yaml` — індекс canonical-артефактів;
- `progress/artefacts/docs-status.yaml` — статуси артефактів.

### Write

Має право писати:

- **нові / оновлені canonical-документи**:
  - у `docs/`, `concepts/`, `domains/`, `templates/`;
- **індекси та статуси**:
  - `progress/artefacts/artefact-index.yaml`;
  - `progress/artefacts/docs-status.yaml`.

---

## 3. Guardrails

Агент **не має права змінювати**:

- `ingestion/` — індекс та трансформації ingestion-шару;
- `infra/`, `tools/`, `config/` — інфраструктура та утиліти;
- `monitoring/` — метрики, алерти;
- `import/` — сирі матеріали;
- будь-які інші файли поза переліченими у scope write.

Принципи:

- **Не видаляє** canonical-файли;
- **Не затирає** зміст без явного мапінгу:
  - якщо не може безпечно оновити — ставить `status=conflict` і додає нотатку;
- будь-яка зміна повинна бути диф-направленою (зрозумілою людям через git diff).

---

## 4. Main responsibilities

1. **Відбір кандидатів**
   - з `ingestion-index.yaml` обирає всі записи з:
     - `decision = "promote_candidate"`.

2. **Визначення типу артефакту**
   - на основі шляху, назви файла та контенту вирішує:
     - `type = pd | vg | concept | domain | template | other`.

3. **Призначення `artefact id`**
   - якщо `linked_artefact_id` вже є — використовує його;
   - інакше:
     - пропонує новий `id` (`PD-***`, `VG-***`, `CONCEPT-*`, `DOMAIN-*`, `TEMPLATE-*`);
     - обирає canonical-шлях під нього (наприклад, `docs/pd/PD-010-....md`).

4. **Оновлення індексу артефактів**
   - додає або оновлює записи в `artefact-index.yaml`:
     - `id`, `type`, `path`, `title`, `scope`, `domains`, `concepts`, `status`, `source`, `tags`.

5. **Оновлення статусів**
   - у `docs-status.yaml`:
     - створює/оновлює entries для відповідних `id`;
     - виставляє `status` і `readiness_score`;
     - оновлює `last_agent_update`, `last_agent_id`.

6. **Робота з canonical-файлами**
   - якщо файл ще не існує:
     - створює його за шаблоном відповідного типу (PD/VG/CONCEPT/DOMAIN/TEMPLATE);
   - якщо існує:
     - акуратно вливає новий контент у відповідні секції;
     - не видаляє важливі частини без явних сигналів;
     - у разі сумнівів → не змінює файл, ставить `status=conflict`.

---

## 5. Conflict handling

Агент вважає ситуацію конфліктною, якщо:

- різні кандидати претендують на один і той самий `artefact id` / `path` із несумісним змістом;
- новий кандидат явно суперечить уже canonical-версії (інша бізнес-логіка, правила, моделі).

У такому випадку:

1. Не змінює canonical-файл.
2. Оновлює `docs-status.yaml`:
   - `status: conflict` для відповідного `id`;
   - додає `notes` з описом проблеми:
     - джерельні `path`,
     - короткий опис розбіжностей.
3. Опційно може створити допоміжний diff/звіт (як окремий `.md` у `progress/`), якщо це дозволено конфігом.

Розвʼязання конфлікту покладається на людей (product/arch/data/legal).

---

## 6. Relation to other layers

- Працює **після**:
  - `repo-ingestion-agent` (який заповнює `ingestion-index.yaml`).
- Готує матеріал для:
  - інших агентів (data-raids, macro-агентські структури),
  - людей, які працюють із canonical-доками.

Док-пайплайн описаний у:
- `agents/systems/doc-pipeline/doc-pipeline.system.yaml`.

---

## 7. Config & prompts

- Маніфест:
  - `agents/patterns/doc-canonisation-agent/doc-canonisation.agent.yaml`
- Системний промпт:
  - `agents/patterns/doc-canonisation-agent/doc-canonisation.prompt.md`

У маніфесті зафіксовано:
- які директорії читаються;
- куди агент має право писати;
- посилання на `artefact-index.yaml` і `docs-status.yaml`.

У промпті:
- покроковий алгоритм роботи;
- правила для створення/оновлення canonical-файлів;
- політика поведінки в кейсах невизначеності та конфлікту.
