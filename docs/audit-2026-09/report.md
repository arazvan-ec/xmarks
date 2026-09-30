# flywheel (arazvan-ec/xmarks) — Análisis y propuestas de mejora

**Fecha:** 2026-09-30 · **Versión analizada:** 0.83.0 (`5249626`) · **Método:** lectura estática + ejecución real del sweep + shellcheck + cuatro auditorías paralelas (scripts, tests, superficie del plugin, docs/CI), contrastadas con las guías `agent-development`, `writing-skills`, `skill-creator` y `claude-automation-recommender`.

---

## 0. Veredicto

El repo está **sano y por encima de la media**. No es un caso de "arreglar lo roto":

| Señal | Medición |
|---|---|
| Sweep completo (13 gates + 35 suites) | **48/48 PASS** (ejecutado) |
| shellcheck sobre 66 scripts / 12.604 líneas | **0 errores**, 3 warnings (los 3 falsos positivos: `VAR= cmd` leído como `SC1007`) |
| Paridad hooks/agentes distribuidos vs autoaplicados | Vigilada por gate propio (`check-hook-parity.sh`, `check-agent-parity.sh`) |
| Paridad sweep local ↔ CI | Vigilada (`check-ci-gate-parity.sh`, lee los `run:` del YAML) |

El problema **no es calidad, es masa y acoplamiento**: 12.604 líneas de bash, 2.616 de Python embebido en heredocs, 7.188 líneas de tests con 75-90 % de arnés repetido, un README de 5.431 palabras y 80 notas de upgrade en 90 días de historia (≈1 release/día). El riesgo dominante es el **coste marginal de cada cambio futuro**, no un defecto presente.

Las propuestas siguen el idioma del propio repo: **cada mejora viene con el gate que la mantiene viva**.

---

## 1. Top 5 por retorno inmediato

### 1.1 Paralelizar el sweep — **3,9× medido**, esfuerzo S

`sweep.sh` ejecuta las 35 suites secuencialmente. Medido en este sandbox:

```
secuencial (for t in scripts/test-*.sh)      real 1m18.339s
paralelo   (xargs -P4)                       real 0m20.268s   ← mismo resultado, 0 fallos
```

Los tests ya son seguros para paralelizar: cada uno crea su propio `WORK="$(mktemp -d)"` con `trap`, ninguno hace `cd` al árbol compartido, y los 6 que tocan ficheros de presupuesto escriben en copias bajo `${WORK}`. Los tres pesados (`test-eval-graders.sh` 13,1 s, `test-fixture-scratch.sh` 8,7 s, `test-install-vendored.sh` 8,1 s) concentran el tiempo.

**Acción:** en `sweep.sh`, sustituir el bucle por `xargs -P "$(nproc)"` con log por fichero (para no entrelazar salidas) y conservar el veredicto por exit code. En CI, lo mismo dentro del job.
**Gate:** `test-sweep.sh` ya existe; añadir un caso que verifique que el sweep paralelo detecta un test rojo igual que el secuencial.

### 1.2 shellcheck en CI — hoy pasa limpio, esfuerzo S

El repo es 100 % bash ejecutable y **no tiene linter de shell** en ningún workflow. Lo verifiqué: `shellcheck -S warning scripts/*.sh` da 0 errores hoy, así que el gate **entra en verde el primer día** y a partir de ahí la deuda no puede crecer.

**Acción:** step nuevo en `validate-plugins.yml` (`shellcheck -S warning scripts/*.sh`) y, opcionalmente, hook `PostToolUse` con matcher `Write|Edit` sobre `*.sh` para retroalimentación inmediata durante el trabajo.

### 1.3 Pinning de acciones en los otros tres workflows — esfuerzo S

`check-supply-chain-pin.sh` protege con rigor el caso crítico (`flywheel-update.yml`: `actions/checkout@11bd719…` + `peter-evans/create-pull-request@271a8d0…`). Pero:

```
.github/workflows/release.yml:36            uses: actions/checkout@v4      ← tag móvil
.github/workflows/validate-plugins.yml:29   uses: actions/checkout@v4      ← tag móvil
.github/workflows/validate-plugins.yml:31   uses: actions/setup-node@v4    ← tag móvil
.github/workflows/validate-plugins.yml:50   uses: actions/checkout@v4      ← tag móvil
```

