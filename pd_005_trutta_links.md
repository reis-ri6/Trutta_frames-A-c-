# PD-005 Trutta Links v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Token & Settlement Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-004-tjm-integration-links.md  
- PD-005-trutta-integration-spec.md  
- PD-005-trutta-ddl.sql  
- PD-005-trutta-templates.md

**Trutta side:**  
- TRT-CORE.md — основна логіка entitlements/tokens/swaps.  
- TRT-WALLET.md — гаманці користувачів / вендорів / пулів.  
- TRT-VENDOR-SETTLEMENT.md — розрахунки з вендорами.  
- TRT-FRAUD-RISK.md — fraud-контролі та ліміти.

Мета документа — описати **зв’язки Product DSL / Registry ↔ Trutta core**, включно з:

- як продукти підключаються до Trutta wallet-профілів;
- як події claim/redeem йдуть через core та settlement;
- як fraud/limit/risk-шар вписаний у загальний флоу.

> PD-005-spec задає контракт; цей документ розкладає, як саме Trutta core, wallet, settlement та fraud інтегруються в загальну систему.

---

## 1. Компоненти Trutta та їх ролі

### 1.1 Trutta Core

- Entitlement engine: створення, оновлення, зміна станів entitlements.
- Token engine: відображення entitlements у токени (on-/off-chain, internal ledger).
- Swap engine: застосування SwapRule / SwapProfile.

### 1.2 Trutta Wallet

- Зберігає баланс entitlements/tokens per користувач/вендор/пул.
- Дає API для:
  - перегляду доступних entitlements;
  - ініціації claim-операцій;
  - перегляду історії транзакцій.

### 1.3 Vendor Settlement

- Агрегує redeemed entitlements → settlement batches per vendor/city/product.
- Генерує payout-інструкції у фінансові/платіжні системи.

### 1.4 Fraud & Risk Control

- Валідує claim/issue/swap-операції проти:
  - лімітів профілів (EntitlementProfile, TokenProfile, SwapProfile);
  - поведінкових сигналів (швидкість, гео, девайси);
  - зовнішніх списків/флагів (KYC/KYB, blacklist/greylist).

---

## 2. Registry ↔ Trutta Core

### 2.1 Reference-зв’язок

- Registry зберігає в ProductVersion:
  - `entitlement_profile_id`;
  - `token_profile_id`;
  - `settlement_profile_id`;
  - `swap_profile_id` / список.

- Trutta core зберігає самі профілі та їх стани (active/issuing/frozen/closed).

### 2.2 Lifecycle-синхронізація

- Подія `product.version.status_changed` → Trutta control-plane:
  - `active → issuing` для відповідних EntitlementProfile;
  - `deprecated → frozen`;
  - `retired → closed`.

- Trutta не змінює статус ProductVersion, лише свої профілі.

### 2.3 Consistency інваріанти

- У prod env не можна:
  - випускати entitlements для ProductVersion зі статусом `retired`;
  - випускати entitlements, якщо EntitlementProfile в стані `closed`.

- Registry-валидація + Trutta-fraud-валидація мають бути комплементарні, а не дублювати логіку.

---

## 3. Wallet Links: Product / Registry ↔ Trutta Wallet

### 3.1 User Wallet

- Ідентифікатор: `user_wallet_id` (Trutta), який мапиться на:
  - `user_id` (core ID користувача);
  - або avatar/account у анонімній моделі.

- Registry не зберігає балансів, лише зв’язки `ProductVersion ↔ EntitlementProfile`.

### 3.2 Vendor Wallet

- `vendor_wallet_id` ↔ `vendor_id` (REIS/Trutta vendor registry / LEM service_point).
- Settlement вендора завжди йде в vendor wallet (або прив’язаний банківський/crypto-рахунок).

### 3.3 UI / API флоу

- BFF/Apps:
  - читають список продуктів/entitlements через:
    - Registry: які Trutta-профілі застосовні до продукту;
    - Trutta Wallet: конкретні entitlements і їх стани.

Флоу:

1. Користувач відкриває "My passes".
2. BFF:
   - через Registry знаходить продукти, які мають Trutta інтеграцію;
   - через Trutta Wallet тягне ентайтлменти per `user_wallet_id`.
3. В UI показуються конкретні entitlement’и з мапінгом на продукти (назва/опис із Registry).

---

## 4. Claim & Redeem Links

### 4.1 Claim

- Старт: `product.entitlement.issue_requested` або внутрішній тригер TJM (при старті/досягненні node’а).
- Trutta Core:
  - валідує через EntitlementProfile + fraud/limits;
  - створює `trutta_entitlement` із state `issued` або `reserved`;
  - відображає entitlement у Wallet (за потреби — токен).

### 4.2 Redeem

- Vendor-side:
  - vendor app / POS сканує/отримує entitlement (QR/NFC/code);
  - робить `claim_attempt` (табл. `trutta_claim_attempt`);
  - fraud/limits шар приймає рішення (`accepted/rejected`).

- При `accepted`:
  - Trutta оновлює entitlement (`issued/reserved → claimed`);
  - створює запис у `trutta_redemption` з `units_redeemed`;
  - емить подію `entitlement.redeemed`.

### 4.3 Зв’язок із TJM/Product runtime

