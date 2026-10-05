# Quickstart: destinos do projeto

Cenários a automatizar em `scripts/testar-configurar.sh` (SC-001), com os helpers existentes
(`novo_repo`, `cockpit_copia`, `codigo`, `rodar`), como `cenario "18: destinos do projeto"`
(casos 1 a 8) e `cenario "19: worktree e destino ignorado"` (casos 9 a 15). O caso 16 é ajuste
do cenário 14 (pty). Configs de teste: `cockpit.config.example` com `PROJETO_NOME` trocado e uma
linha `DESTINOS_DO_PROJETO='…'` acrescentada.

## 1. Destino editado e listado fica intacto (US1-1, SC-002)

1. Repo configurado com o exemplo → editar `.github/workflows/ci.yml` → guardar cópia e a linha
   dele no manifesto
2. Rodar com `PROJETO_NOME` trocado e `DESTINOS_DO_PROJETO='.github/workflows/ci.yml'`
3. **Expected**: exit 0; `ci.yml` igual byte a byte à cópia; stdout tem
   `  mantido (projeto): .github/workflows/ci.yml` e `1 mantido(s) (projeto)`; `.cockpit/LEIAME.md`
   re-renderizado; linha de `ci.yml` no manifesto igual à anterior (US1-3).

## 2. `--forcar` e `--atualizar` não tocam o listado (US1-2)

1. Repo do caso 1 → rodar com `--forcar`; depois `--atualizar`
2. **Expected**: exit 0 nas duas; `ci.yml` igual à cópia.

## 3. Semente listada e ausente não é gerada (US1-4, FR-005)

1. Repo novo → rodar com `DESTINOS_DO_PROJETO='CLAUDE.md'`
2. **Expected**: exit 0; `CLAUDE.md` não existe; stdout `  mantido (projeto): CLAUDE.md`; demais
   sementes gravadas.

## 4. Conflito fora da lista recusa o lote e sugere a chave (US1-5, D2)

1. Repo do caso 1 → editar também `.cockpit/LEIAME.md` (não listado) → rodar com `PROJETO_NOME`
   trocado
2. **Expected**: exit 2; stderr cita `.cockpit/LEIAME.md`, `--forcar` e `DESTINOS_DO_PROJETO`;
   não cita `ci.yml`; nenhum template alterado (o `cockpit.config` é gravado, contrato do exit 2).

## 5. Item inválido: exit 1 antes de qualquer escrita (US2-1)

1. Para cada valor: `'/etc/x'`, `'docs/../x'`, `'ci.yml "" b'` e um valor com TAB, num repo novo
2. **Expected**: exit 1; stderr cita `DESTINOS_DO_PROJETO`; `cockpit.config` não foi criado.

## 6. Item sem template: aviso, não erro (US2-2)

1. Repo novo → `DESTINOS_DO_PROJETO='nao/existe.md'`
2. **Expected**: exit 0; stderr tem `Aviso:` citando `nao/existe.md`.

## 7. Chave ausente ou em branco = comportamento atual (US3-1)

1. Repo novo com o exemplo puro; outro com `DESTINOS_DO_PROJETO='   '`
2. **Expected**: exit 0 nos dois; `diff -r --exclude=.git` entre os dois vazio (o
   `cockpit.config` não tem linha `DESTINOS_DO_PROJETO`); stdout sem `(projeto)`.

## 8. Idempotência com destino listado

1. Repo do caso 1 → rodar duas vezes a mesma config
2. **Expected**: a 2ª não altera nenhum arquivo (`diff -r --exclude=.git` com cópia anterior).

## 9. Worktree recebe o arquivo ignorado da árvore principal (US4-1, FR-009)

1. Repo principal `M`: `.gitignore` com `CLAUDE.md` commitado (commit com
   `git -c user.name=… -c user.email=… -c commit.gpgsign=false`); `M/CLAUDE.md` com conteúdo
   próprio; `git -C M worktree add <W> -b w`
2. Configurar `W` com o exemplo
3. **Expected**: exit 0; `W/CLAUDE.md` é arquivo regular (`-f` e `! -L`) e `cmp` igual a
   `M/CLAUDE.md`; stdout `  copiado da árvore principal: CLAUDE.md`; manifesto sem `CLAUDE.md`;
   `docs/constitution.md` (não ignorada) renderizada normalmente (FR-011); `M/CLAUDE.md` e
   `git -C M status --porcelain --ignored` iguais aos de antes (FR-012).

## 10. Segunda passagem mantém a cópia (Edge Case)

1. Rodar de novo em `W`
2. **Expected**: exit 0; `W/CLAUDE.md` igual; stdout `  mantido (semente): CLAUDE.md`.

## 11. Sem o arquivo na árvore principal (US4-2, FR-010)

1. Remover `M/CLAUDE.md` → nova worktree `W2` → configurar
2. **Expected**: exit 0; `W2/CLAUDE.md` não existe; stdout
   `  mantido (ignorado pelo git): CLAUDE.md (esperado em <M físico>/CLAUDE.md)`.

## 12. Origem que é link é recusada (Edge Case)

1. `M/CLAUDE.md` link para um arquivo regular → nova worktree → configurar
2. **Expected**: exit 0; destino não criado; stderr `Aviso:` com `link simbólico`; stdout
   `mantido (ignorado pelo git): CLAUDE.md`.
3. Variação com componente: `cockpit_copia` com `templates/sub/x.md.semente.tmpl`, `.gitignore`
   com `sub/`, `M/sub` link para diretório com `x.md` → **Expected**: `sub/x.md` não criado.

## 13. Destino listado e ignorado também é copiado (D3 sobre D1)

1. `.gitignore` de `M` cobre `docs/rito-dev.md`; `M/docs/rito-dev.md` existe; worktree com
   `DESTINOS_DO_PROJETO='docs/rito-dev.md'`
2. **Expected**: cópia regular igual à de `M`; stdout `copiado da árvore principal: docs/rito-dev.md`;
   pai `docs/` criado se faltava.

## 14. Repositório principal bare (US4-4)

1. `git init --bare B.git`; `git -C M push <B>.git HEAD:refs/heads/main`; `git -C B.git worktree add <WB> -b wb main` (equivalente a `git clone --bare M B.git` seguido do `worktree add`; sem `cp -R` e sem `core.bare`)
2. Configurar `WB`
3. **Expected**: exit 0; `WB/CLAUDE.md` não existe; stderr `Aviso:` com `repositório bare`; stdout
   `mantido (ignorado pelo git): CLAUDE.md (árvore principal indisponível)`.

## 15. Checkout comum não muda (US4-3, FR-011)

1. Configurar o próprio `M` (árvore principal) com `CLAUDE.md` ausente e ignorado
2. **Expected**: exit 0; `CLAUDE.md` renderizado da semente e no manifesto.

## 16. Pergunta interativa (US3-2, FR-007) — ajuste do cenário 14

1. Entradas do cenário 14 ganham uma resposta (a configuração mínima passa de 18 para 19; a de
   18 respostas deixa de concluir); config incompleto responde também a chave nova
2. Uma rodada responde `CLAUDE.md` na pergunta nova
3. **Expected**: o tty mostra `Destinos mantidos pelo projeto` com `(- para vazio)`;
   `cockpit.config` tem `DESTINOS_DO_PROJETO='CLAUDE.md'`; com `-`, a linha não existe.
