# PD-013 Governance Templates v0.1

**Status:** Draft 0.1  
**Owner:** Governance Council / Platform Architecture / Legal & Compliance

**Related docs:**  
- PD-013-governance-and-compliance-spec.md  
- PD-011-product-authoring-and-workflows.md  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-tooling-links.md

Мета — дати **готові темплейти**, які використовуються в governance-процесах навколо Product DSL / Registry:

- access-matrix для ролей і environment’ів;  
- compliance-checklist для нових продуктів та змін;  
- формати audit-log для publish/change/emergency подій.

---

## 1. Access Matrix Templates

### 1.1 Logical Roles

Базовий список ролей (може деталізуватись організаційно):

- `PO` — Product Owner  
- `PA` — Product Architect / Solution Architect  
- `DA` — Data Architect / Analytics Lead  
- `FIN` — Finance / Revenue Ops  
- `OPS` — Operations / SRE  
- `SAFE` — Safety & Quality / Risk  
- `SEC` — Security / Privacy / Legal  
- `GOV` — Governance Council  
- `DEVEX` — DevEx / Platform  
- `VIEWER` — Read-only stakeholder (PM, support тощо)

### 1.2 Access Matrix — High-level Table (Markdown)

```markdown
| Resource / Action                        | PO  | PA  | DA  | FIN | OPS | SAFE | SEC | GOV | DEVEX | VIEWER |
|-----------------------------------------|-----|-----|-----|-----|-----|------|-----|-----|-------|--------|
| DSL repo – read                         | R   | R   | R   | R   | R   | R    | R   | R   | R     | R      |
| DSL repo – create/modify ProductDef     | W   | W   | W   | -   | -   | -    | -   | -   | W*    | -      |
| DSL repo – create/modify pricing        | C   | R   | R   | W   | -   | -    | -   | -   | W*    | -      |
| DSL repo – create/modify ops/safety     | R   | C   | R   | -   | W   | W    | R   | -   | W*    | -      |
| DSL repo – schemas / DSL structure      | R   | R   | R   | -   | -   | -    | R   | C   | W     | -      |
| Approve low-risk changes                | A   | A   | A   | A   | A   | A    | A   | -   | -     | -      |
| Approve medium-risk changes             | A   | A   | A   | A   | A   | A    | A   | -   | -     | -      |
| Approve high-risk changes               | A   | A   | A   | A   | A   | A    | A   | O   | -     | -      |
| Approve critical changes                | A   | A   | A   | A   | A   | A    | A   | A   | -     | -      |
| Trigger emergency stop-sell             | O   | -   | -   | -   | A   | A    | A   | O   | -     | -      |
| Registry dev – read                     | R   | R   | R   | R   | R   | R    | R   | R   | R     | R      |
| Registry dev – write (via CI/pdsl)      | O   | O   | O   | O   | O   | O    | O   | O   | A     | -      |
| Registry staging – read                 | R   | R   | R   | R   | R   | R    | R   | R   | R     | R      |
| Registry staging – write (CI-only)      | -   | -   | -   | -   | -   | -    | -   | O   | A     | -      |
| Registry production – read              | R   | R   | R   | R   | R   | R    | R   | R   | R     | R      |
| Registry production – write (CI-only)   | -   | -   | -   | -   | -   | -    | -   | A   | A     | -      |
```

Легенда:  
- `R` — read  
- `W` — write (author)  
- `C` — co-author  
- `A` — can approve відповідні changes  
- `O` — can initiate (owner / initiator)  
- `W*` — технічний write (DevEx) для підтримки структур, не контенту продуктів.

### 1.3 Access Matrix — JSON Template (Machine-readable)

```json
{
  "roles": ["PO", "PA", "DA", "FIN", "OPS", "SAFE", "SEC", "GOV", "DEVEX", "VIEWER"],
  "resources": [
    {
      "id": "dsl_repo_productdef",
      "description": "DSL repo – ProductDef files",
      "permissions": {
        "PO": ["read", "write"],
        "PA": ["read", "write"],
        "DA": ["read", "write"],
        "FIN": ["read"],
        "OPS": ["read"],
        "SAFE": ["read"],
        "SEC": ["read"],
        "GOV": ["read"],
        "DEVEX": ["read", "write_structural"],
        "VIEWER": ["read"]
      }
    },
    {
      "id": "registry_production_write",
      "description": "Write access to production Registry (via CI)",
      "permissions": {
        "PO": [],
        "PA": [],
        "DA": [],
        "FIN": [],
        "OPS": [],
        "SAFE": [],
        "SEC": [],
        "GOV": ["approve_critical"],
        "DEVEX": ["publish_via_ci"],
        "VIEWER": []
      }
    }
  ]
}
```

Цей шаблон може бути розширено й використано для генерації RBAC-політик або OPA-політик.

---

## 2. Compliance Checklist Templates

### 2.1 Checklist для Нового Продукту (Pilot / Rollout)

