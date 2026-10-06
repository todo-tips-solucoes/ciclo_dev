# Data Model: audit-merge-vermelho

**Feature**: `audit-merge-vermelho` | **Date**: 2026-10-06

Sem persistência própria: o passo do fluxo lê dados da API do GitHub e, no máximo, cria uma
issue. As entidades abaixo são as que o passo consulta; nenhum campo novo é criado.

## Entity: Issue de auditoria

Registro por PR mergeado com check vermelho obrigatório. Inalterada por esta frente (FR-007).

| Campo | Origem | Uso no passo |
|-------|--------|--------------|
| `title` | gerado pelo passo: `Auditoria: PR #<número> mergeado com check vermelho` | chave de duplicidade: igualdade exata de string |
| `state` | GitHub (`open`/`closed`) | não filtra: qualquer estado conta (FR-005) |
| `pull_request` | GitHub, presente só em itens que são PR | item com a chave é descartado (a listagem de issues da REST também devolve PRs, research F2) |

**Regra de duplicidade**: existe item da listagem sem `pull_request` e com `title` idêntico →
o passo encerra com exit 0, sem criar issue. Título parecido (outro número de PR) não conta.

**Transições**: inexistente → aberta (`gh issue create`). Fechamento é manual e fora do passo;
issue fechada continua bloqueando nova criação.

## Entity: Regras da branch base

Conjunto de checks obrigatórios devolvido por `GET /repos/{owner}/{repo}/rules/branches/{branch}`
(research F1).

| Campo | Uso no passo |
|-------|--------------|
| `type` | só entradas `required_status_checks` interessam |
| `parameters.required_status_checks[].context` | nomes dos checks obrigatórios; filtram a lista de vermelhos |

**Chave de consulta**: o nome da branch base (`github.event.pull_request.base.ref`), codificado
para segmento de caminho (Decision 1) antes de entrar na rota.

**Estados do resultado**: lista não vazia → filtra vermelhos ("Lista filtrada pelos checks
obrigatórios da branch base."); lista vazia ou consulta com erro → aviso de regra ilegível e todo
check vermelho listado (comportamento de hoje, mantido para falha real — Edge Cases da spec).
