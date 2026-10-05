# Implementation Plan: destinos do projeto no configurar.sh

**Feature**: `destinos-do-projeto` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1, D2, D3, normativas)

## Summary

Chave opcional `DESTINOS_DO_PROJETO` no `cockpit.config`: destino listado é pulado como semente
existente (sem render, sem conflito, sem prompt, manifesto anterior mantido) e reportado como
`mantido (projeto)`. A recusa do lote por edição local fica; só a mensagem sugere a chave. Numa
worktree vinculada, destino ausente de semente ou listado, ignorado pelo git, é copiado da árvore
principal (arquivo regular, fora do manifesto) ou, sem origem válida, não é gerado. Tudo em
`configurar.sh`, reusando a decisão única por execução da modo-semente: `PULAR[i]` passa de 0/1
a motivo, e `marcar_sementes` vira `classificar_destinos`.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` e `LC_ALL=C` (script existente, Princípio VII)
**Primary Dependencies**: nenhuma nova: `git` (já exigido: `resolver_raiz`, `template_executavel`),
coreutils já usados, `cp`
**Storage**: `cockpit.config` (chave nova) e `.cockpit/manifesto.sha256` (sem mudança de formato)
**Testing**: `scripts/testar-configurar.sh` (cenários 18 e 19 novos; 14 e 15 ajustados) +
shellcheck e `verificar-agnostico.sh` (cenário 11)
**Target Platform**: Linux, WSL, macOS (fonte: constitution, Princípio VII)
**Project Type**: cli (script local)
**Performance Goals**: N/A
**Constraints**: escreve só dentro de `$RAIZ`; a árvore principal só é lida; idempotente;
sem a chave e fora de worktree, saída e efeitos byte a byte iguais aos de hoje
**Scale/Scope**: `configurar.sh` (8 funções alteradas, 1 renomeada entre elas, 2 novas), `cockpit.config.example`,
2 cenários novos e 2 ajustados, 2 documentos da feature `configurar`

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | valor que varia por projeto vira chave do config (D1); exemplo só com caminhos de template do próprio cockpit; cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | branch `feat/destinos-do-projeto` em worktree, via `/feature-00c`; registro SDD neste diretório |
| III. Identidade de commit | N/A | o script não commita; os commits do cenário 19 são de repositório temporário de teste, com `-c user.*` explícito |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova; `cstk` intocado |
| V. Fonte oficial antes de afirmar | PASS | comportamento de `rev-parse`, `check-ignore` e `worktree list --porcelain` citado do manual oficial do git, com link e sonda ([research](research.md), Decisions 6 a 8); sem número inventado |
| VI. Português do Brasil | PASS | mensagens novas em pt-BR acentuado ([contrato](contracts/cli.md)) |
| VII. Portáveis, idempotentes, contidos | PASS | bash `set -euo pipefail`, `LC_ALL=C` já no topo; toda escrita nova (cópia) passa por `exigir_contido` e staging em `$STG` dentro de `$RAIZ`; 2ª execução mantém a cópia; edição local nunca é sobrescrita sem `--forcar` (listado nem com ele); nenhum pré-requisito novo |

## Design

Referências de linha: `configurar.sh` no commit `3599598`.

### `configurar.sh`

1. **Constantes e estado** (l.45-47, l.71-72): `DESTINOS_DO_PROJETO` no fim de `CHAVES_ORDEM` e
   em `CHAVES_OPCIONAIS`; comentário "URLs são as únicas opcionais" atualizado. `PULAR=()` passa a
   guardar o motivo (vazio, `semente`, `projeto`, `copia`, `ignorado`); novo `ORIGEM=()`; novas
   globais `VINCULADA` e `PRINCIPAL` ([data-model](data-model.md)). O laço `unset "CFG_$_k"`
   (l.76) cobre a chave nova sem mudança.
2. **`validar_chave`** (l.264): ramo `DESTINOS_DO_PROJETO)` com `read -ra itens <<<"$v"`; recusa
   item só de aspas, absoluto ou com componente `..` (research Decision 2). Controle já é
   recusado no topo da função por `tem_controle`.
3. **`validar_todos`** (l.359): a condição "opcional vazia → `desetar`" passa a aceitar também
   `DESTINOS_DO_PROJETO` só com espaços (research Decision 3).
4. **`perguntar_chave`** (l.432): ramo `DESTINOS_DO_PROJETO)`, texto da Decision 4.
5. **`marcar_sementes` → `classificar_destinos`** (l.592, chamada em l.947): lê os itens, avisa os
   que não casam com `DEST_REL`, chama `arvore_principal` uma vez e preenche `PULAR`/`ORIGEM`
   pela tabela do [data-model](data-model.md) (research Decision 5).
6. **Nova `arvore_principal`**: `VINCULADA` por `rev-parse --git-dir` × `--git-common-dir`
   resolvidos com `pwd -P`; se vinculada, `PRINCIPAL` do primeiro registro de
   `worktree list --porcelain`, recusando `bare` e confirmando pelo `git-dir` da candidata
   (research Decisions 6 e 7).
7. **Nova `origem_valida REL`**: arquivo regular, não link, pai físico igual ao lógico (research
   Decision 9). Só leitura.
8. **`main`** (l.949-952): o laço de `exigir_contido` antes de `STG` passa a cobrir destinos com
   `PULAR` vazio ou `copia`.
9. **`aplicar_templates`** (l.674):
   - laços de render (l.685) e de conflito (l.701): pulam todo `PULAR` não vazio;
   - mensagem de conflito (l.718): acrescenta `ou declare o destino em DESTINOS_DO_PROJETO no
     cockpit.config` ([contrato](contracts/cli.md));
   - laço de gravação (l.725): por motivo, acumula `mantido (semente)`, `mantido (projeto)`,
     `mantido (ignorado pelo git)` ou faz a cópia (`exigir_contido`, `mkdir -p`, `exigir_contido`,
     `cp` para `$STG/c$i`, `mv -f`), com comentário sobre o limite de corrida da research;
   - relatório (l.741-746): linhas novas e sufixos condicionais na ordem do contrato.
10. **`gravar_manifesto`** (l.773): a regra "reemitir a linha anterior" vale para todo `PULAR`
    não vazio.
11. **`uso()` e cabeçalho** (l.10-12, l.103): linha do `--forcar` e parágrafo sobre destinos do
    projeto e worktree.

### Configuração e documentação

- `cockpit.config.example`: seção nova, opcional, `DESTINOS_DO_PROJETO=''`, exemplo de D1 em
  comentário (research Decision 11).
- `docs/specs/configurar/contracts/cli.md`: incorporar o delta de [contracts/cli.md](contracts/cli.md)
  (opção `--forcar`, regra dos destinos, mensagens de referência).
- `docs/specs/configurar/data-model.md`: linha da chave na tabela do `cockpit.config` e regra na
  tabela de validação.
- Templates: nenhum muda; nenhum pode usar `{{DESTINOS_DO_PROJETO}}`.

### Testes (SC-001, SC-003)

- `cenario "18: destinos do projeto"`: casos 1 a 8 do [quickstart](quickstart.md).
- `cenario "19: worktree e destino ignorado"`: casos 9 a 15, com worktree real, `.gitignore`
  commitado cobrindo `CLAUDE.md` e bare criado sem rede (research Decision 10).
- Cenário 14: uma resposta a mais em cada entrada (mínimo 19), pergunta nova conferida (caso 16).
- Cenário 15: a checagem "nenhum template usa chave opcional" passa a incluir
  `DESTINOS_DO_PROJETO`.
- Cenários 1 a 13, 16 e 17 sem alteração e verdes (comportamento atual sem a chave).

## Project Structure

### Documentação (esta feature)

```text
docs/specs/destinos-do-projeto/
├── decisoes-do-owner.md
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/cli.md
```

### Código e documentos tocados

```text
configurar.sh                            # alterado
cockpit.config.example                   # seção DESTINOS_DO_PROJETO
scripts/testar-configurar.sh             # cenários 18 e 19; 14 e 15 ajustados
docs/specs/configurar/contracts/cli.md   # delta incorporado
docs/specs/configurar/data-model.md      # chave nova
```

## Convenções de Borda

N/A — single-layer (script CLI local).

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Saída de projeto sem a chave e fora de worktree mudar | sufixos condicionais; `PULAR` vazio segue o caminho atual; cenários 1 a 17 intactos |
| Lote recusado (exit 2) deixar cópia feita | cópia só no laço de gravação, depois das checagens de residual e conflito |
| Cópia escrever fora do projeto | `exigir_contido` antes e depois do `mkdir -p`, como o render; laço de contenção de `main` inclui `copia` |
| Origem fora da árvore principal (link, caminho truncado, bare) | `origem_valida` (pai físico = lógico, sem link) e confirmação da árvore principal pelo `git-dir` |
| Troca da origem por link entre a checagem e o `cp` | risco aceito e documentado (research, Riscos aceitos) |
| SC-001 da feature `configurar` (18 respostas) | mudança intencional para 19, exigida por FR-007; cenário 14 atualizado |

## Complexity Tracking

Nenhuma violação.
