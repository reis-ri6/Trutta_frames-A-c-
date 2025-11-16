# PD-005 Trutta Integration Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Token & Settlement Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-002-product-domain-model-templates.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-api.yaml  
- PD-004-tjm-integration-spec.md  
- DOC-02x Trutta Token Standards  
- DOC-03x Trutta Protocol Architecture

---

## 1. Purpose & Scope

### 1.1 Purpose

Описати **контракт між Product DSL / Registry та Trutta** на рівні:

- entitlements (права на послуги/товари);
- claim-flow (отримання/використання/експірація прав);
- swap-моделі (локальні свопи токенів/ентайтлментів);
- settlement (розрахунки з вендорами / пулами / казначейством).

### 1.2 Scope

Входить:

- блок `integrations.trutta` у ProductDef;
- map ProductVersion → Trutta entitlement/settlement профілі;
- lifecycle-правила між статусами продукту та станами entitlements;
- події, які йдуть між Registry/TJM/Product runtime ↔ Trutta.

Не входить:

- внутрішня chain/ledger-реалізація Trutta;
- детальна tokenomics/економічна модель (див. Trutta DOC-02x/03x);
- UI-гаманців, KYC/KYB, fraud-двигуни (окремі Trutta-документи).

---

## 2. Core Concepts (Trutta side)

### 2.1 Entitlement

- Одиниця права на сервіс/товар ("1 coffee", "1 day-pass", "N rides").
- Ключові поля (логічно):
  - `entitlement_id` — стабільний ID;
  - `product_id`, `product_version_id` — прив’язка до продукту;
  - `beneficiary` — wallet/account/аватар;
  - `units` — кількість/мірна одиниця;
  - `state` — `issued/reserved/claimed/redeemed/expired/refunded/cancelled`;
  - `valid_from` / `valid_until`;
  - `origin` — source (product, campaign, sospeso pool, swap, reward).

### 2.2 EntitlementProfile

- Шаблон випуску entitlements для певного продукту та сценаріїв:
  - ліміти (per user / per day / per vendor);
  - тип бенефіціара (користувач/сімейний акаунт/ком’юніті-пул);
  - поведінка при no-show, поверненнях, fraud-флагах;
  - чи є entitlement токеном на публічному/приватному chain.

### 2.3 TokenProfile / SettlementProfile

- **TokenProfile**:
  - як entitlement відображається у токені (fungible/non-fungible, chain, decimals, transfer rules);
  - чи є токен soulbound/escrow/claimable.

- **SettlementProfile**:
  - валюти/пули (USDC, EUR, TRT-пул);
  - правила split’ів (user share, vendor share, protocol fee, city fund);
  - частота settlement (T+1, weekly, on-demand);
  - FX-джерела, rounding rules.

### 2.4 SwapRule

- Описує локальні обміни:
  - які токени/entitlements можна свопати між собою;
  - курс (фіксований, з оракула, з AMM-пула);
  - fee-структура;
  - обмеження (per city/vendor/user/час).

---

## 3. ProductDef → Trutta Mapping

### 3.1 ProductDef.integrations.trutta блок

Мінімальний блок у ProductDef:

```yaml
integrations:
  trutta:
    entitlement_profile_id: TRT-ENT-VIEN-COFFEE-PASS
    settlement_profile_id: TRT-SET-VIEN-COFFEE-PASS
    token_profile_id: TRT-TKN-VIEN-COFFEE-PASS
    swap_profile_id: TRT-SWAP-VIEN-COFFEE-PASS-LOCAL
    emission:
      units_per_product: 5
      unit_label: "coffee"
      usage_policy:
        per_day_per_user: 3
        per_vendor_per_day: 2
      sospeso_enabled: true
```

### 3.2 Mapping table

| ProductDef поле                         | Trutta сутність / поле                         |
|----------------------------------------|-----------------------------------------------|
| `integrations.trutta.entitlement_profile_id` | `EntitlementProfile.id`                    |
| `integrations.trutta.settlement_profile_id`  | `SettlementProfile.id`                     |
| `integrations.trutta.token_profile_id`       | `TokenProfile.id`                          |
| `integrations.trutta.swap_profile_id`        | `SwapRule.profile_id`                      |
| `integrations.trutta.emission.units_per_product` | default units при випуску per product   |
| `integrations.trutta.emission.unit_label`    | label у EntitlementProfile/TokenProfile    |
| `integrations.trutta.emission.usage_policy.*`| usage constraints in EntitlementProfile    |
| `integrations.trutta.emission.sospeso_enabled` | flag для sospeso-пулів                   |

