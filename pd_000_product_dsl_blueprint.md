# PD-000 Product DSL & Registry Blueprint (Variant C) v0.1

**Status:** Draft 0.1  
**Owner:** Product Architecture / Platform / DevEx  
**Audience:** Product, Arch, Data, DevEx, City Ops, Integrators

**Related index:**  
- PD-001…PD-016 (Tier 0–3, Core → Integration → Runtime → Tooling → Roadmap)

Мета цього документа — дати **цілісну картинку** Product DSL & Registry як продуктового шару між TJM, Trutta, LEM, міськими графами та runtime-агентами.

Документ відповідає на питання:

- що таке Product DSL і Registry на рівні моделі й runtime;  
- як вони вбудовані в TJM / Trutta / LEM / mpt.tours;  
- як виглядає життєвий цикл продукту;  
- які шари даних/сервісів існують;  
- як управляються ризики, breaking changes та міграції.

---

## 1. Product DSL: роль у системі

### 1.1 Проблема

Усі стек-и (TJM, Trutta, LEM, мапи міст, агенти) потребують **єдиного способу описати продукт**:

- що саме продається / надається (journeys, passes, meal entitlements, city experiences);  
- де, коли й для кого (markets, сегменти, профілі);  
- за якою ціною і з якою економікою (pricing, revenue-split, FX);  
- з якими обмеженнями безпеки/оперування (ops/safety/quality);  
- як усе це поводиться в runtime (events, agents, states).

Без єдиного DSL:

- з’являються розрізнені конфіги в TJM/Trutta/LEM;  
- неможливо гарантувати цілісність продукту при змінах;  
- кожне місто/вендор/інтегратор отримують свою варіацію "як воно працює".

### 1.2 Роль Product DSL

Product DSL — це **єдина декларативна модель** продукту:

- формальний `ProductDef` + набір профілів (Token/Loyalty/Pricing/Ops/Safety/UI);  
- канонічні інваріанти домену (PD-002);  
- мапінг на TJM journey-модель, Trutta entitlements/settlement, LEM city graph;  
- основа для Registry, runtime, тестів, SDK, документації.

---

## 2. Архітектурний контекст

### 2.1 High-level контур

Логічні компоненти:

1. **Product DSL & Schemas**  
   - core схеми `ProductDef`, профілі (PD-001, PD-007, PD-009, PD-010);  
   - JSON/YAML артефакти у репозиторіях (PD-014).

2. **Product Registry**  
   - центральний реєстр продуктів, версій, статусів (PD-003);  
   - API/DDL/історія змін, publish/promotion flows.

3. **Integration Layer**  
   - TJM integration: journeys, micro-journeys, lifecycle стани (PD-004);  
   - Trutta: entitlements, claim/redeem, swap, settlement (PD-005);  
   - LEM: city graph, service_points, edges, experience snapshots (PD-006).

4. **Runtime & Agents**  
   - product-runtime, journey-runtime, agent-orchestrator (PD-008);  
   - фінансовий і ops/safety runtime (PD-009, PD-010).

5. **Tooling & Governance**  
   - `pdsl` CLI, CI-пайплайни, тест-сьюти (PD-011, PD-012, PD-015);  
   - governance, risk, compliance (PD-013, PD-016).

### 2.2 Зв’язок зі стеком TJM / Trutta / LEM

- DSL відповідає на питання **"що таке продукт"**.  
- TJM відповідає на **"як ми ведемо journey"**.  
- Trutta — **"як ми токенізуємо й розраховуємось"**.  
- LEM — **"де в місті це відбувається"**.

Product DSL — верхній шар, що конфігурує решту підсистем через конектори/інтеграції.

---

## 3. Модель даних: ядро

### 3.1 Ключові сутності (див. PD-002)

- `Product` — абстракція proposition (vien.geist city guide, city pass, kidney.mpt trip);  
- `ProductVersion` — конкретна версія конфігурації;  
- `Variant` — варіації (наприклад, 24h/48h/72h city pass);  
- `Profile*` — окремі профілі (token, loyalty, pricing, ops/safety, UI);  
- `Market` / `City` / `Cluster` — де діє продукт;  
- `RuntimeBinding` — зв’язки з TJM journeys, LEM graphs, Trutta entitlements.

### 3.2 ProductDef як центральний об’єкт

`ProductDef` — агрегат, який:

- містить базові атрибути продукту (ID, name, category, vertical, risk level);  
- посилається на профілі (через `*_profile_ref`);  
- містить мапінг на journey-класи/шаблони TJM;  
- описує фінансову модель (pricing, revenue-split, FX);  
- задає ops/safety/quality параметри.

### 3.3 Registry як "джерело правди"

Registry зберігає:

- які продукти існують, у яких версіях;  
- які версії активні в яких markets/містах;  
- conformance-рівень (L0/L1/L2) та історію сертифікацій;  
- audit-трейл змін.

DSL-документи — editable layer; Registry — authoritative runtime layer.

---

## 4. Життєвий цикл продукту

### 4.1 Стани продукту (спрощено)

- `draft` — чернетка ProductDef;  
- `review` — пройшов internal review (product/arch/data/legal/ops залежно від ризику);  
- `approved` — затверджений для non-prod env;  
- `staging_active` — активний у staging;  
- `prod_candidate` — пройшов conformance тести для target рівня;  
- `prod_active` — активний у prod для певних markets/міст;  
- `deprecated` — нові journey/purchases не стартують;  
- `retired` — недоступний у prod, залишається в історії.