Un tag `v4` re-apuntado (el vector clásico contra GitHub Actions) alcanza el pipeline que **valida el propio plugin** — el sitio donde un compromiso pasa más desapercibido. El estándar que el repo se exige en un workflow no se aplica en los otros tres.

**Acción:** pinnear por SHA los 4 `uses:` restantes; extender `check-supply-chain-pin.sh` para cubrir todos los `uses:` del directorio, no solo el par crítico.
**Extras del mismo bloque (S):** falta `concurrency:` en los 4 workflows (dos pushes casi simultáneos pueden correr `release.yml` en paralelo sobre tags), falta `cache: npm` en `setup-node` (se reinstala `@anthropic-ai/claude-code` sin caché en cada corrida) y no hay `dependabot.yml`.

### 1.4 Rotación de `LEARNINGS.md` — el diseño ya existe, falta implementarlo — esfuerzo M

`LEARNINGS.md` tiene **1.049 líneas / 96 KB** y se inyecta (filtrado) en cada `SessionStart`. `docs/research/git-native-memory-design.md:115-121` **ya especifica** la política de archivado a `.claude/flywheel/learnings-archive/YYYY-QN.md` al cruzar un umbral — y `find . -iname "*learnings-archive*"` no devuelve nada: **diseñado, nunca construido**.

Es el punto de mayor impacto sobre el coste de contexto recurrente, y es el propio repo el que se contradice: su producto vende disciplina de tokens mientras su ledger crece sin rotación.

**Acción:** implementar la rotación en `/flywheel:compound` con umbral por bytes (p. ej. 50 KB) y gate `check-ledger-size.sh`.

### 1.5 Descriptions de skills: el disparador está contaminado por el workflow — esfuerzo S-M

`writing-skills` documenta con un caso reproducido que **si la description resume el flujo, el agente sigue la description y no lee el body** (en ese caso hizo una revisión en vez de dos). 17 de 18 skills de flywheel empiezan correctamente por "Use when…" pero **casi todas resumen antes el proceso**. Los peores: `loop` (enumera las 6 fases), `work` (el inner loop completo: "failing test, minimal implementation, run, observe, fix"), `run` (los 5 pasos del contrato), `review` ("routed by diff type… dispatched in parallel, synthesized").

El riesgo concreto: `review` describe el enrutamiento por tipo de diff en la propia description, así que un agente puede decidir el fan-out **sin leer la lógica real** del body.

Reescrituras de ejemplo (solo disparador):

| Skill | Propuesta |
|---|---|
| `loop` | *Use when starting a new feature or task and you want the full gated cycle instead of running one phase manually.* |
| `work` | *Use when executing tasks from an approved plan, or when told to implement something test-first rather than write-then-check.* |
| `run` | *Use when executing an operation previously defined with /flywheel:process; Claude acts as the backend for that operation.* |

**Sobre el gate existente:** `check-description-budget.sh` mide bien (3538/3600 chars, verificado) pero mide **cuánto pesa**, no **de qué tipo es**. Una description puede cumplir el presupuesto y violar la regla SDO — como pasa hoy.
**Acción:** añadir al gate una heurística que exija "Use when|Use to|Use before|Use after" al inicio y marque encadenamientos de proceso (`→`, `then`, listas de pasos) en la description.

---

## 2. Refactors estructurales (mayor esfuerzo, mayor apalancamiento)

### 2.1 Librería común de bash + extracción de los heredocs Python — L

**Los números:** 23 scripts de producción contienen Python embebido, **2.616 líneas** en heredocs. Los cuatro mayores suman 996: `run-cost.sh:27-324` (297), `check-supply-chain-pin.sh:60-311` (251), `delegation-guard.sh:53-267` (214), `check-route-honored.sh:69-276` (207). Esa lógica **no es lintable con ruff/mypy, no admite pytest y solo se verifica end-to-end**.

Ya existe precedente propio de que el patrón alternativo funciona: `fw_cutoffs.py` (99 líneas) y `fw_tasks.py` (36) están extraídos e invocados como CLI desde `check-route-honored.sh:64`.

