# Transform: Marketing Cleaning

Goal: turn noisy marketing copy into a compact, structured spec input.

## Input

- A file with:
  - `kind = doc`
  - `subtype = marketing`
  - `decision = compress_clean`

## Output

For each input file `<path>`:

- `<path>.clean.md`
  - structured, cleaned version of the content.
- `<path>.summary.md`
  - 10–20 lines summary with core ideas.

## Steps

1. **Extract facts**
   - Product / service being described.
   - Target users / roles.
   - Key user flows (journeys).
   - Key constraints (technical, legal, behavioural).
   - Any explicit metrics, SLA, economics.

2. **Remove noise**
   - Buzzwords and emotional language (revolutionary, seamless, magic…).
   - Repetitions.
   - Vague claims without concrete consequences.

3. **Restructure**
   - Use clear sections:
     - `Overview`
     - `Target users`
     - `Key flows`
     - `Constraints`
     - `Open questions`
   - Use bullet lists where possible.
   - Preserve all factual information, do not invent new facts.

4. **Summary**
   - Create `<path>.summary.md`:
     - 10–20 lines.
     - Focus on what this actually changes in the system / product.

5. **Index update (done by agent)**
   - In `ingestion/ingestion-index.yaml`:
     - for the original file, add `clean_output_paths` with both new paths.
