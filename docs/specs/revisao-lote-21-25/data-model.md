# Data Model: correções do code review retroativo do lote 21-25

**Feature**: `revisao-lote-21-25` | **Date**: 2026-10-08

Sem armazenamento: as entidades são dados lidos em tempo de execução (API do GitHub, via `gh`) ou
de `cockpit.config`. Fontes: [research.md](research.md).

## Entity: Review de PR

Linha projetada pelo `--jq` do passo "Conferir aprovação de dono" (sem mudança no `--jq`).

| Campo | Origem | Regra |
|-------|--------|-------|
| login | `.user.login` | comparado em minúsculas |
| estado | `.state` | `commented` e `pending` são descartados no `--jq`; os demais (`approved`, `changes_requested`, `dismissed`) entram |
| commit | `.commit_id // ""` | nulo vira vazio (F1) |
| ordem | posição na lista | cronológica (F1); páginas em sequência (F3) |

**Regra de aprovação (D2, substitui a da PR #25)**: para cada login, vale a **última** linha
(estado e commit da mesma review). O login conta como aprovação quando o estado é `approved` e o
commit é igual ao head atual do PR. O check passa quando algum login que conta está entre os donos
da linha `*` do `CODEOWNERS` da base.

**State transitions** (último estado por login):

| Sequência de reviews do login | Conta? |
|-------------------------------|--------|
| `approved@head` | sim |
| `approved@antigo` | não |
| `approved@head` → `changes_requested@antigo` | não (corrige a regressão) |
| `approved@antigo` → `approved@head` | sim |
| `approved@head` → `dismissed@head` | não |
| `approved@<nulo>` | não |

## Entity: Regra de checks obrigatórios

| Campo | Origem | Regra |
|-------|--------|-------|
| contexts | `rules/branches/<base codificada>`, `--jq` de hoje | um nome por linha |
| legível | código de saída da chamada | 0 → saída usada; diferente de 0 → saída descartada (arquivo truncado), mesmo com corpo no stdout (M1) |

**Regra (D1)**: lista vazia ou chamada que falhou → todos os vermelhos listados, nota "Sem regra de
checks obrigatórios legível na branch base: todo check vermelho foi listado."; lista não vazia →
só os vermelhos obrigatórios, nota "Lista filtrada pelos checks obrigatórios da branch base.".

## Entity: Valor do `cockpit.config` lido por skill

| Chave | Regra (após tirar o par de aspas simples envolvente) | Fonte da regra |
|-------|-------------------------------------------------------|----------------|
| `REPO_REMOTO` | `^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$`, nenhuma parte igual a `.` ou `..` | `configurar.sh` l.64 e l.289-291 |
| `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO` | `^[A-Za-z0-9][A-Za-z0-9._/-]*$` | `configurar.sh` l.67 |

Ordem obrigatória: ler → tirar aspas → conferir → só então compor comando. Fora da regra: PARAR
nomeando a chave, sem colar o valor num comando. A `rito-dev` confere as três chaves; a
`parallel-work` confere as duas de branch.

## Entity: Manifesto (`.cockpit/manifesto.sha256`)

Sem mudança de regra (research Decision 8). Para referência dos testes:

| Manifesto anterior | Linhas a registrar | Resultado |
|--------------------|--------------------|-----------|
| não existe | nenhuma | nada gravado, `.cockpit/` não criado (cenário 21, caso 5) |
| existe | alguma | regravado com as linhas (cenário 21, caso 6) |
| existe | nenhuma | continua existindo, regravado sem linhas (cenário 21, caso novo) |
