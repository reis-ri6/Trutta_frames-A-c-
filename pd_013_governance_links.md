# PD-013 Governance Links – Ops, Legal, City/Vendor Administrations v0.1

**Status:** Draft 0.1  
**Owner:** Governance Council / Ops / Legal / City Network

**Related docs:**  
- PD-010-ops-safety-and-quality-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-012-tooling-links.md  
- PD-013-governance-and-compliance-spec.md  
- PD-013-governance-templates.md

Мета документа — зафіксувати **зв’язки governance-рівня** (GOV/SEC/FIN/SAFE/OPS) з:

- операційним шаром (OPS / NOC / SRE),
- юридичним та комплаєнс-шарами (SEC/Legal),
- міськими/регіональними адміністраціями та vendor-адміністраціями.

Фокус: як правила й рішення governance перетворюються на конкретні політики, конфіги, обмеження та дії в містах і у вендорів.

---

## 1. Стейкхолдери та інтерфейси

### 1.1 Ops / NOC / SRE

- чергові OPS/SRE, NOC-команда;
- власники інцидентів, change-менеджери;
- користуються **ops-консоллю**, графіками, алертингом.

### 1.2 Legal / Compliance / Security

- SEC/Legal/Privacy офіцери;
- AML/KYC/санкційні офіцери;
- користуються **legal-консоллю** (реєстр продуктів/юрисдикцій, legal-атрибути, санкційні списки).

### 1.3 City Administration

- внутрішні city leads / city councils;
- регуляторні лізіони в містах/регіонах;
- користуються **city-admin порталом**: карти продуктів по місту, локальні обмеження, токен-політики.

### 1.4 Vendor Administration

- vendor success / vendor ops;
- ключові акаунт-менеджери;
- користуються **vendor-порталом**: які продукти активні / на паузі / в stop-sell, які SLA/SLO до них застосовуються, локальні правила.

---

## 2. Governance → Ops

### 2.1 Артефакти

- `ops_policies` (PD-010): правила SLO/SLI/SLA, escalation, change windows.
- `safety_overrides`, `quality_gates` (PD-010): умови деградації / stop-sell.
- change calendar & risk регістри: high/critical зміни з тайм-слотами.

### 2.2 Потік змін

1. **Authoring**: зміни в ProductDef / фін / ops-профілях → PR (PD-011).  
2. **Risk + approvals**: risk-level, approvals за матрицею (PD-013-spec).  
3. **Publish**: staging → prod (PD-012).  
4. **OPS link**:
   - update ops-консолі (нові/змінені продукти, SLO/SLA);
   - оновлення change calendar (заплановані релізи, заборонені вікна);
   - генерація runbook-ів/чеклістів для high/critical змін.

### 2.3 Інциденти → Governance

- Інциденти (таблиці `incidents`, `quality_scores` з PD-010) лінкуються до версій продуктів / змін.  
- OPS створює **change feedback**:
  - чи була зміна причиною інциденту;
  - чи потрібні додаткові safety thresholds / rate limits / stop-sell сценарії.
- GOV/SAFE переглядають інциденти на регулярних review та, за потреби, оновлюють політики.

### 2.4 Emergency

- OPS/SAFE можуть тригерити `stop-sell` / overrides (див. PD-013-spec + templates).  
- Кожен emergency-івент автоматично формує **governance task**:
  - розібрати причини;
  - оновити DSL/політики (follow-up PR);
  - оновити runbooks.

---

## 3. Governance → Legal / SEC

### 3.1 Структуровані Legal-атрибути в DSL/Registry

Для кожного продукту/ринку/міста в Registry фіксуються як мінімум:

- `legal_entity_id` — яка юрособа є стороною контракту;
- `jurisdiction_code` — країна/регіон юрисдикції;
- `age_restriction` — 0/13/16/18+ тощо;
- `restricted_categories` — алкоголь, азартні ігри, фінансові сервіси, health-сервіси тощо;
- `requires_kyc` / `requires_aml` / `requires_pep_check`;
- `sanctions_restricted` — чи підпадає продукт під санкційні/експортні обмеження;
- посилання на актуальні `terms_url`, `privacy_policy_url`, `vendor_terms_url`.

### 3.2 Потік нових продуктів / ринків

1. PO/PA ініціює новий продукт або вихід на новий ринок.  
2. У ProductDef/профілях заповнюються legal-атрибути (частково — як драфт).  
3. SEC/Legal отримують задачі на review через:
   - DSL-PR (GitHub reviewers);  
   - legal-console (список pending продуктів/ринків).  
4. SEC/Legal прив’язують продукт до:
   - юрособи;
   - локальних terms/policies;
   - списків обмежень (санкції, вікові, категорії).  
5. Тільки після approve Legal продукт може отримати статус `ready_for_staging` / `ready_for_prod`.

### 3.3 Enforcement

На runtime рівні legal-атрибути впливають на:

- доступність продукту в UI (гео/вікові обмеження, сегменти користувачів);
- вимоги до KYC/AML/додаткової згоди (відображення попапів, додаткових кроків);
- обмеження на токен-операції (типи токенів, ліміти, неможливість реселлу тощо).

### 3.4 Legal → Governance

SEC/Legal можуть:

- ініціювати **policy changes** (оновлення шаблонів профілів, legal-атрибутів);
- блокувати publish змін, якщо не виконані legal-передумови;
- ініціювати city/vendor-level кампанії (наприклад, оновити legal-матеріали у вендорів, отримати підтвердження по нових правилах).

---

## 4. Governance → City Administration

### 4.1 Роль City Admin

City Admin / City Council працює як **локальний governance-шар** для конкретного міста/регіону:

- може звужувати (але не розширювати) глобальні політики;
- визначає локальні обмеження по часу, локаціях, сегментах;
- взаємодіє з місцевими регуляторами й вендорами.

### 4.2 Модель обмежень на рівні міста

У Registry/LEM для міста зберігаються, наприклад:

- `city_product_status` (enabled / paused / stop-sell / beta-only);
- `city_time_windows` (години, в які продукт доступний);
- `city_cap_rules` (ліміти на кількість рідемпшенів/день/район);
- `city_geo_restrictions` (дозволені/заборонені кластери/квартали);
- `city_priorities` (наприклад, пріоритизація гуманітарних/соціальних продуктів).

### 4.3 Потоки рішень

- GOV визначає **глобальну політику** (які типи продуктів допустимі, базові правила).  
- City Admin може:
  - відключити або обмежити продукт у конкретному місті;
  - підняти stricter-ограничення (нижчі ліміти, коротші вікна);
  - запропонувати локальні модифікації (як change-request до глобальних профілів).

**Precedence:**

- Legal/SEC > SAFE > City Admin > OPS > Commercial (PO/FIN).  
- City Admin не може зняти глобальні legal/safety обмеження, але може робити продукт ще більш консервативним.

### 4.4 Інтерфейс City Admin Portals

- списки продуктів у місті, їх статуси, графіки використання;
- панель для зміни локальних статусів (pause/stop-sell/beta);
- конфіг локальних капів та часових вікон;
- канал зворотного зв’язку до Governance ("продукт не відповідає локальним очікуванням/правилам").

---

## 5. Governance → Vendor Administration

### 5.1 Vendor-level політики

Кожен vendor (мережа/локація) має в Registry/Vendor DB:

- список продуктів, які він може приймати;
- SLA/SLO, що застосовуються до цього вендора;
- quality_requirements (мін. рейтинг, час обслуговування, мін. стандарт сервісу);
- токен-політики (які токени приймаються, які мають обмеження);
- legal/contract статус (підписані умови, дата, версія контракту).

### 5.2 Vendor Portal

