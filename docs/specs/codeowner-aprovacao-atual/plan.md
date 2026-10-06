# Implementation Plan: aprovação de dono sobre o commit atual

**Feature**: `codeowner-aprovacao-atual` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1, D2, fora de escopo e
restrições, normativas) | **Origem**: issue #9

## Summary

O passo "Conferir aprovação de dono" de `require-codeowner-approval.yml` passa a contar só reviews
cujo `commit_id` é o commit head atual do PR, lido em tempo de execução por REST "Get a pull
request" (`head.sha`), com a permissão `pull-requests: read` que o fluxo já tem. Entre essas
reviews vale o último estado de cada usuário, como hoje. Head não lido → falha, nunca aprovação.
Os cabeçalhos do fluxo e do `CODEOWNERS` citam a opção nativa "Dismiss stale pull request
approvals when new commits are pushed" ao lado de "Require review from Code Owners"
([research](research.md), F1). O cenário 22 do `testar-configurar.sh` executa o passo renderizado
com `gh` falso. Mudança: uma chamada à API, uma coluna a mais no `--jq`, uma condição no `awk`,
comentários e um cenário de teste.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` (passo `run:` do fluxo; script de testes)
**Primary Dependencies**: nenhuma nova: `gh` (com `--jq`, como hoje) e `awk` no fluxo; `jq` no
teste, já pré-requisito do cockpit (Princípio VII; `instalar.sh`, `checar_prerequisitos`)
**Storage**: N/A (fluxo sem estado)
**Testing**: `scripts/testar-configurar.sh`, cenário 22 novo; cenários 16 (actionlint, `${{ }}`
intactos) e 11 (shellcheck, `verificar-agnostico.sh`) seguem valendo
**Target Platform**: runner `ubuntu-latest` do GitHub Actions (fluxo, sem mudança; fonte:
`runs-on` do template, l.20); Linux, WSL e macOS para o script de testes (fonte: constitution,
Princípio VII)
**Project Type**: templates de automação + script de testes
**Performance Goals**: N/A (uma chamada REST a mais por execução do check)
**Constraints**: `on:` e `permissions:` inalterados; mensagens e exit codes existentes
inalterados (FR-006); verificação extra, não garantia (FR-008, dec-025 de `templates-automacao`);
prosa em pt-BR acentuado; nada que nomeie projeto real
**Scale/Scope**: 2 templates (`require-codeowner-approval.yml.tmpl`, `CODEOWNERS.tmpl`), 1 cenário
novo no script de testes, 1 linha de delta no contrato de `templates-automacao`

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | fixtures com nomes fictícios do exemplo (`@maria-exemplo`, `org-exemplo`); cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | branch `fix/codeowner-aprovacao-atual` em worktree, via `/feature-00c`; registro SDD neste diretório |
| III. Identidade de commit | N/A | nada aqui commita |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova; `gh`, `awk` e `jq` já usados |
| V. Fonte oficial antes de afirmar | PASS | nome da opção, `commit_id`, `head.sha` e permissão citados de páginas oficiais lidas com `context-mode` ([research](research.md), F1 a F7); lacunas marcadas "não medido" |
| VI. Português do Brasil | PASS | comentários e mensagens em pt-BR; nomes de opções da interface do GitHub em inglês, entre aspas, como já é feito |
| VII. Portáveis, idempotentes, contidos | PASS | sem pré-requisito fora da lista (`jq` está nela); cenário 22 escreve só no `$TMP` do script; render e `--atualizar` seguem idempotentes (cenário 16) |

**Re-check pós-design**: PASS. O design não cria arquivo novo no projeto-alvo, nem permissão,
gatilho ou dependência; reusa o pipeline `gh --jq | awk | grep` existente e o padrão de teste do
cenário 16. Sem violação a justificar.

## Design

Referências de linha: commit `09f7cb0`.

### `templates/.github/workflows/require-codeowner-approval.yml.tmpl`

1. **Cabeçalho** (l.1-4, FR-007, FR-008): mantém "verificação EXTRA", "forjável" e "A garantia
   real é a regra nativa da branch"; a frase da garantia cita "Require review from Code Owners" e
   "Dismiss stale pull request approvals when new commits are pushed"; uma linha diz que só conta
   aprovação feita sobre o commit atual (head) do PR.
2. **Head do PR** (novo, entre l.41 e l.42, FR-005): `head` lido com
   `gh api "repos/$REPO/pulls/$PR" --jq .head.sha`; chamada com falha ou valor vazio →
   `::error::` acionável e `exit 1`. Fica depois das checagens de CODEOWNERS, para que os casos
   de l.31-41 saiam como hoje (FR-006) ([research](research.md), Decision 2).
3. **Filtro das reviews** (l.43-45, FR-001 a FR-004): a projeção do `--jq` vira
   `[.user.login, .state, (.commit_id // "")] | @tsv`; o `awk` recebe `-v head="$head"` e só
   atualiza `u[...]` quando `$3 == head`. O resto (descartar `commented`/`pending`, minúsculas,
   último estado, `grep -Fxqf`, mensagens) não muda (Decision 3).

`on:`, `permissions:`, `env:` e o número de `${{ }}` não mudam.

### `templates/.github/CODEOWNERS.tmpl` (FR-007)

- l.3: a linha da regra da branch cita "Require review from Code Owners" e "Dismiss stale pull
  request approvals when new commits are pushed". l.1, l.2 e a linha `*` não mudam.

### `scripts/testar-configurar.sh` (FR-009, SC-001)

- Cenário 22 "aprovação de dono no commit atual", depois do 20 e antes do 11, com os casos do
  [quickstart](quickstart.md) 1 a 4 e 6: render com o exemplo, extração do passo pelo `awk` do
  cenário 16, `gh` falso em `$TMP` que serve CODEOWNERS, head e reviews (reviews pelo `jq -r` com
  o programa recebido em `--jq`). Sem `jq`: pulado com aviso; no CI, falha.
- Conflito de rebase com frentes paralelas no mesmo ponto: mantém os dois blocos (restrição do
  owner).

### Documentação

- `docs/specs/templates-automacao/contracts/automacao.md` §require-codeowner-approval: uma linha de
  delta apontando para o [contrato desta feature](contracts/require-codeowner-approval.md), porque
  "passa se o último review de algum dono [...] tem state aprovado" deixa de ser a regra completa.

## Project Structure

### Documentação (esta feature)

```text
docs/specs/codeowner-aprovacao-atual/
├── decisoes-do-owner.md   # D1, D2 (normativas)
├── spec.md
├── plan.md                # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── require-codeowner-approval.md
```

### Código e documentos tocados

```text
templates/.github/workflows/require-codeowner-approval.yml.tmpl
templates/.github/CODEOWNERS.tmpl
scripts/testar-configurar.sh
docs/specs/templates-automacao/contracts/automacao.md
```

## Convenções de Borda

N/A — single-layer (passo de fluxo que só lê a API e devolve exit code).

## Gate de segurança

Revisão OWASP do desenho (A05 injeção, A10 falha fechada, CICD-SEC-2 permissões, CICD-SEC-4
pipeline envenenado): 0 crítico, 0 alto, 0 médio. Permissões e gatilhos não mudam; nenhum dado
lido da API vira código (head por `awk -v`, programa `--jq` fixo); nenhuma ação ou dependência
nova.

| Achado | Severidade | Disposição |
|---|---|---|
| S1 — sem a guarda de head vazio, `commit_id` nulo (coluna vazia) igualaria head vazio e aprovaria | baixo (coberto no desenho) | guarda obrigatória antes das reviews (Design, item 2) e caso 4 do [quickstart](quickstart.md) |
| S2 — formato do head não é validado (por exemplo, `null` literal se o campo faltar) | baixo | aceito: qualquer valor que não seja o SHA de uma review falha fechado; o campo é obrigatório no schema (F5) |
| S3 — push entre a leitura do head e a das reviews | baixo | aceito: o check vale para o head lido; o evento do push novo roda o check de novo |
| S4 — check forjável por conteúdo do PR | info (preexistente) | aceito desde dec-025 de `templates-automacao`; a garantia é a regra nativa (FR-008) |

## Riscos

- O check segue forjável por conteúdo do PR (F14 de `templates-automacao`): a mudança só torna a
  verificação extra mais fiel; a garantia continua sendo a regra nativa (FR-008).
- Head lido em tempo de execução: se houver push entre o evento e a execução, o check avalia o
  head novo e fica pendente até nova review de dono, que é o comportamento de D1.
- O check é mais estrito que a opção nativa: commit novo sem mudança de diff também invalida a
  aprovação (F3, Decision 1, nota). Consequência de D1, aceita.
- Presença do `jq` no `ubuntu-latest`: não medida; o CI da PR responde.

## Complexity Tracking

Nenhuma violação de constitution a justificar.
