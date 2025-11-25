# Doc Canonisation Agent

**Name:** `doc-canonisation-agent`  
**Repository:** `reis-ri6/Trutta_frames-A-c-`

## Purpose

- Take high-value files marked by the ingestion layer (`decision=promote_candidate`).
- Map them to canonical artefacts:
  - `pd`, `vg`, `concept`, `domain`, `template`.
- Update:
  - `progress/artefacts/artefact-index.yaml`
  - `progress/artefacts/docs-status.yaml`
- Create or patch canonical files in:
  - `docs/`, `concepts/`, `domains/`, `templates/`.

This agent turns “good candidates” from ingestion into **proper PD/VG/Concept/Domain/Template docs**.

## Scope

- Read:
  - `ingestion/ingestion-index.yaml`
  - existing canonical files in `docs/`, `concepts/`, `domains/`, `templates/`
  - `progress/artefacts/artefact-index.yaml`
  - `progress/artefacts/docs-status.yaml`
- Write:
  - new/updated canonical docs
  - updates to `artefact-index.yaml` and `docs-status.yaml`.

It must:
- not touch ingestion config or infra (`ingestion/`, `infra/`, `tools/`, `monitoring/`).
- not silently overwrite `canonical` artefacts; conflicts must be explicit.