```markdown
# Compliance Checklist – New Product

## Basic Identification
- [ ] Product ID (stable, нормалізований)
- [ ] Product name (локалізації за потреби)
- [ ] Product owner (PO) призначений
- [ ] Jurisdiction / legal entity

## Functional Scope
- [ ] ProductDef задокументовано (core journeys, services, включення TJM/Trutta/LEM)
- [ ] Market coverage (країни, міста, сегменти)
- [ ] Dependencies (інтеграції, зовнішні сервіси) описані

## Pricing & Financial
- [ ] Pricing profile заповнений (базові ціни, валюти)
- [ ] Revenue-split / комісії погоджені з FIN
- [ ] FX-поведінка визначена (джерело курсів, частота оновлення)
- [ ] Промокампанії/знижки описані та мають обмеження (тривалість, ліміти)

## Ops / Safety / Quality
- [ ] SLO/SLI визначені (latency, availability, error rate)
- [ ] SLA описане (якщо клієнт-facing)
- [ ] Safety thresholds визначені (особливо для health/safety продуктів)
- [ ] Escalation-процедури прописані (OPS/SAFE)

## Data & Privacy
- [ ] Product не вимагає зберігання PII в DSL/Registry
- [ ] Описані типи даних, що обробляються (health, location, payment metadata тощо)
- [ ] Privacy level класифіковано (низький/середній/високий)
- [ ] Перевірено відповідність локальним privacy-законам (GDPR/інші)

## AML / KYC / Legal
- [ ] Позначено, чи вимагає продукт KYC/KYB/AML checks
- [ ] За потреби – визначено інтеграцію з KYC/AML-провайдерами
- [ ] Legal terms / ToS / policy links актуальні
- [ ] Є переліки заборонених країн/категорій (санкції, вікові обмеження)

## Runtime & Monitoring
- [ ] Продукт прив’язаний до відповідних дашбордів/метрик
- [ ] Налаштовані алерти для критичних SLO/SLA
- [ ] Є план roll-forward / roll-back

## Approvals
- [ ] PO approval
- [ ] PA approval
- [ ] FIN approval (для revenue-affecting)
- [ ] OPS approval
- [ ] SAFE approval (якщо релевантно)
- [ ] SEC/Legal approval (якщо релевантно)
- [ ] GOV/CAB approval (для high/critical)
```

### 2.2 Checklist для Changes (Existing Product)

```markdown
# Compliance Checklist – Product Change

## Change Description
- [ ] Короткий опис зміни
- [ ] Тип зміни (product / pricing / ops / safety / policy / schema)
- [ ] Оцінений risk-level (low/medium/high/critical)

## Impact Analysis
- [ ] Вплив на активних користувачів / бронювання / токени
- [ ] Вплив на фінансові показники (GMV, unit economics)
- [ ] Вплив на SLA/SLO
- [ ] Вплив на safety/health (якщо релевантно)

## Technical Changes
- [ ] Оновлені ProductDef/профілі/політики
- [ ] Diff DSL → Registry (auto pdsl diff) перевірений
- [ ] Сумісність зі схемами/Registry контрактом підтверджена

## Data & Privacy / Legal
- [ ] Чи змінюється обсяг/тип даних, що збираються/обробляються
- [ ] Чи змінюються privacy/consent вимоги
- [ ] Чи виникають нові регуляторні ризики (нові країни, категорії продуктів)

## Tests & Rollout
- [ ] Є план тестування (unit/integration/e2e)
- [ ] Є plan roll-back / feature flags
- [ ] Для high/critical – визначені change windows

## Approvals
- [ ] Зібрані approvals згідно з risk-level (див. PD-013)
```

### 2.3 Checklist для Schema / DSL / Registry Contract Changes

```markdown
# Compliance Checklist – Schema / Registry Contract Change

## Scope
- [ ] Тип змін (DSL schema / Registry API / обидва)
- [ ] Класифікація змін (non-breaking / potentially breaking / breaking)

## Impact
- [ ] Які продукти/профілі/ринкові конфігурації зачіпає
- [ ] Які сервіси (TJM/Trutta/LEM/інші) будуть вимагати оновлення
- [ ] Які зовнішні інтеграції використовують ці контракти

## Migration Plan
- [ ] Визначена стратегія Expand → Migrate → Contract
- [ ] Передбачена backward-compatible фаза
- [ ] Documented deprecation timeline

## Tooling & CI
- [ ] Оновлені схеми в schema-store / core/schemas
- [ ] Оновлені валідації в `pdsl`
- [ ] Оновлені CI-джоби / тести

## Approvals
- [ ] DevEx/Platform approval
- [ ] PA/DA approval
- [ ] OPS approval (якщо зачіпає runtime/ops)
- [ ] SEC/Legal approval (якщо є регуляторні наслідки)
- [ ] GOV approval (для breaking змін)
```

---

## 3. Audit-log Format Templates

### 3.1 Canonical Audit Event Schema (JSON)

