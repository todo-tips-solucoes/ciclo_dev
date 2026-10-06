# Research: PR de promoção decidido pelo conteúdo das árvores

**Feature**: `promotion-pr-arvores` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 e D2, normativas)

Referências de linha: `templates/.github/workflows/promotion-pr.yml.tmpl` e
`scripts/testar-configurar.sh` no commit `18a0df9`. Nenhum `NEEDS CLARIFICATION` de eixo
estrutural: linguagem, plataforma e entrega são as do fluxo existente (bash embutido num fluxo do
GitHub Actions, gerado pelo `configurar.sh`).

## Fontes

Lidas em 2026-10-06 com `ctx_fetch_and_index` (Princípio V). As citações abaixo são literais.

| # | Fonte | O que sustenta |
|---|-------|----------------|
| F1 | [REST API — Commits, "Get a commit"](https://docs.github.com/en/rest/commits/commits#get-a-commit) | endpoint `GET /repos/{owner}/{repo}/commits/{ref}`; `ref`: "Can be a commit SHA, branch name (`heads/BRANCH_NAME`), or tag name (`tags/TAG_NAME`)"; o exemplo de resposta 200 traz `"commit": { ... "tree": { "url": ..., "sha": "6dcb09b5..." } ... }`; status 200, 404, 409, 422, 429, 500, 503; token fine-grained: "\"Contents\" repository permissions (read)" |
| F2 | [REST API — Commits, "Compare two commits"](https://docs.github.com/en/rest/commits/commits#compare-two-commits) | "This endpoint is equivalent to running the `git log BASE..HEAD` command"; `ahead_by` no exemplo de resposta; token fine-grained: "\"Contents\" repository permissions (read)" |
| F3 | [Pro Git — Git Objects](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects) | "Git is a content-addressable filesystem"; "Git concatenates the header and the original content and then calculates the SHA-1 checksum of that new content"; o tree guarda nomes de arquivo e diretórios ("A single tree object contains one or more entries, each of which is the SHA-1 hash of a blob or subtree with its associated mode, type, and filename"); o commit "specifies the top-level tree for the snapshot of the project at that point" |
| F4 | [Workflow syntax — `permissions`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions) | "`contents: read` permits an action to list the commits"; "If you specify the access for any of these permissions, all of those that are not specified are set to `none`." |
| F5 | [gh api](https://cli.github.com/manual/gh_api) | "`-q`, `--jq <string>` Query to select values from the response using jq syntax". A página **não diz** qual código de saída o `gh api` devolve numa resposta HTTP 4xx/5xx |
| F6 | [gh help exit-codes](https://cli.github.com/manual/gh_help_exit-codes) | "If a command fails for any reason, the exit code will be 1", com a ressalva: "It is possible that a particular command may have more exit codes" |

## Decision 1: como ler a árvore de cada branch

- **Decision**: uma chamada por branch,
  `gh api "repos/$REPO/commits/heads/$PRODUCAO" --jq '.commit.tree.sha'` e a mesma com
  `$INTEGRACAO`.
- **Rationale**: F1 dá o endpoint, a forma `heads/BRANCH_NAME` do `ref` (que não colide com uma
  tag de mesmo nome) e o campo `commit.tree.sha` no exemplo de resposta. Usa o mesmo `gh api`
  e o mesmo `GH_TOKEN` que o passo já usa (FR-007): nenhuma ferramenta, ação ou passo novo.
- **Alternatives considered**:
  - O próprio `compare`: rejeitado. Ele é equivalente a `git log BASE..HEAD` (F2), isto é, a
    comparação por ancestralidade que D1 substitui; é ela que segue positiva depois do squash.
  - `actions/checkout` com as duas branches e `git rev-parse <branch>^{tree}`: rejeitado. Passo
    e ação novos, clone a cada push na integração, contra FR-007 e FR-008.
  - GraphQL lendo as duas árvores numa chamada: rejeitado. Consulta maior para o mesmo dado, e
    duas chamadas REST só acontecem quando há commits à frente (Decision 3).

## Decision 2: igualdade do SHA da árvore como critério de conteúdo

- **Decision**: há o que promover se, e só se, o SHA da árvore da ponta da produção difere do da
  ponta da integração.
- **Rationale**: o commit aponta para a árvore do topo do projeto, e a árvore lista nome, modo e
  SHA de cada arquivo e subdiretório; todo objeto é endereçado pelo SHA do próprio conteúdo (F3).
  Mesmos arquivos, nomes e modos dão o mesmo SHA de árvore, qualquer que seja o histórico (merge
  commit, squash ou rebase). É D1 ao pé da letra: "a árvore de arquivos do commit".
- **Alternatives considered**: comparar a lista de arquivos alterados — rejeitado, depende do
  histórico e exige mais leitura.

## Decision 3: a comparação de árvores entra depois da contagem zero

- **Decision**: ordem do passo: branch única (sai, hoje) → `ahead_by` = `0` (sai, hoje) →
  **árvores iguais (sai, novo)** → corpo, `gh pr list`, `gh pr edit` ou `gh pr create` (hoje).
  O bloco novo fica entre as linhas 42 e 43 do template.
- **Rationale**: FR-001 vale para qualquer contagem: com contagem zero o passo já sai sem PR. As
  duas leituras de árvore só acontecem quando há commits à frente, que é o caso do squash. As
  saídas e mensagens de hoje não mudam (FR-003, FR-004).
- **Alternatives considered**: comparar as árvores antes da contagem — mesmo resultado, duas
  chamadas a mais em todo push com contagem zero.

## Decision 4: falha na leitura das árvores (FR-005)

- **Decision**: além do `set -euo pipefail` que o passo já tem (a atribuição
  `x="$(gh api ...)"` herda o código de saída do `gh`), uma guarda: cada SHA lido precisa ser
  hexadecimal não vazio; senão o passo escreve no stderr que não conseguiu ler as árvores e sai
  com `1`, antes de qualquer `gh pr`.
- **Rationale**: F5 e F6 não dizem qual código de saída o `gh api` devolve numa resposta 4xx/5xx.
  Sem a guarda, uma resposta sem o campo, lida como vazia ou `null` dos dois lados, daria
  "árvores iguais" e sairia 0; de um lado só, daria "diferentes" e abriria PR. As duas violam
  FR-005. A guarda cumpre FR-005 sem depender do código de saída não documentado.
- **Alternatives considered**: só o `set -e` — rejeitado pelo motivo acima.
- **Limite conhecido**: o nome da branch vai no caminho da URL sem codificação, como no `compare`
  de hoje (linha 38). `ponytail:` mesmo limite que o fluxo já tem; codificar os dois caminhos
  juntos se um nome com `%` ou `#` aparecer.

## Decision 5: permissões e token

- **Decision**: nenhuma mudança em `permissions:` nem no token (FR-008).
- **Rationale**: o bloco do fluxo já declara `contents: read`, que "permits an action to list the
  commits" (F4); para token fine-grained em `TOKEN_AUTOMACAO`, "Get a commit" exige a mesma
  permissão "Contents" (read) que o `compare` já exige (F1, F2).

## Decision 6: PR aberto com árvores iguais

- **Decision**: o passo sai antes de `gh pr list` e não toca o PR aberto.
- **Rationale**: US1-2 e FR-002 ("sem criar nem editar PR"). Fechar o PR seria mudança de
  comportamento fora de D1, que só proíbe abrir e reabrir.

## Decision 7: contagem zero com árvores diferentes

- **Decision**: segue a saída de hoje, "A produção já contém a integração: nada a promover."
- **Rationale**: D1 ("com árvores diferentes, o comportamento de hoje continua") e FR-003. A
  redação anterior do edge case na spec, que dizia "há o que promover", foi alinhada a D1 nesta
  etapa (Decisão `dec-011` da execução).

## Decision 8: cabeçalho do template (D2, FR-006)

- **Decision**: duas linhas a mais no comentário de cabeçalho (linhas 1 a 4), em pt-BR:
  promova por merge commit, como na Fase 9 do `rito-dev`; com squash a produção não passa a
  conter os commits da integração, e o fluxo compara o conteúdo das duas pontas para não reabrir
  o PR quando ele já é igual.
- **Rationale**: a Fase 9 manda `gh pr merge <número> --merge`, "merge commit, nunca squash"
  (`skills/rito-dev/SKILL.md`, linha 214). O texto não cita comportamento de API, só o do
  próprio fluxo.

## Decision 9: cenário 23 de `scripts/testar-configurar.sh` (FR-009)

- **Decision**: bloco `# --- 23 ---` com `cenario "23: promotion-pr decide pelas árvores"` logo
  antes do bloco do cenário 11 (linha 922). Reusa `$TMP/promocao.sh`, já extraído pelo cenário 16
  (o passo não contém nome de branch). Um `gh` falso novo em diretório próprio responde por
  `case "$*"` às cinco chamadas do passo, a partir de variáveis do caso (commits à frente, árvore
  de cada branch, PR aberto, falha simulada), e registra cada chamada num log. Casos do
  [quickstart](quickstart.md), 1 a 6.
- **Rationale**: é o padrão do cenário 16 (passo extraído e executado com `gh` falso), sem rede.
  actionlint com shellcheck embutido sobre o fluxo renderizado já roda no cenário 16 (SC-004),
  sem duplicar aqui.
- **Alternatives considered**: estender o `gh` falso do cenário 16 — rejeitado, ele precisa
  continuar falhando se for chamado (prova de que a branch única não chama o `gh`).
