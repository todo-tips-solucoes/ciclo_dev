# Research: codeowner-aprovacao-atual

**Feature**: `codeowner-aprovacao-atual` | **Date**: 2026-10-06

Nenhum eixo estrutural em aberto: provedor (GitHub), linguagem do passo (bash) e forma do teste
(cenário no padrão do 16) já estão decididos pelo briefing, pela frente `templates-automacao` e
por [decisoes-do-owner.md](decisoes-do-owner.md). As decisões abaixo são operacionais.
Toda leitura de fonte externa desta página foi feita com `ctx_fetch_and_index`, `ctx_search` e
`ctx_execute` do `context-mode` (Princípio V), em 2026-10-06; as citações são literais.

## Fontes oficiais consultadas (Phase 0)

| # | Afirmação usada no plano | Veredito | Fonte |
|---|--------------------------|----------|-------|
| F1 | Nome da opção nativa (proteção de branch clássica): "Optionally, to dismiss a pull request approval review when a code-modifying commit is pushed to the branch, select **Dismiss stale pull request approvals when new commits are pushed**." Na mesma página, o nome exato da outra opção: "select **Require review from Code Owners**". | confirmado | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule |
| F2 | Em rulesets o nome é o mesmo: "If you select **Dismiss stale pull request approvals when new commits are pushed** and/or **Require approval of the most recent reviewable push**, manually creating the merge commit ... will fail". A página cita donos só em prosa ("Optionally, you can choose to require reviews from code owners."). | confirmado | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets |
| F3 | Comportamento da opção nativa: "the approving review is dismissed as stale, and the pull request cannot be merged until someone approves the work again", quando "the diff changes" (por exemplo "because a contributor pushes new changes to the pull request branch"); o descarte ocorre com commits "that affect the diff in the pull request". | confirmado | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches |
| F4 | List reviews for a pull request (`GET /repos/{owner}/{repo}/pulls/{pull_number}/reviews`): schema da resposta com "`state`: required, string" e "`commit_id`: required, string or null"; o exemplo traz `"state": "APPROVED"` e `"commit_id": "ecdd80bb57125d7ba9641ffaa4d7d2c19d3f3091"`; "The list of reviews returns in chronological order." A página não explica quando `commit_id` é nulo (não medido) nem lista o enum de `state` (os exemplos mostram `APPROVED`, `CHANGES_REQUESTED`, `DISMISSED`). | confirmado com lacuna | https://docs.github.com/en/rest/pulls/reviews |
| F5 | Get a pull request (`GET /repos/{owner}/{repo}/pulls/{pull_number}`): "Same response schema as Create a pull request", cujo schema traz "`head`: required, object" com "`sha`: required, string". Permissão: "The fine-grained token must have at least one of the following permission sets: "Pull requests" repository permissions (read) ... "Contents" repository permissions (read)". | confirmado | https://docs.github.com/en/rest/pulls/pulls |
| F6 | `pull_request`: "Note that `GITHUB_SHA` for this event is the last merge commit of the pull request merge branch. If you want to get the commit ID for the last commit to the head branch of the pull request, use `github.event.pull_request.head.sha` instead." Na seção `pull_request_review` a página não cita `head.sha`; a página de webhooks lista `pull_request` como "`object` **Required.**" no payload de `pull_request_review`, sem expandir os subcampos. | confirmado só para `pull_request` | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows, https://docs.github.com/en/webhooks/webhook-events-and-payloads |
| F7 | `github.event`: "The full event webhook payload. ... This object is identical to the webhook payload of the event that triggered the workflow run". | confirmado | https://docs.github.com/en/actions/reference/workflows-and-actions/contexts |

Fontes da frente `templates-automacao` que seguem valendo e não foram relidas: permissões do
`GITHUB_TOKEN` (F4 de lá), CODEOWNERS lido na base e "Require review from Code Owners" (F8 de lá),
fluxo roda o merge commit do PR (F14 de lá) — [research de templates-automacao](../templates-automacao/research.md).

## Decision 1: Nome da opção nativa citada nos comentários (D2, FR-007)

**Decision**: os cabeçalhos do fluxo e de `CODEOWNERS.tmpl` citam, ao lado de "Require review from
Code Owners", a opção "Dismiss stale pull request approvals when new commits are pushed", com o
nome em inglês, como aparece na interface (F1). O link fica aqui, não no comentário.

**Rationale**: é o nome literal na página de regra de proteção clássica e o mesmo em rulesets (F1,
F2), então serve a quem configura por qualquer dos dois caminhos. D2 pede o nome exato e o link na
research; repetir a URL em dois arquivos gerados não acrescenta nada ao operador que já tem o
nome para procurar.