```json
{
  "event_id": "ULID-OR-UUID",
  "event_type": "registry.publish",
  "timestamp": "2025-01-01T12:34:56Z",
  "env": "staging",
  "actor": {
    "type": "system",            
    "id": "ci-github-actions",   
    "user": "github-actions[bot]",
    "pr_author": "user@example.com"
  },
  "git": {
    "repo": "product-dsl",
    "commit": "abcdef1234567890",
    "branch": "main",
    "pr_id": 123
  },
  "snapshot": {
    "id": "snap_20250101_123456",
    "hash": "sha256:...",
    "ref": "v1.2.3"
  },
  "change_summary": {
    "products_added": 2,
    "products_modified": 5,
    "products_removed": 0,
    "risk_level": "high",
    "impacted_markets": ["AT-VIE", "DE-BER"]
  },
  "links": {
    "diff_url": "https://git.example.com/...",
    "pr_url": "https://git.example.com/.../pull/123"
  },
  "metadata": {
    "pdsl_version": "0.1.0",
    "registry_version": "1.4.0"
  }
}
```

### 3.2 Audit Event – Emergency Action (Stop-sell)

```json
{
  "event_id": "ULID-OR-UUID",
  "event_type": "product.emergency_stop_sell",
  "timestamp": "2025-01-01T13:00:00Z",
  "env": "production",
  "actor": {
    "type": "human",
    "id": "ops-duty-officer",
    "user": "ops.lead@example.com",
    "role": "OPS"
  },
  "product": {
    "id": "PRD-VIEN-COFFEE-PASS",
    "markets": ["AT-VIE"],
    "version": "2.1.0"
  },
  "reason": {
    "category": "safety",
    "description": "Unexpected issue with vendor redemption leading to over-redemption",
    "incident_ids": ["INC-2025-0001"]
  },
  "action": {
    "type": "stop_sell",
    "scope": "market",
    "effective_from": "2025-01-01T13:00:00Z",
    "expected_until": "2025-01-02T13:00:00Z"
  },
  "follow_up": {
    "dsl_pr_required": true,
    "dsl_pr_reference": null,
    "post_mortem_required": true,
    "post_mortem_id": null
  }
}
```

### 3.3 Audit Event – Governance Decision

```json
{
  "event_id": "ULID-OR-UUID",
  "event_type": "governance.decision",
  "timestamp": "2025-01-05T10:00:00Z",
  "actor": {
    "type": "committee",
    "id": "GOV-Council-01"
  },
  "context": {
    "change_request_id": "CR-2025-0010",
    "related_pr": 145,
    "risk_level": "critical"
  },
  "decision": {
    "status": "approved",
    "conditions": [
      "Enable feature only for AT-VIE and DE-BER in first phase",
      "Run additional load tests on staging before rollout"
    ],
    "effective_from": "2025-01-10T00:00:00Z"
  },
  "participants": [
    { "role": "PO", "user": "po@example.com" },
    { "role": "PA", "user": "pa@example.com" },
    { "role": "FIN", "user": "fin@example.com" },
    { "role": "OPS", "user": "ops@example.com" },
    { "role": "SEC", "user": "sec@example.com" },
    { "role": "GOV", "user": "gov.chair@example.com" }
  ]
}
```

---

## 4. Storage & Querying Templates

### 4.1 Relational Table Sketch (Registry Audit)

```sql
CREATE TABLE registry_audit_events (
  id            TEXT PRIMARY KEY,
  event_type    TEXT NOT NULL,
  env           TEXT NOT NULL,
  ts            TIMESTAMPTZ NOT NULL,
  actor_type    TEXT NOT NULL,
  actor_id      TEXT NOT NULL,
  actor_role    TEXT,
  git_repo      TEXT,
  git_commit    TEXT,
  git_branch    TEXT,
  pr_id         INTEGER,
  product_id    TEXT,
  product_version TEXT,
  risk_level    TEXT,
  payload       JSONB NOT NULL
);

CREATE INDEX ON registry_audit_events (env, ts);
CREATE INDEX ON registry_audit_events (event_type, ts);
CREATE INDEX ON registry_audit_events (product_id, ts);
CREATE INDEX ON registry_audit_events USING GIN (payload jsonb_path_ops);
```

### 4.2 Typical Queries (Sketch)

- Витягнути всі publish-івенти по продукту:

```sql
SELECT *
FROM registry_audit_events
WHERE event_type = 'registry.publish'
  AND product_id = 'PRD-VIEN-COFFEE-PASS'
ORDER BY ts DESC;
```

- Знайти всі emergency stop-sell за останній місяць:

```sql
SELECT *
FROM registry_audit_events
WHERE event_type = 'product.emergency_stop_sell'
  AND ts >= now() - interval '30 days';
```

---

## 5. Summary

У цьому документі зафіксовано **конкретні темплейти**, які можна одразу брати в роботу:

- access-matrix (markdown + JSON), який лягає в основу RBAC / policy-as-code;  
- compliance-checklists для нових продуктів, змін і schema/contract-еволюції;  
- canonical JSON-схеми audit-подій (publish, emergency, governance decision) + скетч реляційної таблиці.

Подальші кроки — підлаштувати значення ролей/полів під конкретну організацію, зафіксувати їх у PD-016-roadmap та прив’язати до фактичних політик доступу, CI та log storage.

