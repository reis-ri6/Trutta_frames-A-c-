# PD-010 Ops, Safety & Quality Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform Ops / Safety / Product Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-003-registry-and-versioning-spec.md  
- PD-007-product-profiles-spec.md  
- PD-007-product-profiles-templates.md  
- PD-008-product-runtime-and-agents-spec.md  
- PD-008-product-runtime-events.md  
- PD-008-product-runtime-links.md  
- PD-009-financial-and-pricing-profile-spec.md  
- PD-010-ops.ddl.sql (planned)  
- PD-010-ops-templates.md (planned)  
- PD-010-ops-links.md (planned)  
- PD-013-governance-and-compliance-spec.md

---

## 1. Purpose & Scope

### 1.1 Purpose

Цей документ визначає **операційні, safety та quality стандарти продуктів**, а саме:

- як ми формалізуємо SLI/SLO/SLA для ProductRuntimeSession і пов’язаних сервісів;
- як описуються safety-пороги (risk/safety-профілі) на рівні продукту та міста;
- як працюють quality-гейти для запуску, змін та виконання продукту;
- як ці політики інтегруються з runtime (PD-008) та governance (PD-013).

### 1.2 Scope

Входить:

- логічна модель Ops/Safety/Quality-профілів (як частина Product Profiles);  
- типи SLI, SLO та SLA;  
- safety thresholds (для LEM, Trutta, агентів);  
- quality gates для lifecycle: design → rollout → runtime;  
- зв’язки з Ops console та incident management.

Не входить:

- повна фізична DDL (див. PD-010-ops.ddl.sql);  
- детальні runbooks (інциденти, SRE — в окремих VG-* документах для конкретних продуктів/міст);
- юридичний текст SLA з партнерами (договірний рівень, не технічний).

---

## 2. Core Concepts

### 2.1 SLI / SLO / SLA (definitions)

- **SLI (Service Level Indicator)** — вимірюваний показник (наприклад, latency p95, success rate, coverage).  
- **SLO (Service Level Objective)** — цільове значення SLI (наприклад, `success_rate >= 99.0%` за 30 днів).  
- **SLA (Service Level Agreement)** — формалізоване зобов’язання (зазвичай контрактне) між платформою та вендорами/клієнтами/партнерами.

У DSL ми моделюємо **SLI/SLO** як частину OpsProfile/SafetyProfile/QualityProfile; SLA — як похідну, що використовує ті ж SLO як технічну базу.

### 2.2 Profiles: Ops, Safety, Quality

Згідно PD-007, для кожного продукту існують профілі:

- `OpsProfile` — операційні показники: latency, error rate, availability, incident response;  
- `SafetyProfile` — ризики та пороги: city safety, vendor risk, fraud, health/diet safety;  
- `QualityProfile` — суб’єктивна та об’єктивна якість: рейтинг, NPS/CSAT, complaint rate, content/UX гейти.

Кожен профіль має:

- scope (глобальний / per-market / per-product / per-segment);
- SLI/SLO конфігурацію;  
- threshold-и для автоматичних дій runtime;
- escalation рівні для Ops / Safety команд.

### 2.3 Quality Gates

**Quality gate** — формалізована умова, яку продукт або зміна має пройти, щоб перейти в наступну фазу:

- **Design Gate:** чи можна вивести продукт у beta;  
- **Launch Gate:** чи можна запустити в прод/місто;  
- **Change Gate:** чи можна підняти версію product_version/профілю;  
- **Runtime Gate:** чи дозволено прийняти нову сесію / продовжити journey в поточних умовах.

Гейти використовують SLO/threshold-и та аналітику (наприклад, достатній обсяг тестових сесій, відсутність інцидентів високого рівня).

---

## 3. OpsProfile

### 3.1 Logical structure

```yaml
ops_profile:
  profile_id: PRF-OPS-VIEN-COFFEE-PASS
  profile_type: ops_profile

  scope:
    level: product
    market_code: AT-VIE
    product_ids: [PRD-VIEN-COFFEE-PASS]

  slo:
    availability:
      target_percent: 99.5
      window_days: 30
    journey_success_rate:
      target_percent: 97.0
      window_days: 30
    runtime_error_rate:
      max_percent: 1.0
      window_days: 7
    latency_p95_ms:
      max_ms: 1500
      window_days: 7

  incident_policies:
    critical_error_burst:
      threshold_count: 10
      window_minutes: 5
      action: "create_incident_and_throttle"

  escalation:
    primary_team: "vien-ops"
    oncall_rotation_id: "OC-VIEN-PLATFORM"
```

