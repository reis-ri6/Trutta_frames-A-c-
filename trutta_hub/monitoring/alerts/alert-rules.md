# Alert Rules

## 1. Data freshness
- **Name**: city-data-stale
- **Condition**: останній успішний `tourism-daily-refresh` > 24 годин тому.
- **Action**: створити інцидент, сповістити data-ops.

## 2. Ingestion failures
- **Name**: ingestion-failures-spike
- **Condition**: > 5 послідовних падінь repo-ingestion-agent.
- **Action**: ескалація до ai-ops.
