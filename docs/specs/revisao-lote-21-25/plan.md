# Implementation Plan: correções do code review retroativo do lote 21-25

**Feature**: `revisao-lote-21-25` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D7, fatos medidos, fora de
escopo e restrições, normativas) | **Origem**: `bmad-code-review` retroativo sobre `09f7cb0..04c66fd`

## Summary

Correções pontuais em arquivos que já existem, sem arquivo, função, chamada à API, permissão ou
dependência novos:

1. `audit-merge-vermelho`: chamada das regras que falha trunca a lista (`|| : >"$obrigatorios"`) e
   o passo lista todos os vermelhos com a nota de regra ilegível (D1; research Decision 1).
2. `require-codeowner-approval`: o `awk` guarda o último estado e o commit de cada usuário em todas
   as reviews e só então exige `approved` no head (D2; Decision 2).
3. `rito-dev`: tira as aspas antes de conferir e confere também `REPO_REMOTO` com a `RE_REPO`
   (D3, D4; Decision 3). `parallel-work`: confere as duas branches antes do `--base` (D5;
   Decision 4).
4. `configurar.sh --atualizar` com `BRANCH_*` recusada ganha a dica de renomear a branch no remoto
   (D6; Decision 5). Textos dos modelos, comentário `ponytail:`, contrato e research das frentes de
   origem corrigidos (D6; Decision 6).
5. Casos novos nos cenários 21 a 24 de `scripts/testar-configurar.sh` (D7; Decisions 7 e 8), e
   `export LC_ALL=C` nos scripts alterados (FR-011; Decision 9).

## Technical Context

**Language/Version**: bash com `set -euo pipefail` (passos `run:` dos fluxos, `configurar.sh`,
`scripts/testar-configurar.sh`); Markdown nas skills e registros
**Primary Dependencies**: nenhuma nova: `gh` (com `--jq`), `awk`, `grep`, `sort` nos fluxos; `git`
no `configurar.sh`; `jq` e `script(1)` no teste, como hoje (Princípio VII)
**Storage**: N/A (fluxos sem estado; `.cockpit/manifesto.sha256` sem mudança de regra)
**Testing**: `scripts/testar-configurar.sh`, cenários 21 a 24 estendidos; 16 (actionlint sobre os
fluxos renderizados) e 11 (shellcheck, `verificar-agnostico.sh`) seguem valendo; CI em
`.github/workflows/ci.yml` com `COCKPIT_EXIGIR_FERRAMENTAS=1`
**Target Platform**: runner `ubuntu-latest` para os fluxos gerados (fonte: `runs-on` dos modelos, sem mudança); Linux, WSL e macOS para os scripts (fonte: constitution, Princípio VII)
**Project Type**: modelos de automação + configurador + script de testes + texto de skills
**Performance Goals**: N/A
**Constraints**: shellcheck e actionlint sem findings; `LC_ALL=C`; prosa em pt-BR com acentuação;
nada que nomeie projeto real; afirmação sobre API só com fonte oficial ou medição registrada
(Princípios I, V, VI, VII; decisoes, "Restrições")
**Scale/Scope**: 11 arquivos alterados mais o registro desta frente (Project Structure); nada do
"Fora de escopo" de `decisoes-do-owner.md`

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checado após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo verificável | PASS | exemplos com `minha-org/meu-projeto`, `Maria-Exemplo`, `org/repo`; nenhum literal novo que varie por projeto; `verificar-agnostico.sh` no cenário 11 |
| II. Ciclo próprio | PASS | worktree `fix/revisao-lote-21-25`, `/feature-00c`, registro SDD e ajustes de D6 na mesma PR; `bmad-code-review` sobre o diff antes da PR |
| III. Identidade de commit | N/A nesta etapa | conferida no commit, não no plano |
| IV. Ferramentas externas | PASS | nenhuma instalação, cópia de terceiro ou bootstrap |
| V. Fonte oficial antes de afirmar | PASS | toda afirmação de API/`gh` cita M1-M3 (medidos) ou F1-F4 (oficiais, com link); o que não foi medido segue "não medido" (M3) |
| VI. Português do Brasil | PASS | textos novos em pt-BR com acentuação; nomes das opções nativas do GitHub ficam literais, como no código |
| VII. Scripts portáveis, idempotentes, contidos | PASS | sem pré-requisito novo; `configurar.sh` continua escrevendo só no projeto-alvo; `LC_ALL=C` nos scripts alterados (S1: suíte verde com `C`) |

## Project Structure

### Documentation (this feature)

```
docs/specs/revisao-lote-21-25/
├── decisoes-do-owner.md   # normativo (owner, 2026-10-08)
├── spec.md
├── plan.md                # este arquivo
├── research.md            # Decisions 1-9, fontes M1-M3, F1-F4, S1
├── data-model.md          # review, regra de obrigatórios, valor do cockpit.config, manifesto
├── quickstart.md          # casos novos dos cenários 21-24 e leituras das skills
└── contracts/
    └── passos.md          # comportamento dos três passos alterados
```

### Source Code (repository root)

```
templates/.github/workflows/
├── audit-merge-vermelho.yml.tmpl        # l.31 LC_ALL; l.50-51 `|| : >"$obrigatorios"`; l.69 ponytail
└── require-codeowner-approval.yml.tmpl  # l.1-6 cabeçalho; l.31 LC_ALL; l.52 awk
templates/.github/CODEOWNERS.tmpl        # l.3-4 texto da opção nativa
configurar.sh                            # validar_chave, ramo BRANCH_* (l.293-298): dica no --atualizar
scripts/testar-configurar.sh             # LC_ALL; cenários 21 (l.922-993), 23 (l.995-1036), 24 (l.1038-1100), 22 (l.1115-1159)
skills/rito-dev/SKILL.md                 # l.20-23 aspas + REPO_REMOTO; l.53-54 frase das aspas sai
skills/parallel-work/SKILL.md            # l.43-49 conferência antes do --base
docs/specs/audit-merge-vermelho/
├── research.md                          # Decision 1: M1, M3, correção
└── contracts/github-rest.md             # l.34-36 erro das regras; l.62 filtro do código
docs/specs/promotion-pr-arvores/research.md  # Decision 4: M1; limite conhecido: M2
docs/specs/revisao-lote-21-25/spec.md    # US6 cenário 2 alinhado (research Decision 8)
```

**Structure Decision**: só arquivos existentes; a ordem natural de implementação é código e teste
de cada achado juntos (D1 + cenário 24; D2 + cenário 22; D6 do `configurar.sh` + cenário 21),
depois textos das skills e dos modelos, depois os registros das frentes de origem.

## Convenções de Borda

N/A — sem borda entre camadas com convenção de nomes: os passos leem campos da API do GitHub já
usados hoje (`state`, `commit_id`, `user.login`, `head.sha`, `pull_request`, `title`) e as skills
leem chaves do `cockpit.config` com as regras de `configurar.sh`.

## Riscos

- **Ordem das reviews**: a regra depende da ordem cronológica documentada (F1) e da paginação em
  sequência (F3); não há medição própria nesta frente.
- **Nome cru em `rules/branches`**: continua não medido se casa as regras de uma branch com `/` que
  as tem (M3); a codificação de hoje fica.
- **Leitura das skills**: US3 e US4 não têm teste automático; a revisão do diff confere a ordem
  "tirar aspas → conferir → compor".

## Complexity Tracking

Sem violações.
