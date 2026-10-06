# Research: audit-merge-vermelho

**Feature**: `audit-merge-vermelho` | **Date**: 2026-10-06

Nenhum eixo estrutural em aberto: provedor (GitHub), linguagem do passo (bash em `run:`) e
ferramentas (`gh`) já decididos pela frente `templates-automacao`. D1 e D2
([decisoes-do-owner.md](decisoes-do-owner.md)) são normativas; as decisões abaixo só fixam a
forma. Toda leitura de fonte externa foi feita com `ctx_fetch_and_index` do `context-mode`
(Princípio V), em 2026-10-06; as citações são literais.

## Fontes oficiais consultadas (Phase 0)

| # | Afirmação usada no plano | Veredito | Fonte |
|---|--------------------------|----------|-------|
| F1 | Get rules for a branch, parâmetro `branch`: "The name of the branch. Cannot contain wildcard characters." e "The branch does not need to exist; rules that would apply to a branch with that name will be returned."; permissão "'Metadata' repository permissions (read)". A página não fala de `/` no nome nem de codificação. | confirmado com lacuna | https://docs.github.com/en/rest/repos/rules |
| F2 | List repository issues: "GitHub's REST API considers every pull request an issue, but not every issue is a pull request. For this reason, "Issues" endpoints may return both issues and pull requests in the response. You can identify pull requests by the `pull_request` key."; `state` "Default: `open` Can be one of: `open`, `closed`, `all`"; `per_page` "(max 100)… Default: `30`"; `sort` "Default: `created`"; `direction` "Default: `desc`"; permissão "'Issues' repository permissions (read)". Parâmetros da rota: milestone, state, assignee, type, creator, mentioned, issue_field_values, labels, sort, direction, since, per_page, page — **nenhum filtra por título**. Exemplo de resposta traz `number`, `state`, `title` e `pull_request`. | confirmado | https://docs.github.com/en/rest/issues/issues |
| F3 | Paginação: "The URL for the next page is followed by `rel="next"`."; "Once the `link` header no longer includes a link to the next page, all of the results are returned."; "For most endpoints, the maximum value of `per_page` is `100`. If you specify a value greater than the maximum, GitHub does not return an error. Instead, the value is automatically reduced to the maximum". | confirmado | https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api |
| F4 | `gh api`: `--paginate` "Make additional HTTP requests to fetch all pages of results"; "In `--paginate` mode, all pages of results will sequentially be requested until there are no more pages of results… Each page is a separate JSON array or object."; `--jq` "Query to select values from the response using jq syntax". A página **não** diz se o `--jq` roda por página ou sobre o total, nem se a rota é codificada pelo `gh` (nenhuma ocorrência de "encod"). | confirmado com lacuna | https://cli.github.com/manual/gh_api |
| F5 | `gh issue list`: `--search` "Search issues with query", sintaxe documentada em "https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests"; `--limit` "(default 30)". | confirmado | https://cli.github.com/manual/gh_issue_list |
| F6 | Atraso do índice de busca: **não documentado** nas páginas consultadas (nenhuma ocorrência de "index", "immediately", "reflect" ou "delay"). A premissa vem da issue #10 e de D2, não de medição. A REST de busca limita: "up to 1,000 results for each search". | não documentado | https://docs.github.com/en/rest/search/search, https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests |
| F7 | `ubuntu-latest` aponta para a imagem `Ubuntu2404-Readme.md` ("`ubuntu-latest`, `ubuntu-24.04`"), cujo README lista "jq 1.7" em Tools. | confirmado | https://docs.github.com/en/actions/reference/runners/github-hosted-runners, https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md |
| F8 | RFC 3986: "unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~""; "/" é gen-delim; "A percent-encoded octet is encoded as a character triplet, consisting of the percent character "%" followed by the two hexadecimal digits"; "URI producers and normalizers should use uppercase hexadecimal digits for all percent- encodings." | confirmado | https://www.rfc-editor.org/rfc/rfc3986 |

## Decision 1: codificar a branch com função bash no próprio passo (D1)

**Decision**: função `codificar` dentro do `run:`, com `local LC_ALL=C` para iterar por byte:
mantém `[A-Za-z0-9._~-]`, troca qualquer outro byte por `%XX` em hexadecimal maiúsculo (F8). O
resultado entra em `repos/$REPO/rules/branches/<codificado>`; o resto da chamada (filtro `--jq`,
`2>/dev/null || true`, nota de fallback) fica igual.

**Rationale**: atende D1 sem dependência nova (FR-008). Sonda empírica em 2026-10-06 (bash
5.2.21, com `LC_ALL=C.UTF-8` e `LANG=C.UTF-8`): `main` → `main`; `release/2026` →
`release%2F2026`; `feat/ação+1#x` → `feat%2Fa%C3%A7%C3%A3o%2B1%23x`; `a%b&c=d` → `a%25b%26c%3Dd`
— idêntico byte a byte a `jq -rn --arg b … '$b|@uri'` nos três casos com caractere especial.
Branch sem caractere especial sai igual à entrada, logo a rota de hoje não muda (FR-003).

**Lacuna registrada (não medido)**: F1 não documenta como a API trata `%2F` no segmento
`{branch}`, e F4 não diz se o `gh` mexe na rota. A codificação é a decisão do owner (D1); que a
API devolva as regras de `release/2026` com `%2F` não foi medido. O risco é limitado: se a API
recusar, a chamada já está sob `2>/dev/null || true` e o fluxo cai no aviso de regra ilegível,
que é exatamente o comportamento de hoje. Verificação final: primeiro merge real em base com
`/` num projeto-alvo.

