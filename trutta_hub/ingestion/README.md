# Ingestion Layer

This directory contains the **pre-canonical ingestion layer** for the Trutta Hub repository.

It is responsible for:
- scanning all files in the repo;
- classifying them (`kind`, `subtype`);
- scoring them (`relevance`, `novelty`, `actuality`);
- deciding what to do with each file (`ignore`, `archive`, `compress_clean`, `promote_candidate`);
- optionally producing cleaned versions of noisy marketing texts.

Ingestion **does not** touch canonical artefacts (PD/VG/concepts/domains/schemas/templates/agents).
It only writes:
- `ingestion/ingestion-index.yaml`,
- `ingestion/logs/*`,
- `*.clean.md`, `*.summary.md` near original files.

## Structure

- `ingestion-index.yaml` — machine-readable index of all files.
- `rules.md` — classification & scoring rules.
- `transforms/` — transformation specs:
  - `marketing-cleaning.md`
  - `code-classification.md`
- `logs/` — run logs from ingestion agent.

The main agent that operates on this layer is:
- `agents/patterns/repo-ingestion-agent/*`.
