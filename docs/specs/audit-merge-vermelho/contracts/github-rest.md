# Contracts: audit-merge-vermelho — rotas da REST do GitHub consultadas pelo passo

Contratos **existentes** do GitHub, não propostos aqui. Rotas, parâmetros e campos vêm das
páginas oficiais citadas (research F1–F4); o que a página não diz está marcado como não medido.
Só as duas rotas que mudam nesta frente; check-runs, status e `gh issue create` seguem como
estão (FR-007).

## [EXISTENTE] Regras da branch base

**Method**: `GET /repos/{owner}/{repo}/rules/branches/{branch}` (research F1)
**Auth**: `GH_TOKEN` do passo; permissão "'Metadata' repository permissions (read)" (F1)
**Chamada no passo**: `gh api "repos/$REPO/rules/branches/<base codificada>"` + `--jq` de hoje

### Request

| Elemento | Valor | Origem |
|----------|-------|--------|
| `{owner}/{repo}` | `$REPO` (`github.repository`) | inalterado |
| `{branch}` | `github.event.pull_request.base.ref` percent-encoded (bytes fora de `A-Za-z0-9-._~` → `%XX` maiúsculo) | D1, research Decision 1, F8 |

F1: "The name of the branch. Cannot contain wildcard characters." e "The branch does not need
to exist; rules that would apply to a branch with that name will be returned." Tratamento de
`%2F` pela API: não documentado em F1, não medido (research Decision 1, lacuna registrada).

### Response (200) — campos usados

| Campo | Uso |
|-------|-----|
| `[].type` | só `required_status_checks` |
| `[].parameters.required_status_checks[].context` | checks obrigatórios |

### Erro

Qualquer falha (rota recusada, permissão) → saída descartada (`2>/dev/null || true`), lista
vazia → nota "Sem regra de checks obrigatórios legível na branch base: todo check vermelho foi
listado." (inalterado).

## [EXISTENTE] Issues do repositório (checagem de duplicada)

**Method**: `GET /repos/{owner}/{repo}/issues` (research F2)
**Auth**: `GH_TOKEN` do passo; permissão "'Issues' repository permissions (read)" (F2) — escopo
`issues` já declarado no fluxo, sem mudança (FR-007)
**Chamada no passo**: `gh api "repos/$REPO/issues?state=all&per_page=100" --paginate --jq <filtro>`

### Request

| Parâmetro | Valor | Fonte |
|-----------|-------|-------|
| `state` | `all` (default `open` não serve: FR-005) | F2 |
| `per_page` | `100` (máximo) | F2, F3 |
| `page` | conduzido pelo `--paginate` via header `link` até não haver `rel="next"` | F3, F4 |
| filtro por título | **não existe na rota**; feito no `--jq` | F2 |

### Response (200) — campos usados

| Campo | Uso |
|-------|-----|
| `[].title` | igualdade exata com `TITULO` |
| `[].pull_request` | presente só em PR; item com a chave é descartado (F2) |
| `[].number` | emitido pelo filtro quando há coincidência (só o "não vazio" importa) |

Filtro: `.[] | select(.pull_request == null and .title == env.TITULO) | .number`.

### Erro

Falha da chamada → exit diferente de zero da atribuição sob `set -euo pipefail` → passo falha
com erro visível, sem `gh issue create` (FR-010).
