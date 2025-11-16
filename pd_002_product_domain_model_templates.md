# PD-002 Product Domain Model Templates v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture  

Мета документа — дати прикладові YAML/JSON структури для ключових сутностей доменної моделі (PD-002-product-domain-model.md), які можна використовувати як еталонні payload’и в API/CLI/фикстурах.

> Це не DDL і не повний API-контракт. Це референсні структури для Registry/ingestion/адмін-інтерфейсів.

---

## 1. Конвенції

- Плейсхолдери: `__LIKE_THIS__`.
- ID — текстові ULID/UUID-подібні значення.
- semver: `1.0.0`, `1.1.0` тощо.
- Дати — ISO-8601 UTC.

---

## 2. Product Core

### 2.1 Product (YAML)

```yaml
id: "__PRODUCT_ID__"              # ULID/UUID
code: "VG-VIEN-COFFEE-PASS"      # унікальний код в org
slug_base: "vienna-coffee-pass"  # базова частина slug
product_type: "PASS"             # PASS | SINGLE_SERVICE | PACKAGE | ADDON | ...
created_at: "2025-11-15T10:00:00Z"
created_by: "__AUTHOR_CONTACT__"
```

### 2.2 ProductVersion (YAML)

```yaml
id: "__PRODUCT_VERSION_ID__"
product_id: "__PRODUCT_ID__"
version: "1.0.0"                 # semver
status: "active"                 # draft | review | active | deprecated | retired
title_default: "Vienna Coffee Day Pass"
category_id: "__CATEGORY_ID__"   # посилання на Category
product_type: "PASS"             # денормалізовано з Product
valid_from: "2025-12-01T00:00:00Z"
valid_until: null
Dsl_document_ref: "s3://product-defs/viennacoffee/1.0.0.yaml"
created_at: "2025-11-15T10:00:00Z"
created_by: "product-arch@reis.agency"
updated_at: "2025-11-15T10:00:00Z"
```

### 2.3 ProductVersionTitles (YAML)

```yaml
product_version_id: "__PRODUCT_VERSION_ID__"
locale: "en"
title: "Vienna Coffee Day Pass"
```

### 2.4 ProductOverlay (YAML)

```yaml
id: "__OVERLAY_ID__"
base_product_version_id: "__PRODUCT_VERSION_ID__"
overlay_kind: "city"             # operator | market | city | vendor
operator_code: "TRUTTA-VIEN"     # для operator-оверлеїв
market_code: "AT-VIE"
city_code: "AT-VIE"
patch_payload:
  title:
    en: "Vienna Coffee Day Pass (Local Edition)"
  classification:
    tags_add: ["local"]
  profiles:
    financial_profile:
      overrides:
        currency: "EUR"
created_at: "2025-11-16T09:00:00Z"
created_by: "city-ops@reis.agency"
```

### 2.5 ProductVersion Categories / Tags / Markets / Segments (YAML)

```yaml
# product.product_version_categories
product_version_id: "__PRODUCT_VERSION_ID__"
category_id: "__CATEGORY_ID__"

# product.product_version_tags
product_version_id: "__PRODUCT_VERSION_ID__"
tag_id: "__TAG_ID__"

# product.product_version_markets
product_version_id: "__PRODUCT_VERSION_ID__"
market_id: "__MARKET_ID__"

# product.product_version_segments
product_version_id: "__PRODUCT_VERSION_ID__"
segment_id: "__SEGMENT_ID__"
```

---

## 3. Journeys & Runtime

### 3.1 JourneyClass (YAML)

```yaml
id: "city.coffee.pass"
description: "City pass for coffee entitlements within a day"
created_at: "2025-11-15T09:00:00Z"
```

Allowed product types (journey_class_product_types):

```yaml
journey_class_id: "city.coffee.pass"
product_type: "PASS"
```

### 3.2 JourneyDocumentRef (YAML)

```yaml
id: "__JOURNEY_DOC_REF_ID__"
journey_class_id: "city.coffee.pass"
version: "1.0.0"
document_ref: "TJM-JOURNEY-COFFEE-PASS@1.0.0"
status: "active"                  # draft | active | deprecated
created_at: "2025-11-15T09:30:00Z"
```

### 3.3 JourneyBinding (YAML)

