# PD-003 Registry and Versioning Templates v0.1

**Status:** Draft 0.1  
**Owner:** Platform / Product Architecture

**Related docs:**  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry-ddl.sql  
- PD-003-registry-api.yaml  
- PD-002-product-domain-model-templates.md

Мета документа — дати **еталонні приклади запитів/відповідей** до Registry та payload’ів подій/CLI-операцій, прив’язаних до моделі версіонування.

---

## 1. Ingestion: registerProductDef

### 1.1 Request (JSON, prod)

```bash
curl -X POST "https://api.example.com/v1/product-defs" \
  -H "Content-Type: application/json" \
  -H "X-Env: prod" \
  -d @vienna-coffee-pass.productdef.json
```

Приклад `vienna-coffee-pass.productdef.json` (скорочено):

```json
{
  "identity": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_code": "VG-VIEN-COFFEE-PASS",
    "version": "1.0.0",
    "slug": "vienna-coffee-day-pass"
  },
  "meta": {
    "spec_version": "1.0.0",
    "owner": "product-arch@reis.agency"
  },
  "classification": {
    "product_type": "PASS",
    "category_code": "food-and-beverage",
    "tags": ["vienna", "coffee", "day-pass"],
    "markets": ["AT-VIE"],
    "segments": ["traveler"]
  },
  "lifecycle": {
    "status": "draft",
    "valid_from": "2025-12-01T00:00:00Z"
  },
  "journey": {
    "journey_class_id": "city.coffee.pass",
    "journey_doc_ref": "TJM-JOURNEY-COFFEE-PASS@1.0.0",
    "entry_points": ["app.home.hero", "city.vienna.offers"]
  },
  "profiles": {
    "financial_profile_id": "FP-VIEN-COFFEE-PASS@1.0.0",
    "token_profile_id": "TP-VIEN-COFFEE-PASS@1.0.0"
  },
  "integrations": {
    "trutta": {
      "entitlement_profile_id": "TRT-ENT-VIEN-COFFEE-PASS",
      "settlement_profile_id": "TRT-SET-VIEN-COFFEE-PASS"
    },
    "lem": {
      "city_graph_profile_id": "LEM-CITY-VIE-COFFEE-PASS"
    }
  }
}
```

### 1.2 Response: success

```json
{
  "product_id": "PRD-VIEN-COFFEE-PASS",
  "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "env": "prod",
  "dry_run": false,
  "ingestion_run_id": "IR-20251115-0001",
  "status": "succeeded",
  "error": null
}
```

### 1.3 Response: schema/domain error

```json
{
  "error_code": "SCHEMA_ERROR",
  "message": "Invalid field: classification.product_type must be a non-empty string",
  "details": {
    "path": "$.classification.product_type",
    "expected": "string(non-empty)",
    "actual": null
  }
}
```

---

## 2. Зміна статусу: setProductVersionStatus

### 2.1 Request: review → active

```bash
curl -X POST "https://api.example.com/v1/products/PRD-VIEN-COFFEE-PASS/versions/1.0.0/status" \
  -H "Content-Type: application/json" \
  -H "X-Env: prod" \
  -d '{
    "status": "active",
    "reason": "All checks passed; approved by Council",
    "metadata": {
      "approval_ticket": "CC-1234",
      "approved_by": "council@reis.agency"
    }
  }'
```

### 2.2 Response: success

```json
{
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
  "updated_at": "2025-11-15T11:30:00Z"
}
```

### 2.3 Response: invalid transition (retired → active)

```json
{
  "error_code": "INVALID_STATUS_TRANSITION",
  "message": "Cannot transition from retired to active",
  "details": {
    "current_status": "retired",
    "requested_status": "active"
  }
}
```

---

## 3. Overlay: create / update

### 3.1 Create overlay (market)