**Duplicación literal cuantificada:**

| Patrón | Copias | Ubicación representativa |
|---|---|---|
| Parser de allow-list con "reason" + detección de stale | **3 implementaciones distintas** | `check-fixture-leaks.sh:59-79` (bash), `check-supply-chain-pin.sh:80-96` (py), `check-task-closure.sh:98-110` (py, semántica distinta: regex) |
| `SKIP_<GATE>=1 → echo SKIPPED → exit 0` | 8-9 | `check-agent-parity.sh:24`, `check-description-budget.sh:13`, … |
| Resolución de `CLAUDE_PROJECT_DIR` | 7 idénticas | `bash-allow.sh:24`, `write-allow.sh:19`, `gate.sh:37`, … |
| Resolución de base-ref | 2 idénticas (admitido en el comentario de `check-release-bump.sh:12-13`) | `check-release-bump.sh:37-39`, `check-test-pairing.sh:15-17` |

**Acción:** `scripts/lib/fw_common.sh` (`fw_strict_mode`/`fw_hook_mode`, `fw_skip_gate`, `fw_project_dir`, `fw_resolve_base_ref`, `fw_read_hook_input`) + `scripts/lib/fw_allowlist.py` + extracción de los 4 heredocs mayores a `scripts/lib/fw_*.py` con su pytest. Ahorro estimado: 250-350 líneas duplicadas y ~1.770 líneas que pasan de "solo verificables end-to-end" a testeables unitariamente.

### 2.2 Arnés de test común — L, pero es el mayor apalancamiento de mantenibilidad

`pass()` está definido **34 veces** y `fail()` **33**, casi siempre byte a byte (`fail() { echo "FAIL: $*" >&2; exit 1; }`). `mktemp -d` + `trap` en 33 de 35 ficheros. `run_hook()` reimplementado 7 veces. `repo()` 6 veces. `g() { git -C … }` 6 veces. Y los graders de evals (`skills/*/evals/check.sh`, 847 líneas) triplican su propio `ok()/fail()/check()` — tres de ellos son **idénticos byte a byte**.

Midiendo líneas de aserción real frente al total en cinco ficheros representativos: entre **5 % y 26 %** es aserción; el resto es arnés.

La deriva ya empezó: la mayoría de `fail()` hace `exit 1` inmediato, pero `test-docs-consistency.sh:9` acumula en `STATUS=0` y sigue. Son dos semánticas distintas de "test rojo" conviviendo.

**Acción:** `scripts/lib/fwtest.sh` con API mínima (`fw_work`, `fw_repo`, `fw_g`, `fw_run_hook`, `fw_pass/fw_fail`, `fw_assert_rc`, `fw_assert_says`, `fw_summary`).
**Riesgo honesto:** un arnés roto rompe 41 suites a la vez. Mitigación en tres capas: (a) `test-fwtest.sh` — self-test del arnés que corre **primero** en el sweep, con casos rojo y verde explícitos (el repo ya hace esto para `sweep.sh` con `test-sweep.sh`); (b) migración incremental empezando por los 7 `run_hook`, que son el grupo más homogéneo; (c) nunca big-bang.

### 2.3 Consolidar los tres hooks `Stop` — M

Hoy hay tres hooks `Stop` encadenados que bloquean con `exit 2` **por razones no relacionadas**: `gate.sh` (suite roja, timeout 300 s), `toolbar.sh stop` (la respuesta final no abre con la barra de progreso), `compound-due.sh` (hay un run con `phase: ship` sin `phase: compound`).

El propio repo ya documentó el problema en `docs/research/improvement-proposals.md:565-580`: el suite se re-ejecuta en turnos de solo-Q&A y un gate rojo permanente re-atrapa turno tras turno. Con tres bloqueadores independientes, el modelo recibe los motivos **fragmentados en reintentos sucesivos** en vez de todos a la vez: arregla el formato de la barra, reintenta, ahora falla el compound, reintenta, ahora falla el gate.

**Acción:** un orquestador `stop-gates.sh` que ejecute los tres internamente, **agregue todos los motivos en un único mensaje** y emita un solo `exit 2`. Coste adicional cero, y convierte tres ciclos de reintento en uno.

