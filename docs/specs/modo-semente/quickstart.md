# Quickstart: modo semente

Cenários a automatizar como `cenario "17: modo semente"` em `scripts/testar-configurar.sh`
(SC-001), usando os helpers existentes (`novo_repo`, `cockpit_copia`, `codigo`, `rodar`).

## 1. Semente nova é gravada (US1-1)

1. Repo vazio → configurar com `cockpit.config.example`
2. **Expected**: exit 0; `CLAUDE.md`, `docs/constitution.md`, `docs/project-context.md`
   existem e estão no manifesto.

## 2. Semente existente fica intacta (US1-2, SC-002)

1. Repo com `CLAUDE.md` próprio → configurar
2. **Expected**: exit 0; `CLAUDE.md` igual byte a byte; demais gravados; stdout tem
   `mantido (semente): CLAUDE.md`; manifesto sem entrada `CLAUDE.md`.

## 3. `--forcar` não toca semente (US1-3)

1. Repo do cenário 2 com config diferente + `--forcar`
2. **Expected**: exit 0; `CLAUDE.md` intacto; não semente re-renderizado.

## 4. Conflito de não semente continua recusando, sem citar semente (US1-4) — error case

1. Semente existente + `.cockpit/LEIAME.md` editado → configurar com config diferente
2. **Expected**: exit 2; stderr cita `.cockpit/LEIAME.md` e não cita `CLAUDE.md`.

## 5. `--atualizar` após editar a constituição (US2-1)

1. Projeto configurado; anexar linha em `docs/constitution.md` → `--atualizar`
2. **Expected**: exit 0; arquivo intacto; entrada do manifesto igual à anterior (FR-006).

## 6. Colisão `X.tmpl` x `X.semente.tmpl` (FR-005) — error case

1. `cockpit_copia`; criar `templates/CLAUDE.md.tmpl` ao lado de `CLAUDE.md.semente.tmpl`
2. **Expected**: exit 1; stderr `Templates com o mesmo destino`.

## 7. Residual só conta se a semente for gravada (FR-004)

1. `cockpit_copia`; semente nova com `{{CHAVE_INEXISTENTE}}`; destino já existe → exit 0
2. Mesmo template, destino ausente → **Expected**: exit 2, `Placeholder sem valor`.

## 8. Destino diretório / link quebrado (edge case)

1. `CLAUDE.md` como diretório; depois como link quebrado
2. **Expected**: exit 0 nos dois; nada alterado.

## 9. Idempotência

Coberta pelos cenários 2/3/15 existentes (segunda execução não altera nada), que continuam
verdes com os três templates renomeados.