```bash
curl -X POST "https://api.example.com/v1/products/PRD-VIEN-COFFEE-PASS/overlays" \
  -H "Content-Type: application/json" \
  -H "X-Env: prod" \
  -d '{
    "base_product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "overlay_kind": "market",
    "market_code": "AT-VIE",
    "patch_payload": {
      "title": {
        "en": "Vienna Coffee Day Pass (Local Edition)"
      },
      "profiles": {
        "financial_profile": {
          "overrides": {
            "currency": "EUR",
            "taxes": {
              "vat_rate": 0.2
            }
          }
        }
      }
    }
  }'
```

### 3.2 Response: overlay created

```json
{
  "id": "OV-VIEN-COFFEE-PASS-AT-VIE",
  "base_product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "overlay_kind": "market",
  "operator_code": null,
  "market_code": "AT-VIE",
  "city_code": null,
  "patch_payload": {
    "title": {
      "en": "Vienna Coffee Day Pass (Local Edition)"
    },
    "profiles": {
      "financial_profile": {
        "overrides": {
          "currency": "EUR",
          "taxes": {
            "vat_rate": 0.2
          }
        }
      }
    }
  },
  "status": "active",
  "created_at": "2025-11-15T12:00:00Z",
  "created_by": "city-ops@reis.agency"
}
```

### 3.3 Update overlay (disable)

```bash
curl -X PATCH "https://api.example.com/v1/overlays/OV-VIEN-COFFEE-PASS-AT-VIE" \
  -H "Content-Type: application/json" \
  -H "X-Env: prod" \
  -d '{
    "status": "disabled"
  }'
```

### 3.4 Response: overlay updated

```json
{
  "id": "OV-VIEN-COFFEE-PASS-AT-VIE",
  "base_product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "overlay_kind": "market",
  "operator_code": null,
  "market_code": "AT-VIE",
  "city_code": null,
  "patch_payload": {
    "title": {
      "en": "Vienna Coffee Day Pass (Local Edition)"
    },
    "profiles": {
      "financial_profile": {
        "overrides": {
          "currency": "EUR",
          "taxes": {
            "vat_rate": 0.2
          }
        }
      }
    }
  },
  "status": "disabled",
  "created_at": "2025-11-15T12:00:00Z",
  "created_by": "city-ops@reis.agency"
}
```

---

## 4. Resolution: getActiveProductVersion / resolveProductForContext

### 4.1 Get active version for context

```bash
curl "https://api.example.com/v1/products/PRD-VIEN-COFFEE-PASS/active-version?market_code=AT-VIE" \
  -H "X-Env: prod"
```

#### Response

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
  "version": {
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
    "updated_at": "2025-11-15T11:30:00Z"
  }
}
```

### 4.2 Resolve product for context (base + overlays)

```bash
curl "https://api.example.com/v1/products/PRD-VIEN-COFFEE-PASS/resolve?market_code=AT-VIE" \
  -H "X-Env: prod"
```

#### Response

```json
{
  "base_version": {
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
    "updated_at": "2025-11-15T11:30:00Z"
  },
  "overlays": [
    {
      "id": "OV-VIEN-COFFEE-PASS-AT-VIE",
      "base_product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
      "overlay_kind": "market",
      "operator_code": null,
      "market_code": "AT-VIE",
      "city_code": null,
      "patch_payload": {
        "title": {
          "en": "Vienna Coffee Day Pass (Local Edition)"
        },
        "profiles": {
          "financial_profile": {
            "overrides": {
              "currency": "EUR",
              "taxes": {
                "vat_rate": 0.2
              }
            }
          }
        }
      },
      "status": "active",
      "created_at": "2025-11-15T12:00:00Z",
      "created_by": "city-ops@reis.agency"
    }
  ],
  "resolved": {
    "identity": {
      "product_id": "PRD-VIEN-COFFEE-PASS",
      "version": "1.0.0"
    },
    "title": {
      "en": "Vienna Coffee Day Pass (Local Edition)"
    },
    "classification": {
      "product_type": "PASS",
      "category_code": "food-and-beverage",
      "tags": ["vienna", "coffee", "day-pass"],
      "markets": ["AT-VIE"],
      "segments": ["traveler"]
    },
    "profiles": {
      "financial_profile": {
        "currency": "EUR",
        "taxes": {
          "vat_rate": 0.2
        }
      }
    },
    "integrations": {
      "trutta": {
        "entitlement_profile_id": "TRT-ENT-VIEN-COFFEE-PASS"
      },
      "lem": {
        "city_graph_profile_id": "LEM-CITY-VIE-COFFEE-PASS"
      }
    }
  }
}
```

---

## 5. Search & Listing

### 5.1 Search products

```bash
curl "https://api.example.com/v1/products/search?market_code=AT-VIE&status=active&limit=20" \
  -H "X-Env: prod"
