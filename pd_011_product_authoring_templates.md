# PD-011 Product Authoring Templates v0.1

**Status:** Draft 0.1  
**Owner:** Product / Platform Architecture

**Related docs:**  
- PD-011-product-authoring-and-workflows.md  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-templates.md  
- PD-009-financial-templates.md  
- PD-010-ops-templates.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-013-governance-and-compliance-spec.md

Мета — дати **конкретні темплейти** для авторингу та зміни продуктів:

- product-spec (основний опис продукту);
- city/market addendum;
- PR шаблонів для змін у Product DSL;
- ADR (Architecture / Product Decision Record);
- release notes / changelog.

---

## 1. Product Spec Template (Markdown)

Базовий `product-spec.md` для нового продукту (живе поряд із `product.yaml`).

```markdown
# Product Spec – [PRODUCT NAME]

- **ID:** PRD-[CODE]  
- **Version:** [MAJOR.MINOR.PATCH]  
- **Owner (PO):** [NAME]  
- **Product Architect:** [NAME]  
- **Primary Markets:** [AT-VIE, DE-BER, ...]  
- **Status:** idea | draft | review | approved | beta | active | retired

---

## 1. Summary

### 1.1 One-liner
- Коротко і чітко: що це за продукт і для кого.

### 1.2 Problem & Solution
- **Problem:** 2–3 речення про біль користувача/ринку.
- **Solution:** як продукт її закриває.

### 1.3 Target Segments & Use Cases
- Основні сегменти (туристи, місцеві, корпоративні, health-specific тощо).
- 3–5 ключових use cases (бажано у форматі "As a X I want Y so that Z").

---

## 2. Journey & Experience

### 2.1 Core Journey
- Короткий опис базового шляху (від відкриття продукту до завершення досвіду).
- Посилання на TJM: [PD-004-tjm-integration-spec] / TJM doc ID.

### 2.2 Variants / Flows
- Варіанти сценаріїв (наприклад, з/без попереднього бронювання, різні тривалості тощо).

### 2.3 Constraints & Assumptions
- Які припущення щодо даних, вендорів, інфраструктури, регуляцій.

---

## 3. Value & Economics

### 3.1 Value Proposition
- Для користувачів.
- Для вендорів.
- Для платформи.

### 3.2 Pricing & Revenue Model
- Базова модель (flat fee, usage-based, mix, subscription, інше).
- Посилання: `financial/financial-model.v1.yaml` (PD-009).

### 3.3 Key Metrics
- North Star / primary outcome.
- Secondary metrics (GMV, маржа, NPS, retention, completion rate).

---

## 4. Profiles & Policies

### 4.1 Profiles
- Які профілі будуть створені / використані:
  - PricingProfile(s)
  - TokenProfile / LoyaltyProfile
  - OpsProfile
  - SafetyProfile
  - QualityProfile

Посилання на відповідні файли в `profiles/`.

### 4.2 Ops / Safety / Quality Requirements
- Цільові SLO (availability, journey success, error rate, latency).
- Safety вимоги (LEM, Trutta fraud, health/diet.
- Quality вимоги (мін. рейтинг, complaint rate, контент).

---

## 5. Integrations

### 5.1 TJM
- Які типи journey-ноди, специфічні constraints.

### 5.2 Trutta
- Тип entitlements / tokens.
- Claim/redeem патерни.
- Settlement / compensation нюанси.

### 5.3 LEM
- Які точки/маршрути/кластери обов’язкові.
- Safety/coverage очікування.

---

## 6. Risks & Open Questions

### 6.1 Risks
- Технічні.
- Операційні.
- Регуляторні.
- Вендорські.

### 6.2 Mitigations
- Що робимо для мінімізації кожного ключового ризику.

### 6.3 Open Questions
- Невирішені питання, які блокують або можуть впливати на решення Go/No-Go.

---

## 7. Rollout Plan

### 7.1 Beta Plan
- Де, з ким, які обмеження.

### 7.2 Go/No-Go Criteria
- Які метрики / сигнали потрібні для переходу з beta → active.

### 7.3 Sunset Criteria
- За яких умов продукт буде консервуватись / ретиритись.

---

## 8. Appendix

- Посилання на PR-и, ADR-и, експерименти.
- Макети UI / Figma / Framer.
- Додаткові матеріали.
```

