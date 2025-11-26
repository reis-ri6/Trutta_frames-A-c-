# Transform: Code Classification

Ця трансформація описує, як класифікувати кодові файли, оцінити їхню цінність для Trutta-екосистеми й вирішити, чи це кандидат у темплейт/канон, чи історичний шум.

Використовується `repo-ingestion-agent` для файлів із:
- `kind = code`.

---

## 1. Вхід

**Input file**:

- будь-який файл, класифікований як `kind = code`:
  - `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.sql`, `.sh`, `.go`, `.rb`, `.php`, `.tf`, `.yaml`, `.yml`, `.json` (як конфіг/код), тощо;
- містить:
  - приклади, скрипти, темплейти, інфраструктуру, тести.

Агент має читати контент + аналізувати шлях/назву файла.

---

## 2. Вихід

Агент **не змінює код**.  
Він оновлює запис у `ingestion/ingestion-index.yaml` для кожного файлу:

- `subtype`
- `relevance_score`
- `novelty_score`
- `actuality_score`
- `decision`
- `linked_artefact_id` (якщо очевидно)

---

## 3. `subtype` для `kind = code`

Визначити один із:

- `snippet`
  - короткий шматок коду;
  - немає чіткого entrypoint;
  - часто у docs/notes, всередині Markdown;
  - не самодостатній.
- `script`
  - можна запускати напряму (CLI, job, міграція);
  - має зрозумілий entrypoint:
    - `main()`, `if __name__ == "__main__"`, `#!/usr/bin/env`, `npm script`, cron-job.
- `template`
  - містить плейсхолдери/коментарі «project-specific»;
  - призначений для копіювання/адаптації;
  - назви типу `template`, `boilerplate`, `skeleton`.
- `infra`
  - Dockerfile, docker-compose, Terraform, k8s manifests, CI pipelines, Supabase/DB конфіги;
  - все, що описує інфраструктуру/розгортання.
- `test`
  - шляхи: `tests/`, `__tests__/`, `test/`;
  - назви: `*.test.*`, `*.spec.*`;
  - містить assertions/expectations.
- `other`
  - усе, що не підпадає ні під один з вище описаних кейсів.

Якщо сумнів між `script` і `template`:
- якщо є багато TODO/placeholder → `template`;
- інакше → `script`.

---

## 4. Скоринги для коду

### 4.1. `relevance_score`

Питання: «наскільки цей код про Trutta/TJM/ABC/домени?»

Підвищують:

- шляхи типу:
  - `trutta/`, `tjm/`, `abc/`, `sospeso/`, `bread/`, `vienna/`, `reis/ri6/`;
- імпорт/використання:
  - Trutta APIs/SDK;
  - доменних схем з `schemas/`;
  - модулів, що явно маркують токенізацію сервісів/страв/подорожей;
- згадка доменів:
  - trips, vendors, hotels, dishes, menus, health constraints, FDA.

Знижують:

- generic-туторіали без привʼязки до Trutta/доменів;
- файли, що стосуються локального дев-оточення користувача (особисті helper-и).

### 4.2. `novelty_score`

Питання: «наскільки цей код відрізняється від того, що вже є?»

- якщо структура/AST майже збігається з існуючим файлом → низька новизна (`0.0–0.2`);
- якщо це варіація прикладу з незначними змінами → середня (`0.3–0.5`);
- якщо вводить новий флоу/патерн/інтеграцію → висока (`0.6+`).

Агент може орієнтуватись на:
- семантичну схожість;
- однакові назви функцій/класів/файлів;
- вставки `copy of`, `backup`, `old`, `v2`, `final-final-2` → часто низька новизна.

### 4.3. `actuality_score`

Питання: «наскільки цей код відповідає поточному стеку?»

Підвищують:

- використання актуальних бібліотек/версій;
- згадки про діючі сервіси/ендпоінти;
- узгодженість з останніми схемами/PD/VG.

Знижують:

- deprecated SDK/версії;
- старі назви сервісів;
- коментарі типу `legacy`, `old api`, `tmp`, `to be removed`.

---

## 5. `decision` для коду

### 5.1. `ignore`

- build-артефакти, згенеровані файли, vendor bundles;
- автоматично згенерований код, який не редагується вручну.

### 5.2. `archive`

- старі/legacy-приклади;
- код, який не відповідає актуальному стеку;
- вузькоособисті helper-и.

### 5.3. `promote_candidate`

Сильний кандидат у:

- canonical-приклад;
- темплейт;
- частину архітектури/infra.

Типові кейси:

- `subtype = template` з високими `relevance_score` і `actuality_score`;
- `subtype = script`, що реалізує важливий флоу (onboarding vendor, mint/redeem tokens, journey sync);
- `subtype = infra`, що описує рекомендований спосіб деплою.

Хороші пороги (орієнтовно):

- `relevance_score >= 0.6`
- `actuality_score >= 0.6`
- `novelty_score >= 0.3`

### 5.4. `archive` vs `promote_candidate`

Якщо файл корисний **але**:

- стек старий;
- флоу вже перекритий більш новими прикладами;
- є кращий, більш сучасний темплейт —

→ краще `archive`, а не `promote_candidate`.

---

## 6. `linked_artefact_id` для коду

Якщо код очевидно належить до певного canonical-артефакту:

- темплейт Sospeso → `TEMPLATE-SOSPESO`;
- core Trutta DSL → `PD-001`;
- vendor onboarding scripts → `VG-500`;
- TJM-related tools → `CONCEPT-TJM` або спеціальний `VG`/`PD`.

Правила:

1. Звірити шлях/назву/коментарі з `progress/artefacts/artefact-index.yaml`.
2. Якщо є однозначне попадання → заповнити `linked_artefact_id`.
3. Якщо сумнів → лишити `null`.

---

## 7. Поведінка агента

Для кожного `code`-файла:

1. Визначити `subtype` за структурою, шляхом, назвою.
2. Оцінити:
   - `relevance_score`,
   - `novelty_score`,
   - `actuality_score`.
3. Обрати `decision` (`ignore` | `archive` | `promote_candidate`).
4. За потреби — встановити `linked_artefact_id`.
5. Оновити відповідний запис у `ingestion-index.yaml`.

Жодних змін в самому файлі коду агент не робить.

---

## 8. Консервативні правила

Якщо:

- немає впевненості в `subtype` → ставити `other`;
- немає впевненості в рішенні:
  - між `archive` і `promote_candidate` → брати `archive`;
- немає впевненості в `linked_artefact_id` → лишити `null`.

`doc-canonisation-agent` + люди вже вирішуватимуть, що підняти в канон.