Vendor бачить:

- які продукти активні/на паузі/в stop-sell у його локаціях;
- зміни в SLA/SLO/quality-гейтах (із датами набуття чинності);
- попередження щодо порушень (низький рейтинг, інциденти, порушення legal/ops правил);
- вимоги до дій (оновити матеріали, пройти додатковий training, підтвердити нові terms).

### 5.3 Потоки Governance → Vendor

- Зміни у ProductDef/профілях, що впливають на вендорів (нові вимоги до сервісу, часів роботи, форматів рідемпшену) → автоматичні нотіфікації у vendor-порталі.  
- High/critical зміни (наприклад, зміна способу рідемпшену токенів, нові safety-процедури) можуть вимагати **explicit acknowledgement** від vendor’ів.

### 5.4 Vendor → Governance

- Vendor може:
  - подавати зауваження та скарги ("продукт не працює як заявлено", "недостатньо компенсуються витрати" тощо);
  - запитувати паузу/відключення продукту в конкретній локації;
  - пропонувати локальні модифікації продукту (через City Admin або напряму до PO/PA).

Ці сигнали агрегуються й потрапляють до GOV/PO/FIN/SAFE для перегляду продуктового портфелю.

---

## 6. Потоки рішень та нотифікацій

### 6.1 Ключові евенти

- `governance.decision` (PD-013-templates)  
- `registry.publish`  
- `product.emergency_stop_sell`  
- `city.policy_update`  
- `vendor.policy_update`  
- `legal.policy_update`

### 6.2 Нотифікації по аудиторіях

- **OPS**: усі publish high/critical, emergency, city policy updates, що впливають на навантаження/інциденти.  
- **Legal/SEC**: усі legal/policy updates, нові продукти/юрисдикції, breaking schema/contract changes.  
- **City Admin**: продукти, що додаються/видаляються у їх місті, зміни у глобальних політиках, що впливають на місто.  
- **Vendor Admin**: зміни у продуктах/політиках, які зачіпають цього вендора, нові вимоги/terms.

Механіка: email + in-app нотифікації в консолях +, за потреби, webhooks.

---

## 7. Дані назад у Governance

### 7.1 Джерела сигналів

- інциденти (OPS);
- legal/complaints (SEC/Legal);
- city feedback (City Admin);
- vendor feedback (Vendor Admin);
- runtime-метрики (unit economics, adoption, churn).

### 7.2 Агрегація

- центрична панель Governance, де по кожному продукту видно:
  - risk-профіль;  
  - історію інцидентів;  
  - legal/city/vendor flags;  
  - фінансові результати та відхилення від очікувань.

Це стає тригером для рев’ю продуктів, перелицювання продуктового портфелю, змін у DSL-профілях.

---

## 8. Еволюція: Policy-as-Code

Кінцева мета — звести governance → policy-as-code шар:

- access-matrix, risk-моделі, legal/city/vendor обмеження описуються як політики (наприклад, OPA/Rego);
- `pdsl` та CI автоматично перевіряють, що нові зміни DSL не порушують цих політик;
- City/Vendor/Legal-обмеження стають вхідними даними для цих політик, а не розкиданими по окремих системах.

PD-016-roadmap має зафіксувати етапи переходу до повноцінного policy-as-code шару та уніфікованих governance rule engines.

---

## 9. Summary

- Governance-рішення не живуть у вакуумі: вони повинні бути **проєковані** в Ops, Legal, City та Vendor контури.
- Product DSL / Registry є технічним носієм цих рішень, а консолі (ops/legal/city/vendor) — їхнім UX-шаром.
- Потоки рішень і сигналів двосторонні: зверху вниз (policy→конфіг→runtime) і знизу догори (інциденти/фідбек→policy updates).
- Дальший розвиток — формалізація всіх цих зв’язків у policy-as-code шарі з автоматичними перевірками в `pdsl`/CI.