---

## 2. City / Market Addendum Template

Специфікація для адаптації продукту до конкретного ринку/міста, `product-[market]-addendum.md`.

```markdown
# Market Addendum – [PRODUCT NAME] – [MARKET CODE]

- **Product ID:** PRD-[CODE]
- **Market:** [AT-VIE]
- **City:** [VIE]
- **City PM:** [NAME]
- **Vendor Lead:** [NAME]

---

## 1. Local Context

- Короткий опис ринку/міста.
- Особливості попиту, сезонність, поведінкові патерни.

## 2. Vendors & Supply

- Типи вендорів / партнерів.
- Мінімальні вимоги до вендорів.
- Список ключових вендорів для старту.

## 3. Pricing & Financials

- Локальні ціни / валютні обмеження.
- Локальні податки / fees / caps.
- Посилання на `profiles/pricing.[market].yaml`.

## 4. Ops / Safety / Quality

- Локальні SLO / відмінності від глобальних.
- Local safety нюанси (райони, час доби, культурні особливості).
- Локальні quality-вимоги (очікування від сервісу, мін. рейтинг).

## 5. Rollout Plan

- Початкові райони / кластери.
- Вендори першої хвилі.
- Локальний beta-період та критерії.

## 6. Risks & Dependencies

- Локальні ризики (регуляції, відсутність даних, слабка інфраструктура).
- Необхідні інтеграції / анотації LEM/Trutta.
```

---

## 3. PR Template for Product DSL Changes

Шаблон для PR у репозиторії `product-dsl`.

```markdown
# PR: [Short title]

## 1. Summary
- Коротко: що змінюємо і навіщо.

## 2. Type of change
- [ ] New product
- [ ] New city/market for existing product
- [ ] New variant/experiment
- [ ] Product change – minor (non-breaking)
- [ ] Product change – major (potentially breaking)
- [ ] Policy / profile change (Ops/Safety/Quality/Financial)

## 3. Scope
- Products: [PRD-...]
- Versions: [1.0.0 → 1.1.0]
- Markets: [AT-VIE, ...]
- Affected profiles: [pricing, ops, safety, quality, financial, token]
- Affected policies: [ops_policies IDs, safety_overrides patterns]

## 4. Motivation
- Яку проблему вирішуємо / яку можливість реалізуємо.
- Reference: JIRA/Notion/ADR/product-spec link.

## 5. Changes
- High-level список змін у ProductDef/профілях/політиках.
- Для major-проєктів – коротка табличка old vs new.

## 6. Risk & Impact
- Ризики для користувачів.
- Ризики для вендорів.
- Ризики для платформи (Ops/Safety/Finance).

## 7. Migration / Rollout Plan
- Як відбувається rollout (beta, фази, markets).
- Чи потрібні міграції сесій / entitlements / billing-конфігів.
- План rollback (якщо щось іде не так).

## 8. Testing & Validation
- [ ] Schema validation (CLI)
- [ ] Semantic validation
- [ ] Local/staging TJM flows
- [ ] Local/staging Trutta flows
- [ ] LEM integration sanity
- [ ] Analytics events coverage

## 9. Approvals
- Product Owner: @
- Platform Architect: @
- Data/Analytics: @
- Finance: @
- Ops/SRE: @
- Safety/Risk: @ (якщо релевантно)

## 10. Additional Notes
- Будь-що інше, що reviewer має знати.
```

---

## 4. ADR Template (Architecture / Product Decision Record)

ADR-и фіксують важливі рішення по продуктовій моделі, версіюванням, інтеграціям.

```markdown
# ADR-[NNN]: [Decision Title]

- **Status:** proposed | accepted | superseded | dropped
- **Date:** YYYY-MM-DD
- **Context:** product-dsl | tjm | trutta | lem | ops | analytics | cross-cutting
- **Authors:** [NAMEs]
- **Related:** [PRs, product-spec, issues]

---

## 1. Context

- Поточний стан системи / продуктової моделі.
- Які обмеження / драйвери.
- Які альтернативи розглядаються.

## 2. Decision

- Чітко сформульоване рішення (1–3 абзаци).
- Можна додати короткий bullet-список.

## 3. Alternatives Considered

- Alternative 1: короткий опис + плюси/мінуси.
- Alternative 2: ...
- Чому не обрані.

## 4. Consequences

- **Positive:**
  - ...
- **Negative / Trade-offs:**
  - ...

## 5. Implementation Notes

- Як це рішення відображається в ProductDef / профілях / схемах / коді.
- Посилання на відповідні файли/компоненти.

## 6. Follow-ups

- Які дії потрібно зробити після прийняття.
- Коли рішення планується переглянути / які тригери для ревізії.
```