### 3.3 Validation

При ingestion ProductDef (PD-003):

1. Registry валідує, що вказані `*_profile_id` існують у Trutta (через кешовані reference-таблиці або Trutta-capability API).
2. Перевіряє consistency:
   - `product_type` сумісний із EntitlementProfile (наприклад, PASS/MEAL/TOKENIZED_SERVICE);
   - `markets/segments` не конфліктують з Trutta-налаштуваннями.
3. У разі неконсистентності — помилки:
   - `REF_ERROR: TRUTTA_PROFILE_NOT_FOUND`;
   - `POLICY_ERROR: TRUTTA_PROFILE_INCOMPATIBLE`.

---

## 4. Lifecycle: ProductVersion vs Entitlements

### 4.1 Стани ProductVersion

- ProductVersion: `draft/review/active/deprecated/retired` (PD-003).

### 4.2 Стани EntitlementProfile / Entitlements

- EntitlementProfile state:
  - `inactive` — не можна випускати нові entitlements;
  - `issuing` — можна випускати нові;
  - `frozen` — нові не випускаються, старі ще можна погасити;
  - `closed` — нічого не випускається, погашення заборонено (окрім винятків).

- Entitlement state (одиниця): `issued/reserved/claimed/redeemed/expired/refunded/cancelled`.

### 4.3 Узгодження станів (рекомендації)

| ProductVersion.status | EntitlementProfile.state (мінімум) |
|-----------------------|-------------------------------------|
| `draft`               | `inactive`                          |
| `review`              | `inactive`                          |
| `active`              | `issuing`                           |
| `deprecated`          | `frozen`                            |
| `retired`             | `closed`                            |

Синхронізація відбувається через події `product.version.status_changed` → Trutta control-plane (див. розд. 7).

---

## 5. Claim-flow (end-to-end)

### 5.1 Базові ролі

- **Issuer** — система/оператор, що випускає entitlement (продукт, кампанія, донор sospeso, DAO-фонд).
- **Beneficiary** — користувач/аккаунт/ком’юніті-пул, що володіє entitlement.
- **Vendor** — точка сервісу, яка погашає entitlement.

### 5.2 Стандартний флоу

1. **Issue**
   - Подія: `product.entitlement.issue_requested` (з боку Product/TJM/BFF).
   - Trutta перевіряє EntitlementProfile, usage_policy, fraud-правила.
   - Створюється entitlement у стані `issued` (або `reserved`, якщо потрібен додатковий trigger).

2. **Assign / Reserve**
   - Entitlement прив’язується до `beneficiary` (wallet/account/аватар).
   - Може бути `reserved` під конкретний journey/slot/time-window.

3. **Claim**
   - Beneficiary (або агент від його імені) ініціює claim у конкретного vendor:
     - геолокація/QR/NFC/код;
     - Trutta переходить `issued/reserved → claimed` (умови виконані).

4. **Redeem**
   - Vendor підтверджує операцію (через Trutta vendor app/API).
   - Entitlement переходить `claimed → redeemed`.
   - Створюється settlement-entry на користь vendor.

5. **Settle**
   - Periodic або on-demand settlement:
     - агрегація redeemed entitlements;
     - розрахунок payout’ів;
     - створення/оновлення записів у SettlementProfile/pools.

6. **Expire / Refund / Cancel**
   - За правилами EntitlementProfile / ProductDef:
     - `issued/claimed` можуть перейти в `expired` після `valid_until`;
     - можливі `refunded`/`cancelled` згідно ops/policy rules.

> DIAGRAM_PLACEHOLDER #1: "Entitlement claim-flow"  
> Prompt: "Sequence: Product/TJM (issue request) → Trutta (issue/reserve) → User (claim) → Vendor (redeem) → Trutta (settlement) with state changes on entitlement."

---

## 6. Swap-модель (локальні свопи)

### 6.1 Цілі

- Дозволити локальні обміни:
  - між різними product entitlements (кава ↔ десерт, Vienna ↔ Prague);
  - між локальними токенами (TRT-city, скидкові токени тощо);
  - між fiat-деномінаціями (через FX/AMM-пули).

### 6.2 SwapProfile (логічно)

Ключові поля:

- `swap_profile_id` — ID профілю;
- `base_asset` / `quote_asset` — токени/entitlements;
- `pricing_model` — `fixed/oraсle/amm`;
- `fee_model` — протокольні/операторські/вендорські fee;
- `constraints` — ліміти per user, per region, time-window.

