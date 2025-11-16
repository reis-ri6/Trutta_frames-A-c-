# PD-010 Ops / Safety / Quality Templates v0.1

**Status:** Draft 0.1  
**Owner:** Platform Ops / Safety / Product

**Related docs:**  
- PD-010-ops-safety-and-quality-spec.md  
- PD-010-ops.ddl.sql  
- PD-007-product-profiles-templates.md  
- PD-008-product-runtime-events.md  
- VG-* Ops/SRE runbooks

Мета — дати **готові шаблони** для:

- SLI/SLO/SLA-конфігів (OpsProfile/SafetyProfile/QualityProfile);
- quality-audit артефактів;  
- escalation-політик і ops_policies.

---

## 1. Template: OpsProfile (YAML)

Базовий OpsProfile для продукту в місті.

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
      sli_query: "runtime_availability_v1"  # id метрики в observability

    journey_success_rate:
      target_percent: 97.0
      window_days: 30
      sli_query: "journey_success_rate_v1"

    runtime_error_rate:
      max_percent: 1.0
      window_days: 7
      sli_query: "runtime_error_rate_v1"

    latency_p95_ms:
      max_ms: 1500
      window_days: 7
      sli_query: "prg_latency_p95_v1"

  incident_policies:
    critical_error_burst:
      threshold_count: 10
      window_minutes: 5
      action: "create_incident_and_throttle"
      ops_policy_ref: "OPS-POL-SLO-VIEN-ERR-BURST"

  escalation:
    primary_team: "vien-ops"
    oncall_rotation_id: "OC-VIEN-PLATFORM"
    slack_channel: "#ops-vien"
    pagerduty_service_id: "PD-SVC-VIEN-PLATFORM"
```

---

## 2. Template: SafetyProfile (YAML)

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
    max_night_hours_without_check: 2

  vendor_thresholds:
    min_vendor_safety_score: 0.80
    disallow_unverified_vendors: true
    disallow_vendors_with_recent_incidents_days: 30

  dietary_constraints:
    requires_profile_type: null          # наприклад, "kidney" для kidney.mpt
    disallow_conflicting_dishes: true

  fraud_thresholds:
    max_daily_redemptions_per_user: 10
    max_parallel_sessions_per_user: 3

  runtime_actions:
    on_low_safety_route:
      action: "fallback_to_safer_route"
      ops_policy_ref: "OPS-POL-SAFETY-ROUTE-VIEN"

    on_vendor_safety_drop:
      action: "temporarily_disable_vendor"
      ops_policy_ref: "OPS-POL-SAFETY-VENDOR-VIEN"

    on_fraud_pattern_detected:
      action: "freeze_entitlements_and_alert_risk"
      ops_policy_ref: "OPS-POL-SAFETY-FRAUD-GLOBAL"
```

---

## 3. Template: QualityProfile (YAML)

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
      ops_policy_ref: "OPS-POL-QUALITY-VENDOR-RANKING"

    on_high_complaint_route:
      action: "pause_route_and_alert_ops"
      ops_policy_ref: "OPS-POL-QUALITY-ROUTE-PAUSE"
```

---

## 4. Template: SLO Definition (JSON)

SLO як окремий артефакт (може лінкуватись у ops_policies.condition).

```json
{
  "slo_id": "SLO-VIEN-PROD-AVAIL-99_5",
  "name": "Vienna Coffee Pass – product runtime availability",
  "metric_id": "runtime_availability_v1",
  "target_type": "min_percent",
  "target_value": 99.5,
  "window": {
    "length_days": 30,
    "alignment": "sliding"
  },
  "dimensions": {
    "product_id": "PRD-VIEN-COFFEE-PASS",
    "market_code": "AT-VIE"
  }
}
```

---

## 5. Template: SLA Summary (Markdown)

Це — технічний summary, на базі якого юристи роблять контрактний SLA.

```markdown
# SLA – Vienna Coffee Pass (Ops/Safety/Quality Extract)

## Scope
- Product: Vienna Coffee Pass (PRD-VIEN-COFFEE-PASS)
- Market: Vienna (AT-VIE)

## Availability SLO
- Target: 99.5% product runtime availability over rolling 30 days.
- Measure: percentage of `product.runtime.created` not ending with platform error.

## Journey Success SLO
- Target: 97.0% journeys completed successfully over rolling 30 days.

## Safety SLO
- Max 1 safety-related incident (severity ≥ high) per 10,000 sessions over 90 days.

## Quality SLO
- Average rating ≥ 4.2 over 90 days.
- Complaint rate ≤ 2.0% of sessions over 90 days.

## Credits (Illustrative)
- If availability < 99.0% in a calendar month → 5% credit on platform fees for affected vendors.
- If safety SLO is violated → individual review and compensation case per incident.
```

---

## 6. Template: Quality Audit Checklist (Markdown)

```markdown
# Quality Audit – Vienna Coffee Pass – [YYYY-MM]

## 1. Content Quality
- [ ] All venues have ≥ 3 photos.
- [ ] All descriptions verified in last 180 days.
- [ ] All opening hours updated in last 90 days.
- [ ] All routes have up-to-date map data.

## 2. Service Quality
- [ ] Average rating ≥ 4.2.
- [ ] Complaint rate ≤ 2.0%.
- [ ] No vendor with rating < 3.5 and > 50 reviews.

## 3. Experience Quality
- [ ] NPS ≥ 40 (last 90 days).
- [ ] CSAT ≥ 4.3.
- [ ] Journey abandonment rate ≤ 15%.

