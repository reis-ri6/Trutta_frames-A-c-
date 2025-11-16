# PD-005 Trutta Templates v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Token & Settlement Architecture

**Related docs:**  
- PD-005-trutta-integration-spec.md  
- PD-005-trutta-ddl.sql  
- DOC-02x Trutta Token Standards  
- DOC-03x Trutta Protocol Architecture

Мета документа — надати **еталонні шаблони** для інтеграції продуктів з Trutta:

- EntitlementProfile + entitlement JSON;
- TokenProfile (fungible / pass / soulbound / escrow-like);
- SwapRule / SwapProfile.

Усі приклади — для продукту **Vienna Coffee Day Pass**.

---

## 1. Entitlement Issue Request (runtime payload)

> Використовується Product/TJM/BFF для запиту випуску entitlements.

```json
{
  "event_type": "product.entitlement.issue_requested",
  "source": "bff.app",
  "occurred_at": "2025-12-01T08:05:00Z",
  "correlation": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "user_id": "USR-0001",
    "journey_instance_id": "JRN-00012345",
    "city_code": "VIE",
    "market_code": "AT-VIE"
  },
  "payload": {
    "units_requested": 5,
    "origin_type": "product",
    "origin_ref": "ORD-987654321",
    "beneficiary": {
      "beneficiary_id": "USR-0001",
      "beneficiary_type": "user"
    }
  }
}
```

---

## 2. EntitlementProfile Template (logical YAML)

> Логічний профіль, з яким зв’язується Product через `integrations.trutta.entitlement_profile_id`.

```yaml
id: TRT-ENT-VIEN-COFFEE-PASS
kind: entitlement_profile

meta:
  title: "Vienna Coffee Day Pass Entitlements"
  description: "Up to 5 coffees per day-pass user in Vienna."
  owner: "trutta-core@reis.agency"

product_binding:
  allowed_product_types:
    - PASS
  allowed_product_ids:
    - PRD-VIEN-COFFEE-PASS
  markets:
    - AT-VIE

unit:
  label: "coffee"
  decimals: 0

emission:
  units_per_product: 5
  per_user_limits:
    per_day: 3
    total_per_product_instance: 5
  per_vendor_limits:
    per_vendor_per_day: 2

validity:
  default_valid_from_offset_hours: 0
  default_valid_until_offset_hours: 48

sospeso:
  enabled: true
  pools:
    - id: TRT-SOSPESO-VIE-COFFEE
      max_units_per_user_per_day: 2

fraud_policies:
  require_geo_check: true
  require_vendor_binding: true
  max_devices_per_user_per_day: 3

state_machine:
  initial_state: issued
  terminal_states:
    - redeemed
    - expired
    - refunded
    - cancelled
```

---

## 3. Entitlement Record Template (DB JSON view)

> Вигляд одного entitlement’а, сумісний із `trutta_entitlement` (PD-005-trutta-ddl.sql).

```json
{
  "entitlement_id": "ENT-VIEN-COFFEE-PASS-000001",
  "product_id": "PRD-VIEN-COFFEE-PASS",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "beneficiary_id": "USR-0001",
  "beneficiary_type": "user",
  "units_total": "5.000000",
  "units_remaining": "5.000000",
  "unit_label": "coffee",
  "state": "issued",
  "valid_from": "2025-12-01T08:05:00Z",
  "valid_until": "2025-12-03T08:05:00Z",
  "origin_type": "product",
  "origin_ref": "ORD-987654321",
  "market_code": "AT-VIE",
  "city_code": "VIE",
  "issued_at": "2025-12-01T08:05:01Z",
  "issued_by": "svc-trutta-issuer",
  "updated_at": "2025-12-01T08:05:01Z",
  "updated_by": null
}
```

---

## 4. TokenProfile Templates

> Логічні профілі, що описують, як entitlement відображається у токені.

### 4.1 Fungible city pass token (internal only)

```yaml
id: TRT-TKN-VIEN-COFFEE-PASS
kind: token_profile

meta:
  title: "Vienna Coffee Day Pass Token"
  description: "Internal fungible token representing coffee entitlements for a day-pass."
  owner: "trutta-core@reis.agency"

chain:
  type: internal_ledger
  network: "trutta-internal"

asset:
  token_standard: "FUNGIBLE_INTERNAL"
  symbol: "VIECOFFEE"
  decimals: 0

linkage:
  entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS
  units_per_token: 1

transfer_rules:
  transferable: false
  allow_transfer_to:
    - "community_pool"
  burn_on_redeem: true

visibility:
  show_in_wallet: true
  show_unit_breakdown: true
```

