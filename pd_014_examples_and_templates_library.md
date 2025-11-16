# PD-014 Examples & Templates Library v0.1

**Status:** Draft 0.1  
**Owner:** Product Architecture / DevEx

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-spec.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-013-governance-and-compliance-spec.md  
- PD-015-testing-and-conformance-suite.md  
- PD-016-roadmap-and-evolution.md

Мета документа — описати **бібліотеку прикладів продуктів**, яка використовується для:

- документації (how-to, туторіали, демо в UI);  
- тестів (schema/semantic/integration/e2e, PD-015);  
- демонстрацій (sales, investor deck, city/vendor onboarding);  
- внутрішнього навчання авторів Product DSL.

Бібліотека прикладів — це *окремий шар* поверх DSL, з чіткими ID, структурою директорій, профілями та статусами.

---

## 1. Структура бібліотеки

### 1.1 Фізична структура в репозиторії

Рекомендована структура:

```text
examples/
  catalog/
    examples-catalog.md          # Людський опис усіх прикладів
    examples-index.json          # Машиночитний індекс
  products/
    EX-001-vien-geist-city-guide/
      product.yml                # ProductDef
      journeys.yml               # TJM journeys
      profiles.yml               # token/loyalty/pricing/ops
      notes.md                   # контекст, лімітації, usage
    EX-002-vienna-city-pass/
      ...
    EX-003-spa-weekend-budapest/
      ...
    EX-004-kidney-mpt-city-trip/
      ...
    EX-005-humanitarian-meals-trutta/
      ...
  fixtures/
    EX-001-fixtures.json         # PD-015 test fixtures, по прикладу
    EX-002-fixtures.json
  generated/
    json/                        # PD-014-generated-samples-json/
      EX-001/*.json              # автогенеровані зразки, зібрані CLI
      EX-002/*.json
```

- `examples/catalog` — логічний індекс усіх прикладів.  
- `examples/products` — вихідні ProductDef + профілі.  
- `examples/fixtures` — тест-дані/івенти, використані у PD-015.  
- `examples/generated/json` — артефакти, що генерує CLI/CI (див. PD-014-generated-samples-json).

### 1.2 Ідентифікатори прикладів

Кожен приклад має стабільний ID:

- `EX-<NNN>-<slug>` — наприклад, `EX-001-vien-geist-city-guide`.  
- NNN — тризначний номер (001–999), slug — kebab-case.

Цей ID використовується у:

- шляхах (`examples/products/EX-001-...`);  
- metadata DSL (`example_id: EX-001-vien-geist-city-guide`);  
- test fixtures (`fixture.example_id`);  
- документації та UI.

---

## 2. Таксономія прикладів

### 2.1 Основні поля каталогу

Кожен запис у каталозі містить:

- `example_id` — стабільний ID;  
- `name` — коротка назва;  
- `category` — тип продукту (city_guide, city_pass, package, health_trip, humanitarian, mobility, event, etc.);  
- `vertical` — domain (travel, F&B, health, humanitarian, mobility);  
- `primary_stack` — TJM / Trutta / LEM / mixed;  
- `complexity` — low / medium / high (для авторів та тестів);  
- `risk_level` — low / medium / high / critical (для governance);  
- `status` — draft / demo_only / internal / public_template;  
- `main_use_cases` — короткий список сценаріїв;  
- `linked_docs` — пов’язані туторіали/гайди.

### 2.2 Приклади записів (YAML)

```yaml
- example_id: EX-001-vien-geist-city-guide
  name: "vien.geist – Vienna city gastro guide"
  category: city_guide
  vertical: travel_fnb
  primary_stack: [TJM, Trutta, LEM]
  complexity: high
  risk_level: medium
  status: public_template
  main_use_cases:
    - product_authoring_training
    - city_onboarding_demo
    - vendor_network_demo
  linked_docs:
    - DOC-VG-000-overview.md
    - TJM-spec-vien-geist.md

- example_id: EX-002-vienna-city-pass
  name: "Vienna City Pass – attractions + transit"
  category: city_pass
  vertical: travel
  primary_stack: [TJM, Trutta]
  complexity: medium
  risk_level: high
  status: public_template
  main_use_cases:
    - financial_profile_training
    - pricing_bundling_demo
  linked_docs:
    - city-pass-pricing-guide.md

- example_id: EX-003-spa-weekend-budapest
  name: "Spa Weekend Budapest – hotel + spa + transfer"
  category: package
  vertical: travel_hospitality
  primary_stack: [TJM]
  complexity: medium
  risk_level: medium
  status: demo_only
  main_use_cases:
    - journey_composition_training
    - ops_sla_demo

- example_id: EX-004-kidney-mpt-city-trip
  name: "Kidney.MPT – kidney-aware city trip"
  category: health_trip
  vertical: health_travel
  primary_stack: [TJM, LEM]
  complexity: high
  risk_level: critical
  status: internal
  main_use_cases:
    - safety_profile_training
    - health_constraints_demo

- example_id: EX-005-humanitarian-meals-trutta
  name: "Humanitarian Meals – Trutta voucher program"
  category: humanitarian
  vertical: humanitarian_fnb
  primary_stack: [Trutta]
  complexity: medium
  risk_level: high
  status: internal
  main_use_cases:
    - entitlement_claim_flow_demo
    - fraud_controls_demo
```

---

## 3. Template для "Example Card" (Markdown)

Кожен приклад має свій `notes.md` з короткою карткою.