Приклад (скорочено):

```yaml
swap_profiles:
  - id: TRT-SWAP-VIEN-COFFEE-PASS-LOCAL
    base_asset: ENT-VIEN-COFFEE-PASS
    quote_asset: TRT-CITY-VIE
    pricing_model:
      type: fixed
      rate: 1.0
    fee_model:
      protocol_fee_bps: 50
      city_fund_bps: 25
    constraints:
      max_per_user_per_day: 5
      allowed_cities: ["VIE"]
```

### 6.3 Зв’язок з ProductDef

- ProductDef може посилатися на один або кілька SwapProfile через `integrations.trutta.swap_profile_id` / список.
- Registry не рахує курси; лише фіксує, які swap-профілі застосовні до продукту.

---

## 7. Settlement модель

### 7.1 Settlement entities (Trutta)

- `SettlementBatch`:
  - набір redeemed entitlements за період (per vendor/per city/per product);
  - статуси: `pending/calculating/ready/paid/error`.
- `SettlementRule`:
  - частота / cut-off time;
  - валютні пули;
  - FX-джерело;
  - who pays fees (user/vendor/protocol).

### 7.2 Mapping з ProductDef

- ProductDef не описує settlement-low-level, але посилається на `settlement_profile_id`:
  - визначає, які правила застосовуються до entitlements цього продукту;
  - Registry зберігає binding `ProductVersion ↔ SettlementProfile`.

### 7.3 Взаємодія з Registry / Analytics

- При створенні/оновленні SettlementBatch Trutta емить події:
  - `settlement.batch.created`;
  - `settlement.batch.paid`.
- Аналітика може:
  - join’ити ці події з `ProductVersion` / `dim_product` з Registry;
  - будувати unit economics per product/city/vendor.

---

## 8. Events & Contracts (Registry/TJM/Product ↔ Trutta)

### 8.1 Events з Registry/Product side

- `product.version.status_changed` — керує EntitlementProfile state (див. табл. 4.3).
- `product.entitlement.issue_requested` — запит на issue entitlements (з payload:
  - `product_version_id`, `user_id/beneficiary`, `units_requested`, `origin`).

### 8.2 Events з Trutta side

Основні типи:

- `entitlement.issued`
- `entitlement.claimed`
- `entitlement.redeemed`
- `entitlement.expired`
- `entitlement.refunded`
- `swap.executed`
- `settlement.batch.created`
- `settlement.batch.paid`

Кожна подія має `correlation` блок, що включає (мінімум):

- `product_id`, `product_version_id`;
- `entitlement_id` (де доречно);
- `user_id` / `vendor_id`;
- `city_code`, `market_code`;
- опційно `journey_instance_id`.

### 8.3 Mapping на Product/TJM runtime

- Через `state_map` (див. PD-004/PD-008):
  - `entitlement.claimed` → `journey.node.entitlement_claimed` → `product.runtime` подія;
  - `entitlement.redeemed` → може тригерити `product.completed` для простих продуктів.

---

## 9. Ownership & Boundaries

### 9.1 Registry / Product DSL

- Own’ить:
  - каталог продуктів і їх binding’и до Trutta профілів (entitlement/settlement/token/swap);
  - lifecycle ProductVersion.
- Не own’ить:
  - стани конкретних entitlements;
  - деталізацію свопів/settlement.

### 9.2 Trutta

- Own’ить:
  - EntitlementProfile, TokenProfile, SettlementProfile, SwapProfile;
  - всі стани entitlements/swaps/settlements;
  - fraud/limit/policy enforcement.

### 9.3 TJM / BFF

- TJM працює з entitlements як з подіями + частково як з runtime-предикатами ("чи є активний entitlement?").
- BFF говорить з Trutta напряму для wallet/claim/redeem flows, але використовує Registry, щоб знати **які** Trutta профілі та правила застосувати для продукту.

---

## 10. Summary

- PD-005 фіксує контракт Product DSL ↔ Trutta:
  - як ProductDef посилається на EntitlementProfile/TokenProfile/SettlementProfile/SwapProfile;
  - як lifecycle продукту узгоджується зі станами entitlement-профілів;
  - як end-to-end claim-flow/settlement працює з точки зору state та подій;
  - як події Trutta інтегруються з Product/TJM runtime.
- Registry залишається точкою, де фіксуються **зв’язки** продуктів із Trutta-профілями; Trutta — виконуючим шаром для токенів, entitlements, свопів і розрахунків.