### 4.2 Потік authoring → runtime

1. Product author / arch створює/редагує `ProductDef` + профілі (PD-011).  
2. `pdsl lint/schema/semantic` локально + у PR CI (PD-012, PD-015).  
3. Golden samples генеруються/оновлюються (PD-014).  
4. Registry dry-run publish: перевірка відповідності схемам, policy, risk (PD-003, PD-013).  
5. Publish у staging Registry + e2e тести в staging (PD-015, PD-015-links).  
6. Governance approvals (для high/critical) + prod publish; оновлення state продукту в Registry.  
7. Міста/тенанти активують продукт згідно своїх release-трейнів.

---

## 5. Шари runtime

### 5.1 Product Runtime

Product-runtime (PD-008):

- читає Registry snapshots / caches;  
- створює runtime-конфіги для агентів, UI, API;  
- транслює ProductDef у конкретні виклики TJM/Trutta/LEM.

Ключові події:

- `product.started`, `product.step_reached`, `product.completed`, `product.failed`;  
- фінансові: `entitlement.issued`, `entitlement.claimed`, `entitlement.redeemed`, `settlement.completed`;  
- ops/safety: `incident.recorded`, `safety.threshold_breached`, `compensation.issued`.

### 5.2 Роль агентів

AI-агенти (journey-, city-, ops-, finance-) працюють поверх Product Runtime:

- використовують DSL як "contract" того, що можна/не можна робити;  
- не тримають продуктову логіку в коді, а читають її з профілів;  
- звітують події назад у Registry/аналітику.

---

## 6. Governance, ризики, conformance

### 6.1 Risk-aware продукт

Кожен продукт має:

- `risk_level` (low/medium/high/critical);  
- категорії (travel, F&B, health, humanitarian, finance...);  
- прив’язку до юрисдикцій / регуляторних режимів.

Risk-level впливає на:

- вимоги до профілів (обов’язкові ops/safety, legal поля);  
- набір обов’язкових тестів (PD-015);  
- необхідні approvals (PD-013);  
- мінімальний conformance-рівень (L0/L1/L2) перед prod.

### 6.2 Conformance

Conformance (PD-015):

- L0 — базова валідність, внутрішні/β сценарії;  
- L1 — стандартні продукти, що можуть бути розгорнуті в більшості міст;  
- L2 — критичні (health/humanitarian/finance) з підвищеними вимогами.

Conformance рівень зберігається в Registry та впливає на:

- доступність продуктів у prod;  
- видимість у public demo/docs/SDK;  
- можливість включення в city-level bundles.

---

## 7. Еволюція, breaking changes, міграції

### 7.1 Semver та compatibility

PD-016 задає:

- semver для DSL схем: PATCH/MINOR/MAJOR;  
- чітке розділення non-breaking vs breaking;  
- policy "no silent breaking" + обов’язковий deprecation lifecycle.

### 7.2 Expand→Migrate→Contract

Усі зміни схем/DDL/Registry проходять через E→M→C:

- Expand — додати нові елементи, залишити старі;  
- Migrate — мігрувати дані/продукти/EX-XXX;  
- Contract — депрекейтнути та видалити legacy.

Migration descriptors (PD-003-templates) + `pdsl migrate` дають контрольований механізм переходів.

---

## 8. Бібліотека прикладів та тести як "живий стандарт"

### 8.1 EX-XXX як referential layer

PD-014 визначає бібліотеку **EX-XXX**:

- реальні, але деідентифіковані приклади (vien.geist, city passes, kidney.mpt, humanitarian flows);  
- templates для продуктових команд і міст;  
- джерело правди для docs/demo/SDK.

### 8.2 Тести (PD-015)

Тестова система сприймає DSL/Registry як код:

- schema + semantic тести для всіх продуктів;  
- integration/e2e для EX-XXX;  
- performance/resilience для ключових флоу.

Будь-які зміни DSL/Registry мають проходити через цю сітку, до того як потрапити в міста/вендорів.

---

## 9. Multi-city / multi-domain модель

### 9.1 Multi-city

Одна DSL/Registry модель, багато міст:

- spільний core схем;  
- city-specific policy/profiles/config (через policy-as-code, локальні профілі);  
- registry trains per city + EOL політики.

### 9.2 Multi-domain

Ті самі патерни для:

- travel (mpt.tours, city passes);  
- F&B (Trutta, meal tokens);  
- health-aware travel (kidney.mpt, special diets);  
- humanitarian flows (vouchers, passes, shelters).

Domain-specific розширення — через DSL modules, не через forking core.

---

## 10. Summary

PD-000 задає **каркас** для всіх PD-001…PD-016:

- Product DSL — єдина декларативна модель продуктів для всіх стеків;  
- Registry — authoritative шар, що тримає versions, states, conformance, history;  
- TJM/Trutta/LEM — runtime-рушії, які конфігуруються DSL;  
- governance/test/tooling — гарантія того, що еволюція DSL/Registry контрольована, передбачувана й безпечна для міст, вендорів і інтеграторів.

Усі наступні документи PD-001…PD-016 деталізують цей blueprint по шарах: core моделі, інтеграції, runtime, профілі, tooling, тести та roadmap.