### 2.4 `read-meter.sh` en `PostToolUse` con matcher `.*` — M

Corre en **cada** llamada de herramienta: arranca bash + `mktemp` + CPython (20-40 ms solo de arranque) y hace escritura + relectura del acumulado por invocación. En un turno con 3-5 herramientas, sumando `bash-allow`/`write-allow`/`delegation-guard` en `PreToolUse` y `toolbar.sh` dos veces por turno, son del orden de **8-15 arranques de proceso por turno** antes de que el modelo haga nada útil.

Hay una ironía medible: el hook existe para advertir de que "la factura de la sesión crece con el cuadrado de su longitud" y él mismo reproduce ese patrón a nivel de hooks (relee el log completo cada vez).

**Acción:** (a) pre-filtro en bash puro con `case` sobre `tool_name` antes de arrancar Python; (b) append sin relectura total, releyendo solo al cruzar umbral.

---

## 3. Corrección de defectos latentes (todo esfuerzo S)

### 3.1 `grep -q` alimentado por pipe bajo `pipefail` — clase de bug ya reproducida, corregida a medias

El commit `38a7a1e` documenta el hallazgo con datos: *"Under pipefail, `sed | grep -q` reads a match as a failure when grep exits before sed finishes (SIGPIPE). 5/300 false fails reproduced in isolation; this is what reddened check-task-closure intermittently"*. Ese fix tocó **solo** `test-fixture-scratch.sh`. El mismo patrón sigue vivo en producción:

- `check-fixture-leaks.sh:77` → `if ! pattern_ids | grep -qx "${aid}"; then` (el script tiene `set -uo pipefail` en :21)
- `renumber.sh:55` → `printf … | sed -E … | grep -qE -- "${RE}" && printf …` (`set -uo pipefail` en :20)

**Acción:** aplicar el mismo fix ya validado — alimentar `grep -q` desde variable, no desde pipe.

### 3.2 Convención de `set` no declarada ni vigilada

Tres clases conviven sin que nada las documente ni las verifique: **8 scripts sin ninguna línea `set`** (`bash-allow.sh`, `delegation-guard.sh`, `delegation-record.sh`, `gate.sh`, `git-tracking-refs.sh`, `read-prime.sh`, `session-start.sh`, `write-allow.sh`), **17 con `set -uo pipefail`**, **6 con `set -euo pipefail`** y `read-meter.sh` con solo `set -u`.

El diseño es correcto —los hooks deben fallar abiertos, nunca abortar a medias— pero es **conocimiento tácito**: nada impide que el próximo hook nazca con `set -e` y bloquee un turno por un fichero ausente.

**Acción:** declarar la convención en `CLAUDE.md` y añadir `check-shell-conventions.sh` que exija: todo script registrado en `hooks.json` → clase fail-open; todo `check-*.sh` → `set -euo pipefail`.

### 3.3 `install-vendored.sh`: temporales huérfanos y glob sin `nullglob`

Con `set -euo pipefail` (:36) pero **sin ningún `trap`** (verificado: `grep -n "trap "` no devuelve nada), `mktemp` en :339 y en :358 (`vendor_file()`, llamada decenas de veces) deja temporales en `/tmp` si la instalación falla a medias. Y `for f in "${SRC}"/agents/*.md` (:264, :395) sin `shopt -s nullglob`: si `agents/` quedara vacío, el glob literal se pasaría como nombre de fichero.

### 3.4 Límite de 128 KiB en la entrada de hooks

`read-meter.sh:120-126` usa fichero temporal **precisamente porque documenta** que el payload puede superar el límite de variable de entorno. Pero `bash-allow.sh:26`, `write-allow.sh:22`, `delegation-guard.sh:37` y `read-prime.sh:16` hacen `INPUT="$(cat)"` y lo pasan a Python vía `FW_HOOK_INPUT="${INPUT}"` — heredando exactamente el límite que `read-meter.sh` decidió evitar. Con un `tool_response` grande, truncan en silencio.

### 3.5 Contrato de exit code sin test transversal