**Alternatives considered**:
- `jq @uri`: `jq` está na imagem do runner (F7), mas o template não usa `jq` hoje; seria
  dependência nova no fluxo (FR-008).
- Placeholder `{branch}` do `gh api` (F4): resolve para a branch do diretório corrente, não para
  a base do PR; e o passo roda sem checkout.
- Trocar só `/` por `%2F` (`${BASE//\//%2F}`): mais curto, mas deixa `#`, `%`, `+` e bytes não
  ASCII crus (Edge Cases da spec); a função cobre todos com poucas linhas a mais.

## Decision 2: listagem direta pela REST, filtrada no cliente (D2)

**Decision**:

```
gh api "repos/$REPO/issues?state=all&per_page=100" --paginate \
  --jq '.[] | select(.pull_request == null and .title == env.TITULO) | .number'
```

Saída não vazia → já existe issue → mensagem de hoje e exit 0. Saída vazia → segue para criar.

**Rationale**:
- Rota de listagem, não de busca: não passa pelo índice de busca (FR-004). Não há filtro por
  título na rota (F2), então a igualdade exata fica no `--jq`, como já é hoje.
- `state=all` cobre aberta e fechada (F2, FR-005); o default `open` não serviria.
- `per_page=100` é o máximo (F2, F3) e `--paginate` segue o `link` até não haver `rel="next"`
  (F3, F4): todas as páginas são lidas (FR-006), inclusive a issue além da primeira página
  (US2 cenário 3).
- `.pull_request == null` descarta PRs, que a rota também devolve (F2), e preserva a semântica
  de hoje (`gh issue list` só lista issues).
- O filtro emite uma linha por item encontrado, então funciona tanto se o `--jq` rodar por
  página quanto sobre o total — F4 não diz qual, e o desenho não depende disso. É o mesmo
  padrão `--paginate --jq '.check_runs[] | …'` que o passo já usa.
- Falha da chamada derruba a atribuição `ja="$(…)"` pelo `set -euo pipefail` do passo: erro
  visível, sem criar issue (FR-010), igual a hoje.
- Permissão: a rota exige o escopo de issues em leitura (F2); o passo já usa o escopo `issues`
  hoje para listar e criar, e `permissions:` não muda (FR-007).

**Alternatives considered**:
- `gh issue list --state all --limit <N>` sem `--search`: F5 não documenta por qual API a
  listagem é feita nem garante ausência de índice; e `--limit` exige um teto arbitrário,
  contra FR-006.
- Filtro `creator=github-actions[bot]` ou `since=<merge>` para encurtar a varredura: mudam a
  regra "título idêntico, em qualquer estado" (issue manual de mesmo título deixaria de contar)
  e o FR-006 pede todas as issues. Ficam como caminho de evolução (Decision 3).
- `--slurp` + `length`: F4 o documenta, mas a versão mínima do `gh` que o traz não foi
  verificada; o filtro por linha dispensa a flag.
- GraphQL: mais código para o mesmo resultado; sem ganho medido.

## Decision 3: checagem de duplicada logo antes de criar a issue

**Decision**: o bloco de duplicada sai do início do `run:` e vai para depois de "nada a
auditar", imediatamente antes de montar o corpo e chamar `gh issue create`.

**Rationale**: a busca de hoje custa uma requisição; a listagem direta custa uma por página de
100 itens (F2, F3), e a rota conta PRs também (F2). No início do passo ela rodaria em todo PR
mergeado, inclusive nos verdes. Depois do filtro, roda só quando há o que auditar. O resultado
é o mesmo nos dois lugares: com duplicada não se cria issue; sem vermelho obrigatório não se
cria issue. Critério de vermelho, conteúdo da issue, gatilhos e permissões não mudam (FR-007).
Volume real de issues por projeto-alvo: não medido.

Teto aceito: a varredura cresce com o total de issues e PRs do repositório. Comentário
`ponytail:` no passo nomeia o teto e o caminho de evolução (filtrar por `since` ou `creator`
se o volume pesar, com nova decisão do owner, porque muda a regra).

**Alternatives considered**: manter a ordem de hoje (paga a varredura em todo merge, sem ganho
de comportamento).

## Decision 4: cenário 24 com `gh` falso que aplica o `--jq` real

**Decision**: o `gh` falso do cenário 24 escolhe a fixture pela rota e aplica o filtro `--jq`
recebido com `jq -r`; na rota de issues, aplica a cada página em sequência (emula `--paginate`,
F4). Subcomando desconhecido sai 64. Casos em [quickstart.md](quickstart.md). O cenário checa
`command -v jq` e falha com mensagem clara se faltar.

**Rationale**: testar a resposta pronta não exercitaria o filtro (título exato, descarte de PR,
página 2). `jq` é pré-requisito permitido pelo Princípio VII e está no runner do CI (F7). O
`gh` falso que sai 64 em `issue list` garante que a busca por índice saiu sem asserção extra.
Extração do passo por `awk`, como no cenário 16 (o passo é o último bloco do YAML).

**Alternatives considered**: `gh` falso com saída já filtrada (mais curto, mas não testa o
filtro); fixture em Python (o script já usa `python3`, mas o filtro é jq e reescrevê-lo seria
testar outra coisa).
