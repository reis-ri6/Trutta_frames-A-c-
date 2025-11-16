# PD-006 LEM City Graph Integration Spec v0.1

**Status:** Draft 0.1  
**Owner:** Platform / City Graph & Routing Architecture

**Related docs:**  
- PD-001-product-dsl-core-spec.md  
- PD-002-product-domain-model.md  
- PD-002-product-domain-model-links.md  
- PD-003-registry-and-versioning-spec.md  
- PD-004-tjm-integration-spec.md  
- PD-005-trutta-integration-spec.md  
- PD-006-lem-city-graph.ddl.sql (next)  
- PD-006-lem-city-graph-templates.md (next)  
- PD-006-lem-city-graph-links.md (next)

**LEM side:**  
- LEM-CORE.md — модель city graph (service_point, service_edge, cluster).  
- LEM-ROUTING.md — routing/paths.  
- LEM-METRICS.md — агрегація метрик за містом/кластером/точками.  
- LEM-FACETS.md — journey_facets / experience layers.

Мета документа — зафіксувати **контракт між Product DSL / Registry та LEM (city graph)**:

- як продукти прив’язуються до міста, service point класів та journey_facets;
- як LEM-граф використовується для runtime-поведінки продукту (маршрути, вибір точок, experience);
- які інваріанти по coverage/доступності потрібні для активації продукту.

---

## 1. Purpose & Scope

### 1.1 Purpose

- Визначити стабільний блок `integrations.lem` у ProductDef.
- Формалізувати mapping ProductVersion → LEM city graph:
  - city/market;
  - класи service points;
  - journey_facets (шари досвіду);
  - routing/metrics профілі.

### 1.2 Scope

Входить:

- логічна модель LEM-ентітій з точки зору Product DSL;
- mapping ProductDef → LEM-об’єкти та профілі;
- lifecycle-узгодження (продукт ↔ city graph coverage);
- runtime-патерни використання LEM (routing, experience, safety).

Не входить:

- внутрішня реалізація LEM-CORE/ROUTING/METRICS;
- low-level storage (див. PD-006-lem-city-graph.ddl.sql);
- UI-карти/візуалізації.

---

## 2. Core Concepts (LEM perspective)

### 2.1 ServicePointClass

- Логічний клас сервісної точки:
  - `cafe.coffee_partner`, `hotel.partner`, `poi.viewpoint`, `transit.stop`, `medical.facility` тощо.
- Визначається у LEM-CORE; може мати:
  - атрибути (opening_hours, tags, capabilities);
  - вимоги до геоданих (lat/lon, точність);
  - зв’язок із Trutta (чи є вендор, який приймає токени).

### 2.2 ServicePoint

- Конкретна сервісна точка в місті:
  - кафе, готель, парк, лікарня, станція.
- Ключові поля (логічно):
  - `service_point_id`;
  - `city_code`, `market_code`;
  - `class_id` (ServicePointClass);
  - гео (lat/lon);
  - vendor/partner ref (якщо є);
  - capability-теги (наприклад, `kidney_safe`, `family_friendly`, `nightlife`).

### 2.3 EdgeClass & ServiceEdge

- **EdgeClass** — тип зв’язку між точками:
  - `walk`, `transit`, `recommended_path`, `unsafe_edge`, `cluster_link` тощо.
- **ServiceEdge** — конкретний ребро:
  - `from_service_point_id`, `to_service_point_id`;
  - `edge_class_id`;
  - метрики (distance, travel_time, elevation, safety_score, cost_score).

### 2.4 JourneyFacet

- Логічний шар/"фасет" досвіду journey:
  - `coffee_walk`, `family_day`, `kidney_safe`, `nightlife`, `museum_hopper`.
- Може визначати:
  - фільтри по ServicePointClass/ServicePoint (які точки допустимі для цього фасету);
  - фільтри по ServiceEdge (які шляхи дозволені/бажані);
  - цільові метрики (макс. walking time, мін. safety_score, мін./макс. price рівень).

### 2.5 Cluster / CityExperienceLayer

- **Cluster** — група service points (район, квартал, food cluster).
- **CityExperienceLayer** — агреговані метрики по кластеру/району/фасету (LEM-METRICS).

---

## 3. ProductDef → LEM Mapping

### 3.1 Блок `integrations.lem` у ProductDef

Мінімальний варіант:

```yaml
integrations:
  lem:
    city_code: VIE
    market_code: AT-VIE

    service_point_classes:
      required:
        - cafe.coffee_partner
      optional:
        - poi.viewpoint

    journey_facets:
      primary:
        - coffee_walk
      safety:
        min_safety_score: 0.7
      mobility:
        max_walk_time_minutes: 15

    routing_profile_id:  LEM-ROUTE-VIEN-COFFEE-PASS
    metrics_profile_id:  LEM-METRICS-VIEN-COFFEE-PASS
```

### 3.2 Mapping table

| ProductDef поле                                    | LEM сутність / семантика                          |
|---------------------------------------------------|---------------------------------------------------|
| `integrations.lem.city_code`                      | city graph id (LEM City)                          |
| `integrations.lem.market_code`                    | market/shard в LEM / routing                      |
| `integrations.lem.service_point_classes.required` | обов’язкові ServicePointClass, що мають покриття  |
| `integrations.lem.service_point_classes.optional` | додаткові класи, що можуть використовуватись      |
| `integrations.lem.journey_facets.primary[]`       | базові journey_facets для цього продукту          |
| `integrations.lem.journey_facets.safety.*`        | параметри safety-фасету (мін. safety_score і т.п.)|
| `integrations.lem.journey_facets.mobility.*`      | mobility-фасет (макс. час/відстань тощо)          |
| `integrations.lem.routing_profile_id`             | LEM routing profile (алгоритми/пріоритети)        |
| `integrations.lem.metrics_profile_id`             | LEM metrics profile (які метрики рахувати)        |

