# Context and Tools

## Inputs to inspect
- Agent manifests: `agents/**/*.agent.yaml`
- Agent prompts and docs: `agents/patterns/**/` (overviews, responsibilities, context, guardrails)
- System manifests: `agents/systems/**/*.system.yaml`
- Guardrails: `ai-guardrails.md`, `ingestion/rules.md`, `ingestion/transforms/*`
- Progress trackers: `progress/artefacts/*.yaml`, `progress/agents/`

## Recommended tools
- **File scan + semantic diff** to spot missing sections.
- **YAML/JSON lint** for manifest validity.
- **Path consistency checks** to ensure prompts and configs reference the same files.

## Output format
- `progress/agents/recon-report.md` with sections:
  - Overview of inspected agents
  - Missing/misaligned docs
  - Guardrail issues
  - Recommended fixes (checklist)

## Safety
- Read-only for canonical artefacts; write only to `progress/agents/` and optional `ingestion/logs/` if logging validation steps.
