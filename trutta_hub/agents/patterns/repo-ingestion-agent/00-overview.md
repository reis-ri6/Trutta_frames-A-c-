# Repo Ingestion Agent

**Name:** `repo-ingestion-agent`  
**Repository:** `reis-ri6/Trutta_frames-A-c-`

## Purpose

- Scan the entire repository tree.
- Classify each file (`kind`, `subtype`).
- Compute:
  - `relevance_score`
  - `novelty_score`
  - `actuality_score`
- Decide:
  - `ignore`
  - `archive`
  - `compress_clean`
  - `promote_candidate`
- Write results into `ingestion/ingestion-index.yaml`.
- For marketing docs:
  - generate `*.clean.md` and `*.summary.md` according to `ingestion/transforms/marketing-cleaning.md`.

## Scope

- Read: all files in the repo (except technical exclusions like `.git`, `node_modules`, `dist`).
- Write:
  - `ingestion/ingestion-index.yaml`
  - `ingestion/logs/*`
  - `*.clean.md`, `*.summary.md` next to original docs.

It **must not**:
- touch canonical artefacts under:
  - `docs/`, `concepts/`, `domains/`, `schemas/`, `templates/`,
  - `agents/`, `infra/`, `progress/`, `monitoring/`.
- modify `progress/artefacts/*`.

This agent is the **first stage** of the doc pipeline. Canonicalisation is handled by `doc-canonisation-agent`.
