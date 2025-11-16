# PD-001 Product DSL Core Templates v0.1

**Status:** Draft 0.1  
**Owner:** Product & Platform Architecture  

Мета цього документу — дати готові до копіювання шаблони ProductDef для різних типів продуктів, а також реюзабельні фрагменти блоку `meta`, `identity`, `classification`, `lifecycle`, `journey`, `profiles`, `integrations`.

> Нормативна структура та інваріанти описані в **PD-001-product-dsl-core-spec.md**. Тут — лише темплейти.

---

## 1. Загальні конвенції

- Плейсхолдери записуються як `__LIKE_THIS__`.
- Усі ідентифікатори (`product_id`, `profile_id`, `journey_class`) — стабільні строки, що видаються Registry / відповідним сервісом.
- Прикладова локалізація мінімальна (`en`), інші мови додаються симетрично.
- Усі дати — ISO‑8601 UTC.

---

## 2. Базові фрагменти

### 2.1 `meta` фрагмент

```yaml
meta:
  spec_version: "1.0.0"                 # версія DSL‑спеки
  created_at: "__CREATED_AT_ISO__"      # напр. 2025-11-15T10:00:00Z
  updated_at: "__UPDATED_AT_ISO__"      # оновлюється при кожній зміні
  author: "__AUTHOR_CONTACT__"          # e-mail або технічний slug
  source_repo: "__GIT_REPO_AND_PATH__"  # git url + шлях до файлу
```

### 2.2 `identity` фрагмент

```yaml
identity:
  product_id: "__PRODUCT_ULID__"        # призначається Registry
  product_code: "__PRODUCT_CODE__"      # читабельний код, унікальний в org
  slug: "__PRODUCT_SLUG__"             # url-friendly
  version: "__SEMVER__"                 # напр. 1.0.0
  title:
    en: "__PRODUCT_TITLE_EN__"
```

### 2.3 `classification` фрагмент

```yaml
classification:
  product_type: "__PRODUCT_TYPE__"      # PASS | SINGLE_SERVICE | PACKAGE | ADDON
  category: "__CATEGORY__"              # food-and-beverage | city-pass | ...
  tags: [__TAG_1__, __TAG_2__]
  markets: ["__MARKET_CODE__"]          # напр. AT-VIE
  segments: ["__SEGMENT_1__", "__SEGMENT_2__"]
```

### 2.4 `lifecycle` фрагмент

```yaml
lifecycle:
  status: "__STATUS__"                  # draft | review | active | deprecated | retired
  valid_from: "__VALID_FROM_ISO__"      # допускається null
  valid_until: "__VALID_UNTIL_ISO__"    # допускається null
  replaces: "__PREVIOUS_PRODUCT_REF__"  # optional
  superseded_by: null                    # зазвичай ведеться Registry
```

### 2.5 `journey` фрагмент

```yaml
journey:
  journey_class: "__JOURNEY_CLASS_ID__"       # напр. city.coffee.pass
  tjm_document_ref: "__TJM_DOC_REF__"        # напр. TJM-JOURNEY-COFFEE-PASS@1.0.0
  entry_points: ["__ENTRY_POINT_1__"]        # напр. app.home.hero
  states:
    created: {}
    issued: {}
    redeemed: {}
    expired: {}
```

### 2.6 `profiles` фрагмент

```yaml
profiles:
  token_profile: { profile_id: "__TOKEN_PROFILE_ID__" }
  financial_profile: { profile_id: "__FINANCIAL_PROFILE_ID__" }
  ops_profile: { profile_id: "__OPS_PROFILE_ID__" }
  ui_profile: { profile_id: "__UI_PROFILE_ID__" }
  # loyalty_profile, safety_profile, quality_profile додаються за потреби
```

### 2.7 `integrations` фрагмент

```yaml
integrations:
  trutta:
    entitlement_profile_id: "__TRUTTA_ENTITLEMENT_PROFILE_ID__"
  lem:
    city_graph_profile_id: "__LEM_CITY_GRAPH_PROFILE_ID__"
  external: {}
```

---

## 3. Шаблони ProductDef за типами продуктів

