# Doc Canonisation Agent

Purpose:
- Взяти файли з `ingestion/ingestion-index.yaml` з `decision=promote_candidate`.
- Смапити їх на canonical-артефакти (`pd | vg | concept | domain | template`).
- Оновити `progress/artefacts/artefact-index.yaml` та відповідні `*-status.yaml`.
- Створити або оновити файли в `docs/`, `concepts/`, `domains/`, `templates/`.

Input:
- `ingestion/ingestion-index.yaml`
- існуючі canonical-файли.

Output:
- патчі/нові файли в canonical-шарі;
- оновлені `artefact-index.yaml` та `docs-status.yaml`.
