# PD-011 Product Authoring & Workflows v0.1

**Status:** Draft 0.1  
**Owner:** Product / Platform Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-spec.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-013-governance-and-compliance-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Цей документ описує **як на практиці створюються й змінюються продукти** в рамках Product DSL / Registry:

- хто має право створювати/редагувати артефакти (ролі);  
- який end-to-end workflow від ідеї до запущеного продукту;  
- як працюють review / approval / quality & safety gates;  
- як авторинг інтегрується з Registry, CLI, CI/CD та governance.

### 1.2 Scope

Охоплює:

- роботу з артефактами Product DSL (ProductDef, Profiles, Financial/Ops/Safety/Quality, інтеграції з TJM/Trutta/LEM);  
- git-репозиторій/репозиторії як source-of-truth;  
- процеси для **нових продуктів**, **змін існуючих**, **варіантів/експериментів**, **рол-ауту в нові міста**;  
- emergency-процес (швидкі зміни під інциденти).

Не охоплює:

- детальну реалізацію CLI/CI (див. PD-012);  
- юридичні контракти (див. PD-013 + окремі legal-документи);  
- city-level runbooks (VG-*).

---

## 2. Roles & Responsibilities

### 2.1 Основні ролі

- **Product Owner (PO)**  
  Відповідальний за цінність продукту, backlog, roadmap.

- **City / Market PM (CPM)**  
  Адаптує продукт під конкретне місто/ринок, локальні профілі та ціни.

- **Platform Architect (PA)**  
  Визначає структуру ProductDef, інтеграцію з TJM/Trutta/LEM, технічні інваріанти.

- **Data & Analytics (DA)**  
  Відповідає за івенти, трекінг, unit economics, аналітичні вимоги.

- **Finance (FIN)**  
  Фінмодель, ціноутворення, revenue split, FX, SLA credits.

- **Ops / SRE (OPS)**  
  SLO/SLA, інциденти, rollout/rollback, stop-sell політики.

- **Safety / Risk (SAFE)**  
  Safety-профілі, LEM-пороги, fraud-політики (разом з Trutta).

- **Vendor Ops / Supply (VO)**  
  Релевантність вендорів, їх готовність, SLA з їх боку.

- **Customer Care (CARE)**  
  Experience requirements, compensation expectations, сценарії підтримки.

- **Docs / Tech Writer (DOC)**  
  Документація для внутрішніх команд і публічних описів.

### 2.2 RACI (узагальнено)

- ProductDef структура: **R** PA, **A** PO, **C** DA/OPS/SAFE, **I** FIN/VO.  
- Фінмодель: **R** FIN, **A** PO, **C** DA/PA, **I** OPS/SAFE.  
- Ops/Safety/Quality профілі: **R** OPS/SAFE, **A** PA/PO, **C** DA/FIN, **I** VO/CARE.  
- City rollout: **R** CPM/VO, **A** PO, **C** OPS/SAFE, **I** FIN/DA.  
- Experiments/variants: **R** PO/DA, **A** PA, **C** OPS/FIN, **I** SAFE.

---

## 3. Artefacts & Repositories

### 3.1 Структура репозиторію DSL

Рекомендована структура git-репозиторію:

```text
product-dsl/
  core/
    schemas/      # JSON/YAML-схеми ProductDef, профілів, policies
    templates/    # базові шаблони (див. PD-00x-templates)

  products/
    PRD-VIEN-COFFEE-PASS/
      product.yaml
      profiles/
        pricing.at-vie.yaml
        ops.at-vie.yaml
        safety.at-vie.yaml
        quality.at-vie.yaml
      financial/
        financial-model.v1.yaml
      runtime/
        tjm-mapping.yaml
        trutta-mapping.yaml
        lem-mapping.yaml

    PRD-KIDNEY-MPT/
      ...

  policies/
    ops/
    safety/
    quality/

  cities/
    AT-VIE/
      market-config.yaml
    DE-BER/
      ...
```

### 3.2 Single source of truth

- **Git-репозиторій DSL** — єдине джерело ProductDef/профілів/політик.  
- Registry (PD-003) синхронізується через CLI/CI (PD-012).  
- Будь-яка зміна продукту повинна бути **traceable до git-commit/PR**.

---

## 4. Lifecycle States & Gates

### 4.1 Product lifecycle (logical)

Для `product_version` визначаємо стани:

