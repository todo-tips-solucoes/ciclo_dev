# Implementation Plan: auditoria de merge vermelho sem falsos achados

**Feature**: `audit-merge-vermelho` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

## Summary

Duas trocas no único passo de `templates/.github/workflows/audit-merge-vermelho.yml.tmpl`,
dentro das decisões normativas D1 e D2 de [decisoes-do-owner.md](decisoes-do-owner.md):

1. **D1**: o nome da branch base passa por uma função bash de percent-encoding (bytes fora de
   `A-Z a-z 0-9 - . _ ~` viram `%XX` maiúsculo, RFC 3986) antes de entrar em
   `repos/$REPO/rules/branches/<base>` (research Decision 1).
2. **D2**: a checagem de duplicada troca `gh issue list --search` (índice de busca) por
   `gh api "repos/$REPO/issues?state=all&per_page=100" --paginate`, com o filtro `--jq`
   descartando PRs e comparando o título exato (Decision 2). A checagem sai do começo do passo e
   vai para logo antes do `gh issue create`: o resultado é o mesmo, mas a varredura de todas as
   páginas só acontece quando há o que auditar (Decision 3).

Teste: cenário 24 de `scripts/testar-configurar.sh`, antes do cenário 11, no padrão do cenário
16, com `gh` falso que aplica o filtro `--jq` real com `jq` sobre fixtures (Decision 4,
[quickstart.md](quickstart.md)).

## Technical Context

**Language/Version**: bash embutido em `run:` de GitHub Actions (`set -euo pipefail`, já no
passo); suíte de teste em bash.
**Primary Dependencies**: `gh` (já usado pelo passo, pré-instalado nos runners — research F13 de
`templates-automacao`); nenhuma nova no template. Teste: `jq`, pré-requisito permitido pelo
Princípio VII (research F7).
**Storage**: N/A.
**Testing**: `scripts/testar-configurar.sh` (cenário 24 novo; cenários 16 e 11 já cobrem
actionlint/shellcheck); job `configurar` do CI.
**Target Platform**: runner `ubuntu-latest` do GitHub Actions (projetos-alvo; `runs-on` do template, research F7); suíte local em
Linux, WSL e macOS (constitution VII).
**Project Type**: template de fluxo de CI renderizado pelo `configurar.sh`.
**Performance Goals**: sem meta numérica. Custo da listagem: uma requisição por página de 100
itens (issues e PRs do repositório), só em merge com check vermelho obrigatório (Decision 3);
volume real não medido.
**Constraints**: sem dependência nova no template (FR-008); actionlint e shellcheck sem findings;
gatilhos, permissões, critério de vermelho e conteúdo da issue inalterados (FR-007); prosa em
português do Brasil.
**Scale/Scope**: 1 template (1 passo) + 1 cenário de teste. Nenhum eixo estrutural em aberto.

## Constitution Check

*GATE: passou antes do Phase 0; re-checado após o Phase 1 (sem mudança).*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | Fixtures e exemplos usam nomes genéricos (`release/2026`, `main`, `minha-org/meu-projeto`); nenhum valor por projeto vira literal. |
| II. Ciclo próprio | PASS | Trilha completa (`templates/`, `scripts/`): worktree com base `main`, `/feature-00c`, `bmad-code-review`, PR e registro em `docs/specs/audit-merge-vermelho/`. |
| III. Identidade de commit | N/A no plano | Conferida no commit, não no desenho. |
| IV. Ferramentas externas | PASS | Nada instalado pelo usuário; o teste segue pulando actionlint/shellcheck ausentes fora do CI, como hoje. |
| V. Fonte oficial | PASS | Rotas, parâmetros e flags citados com link e trecho literal na research, lidos via `ctx_*`; o que não foi medido está marcado como não medido. |
| VI. Português do Brasil | PASS | Mensagens do passo inalteradas; comentários novos em português com acentuação. |
| VII. Scripts portáveis | PASS | `set -euo pipefail` mantido; função bash sem ferramenta nova; `jq` no teste está na lista de pré-requisitos permitidos. |

## Project Structure

### Documentation (this feature)

```
docs/specs/audit-merge-vermelho/
├── decisoes-do-owner.md   # D1/D2 normativas
├── spec.md
├── plan.md                # este arquivo
├── research.md            # fontes oficiais + Decisions 1-4
├── data-model.md
├── quickstart.md          # casos do cenário 24
└── contracts/
    └── github-rest.md     # rotas consultadas pelo passo
```

### Source Code (repository root)

```
templates/.github/workflows/audit-merge-vermelho.yml.tmpl   # único passo alterado
scripts/testar-configurar.sh                                # cenário 24, antes do cenário 11
```

**Structure Decision**: nenhum arquivo novo de código. A função de codificação vive dentro do
próprio `run:` (não há biblioteca de shell compartilhada entre fluxos renderizados; criar uma
seria arquivo novo no projeto-alvo para um uso). O passo continua sendo o último bloco do YAML,
o que mantém a extração por `awk` do cenário 24 igual à do cenário 16.

## Mudanças no passo (desenho, não código)

Ordem final do `run:`:

1. `set -euo pipefail`; `TITULO` exportado (inalterado).
2. Função `codificar` (Decision 1) e `base_rota="$(codificar "$BASE")"`.
3. Coleta de vermelhos: check-runs e status (inalterado).
4. Regras: `gh api "repos/$REPO/rules/branches/$base_rota"` com o mesmo `--jq`, o mesmo
   `2>/dev/null || true` e a mesma nota de fallback (falha real continua virando aviso).
5. Filtro pelos obrigatórios e saída "nada a auditar" (inalterado).
6. Checagem de duplicada (Decision 2 e 3): se a listagem devolver qualquer número, imprime a
   mensagem de hoje ("Já existe issue de auditoria para o PR #$PR.") e sai 0. Falha da listagem
   derruba o passo pelo `set -e`, sem criar issue (FR-010).
7. Corpo e `gh issue create` (inalterados).

Comentário `ponytail:` junto da listagem, nomeando o teto (varre todas as páginas a cada merge
vermelho) e o caminho de evolução (Decision 3).

## Convenções de Borda

Uma borda só: passo de CI → API REST do GitHub.

| Elemento | Convenção | Fonte da verdade |
|----------|-----------|------------------|
| Segmento `{branch}` da rota de regras | percent-encoding de todo byte fora do conjunto não reservado (RFC 3986 §2.3), hexadecimal maiúsculo | research Decision 1, F8 |
| Querystring da listagem de issues | literal fixa `state=all&per_page=100` | research F2, [contracts/github-rest.md](contracts/github-rest.md) |
| Filtro de resposta | `--jq` do `gh`, uma linha por item encontrado (independe de rodar por página ou no total) | research F4, Decision 2 |

## Fora de escopo (registrado)

- Outras rotas com nome de branch em outros templates (`compare/$PRODUCAO...$INTEGRACAO` no
  `promotion-pr`, `branches/<BRANCH_INTEGRACAO>` no rito): issue #10 trata só deste fluxo e não
  há evidência medida de quebra nelas. Candidatas a frente própria se aparecer o defeito.
- Mudança do critério de vermelho, do conteúdo da issue, de gatilhos ou permissões (FR-007).

## Complexity Tracking

Nenhuma violação de constituição.
