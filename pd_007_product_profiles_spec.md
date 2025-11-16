# PD-007 Product Profiles Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph-integration-spec.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Цей документ формалізує **profile layer** для продуктів:

- уніфіковані **TokenProfile / LoyaltyProfile / PricingProfile / OpsProfile / SafetyProfile / QualityProfile / UiProfile**;
- єдиний контракт між ProductDef, Registry, TJM, Trutta, LEM, BFF;
- модель reuse/override профілів між продуктами, містами, сегментами.

### 1.2 Scope

Входить:

- таксономія профілів;  
- спільне ядро (base profile schema);  
- специфіка для кожного типу профілю;  
- lifecycle та override-модель.

Не входить:

- деталізована фінансова логіка (див. PD-009);  
- повні SLO/SLA-деталі (див. PD-010);  
- low-level DDL для таблиць (там, де це окремі PD-00x-*.ddl.sql).

---

## 2. Taxonomy of Product Profiles

### 2.1 Profile types

Ми виділяємо такі **profile_type**:

- `token_profile` — описує токенізацію продукту (Trutta, chain, wallet-видимість).
- `loyalty_profile` — нарахування/списання loyalty-юнітів (points/miles/tiers).
- `pricing_profile` — бізнес-логіка ціноутворення (базові ціни, overrides, дисконти).
- `ops_profile` — операційні пороги, алерти, duty-цикли.
- `safety_profile` — safety-політики, гео/часові обмеження, контентні обмеження.
- `quality_profile` — quality-гейти, NPS/CSAT таргети, рев’ю-політики.
- `ui_profile` — те, як продукт виглядає в UI (copy, layout hints, feature flags).

### 2.2 Profile scope

Кожен профіль має **scope**:

- `global` — спільний для багатьох продуктів/ринків;  
- `market` — специфічний для `market_code` (AT-VIE, CZ-PRG);  
- `product` — специфічний для конкретного `product_id`;  
- `segment` — специфічний для сегмента (kidney, family, local, tourist);  
- `experiment` — A/B / feature flag.

Профілі комбінуються **layered override-моделлю** (див. 6).

---

## 3. Base Profile Schema

Усі профілі наслідують базову структуру.

```yaml
profile_id: PRF-TOKEN-VIEN-COFFEE-PASS
profile_type: token_profile

version: 1
status: active        # draft | active | deprecated | retired

scope:
  level: market       # global | market | product | segment | experiment
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments:
    - coffee_lover
    - tourist
  experiment_key: null

priority: 100         # для resolve конфліктів між профілями одного типу

meta:
  title: "Vienna Coffee Pass Token Profile"
  description: "Defines tokenisation for Vienna Coffee Day Pass."
  owner: "product-arch@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

created_at: 2025-10-15T10:00:00Z
created_by: "sys-product-admin"
updated_at: 2025-10-20T12:00:00Z
updated_by: "sys-product-admin"
```

Інваріанти:

- `profile_id` — глобально унікальний;  
- `(profile_type, scope.level, market_code?, product_ids?, segments?)` + `status=active` не повинні створювати неоднозначностей без priority;  
- `effective_from < effective_until` (якщо `effective_until` не null).

---

## 4. TokenProfile

### 4.1 Purpose

TokenProfile описує **як продукт пов’язаний із токенізаційним шаром** (Trutta, блокчейн, внутрішній ledger):

- які token/entitlement профілі використовуються;  
- як це показується у wallet;  
- які обмеження та swap-пріоритети.

### 4.2 Logical schema

