# PD-007 Product Profiles Templates v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-007-product-profiles-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md

Мета — дати **мінімальні YAML/JSON-шаблони** для основних типів профілів:

- TokenProfile  
- LoyaltyProfile  
- PricingProfile  
- OpsProfile  
- SafetyProfile  
- QualityProfile  
- UiProfile

Усі приклади — для продукту **Vienna Coffee Day Pass** з можливістю reuse.

---

## 1. Base Profile Skeleton (all types)

> Використовується як заготовка для будь-якого профілю.

```yaml
profile_id: PRF-<TYPE>-<CODE>
profile_type: <token_profile|loyalty_profile|pricing_profile|ops_profile|safety_profile|quality_profile|ui_profile>

version: 1
status: draft   # draft | active | deprecated | retired

scope:
  level: global  # global | market | product | segment | experiment
  market_code: null
  product_ids: []
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "<Human readable profile name>"
  description: "<Short description>"
  owner: "product-arch@reis.agency"

constraints:
  effective_from: 2025-01-01T00:00:00Z
  effective_until: null

created_at: 2025-01-01T00:00:00Z
created_by: "sys-product-admin"
updated_at: 2025-01-01T00:00:00Z
updated_by: "sys-product-admin"
```

---

## 2. TokenProfile Templates

### 2.1 Global TokenProfile (baseline for coffee passes)

```yaml
profile_id: PRF-TOKEN-COFFEE-GLOBAL
profile_type: token_profile

version: 1
status: active

scope:
  level: global
  market_code: null
  product_ids: []
  segments: []
  experiment_key: null

priority: 10

meta:
  title: "Global Coffee Token Profile"
  description: "Baseline tokenisation settings for all coffee passes."
  owner: "product-arch@reis.agency"

constraints:
  effective_from: 2025-01-01T00:00:00Z
  effective_until: null

trutta:
  entitlement_profile_id: TRT-ENT-COFFEE-PASS-GLOBAL
  token_profile_id:       TRT-TKN-COFFEE-PASS-GLOBAL
  settlement_profile_id:  TRT-SET-COFFEE-PASS-GLOBAL
  swap_profile_ids: []

wallet:
  show_in_user_wallet: true
  show_in_vendor_wallet: true
  show_unit_breakdown: true
  grouping_key: "coffee_pass"

limits:
  per_user:
    max_tokens_total: 20
    max_tokens_per_day: 5
  per_wallet:
    max_unredeemed_units: 50

swap_preferences:
  preferred_swap_profiles: []
  allow_cross_city_swap: false

chain_metadata:
  visibility: "offchain_first"
  networks: []
```

### 2.2 Market-level TokenProfile override (Vienna Coffee Day Pass)

```yaml
profile_id: PRF-TOKEN-VIEN-COFFEE-PASS
profile_type: token_profile

version: 1
status: active

scope:
  level: market
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass Token Profile"
  description: "Tokenisation for Vienna Coffee Day Pass."
  owner: "product-arch@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

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
  grouping_key: "coffee_pass_vienna"

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
  visibility: "offchain_first"
  networks:
    - name: polygon
      token_contract: "0x<contract>"
      explorer_url_template: "https://polygonscan.com/token/{contract}?a={wallet}"
```

---

## 3. LoyaltyProfile Templates

### 3.1 Global Coffee Points

```yaml
profile_id: PRF-LOYALTY-COFFEE-GLOBAL
profile_type: loyalty_profile

version: 1
status: active

scope:
  level: global
  market_code: null
  product_ids: []
  segments: []
  experiment_key: null

priority: 10

meta:
  title: "Global Coffee Loyalty"
  description: "Default loyalty currency and rules for coffee products."
  owner: "loyalty@reis.agency"

constraints:
  effective_from: 2025-01-01T00:00:00Z
  effective_until: null

currency:
  code: "COFFEE_POINTS"
  title: "Coffee Points"
  decimals: 0

earn_rules:
  - id: EARN-COFFEE-REDEMPTION
    event_type: "entitlement.redeemed"
    conditions:
      product_ids: []      # any coffee product
      city_codes: []       # any city
    formula:
      type: fixed_per_unit
      points_per_unit: 1

redeem_rules: []

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

### 3.2 Product-level Loyalty override (extra for Vienna Coffee Day Pass)

```yaml
profile_id: PRF-LOYALTY-VIEN-COFFEE-PASS
profile_type: loyalty_profile

version: 1
status: active

scope:
  level: product
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 200

meta:
  title: "Vienna Coffee Day Pass Loyalty Bonus"
  description: "Extra loyalty earnings for Vienna Coffee Day Pass."
  owner: "loyalty@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

currency:
  code: "COFFEE_POINTS"
  title: "Coffee Points"
  decimals: 0

earn_rules:
  - id: EARN-JOURNEY-COMPLETED-VIEN
    event_type: "journey.completed"
    conditions:
      product_ids:
        - PRD-VIEN-COFFEE-PASS
      journey_facets:
        - coffee_walk
    formula:
      type: flat
      points: 10

redeem_rules: []

tiers: []   # успадковується з global профілю
```

---

## 4. PricingProfile Templates

### 4.1 Market-level PricingProfile (Vienna)

```yaml
profile_id: PRF-PRICING-VIEN-COFFEE-PASS
profile_type: pricing_profile

version: 1
status: active

scope:
  level: market
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass Pricing"
  description: "Base price and overrides for Vienna Coffee Day Pass."
  owner: "finance@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

base_price:
  currency: EUR
  amount: 19.00

market_overrides: []

conditions:
  segments:
    local_resident:
      discount_percent: 10

