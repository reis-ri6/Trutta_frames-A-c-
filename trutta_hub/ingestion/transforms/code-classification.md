# Transform: Code Classification

Goal: detect valuable code files and mark good candidates for templates/examples.

## Input

- A file with `kind = code`.

## Tasks

1. Determine `subtype`:
   - `snippet`   — short example, not standalone.
   - `script`    — executable tool or CLI.
   - `template`  — reusable skeleton, usually with placeholders.
   - `infra`     — infra configuration: Docker, Terraform, k8s, Supabase, CI.
   - `test`      — test-code.
   - `other`.

2. Estimate scores:
   - `relevance_score`:
     - higher if code uses Trutta/TJM/ABC-related APIs, schemas or concepts.
   - `novelty_score`:
     - low if AST/structure duplicates existing examples;
     - higher if it introduces new flows/patterns.
   - `actuality_score`:
     - higher for code that uses current stack and valid APIs;
     - lower for clearly deprecated or old patterns.

3. Decide what to do:
   - `promote_candidate`:
     - code looks like a good example or template and is up-to-date.
   - `archive`:
     - legacy example, outdated stack, or superseded snippet.
   - `ignore`:
     - compiled/build artefacts, vendor bundles, generated code.

4. Do not modify the original code files.
   - Only update `ingestion/ingestion-index.yaml` with:
     - `subtype`
     - scores
     - `decision`
     - optional `linked_artefact_id` (e.g. `TEMPLATE-SOSPESO`).
