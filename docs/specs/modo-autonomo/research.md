# Research: modo-autonomo

**Roteiro**: seção "Pendências para a research do plan" de [decisoes-do-owner.md](decisoes-do-owner.md)
(itens R1 a R8), mais os itens que o desenho pediu (R9 a R15), os do gate owasp-security (R16, R17)
e os das rodadas 1 e 2 do `bmad-code-review` (R18).

**Método (Princípio V)**: três subagentes folha, em 2026-11-05, leram as páginas oficiais só com
`ctx_fetch_and_index` e `ctx_search` do context-mode. Nenhum `curl`, `WebFetch` nem whitelist. Os
trechos abaixo são citações literais com o link de origem.

**Legenda**:
- **CONFIRMADO**: a fonte diz.
- **PARCIAL**: a fonte diz uma parte, e o resto está marcado.
- **NÃO VERIFICADO**: nenhuma fonte encontrada diz; nada no artefato afirma isso, e vale a falha
  fechada indicada.

Três páginas REST trazem o schema de resposta só na versão markdown, que fica no mesmo domínio:
`https://docs.github.com/api/article/body?pathname=/en/rest/...`.

## R1. `permissions.deny` para subagente e para edição de arquivo; precedência

**Veredito**: PARCIAL. A regra de subagente está confirmada. A regra de agente de **plugin** é
composição de duas fontes, não está escrita e é ambígua.

- "Use the format `Agent(subagent-name)` where `subagent-name` matches the subagent's name field."
  Exemplo: `"deny": ["Agent(Explore)", "Agent(my-custom-agent)"]`.
  <https://code.claude.com/docs/en/sub-agents>
- "an agent `reviewer` in plugin `deploy-tools` appears as `deploy-tools:reviewer`".
  <https://code.claude.com/docs/en/plugins-reference>
- Ambiguidade: "Deny and ask rules can match a top-level input parameter on any built-in tool with
  `Tool(param:value)`". <https://code.claude.com/docs/en/permissions>. Por isso,
  `Agent(deploy-tools:reviewer)` pode ser lido como regra de parâmetro, e aí não bloquearia nada.
- Edição: "Claude Code checks file permissions against `Edit(path)` and `Read(path)` rules only".
  Regras `Write(path)` nunca casam: "Use `Edit(docs/**)` in place of `Write(docs/**)`".
  <https://code.claude.com/docs/en/permissions>
- Âncora do caminho: "Read and Edit rules both use gitignore pattern syntax"; `/path` é "Path
  relative to the settings source". Em `.claude/settings.json`, `/path` vira
  `<primary working directory>/path`. <https://code.claude.com/docs/en/permissions>
- Limite: as regras de Read e Edit "don't apply to … arbitrary subprocesses".
  <https://code.claude.com/docs/en/permissions>
- Precedência: "3. **Project local settings** (`.claude/settings.local.json`)", numa lista em ordem
  "highest precedence first". <https://code.claude.com/docs/en/settings>
- Deny prevalece: "If a tool is denied at any level, no other level can allow it."
  <https://code.claude.com/docs/en/permissions>

**Decision**: o subcomando emite duas regras por agente proibido:
- `Agent(<plugin>:<agente>)`, a forma de nome;
- `Agent(subagent_type:<plugin>:<agente>)`, a forma de parâmetro.

O nome do parâmetro, `subagent_type`, foi observado no schema da ferramenta Agent desta sessão.
Não vem de doc publicada.

A negação de edição das configurações é `Edit(/.claude/settings*.json)`, sem regra `Write` (D-P1).
O S4 prova qual forma bloqueia; regra que não bloqueia para o rito (D9). Depois do S4, a forma que
não bloqueia sai por PR de correção.

**Rationale**: as duas formas são as leituras possíveis da doc. Uma regra deny que não casa não
tem efeito, então a união é segura. O deny no `.claude/settings.json` não é desfeito por um allow
no `settings.local.json`.

**Alternatives considered**: só a forma de nome (falharia em silêncio se a leitura for a de
parâmetro); deny global em `~/.claude/settings.json` (recusado no D9).

## R2. Status publicado por `pull_request_target` como check obrigatório no HEAD; fonte esperada

**Veredito**: PARCIAL. Contexto e fonte estão confirmados. Que o status no HEAD satisfaça a regra
é NÃO VERIFICADO.

- `pull_request_target`: `GITHUB_SHA` = "Last commit on default branch"; `GITHUB_REF` = "Default
  branch". <https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>
- "Required status checks can be checks or statuses." E também: "you can select an app as the
  expected source of status updates. The app must be installed in the repository with the
  `statuses:write` permission … If the status is set by any other person or integration, merging
  won't be allowed."
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>
- Na API: `context` é "The status check context name that must be present on the commit." e
  `integration_id` é "The optional integration ID that this status check must originate from".
  <https://docs.github.com/en/rest/repos/rules>