campaigns:
  - id: CAMP-VIEN-LAUNCH
    discount_percent: 15
    valid_from: 2025-11-01T00:00:00Z
    valid_until: 2025-11-15T23:59:59Z

rounding:
  mode: "nearest_0_10"

integration:
  billing_price_list_id: "BILL-PL-VIEN-COFFEE-PASS"
```

### 4.2 Experiment PricingProfile (A/B discount test)

```yaml
profile_id: PRF-PRICING-VIEN-COFFEE-PASS-AB-10OFF
profile_type: pricing_profile

version: 1
status: active

scope:
  level: experiment
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: "vien_coffee_ab_10off"

priority: 300

meta:
  title: "Vienna Coffee A/B 10% Off"
  description: "Experiment group with additional 10% discount."
  owner: "growth@reis.agency"

constraints:
  effective_from: 2025-11-10T00:00:00Z
  effective_until: 2025-11-30T23:59:59Z

base_price:
  currency: EUR
  amount: 19.00

market_overrides: []

conditions:
  segments: {}

campaigns:
  - id: CAMP-AB-EXTRA-10
    discount_percent: 10
    valid_from: 2025-11-10T00:00:00Z
    valid_until: 2025-11-30T23:59:59Z

rounding:
  mode: "nearest_0_10"

integration:
  billing_price_list_id: "BILL-PL-VIEN-COFFEE-PASS"
```

---

## 5. OpsProfile Templates

### 5.1 Product-level OpsProfile

```yaml
profile_id: PRF-OPS-VIEN-COFFEE-PASS
profile_type: ops_profile

version: 1
status: active

scope:
  level: product
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass Ops Profile"
  description: "Operational SLOs and alerts for Vienna Coffee Day Pass."
  owner: "ops@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

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
    - id: OPS-ALERT-REDEEM-FAIL
      metric: "entitlement.redeem.error_rate"
      threshold: 0.01
      window: "5m"
      severity: "high"
```

---

## 6. SafetyProfile Templates

### 6.1 Market-level SafetyProfile (Vienna)

```yaml
profile_id: PRF-SAFETY-VIEN-COFFEE-PASS
profile_type: safety_profile

version: 1
status: active

scope:
  level: market
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass Safety Profile"
  description: "Safety and geo/time constraints for Vienna Coffee Day Pass."
  owner: "safety@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

safety:
  min_safety_score: 0.7
  forbidden_tags:
    - "edge.unsafe"

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

### 6.2 Segment-level SafetyProfile override (Kidney segment)

```yaml
profile_id: PRF-SAFETY-VIEN-COFFEE-KIDNEY
profile_type: safety_profile

version: 1
status: active

scope:
  level: segment
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments:
    - kidney
  experiment_key: null

priority: 200

meta:
  title: "Vienna Coffee Pass Safety (Kidney Segment)"
  description: "Stricter safety for kidney-sensitive users."
  owner: "safety@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

safety:
  min_safety_score: 0.8

geo:
  allowed_cities:
    - VIE

content:
  disallow_categories:
    - "alcohol"
    - "smoking"
```

---

## 7. QualityProfile Templates

### 7.1 Product-level QualityProfile

```yaml
profile_id: PRF-QUALITY-VIEN-COFFEE-PASS
profile_type: quality_profile

version: 1
status: active

scope:
  level: product
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass Quality Profile"
  description: "Quality targets and review policies."
  owner: "cx@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

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

## 8. UiProfile Templates

### 8.1 Global UiProfile for coffee passes

```yaml
profile_id: PRF-UI-COFFEE-GLOBAL
profile_type: ui_profile

version: 1
status: active

scope:
  level: global
  market_code: null
  product_ids: []
  segments: []
  experiment_key: null

priority: 10

meta:
  title: "Global Coffee UI Profile"
  description: "Default UI settings for coffee-related products."
  owner: "design@reis.agency"

constraints:
  effective_from: 2025-01-01T00:00:00Z
  effective_until: null

localization:
  default_locale: "en"
  supported_locales:
    - "en"

  title:
    en: "Coffee Pass"

  short_description:
    en: "Discover local coffee spots with one simple pass."

  long_description_md:
    en: """## Coffee pass\nAccess curated partner cafés in your city."""

visual:
  icon_key: "coffee_pass"
  primary_color: "#C98F4A"
  accent_color: "#2B2B2B"

layout:
  grouping_section: "city_passes"
  badges:
    - "coffee"

feature_flags:
  show_loyalty_badge: true
  show_kidney_safe_label: false
```

### 8.2 Market-level UiProfile override (Vienna)

```yaml
profile_id: PRF-UI-VIEN-COFFEE-PASS
profile_type: ui_profile

version: 1
status: active

scope:
  level: market
  market_code: AT-VIE
  product_ids:
    - PRD-VIEN-COFFEE-PASS
  segments: []
  experiment_key: null

priority: 100

meta:
  title: "Vienna Coffee Day Pass UI"
  description: "Localized UI for Vienna Coffee Day Pass."
  owner: "design@reis.agency"

constraints:
  effective_from: 2025-11-01T00:00:00Z
  effective_until: null

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
  accent_color: "#1E1E1E"

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

## 9. Summary

Цей документ дає **ready-to-use профільні YAML-шаблони**:

- базовий skeleton для всіх типів профілів;  
- global / market / product / segment / experiment-приклади;  
- мінімальний, але реалістичний набір полів для Vienna Coffee Day Pass.

Їх можна:
- використовувати як seed-фікстури в репозиторії;  
- копіювати у Registry-адмінку;  
- брати як референс при розробці SDK та валідації профілів.

