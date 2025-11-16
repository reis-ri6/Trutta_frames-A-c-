# PD-009 Financial & Pricing Templates v0.1

**Status:** Draft 0.1  
**Owner:** Finance / Product Architecture

**Related docs:**  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-009-financial.ddl.sql  
- PD-007-product-profiles-templates.md

Мета цього документу — дати **готові темплейти** для:

- фінансової моделі продукту (`financial_model`);
- PricingProfile (базовий, ринковий, сегментний, експериментальний);
- промокампаній та купонів;
- запиту на розрахунок ціни та price quote.

---

## 1. Template: Product Financial Model (YAML)

### 1.1 Simple fixed_split model

```yaml
financial_model:
  base_currency: EUR

  base_cost:
    amount: 10.00
    components:
      vendor_service: 8.00
      operational_overhead: 2.00

  target_gross_price:
    amount: 19.00

  tax_model:
    vat_included: true
    vat_rate_percent: 20

  revenue_model:
    type: fixed_split
    fixed_split:
      vendor_share_percent: 70.0
      platform_fee_percent: 25.0
      partner_fee_percent: 5.0

  fx_policy:
    base_currency: EUR
    allowed_charge_currencies: [EUR, USD]
    pricing_mode: base_then_convert
    fx_source: ECB
    fx_refresh_interval_minutes: 60
    fx_markup_percent: 2.0
```

### 1.2 Cost-plus model with tiered markup

```yaml
financial_model:
  base_currency: EUR

  base_cost:
    amount: 15.00
    components:
      vendor_service: 11.00
      operational_overhead: 4.00

  tax_model:
    vat_included: true
    vat_rate_percent: 10

  revenue_model:
    type: cost_plus
    cost_plus:
      base_markup_percent: 30.0
      tiers:
        - min_quantity: 1
          max_quantity: 9
          markup_percent: 30.0
        - min_quantity: 10
          max_quantity: 49
          markup_percent: 25.0
        - min_quantity: 50
          max_quantity: null
          markup_percent: 20.0

  fx_policy:
    base_currency: EUR
    allowed_charge_currencies: [EUR, USD, GBP]
    pricing_mode: per_market_price
    fx_source: ECB
    fx_refresh_interval_minutes: 120
    fx_markup_percent: 1.0
```

---

## 2. Template: Base PricingProfile (YAML)

### 2.1 Global base profile for a product

```yaml
pricing_profile:
  profile_id: PRF-PRICING-VIEN-COFFEE-PASS
  profile_type: pricing_profile

  version: 1
  status: active

  scope:
    level: product
    market_code: null
    product_ids: [PRD-VIEN-COFFEE-PASS]
    segments: []
    experiment_key: null

  priority: 100

  constraints:
    effective_from: 2025-11-01T00:00:00Z
    effective_until: null

  base_price:
    currency: EUR
    amount: 19.00
    ppu_code: VIEN-COFFEE-PASS
    unit_type: pass
    unit_quantity: 1

  rounding:
    mode: nearest_0_10

  guards:
    min_margin_percent: 20.0
    max_discount_percent: 50.0
    require_revenue_model_match: true

  integration:
    billing_price_list_id: BILL-PL-VIEN-COFFEE-PASS
    trutta_pricing_ref: TRT-PRICE-VIEN-COFFEE-PASS
```


### 2.2 Market-level override profile (e.g. Berlin)

```yaml
pricing_profile:
  profile_id: PRF-PRICING-BER-COFFEE-PASS
  profile_type: pricing_profile

  version: 1
  status: active

  scope:
    level: market
    market_code: DE-BER
    product_ids: [PRD-VIEN-COFFEE-PASS]
    segments: []
    experiment_key: null

  priority: 120

  constraints:
    effective_from: 2025-11-01T00:00:00Z
    effective_until: null

  base_price:
    currency: EUR
    amount: 21.00
    ppu_code: VIEN-COFFEE-PASS
    unit_type: pass
    unit_quantity: 1

  rounding:
    mode: nearest_0_10

  guards:
    min_margin_percent: 22.0
    max_discount_percent: 40.0
    require_revenue_model_match: true

  integration:
    billing_price_list_id: BILL-PL-BER-COFFEE-PASS
    trutta_pricing_ref: TRT-PRICE-BER-COFFEE-PASS
```

---

## 3. Template: Overrides (market / channel / segment / time)

### 3.1 Overrides YAML (conceptual, maps to `product_pricing_overrides` rows)

```yaml
pricing_overrides:
  - id: OV-MARKET-AT-VIE
    override_type: market
    market_code: AT-VIE
    price_delta_amount: 0.00
    price_delta_percent: 0.0
    priority: 100

  - id: OV-CHANNEL-B2B
    override_type: channel
    channel: b2b_partner
    price_delta_amount: null
    price_delta_percent: -10.0  # 10% discount
    priority: 150

  - id: OV-SEGMENT-LOCAL
    override_type: segment
    segment_key: local_resident
    price_delta_percent: -10.0
    priority: 160

  - id: OV-TIME-HIGH-SEASON
    override_type: time_window
    valid_from: 2025-12-15T00:00:00Z
    valid_until: 2026-01-15T23:59:59Z
    price_delta_percent: 20.0   # +20% in high season
    priority: 90
```