**Decision**: o workflow publica um commit status (`POST /repos/{owner}/{repo}/statuses/{sha}`,
com o `sha` do HEAD do PR tirado do evento) e contexto `caminhos-previstos`. O configurador imprime
a instrução de escolher como fonte esperada o app que publica esse status. Não escreve ID numérico:
o ID do app do GitHub Actions não tem fonte. O S3 prova o caminho inteiro.

**Rationale**: o check automático do job de um `pull_request_target` fica no SHA da branch padrão,
não no HEAD do PR. Por isso o D4 pede status explícito no HEAD.

**Alternatives considered**: check run pela API, também sem fonte de que satisfaz a regra; usar
`pull_request`, que roda o arquivo do PR (recusado no D4).

## R3. `GET rules/branches`, ruleset sem bypass, ruleset e auto-merge em repositório privado

**Veredito**: PARCIAL.

- "Returns all active rules that apply to the specified branch … regardless of the level at which
  they are configured … Rules in rulesets with "evaluate" or "disabled" enforcement statuses are
  not returned." <https://docs.github.com/en/rest/repos/rules>
- Esquema do ruleset: "`type`: required, string, enum: `required_status_checks`" e
  "`required_status_checks`: required, array of `StatusCheckConfiguration`: `context`: required,
  string / `integration_id`: integer".
  <https://docs.github.com/api/article/body?pathname=/en/rest/repos/rules>
- "the `bypass_actors` property is only returned if the user making the API request has write
  access to the ruleset." Ruleset também traz "`current_user_can_bypass`: string, enum: `always`,
  `pull_requests_only`, `never`, `exempt`" (sem descrição). Permissão das duas leituras: "Metadata"
  (read). <https://docs.github.com/en/rest/repos/rules>
- "Rulesets are available in public repositories with GitHub Free and GitHub Free for
  organizations, and in public and private repositories with GitHub Pro, GitHub Team, and GitHub
  Enterprise Cloud."
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>
- "Auto-merge for pull requests is available in public repositories with GitHub Free and GitHub
  Free for organizations, and in public and private repositories with GitHub Pro, GitHub Team,
  GitHub Enterprise Cloud, and GitHub Enterprise Server."
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-auto-merge-for-pull-requests-in-your-repository>

**Pontos NÃO VERIFICADOS**:
- que a proteção clássica fica fora de `rules/branches` ("work alongside each other" é o que a doc
  diz);
- o formato de cada regra na resposta de `rules/branches`, inclusive o vínculo com o ruleset de
  origem;
- o significado exato de cada valor de `current_user_can_bypass`.

**Decision**: a identidade do agente não tem escrita no ruleset, e por isso não recebe
`bypass_actors`. A conferência na hora (D5) usa o que a identidade enxerga:
- regra `required_status_checks` com os três contextos;
- `current_user_can_bypass` igual a `never` em cada ruleset que alcança a branch.

Campo ausente ou outro valor vale `desligado`. A lista de bypass vazia é instrução impressa pelo
configurador e conferida pelo owner com credencial de administração nas precondições do S3.
Registrada como decisão operacional (D-P7).

**Rationale**: a API esconde `bypass_actors` de quem não administra o ruleset. Exigir a lista
vazia na hora faria o modo nunca ligar.

**Alternatives considered**: exigir `bypass_actors` vazio (ilegível para a identidade); usar a
credencial do owner para conferir (contraria o D2).

## R4. Permissões de token fine-grained e de GitHub App

**Veredito**: PARCIAL.

- Merge de PR: vale para "GitHub App user access tokens / GitHub App installation access tokens /
  Fine-grained personal access tokens" e exige "Contents" repository permissions (write).
  <https://docs.github.com/en/rest/pulls/pulls>
- Criar ruleset exige "Administration" repository permissions (write).
  <https://docs.github.com/en/rest/repos/rules>
- "Workflows" lista `PUT /repos/{owner}/{repo}/contents/{path}` com write, marcado "Multiple
  permissions are required".
  <https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens>