### 3.1 ProductDef для `PASS`

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "__CREATED_AT_ISO__"
  updated_at: "__UPDATED_AT_ISO__"
  author: "__AUTHOR_CONTACT__"
  source_repo: "__GIT_REPO_AND_PATH__"

identity:
  product_id: "__PRODUCT_ULID__"
  product_code: "__PASS_PRODUCT_CODE__"      # напр. VG-VIEN-COFFEE-PASS
  slug: "__PASS_SLUG__"                      # напр. vienna-coffee-day-pass
  version: "__SEMVER__"
  title:
    en: "__PASS_TITLE_EN__"

classification:
  product_type: "PASS"
  category: "__CATEGORY__"                    # напр. food-and-beverage
  tags: [__TAG_1__, __TAG_2__]
  markets: ["__MARKET_CODE__"]
  segments: ["__SEGMENT_1__", "__SEGMENT_2__"]

lifecycle:
  status: "draft"
  valid_from: null
  valid_until: null
  replaces: null
  superseded_by: null

journey:
  journey_class: "__JOURNEY_CLASS_ID__"       # напр. city.coffee.pass
  tjm_document_ref: "__TJM_DOC_REF__"
  entry_points: ["__ENTRY_POINT_1__", "__ENTRY_POINT_2__"]
  states:
    created: {}
    issued: {}
    redeemed: {}
    expired: {}

profiles:
  token_profile: { profile_id: "__TOKEN_PROFILE_ID__" }
  financial_profile: { profile_id: "__FINANCIAL_PROFILE_ID__" }
  ops_profile: { profile_id: "__OPS_PROFILE_ID__" }
  ui_profile: { profile_id: "__UI_PROFILE_ID__" }

integrations:
  trutta:
    entitlement_profile_id: "__TRUTTA_ENTITLEMENT_PROFILE_ID__"
  lem:
    city_graph_profile_id: "__LEM_CITY_GRAPH_PROFILE_ID__"
  external: {}
```

---

### 3.2 ProductDef для `SINGLE_SERVICE`

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "__CREATED_AT_ISO__"
  updated_at: "__UPDATED_AT_ISO__"
  author: "__AUTHOR_CONTACT__"
  source_repo: "__GIT_REPO_AND_PATH__"

identity:
  product_id: "__PRODUCT_ULID__"
  product_code: "__SERVICE_PRODUCT_CODE__"   # напр. VG-VIEN-COFFEE-TASTING
  slug: "__SERVICE_SLUG__"
  version: "__SEMVER__"
  title:
    en: "__SERVICE_TITLE_EN__"

classification:
  product_type: "SINGLE_SERVICE"
  category: "__CATEGORY__"                    # напр. tasting-experience
  tags: [__TAG_1__, __TAG_2__]
  markets: ["__MARKET_CODE__"]
  segments: ["__SEGMENT_1__", "__SEGMENT_2__"]

lifecycle:
  status: "draft"
  valid_from: null
  valid_until: null
  replaces: null
  superseded_by: null

journey:
  journey_class: "__JOURNEY_CLASS_ID__"       # напр. city.experience.single
  tjm_document_ref: "__TJM_DOC_REF__"
  entry_points: ["__ENTRY_POINT_1__"]
  states:
    created: {}
    booked: {}
    completed: {}
    cancelled: {}

profiles:
  token_profile: { profile_id: "__TOKEN_PROFILE_ID__" }   # опціонально
  financial_profile: { profile_id: "__FINANCIAL_PROFILE_ID__" }
  ops_profile: { profile_id: "__OPS_PROFILE_ID__" }
  ui_profile: { profile_id: "__UI_PROFILE_ID__" }

integrations:
  trutta:
    entitlement_profile_id: "__TRUTTA_ENTITLEMENT_PROFILE_ID__"  # може бути null
  lem:
    city_graph_profile_id: "__LEM_CITY_GRAPH_PROFILE_ID__"       # venue/experience ноди
  external:
    reservation_system:
      integration_id: "__INTEGRATION_ID__"
      external_product_code: "__EXTERNAL_CODE__"
```

---

### 3.3 ProductDef для `PACKAGE`

