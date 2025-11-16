# PD-009 Financial & Pricing Profile Spec v0.1

**Status:** Draft 0.1  
**Owner:** Finance / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-007-product-profiles-spec.md  
- PD-007-product-profiles-templates.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-008-product-runtime-events.md  
- PD-010-ops-safety-and-quality-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Формалізувати **фінансову модель продукту** та **PricingProfile**, які визначають:

- як рахується кінцева ціна для користувача;
- як розподіляється виручка (revenue-split) між вендорами / платформою / партнерами;
- як працює FX (валютні конверсії) на рівні продукту;
- як застосовуються промо (кампанії, купони, експерименти).

### 1.2 Scope

Входить:

- логічна модель Product Financial Model;  
- структура PricingProfile як частини Product Profiles;  
- правила розрахунку ціни та маржі;  
- зв’язки з Trutta settlement та billing/rating-сервісами.

Не входить:

- фізична DDL (PD-009-financial.ddl.sql);  
- конкретні YAML/JSON-фікстури (PD-009-financial-templates.md);  
- деталі інтеграції з PSP/банками.

---

## 2. Core Concepts

### 2.1 Product Priceable Unit (PPU)

**Product Priceable Unit (PPU)** — мінімальна одиниця, яка має ціну у фінансовій моделі.

Приклади:

- 1 Vienna Coffee Day Pass (фіксований пакет);  
- 1 ніч проживання в готелі;  
- 1 квиток на подію;  
- 1 токен/entitlement на страву чи напій.

Поля (логічно):

- `ppu_code` — унікальний код (в рамках продукту/категорії);
- `unit_type` — `pass|night|ticket|token|seat|other`;
- `unit_quantity` — скільки реальних прав/послуг за PPU (наприклад, 5 кав у пасі).

### 2.2 Product Financial Model

Фінансова модель задає, як PPU перетворюється на:

- ціну для кінцевого користувача;
- витрати (cost) і маржу;
- оплату вендорів (settlement);
- плату платформі та партнерам.

Основні блоки:

- `base_cost` — очікувана собівартість PPU (в одній базовій валюті);
- `revenue_model` — опис розподілу виручки;
- `tax_model` — high-level інформація про ПДВ/податки (деталі можуть бути в окремому TaxService);
- `fx_policy` — як робити FX-конверсії.

### 2.3 PricingProfile (огляд)

PricingProfile — один з Product Profiles (див. PD-007). Він описує:

- базову ціну продукту / PPU в базовій валюті;
- overrides для ринків/сегментів/каналів/експериментів;
- промо-кампанії, купони, A/B pricing;
- rounding/presentation правила;
- інтеграцію з billing/Trutta.

Registry резолвить **effective PricingProfile** для контексту `(product_version, market, segment, experiment)`.

---

## 3. Financial Model Structure

### 3.1 Base cost & gross price

Логічна структура:

```yaml
financial_model:
  base_currency: EUR

  base_cost:
    amount: 10.00          # очікувана собівартість PPU
    components:
      vendor_service: 8.00
      operational_overhead: 2.00

  target_gross_price:
    amount: 19.00          # рекомендована ціна PPU (до промо)

  tax_model:
    vat_included: true
    vat_rate_percent: 20
```

Ці поля використовуються Finance/analytics, але можуть впливати на обмеження в PricingProfile (мін. маржа).

### 3.2 Revenue model

`revenue_model` визначає розподіл виручки:

```yaml
financial_model:
  revenue_model:
    type: fixed_split  # fixed_split | tiered_split | cost_plus
    fixed_split:
      vendor_share_percent: 70
      platform_fee_percent: 25
      partner_fee_percent: 5
```

Інші варіанти:

- `tiered_split` — залежить від обсягу (наприклад, зростаюча знижка вендору при високому обсязі);  
- `cost_plus` — `price = cost * (1 + markup_percent)` із target-маржею.

### 3.3 FX policy