### 3.2 Key SLI categories

1. **Availability / uptime**
   - наприклад, `product.runtime.created` запити, що не закінчились `failed` через платформу.
2. **Journey success rate**
   - частка сесій, що завершились `product.runtime.completed` зі `completion_status = success` і `journey_status = completed`.
3. **Error / incident rate**
   - частка `runtime.error` / інцидентів на кількість сесій.
4. **Latency**
   - p95/p99 для ключових API (PRG, TJM, Trutta, LEM, AO) в контексті конкретного продукту.

### 3.3 Runtime actions

OpsProfile задає, що робити при порушенні SLO/safety:

- soft breach (попередження): сигнал у Ops console, не блокує нові сесії;  
- hard breach (критичне відхилення):
  - stop-sell для нового product_version/market;  
  - auto-throttle (обмеження кількості нових сесій);  
  - автоматичний перехід у `product.runtime.degraded` з fallback-режимом.

Загальна логіка: OpsProfile не змінює бізнес-логіку продукту, але задає **політику реакції** на деградацію.

---

## 4. SafetyProfile

### 4.1 Dimensions of safety

SafetyProfile покриває декілька вимірів:

- **City / route safety** — ризики маршруту, районів, часу доби (LEM-інтеграція).  
- **Vendor safety** — статус вендора: перевірений/підозрілий/заблокований; hygiene/inspection score.  
- **Product-specific safety** — дієтичні/health-обмеження (наприклад, kidney.mpt), алергени, алкоголь.  
- **Fraud / abuse** — підозрілі патерни клеймів/редемпшенів (Trutta).  
- **Regulatory** — вікові, юридичні, AML/KYC межі.

### 4.2 Logical structure

```yaml
safety_profile:
  profile_id: PRF-SAFETY-VIEN-COFFEE-PASS
  profile_type: safety_profile

  scope:
    level: product
    market_code: AT-VIE

  lem_thresholds:
    min_city_safety_score: 0.75
    min_route_safety_score: 0.80
    max_night_hours_without_check: 2   # скільки годин у нічний час без дод. перевірок

  vendor_thresholds:
    min_vendor_safety_score: 0.80
    disallow_unverified_vendors: true
    disallow_vendors_with_recent_incidents_days: 30

  dietary_constraints:
    requires_profile_type: "kidney|diabetes|allergy"   # якщо продукт медично чутливий
    disallow_conflicting_dishes: true

  fraud_thresholds:
    max_daily_redemptions_per_user: 10
    max_parallel_sessions_per_user: 3

  runtime_actions:
    on_low_safety_route:
      action: "fallback_to_safer_route|block_journey_node"
    on_vendor_safety_drop:
      action: "temporarily_disable_vendor"
    on_fraud_pattern_detected:
      action: "freeze_entitlements_and_alert_risk"
```

### 4.3 Integration with LEM & Trutta

- LEM: safety-поля у service_point / route (наприклад, `safety_score`, `night_risk_score`) порівнюються з threshold’ами профілю.  
- Trutta: ліміти на redemptions/entitlements + fraud-сигнали → runtime-actions (freeze, require manual review).

### 4.4 Runtime enforcement

Під час preflight та journey execution:

- PRG/TJM запитують LEM/Trutta з контекстом SafetyProfile;  
- якщо route/venue не проходять пороги →
  - або підбирається альтернатива;  
  - або певні ноди journey позначаються як недоступні;  
  - або сесія не допускається до активного стану (preflight_failed).

---

## 5. QualityProfile

### 5.1 Dimensions of quality

QualityProfile описує якість продукту та досвіду:

- **Content quality** — повнота/актуальність описів, фото, інструкцій.  
- **Service quality** — відгуки, рейтинги, complaint rate по вендорах/маршрутах.  
- **Experience quality** — NPS/CSAT, completion rate journeys, churn/abandonment.

### 5.2 Logical structure