`PACKAGE` — композиція з кількох інших продуктів/ентайтлів.

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "__CREATED_AT_ISO__"
  updated_at: "__UPDATED_AT_ISO__"
  author: "__AUTHOR_CONTACT__"
  source_repo: "__GIT_REPO_AND_PATH__"

identity:
  product_id: "__PRODUCT_ULID__"
  product_code: "__PACKAGE_PRODUCT_CODE__"  # напр. VG-VIEN-COFFEE-SPA-WEEKEND
  slug: "__PACKAGE_SLUG__"
  version: "__SEMVER__"
  title:
    en: "__PACKAGE_TITLE_EN__"

classification:
  product_type: "PACKAGE"
  category: "__CATEGORY__"                    # напр. weekend-package
  tags: [__TAG_1__, __TAG_2__]
  markets: ["__MARKET_CODE__"]
  segments: ["__SEGMENT_1__", "__SEGMENT_2__"]

lifecycle:
  status: "draft"
  valid_from: null
  valid_until: null
  replaces: null
  superseded_by: null

journey:
  journey_class: "__JOURNEY_CLASS_ID__"       # напр. weekend.package
  tjm_document_ref: "__TJM_DOC_REF__"
  entry_points: ["__ENTRY_POINT_1__"]
  states:
    created: {}
    booked: {}
    in_progress: {}
    completed: {}
    cancelled: {}

profiles:
  token_profile: { profile_id: "__TOKEN_PROFILE_ID__" }
  financial_profile: { profile_id: "__FINANCIAL_PROFILE_ID__" }
  ops_profile: { profile_id: "__OPS_PROFILE_ID__" }
  ui_profile: { profile_id: "__UI_PROFILE_ID__" }

integrations:
  trutta:
    entitlement_profile_id: "__TRUTTA_ENTITLEMENT_PROFILE_ID__"  # пакетний entitlement або набір
  lem:
    city_graph_profile_id: "__LEM_CITY_GRAPH_PROFILE_ID__"
  external: {}

# Додатковий блок композиції (опційно, але рекомендовано для PACKAGE)
package_components:
  - product_ref: "__CHILD_PRODUCT_ID_OR_CODE_1__"
    quantity: 1
  - product_ref: "__CHILD_PRODUCT_ID_OR_CODE_2__"
    quantity: 1
```

---

### 3.4 ProductDef для `ADDON`

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "__CREATED_AT_ISO__"
  updated_at: "__UPDATED_AT_ISO__"
  author: "__AUTHOR_CONTACT__"
  source_repo: "__GIT_REPO_AND_PATH__"

identity:
  product_id: "__PRODUCT_ULID__"
  product_code: "__ADDON_PRODUCT_CODE__"     # напр. VG-VIEN-LATE-CHECKOUT
  slug: "__ADDON_SLUG__"
  version: "__SEMVER__"
  title:
    en: "__ADDON_TITLE_EN__"

classification:
  product_type: "ADDON"
  category: "__CATEGORY__"                    # напр. addon
  tags: [__TAG_1__, __TAG_2__]
  markets: ["__MARKET_CODE__"]
  segments: ["__SEGMENT_1__", "__SEGMENT_2__"]

lifecycle:
  status: "draft"
  valid_from: null
  valid_until: null
  replaces: null
  superseded_by: null

journey:
  journey_class: "__JOURNEY_CLASS_ID__"       # напр. addon.to.hotel.stay
  tjm_document_ref: "__TJM_DOC_REF__"
  entry_points: ["__ENTRY_POINT_1__"]         # напр. booking.addons
  states:
    created: {}
    attached: {}
    consumed: {}
    cancelled: {}

profiles:
  financial_profile: { profile_id: "__FINANCIAL_PROFILE_ID__" }
  ops_profile: { profile_id: "__OPS_PROFILE_ID__" }
  ui_profile: { profile_id: "__UI_PROFILE_ID__" }

integrations:
  trutta: null
  lem: null
  external:
    host_system:
      integration_id: "__INTEGRATION_ID__"
      external_addon_code: "__EXTERNAL_CODE__"

addon_constraints:
  attachable_to_product_types: ["PASS", "PACKAGE", "SINGLE_SERVICE"]
  must_be_attached_before: "checkin"         # семантичний маркер з TJM
```

---