- Auto-merge: mutation GraphQL `enablePullRequestAutoMerge` ("Enable the default auto-merge on a
  pull request."). <https://docs.github.com/en/graphql/reference/pulls>

**Pontos NÃO VERIFICADOS**:
- a permissão exigida para ligar o auto-merge;
- que o push por git de arquivo em `.github/workflows/` exija "Workflows";
- o equivalente exato em GitHub App (a página foi indexada mas não consultada).

**Decision**: o configurador imprime a identidade com Contents (write), Pull requests (write) e
Metadata (read), sem Administration nem Workflows (D2). O S3 prova as recusas e o auto-merge com
essa credencial.

## R5. Merge feito pelo auto-merge dispara `push` e `pull_request` `closed`?

**Veredito**: NÃO VERIFICADO.

- "Auto-merge merges a pull request automatically after all required reviews and status checks
  pass."
  <https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request>
- Existem os tipos `auto_merge_enabled` e `auto_merge_disabled`.
  <https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>

**Decision**: o S3 confere, depois do merge autônomo, que o CI de `push` na integração e o
`audit-merge-vermelho` rodaram. Se não rodaram, o rito para e volta ao owner: o smoke e a promoção
dependem desses eventos.

## R6. Evento criado com o `GITHUB_TOKEN` não dispara workflow

**Veredito**: CONFIRMADO.

- "events triggered by the `GITHUB_TOKEN` will not create a new workflow run, with the following
  exceptions: `workflow_dispatch` and `repository_dispatch` events always create workflow runs."
  <https://docs.github.com/en/actions/concepts/security/github_token>
- "if a workflow run pushes code using the repository's `GITHUB_TOKEN`, a new workflow will not run
  even when the repository contains a workflow configured to run when `push` events occur."
  <https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow>

**Decision**: no modo ligado, `promotion-pr` exige `TOKEN_AUTOMACAO` e falha sem ele (D8).

## R7. `gh pr revert`: merge commit, squash e versão mínima

**Veredito**: PARCIAL.

- "gh pr revert {<number> | <url> | <branch>} [flags]", título "Revert a pull request".
  <https://cli.github.com/manual/gh_pr_revert>
- "feat: implement gh `pr revert` by @lucasmelin in #8826".
  <https://github.com/cli/cli/releases?q=%22pr+revert%22&expanded=true>
- `revertPullRequest`: "Create a pull request that reverts the changes from a merged pull request."
  <https://docs.github.com/en/graphql/reference/pulls>

**Pontos NÃO VERIFICADOS**: a versão mínima (a tag do release não veio no índice) e o
comportamento com squash e com merge commit.

**Decision**: o rito testa `gh pr revert --help` antes de usar, em vez de fixar versão (D-P8).
Ausente: para e volta ao owner. O S3 prova o revert de squash na integração; o de merge commit
(promoção) fica provado no primeiro rollback real ou num S3 com integração ≠ produção.

## R8. `pulls/N/files`: paginação, teto e `previous_filename`

**Veredito**: CONFIRMADO.

- "Responses include a maximum of 3000 files. The paginated response returns 30 files per page by
  default." E `per_page` é "The number of results per page (max 100)".
  <https://docs.github.com/en/rest/pulls/pulls>
- "`status`: required, string, enum: `added`, `removed`, `modified`, `renamed`, `copied`,
  `changed`, `unchanged`" e "`previous_filename`: string" (opcional).
  <https://docs.github.com/api/article/body?pathname=/en/rest/pulls/pulls>
- "Get a pull request" traz `"changed_files"` no exemplo. Permissão: "Pull requests" (read).
  <https://docs.github.com/en/rest/pulls/pulls>

**Decision**: a trava pagina com `per_page=100` até acabar. Confere cada `filename` e, quando
houver, o `previous_filename`. Reprova se o total listado ≠ `changed_files`, o que cobre PR acima de
3000 arquivos.

## R9. `pull_request_target`: tipos de atividade e contexto

**Veredito**: CONFIRMADO.

- "By default, a workflow only runs when a `pull_request_target` event's activity type is
  `opened`, `synchronize`, or `reopened`."
  <https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>
- "This event runs in the context of the default branch of the base repository, rather than in
  the context of the merge commit, as the `pull_request` event does. This prevents execution of
  unsafe code from the head of the pull request…" (mesma URL)

**Decision**: tipos `opened`, `synchronize`, `reopened` e `edited`. O `edited` cobre a troca de base
e de corpo, porque a linha `Origem:` fica no corpo. O workflow precisa estar na branch padrão
(D4). Quando a branch padrão difere da integração, o README avisa.

## R10. Reexecução depois da aprovação

**Veredito**: CONFIRMADO.

- "The workflow will also use the same `GITHUB_SHA` (commit SHA) and `GITHUB_REF` (git ref) of the
  original event that triggered the workflow run."
- "Re-runs use the privileges of the actor who initially triggered the workflow, not the
  privileges of the actor who initiated the re-run."
- "People with write permissions to a repository can re-run workflows in the repository."

Fonte das três: <https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs>

**Decision**: PR sem registro ou de governança é reexecutada pelo owner com "Re-run" depois de
aprovar, nunca por `pull_request_review` (D4). A trava lê a aprovação na API, no commit atual,
então quem dispara não muda o veredito. Que o re-run use o mesmo arquivo de workflow é inferência
do mesmo SHA e REF.

## R11. Ferramentas do runner

**Veredito**: CONFIRMADO, com aviso.

- "Ubuntu 24.04 | x64 | `ubuntu-latest` or `ubuntu-24.04`". <https://github.com/actions/runner-images>
- "Node.js 22.23.4", "jq 1.7", "GitHub CLI 2.103.2".
  <https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md>
- "[Ubuntu] `ubuntu-latest` label will use Ubuntu 26.04 in November 2026" (mesma URL).

**Decision**: `ubuntu-latest`, como os demais jobs. O job novo e o workflow-template conferem
`node`, `gh` e `jq` antes de usar e falham fechado (D-P5). As versões citadas são as do README na
data do fetch.

## R12. Rótulo e rascunho

**Veredito**: CONFIRMADO.

- Rotular PR: "The fine-grained token must have at least one of the following permission sets:
  "Issues" repository permissions (write); "Pull requests" repository permissions (write)".
  <https://docs.github.com/en/rest/issues/labels>
- "If supported by your plan, convert to draft with `--undo`".
  <https://cli.github.com/manual/gh_pr_ready>

## R13. Criar commit status exige permissão própria

**Veredito**: CONFIRMADO.

- "The fine-grained token must have the following permission set: "Commit statuses" repository
  permissions (write)". <https://docs.github.com/en/rest/commits/statuses>
- "Any person or integration with write permissions to a repository can set the state of any
  status check in the repository".
  <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets>

**Decision**: a identidade do D2 não recebe "Commit statuses". Status forjado com a credencial do
agente é recusado por permissão, e a fonte esperada é a 2ª camada (R2). O workflow usa
`permissions: statuses: write` só no job da trava.

## R14. Flags do `gh pr merge`

**Veredito**: CONFIRMADO.

- "`--admin` Use administrator privileges to merge a pull request that does not meet
  requirements"
- "`--auto` Automatically merge only after necessary requirements are met" e "`--disable-auto`
  Disable auto-merge for this pull request"
- "`-m`, `--merge` Merge the commits with the base branch" e "`-s`, `--squash` Squash the commits
  into one commit and merge it into the base branch"

Fonte: <https://cli.github.com/manual/gh_pr_merge>

`--match-head-commit <SHA>` também existe. Desde a rodada 2 do `bmad-code-review` (emenda à D8), a
promoção usa `--merge --match-head-commit X` sem `--auto`, depois dos checks obrigatórios verdes com
a cabeça em `X`. A fonte da recusa com outro HEAD e a do `gh pr checks` estão no R18.

## R15. Permissões do usuário autenticado no repositório

**Veredito**: PARCIAL.

- Schema de "Get a repository": "`permissions`: object: `admin`: required, boolean / `maintain`:
  boolean / `push`: required, boolean / `triage`: boolean / `pull`: required, boolean".
  <https://docs.github.com/api/article/body?pathname=/en/rest/repos/repos>
- A doc não diz literalmente que o objeto é do usuário autenticado.

**Decision**: pré-condição P2 (`admin` falso e `maintain` não verdadeiro). Campo ausente vale
`desligado`. O S3 confere o valor com a credencial do agente.

## R16. `GITHUB_TOKEN`: app de origem e permissões padrão (gate owasp-security do plan)

**Veredito**: PARCIAL.

- "When you enable GitHub Actions, GitHub installs a GitHub App on your repository. The
  `GITHUB_TOKEN` secret is a GitHub App installation access token."
  <https://docs.github.com/en/actions/concepts/security/github_token>
- Opção do repositório: "read and write access for all permissions (the permissive setting), or
  just read access for the `contents` and `packages` permissions (the restricted setting)"; em
  organização, "the setting is inherited from what is configured in the organization settings".
  <https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository>
- "If you specify the access for any of these permissions, all of those that are not specified are
  set to `none`." <https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax>
- NÃO VERIFICADO: a doc de rulesets não cita "GitHub Actions" como fonte esperada. Que o status de
  qualquer workflow do repositório venha da mesma app que o da trava é inferência das duas frases
  acima e da R2.

**Decision**: a fonte esperada não separa a trava de outro workflow do mesmo repositório. O
configurador imprime o padrão restrito do token e a regra de `permissions:` sem `statuses: write`
nos workflows que rodam em `pull_request`; o S3 inclui o status forjado por outro workflow.

## R17. Configuração do semantic-release lida do repositório (gate owasp-security do plan)

**Veredito**: PARCIAL.

- "A `.releaserc` file, written in YAML or JSON, with optional extensions:
  `.yaml`/`.yml`/`.json`/`.js`/`.ts`/`.cjs`/`.mjs`"; "A `release.config.(js|ts|cjs|mjs)` file that
  exports an object"; "A `release` key in the project's `package.json` file"; `extends`: "List of
  modules or file paths containing a shareable configuration".
  <https://semantic-release.org/usage/configuration/>
- Plugins: "listing plugins by npm module name". <https://semantic-release.org/foundation/plugins.md>
- NÃO VERIFICADO literalmente: que o arquivo `.js`/`.mjs` seja executado. A doc diz "exports an
  object" e mostra `module.exports`/`export default`; carregar o módulo roda o código dele
  (inferência).

**Decision**: A2, escolhida pelo owner no block-001 (dec-022). O `release.yml` roda o
semantic-release com o `TOKEN_AUTOMACAO` no ambiente, sobre código que no modo ligado chega à
produção sem leitura humana. Por isso:
- `.releaserc*` e `release.config.*` (nome de base, em qualquer pasta) e a mudança da chave
  `release` de qualquer `package.json` (`jq -c '.release // null'` na base e no HEAD, como no
  D-P10) entram na lista de governança da trava;
- o configurador orienta o `TOKEN_AUTOMACAO` como token de GitHub App ou fine-grained de uma
  identidade que não é dona, só deste repositório, com Contents e Pull requests, sem
  Administration nem Workflows, nunca o token pessoal do owner. Assim um vazamento não dá
  aprovação de dono nem mudança de regra ou de workflow;
- o `release.yml` não muda (a alternativa B2 mexia nele, fora de "Caminhos previstos").

Residual: `extends` aceita caminho de arquivo; o arquivo local apontado não casa com a lista (a
mudança da referência casa). O dano fica no escopo do token restrito. As permissões que o
semantic-release exige desse token não foram lidas na fonte: ver Pendências.

## R18. Campos de API e flags usados pela trava, pela promoção e pela auditoria (rodadas 1 e 2 do `bmad-code-review`, A6 e A2-11)

**Veredito**: PARCIAL.

Lidos em 2026-11-06 com `ctx_fetch_and_index` (versão markdown das páginas REST e de payloads, que
traz o schema) e `ctx_search` do context-mode; nenhum `curl`, `wget` nem `WebFetch`. Campo sem
trecho literal encontrado está como "não confirmado na fonte", com a leitura de falha fechada que o
código aplica.

- **`GET /repos/{owner}/{repo}/pulls/{pull_number}`** ("Get a pull request"). Fontes:
  <https://docs.github.com/api/article/body?pathname=/en/rest/pulls/pulls> e
  <https://docs.github.com/en/rest/pulls/pulls>.
  - `changed_files`: CONFIRMADO, "`changed_files`: required, integer" no schema do pull request.
  - `head`: CONFIRMADO como objeto obrigatório, "`head`: required, object: `label`: required,
    string".
  - `head.ref`, `head.sha`, `head.repo.full_name`, `base.ref`, `base.sha` e `merged`: **não
    confirmados na fonte** (o trecho do schema com esses campos não saiu na busca); o código falha
    fechado. `head.sha` vazio ou diferente do SHA do evento dá `failure` "HEAD mudou";
    `head.repo.full_name` ausente, nulo ou diferente do repositório dá "PR de outro repositório"
    (exige dono); `head.ref` ausente não é PR de promoção (exige dono); na correção, `merged`
    diferente de `true` ou `base.ref` diferente da base dá `failure`.
- **`GET /repos/{owner}/{repo}/pulls/{pull_number}/files`**: CONFIRMADO. "Responses include a
  maximum of 3000 files. The paginated response returns 30 files per page by default." e
  `per_page` "The number of results per page (max 100)". Mesmas fontes (ver também R8).
- **`GET /repos/{owner}/{repo}`**. Fonte:
  <https://docs.github.com/api/article/body?pathname=/en/rest/repos/repos>.
  - `allow_auto_merge`: CONFIRMADO, "`allow_auto_merge`: boolean, default: `false`" no schema do
    repositório.
  - `allow_merge_commit`: PARCIAL. Confirmado como parâmetro de criação e atualização ("Either true
    to allow merging pull requests with a merge commit, or false to prevent merging pull requests
    with merge commits. Default: `true`"); na resposta do GET, **não confirmado na fonte**. O código
    falha fechado: `[.allow_auto_merge, .allow_merge_commit] | all` com campo ausente (`null`) dá
    falso, e o `promotion-pr` para sem criar a PR.
- **Payload do evento `pull_request`** (`pull_request_target`, tipo `closed`). Fonte:
  <https://docs.github.com/api/article/body?pathname=/en/webhooks/webhook-events-and-payloads>. A
  doc lista `number` ("Required. The pull request number.") e `pull_request` ("object, Required.")
  sem detalhar os campos do objeto. `pull_request.base.sha`, e qual commit ele indica numa PR já
  mergeada: **não confirmado na fonte**. O código falha fechado: SHA vazio ou constituição ilegível
  nele vale `desligado`, e o `aprovacao-de-dono` vermelho volta a abrir a issue de auditoria.
- **`gh pr merge`**: CONFIRMADO. "`--auto` Automatically merge only after necessary requirements are
  met"; "`-m`, `--merge` Merge the commits with the base branch"; "`--match-head-commit <SHA>`
  Commit SHA that the pull request head must match to allow merge"; "`--disable-auto` Disable
  auto-merge for this pull request". <https://cli.github.com/manual/gh_pr_merge>
  - Merge direto com `--match-head-commit` (promoção, emenda à D8 da rodada 2): a recusa com outra
    cabeça se apoia no manual do `gh` ("must match to allow merge", acima). O REST de merge devolve
    "409 Conflict if sha was provided and pull request head did not match"
    (<https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request>, tabela "HTTP response
    status codes for 'Merge a pull request'"), mas nenhuma fonte lida diz que o `gh` usa essa
    chamada: o 409 fica como referência (rodada 3, A3-5). Merge com erro, qualquer que seja: o rito
    relê a cabeça; diferente de `X` volta ao passo 2, igual para. O `--auto` saiu da promoção: a
    combinação com `--match-head-commit` não é mais usada.
  - `--disable-auto` também desarma as PRs de frente do agente quando a leitura do modo dá
    `desligado` (B2-5).
- **`gh pr checks`**: CONFIRMADO. "`--required` Only show checks that are required"; "`--watch`
  Watch checks until they finish"; "`--fail-fast` Exit watch mode on first check failure"; "When
  the `--json` flag is used, it includes a `bucket` field, which categorizes the `state` field into
  `pass`, `fail`, `pending`, `skipping`, or `cancel`"; "Additional exit codes: 8: Checks pending";
  `-R`, `--repo` herdado de `gh pr`. <https://cli.github.com/manual/gh_pr_checks>
  - O manual não dá o código de saída de check em falha, nem diz se a lista inclui commit
    statuses. Por isso a promoção não decide pela saída do `--watch`: lê os `bucket` com `--json`
    e só segue com lista não vazia e todos `pass`. O merge recusado por check pendente cai em
    "outro erro" e volta ao owner.
- **`gh pr view --json headRefOid,body`**: CONFIRMADO. `headRefOid` e `body` estão em "JSON
  Fields"; "`--json <fields>` Output JSON with the specified fields"; `-R`, `--repo` herdado de
  `gh pr`. <https://cli.github.com/manual/gh_pr_view>
- **Ordem dos commit statuses** (status `caminhos-previstos` mais recente do commit): CONFIRMADO.
  "Statuses are returned in reverse chronological order. The first status in the list will be the
  latest one." (List commit statuses for a reference,
  <https://docs.github.com/en/rest/commits/statuses>).
- **`release.yml` e o revert**: nenhuma fonte lida diz o que o semantic-release faz com o commit de
  revert mergeado na produção. O rito não afirma que vira versão: manda conferir se o
  `release.yml` gerou versão a partir do revert e informar o owner (A2-11).
- **Erro do `gh api`**: a trava separa "registro ausente" de "erro de leitura" pelo texto
  `(HTTP 404)` na saída de erro do `gh`. O formato da mensagem **não foi confirmado na fonte**; o
  código falha fechado: erro sem esse texto é `failure` "erro de leitura", nunca "sem registro".
- **`.claude/settings.json` como link (rodada 3, E3-11)**: o tipo do item vem da API de conteúdo,
  <https://docs.github.com/en/rest/repos/contents>, cuja resposta tem `type` com enum `file`,
  `symlink`, `submodule` e diretório. A mesma página diz: "If the content is a symlink and the
  symlink's target is a normal file in the repository, then the API responds with the content of
  the file. Otherwise, the API responds with an object describing the symlink itself." A trava
  exige `type` = `file` e `path` = `.claude/settings.json` no HEAD e na base, e qualquer outra
  resposta conta como governança. Que o `path` da resposta para link seja o do alvo **não está
  confirmado na fonte**, e o S3 confere.

**Decision**: a trava, o `promotion-pr` e o `audit-merge-vermelho` usam só esses campos. Cada campo
não confirmado tem a leitura de falha fechada acima, e o S3 confere os valores reais.

## R19. Hooks do cstk fora do `.claude/settings.json` rastreado (rodada 4, E4-1/E4-7)

Fonte: `cstk hooks --help` do `cstk` v10.13.1 instalado, lido em 2026-11-06. "--local: grava o
REGISTRO em <PATH>/.claude/settings.local.json em vez de settings.json (os scripts continuam em
.claude/hooks/). [...] o Claude Code SOMA hooks entre escopos". Se o outro arquivo já registra os
hooks, "os dois ficam ativos e cada tool call e contada em dobro". Dica do mesmo texto:
`printf '.claude/hooks/\n.claude/settings.local.json\n.claude/*.bak\n.claude/*.bak-pre-dedup\n' >> .git/info/exclude`.

Numa worktree, o `.git` é arquivo; `git rev-parse --git-path info/exclude` devolve o
`info/exclude` do diretório git comum, que vale para todas as worktrees (conferido com git 2.55 num
repositório descartável).

**Decision**: o passo 5 do "Depois do OK" roda `cstk hooks install --local`, salvo quando o
`.claude/settings.json` commitado já registra os hooks (`cstk hooks status`), e acrescenta as
quatro linhas, sem repetir, ao `info/exclude` comum.

## Decisões de desenho (operacionais, dentro de D1 a D13)

### D-P1. Negação de escrita nas configurações só com `Edit`

`Edit(/.claude/settings*.json)`, ancorada na raiz da worktree. Segundo R1, uma regra `Write`
nunca casa e `Edit` cobre a escrita. Isso cumpre a intenção do D9 ("deny de Edit e Write") com a
sintaxe oficial. O curinga no nome do arquivo segue a sintaxe gitignore, mas não há exemplo literal
com `settings*.json`: o S4 prova.

### D-P2. A frente vem do diff mais o registro na base

A PR de frente toca `docs/specs/<x>/**` para exatamente um `<x>` com registro na base. A PR de
correção ou revert leva a linha `Origem: #<n>`. Título e branch nunca contam (D4). O corpo só serve
para achar a PR original; o veredito sai das listas de arquivos lidas na API.

### D-P3. Trava no modo desligado

Publica `success` com a descrição "modo desligado". Sem isso, toda PR de docs mostraria vermelho
até a reexecução manual, e o check não é obrigatório nesse modo. A PR que liga o modo edita
`docs/constitution.md` e passa pelo gate humano do modo desligado.

### D-P4. Teste do subcomando em Node puro

Arquivo `skills/rito-descoberta/historico.test.mjs`, só com módulos `node:`, como o próprio
`historico.mjs`. Os fixtures são criados em diretório temporário: nenhum symlink nem executável
versionado, e o `cp -r` do S1 continua limpo. O job novo `historico` fica no `ci.yml`.

### D-P5. Runner e ferramentas

`ubuntu-latest`, mais a conferência explícita de `node`, `gh` e `jq` (R11).

### D-P6. Critério (a), navegador e desktop

O teste deterministico casa os termos `browser`, `chrome`, `playwright`, `puppeteer`, `computer`
e `desktop` sem diferenciar maiúsculas, além de `WebFetch`, `WebSearch` e do prefixo `mcp__`. Uma
lista mais larga só endurece o critério; não afirma nada sobre ferramenta externa.

### D-P7. Bypass conferido pelo que a identidade enxerga

Ver R3. O agente confere `current_user_can_bypass` = `never` e os três checks obrigatórios. A lista
de bypass vazia fica com o owner.

### D-P8. `gh pr revert` por detecção

Ver R7. O rito não fixa versão mínima do `gh`.

### D-P9. Manifesto e lockfile

São reconhecidos pelo nome de base, numa lista fechada da trava:
- `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `yarn.lock`, `pnpm-lock.yaml`;
- `requirements*.txt`, `pyproject.toml`, `poetry.lock`, `Pipfile`, `Pipfile.lock`;
- `go.mod`, `go.sum`, `Cargo.toml`, `Cargo.lock`, `Gemfile`, `Gemfile.lock`, `composer.json`,
  `composer.lock`;
- desde a rodada 2 do `bmad-code-review`: `pnpm-workspace.yaml`, `bun.lock`, `bun.lockb`,
  `deno.lock`, `uv.lock`.

Fontes dos nomes da rodada 2, conferidas via `ctx_fetch_and_index` em 2026-11-06:
- `bun.lock` e `bun.lockb`, <https://bun.sh/docs/install/lockfile>: "`bun install` creates a
  lockfile called `bun.lock`." e "Bun v1.2 changed the default lockfile format to the text-based
  `bun.lock`. To migrate an existing binary `bun.lockb`, run …".
- `deno.lock`, <https://docs.deno.com/runtime/packages/>: "Deno automatically maintains a
  `deno.lock` file recording the exact version and integrity hash of every dependency".
- `uv.lock`, <https://docs.astral.sh/uv/concepts/projects/layout/>: "uv creates a `uv.lock` file
  next to the `pyproject.toml`."
- `pnpm-workspace.yaml`, <https://pnpm.io/pnpm-workspace_yaml>: "Catalogs are also defined in the
  `pnpm-workspace.yaml` file" (versões de dependência no próprio arquivo).

O `deno.json`/`deno.jsonc` também declara dependências e ficou fora da lista. O `deno.lock` muda
junto, por isso o risco é baixo.

Um arquivo desses só passa listado **literalmente** em "Caminhos previstos" e com "Dependências
novas" com ao menos um item que não seja variação de "nenhuma" (Clarifications, Q1). A trava
confere que existe item aprovado, não o nome do pacote (limite conhecido, rodada 2). A lista é
escolha de desenho e só endurece a trava.

### D-P10. Acréscimo puro em `permissions.deny`

Os blobs de `.claude/settings.json` na base e no HEAD são lidos pela API de conteúdo, sem checkout.
Passa só se:
- fora de `.permissions.deny`, os dois JSON são iguais (`del(.permissions.deny)`);
- todo item do deny da base continua no do HEAD.

Sem o arquivo na base, o do HEAD tem de ser exatamente `{"permissions":{"deny":[...]}}`. O
`settings.local.json` nunca passa.

### D-P11. PR para a produção na trava (A1 do block-001)

Resposta do owner ao F-PROD do gate owasp-security (block-001, dec-022): a trava roda também em PR
com base = produção, e passa sozinha só a PR de promoção (cabeça = branch de integração e
repositório da cabeça = repositório da base). Qualquer outra PR para a produção cai na aprovação de
dono no commit atual. A promoção segue autônoma (D8). Isso troca a redação "a PR de promoção fica
fora da trava" do D4 e do FR-011.

Desenho, dentro de A1:
- **contexto próprio**: `caminhos-previstos-producao` na produção e `caminhos-previstos` na
  integração. O contexto é "the status check context name that must be present on the commit"
  (R2): o status fica no commit, e o mesmo SHA pode ser HEAD de uma PR verde para a integração e de
  outra para a produção. Com um contexto só, o verde da integração satisfaria a regra da produção;
- **modo lido na integração**: também na PR para a produção, porque a fonte da verdade do D1 é
  `origin/<BRANCH_INTEGRACAO>:docs/constitution.md`; a produção pode ainda não ter a linha;
- **HEAD antes da base**: o SHA do HEAD é conferido antes de reconhecer a promoção, para não
  publicar sucesso em commit que já deixou de ser HEAD;
- campos de base, cabeça e repositório no `GET pulls/{n}` estão "a confirmar" (Pendências); campo
  ausente não é promoção e cai na aprovação de dono (falha fechada);
- a P3 e a P4 conferem as duas branches quando integração ≠ produção.

Com integração = produção não há PR de promoção (Fase 9 no-op) e a trava segue só o caminho da
integração.

## Pendências (NÃO VERIFICADO, com falha fechada)

| Item | Onde se prova | Até lá |
|---|---|---|
| Forma da regra deny de agente de plugin (R1) | S4 | as duas formas são emitidas; nenhuma bloqueia: o rito para |
| Curinga em `Edit(/.claude/settings*.json)` (D-P1) | S4 | o rito para se a edição não for recusada |
| Status do `pull_request_target` no HEAD vale como check obrigatório; fonte esperada (R2) | S3 | modo não liga no repositório de teste |
| Formato das regras em `rules/branches` e vínculo com o ruleset (R3) | implementação (fonte) + S3 | campo ausente: `desligado` |
| Permissão de auto-merge; push de workflow exige "Workflows" (R4) | S3 | recusa esperada; se o push de workflow passar, o rito para |
| Auto-merge dispara `push` e `closed` (R5) | S3 | não disparou: para |
| `gh pr revert` com squash e com merge commit; versão mínima (R7) | S3 / 1º rollback | comando ausente ou falho: para |
| Sintaxe da regra deny de Bash para `--admin` (contrato modo-autonomo §3): sintaxe conferida (dec-047, <https://code.claude.com/docs/en/permissions>); efeito de bloquear não medido, a provar no caso `--admin` do S3 | S3 | camada extra; o `--admin` já é recusado pela identidade (D2) |
| Campos de checks por SHA, de auto-merge e de merge commit permitidos, e flags de `gh pr list` e `gh pr edit` (contrato modo-autonomo §2, §4, §5, §7) | implementação: manual oficial via context-mode antes de escrever o comando | sem fonte, o comando não entra na skill |
| Campos de base, cabeça e repositório da cabeça e da base em `GET pulls/{n}`, `merged`, `allow_merge_commit` no GET do repositório e `pull_request.base.sha` do payload (R18) | S3 | falha fechada descrita no R18 para cada campo |
| `gh pr checks --required` inclui o commit status obrigatório da trava (`caminhos-previstos-producao`), não só check runs (R18) | S3 | `bucket` diferente de `pass` ou lista vazia para; se a lista não incluir o status, a garantia é o ruleset da produção, que recusa o merge sem ele; merge com erro relê a cabeça e, igual a `X`, para |
| Constituição commitada com CRLF (rodada 3, B3-1): configurador, trava, `audit-merge-vermelho`, `require-codeowner-approval`, `promotion-pr` e `rito-dev` tiram o `\r` e leem o mesmo modo | S3, com a constituição em CRLF nos dois valores | o `rito-dev` lê com `tr -d '\r'`; leitor que divergir reprova o S3 |
| Emenda do registro durante a frente (decisão do owner na rodada 3): PR de registro própria, aprovada pelo owner; depois do merge a trava vale pela versão emendada (caminhos, dependências, instalações e smoke); merge da integração na branch da frente com o registro idêntico byte a byte | S3 | sem a prova, a emenda segue o texto da `rito-descoberta` ("Antes da PR"): PR própria, aprovação de dono, conferência byte a byte |
| Versão gerada pelo `release.yml` a partir do revert na produção (R18) | 1º rollback | o rito manda conferir e informar o owner, sem afirmar |
| Formato `(HTTP 404)` do erro do `gh api` (R18) | S3 | erro sem o texto vale "erro de leitura" (`failure`) |
| Permissões que o semantic-release exige do `TOKEN_AUTOMACAO` restrito (R17, A2) | implementação: doc oficial via context-mode; S3 com integração ≠ produção | falta de permissão faz o release falhar visível; ampliar para Administration ou Workflows só com o owner |