```yaml
quality_profile:
  profile_id: PRF-QUALITY-VIEN-COFFEE-PASS
  profile_type: quality_profile

  scope:
    level: product
    market_code: AT-VIE

  content_requirements:
    min_photos_per_venue: 3
    requires_verified_descriptions: true
    max_content_age_days: 180

  rating_thresholds:
    min_average_rating: 4.2
    max_complaint_rate_percent: 2.0

  cx_metrics:
    min_nps_score: 40
    min_csat_score: 4.3
    max_journey_abandon_rate_percent: 15

  runtime_actions:
    on_low_rating_vendor:
      action: "deprioritize_in_routes"
    on_high_complaint_route:
      action: "pause_route_and_alert_ops"
```

### 5.3 Quality gates by phase

- **Design/Pre-launch:**
  - контент повинен відповідати `content_requirements`;  
  - немає критичних вендорів з низьким рейтингом.

- **Post-launch:**
  - якщо `average_rating` < threshold або `complaint_rate` > threshold протягом X днів:  
    - автоматичний stop-sell або зниження видимості;  
    - Ops-інцидент.

- **Runtime:**
  - AI-агенти (journey guide) мають доступ до quality-сигналів;  
  - рекомендації будуються з урахуванням мінімального рейтингу/максимального complaint rate.

---

## 6. SLO/SLA & Runtime Events

### 6.1 Event mapping

SLI/SLO будуються поверх подій (PD-008):

- **Availability / success:**
  - `product.runtime.created`, `product.runtime.completed`, `product.runtime.failed`.
- **Journeys:**
  - `journey.started`, `journey.completed`, `journey.abandoned`, `journey.node.*`.
- **Safety/Quality:**
  - `lem.degraded`, `lem.coverage.degraded`;  
  - `entitlement.redeemed` + fraud flags;  
  - `cx.survey.completed`, `cx.review.created`;  
  - `runtime.degraded`, `ops.incident.*`.

### 6.2 Example SLO definitions (logical)

```yaml
slo_definitions:
  product_availability:
    sli_query: "% of product.runtime.created not ending in failed due to platform error over 30d"
    target_percent: 99.5

  journey_success_rate:
    sli_query: "% of journeys with journey.completed / (journey.completed + journey.abandoned) over 30d"
    target_percent: 97.0

  safety_incident_rate:
    sli_query: "# of safety-related ops.incident.* per 10k sessions over 90d"
    max_value: 1.0

  quality_nps:
    sli_query: "average nps_score from cx.survey.completed over 90d"
    min_value: 40
```

### 6.3 SLA mapping

На базі цих SLO тех/юридична команда формує SLA-документ:

- які SLO виносяться назовні;  
- які penalties/compensation при невиконанні (наприклад, безкоштовні tokens/entitlements або revenue-кредити для вендорів);  
- механіка вимірювання (DWH-пайплайни, звітність).

---

## 7. Integration with Ops Console & Incidents

### 7.1 Dashboards

Ops console відображає для кожного продукту/міста:

- поточний стан SLO (green/amber/red);
- тренди SLI (availability, success, latency, safety, quality);
- список активних `ops.incident.*` з прив’язкою до продуктів і маршрутів.

### 7.2 Alerts & incidents

- порушення SLO або safety/quality threshold → alert → потенційно інцидент;  
- `ops.incident.created` містить посилання на product_id, profiles, route/vendor.

Ops-плейбуки (окремі документи) описують дії:

- stop-sell / pause-route / disable-vendor;  
- rollback product_version / profiles;  
- компенсації користувачам/вендорам.

---

## 8. Governance & Changes

### 8.1 Change management

Будь-які зміни Ops/Safety/Quality профілів:

- створюють нову версію профілю в Registry;  
- проходять approval flow (PD-013);  
- можуть вимагати оновлення SLA/контрактів;  
- емлять подію `product.profile.updated`.

### 8.2 Agent constraints

AI-агенти можуть:

- читати поточні профілі та їхні пороги;  
- обирати більш безпечні/якісні варіанти;  
- пропонувати зміни порогів (у вигляді рекомендацій для Ops/PM).

Але не можуть:

- змінювати профілі або гейти без approval;  
- оминати safety-гейти при побудові маршрутів/продуктових рекомендацій.

---

## 9. Summary

- PD-010 формалізує Ops/Safety/Quality як **першокласні профілі** продукту із SLI/SLO/threshold-ами та quality-гейтами.  
- Runtime використовує ці профілі для preflight, вибору маршрутів/вендорів, реакції на деградацію й блокування небезпечних сценаріїв.  
- Ops console, інцидент-менеджмент і governance (PD-013) забезпечують контрольовану еволюцію політик без ручної магії в коді та ад-хок фіксів у проді.

