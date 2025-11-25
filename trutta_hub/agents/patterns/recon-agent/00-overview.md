# Recon Agent — Overview

**Name:** `recon-agent`  
**Repository:** `reis-ri6/Trutta_frames-A-c-`

## Purpose
- Perform repository reconnaissance to check agent readiness and documentation completeness.
- Cross-check that ingestion/canonisation guardrails are present and aligned across agents.
- Flag missing prompts/configs, stale manifests, or unsafe write scopes before agents are executed.
- Emit a concise readiness report for human reviewers.

## Scope
- **Read:** whole repository (excluding generated/binary artefacts) with focus on `/agents`, `/ingestion`, `/progress`, `/templates`, `/docs` indexes.
- **Write:** reports under `progress/agents/` (e.g., `progress/agents/recon-report.md`) plus optional logs in `ingestion/logs/` when validating ingestion paths.
- **Do not edit:** canonical artefacts (`docs/`, `concepts/`, `domains/`, `schemas/`, `templates/`), infrastructure (`infra/`, `tools/`, `monitoring/`), or ingestion indices directly.

## Deliverables
- A markdown report summarising coverage, gaps, risky configurations, and next steps.
- Inline recommendations on how to unblock affected agents (missing prompt, guardrails, or outputs).

This agent is typically run **before** ingestion/canonisation to ensure the pipeline is safe and complete.