```yaml
profile_type: token_profile

trutta:
  entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS
  token_profile_id:       TRT-TKN-VIEN-COFFEE-PASS
  settlement_profile_id:  TRT-SET-VIEN-COFFEE-PASS
  swap_profile_ids:
    - TRT-SWAP-VIEN-COFFEE-PASS-LOCAL

wallet:
  show_in_user_wallet: true
  show_in_vendor_wallet: true
  show_unit_breakdown: true
  grouping_key: "coffee_pass"

limits:
  per_user:
    max_tokens_total: 10
    max_tokens_per_day: 3
  per_wallet:
    max_unredeemed_units: 30

swap_preferences:
  preferred_swap_profiles:
    - TRT-SWAP-VIEN-COFFEE-PASS-LOCAL
  allow_cross_city_swap: false

chain_metadata:
  visibility: "offchain_first"   # offchain_first | onchain_first | hybrid
  networks:
    - name: polygon
      token_contract: "0x..."
      explorer_url_template: "https://polygonscan.com/token/{contract}?a={wallet}"
```

Інваріанти:

- IDs мають існувати в Trutta (див. PD-005).  
- Limits не суперечать EntitlementProfile/TokenProfile на Trutta-стороні (не послаблюють їх).

---

## 5. LoyaltyProfile

### 5.1 Purpose

Описує, **як продукт взаємодіє з loyalty-системою**:

- earn-правила (event → points);  
- redeem-правила;  
- tiering / статуси.

### 5.2 Logical schema

```yaml
profile_type: loyalty_profile

currency:
  code: "COFFEE_POINTS"
  title: "Coffee Points"
  decimals: 0

earn_rules:
  - id: EARN-COFFEE-REDEMPTION
    event_type: "entitlement.redeemed"
    conditions:
      product_ids:
        - PRD-VIEN-COFFEE-PASS
      city_codes:
        - VIE
    formula:
      type: fixed_per_unit
      points_per_unit: 1

  - id: EARN-JOURNEY-COMPLETED
    event_type: "journey.completed"
    conditions:
      journey_facets:
        - coffee_walk
    formula:
      type: flat
      points: 10

redeem_rules:
  - id: REDEEM-FREE-COFFEE
    title: "Free coffee for 10 points"
    required_points: 10
    reward_type: "entitlement"
    reward_ref: "TRT-ENT-VIEN-COFFEE-ONE"

tiers:
  - id: TIER-BASIC
    title: "Basic"
    threshold_points: 0
  - id: TIER-REGULAR
    title: "Regular"
    threshold_points: 100
  - id: TIER-VIP
    title: "VIP"
    threshold_points: 500
```

Інваріанти:

- `earn_rules` не повинні створювати нескінченний цикл (journey/entitlement → points → нові entitlements → ще points).  
- Redeem-правила повинні мапитись на валідні Trutta/продуктові entitlement-и.

---

## 6. PricingProfile (high-level)

> Деталі фінансових моделей — у PD-009. Тут — high-level зв’язок продукту з pricing-конфігами.

```yaml
profile_type: pricing_profile

base_price:
  currency: EUR
  amount: 19.00

market_overrides:
  - market_code: AT-VIE
    amount: 17.00
  - market_code: CZ-PRG
    amount: 21.00

conditions:
  segments:
    kidney_friendly:
      discount_percent: 15
    local_resident:
      discount_percent: 10

campaigns:
  - id: CAMP-BLACK-FRIDAY
    discount_percent: 25
    valid_from: 2025-11-28T00:00:00Z
    valid_until: 2025-11-30T23:59:59Z

rounding:
  mode: "nearest_0_10"   # до 0.10 EUR

integration:
  billing_price_list_id: "BILL-PL-VIEN-COFFEE-PASS"
```

Інваріанти:

- PricingProfile не суперечить фінпрофілю (PD-009);  
- розрахунки фінального price йдуть в окремому сервісі, профіль — лише конфіг.

---

## 7. Ops/Safety/Quality Profiles (link layer)

> Повна модель — у PD-010. Тут — як ProductProfiles посилаються на них.

### 7.1 OpsProfile

```yaml
profile_type: ops_profile

ops:
  slo_targets:
    booking_flow_availability: 0.995
    entitlement_issue_latency_p95_ms: 500
  alert_policies:
    - id: OPS-ALERT-ENT-FAIL
      metric: "entitlement.issue.error_rate"
      threshold: 0.01
      window: "5m"
      severity: "high"
```

### 7.2 SafetyProfile