Todos los gates usan `0 ok / 1 fail / 2 input inutilizable`, pero **6 lo deciden en bash** (`exit "${rc}"`) y **5 lo delegan al heredoc Python** (`sys.exit(1 if cond else 0)`). Existe test por gate, pero ninguno del contrato común: un cambio en un heredoc puede romperlo sin que nada se ponga rojo.
**Acción:** `test-gate-contract.sh` que ejecute los 11 `check-*.sh` con fixtures inválidas comunes.

### 3.6 Huecos de cobertura en los propios gates

- `check-test-pairing.sh:24` empareja `scripts/*.sh` y `scripts/*.py`, pero **no** `skills/*/evals/check.sh` (6 graders, 847 líneas de código de producción que pueden cambiar sin gate de pairing).
- La lista de specs en `test-eval-graders.sh:82-96` es **manual**: un eval nuevo no aparece solo. Es el mismo patrón de "lista a mano desincronizable" que `check-ci-gate-parity.sh` ya corrigió para los gates de CI.
- No hay validación estructural de `evals.json` (ids únicos, campos obligatorios). Un lint de ~40 líneas, **sin coste de tokens**, cerraría el hueco.

---

## 4. Superficie del plugin

### 4.1 Agentes: falta `color` y "When to invoke" en los 6

Contrastado con `agent-development`, que lista `color` como **campo requerido** y la sección `## When to invoke` como parte del formato completo. Ninguno de los 6 agentes tiene ninguna de las dos cosas (`grep -il "when to invoke" agents/*.md` → vacío). El campo propio `effort:` es una extensión legítima, pero no sustituye a `color`.

Colores sugeridos (distintos entre sí, según la guía): `verifier`=green, `reviewer-correctness`=blue, `reviewer-security`=red, `reviewer-performance`=yellow, `evaluator`=cyan, `executor`=magenta.

**Menor privilegio:** los tres `reviewer-*` declaran `tools: Read, Grep, Glob, Bash` mientras su system prompt dice *"Do not modify files"*. Bash permite `sed -i` o `>`: la restricción está en la prosa, no en el frontmatter. La guía recomienda `["Read","Grep","Glob"]` para análisis de solo lectura. **Acción:** quitar Bash o acotarlo (`Bash(git diff:*)`, `Bash(git log:*)`).

### 4.2 Duplicación README ↔ `skills/help/SKILL.md`

La tabla de comandos de `skills/help/SKILL.md:16-35` (16 filas) es una reescritura casi 1:1 de `README.md:57-78`, **y ya ha divergido en redacción** (help:29 *"About to delegate work outside a plan…"* vs README:72 *"Before delegating work outside a plan…"*). Dos fuentes de verdad que `test-docs-consistency.sh` mantiene sincronizadas a mano.
**Acción:** generar ambas desde una fuente única, o que `help` referencie en vez de duplicar.

### 4.3 `plugin.json`: la description son 604 caracteres de una sola frase

Cinco cláusulas técnicas encadenadas, con el gancho al final. Para un catálogo de marketplace —que se escanea rápido— es inadecuado. Propuesta (~185 chars):

> *Disciplined spec→plan→work→verify→review→compound loop for AI-assisted development, plus an agent-native runtime for recurring operations Claude executes and matures over time.*

Además, `marketplace.json` mantiene una **tercera copia** de la misma prosa, sincronizada a mano; y las 7 `keywords` no cubren "agent-native" ni "process-contract", que son literalmente el segundo pilar del producto.

### 4.4 Automatización que falta para el propio repo

Aplicando el criterio de `claude-automation-recommender`: el 100 % del código ejecutable es bash y los tres reviewers son genéricos. **Falta un subagente `bash-reviewer`** especializado (quoting, `set` flags, `trap`, SIGPIPE bajo `pipefail`, inyección por variables no saneadas) invocado por `/flywheel:review` cuando el diff toca `scripts/*.sh`. Los tres defectos de §3.1-3.4 son exactamente lo que ese reviewer habría encontrado.

---

## 5. Documentación y versionado

### 5.1 El README es un cuello de botella — M

**5.431 palabras**, 202 líneas, **31 menciones de versión**, 11 párrafos de más de 150 palabras, y 6 de los 19 encabezados `##` llevan el número de versión en el título. Mezcla tres audiencias en el mismo párrafo: referencia de uso, rationale de diseño y bitácora de versiones.

