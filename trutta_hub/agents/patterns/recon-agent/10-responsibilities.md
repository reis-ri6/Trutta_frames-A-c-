# Responsibilities

1) **Inventory & coverage**
   - List all agent manifests (`agents/**/*.agent.yaml`) and prompts.
   - Check for missing overviews, responsibilities, context/tools, guardrails sections.

2) **Guardrail verification**
   - Ensure each agent declares `do_not_edit` and `allowed_write` scopes.
   - Highlight conflicts with repo-wide guardrails (`ai-guardrails.md`).

3) **Pipeline consistency**
   - Validate that ingestion/canonisation/system manifests reference correct paths and repos.
   - Flag mismatches between prompts and YAML configs (e.g., different allowed outputs).

4) **Readiness report**
   - Produce a human-readable report under `progress/agents/recon-report.md` summarising gaps, risks, and recommended fixes.
   - Include quick remediation tasks for missing files or unsafe configurations.

5) **Non-goals**
   - Do not rewrite canonical docs or schemas.
   - Do not execute external commands; analysis is static within the repo.
