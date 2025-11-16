# PD-006 LEM City Graph Links v0.1

**Status:** Draft 0.1  
**Owner:** City Graph & Routing Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-links.md  
- PD-004-tjm-integration-links.md  
- PD-005-trutta-links.md  
- PD-006-lem-city-graph-integration-spec.md  
- PD-006-lem-city-graph-ddl.sql  
- PD-006-lem-city-graph-templates.md

**LEM side:**  
- LEM-CORE.md — модель city graph.  
- LEM-ROUTING.md — сервіси маршрутизації.  
- LEM-METRICS.md — агрегація метрик.  
- LEM-EXPERIENCE.md — API для city-experience шарів.

Мета — описати **зв’язки між Product DSL / Registry та LEM-компонентами**:

- як використовуються routing / metrics / city-experience сервіси;
- які події і потоки даних пов’язують їх із TJM та Trutta;
- які інваріанти по узгодженості графа й продуктів.

---

## 1. Компоненти та їх ролі

### 1.1 LEM-CORE

- Зберігає city graph: `lem_service_point`, `lem_service_edge`, кластери.
- Експонує read-only API для довідників (points, edges, clusters, classes).

### 1.2 LEM-ROUTING

- Будує маршрути на базі city graph + профілів/фасетів:
  - shortest / safest / scenic / multi-objective.
- Приймає routing-запити від TJM/агентів/BFF.

### 1.3 LEM-METRICS

- Обробляє події (journey, Trutta redemptions, footfall) → `lem_experience_snapshot`.
- Рахує safety/comfort/price/volume по місту, кластерах, фасетах.

### 1.4 LEM-EXPERIENCE

- Видає агреговані city-experience дані для:
  - UI (карти, heatmaps);
  - агентів (підбір кластерів, районів);
  - governance/ops (coverage, деградація, аномалії).

---

## 2. Registry / Product DSL ↔ LEM

### 2.1 Reference-зв’язки

- ProductDef містить блок `integrations.lem` (див. PD-006-spec):
  - `city_code`, `market_code`;
  - `service_point_classes.*`;
  - `journey_facets.*`;
  - `routing_profile_id`, `metrics_profile_id`;
  - опційні `coverage_requirements`.

- Registry тримає це як **конфіг** продукту для просторового/experience шару.
- LEM-CORE/ROUTING/METRICS тримають сам граф, профілі, фактичні метрики.

### 2.2 Lifecycle зв’язки

- При ingestion ProductDef Registry валідує посилання на LEM-профілі/класи.
- При зміні LEM (city, класи, профілі):
  - LEM емить події `lem.*`, Registry/TJM можуть:
    - оновити свої dim-таблиці;
    - позначити продукти як потребуючі review, якщо порушені coverage-вимоги.

---

## 3. LEM-ROUTING Links

### 3.1 Input від TJM / агентів

Типовий routing-запит від journey-runtime/агента:

```json
{
  "city_code": "VIE",
  "routing_profile_id": "LEM-ROUTE-VIEN-COFFEE-PASS",
  "origin_service_point_id": "SP-VIE-CAFE-0001",
  "target": {
    "type": "class",
    "class_ids": ["cafe.coffee_partner"],
    "count": 3
  },
  "journey_facets": ["coffee_walk"],
  "constraints": {
    "max_walk_time_minutes": 20,
    "min_safety_score": 0.7
  },
  "correlation": {
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "journey_instance_id": "JRN-00012345",
    "user_id": "USR-0001"
  }
}
```

### 3.2 Output до TJM

LEM-ROUTING повертає:

```json
{
  "routes": [
    {
      "route_id": "ROUTE-VIE-COFFEE-0001",
      "service_point_ids": [
        "SP-VIE-CAFE-0001",
        "SP-VIE-POI-0001",
        "SP-VIE-CAFE-0002"
      ],
      "edges": [
        {
          "service_edge_id": "SE-VIE-WALK-0001",
          "from_service_point_id": "SP-VIE-CAFE-0001",
          "to_service_point_id": "SP-VIE-POI-0001",
          "distance_meters": 350.0,
          "travel_time_seconds": 300,
          "safety_score": 0.9
        }
      ],
      "metrics": {
        "total_distance_meters": 1200.0,
        "total_travel_time_seconds": 900,
        "min_safety_score": 0.85,
        "avg_scenic_score": 0.8
      }
    }
  ]
}
```

- TJM перетворює це на journey nodes/steps.
- Product runtime використовує `metrics` для додаткових перевірок (safety, fatigue, тощо).

### 3.3 Інваріанти

- LEM-ROUTING не змінює ProductDef/Registry; він лише використовує їх як конфіг.
- TJM не модифікує city graph напряму.
- Routing-профілі (`routing_profile_id`) живуть на стороні LEM.

---

## 4. LEM-METRICS / Experience Snapshots Links

### 4.1 Вхідні потоки

LEM-METRICS споживає події з:

- TJM / journey-runtime:
  - `journey.started`, `journey.completed`;
  - `journey.node.visited_service_point`;
  - `journey.node.route_taken`.

- Trutta / entitlements:
  - `entitlement.redeemed` (з прив’язкою до `service_point_id` через vendor).

- Інші джерела:
  - footfall-сенсори, open data, city APIs.

### 4.2 Агрегація в `lem_experience_snapshot`