Фіксує, як продукт працює з мультивалютністю:

```yaml
financial_model:
  fx_policy:
    base_currency: EUR
    allowed_charge_currencies: [EUR, USD]
    pricing_mode: "base_then_convert"  # base_then_convert | per_market_price
    fx_source: "ECB"                   # джерело курсів
    fx_refresh_interval_minutes: 60
    fx_markup_percent: 2.0              # додатковий націнковий відсоток на FX
```

Інваріанти:

- `base_currency` = валюта збереження базових цін у Registry;  
- якщо `pricing_mode = per_market_price`, то FX використовується для аналітики, а не для фінальної ціни.

---

## 4. PricingProfile Structure

### 4.1 Identity & scope (наслідує підхід з PD-007)

```yaml
pricing_profile:
  profile_id: PRF-PRICING-...
  profile_type: pricing_profile

  version: 1
  status: active

  scope:
    level: global|market|product|segment|experiment
    market_code: AT-VIE
    product_ids: [PRD-VIEN-COFFEE-PASS]
    segments: [tourist]
    experiment_key: vien_coffee_ab_10off

  priority: 100

  constraints:
    effective_from: 2025-11-01T00:00:00Z
    effective_until: null
```

### 4.2 Base price & unit

```yaml
pricing_profile:
  base_price:
    currency: EUR
    amount: 19.00
    ppu_code: "VIEN-COFFEE-PASS"
    unit_type: "pass"
    unit_quantity: 1
```

Важливо: `base_price.amount` — **до** застосування промо/дисконту/експериментів, але з урахуванням рівня (global/market/product).

### 4.3 Overrides & layers

PricingProfile працює шарами:

1. Base price (цяго профілю чи успадкований);  
2. Market overrides;  
3. Channel/segment overrides;  
4. Time windows (seasonality);  
5. Experiments;  
6. Promo/discounts.

Приклад:

```yaml
pricing_profile:
  market_overrides:
    - market_code: AT-VIE
      currency: EUR
      amount: 19.00
    - market_code: DE-BER
      currency: EUR
      amount: 21.00

  channel_overrides:
    - channel: "b2b_partner"
      discount_percent: 10

  segment_overrides:
    - segment_key: "local_resident"
      discount_percent: 10

  time_windows:
    - id: "high_season"
      valid_from: 2025-12-15T00:00:00Z
      valid_until: 2026-01-15T23:59:59Z
      price_delta_percent: 20
```

### 4.4 Campaigns & promo

```yaml
pricing_profile:
  campaigns:
    - id: CAMP-VIEN-LAUNCH
      type: "promo_percent"        # promo_percent | promo_fixed | voucher
      discount_percent: 15
      valid_from: 2025-11-01T00:00:00Z
      valid_until: 2025-11-15T23:59:59Z
      channels: ["direct", "mobile_app"]

  coupons:
    - code: "VIENCOFFEE10"
      type: "promo_percent"
      discount_percent: 10
      max_redemptions: 1000
      per_user_limit: 1
      valid_from: 2025-11-01T00:00:00Z
      valid_until: 2025-12-31T23:59:59Z
```

### 4.5 Rounding & presentation

```yaml
pricing_profile:
  rounding:
    mode: "nearest_0_10"   # none | nearest_0_05 | nearest_0_10 | custom

  presentation:
    show_strikethrough_price: true
    show_discount_badge: true
```

### 4.6 Constraints & guards

```yaml
pricing_profile:
  guards:
    min_margin_percent: 15.0   # проти financial_model.base_cost
    max_discount_percent: 50.0 # включно з усіма промо/купон/експериментами
    require_revenue_model_match: true
```

Інваріанти:

- кінцева ціна **не може** зменшити маржу нижче `min_margin_percent`;  
- сумарний дисконт (кампанії + купон + експеримент) обмежений `max_discount_percent`.

### 4.7 Integration hooks