### 4.2 Soulbound off-chain pass (no free transfer)

```yaml
id: TRT-TKN-VIEN-COFFEE-PASS-SB
kind: token_profile

meta:
  title: "Vienna Coffee Day Pass (soulbound)"
  owner: "trutta-core@reis.agency"

chain:
  type: offchain

asset:
  token_standard: "SOULBOUND_PASS"
  symbol: "VIEPASS"
  decimals: 0

linkage:
  entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS

transfer_rules:
  transferable: false
  delegation_allowed: true
  delegation_scopes:
    - "journey_proxy"   # агент/копілот може діяти від імені власника

visibility:
  show_in_wallet: true
```

### 4.3 Escrow-like token (requires external trigger)

```yaml
id: TRT-TKN-VIEN-COFFEE-PASS-ESCROW
kind: token_profile

meta:
  title: "Vienna Coffee Day Pass (escrow)"
  owner: "trutta-core@reis.agency"

chain:
  type: public_chain
  network: "polygon"

asset:
  token_standard: "ERC-20-ESCROWED"
  symbol: "VIECOFF-ESC"
  decimals: 6

linkage:
  entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS

transfer_rules:
  transferable: true
  transfer_requires_kyc: true
  unlock_triggers:
    - "KYC_PASSED"
    - "JOURNEY_STARTED"

visibility:
  show_in_wallet: true
  show_escrow_state: true
```

---

## 5. SwapRule / SwapProfile Templates

> Частково дублює логіку `trutta_swap_rule`, але у вигляді більш високорівневого YAML.

### 5.1 Local coffee swap (entitlement ↔ city token)

```yaml
id: TRT-SWAP-VIEN-COFFEE-PASS-LOCAL
kind: swap_profile

meta:
  title: "Vienna Coffee ↔ City token swap"
  description: "Local swap between coffee entitlements and Vienna city token."
  owner: "trutta-core@reis.agency"

base_asset:
  type: "entitlement"
  id: "ENT-VIEN-COFFEE-PASS"   # logical id; фактична група entitlements

quote_asset:
  type: "token"
  id: "TRT-CITY-VIE"

pricing_model:
  type: "fixed"
  rate: 1.0   # 1 coffee entitlement = 1 city token

fees:
  protocol_fee_bps: 50        # 0.50%
  operator_fee_bps: 25        # 0.25%
  city_fund_fee_bps: 25       # 0.25%

constraints:
  max_per_user_per_day: 5
  max_per_tx: 5
  allowed_cities:
    - "VIE"
  allowed_markets:
    - "AT-VIE"

lifecycle:
  is_active: true
```

### 5.2 Cross-city swap (Vienna → Prague coffee)

```yaml
id: TRT-SWAP-VIEN-COFFEE-PASS-CROSS
kind: swap_profile

meta:
  title: "Vienna → Prague Coffee Swap"
  owner: "trutta-core@reis.agency"

base_asset:
  type: "entitlement"
  id: "ENT-VIEN-COFFEE-PASS"

quote_asset:
  type: "entitlement"
  id: "ENT-PRAG-COFFEE-PASS"

pricing_model:
  type: "oracle"
  oracle_source_id: "ORC-CITY-COFFEE-INDEX"

fees:
  protocol_fee_bps: 100     # 1.00%
  operator_fee_bps: 0
  city_fund_fee_bps: 50

constraints:
  max_per_user_per_day: 3
  allowed_cities:
    - "VIE"
    - "PRG"

lifecycle:
  is_active: false   # може бути активовано пізніше
```

---

## 6. ProductDef.integrations.trutta Example (concrete)

> Пов’язує конкретний ProductVersion з профілями вище.

```yaml
integrations:
  trutta:
    entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS
    settlement_profile_id:  TRT-SET-VIEN-COFFEE-PASS
    token_profile_id:       TRT-TKN-VIEN-COFFEE-PASS
    swap_profile_id:        TRT-SWAP-VIEN-COFFEE-PASS-LOCAL
    emission:
      units_per_product: 5
      unit_label: "coffee"
      usage_policy:
        per_day_per_user: 3
        per_vendor_per_day: 2
      sospeso_enabled: true
```

---

## 7. Summary

Ці шаблони задають опорні форми:

- як виглядає запит на випуск entitlement;
- як описати EntitlementProfile / TokenProfile / SwapProfile у YAML;
- як виглядає entitlement у БД;
- як ProductDef прив’язує себе до цих Trutta-профілів.

Вони мають бути використані як еталон у SDK, тест-фікстурах та документації для інтеграторів.

