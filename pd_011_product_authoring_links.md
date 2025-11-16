# PD-011 Product Authoring Links v0.1

**Status:** Draft 0.1  
**Owner:** Product / Platform Architecture / DevEx

**Related docs:**  
- PD-011-product-authoring-and-workflows.md  
- PD-011-product-authoring-templates.md  
- PD-003-registry-and-versioning-spec.md  
- PD-003-registry.ddl.sql  
- PD-003-registry-api.yaml  
- PD-012-tooling-cli-and-ci-spec.md  
- PD-012-ci-templates.md  
- PD-013-governance-and-compliance-spec.md

Мета — формально описати **зв’язки між авторинг-процесом продуктів (PD-011)** і:

- реєстром продуктів (Registry, PD-003);  
- governance-процесами (PD-013);  
- інструментами CLI/CI (PD-012).

Фокус: **контракти та потоки даних/подій**, без дублювання деталей із відповідних спеки.

---

## 1. Високорівнева схема

Логічний ланцюжок:

```text
Authoring (Git repo: product-dsl)
   ↓  (PR, code review, approvals)
Governance (PD-013 rules, RACI, risk levels)
   ↓  (merge + CI checks)
Tooling & CI (PD-012 CLI + pipelines)
   ↓  (publish / snapshot / diff)
Registry (PD-003 canonical runtime view)
   ↓
Runtime (TJM / Trutta / LEM / Ops)
```

- **Authoring** = редагування DSL-артефактів у git.  
- **Governance** = хто може що міняти й за яких умов merge дозволено.  
- **Tooling/CI** = автоматичні перевірки, публікація в Registry по середовищах.  
- **Registry** = нормалізований read-optimized шар для рантайму.

---

## 2. Authoring → Governance

### 2.1 PR як одиниця зміни

Будь-яка зміна Product DSL (новий продукт, версія, профіль, політика):

1. Робиться в окремій гілці (`feature/…`, `hotfix/…`).  
2. Оформляється PR із використанням шаблону (PD-011-product-authoring-templates).  
3. У PR явно зазначено:
   - тип зміни (new product / major / minor / policy / experiment);  
   - scope (products, markets, профілі, policies, Registry-entities);  
   - ризики та план rollout/rollback.

### 2.2 Зв’язок із PD-013

Governance-спека (PD-013) задає для кожного типу змін:

- **required approvers** (PO, PA, DA, FIN, OPS, SAFE і т.д.);  
- **risk level** (low/medium/high/critical);  
- **обов’язкові артефакти**: product-spec, ADR, release notes, market addendum;  
- **обмеження за часом** (change windows) для high/critical змін.

Ці правила відображаються у:

- гілці конфігурації CI (наприклад, GitHub CODEOWNERS + required checks);  
- системі approvals (обов’язкові review від певних ролей);  
- політиках для emergency режиму (див. PD-011 §9, PD-013 emergency policy).

### 2.3 Enforcement

- PR **не може бути merged**, поки:
  - не пройшли всі required approvals;  
  - не пройшли всі CI checks (schema/semantic/impact, див. розд. 3).  
- Governance-команда може конфігурити:
  - які CI jobs є **blocking**;  
  - які можна тимчасово bypass-ити (тільки через спеціальний emergency-процес).

---

## 3. Authoring → Tooling & CI

### 3.1 CLI як контракт між Git і Registry

PD-012 визначає CLI, наприклад (імена умовні):

- `product lint` — schema + semantic валідація DSL-файлів;  
- `product diff` — порівняння двох станів DSL (HEAD vs main, або двох версій);  
- `product snapshot` — збір артефактів для середовища (staging/production);  
- `product publish` — публікація snapshot в Registry API по environment.

Authoring-процес **завжди опирається на CLI**:

- локально — для швидкої валідації перед PR;  
- у CI — для автоматичних перевірок та публікацій.

### 3.2 CI пайплайн для PR

Типовий пайплайн для PR у `product-dsl`:

1. **Lint & schema validation**  
   - `product lint --changed-only`  
   - Перевіряє відповідність JSON/YAML схемам (PD-001/PD-002/PD-007/PD-009/PD-010).  
   - Блокує PR при будь-яких помилках.

2. **Semantic validation**  
   - consistency checks: посилання на неіснуючі продукти/markets/профілі, невірні версії, дублікати ID;  
   - базова валідація numerics (ціни, пороги, SLO, FX).  

3. **Impact & diff report**  
   - `product diff` генерує артефакт для reviewer’ів:  
     - які продукти/версії/міста/профілі змінені;  
     - чи є breaking зміни (на основі PD-003 versioning rules).  
   - Репорт лінкується в PR.

4. **Preview / staging snapshot (optional)**  
   - build стейдж-snapshot (`product snapshot --env=staging`);  
   - розгортання в тимчасовому registry-неймспейсі (`/env/staging-preview/…`);  
   - опційно: smoke-тести TJM/Trutta/LEM проти цього snapshot.