## 4. Safety & Compliance Cross-check
- [ ] No active high/critical ops_incidents unresolved > 7 days.
- [ ] All safety_overrides justified and documented.

## 5. Sign-off
- Auditor: ____________________  Date: ______________
- Ops Lead: ___________________  Date: ______________
```

---

## 7. Template: Escalation Policy (YAML)

Escalation policy логічно мапиться на `ops_policies` + зовнішню oncall-інфраструктуру.

```yaml
escalation_policy:
  id: ESC-VIEN-OPS-DEFAULT
  name: "Vienna – Default Ops Escalation"

  scopes:
    market_code: AT-VIE

  levels:
    - level: 1
      trigger:
        severity_at_least: "medium"
        incident_types: ["slo_breach", "system_outage"]
      actions:
        - type: "notify_slack"
          channel: "#ops-vien"
        - type: "assign_team"
          team: "vien-ops"
        - type: "update_incident_status"
          status: "acknowledged"

    - level: 2
      trigger:
        severity_at_least: "high"
        incident_types: ["safety_violation", "system_outage"]
      actions:
        - type: "page_oncall"
          oncall_rotation_id: "OC-VIEN-PLATFORM"
        - type: "create_change_freeze"
          scope: "product_market"
          product_id: "PRD-VIEN-COFFEE-PASS"
          market_code: "AT-VIE"

    - level: 3
      trigger:
        severity_at_least: "critical"
      actions:
        - type: "notify_execs"
          emails: ["cto@example.com", "head.ops@example.com"]
        - type: "declare_major_incident"
          runbook_id: "RB-MI-VIEN-001"
```

---

## 8. Template: ops_policies Rows (JSON)

Відповідає таблиці `ops_policies` з PD-010-ops.ddl.sql.

### 8.1 SLO threshold policy

```json
{
  "policy_id": "OPS-POL-SLO-VIEN-AVAIL-99_5",
  "policy_type": "slo_threshold",
  "scope_level": "product",
  "market_code": "AT-VIE",
  "product_id": "PRD-VIEN-COFFEE-PASS",

  "name": "SLO – Vienna Coffee Pass availability >= 99.5%",
  "description": "If 30d availability drops below 99.5%, raise incident and consider stop-sell.",

  "condition": {
    "metric_id": "runtime_availability_v1",
    "comparator": "<",
    "threshold": 99.5,
    "window": {
      "length_days": 30,
      "alignment": "sliding"
    }
  },

  "action": {
    "steps": [
      {
        "type": "create_incident",
        "incident_type": "slo_breach",
        "severity": "high",
        "title": "SLO breach: Vienna Coffee Pass availability < 99.5%"
      },
      {
        "type": "evaluate_stop_sell",
        "criteria": {
          "min_breach_hours": 6
        }
      }
    ]
  },

  "enabled": true,
  "priority": 100
}
```

### 8.2 Safety rule policy (route safety)

```json
{
  "policy_id": "OPS-POL-SAFETY-ROUTE-VIEN",
  "policy_type": "safety_rule",
  "scope_level": "city",
  "city_code": "VIE",

  "name": "Route safety – minimum LEM route safety score",
  "description": "Block or fallback when route safety_score falls below 0.8.",

  "condition": {
    "metric_id": "lem_route_safety_score_v1",
    "comparator": "<",
    "threshold": 0.8,
    "applies_to": "route",
    "window": {
      "length_minutes": 60,
      "alignment": "sliding"
    }
  },

  "action": {
    "steps": [
      {
        "type": "apply_safety_override",
        "override_action": "fallback",
        "scope": "route"
      },
      {
        "type": "notify_ops",
        "channel": "#ops-vien",
        "message_template": "Route {{route_id}} safety_score below 0.8 – using fallback routes."
      }
    ]
  },

  "enabled": true,
  "priority": 90
}
```

### 8.3 Quality gate policy

```json
{
  "policy_id": "OPS-POL-QUALITY-ROUTE-PAUSE",
  "policy_type": "quality_gate",
  "scope_level": "route",
  "route_id": "ROUTE-VIEN-COFFEE-01",

  "name": "Pause route when complaint rate high",
  "description": "If complaint_rate > 3% over last 30 days with sample_size >= 50, pause route.",

  "condition": {
    "metric_id": "complaint_rate_v1",
    "comparator": ">",
    "threshold": 3.0,
    "window": {
      "length_days": 30,
      "alignment": "sliding"
    },
    "min_sample_size": 50
  },

  "action": {
    "steps": [
      {
        "type": "apply_safety_override",
        "override_action": "block",
        "scope": "route"
      },
      {
        "type": "create_incident",
        "incident_type": "quality_drop",
        "severity": "medium",
        "title": "Quality gate triggered: complaint rate > 3% for route"
      }
    ]
  },

  "enabled": true,
  "priority": 110
}
```

---

## 9. Usage Notes

- SLO/SLA/політики **зберігаються як YAML/JSON** у репозиторії і трансформуються в записи `ops_policies`, `ops_incidents` (шаблони), `quality_scores` агрегаціями.  
- Рекомендується мати окремий `ops-config` репозиторій з:
  - каталожними файлами OpsProfile/SafetyProfile/QualityProfile;  
  - SLO/SLA-пакетами по продукт/місто;  
  - auditable history (Git, PR, review) як частина governance (PD-013).

