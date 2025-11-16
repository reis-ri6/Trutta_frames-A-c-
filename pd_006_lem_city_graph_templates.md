# PD-006 LEM City Graph Templates v0.1

**Status:** Draft 0.1  
**Owner:** City Graph & Routing Architecture

**Related docs:**  
- PD-006-lem-city-graph-integration-spec.md  
- PD-006-lem-city-graph-ddl.sql  
- PD-006-lem-city-graph-links.md (next)

Мета — дати еталонні **YAML/JSON-шаблони** для:
- ServicePointClass / ServicePoint;
- EdgeClass / ServiceEdge;
- Cluster (міські кластери).

Усі приклади — для Vienna (VIE), продуктів типу *coffee walk*.

---

## 1. ServicePointClass Templates (logical YAML)

> Логічні класи сервісних точок, які потім використовуються у `lem_service_point.class_id`.

### 1.1 Cafe partner (coffee program)

```yaml
id: cafe.coffee_partner
kind: service_point_class

meta:
  title: "Coffee Partner Cafe"
  description: "Partner cafe participating in the coffee pass / Trutta program."
  owner: "lem-core@reis.agency"

capabilities:
  accepts_trutta_tokens: true
  seating:
    indoor: true
    outdoor: true
  service:
    takeaway: true
    table_service: true

required_geo:
  require_lat_lon: true
  require_address: true

tags_default:
  - "coffee"
  - "partner"

attributes_schema:
  price_level:        { type: "int",   min: 1, max: 5 }
  opening_hours:      { type: "string" }
  has_wifi:           { type: "bool" }
  power_outlets:      { type: "bool" }
  wheelchair_access:  { type: "bool" }
```

### 1.2 Viewpoint / POI

```yaml
id: poi.viewpoint
kind: service_point_class

meta:
  title: "City Viewpoint / POI"
  owner: "lem-core@reis.agency"

capabilities:
  accepts_trutta_tokens: false

required_geo:
  require_lat_lon: true
  require_address: false

tags_default:
  - "viewpoint"
  - "poi"

attributes_schema:
  category:    { type: "string" }   # park, monument, square
  popularity:  { type: "int", min: 0, max: 100 }
```

### 1.3 Transit stop

```yaml
id: transit.stop
kind: service_point_class

meta:
  title: "Transit Stop"

capabilities:
  accepts_trutta_tokens: false

required_geo:
  require_lat_lon: true

tags_default:
  - "transit"

attributes_schema:
  line_ids:          { type: "string[]" }
  operator:          { type: "string" }
  sheltered:         { type: "bool" }
```

---

## 2. ServicePoint Templates (YAML/JSON)

> Відповідає `lem_service_point` (DDL), використовується ingestion-пайплайнами.

### 2.1 Cafe partner (Vienna)

```yaml
service_point_id: SP-VIE-CAFE-0001
city_code: VIE
market_code: AT-VIE

class_id: cafe.coffee_partner

geo_lat: 48.208450
geo_lon: 16.372504

address_line1: "Graben 21"
address_line2: null
postal_code: "1010"
neighborhood: "Innere Stadt"

vendor_id: VEN-VIE-CAFE-0001
external_refs:
  google_places_id: "gp_1234567890"
  foursquare_id: "4abcdef01234567890"

tags:
  - "coffee"
  - "partner"
  - "kidney_safe"

attributes:
  price_level: 2
  opening_hours: "Mo-Su 08:00-21:00"
  has_wifi: true
  power_outlets: true
  wheelchair_access: true

status: active
created_at: "2025-11-01T09:00:00Z"
created_by: "seed-job-lem-vie"
updated_at: "2025-11-01T09:00:00Z"
updated_by: null
```

### 2.2 Viewpoint / POI

```json
{
  "service_point_id": "SP-VIE-POI-0001",
  "city_code": "VIE",
  "market_code": "AT-VIE",
  "class_id": "poi.viewpoint",
  "geo_lat": 48.207500,
  "geo_lon": 16.373000,
  "address_line1": null,
  "address_line2": null,
  "postal_code": null,
  "neighborhood": "Innere Stadt",
  "vendor_id": null,
  "external_refs": {
    "google_places_id": "gp_viewpoint_001"
  },
  "tags": ["viewpoint", "poi"],
  "attributes": {
    "category": "square",
    "popularity": 85
  },
  "status": "active",
  "created_at": "2025-11-01T09:05:00Z",
  "created_by": "seed-job-lem-vie",
  "updated_at": "2025-11-01T09:05:00Z",
  "updated_by": null
}
```

---

## 3. EdgeClass Templates (logical YAML)

> Логічні типи ребер, що потім використовуються в `lem_service_edge.edge_class_id`.

### 3.1 Walking edge

```yaml
id: edge.walk
kind: edge_class

meta:
  title: "Pedestrian walk edge"
  owner: "lem-core@reis.agency"

modes:
  allowed:
    - "walk"

metrics:
  expected_max_distance_meters: 3000
  expected_max_travel_time_seconds: 3600

preferences:
  default_safety_weight: 0.5
  default_scenic_weight: 0.3
  default_comfort_weight: 0.2

constraints:
  allow_night: true
```