---

## 5. Release Notes Template

### 5.1 Product-facing Release Notes (Markdown)

```markdown
# Release Notes – [PRODUCT NAME] – [VERSION]

**Release date:** YYYY-MM-DD  
**Scope:** [markets, cities]

## 1. What’s new
- [Короткий список ключових покращень для користувача / вендора.]

## 2. Changes

### 2.1 Product & Journeys
- [ ] Нові/оновлені маршрути.
- [ ] Зміни в UX/flows.

### 2.2 Pricing & Financial
- [ ] Зміни цін / валют.
- [ ] Зміни в промо / токенах.

### 2.3 Ops / Safety / Quality
- [ ] Нові/оновлені SLO/SLA.
- [ ] Зміни safety-порогів.
- [ ] Зміни quality-гейтів.

## 3. Impact
- Для користувачів.
- Для вендорів.
- Для внутрішніх команд (Ops/Support).

## 4. Rollout
- План розгортання (фази, markets).
- Можливі регресії та що моніторимо.

## 5. Known Issues
- Відомі обмеження / баги.

## 6. Links
- PR/комміти.
- ADR.
- Оновлені product-spec / addendum.
```

### 5.2 Machine-readable Release Manifest (JSON)

Може зберігатися в `releases/[PRD]/[VERSION].json`.

```json
{
  "product_id": "PRD-VIEN-COFFEE-PASS",
  "version": "1.1.0",
  "release_date": "2025-03-01",
  "environments": ["staging", "production"],
  "markets": ["AT-VIE"],

  "changes": {
    "product": [
      "Updated journey with new vendor cluster in district 7"
    ],
    "pricing": [
      "Adjusted base price by +5% for high season"
    ],
    "ops": [
      "Tightened SLO for availability from 99.0% to 99.5%"
    ],
    "safety": [
      "Raised minimum LEM route safety threshold to 0.82"
    ],
    "quality": [
      "Increased min average rating requirement from 4.0 to 4.2"
    ]
  },

  "rollout": {
    "strategy": "phased",
    "phases": [
      {
        "name": "phase-1",
        "start_date": "2025-03-01",
        "segment": "10% of users in AT-VIE"
      },
      {
        "name": "phase-2",
        "start_date": "2025-03-08",
        "segment": "100% of users in AT-VIE"
      }
    ]
  },

  "links": {
    "product_spec": "products/PRD-VIEN-COFFEE-PASS/product-spec.md",
    "product_yaml": "products/PRD-VIEN-COFFEE-PASS/product.yaml",
    "pr": "https://git.example.com/...",
    "adr": "docs/adr/ADR-012.md"
  }
}
```

---

## 6. Changelog Pattern

Рекомендований патерн для `CHANGELOG.md` в root репозиторію.

```markdown
# Changelog – Product DSL

## [1.5.0] – 2025-03-01

### Added
- Новий продукт: Vienna Coffee Pass (PRD-VIEN-COFFEE-PASS).
- Додано QualityProfile шаблони для city-level rollout.

### Changed
- Оновлено фінмодель для PRD-KIDNEY-MPT (кращий FX handling).
- Підкручені safety thresholds для AT-VIE.

### Fixed
- Виправлено помилку в схемі TokenProfile.

---

## [1.4.0] – 2025-02-10
...
```

---

## 7. Usage Notes

- Всі темплейти використовуються **разом** з процесами з PD-011: кожна зміна продукту повинна мати:
  - product-spec (оновлений при суттєвих змінах);  
  - PR із заповненим шаблоном;  
  - ADR для значущих архітектурних/продуктових рішень;  
  - release notes/manifest для прод-роллауту.
- Рекомендується автоматизувати генерацію частини release notes/manifest із CI (на основі diff’ів ProductDef/профілів/політик).