CI статуси публікуються в PR як required checks.

### 3.3 CI пайплайн для main/release

При merge в main/release-гілку:

1. Ход ті самі валідації (lint + semantic, для захисту main).  
2. Генерується **release snapshot** per environment (staging або production).  
3. Викликається `product publish` до Registry API:

- staging — автоматично після merge;  
- production — або автоматично (для low-risk), або через manual approval step (для high-risk release).

4. Оновлюються machine-readable release manifests (див. PD-011-templates) + `CHANGELOG.md` (частково авто-генерований).

---

## 4. Authoring → Registry

### 4.1 Mapping артефактів DSL на Registry-модель

PD-003 визначає логічні сутності Registry, наприклад:

- `product`, `product_version`;  
- `product_profile` (pricing/ops/safety/quality/token/loyalty);  
- `product_market_mapping` (продукт ↔ ринок/місто);  
- `policy` (ops_policies, safety rules);  
- історію змін (changelog / migration records).

**Authoring** оперує файловою структурою (`products/PRD-…/…`), **Registry** — таблицями/записами.  
CLI + Registry API виконують трансляцію:

- зчитування DSL;  
- трансформацію у нормалізовані моделі (PD-003-registry.ddl);  
- upsert/міграції.

### 4.2 Environments

Registry має чітке розділення **environmentів**:

- `dev` — для локальної розробки/тестів;  
- `staging` — для інтеграційних тестів / beta-rollout;  
- `production` — для живого рантайму.

Authoring/CI керує тим, **які версії DSL** публікуються в який Registry environment:

- PR-Preview → тимчасовий namespace (наприклад, `staging_pr_<id>`);  
- main/staging → `staging`;  
- tagged release або approve step → `production`.

### 4.3 Idempotent публікація

`product publish` реалізує ідемпотентний підхід:

- при повторному запуску з тим самим snapshot’ом — результат той самий;  
- зміни відстежуються через migration records (PD-003), що полегшує rollback та аудит.

---

## 5. Governance → Registry & CI

### 5.1 Risk-based promotion

Governance (PD-013) визначає **policy для promotion** між середовищами:

- low/medium risk:  
  - auto-publish → staging;  
  - auto-promote → production після T0-тестів (або з мінімальним manual approve).

- high/critical risk:  
  - окремі change windows;  
  - обов’язковий pre-deploy review (Ops/SRE/SAFE/FIN);  
  - ручне підтвердження step у CI перед `product publish --env=production`.

### 5.2 Audit trail

Комбінація Git + Registry дає повний слід змін:

- Git: хто, коли, що змінював у DSL-файлах;  
- PR: мотивація, ризики, approvals;  
- Registry: які продукти/версії/профілі фактично були активні в середовищі в конкретний час.

Governance-вимоги (PD-013) включають мінімальний retention для:

- release manifests;  
- migration logs;  
- audit events (publish/rollback).

### 5.3 Emergency policy

У випадках emergency (див. PD-011 §9):

- Governance дозволяє **тимчасовий обхід** стандартного authoring-циклу для:
  - `safety_overrides`;  
  - `stop-sell` флагів на рівні Registry/Runtime.

- Але всі такі дії логуються як **emergency changes** з обов’язковим пост-фактум PR/ADR, що формалізує постійні зміни в DSL.

---

## 6. Runtime Feedback → Authoring

### 6.1 Runtime events & analytics

Runtime (TJM/Trutta/LEM/Ops) генерує події:

- `product.runtime.*`, `journey.*`, `entitlement.*`, `lem.*`, `ops_incidents.*`, `compensation.*`;  
- ці події агрегуються в аналітиці (quality_scores, SLO dashboards, unit economics).

Ці дані формують **input** для наступних циклів authoring’у:

- корекція pricing/financial профілів;  
- зміни в Ops/Safety/Quality профілях;  
- зміни в політиках (`ops_policies`);  
- рішення про sunset/retire продуктів.

### 6.2 Tightly coupled loops

PD-011 визначає процеси product review/portfolio review; PD-013 — governance рамки;  
**цей документ** фіксує, що:

- будь-які системні зміни, які базуються на runtime-даних,
  **повинні повертатися в DSL як авторингові зміни** (PR → CI → Registry), а не тільки як ручні tweaks у рантаймі.

---

## 7. Summary

- Authoring (PD-011) працює поверх git-репозиторію DSL і завжди йде через PR + governance правила (PD-013).  
- Tooling/CI (PD-012) є обов’язковим прошарком: валідація, diff, snapshot, publish; прямі ручні зміни Registry заборонені.  
- Registry (PD-003) — єдине джерело правди для runtime; він наповнюється тільки через затверджені snapshot’и з CI.  
- Emergency-дії можливі, але завжди логуються та повинні бути закриті follow-up авторинговими змінами.  
- Runtime дані та інциденти впливають на наступні цикли authoring’у, але **через формалізовані процеси та інструменти**, а не ad-hoc конфіг змінювання в проді.

