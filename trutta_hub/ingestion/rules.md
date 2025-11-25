# Ingestion Rules

These rules are used by `repo-ingestion-agent` to classify and score files.

## 1. Classification

For each file in the repository:

1. Detect `kind` (by path, extension, and basic content):
   - `doc`    — markdown, txt, doc-like textual content.
   - `code`   — .ts, .js, .py, .sql, .sh, .tf, .yaml, etc.
   - `data`   — .json, .csv and other structured data.
   - `media`  — images, pdf, binary assets.
   - `other`  — everything else.

2. Detect `subtype`:

- For `doc`:
  - `marketing` — pitches, promo, vision-heavy text.
  - `spec`      — clear technical or product specs.
  - `note`      — internal notes, scratchpad.
  - `legal`     — terms, policies, agreements.
  - `log`       — logs, changelog-like.
  - `other`     — anything that doesn't fit above.

- For `code`:
  - `snippet`   — short, non-standalone examples.
  - `script`    — runnable CLIs / utilities.
  - `template`  — skeletons intended for reuse.
  - `infra`     — Docker/Terraform/k8s/Supabase config.
  - `test`      — tests/specs (unit/integration).
  - `other`.

- For `data`:
  - `schema_sample`   — samples showing structure.
  - `dataset_sample`  — small example datasets.
  - `log_export`      — raw export logs.
  - `other`.

## 2. Scoring

All scores are floats in [0, 1].

### 2.1. `relevance_score`

How much this file belongs to the Trutta/TJM/ABC/data stack.

Signals:
- **Path / filename** contains domain terms:
  - `trutta`, `tjm`, `abc`, `sospeso`, `bread`, `token`, `voucher`,
    `journey`, `vendor`, `supabase`, `reis`, `ri6`, `city`, `guide`.
- **Content** mentions:
  - tokenization of services/meals, travel journey, anonymous buyers, industrial domains (tourism / hospitality / services / food / health).
- Clearly unrelated / misc → low relevance.

### 2.2. `novelty_score`

How different this file is from what we already have.

Signals:
- Similarity (hash / semantic) to existing files:
  - almost identical → low novelty;
  - new flows, new APIs, new domain insights → higher novelty.
- For code: AST-level similarity (same structure = low novelty).

### 2.3. `actuality_score`

How up-to-date the content and stack are.

Signals:
- File timestamps (rough heuristic).
- Mentioned stack:
  - current versions, non-deprecated APIs → higher.
  - clearly legacy libraries / old product naming → lower.
- For domain docs: references to current product names and structure.

## 3. Decisions

Based on `kind`, `subtype` and scores, choose:

- `ignore`
  - technical noise: cache, compiled, local artifacts.
- `archive`
  - legacy / historical content worth keeping but not promoting.
- `compress_clean`
  - marketing / noisy docs where we can extract structured facts.
- `promote_candidate`
  - high-value spec/code/concept that should be considered for canonicalisation.

The agent must be conservative: when in doubt, prefer `archive` over `promote_candidate`.