- `idea` — чернетковий опис (ще не в DSL, може бути в іншому місці).  
- `draft` — ProductDef/профілі в репозиторії, але не пройшли review.  
- `review` — активний PR, проходить технічні та бізнес-перевірки.  
- `approved` — пройшов review, чекає на rollout/deploy.  
- `beta` — запущено обмежено (cities/segments).  
- `active` — повноцінно доступний у проді.  
- `degraded` — тимчасові обмеження (safety/ops), але не повний stop-sell.  
- `stop_sold` — нові продажі заборонені, активні сесії можуть догратися.  
- `retired` — більше не пропонується, історія лишається тільки для репортингу.

### 4.2 Gates

Ключові гейти:

- **Design Gate (idea → draft)**  
  Мінімальні вимоги до ProductDef та high-level фінмоделі.

- **Review Gate (draft → approved)**  
  Обов’язкові review від PA, DA, FIN, OPS/SAFE (для чутливих продуктів).

- **Launch Gate (approved → beta/active)**  
  Перевірка готовності міста/вендорів, Ops/Safety/Quality профілів, SLO/monitoring.

- **Change Gate (active → нова версія)**  
  Для major/minor змін: backward compatibility, migration plan, impact analysis.

- **Sunset Gate (active/stop_sold → retired)**  
  План міграції користувачів/вендорів, архівація, довгостроковий доступ до даних.

Гейт формалізується як набір чеків + required approvals.

---

## 5. Workflow: New Product

### 5.1 Step 0: Product Brief

Артефакт: `product-brief.md` (може жити в окремому репо або в `products/PRD-.../docs/`).  
Містить: value prop, цільові сегменти, приклади journey, high-level unit economics, ризики.

### 5.2 Step 1: Initial ProductDef

Відповідальні: PO + PA.

Дії:

1. Створити директорію `products/PRD-XXX/`.  
2. Заповнити `product.yaml` на базі шаблонів (PD-001/PD-002/PD-007).  
3. Описати базові journeys (референс на TJM-док, PD-004).  
4. Описати high-level інтеграції з Trutta та LEM (entitlements, routes/points).

### 5.3 Step 2: Profiles & Financials

Відповідальні: PA + FIN + DA + OPS/SAFE.

Дії:

- Створити `financial/financial-model.v1.yaml` (PD-009).  
- Створити `profiles/pricing.*`, `profiles/ops.*`, `profiles/safety.*`, `profiles/quality.*`.  
- Узгодити ключові SLO, safety thresholds, quality targets.

### 5.4 Step 3: Validation & Tooling

Відповідальні: PA + DA.

- Запустити CLI-валідації (schema, semantic, lint).  
- Перевірити consistency з Registry (немає конфліктів імен, версій).  
- Зібрати snapshot для демо/стейдж-оточення.

### 5.5 Step 4: Review PR

- Створити PR з усіма артефактами нового продукту.  
- Required reviewers (мінімальний набір):
  - PA (архітектура, інтеграції);  
  - DA (події, аналітика);  
  - FIN (модель, pricing);  
  - OPS (SLO/моніторинг);  
  - SAFE (якщо продукт має safety/health/fraud ризики).

CI-пайплайн (PD-012) блокує merge при:

- помилках валідації;  
- відсутності required approvals.

### 5.6 Step 5: Deploy to Staging & Beta

Після merge:

- CLI синхронізує product/profiles у Registry (staging).  
- TJM/Trutta/LEM конфіги для стейдж оновлюються;  
- запускається **beta rollout** у обмежених містах/сегментах.

Мета beta:

- валідувати tech, UX, unit economics на малому обсязі;  
- зібрати перші `quality_scores`, інциденти, feedback.

### 5.7 Step 6: Go/No-Go for Active

Після бета-періоду (визначений у PD-016-roadmap):

- Аналізуються: інциденти, SLO performance, NPS/CSAT, complaint rate, базові P&L.  
- Рішення:
  - `go` → продукт переводиться в `active` для ширшого rollout;  
  - `no-go` → продукт заморожується, доопрацьовується або закривається.

---

## 6. Workflow: Product Change / New Version

### 6.1 Types of changes

- **Minor (non-breaking):**
  - копійки в цінах, copy/UX, невеликі корекції профілів;  
  - backward compatible з поточними journeys.

- **Major (breaking):**
  - зміна структури ProductDef;  
  - нові/видалені journey nodes, значущі зміни логіки;  
  - зміни фінмоделі для існуючих продуктів.

### 6.2 Versioning pattern

- Для major змін створюється нова `product_version` (PD-003):  
  `1.0.0 → 2.0.0`.  
- Для minor — `1.0.0 → 1.1.0` (якщо впливає на конфіг, але не на контракти) або `1.0.0 → 1.0.1` (fixes).

### 6.3 Change workflow