### 3.3 Validation

При ingestion ProductDef:

1. Registry перевіряє, що `city_code` існує в LEM (через кеш city registry).
2. Валідує всі `service_point_classes.*` проти LEM ServicePointClass registry.
3. Валідує `routing_profile_id` / `metrics_profile_id` проти LEM-ROUTING/LEM-METRICS.
4. У разі помилок:
   - `REF_ERROR: LEM_CITY_NOT_FOUND`;
   - `REF_ERROR: LEM_SERVICE_POINT_CLASS_NOT_FOUND`;
   - `REF_ERROR: LEM_PROFILE_NOT_FOUND`;
   - `POLICY_ERROR: LEM_FACET_INCOMPATIBLE` (наприклад, недопустима комбінація фасетів).

---

## 4. Coverage & Availability

### 4.1 Coverage requirements

Продукт може вимагати мінімальне покриття певними ServicePointClass у місті:

```yaml
integrations:
  lem:
    coverage_requirements:
      cafe.coffee_partner:
        min_points: 20
        min_clusters: 3
      poi.viewpoint:
        min_points: 5
```

LEM-METRICS/CORE розраховують фактичне покриття.

### 4.2 Вплив на ProductVersion lifecycle

- Якщо coverage нижче порогів для prod env:
  - або забороняється активація ProductVersion (`POLICY_ERROR: LEM_COVERAGE_INSUFFICIENT`);
  - або продукт може бути `active` лише в subset міста (через overlays/filters).

- При деградації coverage (закриття вендорів, падіння safety score):
  - LEM емить події (`lem.coverage.degraded`), які можуть:
    - тригерити `product.overlay.updated` (обмеження районів/часу);
    - або запускати ops-процес (manual review).

---

## 5. Runtime: LEM у контексті Journey/TJM

### 5.1 Entry points та nodes

- TJM JourneyDoc (див. PD-004) може мати nodes, що залежать від LEM:
  - `select_service_point`;
  - `route_between_points`;
  - `check_safety/mobility constraints`.

- Через `integrations.lem` ProductVersion визначає, які класи точок та фасети доступні.

### 5.2 Routing calls

Runtime-патерн для побудови маршруту:

1. Агент/рантайм має:
   - `ProductJourneyConfig` (PD-004);
   - `integrations.lem` з ProductDef.
2. Викликає LEM-ROUTING:

```json
{
  "city_code": "VIE",
  "routing_profile_id": "LEM-ROUTE-VIEN-COFFEE-PASS",
  "origin_service_point_id": "SP-VIE-START-001",
  "target_classes": ["cafe.coffee_partner"],
  "journey_facets": ["coffee_walk"],
  "constraints": {
    "max_walk_time_minutes": 15,
    "min_safety_score": 0.7
  }
}
```

3. LEM-ROUTING повертає маршрут: послідовність ServicePoint/ServiceEdge з метриками.
4. TJM відображає це у journey nodes/steps.

### 5.3 Safety / experience checks

- Під час рантайму TJM/агенти можуть:
  - викликати LEM-METRICS для перевірки поточних safety/experience показників для району/кластеру;
  - обирати альтернативні точки/маршрути, якщо safety нижче порогу.

---

## 6. Events: LEM ↔ Registry / TJM / Trutta

### 6.1 LEM → Registry/TJM

Основні події:

- `lem.city.updated` — зміни в city config (коди, границі, кластери);
- `lem.service_point.updated` — зміни по конкретній точці (відкриття/закриття, теги);
- `lem.edge.updated` — зміни в ребрах (нові маршрути/обмеження);
- `lem.coverage.degraded` — падіння coverage для певних ServicePointClass/фасетів.

Використання:

- Registry може оновлювати dim-таблиці для довідників LEM;
- TJM/агенти можуть адаптувати journeys в реальному часі;
- Ops може ініціювати перевидачу/зміну продуктів.

### 6.2 Trutta links

- LEM може містити посилання на Trutta-вендорів (через vendor_id / wallet_id);
- події `entitlement.redeemed` можуть бути збагачені LEM-даними (cluster_id, neighborhood, facet_tags), для аналітики.

---

## 7. Ownership & Boundaries

### 7.1 Registry / Product DSL

- Own’ить:
  - блок `integrations.lem` у ProductDef;
  - coverage_requirements;
  - mapping продуктів на city graph/facets.

- Не own’ить:
  - фактичний city graph (service_point/service_edge);
  - runtime маршрути та метрики.

### 7.2 LEM

- Own’ить:
  - city graph (всі точки, ребра, кластери, фасети);
  - routing/metrics logic;
  - події про зміни в місті/сервісах.

### 7.3 TJM / Trutta

- TJM використовує LEM як джерело правди про простір та маршрути.
- Trutta використовує LEM-контекст для enrichment аналітики, fraud (наприклад, чи відповідає гео заявленій точці).

---

## 8. Summary

- PD-006 фіксує, як ProductDef прив’язується до LEM city graph через блок `integrations.lem`.
- Продукти задають:
  - місто/маркет;
  - класи сервісних точок;
  - journey_facets та coverage-вимоги;
  - routing/metrics профілі.
- LEM забезпечує фактичний graph, маршрути, метрики та події про зміни, не дублюючи логіку в Registry.
- Такий поділ дозволяє:
  - незалежно розвивати city graph (LEM) і продуктову модель;
  - формувати продукти, прив’язані до міського простору й досвіду, але не залежні від конкретної реалізації графа.

