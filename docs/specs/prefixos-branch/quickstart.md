# Quickstart: prefixos de branch

Cenários de verificação. Os automatizados viram o cenário 20 de `scripts/testar-configurar.sh`
(e ajustes nos cenários 14 e 15); os manuais ficam registrados na PR.

Preparação comum: `T="$(mktemp -d)" && git init -q "$T"`; respostas = `cockpit.config.example`
com a linha `PREFIXOS_BRANCH=` trocada pelo valor do cenário.

## 1. Chave ausente: render byte a byte igual (US2-1, FR-009, SC-001)

1. Copiar o cockpit para um diretório temporário e, na cópia, trocar nos dois templates os cinco
   placeholders pelos literais `feature`, `fix`, `chore`, `docs`, `hotfix`.
2. Renderizar o cockpit real e a cópia com `PREFIXOS_BRANCH` ausente, em dois projetos.
3. `cmp` de `docs/CICLO-GIT.md` e de `docs/rito-dev.md` entre os dois projetos.
→ **Expected**: os dois pares iguais.

Manual (PR): renderizar com `origin/main` (via `git archive origin/main | tar -x -C <dir>`) e com
a branch, mesmas respostas sem a chave; `diff -r --exclude=.git` dos dois projetos → vazio.

## 2. Chave válida refletida (US1-1, SC-002)

1. Respostas com `PREFIXOS_BRANCH='feat bugfix tarefa doc urgente'`.
2. Rodar `./configurar.sh --projeto "$T" --respostas <arq>`.
→ **Expected**: exit 0; nos dois documentos, `` `feat/<slug>` ``, `` `bugfix/<slug>` ``,
`` `tarefa/<slug>` ``, `` `doc/<slug>` `` e `` `urgente/<slug>` ``; nenhum `` `feature/<slug>` ``,
`` `fix/<slug>` ``, `` `chore/<slug>` ``, `` `docs/<slug>` `` ou `` `hotfix/<slug>` ``.

## 3. Gravação (US1-2, FR-005, FR-007)

Depois do cenário 2 → **Expected**: `cockpit.config` com
`PREFIXOS_BRANCH='feat bugfix tarefa doc urgente'` e nenhuma linha `PREFIXO_`.

## 4. Só espaços = ausente (Edge Case)

Respostas com `PREFIXOS_BRANCH='   '` → **Expected**: exit 0, documentos com o padrão, chave não
gravada.

## 5. Valores inválidos (US3, FR-002 a FR-004, SC-003)

Para cada valor — `'a b c d'`, `'a b c d e f'`, `'feat fix/x chore docs hotfix'`,
`'feat<TAB>fix chore docs hotfix'`, `'feat fix chore docs a..b'`,
`'-x fix chore docs hotfix'`, `'feat fix chore docs fix'` — num projeto novo:
→ **Expected**: exit 1, stderr cita `PREFIXOS_BRANCH`, nenhum `cockpit.config` criado.

## 6. Projeto já configurado, `--atualizar` (US2-2, FR-006, SC-004)

1. Configurar com as respostas sem a linha `PREFIXOS_BRANCH`.
2. `./configurar.sh --projeto "$T" --atualizar </dev/null`.
→ **Expected**: exit 0, stderr sem `PREFIXOS_BRANCH`, documentos inalterados.

## 7. Modo interativo (US4-1, FR-005) — cenário 14 e cenário 20

1. Entrada mínima de 20 respostas (a 20ª é `-`) → **Expected**: exit 0, chave não gravada; com
   19 respostas a configuração não conclui.
2. Pergunta exibida com `(padrão: feature fix chore docs hotfix) (- para vazio)`.
3. Responder `a b` e depois `feat fix chore docs hotfix` → **Expected**: mensagem citando a chave,
   a pergunta se repete, e o segundo valor é gravado.

## 8. Regra do cenário 15 (FR-008)

`grep -rq 'PREFIXOS_BRANCH' templates/` → **Expected**: nenhuma ocorrência; o render do exemplo
não deixa `{{` residual.

## 9. Skill `rito-dev` (US4-3, FR-010) — manual

`grep -n 'PREFIXOS_BRANCH' skills/rito-dev/SKILL.md` → **Expected**: linha na tabela de chaves
consumidas (opcional, Fase 1) e menção na Fase 1 com o padrão `feature fix chore docs hotfix`;
nenhum `` `feature/<slug>` `` literal na Fase 1.

## 10. Qualidade estática (US4-2, FR-013)

`shellcheck -x configurar.sh scripts/testar-configurar.sh` sem findings e
`./scripts/verificar-agnostico.sh` limpo (cenário 11); suíte inteira passa (SC-005).
