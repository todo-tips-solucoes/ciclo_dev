# Contrato: comportamento dos passos alterados

**Feature**: `revisao-lote-21-25` | **Date**: 2026-10-08

Nenhum endpoint, permissão, gatilho ou dependência novos. As chamadas à API são as de hoje,
documentadas nas frentes de origem (`docs/specs/audit-merge-vermelho/contracts/github-rest.md` e
`docs/specs/codeowner-aprovacao-atual/contracts/require-codeowner-approval.md`). Muda o que o passo
faz com o resultado.

## [EXISTENTE, alterado] `audit-merge-vermelho` — leitura das regras da branch base

**Chamada**: `gh api "repos/$REPO/rules/branches/<base codificada>" --jq '<filtro de hoje>'`, stderr
descartado.

| Situação | Conteúdo usado como lista de obrigatórios | Saída do passo |
|----------|-------------------------------------------|----------------|
| exit 0, lista não vazia | a saída | issue só com vermelhos obrigatórios, nota "Lista filtrada pelos checks obrigatórios da branch base."; nenhum obrigatório vermelho → "Nenhum check vermelho obrigatório: nada a auditar.", exit 0 |
| exit 0, saída vazia | nenhum | issue com todos os vermelhos, nota de regra ilegível |
| exit diferente de 0 (qualquer stdout, inclusive corpo de erro — M1) | **nenhum** (arquivo truncado) | issue com todos os vermelhos, nota "Sem regra de checks obrigatórios legível na branch base: todo check vermelho foi listado." |

Listagem de issues (duplicada): sem mudança de chamada; filtro do código
`.[] | select((has("pull_request") | not) and .title == env.TITULO) | .number`.

## [EXISTENTE, alterado] `require-codeowner-approval` — conferência de aprovação

| Situação | Exit | Saída |
|----------|------|-------|
| Sem `.github/CODEOWNERS` na base, ou linha `*` sem dono | 1 | mensagens de hoje |
| Head do PR não lido (`gh` falhou ou valor vazio) | 1 | `::error::Não consegui ler o commit atual do PR; rode o fluxo de novo.` (hoje) |
| Algum dono cujo **último** estado em todas as reviews é `approved` com `commit_id` igual ao head | 0 | `Aprovado por um dono.` |
| Caso contrário | 1 | `::error::Aprovação pendente. Podem aprovar: @a @b` (hoje) |

## [EXISTENTE, alterado] `configurar.sh --atualizar` com `BRANCH_*` fora da regra

| Situação | Exit | stderr |
|----------|------|--------|
| `BRANCH_INTEGRACAO` ou `BRANCH_PRODUCAO` recusada no `--atualizar` | 1 | linha de hoje ("Valor inválido para <CHAVE>: … <conjunto>"), linha nova nomeando a chave e dizendo que, se o valor é o nome real da branch, a saída é renomear a branch no remoto para um nome dentro do conjunto e atualizar a chave, e a linha de hoje "Corrija o valor no cockpit.config …"; nenhum arquivo alterado |
| Mesma recusa com `--respostas` ou no interativo | 1 / pergunta de novo | sem a linha nova (D6 fala só do `--atualizar`) |

Texto final das mensagens: na implementação, em português do Brasil com acentuação, sem repetir o
valor recusado.