```yaml
id: "__JOURNEY_BINDING_ID__"
product_version_id: "__PRODUCT_VERSION_ID__"
journey_document_ref_id: "__JOURNEY_DOC_REF_ID__"
entry_points:
  - "app.home.hero"
  - "city.vienna.offers"
state_map:
  created: "STATE_CREATED"
  issued: "STATE_ISSUED"
  redeemed: "STATE_REDEEMED"
  expired: "STATE_EXPIRED"
created_at: "2025-11-15T10:05:00Z"
```

---

## 4. Profiles

### 4.1 Profile (YAML)

```yaml
id: "FP-VIEN-COFFEE-PASS"        # Financial Profile\ nprofile_type: "financial"         # financial | token | loyalty | ops | safety | quality | ui | ...
scope: "global"                   # global | operator | market | city | vendor
owner_org: "reis.agency"
created_at: "2025-11-14T12:00:00Z"
```

### 4.2 ProfileVersion (YAML)

```yaml
id: "FP-VIEN-COFFEE-PASS@1.0.0"
profile_id: "FP-VIEN-COFFEE-PASS"
version: "1.0.0"
status: "active"                   # draft | active | deprecated | retired
payload:
  currency: "EUR"
  base_price:
    amount: "9.90"
    currency: "EUR"
  revenue_split:
    operator_share: 0.1
    vendor_share: 0.7
    protocol_share: 0.2
  taxes:
    vat_rate: 0.2
created_at: "2025-11-14T12:05:00Z"
updated_at: "2025-11-14T12:05:00Z"
```

### 4.3 ProductProfileBinding (YAML)

```yaml
id: "PPB-__ID__"
product_version_id: "__PRODUCT_VERSION_ID__"
profile_version_id: "FP-VIEN-COFFEE-PASS@1.0.0"
profile_type: "financial"         # копія з profiles.profile_type
role: "primary"                   # primary | fallback | campaign_override | ...
created_at: "2025-11-15T10:10:00Z"
```

Аналогічно створюються binding’и для `token`, `ops`, `ui`, `safety` тощо.

---

## 5. Integrations

### 5.1 IntegrationEndpoint (YAML)

```yaml
id: "TRUTTA-CORE"
kind: "trutta"                    # trutta | lem | reservation_system | host_system | billing | ...
external_system_id: "TRUTTA-PROD"
config_ref: "vault:trutta/prod/core"
created_at: "2025-11-10T08:00:00Z"
```

LEM-приклад:

```yaml
id: "LEM-HQ"
kind: "lem"
external_system_id: "LEM-PROD"
config_ref: "vault:lem/prod/core"
created_at: "2025-11-10T08:10:00Z"
```

### 5.2 IntegrationProfile (YAML)

Trutta entitlement profile:

```yaml
id: "TRT-ENT-VIEN-COFFEE-PASS"
integration_endpoint_id: "TRUTTA-CORE"
name: "Vienna Coffee Pass Entitlement Profile"
payload:
  entitlement_type: "PASS_VOUCHER"
  max_redemptions: 5
  validity_window_hours: 24
  fraud_checks:
    - "geo_radius_check"
    - "device_fingerprint_check"
  vendor_set:
    id: "VSET-VIEN-COFFEE"
created_at: "2025-11-11T09:00:00Z"
```

LEM city-graph profile:

```yaml
id: "LEM-CITY-VIE-COFFEE-PASS"
integration_endpoint_id: "LEM-HQ"
name: "Vienna Coffee Graph Profile"
payload:
  service_point_class: "coffee_shop"
  cluster_id: "VIE-COFFEE-CLUSTER-01"
  default_edges:
    - "COFFEE_LOOP_1"
    - "COFFEE_LOOP_2"
created_at: "2025-11-11T09:05:00Z"
```

### 5.3 ProductIntegrationBinding (YAML)

```yaml
id: "PIB-__ID__"
product_version_id: "__PRODUCT_VERSION_ID__"
integration_profile_id: "TRT-ENT-VIEN-COFFEE-PASS"
purpose: "entitlement"             # entitlement | settlement | city_graph | reservation | host_mapping | ...
created_at: "2025-11-15T10:15:00Z"
```

LEM binding для того ж продукту:

```yaml
id: "PIB-__ID2__"
product_version_id: "__PRODUCT_VERSION_ID__"
integration_profile_id: "LEM-CITY-VIE-COFFEE-PASS"
purpose: "city_graph"
created_at: "2025-11-15T10:16:00Z"
```

---

## 6. Taxonomy & Segmentation

### 6.1 Category (YAML)

```yaml
id: "CAT-FOOD-BEVERAGE"
code: "food-and-beverage"
parent_id: null
title: "Food & Beverage"
created_at: "2025-11-10T07:00:00Z"
```

### 6.2 Tag (YAML)

```yaml
id: "TAG-VIENNA"
code: "vienna"
title: "Vienna"
created_at: "2025-11-10T07:05:00Z"
```

### 6.3 Market (YAML)

```yaml
id: "MKT-AT-VIE"
code: "AT-VIE"
geo_scope: "city"                   # country | region | city | custom
created_at: "2025-11-10T07:10:00Z"
```

### 6.4 Segment (YAML)

```yaml
id: "SEG-TRAVELER"
code: "traveler"
description: "General travelers visiting a city for leisure or business"
created_at: "2025-11-10T07:15:00Z"
```

---

## 7. JSON-приклад повного зрізу Product Core

У скороченому вигляді (Product + ProductVersion + JourneyBinding + основні binding’и):

```json
{
  "product": {
    "id": "PRD-VIEN-COFFEE-PASS",
    "code": "VG-VIEN-COFFEE-PASS",
    "slug_base": "vienna-coffee-day-pass",
    "product_type": "PASS",
    "created_at": "2025-11-15T10:00:00Z",
    "created_by": "product-arch@reis.agency"
  },
  "product_version": {
    "id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "version": "1.0.0",
    "status": "active",
    "title_default": "Vienna Coffee Day Pass",
    "category_id": "CAT-FOOD-BEVERAGE",
    "product_type": "PASS",
    "valid_from": "2025-12-01T00:00:00Z",
    "valid_until": null,
    "dsl_document_ref": "s3://product-defs/viennacoffee/1.0.0.yaml",
    "created_at": "2025-11-15T10:00:00Z",
    "created_by": "product-arch@reis.agency",
    "updated_at": "2025-11-15T10:00:00Z"
  },
  "titles": [
    {
      "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
      "locale": "en",
      "title": "Vienna Coffee Day Pass"
    }
  ],
  "journey_binding": {
    "id": "JB-VIEN-COFFEE-PASS-1.0.0",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "journey_document_ref_id": "JD-VIEN-COFFEE-PASS-1.0.0",
    "entry_points": ["app.home.hero", "city.vienna.offers"],
    "state_map": {
      "created": "STATE_CREATED",
      "issued": "STATE_ISSUED",
      "redeemed": "STATE_REDEEMED",
      "expired": "STATE_EXPIRED"
    },
    "created_at": "2025-11-15T10:05:00Z"
  },
  "profile_bindings": [
    {
      "id": "PPB-FIN-VIEN-COFFEE-PASS-1.0.0",
      "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
      "profile_version_id": "FP-VIEN-COFFEE-PASS@1.0.0",
      "profile_type": "financial",
      "role": "primary",
      "created_at": "2025-11-15T10:10:00Z"
    }
  ],
  "integration_bindings": [
    {
      "id": "PIB-TRT-VIEN-COFFEE-PASS",
      "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
      "integration_profile_id": "TRT-ENT-VIEN-COFFEE-PASS",
      "purpose": "entitlement",
      "created_at": "2025-11-15T10:15:00Z"
    },
    {
      "id": "PIB-LEM-VIEN-COFFEE-PASS",
      "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
      "integration_profile_id": "LEM-CITY-VIE-COFFEE-PASS",
      "purpose": "city_graph",
      "created_at": "2025-11-15T10:16:00Z"
    }
  ],
  "taxonomy": {
    "categories": ["CAT-FOOD-BEVERAGE"],
    "tags": ["TAG-VIENNA", "TAG-COFFEE"],
    "markets": ["MKT-AT-VIE"],
    "segments": ["SEG-TRAVELER"]
  }
}
```

Ці темплейти задають канонічний "shape" об’єктів доменної моделі й можуть слугувати основою для REST/GraphQL контрактів, CLI-команд, сидерів і тестових фікстур.

