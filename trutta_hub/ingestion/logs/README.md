# Ingestion Logs

Each ingestion run should append a log file with name:

- `ingestion-YYYYMMDD-HHMM.md`

Minimal content:

- timestamp
- total number of files processed
- counts per `decision`:
  - `ignore`, `archive`, `compress_clean`, `promote_candidate`
- short notes:
  - errors / edge-cases
  - unusual patterns detected

Example:

```md
# Ingestion run — 2025-11-24T10:30:00Z

- files processed: 124
- decisions:
  - ignore: 10
  - archive: 80
  - compress_clean: 20
  - promote_candidate: 14

Notes:
- Found several legacy pitch docs → marked `compress_clean`.
- New Sospeso mint snippet → `promote_candidate` with linked_artefact_id=TEMPLATE-SOSPESO.
```