- Через state_map (див. PD-004/PD-008):
  - `entitlement.claimed` → `journey.node.entitlement_claimed`;
  - `entitlement.redeemed` → може тригерити `product.completed` / перехід state у journey.

---

## 5. Vendor Settlement Links

### 5.1 Вхідні дані

- `trutta_redemption` як фактова таблиця для settlement:
  - `entitlement_id`, `vendor_id`, `units_redeemed`, `market_code`, `city_code`, `redeemed_at`;
  - `product_id`, `product_version_id` витягуються через entitlement.

- `SettlementProfile` (Trutta) + фінпрофілі (PD-009) визначають:
  - частоту settlement;
  - валюти/пули;
  - fee/спліт.

### 5.2 Settlement batch

- Vendor Settlement engine:
  - агрегує redemptions за період;
  - рахує payout per vendor (per currency/pool);
  - створює `SettlementBatch` (див. TRT-VENDOR-SETTLEMENT.md).

- Події:
  - `settlement.batch.created` (per vendor/city/product);
  - `settlement.batch.paid` (коли payout завершено).

### 5.3 Зв’язок з Registry/Analytics

- Аналітика будує joins:
  - `redemptions` → `entitlements` → `ProductVersion`/`Product` з Registry;
  - `settlement_batches` → unit economics per продукт/маркет/вендор.

- Registry потрібен як dimension, а не як учасник розрахунку.

---

## 6. Fraud & Risk Links

### 6.1 Policy Sources

- ProductDef/Registry:
  - задають high-level usage_policy (per_day/per_vendor, sospeso flags);
  - прив’язують продукт до конкретних Trutta-профілів (де лежать детальні правила).

- Trutta Fraud/Risk:
  - тримає low-level правила і моделі (чорні списки, ML-сигнали, velocity limits);
  - own’ить остаточне рішення `accept/reject` для claim/issue/swap.

### 6.2 Події та інциденти

- Trutta емить події:
  - `fraud.suspected`;
  - `fraud.blocked`;
  - `limit.exceeded`.

- В `correlation` завжди є:
  - `product_id`, `product_version_id`;
  - `user_id` / `vendor_id`;
  - `entitlement_id` (де релевантно);
  - `city_code`, `market_code`.

- Ops/безпекові агенти (див. PD-010) роблять:
  - розслідування;
  - додаткові блокування/розблокування;
  - ескалації в governance/legal.

### 6.3 Інваріанти безпеки

- Registry не приймає ролі fraud-engine:
  - не тримає чутливих поведінкових сигналів;
  - не приймає рішення про block/unblock.

- Всі дії, що змінюють стани entitlements/swaps/settlements, проходять через Trutta core + fraud шар.

---

## 7. Multi-tenant / White-label Links

### 7.1 Tenant boundaries

- Tenant (operator/city/DAO) визначається:
  - у Registry: через Product/Overlay (operator_code, market_code);
  - у Trutta: через окремі профілі/pools/wallet-namespaces.

- Один ProductVersion може використовувати:
  - глобальний EntitlementProfile,
  - або tenant-специфічний (id з префіксом оператора).

### 7.2 White-label wallet

- White-label партнери можуть:
  - мати власний фронт (wallet UI);
  - але використовувати Trutta core/wallet/settlement як бекенд.

- Registry зберігає, до якого Trutta-environment/profile прив’язаний конкретний ProductVersion.

---

## 8. Observability & Debug Links

### 8.1 Трейсинг ланцюжка: Product → Entitlement → Redemption → Settlement

Ключові ID для trace:

- `product_id`, `product_version_id` (Registry);
- `entitlement_id` (Trutta core/wallet);
- `claim_attempt_id`, `redemption_id` (Trutta core/vendor);
- `settlement_batch_id` (Trutta settlement).

Типовий debug-сценарій:

1. По `settlement_batch_id` знайти всі `redemption_id`.
2. По кожному `redemption_id` → `entitlement_id`, `vendor_id`, `units_redeemed`.
3. По `entitlement_id` → `product_version_id` / `user_id` / `origin`.
4. Через Registry → ProductDef, usage_policy, Trutta-профілі.

> DIAGRAM_PLACEHOLDER #1: "End-to-end Trutta trace"  
> Prompt: "Show arrows: ProductVersion (Registry) → EntitlementProfile (Trutta) → Entitlement → ClaimAttempt → Redemption → SettlementBatch with correlation IDs."

### 8.2 Dashboards

- Core метрики:
  - issued/claimed/redeemed/expired per продукт/місто/вендор;
  - fraud/limit events per сегмент/канал;
  - settlement lag (час від redeem до paid).

- Registry-дані використовуються як dimensions (product/journey/segment/market), Trutta — як facts.

---

## 9. Summary

- Registry описує **зв’язки продуктів** з Trutta-профілями, але не зберігає стани entitlements чи баланси.
- Trutta core/wallet/settlement/fraud — виконуючий шар для entitlements, токенів, свопів і розрахунків.
- Взаємодія побудована на:
  - референсах профілів у ProductDef;
  - подіях (`product.version.*`, `entitlement.*`, `settlement.*`, `fraud.*`);
  - спільних correlation ID для наскрізного трейсингу.
- Така декомпозиція дозволяє незалежно еволюціонувати Product DSL/Registry, TJM, Trutta core, не ламаючи базові контракти інтеграції.