```yaml
pricing_profile:
  integration:
    billing_price_list_id: "BILL-PL-VIEN-COFFEE-PASS"
    trutta_pricing_ref: "TRT-PRICE-VIEN-COFFEE-PASS"  # якщо Trutta має свої цінові профілі
```

---

## 5. Price Calculation Pipeline

### 5.1 Inputs

Rating/pricing-сервіс отримує запит типу:

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

### 5.2 Steps

1. **Resolve config:**  
   - Registry → ProductVersion + financial_model + effective PricingProfile.
2. **Determine base price:**  
   - застосувати base_price + market_overrides.
3. **Apply channel/segment/time overrides:**  
   - скоригувати ціну згідно `channel_overrides`, `segment_overrides`, `time_windows`.
4. **Apply experiments:**  
   - якщо є experiment-level PricingProfile, він може додати/змінити знижку.
5. **Apply campaigns & coupons:**  
   - послідовно або за визначеною політикою (наприклад, спочатку кампанії, потім купони).
6. **FX conversion:**  
   - якщо `requested_currency != base_currency`, застосувати `fx_policy`.
7. **Guards:**  
   - перевірити `min_margin_percent`, `max_discount_percent`;  
   - у разі порушення — або скоригувати знижку, або відхилити запит.
8. **Rounding & presentation:**  
   - застосувати `rounding.mode` и підготувати presentation-поля.

### 5.3 Output (Price Quote)

```json
{
  "price_quote_id": "PQUOTE-0001",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",

  "currency": "EUR",
  "unit_price": 17.00,
  "quantity": 1,
  "total_price": 17.00,

  "original_price": 19.00,
  "total_discount_percent": 10.53,

  "applied_layers": {
    "base_price_profile_id": "PRF-PRICING-VIEN-COFFEE-PASS",
    "campaign_ids": ["CAMP-VIEN-LAUNCH"],
    "coupon_codes": ["VIENCOFFEE10"],
    "experiment_keys": ["vien_coffee_ab_10off"]
  },

  "fx": {
    "base_currency": "EUR",
    "rate": 1.0,
    "fx_source": "ECB",
    "fx_applied": false
  }
}
```

Цей quote потім передається в payment/Trutta як частина order/issue.

---

## 6. Revenue Split & Settlement Links

### 6.1 From price to settlement

Зв’язок з Trutta:

- PricingProfile визначає **цінову сторону**;  
- Trutta settlement profile (див. PD-005) визначає **розподіл виплат**.

Приблизна логіка:

```text
user_price (gross)
  → розкладання на net + tax
  → застосування revenue_model (vendor/platform/partner)
  → агрегування по періоду
  → settlement.performed events
```

### 6.2 Invariants

- Для даного продукту/PPU у визначеному періоді не повинно бути суперечливих revenue_model’ів;  
- зміна `revenue_model` вимагає governance-апруву (PD-013) і не застосовується заднім числом;
- PricingProfile **не може** відмінити гарантії в Trutta settlement (наприклад, мінімальний payout вендору).

---

## 7. Governance & Safety

- Будь-які зміни у financial_model або PricingProfile:
  - проходять через approval-флоу (PD-013-governance);  
  - логуються як версії в Registry;  
  - емлять `product.profile.updated`.

- Агенти **можуть пропонувати**, але не застосовувати напряму зміни до фінансової/цінової моделі (лише через governance).

- Ops/Safety-агенти можуть тимчасово блокувати промо/кампанії, якщо вони ведуть до підозрілої активності (взаємодія з Risk/Fraud Engine).

---

## 8. Summary

- PD-009 задає логічну фінансову модель продукту та semantics для PricingProfile.  
- Rating/billing-сервіси працюють тільки через Registry + PricingProfile, не зберігаючи свою ad-hoc логіку цін.  
- Revenue-split, FX та промо моделюються прозоро й версіонуються, що дозволяє робити експерименти без втрати контролю за маржею та ризиками.