Peor: buena parte documenta el **pasado**, no el estado actual —

- `README.md:132` *"Before it, 14 of 16 shipped runs in this repo carried no compound line."*
- `:152` *"It **used to** `git clone` this repo's `main` and `bash` the result…"*
- `:136` *"A lesson about the plugin… **used to** stay in that repo's ledger."*
- `:176` *"this step **used to** say `W=$(mktemp -d)`…"*

Son notas de migración disfrazadas de referencia, y **ya existen mejor contadas en otro sitio** (`upgrades/v0.61.0.md`, `docs/research/pillar2-threat-model.md`).

`check-version-citations.sh` no cubre esto y lo dice explícitamente en su cabecera (*"Not every version named in prose… this repo's prose names old versions constantly and legitimately"*): de las 31 menciones, solo **1** es una citación enlazada que el gate valida.

**Reestructuración propuesta:**

| Destino | Contenido |
|---|---|
| `README.md` (~70 líneas) | Qué es, instalación, los dos loops, tabla de comandos, tabla de agentes, layout. Cero `(vX.Y.Z)` salvo compatibilidad mínima |
| `docs/design-rationale.md` (nuevo) | Los párrafos de >150 palabras que explican el porqué (P27/P28/P47/P56/P69/P70, hoy en `README:83-176`) |
| `docs/security-model.md` (nuevo o fusionado con `pillar2-threat-model.md`) | Supply-chain pinning, delegated review |
| `CHANGELOG.md` (nuevo, **generado**) | Todo "used to / no longer / before it" |

**Gate:** extender `check-version-citations.sh` para fallar por encima de N párrafos de >120 palabras en el README.

### 5.2 Versionado: ~1 release/día, sin CHANGELOG

545 commits en 90 días → **0,92 versiones/día y ~1 spec/día**. `upgrades/` ya tiene **80 ficheros / 33.583 palabras**. No existe `CHANGELOG.md`. La regla `CLAUDE.md:144` (*"Every change to skills/, agents/, hooks/, or scripts/ is a release"*) obliga a tocar tres sitios por cambio, vigilados por tres gates distintos. Proyectado a 12 meses: ~330 notas de upgrade.

**Acción:** generar `CHANGELOG.md` automáticamente desde el frontmatter (`version`, `summary`) de `upgrades/*.md` dentro de `release.yml` —coste casi nulo, el frontmatter ya existe— y dejar de anotar versiones en los títulos del README. Cuantificar cuántas notas son "nothing to do" (el propio `upgrades/README.md` admite que es un resultado común y válido) para valorar agrupar micro-releases.

### 5.3 Estado acumulado: 1,2 MB y creciendo sin política

`.claude/flywheel/` pesa **1,2 MB / 133 ficheros trackeados**: `specs/` 644 KB (90 ficheros), `runs/` 416 KB (31 `.jsonl` + 9 `.html`), `LEARNINGS.md` 96 KB.

**Acción:** además de la rotación del ledger (§1.4), separar `specs/shipped/` de `specs/active/` (hoy 36 de 58 declaran `shipped as vX.Y.Z` y el criterio no es uniforme) y dejar de versionar los `.html` de `runs/`, que son derivables de los `.jsonl` canónicos.

### 5.4 `install-vendored.sh`: 614 líneas, 4 funciones — M/L

Es el único camino de instalación para Claude Code web y el único self-target permitido, es decir, **infraestructura crítica de distribución** — y es un script secuencial con estado global (`MODE`, `AUTO_UPDATE`, `AGENTS_ONLY`, `HOOKS_ONLY` en :38-41), un heredoc Python de ~100 líneas para fusionar `settings.json`, generación de YAML embebida y la lógica completa de desinstalación (~140 líneas) mezclada con la de instalación. Una regresión en el merge de hooks rompe instalación, desinstalación y `--hooks-only` a la vez.

**Acción (manteniendo un único entrypoint):** extraer el merge a `scripts/lib/merge-hook-settings.py`, el flujo `uninstall` a `scripts/lib/uninstall-vendored.sh`, el YAML del auto-update a `scripts/templates/flywheel-update-caller.yml.tpl`, y `vendor_file`/`in_manifest`/`rewrite` a `scripts/lib/vendor-common.sh` — cada pieza con su `test-*.sh`, cumpliendo la propia convención test-first de `CLAUDE.md:131-134`.

