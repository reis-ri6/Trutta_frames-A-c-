# PD-007 Product Profiles Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-004-tjm-integration-links.md  
- PD-005-trutta-links.md  
- PD-006-lem-city-graph-links.md  
- PD-007-product-profiles-spec.md  
- PD-007-product-profiles-templates.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops-safety-and-quality-spec.md

Мета — описати **як продукт-профілі (Token/Loyalty/Pricing/Ops/Safety/Quality/Ui)** використовуються:

- Registry (як джерело правди);  
- Trutta (tokenisation / settlement / loyalty);  
- TJM (journey/runtime);  
- LEM (safety / experience constraints);  
- Frontend/BFF (UI/UX);  
- AI-агентами (product selection, ops, growth, CX).

---

## 1. Registry as Profile Hub

### 1.1 Effective profile resolution

Registry:

- зберігає всі профілі всіх типів;  
- застосовує layered overrides (global → market → product → segment → experiment) з урахуванням `priority`;  
- віддає **effective profile set** для контексту:

```json
{
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "market_code": "AT-VIE",
  "segment_keys": ["tourist", "kidney"],
  "experiment_keys": ["vien_coffee_ab_10off"],
  "profiles": {
    "token_profile": { /* resolved TokenProfile */ },
    "loyalty_profile": { /* resolved LoyaltyProfile */ },
    "pricing_profile": { /* resolved PricingProfile */ },
    "ops_profile": { /* resolved OpsProfile */ },
    "safety_profile": { /* resolved SafetyProfile */ },
    "quality_profile": { /* resolved QualityProfile */ },
    "ui_profile": { /* resolved UiProfile */ }
  }
}
```

### 1.2 Contract

- **Upstream:** ProductDef, governance-процеси створюють/оновлюють профілі.  
- **Downstream:** Trutta, TJM, LEM, BFF, агенти читають профілі **тільки через Registry API** (або cache), не тримають власних копій логіки резолюції.

Інваріант:

- Зміна профілю → Registry емить `product.profile.updated` з granular info (тип профілю, scope, affected products/markets).

---

## 2. Trutta Links (Token & Loyalty & Pricing)

### 2.1 TokenProfile → Trutta

TokenProfile задає bridge між продуктом та Trutta:

- посилання на Trutta-профілі:
  - `trutta.entitlement_profile_id`;
  - `trutta.token_profile_id`;
  - `trutta.settlement_profile_id`;
  - `trutta.swap_profile_ids[]`.

Використання:

- **Issue flow:**
  - Runtime викликає Registry → отримує TokenProfile;  
  - на його основі формує Trutta issue-запит (який EntitlementProfile / TokenProfile використовувати);  
  - Trutta повертає фактичний entitlement/token.

- **Wallet:**
  - `wallet.*` з TokenProfile використовується Wallet/BFF-слоєм для відображення активів (групування, visibility, breakdown).

Інваріанти:

- TokenProfile не послаблює ліміти Trutta;  
- у випадку конфлікту — Trutta-level правила сильніші, профіль лише обмежує.

### 2.2 LoyaltyProfile → Trutta / Loyalty Engine

LoyaltyProfile визначає earn/redeem-правила для подій:

- `entitlement.redeemed`, `journey.completed`, інші runtime events;  
- redeem → Trutta entitlement або внутрішня нагорода.

Потік:

1. Подія (`entitlement.redeemed`, `journey.completed`) потрапляє в Loyalty Engine.  
2. Engine запитує у Registry **effective LoyaltyProfile** для (product_version, market, segment).  
3. Застосовує `earn_rules` / `redeem_rules`.  
4. За потреби викликає Trutta (`reward_ref` → Entitlement issue).

### 2.3 PricingProfile → Billing / Trutta

PricingProfile дає billing/rating-сервісу конфіг:

- базову ціну;  
- сегментні/кампанійні дисконти;  
- rounding;  
- `billing_price_list_id`.

Billing/rating-сервіс не читає ProductDef безпосередньо, а:

- викликає Registry → PricingProfile;  
- рахує кінцеву ціну;  
- передає її в Trutta для issue (якщо потрібно прив’язати до вартості).

---

## 3. TJM Links (Runtime & Journey)

### 3.1 Profiles used by Journey Runtime

TJM використовує:

- TokenProfile — щоб знати, чи має продукт entitlement-кроки і який тип токенів.  
- LoyaltyProfile — щоб знати, які кроки/фасети генерують loyalty-бонуси.  
- PricingProfile — для відображення цін у journey UI / pre-checkout.  
- SafetyProfile — для обмеження маршрутів/часу/кластерів.  
- OpsProfile — для runtime-моніторингу (які SLO таргети важливі).  
- QualityProfile — для тригерів post-journey survey.  
- UiProfile — для тексту, локалізації, badge’ів у journey UI.

### 3.2 Pre-flight resolution

При старті journey (або на етапі pre-checkout):

1. TJM визначає: product_version, market, сегмент(и), активні експерименти.  
2. Запитує Registry → отримує effective profiles.  
3. Кешує профілі на lifetime journey instance (або короткий TTL).

Інваріант:

- протягом однієї journey-сесії набір профілів не змінюється, навіть якщо в Registry відбулися апдейти (для консистентності UX).

### 3.3 Events & mapping

TJM емить runtime events, вже збагачені профільною інформацією там, де це потрібно:

- `journey.started` — з `pricing_profile_id`, `token_profile_id`, segment/experiment keys.  
- `journey.node.entitlement_issued` — з `trutta.entitlement_profile_id`.  
- `journey.completed` — з посиланнями на LoyaltyProfile (щоб downstream-обробка могла коректно порахувати по snapshot’ах).

---

## 4. LEM Links (Safety / Experience)

### 4.1 SafetyProfile → LEM-ROUTING

SafetyProfile визначає constraints для LEM:

- `safety.min_safety_score` → мін. safety_score для edges/кластерів;  
- `safety.forbidden_tags` → edge/service_point tags, які мають бути виключені;  
- `geo.forbidden_clusters` → кластери, які routing не повинен використовувати;  
- `time_restrictions` → allowed_hours_local.

TJM/агенти, викликаючи LEM-ROUTING, додають у routing-запит constraints, згенеровані з SafetyProfile.

### 4.2 QualityProfile / OpsProfile → LEM-METRICS

QualityProfile та OpsProfile задають target метрики, частково прив’язані до LEM:

- потрібна min кількість reviews/visits per cluster;  
- очікуваний рівень experience (safety/comfort/scenic) для фасетів.

LEM-METRICS може:

- використовувати ці таргети для маркування кластерів/районів як **underperforming**;  
- емити події (`lem.experience.degraded`) у Registry/Ops для відповідних продуктів.

---

## 5. Frontend / BFF Links (UI & UX)

### 5.1 UiProfile as single source of truth

BFF/Frontend використовують UiProfile як джерело:

- локалізації (title, short/long description, markdown-блоки);  
- іконок/кольорів/баджів;  
- feature flags (показувати loyalty-бейдж, kidney-safe label, тощо).

Потік:

1. BFF отримує запит: список продуктів для певного міста/юзера.  
2. Звертається до Registry: effective UiProfile (+ PricingProfile, LoyaltyProfile summary).  
3. Формує DTO для фронта:

```json
{
  "product_id": "PRD-VIEN-COFFEE-PASS",
  "title": "Vienna Coffee Day Pass",
  "short_description": "Enjoy 5 coffees...",
  "price": {
    "amount": 17.0,
    "currency": "EUR",
    "is_discounted": true
  },
  "badges": ["popular", "local_partners"],
  "flags": {
    "has_loyalty": true,
    "kidney_safe": true
  }
}
```

### 5.2 Caching & change propagation

- BFF може кешувати UiProfile/PricingProfile з коротким TTL (1–5 хв) для списків.  
- Registry при зміні профілю емить `product.profile.updated` → BFF може інвалідовувати кеш.

---

## 6. AI Agents Links

### 6.1 Product selection / recommendation agents

Агенти, що рекомендують продукти (trip-planner, concierge, marketplace-recommender), використовують:

- PricingProfile — для оцінки affordability, промо.  
- LoyaltyProfile — для підбору продуктів, що дають кращий earn для користувача.  
- SafetyProfile — для сегментів типу kidney/family/night;  
- UiProfile — щоб формувати текстові/візуальні рекомендації (назви, описи).  
- TokenProfile — щоб розуміти, які токени/entitlements будуть видані та як ними оперувати.

### 6.2 Ops / Risk / Governance agents

- Ops-агенти:
  - читають OpsProfile → знають, які SLO/alerts важливі для конкретного продукту;  
  - корелюють фактичні метрики з target’ами, генерують інциденти/рекомендації.

- Risk/fraud-агенти:
  - використовують TokenProfile/LoyaltyProfile для розуміння, які токен/loyalty-патерни допустимі;  
  - SafetyProfile для оцінки аномалій по гео/часу (redeems у заборонених кластерах).

- Governance-агенти:
  - працюють зі змінністю профілів (версії, effective_from/until);  
  - пропонують зміни профілів (наприклад, посилити safety або змінити ціну) на базі usage/impact.

---

## 7. Events & Telemetry

### 7.1 Profile-aware events

Усі ключові події мають включати:

- `product_version_id`;
- `market_code`;
- `profile_ids` (або хоча б хеші/версії профілів на момент події).

Приклад payload’у `entitlement.redeemed`:

```json
{
  "event_type": "entitlement.redeemed",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "market_code": "AT-VIE",
  "token_profile_id": "PRF-TOKEN-VIEN-COFFEE-PASS",
  "loyalty_profile_id": "PRF-LOYALTY-VIEN-COFFEE-PASS",
  "safety_profile_id": "PRF-SAFETY-VIEN-COFFEE-PASS",
  "ui_profile_id": "PRF-UI-VIEN-COFFEE-PASS",
  "trutta_entitlement_id": "TRT-ENT-...",
  "service_point_id": "SP-VIE-CAFE-0001",
  "user_id": "USR-0001"
}
```

Це дозволяє:

- відтворювати, під якими профільними умовами відбулася подія;  
- аналізувати вплив змін профілів (до/після) на поведінку.

### 7.2 Audit & rollback

- Зміни профілів логуються в Registry (change history, versioning).  
- Аналітика може використовувати події з `profile_ids` для порівняння performance різних версій профілів.  
- Governance-агенти можуть рекомендувати rollback профілю (наприклад, невдалий PricingProfile експеримент).

---

## 8. Summary

- PD-007-links фіксує, що **Product Profiles** — це не просто метадані, а **central contract** між Registry та всіма рантайм-компонентами.  
- Trutta, TJM, LEM, BFF, агенти не дублюють логіку, а спираються на resolved профілі з Registry.  
- Профілі дають прозорий, керований шар для зміни поведінки продуктів без зміни коду, з чітким аудитом і можливістю експериментів/роллбеків.