## 4. Оверлеї: Global / Operator / Market / City

### 4.1 Загальний патерн оверлею

Оверлей описується як окремий артефакт, що посилається на `base_product_id` і змінює/доповнює обмежений набір полів.

```yaml
meta:
  spec_version: "1.0.0"
  created_at: "__CREATED_AT_ISO__"
  updated_at: "__UPDATED_AT_ISO__"
  author: "__AUTHOR_CONTACT__"
  source_repo: "__GIT_REPO_AND_PATH__"

overlay:
  kind: "operator"                          # operator | market | city | vendor
  base_product_id: "__BASE_PRODUCT_ID__"    # посилання на глобальний продукт
  overlay_id: "__OVERLAY_ID__"              # стабільний id оверлею
  operator_code: "__OPERATOR_CODE__"        # напр. MPT-TOURS, TRUTTA-VIEN
  market: "__MARKET_CODE__"                 # опційно (для market/city)
  city: "__CITY_CODE__"                     # напр. AT-VIE

patch:
  title:
    en: "__OVERRIDDEN_TITLE_EN__"
  classification:
    tags_add: ["__EXTRA_TAG__"]
  lifecycle:
    valid_from: "__VALID_FROM_ISO__"
    valid_until: "__VALID_UNTIL_ISO__"
  profiles:
    financial_profile:
      overrides:
        currency: "__LOCAL_CURRENCY__"
  integrations:
    trutta:
      entitlement_profile_id: "__LOCAL_TRUTTA_PROFILE_ID__"
```

Конкретна механіка застосування `patch` (мердж‑стратегія, allowed fields) формалізується в PD-003 та PD-007. У цьому документі фіксується лише загальний вигляд.

---

## 5. JSON‑шаблон (мінімальний PASS продукт)

Для інтеграцій, де потрібен JSON, базовий YAML‑шаблон для PASS віддзеркалюється 1:1.

```json
{
  "meta": {
    "spec_version": "1.0.0",
    "created_at": "__CREATED_AT_ISO__",
    "updated_at": "__UPDATED_AT_ISO__",
    "author": "__AUTHOR_CONTACT__",
    "source_repo": "__GIT_REPO_AND_PATH__"
  },
  "identity": {
    "product_id": "__PRODUCT_ULID__",
    "product_code": "__PASS_PRODUCT_CODE__",
    "slug": "__PASS_SLUG__",
    "version": "__SEMVER__",
    "title": {
      "en": "__PASS_TITLE_EN__"
    }
  },
  "classification": {
    "product_type": "PASS",
    "category": "__CATEGORY__",
    "tags": ["__TAG_1__", "__TAG_2__"],
    "markets": ["__MARKET_CODE__"],
    "segments": ["__SEGMENT_1__", "__SEGMENT_2__"]
  },
  "lifecycle": {
    "status": "draft",
    "valid_from": null,
    "valid_until": null,
    "replaces": null,
    "superseded_by": null
  },
  "journey": {
    "journey_class": "__JOURNEY_CLASS_ID__",
    "tjm_document_ref": "__TJM_DOC_REF__",
    "entry_points": ["__ENTRY_POINT_1__"],
    "states": {
      "created": {},
      "issued": {},
      "redeemed": {},
      "expired": {}
    }
  },
  "profiles": {
    "token_profile": { "profile_id": "__TOKEN_PROFILE_ID__" },
    "financial_profile": { "profile_id": "__FINANCIAL_PROFILE_ID__" },
    "ops_profile": { "profile_id": "__OPS_PROFILE_ID__" },
    "ui_profile": { "profile_id": "__UI_PROFILE_ID__" }
  },
  "integrations": {
    "trutta": {
      "entitlement_profile_id": "__TRUTTA_ENTITLEMENT_PROFILE_ID__"
    },
    "lem": {
      "city_graph_profile_id": "__LEM_CITY_GRAPH_PROFILE_ID__"
    },
    "external": {}
  }
}
```

Цей JSON‑шаблон може використовуватись у CLI‑інструментах, тестових фікстурах та API‑контрактах. Повні бібліотеки прикладів з реальними значеннями будуть зібрані в PD-014-examples-and-templates-library.md.