LEM-METRICS агрегує події в snapshots (див. DDL):

- target_type: `city/cluster/service_point/route`;
- facet_id: `coffee_walk/kidney_safe/nightlife/...`;
- вікна: годинні, денні, тижневі.

Приклад snapshot’у для coffee cluster:

```json
{
  "experience_snapshot_id": "EXP-VIE-COFFEE-CENTER-2025-11-01-DAY",
  "city_code": "VIE",
  "target_type": "cluster",
  "target_id": "CL-VIE-COFFEE-CENTER",
  "facet_id": "coffee_walk",
  "window_start": "2025-11-01T00:00:00Z",
  "window_end": "2025-11-02T00:00:00Z",
  "safety_score_avg": 0.93,
  "comfort_score_avg": 0.88,
  "scenic_score_avg": 0.9,
  "price_level_avg": 2.3,
  "volume_visits": 1240,
  "volume_redemptions": 860,
  "metrics_extra": {
    "unique_users": 540,
    "avg_stops_per_journey": 3.1
  },
  "source": "lem-metrics-job-daily",
  "computed_at": "2025-11-02T01:00:00Z"
}
```

### 4.3 Зв’язок із ProductDef / Registry

- ProductDef може посилатися на кластери/фасети, для яких LEM-METRICS рахує snapshots.
- Registry/аналітика join’ять snapshots з продуктами через:
  - `city_code`, `facet_id`, cluster → продукти, які використовують відповідні фасети в `integrations.lem`.

---

## 5. LEM-EXPERIENCE Links

### 5.1 API для UI/агентів

LEM-EXPERIENCE поверх `lem_experience_snapshot` надає:

- heatmaps по місту/кластеру (safety, comfort, price, volume);
- ranking кластерів/районів по певних фасетах;
- рекомендації, де запускати/промотити продукти.

Приклад запиту:

```json
{
  "city_code": "VIE",
  "facet_id": "coffee_walk",
  "time_window": {
    "from": "2025-11-01T00:00:00Z",
    "to": "2025-11-08T00:00:00Z"
  },
  "metrics": ["safety_score_avg", "volume_visits"],
  "limit": 10
}
```

Відповідь — топ-кластери/райони з їх метриками. Це може використовуватись:

- PM/ops — щоб вирішити, де підсилити vendor-onboarding;
- агенти — щоб запропонувати користувачу оптимальні зони для маршруту;
- governance — для оцінки impact продуктів у місті.

### 5.2 Products & overlays

- На основі experience-даних можливі автоматичні або напівавтоматичні overlay’ї продуктів:
  - обмеження зон (виключити кластери з низьким safety_score);
  - таргетинг промо (високий volume, низький redemption rate → стимулювати використання);
  - адаптація journey-фасетів.

---

## 6. Events & Change Propagation

### 6.1 LEM → інші сервіси

Події, які емить LEM:

- `lem.service_point.updated` — відкриття/закриття/зміна тегів;
- `lem.edge.updated` — блокування/додавання маршрутів;
- `lem.cluster.updated` — зміни в складі кластерів;
- `lem.coverage.degraded` — падіння coverage для сервісних класів/фасетів.

Споживачі:

- TJM — адаптація маршрутів у реальному часі.
- Registry — маркування продуктів як `needs_review` при порушенні coverage.
- Trutta — дод. контекст для fraud/settlement (наприклад, район з аномально високими редемпшенами).

### 6.2 Інваріанти узгодженості

- Не можна вважати продукт **fully active** у конкретному місті без виконання coverage-вимог (на основі LEM-даних).
- Routing-профілі мають бути сумісні з доступними EdgeClass та ServicePointClass для міста.
- Experience-метрики мають підтримувати ключові фасети, які використовуються продуктами (мінімальний набір по `facet_id`).

---

## 7. Ownership & Boundaries

### 7.1 Registry / Product DSL

- Own’ить:
  - опис просторових/experience-залежностей продукту (`integrations.lem`);
  - coverage-пороги для активації продуктів;
  - mapping продуктів до фасетів/кластерів.

- Не own’ить:
  - city graph, маршрути, метрики;
  - логіку routing/metrics/experience.

### 7.2 LEM-CORE/ROUTING/METRICS/EXPERIENCE

- Own’ять:
  - реалізацію графа та маршрутизації;
  - агрегацію досвіду й метрик;
  - API для запитів графа та experience.

### 7.3 TJM / Trutta / Analytics

- TJM — клієнт LEM-ROUTING/EXPERIENCE для побудови journey.
- Trutta — споживач/постачальник подій для LEM-METRICS (через redemptions/entitlements).
- Аналітика/BI — споживач `lem_experience_snapshot` та Trutta/TJM подій з Registry як dimension-шаром.

---

## 8. Summary

- PD-006-links фіксує, як LEM-CORE/ROUTING/METRICS/EXPERIENCE вбудовані в загальний рантайм:
  - Registry задає, що продукт очікує від city graph;
  - LEM будує маршрути й experience-моделі;
  - TJM використовує це для journey, Trutta — для контексту використання токенів.
- Декомпозиція гарантує, що:
  - city graph може еволюціонувати незалежно від продуктового DSL;
  - маршрути/метрики/experience можна покращувати, не змінюючи ProductDef контрактів;
  - весь ланцюжок (product → journey → city graph → entitlements → experience) прозорий через спільні ID та події.

