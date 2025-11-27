# PD-010 — Trutta Repositories & Documentation Conventions

**ID:** PD-010  
**Назва:** Trutta Repositories & Documentation Conventions  
**Статус:** draft  
**Власники:** arch, eng, product, docs  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- PD-008 — Trutta Agent & Automation Layer  
- PD-009 — Trutta City & Project Instantiation Model  
- VG-8xx — Engineering & Runtime Guides  
- VG-9xx — Analytics & Telemetry

---

## 1. Purpose

Цей документ фіксує **єдині конвенції для репозиторіїв Trutta**:

- які є типи репозиторіїв (hub, city, project, runtime/service);
- як мають виглядати:
  - структура директорій;
  - назви файлів;
  - індекси та статуси артефактів;
- як цим користуються:
  - люди (архітектори, продакти, деви),
  - агенти/Codex (ingestion, canonisation, pipelines).

Мета — щоб будь-який агент або інженер, відкривши репо Trutta, **одразу розумів, де що лежить і який це рівень правди**.

---

## 2. Scope

### 2.1. Входить

- логічні типи репозиторіїв;
- конвенції директорій і файлів;
- індекси артефактів та статуси;
- базові правила для Codex/агентів.

### 2.2. Не входить

- конкретні CI/CD pipelines (VG-8xx);
- внутрішній код сервісів (окремі service-repos);
- політики безпеки/секретів (піде в окремий PD/VG).

---

## 3. Repository types

### 3.1. Hub repo

- `trutta_hub/` — **канонічний репозиторій**:
  - PD-00x, DOMAIN-*, CONCEPT-*, TEMPLATE-*;
  - DSL-схеми (`schemas/dsl/*`);
  - індустріальні data-layer конвенції;
  - агентні патерни (patterns/systems).

### 3.2. City repos

- `trutta_city-<city>/` — інстанси на рівні міста/регіону:
  - city-graph, service_points, menus;
  - city-level TJM micro-journeys;
  - локальні constraints/регуляторика.

### 3.3. Project repos

- `trutta_project-<name>/` — конкретні продукти/програми:
  - Sospeso, BREAD, vien.geist, health-пілоти;
  - DSL-продукти/офери/токени;
  - ABC-сегменти/пули;
  - ops-документи.

### 3.4. Runtime / Service repos

- `trutta_service-<name>/`, `trutta_runtime-<name>/`:
  - код API/мікросервісів;
  - інфра (helm/terraform);
  - конфіги деплоя.

PD-010 описує **документальні** репо (hub/city/project). Runtime — слідує тим же conventions для docs/, але код описується окремо.

---

## 4. Canonical directory conventions

### 4.1. Базовий каркас для docs-репо

Для `trutta_hub`, `trutta_city-*`, `trutta_project-*`:

```txt
/docs/
  pd/          # product & концептуальні документи (PD-***)
  domain/      # доменні моделі (DOMAIN-***)
  concept/     # окремі концепти (CONCEPT-***)
  vg/          # практичні гіди / runbooks (VG-***)
  templates/   # темплейти (TEMPLATE-***)
  guides/      # getting started / how-to
  index.md     # high-level навігація
  artefact-index.yaml
/dsl/          # DSL-артефакти інстанса (не для hub-схем)
/data/         # data-layers інстанса (canonical/analytics/ai)
/agents/       # маніфести агентів та систем (якщо актуально)
/progress/     # статуси, roadmap, зміни
/ingestion/    # ingestion rules, transforms (якщо репо в контурі ingest)
```

Hub:

* використовує `/docs/*` як **джерело правди** для інших репо;
* `/dsl/` — тільки **схеми** (PD-003) і приклади, не бойові конфіги.

City/Project:

* `/docs/*` — локальні PD/VG/DOMAIN/CONCEPT поверх hub;
* `/dsl/*` — конкретні `*.product.yaml`, `*.offer.yaml`, `*.token.yaml` тощо.

---

## 5. File naming & IDs

### 5.1. Простір PD/VG/DOMAIN/CONCEPT/TEMPLATE

* **PD-*** — product / conceptual design:

  * `PD-001-product-dsl-blueprint.md`
  * `PD-010-trutta-repo-and-docs-conventions.md` (цей документ).
* **VG-*** — практичні гіди, runbooks:

  * `VG-800-dsl-runtime-engineering.md`
  * `VG-1002-pii-map-and-dpia.md`.
* **DOMAIN-*** — доменні моделі:

  * `DOMAIN-tourism-tjm-core.md`
  * `DOMAIN-food-schema.md`.
* **CONCEPT-*** — одиночні концепти:

  * `CONCEPT-sospeso-city-coffee-subsidy.md`.
* **TEMPLATE-*** — темплейти:

  * `TEMPLATE-project-profile.yaml`
  * `TEMPLATE-city-onboarding-checklist.md`.

Конвенція:

* ID у **назві файлу** = ID у **шапці документа**:

  * в `metadata.id` (якщо yaml-frontmatter) або в заголовку.

### 5.2. DSL-файли

* `*.product.yaml`, `*.offer.yaml`, `*.token.yaml`, `*.journey.yaml`, `constraints/*.yaml` — як у PD-003;
* ID — у `metadata.id` всередині;
* шлях не використовується як canonical ID.

---

## 6. Artefact index & status tracking

### 6.1. `docs/artefact-index.yaml`

Єдиний індекс артефактів у репо:

```yaml
apiVersion: trutta.docs/v1
kind: ArtefactIndex
metadata:
  repoType: "hub" | "city" | "project"
  repoId: "trutta_hub" | "trutta_city-vienna" | ...
items:
  - id: "PD-001"
    path: "docs/pd/PD-001-product-dsl-blueprint.md"
    type: "pd"
    status: "canonical"    # draft | in_review | canonical | deprecated | conflict
    owners: ["arch", "product"]
  - id: "PD-010"
    path: "docs/pd/PD-010-trutta-repo-and-docs-conventions.md"
    type: "pd"
    status: "canonical"
```

Призначення:

* один список для людей і агентів:

  * що існує;
  * де лежить;
  * який статус.

### 6.2. `progress/artefact-status.yaml`

Якщо потрібна деталізація:

```yaml
apiVersion: trutta.docs/v1
kind: ArtefactStatus
items:
  - id: "PD-001"
    status: "canonical"
    lastReviewedAt: "2025-11-20"
    lastReviewedBy: "arch"
  - id: "PD-004"
    status: "in_review"
    notes: "need alignment with new health constraints model"
```

---

## 7. `progress/` conventions

### 7.1. Базовий набір файлів

```txt
progress/
  roadmap.yaml             # основні етапи розвитку інстанса
  artefact-status.yaml     # стани PD/VG/DOMAIN/CONCEPT
  integrations.yaml        # зовнішні інтеграції (city/project)
  changes/                 # логи важливих змін docs/dsl/data
    2025-11-xx-*.md
```

`roadmap.yaml` (логічно):

```yaml
stages:
  - id: "bootstrap"
    status: "done"
  - id: "pilot"
    status: "in_progress"
  - id: "rollout"
    status: "planned"
```

Агенти можуть:

* читати roadmap;
* оновлювати прогрес по задачах/артефактах, де це дозволено.

---

## 8. `ingestion/` conventions

Для реп, які обробляє repo-ingestion-agent:

```txt
ingestion/
  README.md                # опис, як саме інжестимо це репо
  ingestion-index.yaml     # список файлів/класифікацій
  rules.md                 # правила обробки (що куди падає)
  transforms/
    marketing-cleaning.md
    code-classification.md
  logs/
    *.log.md | *.json
```

`ingestion-index.yaml`:

* описує класифікацію файлів:

  * `type: "legacy_marketing" | "canonical_pd" | "code_sample" | ...`
  * рекомендовані дії для doc-canonisation-agent.

---

## 9. `agents/` conventions

Як у PD-008, але з привʼязкою до структури репо.

```txt
agents/
  patterns/
    repo-ingestion-agent/
      00-overview.md
      repo-ingestion.agent.yaml
      repo-ingestion.prompt.md
    doc-canonisation-agent/
      00-overview.md
      doc-canonisation.agent.yaml
      doc-canonisation.prompt.md
  systems/
    doc-pipeline/
      doc-pipeline.system.yaml
    city-onboarding/
      city-onboarding.system.yaml
```

У кожному `.agent.yaml`:

* `io.inputs/outputs` — шляхи в межах репо;
* `policies.can_modify/read_only/forbidden` — в термінах цих директорій.

---

## 10. Cross-repo linking

### 10.1. Hub → City → Project

У city/project-репах:

```txt
configs/
  trutta-hub-link.yaml
  city-links.yaml
```

`trutta-hub-link.yaml`:

```yaml
hubRepo: "trutta_hub"
pd:
  - "PD-001"
  - "PD-004"
  - "PD-006"
domain:
  - "DOMAIN-tourism-tjm-core"
  - "DOMAIN-food-schema"
```

`city-links.yaml` (у project-репі):

```yaml
cities:
  - id: "trutta_city-vienna"
    role: "primary"
  - id: "trutta_city-lviv"
    role: "secondary"
```

Мета — щоб агенти:

* могли «зрозуміти», які canonical-документи застосовні до цього інстанса;
* мали явні посилання, а не шукали по всьому GitHub.

---

## 11. Human vs agent expectations

### 11.1. Для людей

* `/docs/pd` — куди йти за концептуальним описом;
* `/docs/domain` — де дивитись ER/DBML доменів;
* `/dsl` — де лежать конфіги продуктів/оферів/токенів;
* `/progress` — де дивитись статус/roadmap.

### 11.2. Для агентів/Codex

* **перше місце** — `docs/artefact-index.yaml`:

  * які PD/DOMAIN/VG існують;
  * які з них canonical;
* **далі** — `ingestion/ingestion-index.yaml`:

  * які файли legacy/маркетинг/код;
  * що робити з ними;
* **завжди поважати**:

  * статуси (`canonical` vs `draft`);
  * `policies` з `.agent.yaml` (що можна правити).

---

## 12. Evolution

Зміни в конвенціях:

* вносяться в PD-010;
* після цього:

  * оновлюються templates в `trutta_hub/templates/*`;
  * оновлюються `artefact-index.yaml` у активних репах;
  * адаптуються агенти (manifests/policies).

Якщо якийсь репозиторій відхиляється від PD-010, це має бути **усвідомлене рішення** з явною поміткою в `docs/index.md` або `progress/artefact-status.yaml` (`local_override: true`).

PD-010 — референс для всіх future-репів Trutta.
Створення нового репозитарію без посилання на ці конвенції вважається помилкою дизайну.
