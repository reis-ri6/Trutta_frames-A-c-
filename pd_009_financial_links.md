# PD-009 Financial Links v0.1

**Status:** Draft 0.1  
**Owner:** Finance / Platform Architecture

**Related docs:**  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-005-trutta-links.md  
- PD-007-product-profiles-links.md  
- PD-008-product-runtime-events.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-009-financial.ddl.sql  
- PD-009-financial-templates.md  
- PD-010-ops-safety-and-quality-spec.md  
- PD-013-governance-and-compliance-spec.md

Мета — описати **зв’язки фінансового шару** (financial_model + PricingProfile + price_quotes) з:

- billing / invoicing / PSP;
- Trutta settlement (entitlements, payouts);
- аналітикою unit economics.

Фокус — потоки даних, контрактні інваріанти, reconciliation.

---

## 1. Components & Boundaries

### 1.1 Logical components

- **Registry** — source-of-truth для ProductVersion, financial_model, PricingProfile.  
- **Rating / Pricing Service** — синхронний сервіс розрахунку ціни, працює лише на читання з Registry + FX-cache.
- **Order / Billing Service** — створення замовлень, інтеграція з PSP, фінальна фіксація ціни.
- **Trutta Core** — issue/redeem entitlements/tokens, settlement-профілі, payout-розрахунки.
- **Ledger / Accounting** (може бути зовнішній) — фінансовий облік, GL-проведення.
- **Analytics / DWH** — unit economics, product/market/segment P&L.

### 1.2 Boundaries

- Rating не зберігає власних тарифів — лише читає Registry та пише `product_price_quotes`.  
- Billing не перераховує ціну самостійно — використовує або price quote, або рейтинговий API з чітко визначеним режимом (re-quote з тими ж параметрами).  
- Trutta не визначає користувацьку ціну — лише payout’и та settlement згідно своїх профілів.

---

## 2. Rating → Billing → Trutta: Main Flow

### 2.1 Rating step (pre-purchase)

1. Frontend / runtime викликає **Rating Service** з запитом (див. PD-009-templates).  
2. Rating:
   - читає ProductVersion + financial_model + PricingProfile з Registry;  
   - читає FX із `fx_rates_cache`;  
   - рахує ціну (pipeline PD-009-spec);  
   - пише запис у `product_price_quotes` зі статусом `final` або `rejected`.

Key invariant:

- `product_price_quotes.price_quote_id` може бути використаний downstream як **immutable reference** на розрахунок.

### 2.2 Billing step (order creation)

1. Billing отримує запит на створення order’а:

```json
{
  "product_version_id": "PRDV-...",
  "quantity": 1,
  "price_quote_id": "PQUOTE-...",  
  "user_id": "USR-...",
  "payment_method": "card|wallet|other"
}
```

2. Billing:
   - витягує `product_price_quotes` по `price_quote_id`;  
   - перевіряє `status = 'final'`, `expires_at` не в минулому;  
   - **не перераховує** ціну, лише використовує зафіксоване значення.

3. Після успішного платежу (PSP):
   - створює order/charge у власній моделі;  
   - емить подію `billing.charge.succeeded` (поза PD-008, окремий namespace);  
   - тригерить Product Runtime для активації продукту.

### 2.3 Trutta step (entitlements / tokens)

- Runtime (PRG) після `payment_captured` викликає Trutta:
  - з посиланням на product_version, order, price_quote (якщо потрібно);  
  - з профілем Trutta (entitlement_profile, settlement_profile).

- Trutta створює entitlements/tokens, емить `entitlement.issued` / `token.issued` (див. PD-008-events).  
- Надалі Redemption/Settlement теж йдуть через Trutta з власними event’ами.

Key invariant:

- Усі суми у Trutta settlement профілях повинні бути **узгоджені** з financial_model/revenue_model; при зміні — governance (PD-013).

---

## 3. Data Contracts Between Layers

### 3.1 Registry → Rating

- Режим **read-only**; Registry повертає:
  - ProductVersion (ідентифікатори, ppu_code);  
  - financial_model (base_cost, revenue_model, fx_policy);  
  - PricingProfile (base_price, overrides, promo/guards).

Rating **не кешує** фінмоделі локально довше, ніж це визначено TTL (конфігurable; дефолт — хвилини). При зміні профілю Registry емить `product.profile.updated` → Rating інвалідовує кеш.

### 3.2 Rating → Billing

- Contract через `product_price_quotes` + API Rating’у:
  - Billing може прийти **з quote_id** або з повним запитом;  
  - якщо без quote_id, Billing має бути готовий прийняти невеликий дрейф (курси FX, час), або явно працювати в режимі "hard match" (`if_reprice_diff > threshold → reject`).

Рекомендація:

- У проді використовувати `price_quote_id` як обов’язковий для складних продуктів.

### 3.3 Billing → Trutta

- Trutta отримує тільки **нетто-інформацію**, потрібну для issue/settlement:

```json
{
  "order_id": "ORD-...",
  "product_version_id": "PRDV-...",
  "ppu_code": "VIEN-COFFEE-PASS",
  "quantity": 1,
  "currency": "EUR",
  "total_price_gross": 17.00,
  "tax_amount": 2.83,
  "total_price_net": 14.17,
  "revenue_model_ref": "FM-VIEN-COFFEE-PASS-V1"
}
```

Trutta не перераховує ціну, а застосовує свій settlement_profile до `total_price_net`.

---

## 4. Settlement & Revenue Split

### 4.1 Settlement profile (Trutta)

- Кожен продукт/market має Trutta settlement_profile, який відзеркалює `financial_model.revenue_model` (див. PD-005).  
- У settlement-профілі визначені:
  - vendor payout share;  
  - platform fee;  
  - partner/distributor share;  
  - період (daily/weekly/monthly) та мінімальні threshold’и.

### 4.2 From transactions to settlement

1. Користувачі redeem’ять entitlements → `entitlement.redeemed` events (PD-008).  
2. Trutta агрегує redemption’и за **профілем + вендором + періодом**.  
3. На основі `total_price_net` і revenue_model рахується:
   - `vendor_gross`, `platform_fee`, `partner_fee`.
4. Trutta емить `settlement.performed` з агрегованими сумами.  
5. Ledger/Accounting та external payout-системи використовують ці події як джерело правди.

Інваріант:

- сума payout’ів по всіх вендорах + fees = агрегований net revenue (до податків) з order/charge-даних Billing + FX-адаптацією.

---

## 5. Unit Economics & Analytics

### 5.1 Data sources

Для аналітики unit economics використовуються:

- `product_costs` — очікувана собівартість на PPU/версію;  
- `product_price_quotes` — фактичні user-facing ціни і дисконти;  
- події:
  - `product.runtime.*` (session lifecycle),
  - `entitlement.issued/redeemed/expired`,
  - `settlement.performed`,
  - billing events (`billing.charge.*`).

### 5.2 Core metrics

На рівні продукт/market/segment/канал/період агрегуються:

- **GMV** — сума `total_price` з `product_price_quotes` / order’ів;  
- **Net revenue** — GMV мінус податки та частка вендора/партнерів;  
- **COGS** — сума `product_costs.base_cost_amount * quantity`;  
- **Gross margin** — `(Net revenue - COGS) / Net revenue`;  
- **LTV/CAC** — поверх користувацьких і маркетингових даних (поза цього PD, але GMV/маржа йдуть звідси);  
- **Break-even usage** — скільки redeem’ів/сесій потрібно для окупності фіксованих витрат.

### 5.3 Data model in DWH (логічно)

- Fact-таблиці:
  - `fact_orders` / `fact_charges`;  
  - `fact_redemptions` (на основі `entitlement.redeemed`);  
  - `fact_settlements` (на основі `settlement.performed`);  
  - `fact_price_quotes` (копія `product_price_quotes`).

- Dimension-таблиці:
  - `dim_product_version`, `dim_market`, `dim_vendor`, `dim_segment`, `dim_channel`.

- Link-таблиці:
  - `order_price_quote_link`, `order_entitlement_link`, `entitlement_settlement_link`.

Ціль — забезпечити можливість повністю відтрейсити шлях:  
**product_version → price_quote → order → entitlements → redemption → settlement → P&L**.

---

## 6. Reconciliation & Controls

### 6.1 Daily reconciliation

Мінімальний набір контролів:

1. `Σ order_gross` (Billing) ≈ `Σ price_quotes.total_price` (Rating) за період.  
2. `Σ settlement.vendor_gross + platform_fee + partner_fee` ≈ `Σ net_revenue` з Billing.  
3. `Σ COGS` з `product_costs` * фактичні PPU (redemptions) порівнюється з очікуваною собівартістю.

Всі розбіжності > заданого порогу → `ops.incident.created`.

### 6.2 Config drift protection

- При зміні `financial_model` чи PricingProfile для активного продукту:
  - Registry створює нову версію, стара лишається для історичних order’ів;  
  - Rating ніколи не змінює існуючі `product_price_quotes`;  
  - Trutta settlement профілі версіонуються; не можна змінити правило заднім числом.

### 6.3 Guardrails for agents & ops

- Агенти не можуть:
  - напряму змінити financial_model/PricingProfile;  
  - змінювати settlement-профілі;  
  - вручну фіксувати виплати.

- Ops може:
  - тимчасово вимкнути кампанії/купони;  
  - зупинити нові продажі продукту;  
  - виконати компенсуючі виплати через окремі playbook-и.  

Усі дії → audit trail + `ops.incident.*`.

---

## 7. Summary

- Financial-шар DSL з PD-009 пов’язаний із billing, Trutta та аналітикою через чіткі контракти: Registry → Rating → Billing → Trutta → DWH.  
- Rating рахує й логить immutable price_quotes; Billing і Trutta використовують їх як reference, не перераховуючи ціну самостійно.  
- Аналітика unit economics будується поверх product_costs, price_quotes, billing/Trutta events з повним трейсингом до продукту, ринку, вендора та користувача.  
- Governance/controls (PD-013, PD-010) гарантують, що фінмодель еволюціонує керовано, без "магічних" змін маржі чи payout’ів у проді.