```

#### Response

```json
{
  "items": [
    {
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
      "updated_at": "2025-11-15T11:30:00Z"
    }
  ],
  "next_cursor": null
}
```

### 5.2 List product versions

```bash
curl "https://api.example.com/v1/products/PRD-VIEN-COFFEE-PASS/versions?status=active" \
  -H "X-Env: prod"
```

#### Response

```json
{
  "items": [
    {
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
      "updated_at": "2025-11-15T11:30:00Z"
    }
  ],
  "next_cursor": null
}
```

---

## 6. Події (Outbox → Message Bus)

### 6.1 product.version.created

```json
{
  "id": "EV-20251115-0001",
  "aggregate_type": "product_version",
  "aggregate_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "event_type": "product.version.created",
  "payload": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "env": "prod",
    "version": "1.0.0",
    "status": "draft",
    "markets": ["AT-VIE"],
    "product_type": "PASS"
  },
  "created_at": "2025-11-15T10:00:10Z"
}
```

### 6.2 product.version.status_changed

```json
{
  "id": "EV-20251115-0002",
  "aggregate_type": "product_version",
  "aggregate_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
  "event_type": "product.version.status_changed",
  "payload": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "env": "prod",
    "old_status": "review",
    "new_status": "active",
    "markets": ["AT-VIE"],
    "product_type": "PASS"
  },
  "created_at": "2025-11-15T11:30:05Z"
}
```

### 6.3 product.overlay.created

```json
{
  "id": "EV-20251115-0003",
  "aggregate_type": "overlay",
  "aggregate_id": "OV-VIEN-COFFEE-PASS-AT-VIE",
  "event_type": "product.overlay.created",
  "payload": {
    "overlay_id": "OV-VIEN-COFFEE-PASS-AT-VIE",
    "base_product_version_id": "PRDV-VIEN-COFFEE-PASS-1.0.0",
    "overlay_kind": "market",
    "market_code": "AT-VIE",
    "status": "active"
  },
  "created_at": "2025-11-15T12:00:05Z"
}
```

---

## 7. CLI-шаблони (логічні)

> Реалізація CLI не фіксується, але payload’и/опції мають відповідати API.

### 7.1 Регистрация продукту

```bash
registry-cli product ingest \
  --env prod \
  --file ./vienna-coffee-pass.productdef.yaml
```

Очікуваний лог:

```text
[info] Submitting ProductDef: ./vienna-coffee-pass.productdef.yaml (env=prod)
[info] Ingestion run: IR-20251115-0001
[ok]  ProductVersion created: PRDV-VIEN-COFFEE-PASS-1.0.0 (status=draft)
```

### 7.2 Промоція версії між середовищами

```bash
registry-cli product promote \
  --product-id PRD-VIEN-COFFEE-PASS \
  --version 1.0.0 \
  --from stage \
  --to prod
```

---

## 8. Summary

Темплейти в цьому документі покривають:

- базові write-операції: ingestion, зміна статусу, створення/оновлення overlay;
- read-операції: пошук, листинг, резолюція для контексту;
- події з outbox для інтеграції з TJM/Trutta/LEM/аналітикою;
- CLI-фрагменти як довідник для DevEx.

Це базовий "канон" для контрактів Registry, який повинен залишатися стабільним, доки не буде MAJOR-зміни в PD-003.