### 3.2 Recommended path

```yaml
id: edge.recommended_path
kind: edge_class

meta:
  title: "Curated recommended route segment"

modes:
  allowed:
    - "walk"

metrics:
  expected_max_distance_meters: 2000

preferences:
  default_scenic_weight: 0.6
  default_comfort_weight: 0.3
  default_safety_weight: 0.1

constraints:
  recommended_for_facets:
    - "coffee_walk"
    - "museum_hopper"
```

### 3.3 Unsafe edge

```yaml
id: edge.unsafe
kind: edge_class

meta:
  title: "Unsafe or low-preference edge"

modes:
  allowed:
    - "walk"

metrics:
  expected_max_distance_meters: 1000

preferences:
  default_safety_weight: 1.0

constraints:
  never_use_if_min_safety_score: 0.7
```

---

## 4. ServiceEdge Templates (JSON)

> Відповідає `lem_service_edge` (DDL). Використовується routing-пайплайнами.

### 4.1 Walking edge між кафе та POI

```json
{
  "service_edge_id": "SE-VIE-WALK-0001",
  "from_service_point_id": "SP-VIE-CAFE-0001",
  "to_service_point_id": "SP-VIE-POI-0001",
  "edge_class_id": "edge.walk",
  "distance_meters": 350.0,
  "travel_time_seconds": 300,
  "elevation_up_m": 5.0,
  "elevation_down_m": 2.0,
  "safety_score": 0.9,
  "comfort_score": 0.8,
  "scenic_score": 0.7,
  "cost_score": 0.0,
  "is_bidirectional": true,
  "city_code": "VIE",
  "market_code": "AT-VIE",
  "status": "active",
  "metadata": {
    "source": "osm+manual_curated",
    "street_names": ["Graben", "Stephansplatz"]
  },
  "created_at": "2025-11-01T10:00:00Z",
  "created_by": "lem-routing-import",
  "updated_at": "2025-11-01T10:00:00Z",
  "updated_by": null
}
```

### 4.2 Recommended path сегмент

```json
{
  "service_edge_id": "SE-VIE-REC-0001",
  "from_service_point_id": "SP-VIE-CAFE-0001",
  "to_service_point_id": "SP-VIE-CAFE-0002",
  "edge_class_id": "edge.recommended_path",
  "distance_meters": 800.0,
  "travel_time_seconds": 600,
  "elevation_up_m": 3.0,
  "elevation_down_m": 5.0,
  "safety_score": 0.85,
  "comfort_score": 0.9,
  "scenic_score": 0.95,
  "cost_score": 0.0,
  "is_bidirectional": true,
  "city_code": "VIE",
  "market_code": "AT-VIE",
  "status": "active",
  "metadata": {
    "route_id": "VIE-COFFEE-WALK-001"
  },
  "created_at": "2025-11-01T10:05:00Z",
  "created_by": "lem-curated-routes",
  "updated_at": "2025-11-01T10:05:00Z",
  "updated_by": null
}
```

---

## 5. Cluster Templates (logical YAML)

> Логічні кластери міста. DDL може бути окремою (не обов’язково у PD-006-lem-city-graph-ddl.sql).

### 5.1 Coffee cluster в центрі Відня

```yaml
cluster_id: CL-VIE-COFFEE-CENTER
kind: service_cluster

city_code: VIE
market_code: AT-VIE

meta:
  title: "Vienna Center Coffee Cluster"
  description: "Dense walkable cluster of partner cafes in the city center."
  owner: "lem-core@reis.agency"

service_point_ids:
  - SP-VIE-CAFE-0001
  - SP-VIE-CAFE-0002
  - SP-VIE-CAFE-0003

centroid:
  geo_lat: 48.208800
  geo_lon: 16.372700

facet_tags:
  - "coffee_walk"
  - "tourist_friendly"

metrics:
  partner_density: 0.85
  avg_price_level: 2.3
  avg_safety_score: 0.92
  avg_scenic_score: 0.88
```

### 5.2 Mixed cluster (coffee + POI)

```yaml
cluster_id: CL-VIE-COFFEE-POI-RING
kind: service_cluster

city_code: VIE
market_code: AT-VIE

meta:
  title: "Vienna Ring Coffee & POI Cluster"

service_point_ids:
  - SP-VIE-CAFE-0001
  - SP-VIE-CAFE-0004
  - SP-VIE-POI-0001
  - SP-VIE-POI-0002

centroid:
  geo_lat: 48.210100
  geo_lon: 16.370900

facet_tags:
  - "coffee_walk"
  - "museum_hopper"

metrics:
  partner_density: 0.7
  poi_density: 0.6
```

---

## 6. Summary

- Шаблони ServicePointClass/ServicePoint задають, як ми описуємо точки в місті (кафе, POI, transit).  
- EdgeClass/ServiceEdge — як ми описуємо типи зв’язків і конкретні ребра для routing.  
- Cluster — логічні групи точок з метриками, які використовуються LEM-METRICS і продуктами (coverage, фасети досвіду).

Ці шаблони мають бути використані як еталон для seed-даних міст, тест-фікстур та документації для інтеграторів LEM.