---

## 6. Hoja de ruta sugerida

Agrupada como specs numeradas, en el idioma del repo: cada una con su gate.

| # | Propuesta | Esfuerzo | Retorno | Gate que la mantiene |
|---|---|---|---|---|
| **P72** | Sweep paralelo (3,9× medido) | S | Alto | `test-sweep.sh` (caso rojo en paralelo) |
| **P73** | shellcheck en CI + pin SHA de las 4 acciones + concurrency + cache + dependabot | S | Alto | `check-supply-chain-pin.sh` extendido |
| **P74** | Convención de `set` declarada + fix SIGPIPE ×2 + `trap`/`nullglob` en install-vendored + límite 128 KiB | S | Alto | `check-shell-conventions.sh` (nuevo) |
| **P75** | Rotación de `LEARNINGS.md` (diseño ya escrito, sin construir) | M | Alto | `check-ledger-size.sh` (nuevo) |
| **P76** | Descriptions = disparador, no workflow (18 skills) | S/M | Alto | `check-description-budget.sh` + heurística SDO |
| **P77** | `color` + "When to invoke" + menor privilegio en los 6 agentes | S/M | Medio | `check-agent-parity.sh` extendido |
| **P78** | Consolidar los tres hooks `Stop` en un orquestador | M | Medio | `test-stop-gates.sh` (nuevo) |
| **P79** | `scripts/lib/fwtest.sh` + `test-fwtest.sh`, migración incremental | L | Muy alto | Self-test del arnés, primero en el sweep |
| **P80** | `fw_common.sh` + `fw_allowlist.py` + extraer los 4 heredocs mayores | L | Muy alto | `test-gate-contract.sh` (nuevo) |
| **P81** | README → docs/ + CHANGELOG generado + archivado de specs/runs | M | Medio | `check-version-citations.sh` extendido |
| **P82** | Descomponer `install-vendored.sh` | M/L | Medio | Un `test-*.sh` por pieza |
| **P83** | Subagente `bash-reviewer` en `/flywheel:review` | M | Medio | Enrutamiento por diff sobre `scripts/*.sh` |

**Orden recomendado:** P72-P74 primero (días, riesgo casi nulo, todo verificable de inmediato) → P75-P77 (impacto directo en el comportamiento del producto) → P79/P80 (el gran refactor, incremental y con self-test) → el resto.

---

## 7. Lo que conviene NO tocar

Para que las propuestas anteriores no se lean como una invitación a reescribir:

- **La disciplina de gates.** 13 gates de CI con test propio cada uno es infraestructura cara de construir y barata de mantener. Está bien.
- **El sistema de paridad** (`check-hook-parity`, `check-agent-parity`, `check-ci-gate-parity`). Cierra la clase de bug más difícil de detectar en un plugin con dos rutas de distribución.
- **Los presupuestos** (`description-budget.txt`, `invocation-budget.txt`, `telemetry-baseline.txt`). Convertir una convención en un fichero de datos versionado es el patrón correcto: retunear es un cambio de datos revisable, no un cambio de código.
- **La honestidad epistémica sobre las evals.** El README admite que las katas de `work` son regression-only y que las pass-rates de pilar 2 no son evidencia del valor de la skill. Eso es infrecuente y vale más que un número bonito.
- **El modelo de confianza de `gate.sh`** (hash fuera del repo, re-consentimiento al editar). Está bien razonado.

---

## Anexo — Comandos de verificación

```bash
bash scripts/sweep.sh                       # 48/48 PASS (ejecutado 2026-09-30)
shellcheck -S warning scripts/*.sh          # 0 errores, 3 warnings (falsos positivos SC1007)
bash scripts/check-description-budget.sh    # OK — 3538/3600 chars across 18 skills
time (for t in scripts/test-*.sh; do bash "$t" >/dev/null 2>&1; done)        # 1m18.339s
time (ls scripts/test-*.sh | xargs -P4 -I{} bash -c 'bash {} >/dev/null 2>&1')  # 0m20.268s
```