**Alternatives considered**:

- Citar também "Require approval of the most recent reviewable push" (F2): fora de D2; fica como
  nota, não entra nos comentários.
- Traduzir o nome: o operador procura o texto da interface, que é em inglês (Princípio VI permite
  nome próprio de opção em inglês entre aspas, como já é feito com "Require review from Code
  Owners").

**Nota (F3)**: a opção nativa descarta a aprovação quando o diff do PR muda; o check desta frente é
mais estrito, porque qualquer commit head novo invalida a aprovação (D1), mesmo sem mudar o diff.
Os dois são compatíveis: o check só é verificação extra (dec-025, FR-008).

## Decision 2: Fonte do commit head atual do PR (FR-005)

**Decision**: o passo lê o head com `gh api "repos/$REPO/pulls/$PR" --jq .head.sha` (REST "Get a
pull request", F5), depois das checagens de CODEOWNERS e antes da lista de reviews. Falha da
chamada ou valor vazio → `::error::` acionável e exit 1, sem olhar reviews.

**Rationale**: é a única fonte com `head.sha` documentado para os dois eventos que disparam o fluxo
(`pull_request` e `pull_request_review`) e devolve o head no momento da execução, que é o "commit
head atual" de D1. A permissão exigida, "Pull requests" (read), já está no fluxo
(`pull-requests: read`), então `permissions:` e `on:` não mudam (fora de escopo respeitado).

**Alternatives considered**:

- `${{ github.event.pull_request.head.sha }}` como variável de ambiente, no padrão do `BASE_SHA`
  existente: mais curto e sem chamada a mais, mas a documentação só garante o campo para o evento
  `pull_request` (F6); para `pull_request_review` o payload traz `pull_request` sem os subcampos
  descritos (F6, F7). Usá-lo seria afirmar o que a fonte não diz (Princípio V). Também é a foto do
  evento, não o head na hora da execução.
- `GITHUB_SHA`: é o merge commit, não o head (F6).

## Decision 3: Como filtrar as reviews pelo head

**Decision**: a projeção do `--jq` ganha uma terceira coluna, `(.commit_id // "")`, e o `awk` que
guarda o último estado por usuário recebe o head por `-v` e só considera linhas cuja terceira
coluna é igual a ele. O resto do filtro (ignorar `commented`/`pending`, minúsculas, último estado
por usuário, `grep -Fxqf` contra os donos) fica como está.

**Rationale**: menor mudança no pipeline existente e o dado nunca vira código: o head não é
interpolado no programa do `--jq`, que segue um texto fixo. `commit_id` nulo (F4) vira coluna
vazia e nunca é igual a um head não vazio, e a guarda de head vazio (Decision 2) impede o caso
vazio igual a vazio. A ordem cronológica da lista (F4) mantém o "último estado" correto.

**Alternatives considered**:

- Interpolar o head no programa `--jq` (`select(.commit_id == "<head>")`): monta código a partir de
  dado lido da API; evitado mesmo com valor confiável.
- Filtrar com `--arg` num `jq` separado: o fluxo passaria a depender de um `jq` instalado no
  runner (não medido), além do `gh`; o `awk` já está no pipeline.

## Decision 4: Forma do teste (FR-009)

**Decision**: cenário 22 em `scripts/testar-configurar.sh`, entre o 20 e o 11. Renderiza o projeto
com o `cockpit.config.example`, extrai o `run:` do passo do YAML renderizado com o mesmo `awk` do
cenário 16 e o executa com um `gh` falso no `PATH` que responde às três chamadas: conteúdo do
CODEOWNERS (texto fixo), head do PR (valor por variável) e lista de reviews (fixture JSON passada
pelo `jq -r` com o programa recebido em `--jq`). Casos no [quickstart](quickstart.md).

**Rationale**: é o padrão pedido pelo owner (restrições) e exercita o filtro real, inclusive a
projeção nova do `--jq`. O `jq` já é pré-requisito de máquina do cockpit (`instalar.sh`,
`checar_prerequisitos`, confere `git gh node jq curl`), então não é dependência nova. Na ausência dele o cenário segue o padrão de
`actionlint`/`shellcheck`: pulado localmente com aviso, falha no CI (`COCKPIT_EXIGIR_FERRAMENTAS=1`).

**Alternatives considered**:

- `gh` falso que ignora `--jq` e devolve TSV pronto: não testaria a coluna nova do `--jq`.
- Teste fora do `testar-configurar.sh`: contraria a restrição do owner.

Se o `jq` existe no runner `ubuntu-latest`: não medido; o CI responde na primeira execução da PR.