> На рівні БД це розкладається в `product_pricing_overrides`.

---

## 4. Template: Campaigns & Coupons (YAML)

### 4.1 Campaign attached to profile

```yaml
campaigns:
  - campaign_id: CAMP-VIEN-LAUNCH
    pricing_profile_id: PRF-PRICING-VIEN-COFFEE-PASS
    campaign_type: promo_percent

    discount_percent: 15.0
    discount_amount: null

    channels: ["direct", "mobile_app"]

    valid_from: 2025-11-01T00:00:00Z
    valid_until: 2025-11-15T23:59:59Z

    priority: 100
    meta:
      description: "Launch promo for Vienna coffee pass"
```

### 4.2 Global coupon + binding to profiles

```yaml
coupon:
  coupon_code: VIENCOFFEE10
  campaign_type: promo_percent

  discount_percent: 10.0
  discount_amount: null

  base_currency: EUR

  max_redemptions: 1000
  per_user_limit: 1

  valid_from: 2025-11-01T00:00:00Z
  valid_until: 2025-12-31T23:59:59Z

  allowed_channels: ["direct", "mobile_app", "b2b_partner"]
  allowed_markets: ["AT-VIE", "DE-BER"]

  meta:
    description: "Generic 10% coupon for Vienna coffee pass"

coupon_profiles:
  - coupon_code: VIENCOFFEE10
    pricing_profile_id: PRF-PRICING-VIEN-COFFEE-PASS

  - coupon_code: VIENCOFFEE10
    pricing_profile_id: PRF-PRICING-BER-COFFEE-PASS
```

---

## 5. Template: Price Calculation Request (JSON)

### 5.1 Rating request

```json
{
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "market_code": "AT-VIE",

  "user_id": "USR-0001",
  "segments": ["tourist", "kidney"],

  "channel": "mobile_app",
  "experiment_keys": ["vien_coffee_ab_10off"],

  "requested_currency": "EUR",
  "quantity": 1,

  "coupon_codes": ["VIENCOFFEE10"]
}
```

---

## 6. Template: Price Quote Response (JSON)

### 6.1 Successful quote

```json
{
  "price_quote_id": "PQUOTE-2025-11-01-0001",

  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "pricing_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",

  "market_code": "AT-VIE",
  "requested_currency": "EUR",

  "unit_currency": "EUR",
  "unit_price": 17.00,
  "quantity": 1,
  "total_price": 17.00,

  "original_price": 19.00,
  "total_discount_percent": 10.53,

  "fx_rate": 1.0,
  "fx_base_currency": "EUR",
  "fx_source": "ECB",

  "status": "final",

  "applied_layers": {
    "base_price_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",
    "override_ids": ["OV-MARKET-AT-VIE"],
    "campaign_ids": ["CAMP-VIEN-LAUNCH"],
    "coupon_codes": ["VIENCOFFEE10"],
    "experiment_keys": ["vien_coffee_ab_10off"]
  },

  "segments": ["tourist", "kidney"],
  "channel": "mobile_app",
  "experiment_keys": ["vien_coffee_ab_10off"],
  "coupon_codes": ["VIENCOFFEE10"],

  "created_at": "2025-11-01T10:15:00Z",
  "expires_at": "2025-11-01T10:20:00Z"
}
```

### 6.2 Quote rejected by guards

```json
{
  "price_quote_id": "PQUOTE-2025-11-01-0002",

  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "pricing_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",

  "status": "rejected",

  "applied_layers": {
    "reason": "MIN_MARGIN_VIOLATION",
    "min_margin_required": 20.0,
    "margin_after_discounts": 12.5
  }
}
```

---

## 7. Template: FX Rate Cache Row (JSON)

```json
{
  "base_currency": "EUR",
  "quote_currency": "USD",
  "rate": 1.08500000,
  "rate_source": "ECB",
  "pricing_mode": "base_then_convert",
  "as_of": "2025-11-01T10:00:00Z",
  "meta": {
    "notes": "Official ECB rate, intraday snapshot"
  }
}
```

---

## 8. Usage Notes

- Ці темплейти відповідають DDL з **PD-009-financial.ddl.sql** і можуть бути:
  - зберігані як YAML/JSON у schema-store;
  - трансформовані в записи таблиць `product_costs`, `product_pricing_profiles`, `product_pricing_overrides`, `product_pricing_campaigns`, `product_pricing_coupons`, `fx_rates_cache`, `product_price_quotes`.
- Рекомендовано тримати **source-of-truth у вигляді YAML/JSON** у репозиторії й генерувати SQL/міграції автоматично поверх цих структур (tooling описується в PD-012).