1. Відкрити гілку `feature/prd-xxx-vX-Y-Z`.  
2. Оновити ProductDef/профілі/політики.  
3. Запустити CLI-валидації, оновити міграції Registry (якщо потрібно).  
4. Створити PR з описом типу зміни (minor/major, breaking/non-breaking).  
5. Пройти скорочений або повний review (залежно від типу змін).  
6. Deploy → стейдж → (опційно) обмежений rollout → прод.

### 6.4 Backward compatibility & migrations

Для major змін обов’язково:

- стратегії міграції активних сесій (TJM/runtime);  
- мапінг старих entitlements/rights (Trutta) на нові продукти;  
- розмежування: нові продажі йдуть по новій версії; старі — дограють по старій.

---

## 7. Workflow: City Rollout

### 7.1 Market adaptation

Артефакти:

- `profiles/pricing.<market>.yaml`  
- `profiles/ops.<market>.yaml`  
- `profiles/safety.<market>.yaml`  
- `profiles/quality.<market>.yaml`

Відповідальні: CPM + VO + OPS/SAFE + FIN.

### 7.2 Steps

1. Оцінити локальні дані: LEM (safety/coverage), Trutta (vendor readiness), попит.  
2. Налаштувати pricing/financial-профіль (локальна валюта, FX, маржа).  
3. Налаштувати ops/safety/quality-профілі з урахуванням міста.  
4. Пройти review (CPM, OPS, SAFE, FIN).  
5. Merge + deploy на staging;  
6. Ограничений rollout (наприклад, один район/кластер, тільки певні вендори) з чіткими SLO-guardrails.

---

## 8. Workflow: Experiments & Variants

### 8.1 Variants

- Визначаємо `Variant` як набір відмінностей у ProductDef/профілях при збереженні ядра продукту.  
- Варіанти версіонуються окремо (`variant_id`, `variant_version`).

### 8.2 Experiments

- Для експериментів додаються `experiment_keys` (PD-009) у PricingProfile/OpsProfile/QualityProfile.  
- DA визначає вимірювані метрики та критерії успіху.

Workflow:

1. Новий варіант описується в окремій гілці/файлах;  
2. PR з тегом `experiment` і скороченим, але обов’язковим review (PA/DA/OPS/SAFE — залежно від природи експерименту);  
3. Deploy на стейдж → обмежена вибірка користувачів/міст;  
4. Після експерименту: рішення `promote to product_version` або `retire`.

---

## 9. Emergency Workflow (Hotfix / Stop-sell)

### 9.1 Triggers

- critical safety incident;  
- серйозний баг, що ламає journeys/оплати;  
- значний fraud pattern.

### 9.2 Immediate actions

1. OPS/SAFE запускають **stop-sell / safety_override** через Ops console (без очікування повного authoring-cycle).  
2. Створюється `ops_incident` з severity `critical`.  
3. TJM/Trutta/LEM працюють з overrides (block/fallback/freeze).

### 9.3 Follow-up authoring

- Протягом визначеного в PD-013 часу (наприклад, 24–72 год):
  - підготовка зміни в ProductDef/профілях, що прибирає джерело проблеми;  
  - PR з позначкою `hotfix`, прискорений review;  
  - оновлення `ops_policies`/SafetyProfile/QualityProfile при необхідності.

- Overrides знімаються тільки після деплою фіксу та валідації.

---

## 10. Integration with Tooling & Governance

### 10.1 Tooling (PD-012)

- CLI-команди:  
  - `product lint/validate` — schema + semantic перевірки;  
  - `product diff` — порівняння версій;  
  - `product publish` — синхронізація в Registry;  
  - `product snapshot` — створення snapshot для стейдж/дему.

- CI-пайплайни:  
  - автоматичні валідації при PR;  
  - auto-preview (стейдж середовище з новим продуктом);  
  - блокування merge без green-статусу.

### 10.2 Governance (PD-013)

- Списки **required approvers** за типами змін;  
- матриця ризиків (low/medium/high/critical) та відповідні рівні review;  
- журнал змін (changelog) у Registry + Git history;  
- регулярні рев’ю портфелю продуктів (sunset/retire кандидати).

---

## 11. Summary

- Authoring Product DSL — це не ad-hoc редагування YAML-файлів, а керований процес з ролями, гейтами та інструментами.  
- Усі продукти, їх версії, профілі та політики проходять через прозорий lifecycle від idea до retired.  
- Registry, TJM, Trutta, LEM і Ops/Safety/Quality працюють поверх **єдиного джерела правди в git**, що спрощує audit, rollback та еволюцію портфелю продуктів.

