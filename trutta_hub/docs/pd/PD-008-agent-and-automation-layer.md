# PD-008 — Trutta Agent & Automation Layer

**ID:** PD-008  
**Назва:** Trutta Agent & Automation Layer (Codex/AI)  
**Статус:** draft  
**Власники:** arch, eng, product, data  
**Повʼязані документи:**  
- PD-001 — Trutta Product DSL Blueprint  
- PD-002 — Trutta Concepts & Glossary  
- PD-003 — Trutta DSL File Types & Schemas  
- PD-004 — Industrial Data & Knowledge Layers  
- PD-005 — Trutta Token Types & Lifecycle  
- PD-006 — TJM (Travel Journey Model)  
- PD-007 — ABC (Anonymous Buyers Community)  
- VG-8xx — Engineering & Runtime Guides  
- VG-9xx — Analytics & Telemetry

---

## 1. Purpose

Цей документ фіксує **агентний шар Trutta**:

- які є типи агентів (Codex/LLM/utility);
- як вони взаємодіють із:
  - репозиторіями (`trutta_hub`, проектні репи),
  - DSL, доменами, data-layers;
- які **контракти**, **обмеження** та **гардрейли** мають бути гарантовані.

Мета — зробити так, щоб будь-який новий агент або pipeline:

- вбудовувався в єдину систему,
- не ламав канонічний шар документації/даних,
- працював прогнозовано для людей та інших агентів.

---

## 2. Scope

### 2.1. Входить

- логічна класифікація агентів;
- контракти агентів (маніфести, промпти, IO);
- патерни побудови pipeline-ів (systems);
- базові принципи безпеки/контролю.

### 2.2. Не входить

- конкретні системні промпти кожного агента;
- деталі оркестрації у конкретній платформі (Airflow, Temporal, MCP тощо);
- UX-персони (туристичний компаньйон, Maxine і т.д.) — це окремі PD/VG.

---

## 3. Agent categories

### 3.1. Repo / Documentation Agents

Працюють з репозиторіями, файлами, документацією:

- **Repo Ingestion Agent**  
  сканує репо, класифікує файли, заповнює `ingestion/ingestion-index.yaml`.

- **Doc Canonisation Agent**  
  перетворює сирі/legacy-тексти на канонічні PD/VG/DOMAIN/TEMPLATE-документи; оновлює `progress/artefacts/*`.

- **Refactoring / Restructuring Agents**  
  допомагають перерозкласти контент по структуруваним директоріям, не змінюючи зміст.

### 3.2. DSL & Domain Agents

Працюють з DSL і доменами:

- **DSL Authoring Agent**  
  генерує/оновлює `*.product.yaml`, `*.offer.yaml`, `*.token.yaml`, `*.journey.yaml`, `constraints/*.yaml` за правилами PD-001–003.

- **Domain Mapping Agent**  
  мапить DSL-артефакти на доменні сутності й БД-схеми (product ↔ Hotel/ServicePoint/Dish/...).

### 3.3. Data & Analytics Agents

Працюють з даними:

- **Data Ingestion Agent**  
  допомагає описувати й налаштовувати pipelines raw → canonical → analytics.

- **Analytics/Metric Agent**  
  зчитує проміжні дані й підказує:
  - які метрики додати,
  - які фічі/сегменти очевидно випливають з даних.

### 3.4. User-facing / Orchestrator Agents

- **Orchestrator Agents**  
  збирають підзадачі для інших агентів:
  - «оновити документацію», «згенерувати DSL для нового продукту», «перебудувати TJM для міста».
- **Companion/Assistant Agents**  
  фронтові шари (туристичний гід, оператор Trutta), які користуються результатами попередніх агентів, але **не змінюють** канонічні артефакти напряму.

---

## 4. Agent contracts

### 4.1. Маніфести агентів

Файл: `agents/patterns/<agent-name>/<agent-name>.agent.yaml`

Мінімально:

```yaml
apiVersion: trutta.agents/v1
kind: Agent
metadata:
  id: "agent.repo-ingestion"
  name: "Repo Ingestion Agent"
  labels:
    scope: ["docs", "repo"]
io:
  inputs:
    - path: "ingestion/ingestion-index.yaml"
    - path: "docs/**"
  outputs:
    - path: "ingestion/ingestion-index.yaml"
    - path: "ingestion/logs/**"
policies:
  can_modify:
    - "ingestion/**"
  read_only:
    - "docs/**"
  forbidden:
    - "schemas/db/**"
prompts:
  system: "agents/patterns/repo-ingestion-agent/repo-ingestion.prompt.md"
```