```yaml
profile_type: safety_profile

safety:
  min_safety_score: 0.7
  forbidden_tags:
    - "unsafe_edge"
  time_restrictions:
    night:
      enabled: true
      allowed_hours_local:
        from: "06:00"
        to: "23:00"

geo:
  allowed_cities:
    - VIE
  forbidden_clusters:
    - CL-VIE-NIGHTLIFE-RED

content:
  disallow_categories:
    - "adult"
    - "gambling"
```

### 7.3 QualityProfile

```yaml
profile_type: quality_profile

quality:
  target_nps: 60
  target_csatscore: 4.5
  review_requirements:
    min_reviews_per_month: 30
    min_review_response_rate: 0.8

experience_checks:
  require_post_journey_survey: true
  survey_template_id: "SURV-VIEN-COFFEE-PASS-01"
```

---

## 8. UiProfile

### 8.1 Purpose

UiProfile визначає **як продукт виглядає в UI**, не змішуючи це з бізнес-логікою:

- naming, copy, локалізація;  
- visual tokens (color/icon/layout hints);  
- feature flags / toggle’и для інтерфейсу.

### 8.2 Logical schema

```yaml
profile_type: ui_profile

localization:
  default_locale: "en"
  supported_locales:
    - "en"
    - "de"

  title:
    en: "Vienna Coffee Day Pass"
    de: "Wien Kaffee Tagespass"

  short_description:
    en: "Enjoy 5 coffees in partner cafés across Vienna in 48 hours."
    de: "Genießen Sie 5 Kaffees in Partner-Cafés in Wien innerhalb von 48 Stunden."

  long_description_md:
    en: """## What you get\n- Up to **5 coffees** in partner cafés\n- Valid for 48 hours from first use"""

visual:
  icon_key: "coffee_pass"
  primary_color: "#C98F4A"
  accent_color: "#2B2B2B"

layout:
  grouping_section: "city_passes"
  badges:
    - "popular"
    - "local_partners"

feature_flags:
  show_loyalty_badge: true
  show_kidney_safe_label: true
```

---

## 9. Profile Resolution & Overrides

### 9.1 Resolution order

Для кожного `profile_type` рантайм/Registry застосовують **layered resolution**:

1. `global` профілі (status=active).  
2. `market` профілі, що match’ять `market_code`.  
3. `product` профілі, що містять `product_id`.  
4. `segment` профілі (за наявності сегмента).  
5. `experiment` профілі (якщо активний експеримент).

Всередині одного рівня — сортування за `priority` (більше число → більш сильний override).

### 9.2 Merge semantics

- Профілі того ж `profile_type` мерджаться **shallow-override** по ключах:  
  - пізніший шар замінює значення попереднього по тому самому полю;  
  - для колекцій (масивів) може застосовуватись політика `append` / `replace` (визначається окремо для типу профілю).

- Приклад: UiProfile
  - global задає локалізацію EN;  
  - market додає DE;  
  - product overlay змінює `primary_color`.

### 9.3 Registry contract

- Registry відповідає за:
  - збереження профілів;  
  - валідацію посилань (на Trutta/LEM/TJM/Analytics);  
  - видачу **effective profile** для конкретного (product_version, market, segment, experiment).

- Runtime сервіси (TJM, BFF, Trutta, LEM) не повинні самі вирішувати конфлікти профілів, а використовують pre-resolved профілі з Registry.

---

## 10. Summary

- PD-007 вводить **стабільний шар профілів продукту**, який:
  - декомпонує токенізацію, loyalty, pricing, ops/safety/quality та UI;  
  - дає єдину модель reuse/override по ринках, сегментах, експериментах;  
  - служить контрактом між ProductDef/Registry та рантаймом (TJM, Trutta, LEM, BFF).

- Наступні документи (PD-008/009/010) деталізують:
  - використання профілів у execution-пайплайні продуктів;  
  - фінансову модель (pricing/settlement);  
  - операційні, safety та quality політики на рівні SLO/SLA та incident-flow.