```markdown
# [EX-XXX] <Name>

## 1. Summary
- **Example ID:** EX-XXX-<slug>
- **Category:** <city_guide | city_pass | package | health_trip | humanitarian | ...>
- **Vertical:** <travel | travel_fnb | health_travel | ...>
- **Primary stack:** [TJM, Trutta, LEM]
- **Complexity:** <low | medium | high>
- **Risk level:** <low | medium | high | critical>
- **Status:** <draft | demo_only | internal | public_template>

## 2. Product Story (1–3 абзаци)
Коротко: для кого продукт, яку проблему вирішує, який очікуваний досвід.

## 3. DSL Artifacts
- ProductDef: `examples/products/EX-XXX-.../product.yml`
- Journeys (TJM): `examples/products/EX-XXX-.../journeys.yml`
- Profiles (token/loyalty/pricing/ops/safety): `examples/products/EX-XXX-.../profiles.yml`
- Additional policies: <paths, якщо є>

## 4. Integration Points
- TJM: <як використовуються journeys, які стани, які події>
- Trutta: <які entitlements, claim-flow, swap-моделі>
- LEM: <які service_points / clusters / routes>

## 5. Constraints & Assumptions
- Географія / міста / типи вендорів
- Сегменти користувачів
- Обмеження (юридичні, safety, capacity)

## 6. Usage
- Демо-сценарії (sales / onboarding)
- Тест-сценарії (schema, semantic, integration, e2e)

## 7. Links
- Пов’язані доки
- Dashboard-и / метрики
```

---

## 4. ProductDef Template для Прикладу

### 4.1 Skeleton ProductDef (YAML)

```yaml
product_id: PRD-EX-001-VIEN-GEIST
product_name: "vien.geist – Vienna city gastro guide"
example_id: EX-001-vien-geist-city-guide
version: "1.0.0"
status: template        # template | demo | production_like
category: city_guide
vertical: travel_fnb

journey_class: city_exploration
journey_templates:
  - id: JRN-VIEN-GEIST-DAY
    ref: tjm://journeys/vien-geist/day.json
  - id: JRN-VIEN-GEIST-EVENING
    ref: tjm://journeys/vien-geist/evening.json

profiles:
  token_profile_ref: profiles/token/vien-geist.yaml
  loyalty_profile_ref: profiles/loyalty/vien-geist.yaml
  pricing_profile_ref: profiles/pricing/vien-geist.yaml
  ops_profile_ref: profiles/ops/vien-geist.yaml
  safety_profile_ref: profiles/safety/vien-geist.yaml

markets:
  - code: AT-VIE
    enabled: true
    beta: true

tags:
  - city:vienna
  - cuisine:local
  - stack:tjm
  - stack:trutta
  - stack:lem

metadata:
  complexity: high
  risk_level: medium
  doc_refs:
    - DOC-VG-000-overview.md
    - DOC-VG-400-content-ops.md
```

Це skeleton, що повторюється для кожного прикладу з адаптованими ID/refs.

---

## 5. Зв’язок із Тестами (PD-015)

### 5.1 Fixture Binding

Кожен `EX-XXX` має відповідні фікстури в `examples/fixtures/EX-XXX-fixtures.json`:

- валідні ProductDef/профілі;  
- невалідні варіанти для перевірки помилок;  
- послідовності подій (journey events, claim/redemption, incidents) для e2e.

Приклад фрагмента:

```json
{
  "example_id": "EX-001-vien-geist-city-guide",
  "fixtures": {
    "valid_products": ["examples/generated/json/EX-001/vien-geist-valid-1.json"],
    "invalid_products": ["examples/generated/json/EX-001/vien-geist-invalid-missing-pricing.json"],
    "event_sequences": [
      {
        "id": "EX-001-day-tour-basic",
        "events": [
          "journey.started",
          "journey.checkpoint_reached",
          "meal.token_claimed",
          "meal.token_redeemed",
          "journey.completed"
        ]
      }
    ]
  }
}
```

### 5.2 Використання у PD-015

- Schema tests — беруть `valid_products` як золотий стандарт.  
- Semantic tests — валідують цілісність journeys/profiles/markets для прикладів.  
- Integration/e2e tests — проганяють `event_sequences` на staging/preview env.

---

## 6. Використання в документації та демо

- Docs-приклади — напряму посилаються на `EX-XXX` ("див. приклад `EX-002-vienna-city-pass`").  
- UI-демо — може завантажувати ProductDef прикладу й показувати, як авторити/публікувати/аналізувати продукт.  
- Training — автори проходять тренінги, виконуючи завдання на базі визначених EX-XXX.

Рекомендація: **не змішувати** навчальні/демо приклади з реальними бойовими конфігураціями.

---

## 7. Governance бібліотеки прикладів

- Кожен EX-XXX має:
  - owner (роль/людина);  
  - статус (draft/demo_only/internal/public_template);  
  - review cadence (наприклад, раз на пів року);  
  - прив’язку до PD-016-roadmap (чи депрекейтиться цей приклад, чи буде замінений).

- Заборонено використовувати:
  - реальні PII;  
  - реальні контрактні умови без анонімізації;  
  - чутливі health/financial сценарії для public_template без погодження SEC/Legal/SAFE.

---

## 8. Summary

- PD-014 формалізує бібліотеку **канонічних прикладів продуктів** як окремий шар поверх DSL.  
- Структура: чіткі ID EX-XXX, директорії `products/`, `fixtures/`, `generated/`, каталоги в markdown+JSON.  
- Ядро бібліотеки — кілька репрезентативних прикладів: vien.geist, city-pass, spa-weekend, kidney.mpt, humanitarian Trutta-програма.  
- Приклади використані одночасно в документації, тренінгу та PD-015 тестах, із жорсткими правилами governance та безпеки.