### 4.2. Промпти

* системний промпт: контекст, правила, заборони;
* user-промпт: конкретна задача/батч.

Промпти **завжди** посилаються на PD-001–PD-007 як джерела правди для термінів/схем, а не вигадують свою семантику.

---

## 5. Agent systems (pipelines)

### 5.1. System manifests

Файл: `agents/systems/<system-name>/<system-name>.system.yaml`
Приклад — `doc-pipeline.system.yaml` (вже визначено):

* описує:

  * які агенти беруть участь;
  * у якій послідовності;
  * які файли/директорії є «кровʼю» пайплайну;
  * які тригери (manual/CI/branch).

### 5.2. Типові системи

* **doc-pipeline**
  ingestion → canonisation → статус артефактів.

* **dsl-pipeline**
  від PD/концептів → схем → конкретних `*.yaml` → валідація.

* **data-pipeline**
  від external sources → raw → canonical → analytics → AI layer.

* **city-onboarding-pipeline**
  зборка city-graph, service_points, initial TJM micro-journeys.

---

## 6. Guardrails & safety

### 6.1. Зона відповідальності агента

Кожен агент має:

* `can_modify` — чіткий whitelist директорій/файлів;
* `read_only` — що можна читати, але не змінювати;
* `forbidden` — до чого взагалі не торкається.

Будь-яке оновлення канонічних документів:

* йде через **PR/ревʼю** або хоча б логування в `progress/changes/**`;
* не робиться «в обхід» doc-pipeline.

### 6.2. Людина в контурі

* критичні зміни PD/DSL/DOMAIN-файлів → ручний review;
* агенти можуть:

  * пропонувати diff,
  * створювати чернетки;
* статус `canonical` змінюється тільки після людського рішення.

---

## 7. Integration with repos

### 7.1. trutta_hub як центральний knowledge-repo

Агенти повинні сприймати `trutta_hub` як:

* **канонічний шар концептів/схем/DSL**;
* джерело стандартів для інших репозиторіїв.

Інші репи (проекти, інстанси, міста):

* можуть посилатися на PD/VG/DOMAIN з `trutta_hub`;
* локальні зміни не повинні «перевизначати» канон без явного рішення.

### 7.2. Mapping legacy → canonical

Файл `progress/integrations/trutta_frames-mapping.yaml`:

* є контрактом між:

  * старим репом `Trutta_frames-A-c-`,
  * новою структурою `trutta_hub`;
* repo-ingestion-agent і doc-canonisation-agent користуються ним як **мапою міграції**.

---

## 8. Telemetry & analytics for agents

* кожен агент/система має:

  * мінімальні метрики:

    * кількість змінених файлів,
    * кількість warnings/errors,
    * час виконання;
  * логи в `ingestion/logs/**` або `progress/logs/**`.
* VG-9xx описує:

  * як моніторити якість роботи агентів;
  * як виявляти систематичні помилки (неправильні класифікації, конфлікти).

---

## 9. Governance & evolution

### 9.1. Додавання нового агента

Новий агент допускається до прод-контурів, якщо:

* має заповнений `.agent.yaml` з чіткими правами;
* має промпт, що посилається на PD-001–PD-007;
* протестований у **dry-run** режимі (тільки read-only або на копії).

### 9.2. Зміни в агентних системах

* будь-яка зміна `*.system.yaml`:

  * проходить review з боку arch/product;
  * має короткий опис:

    * що змінюється в потоці;
    * які нові ризики/бенефіти.

---

## 10. Відношення до інших PD/VG

* PD-001–007
  задають **що таке Trutta як модель** (DSL, токени, TJM, ABC, індустріальні дані).

* PD-008
  фіксує **як ця модель обслуговується агентами**:

  * хто читає/пише файли,
  * як все це складається в pipelines.

Решта PD/VG-доків конкретизують:

* окремі типи агентів (наприклад, city-onboarding, Sospeso-пайплайни);
* окремі репи/проєкти поверх Trutta.

Будь-який новий агент чи система має вписуватись у цю рамку; якщо ні — спочатку оновлюється PD-008, потім — маніфести/практика.
