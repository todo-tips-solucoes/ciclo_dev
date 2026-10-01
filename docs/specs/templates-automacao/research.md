# Research: templates-automacao

**Feature**: `templates-automacao` | **Date**: 2026-09-30

Nenhum eixo estrutural em aberto: provedor (GitHub), motor de render e plataforma já
decididos pelas frentes anteriores e pelo briefing. As decisões abaixo são operacionais.
Toda leitura de fonte externa desta página foi feita com `ctx_fetch_and_index` do
`context-mode` (Princípio V), em 2026-09-30; as citações são literais.

## Fontes oficiais consultadas (Phase 0)

| # | Afirmação usada no plano | Veredito | Fonte |
|---|--------------------------|----------|-------|
| F1 | "events triggered by the GITHUB_TOKEN will not create a new workflow run, with the following exceptions: workflow_dispatch and repository_dispatch events always create workflow runs." | confirmado | https://docs.github.com/en/actions/concepts/security/github_token |
| F2 | "when a workflow using GITHUB_TOKEN creates or updates a pull request, the resulting pull_request event creates workflow runs in an approval-required state." | confirmado (exceção nova) | mesma página de F1 |
| F3 | "if a workflow run pushes code using the repository's GITHUB_TOKEN, a new workflow will not run" — tag/release do semantic-release com `GITHUB_TOKEN` não disparam outro fluxo (inferência desta regra; a página não cita tag nem release) | inferência | mesma página de F1 |
| F4 | Chaves de `permissions:` do `GITHUB_TOKEN`: actions, artifact-metadata, attestations, checks, code-quality, contents, deployments, id-token, issues, discussions, packages, pages, pull-requests, security-events, statuses, vulnerability-alerts — sem `members` nem `administration`. "If you specify the access for any of these permissions, all of those that are not specified are set to none." | confirmado | https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax |
| F5 | "use the Allow GitHub Actions to create and approve pull requests setting to configure whether GITHUB_TOKEN can create and approve pull requests." Em repositório pessoal novo vem desligada; em organização, herda da organização. | confirmado | https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository |
| F6 | List reviews for a pull request: "'Pull requests' repository permissions (read)"; resposta traz `user.login` e `state`. O valor literal do enum de `state` na REST não foi extraído (não medido); o payload do evento usa `approved` minúsculo. | confirmado com lacuna | https://docs.github.com/en/rest/pulls/reviews |
| F7 | List team members: "'Members' organization permissions (read)" — inexistente no `GITHUB_TOKEN` (F4). Confirma a premissa de dec-014 (block-001). | confirmado | https://docs.github.com/en/rest/teams/members |
| F8 | CODEOWNERS em `.github/`, raiz ou `docs/`, "GitHub will search for them in that order and use the first one it finds"; donos "must have write permissions for the repository"; "an approval from any of the owners is sufficient"; o arquivo vale a partir da branch base do PR; existe a proteção nativa "Require review from Code Owners". | confirmado | https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners |
| F9 | `pull_request_review` (submitted, edited, dismissed); "The GITHUB_TOKEN has read-only permissions in pull requests from forked repositories."; `pull_request_target` "runs in the context of the default branch of the base repository" e não deve construir/rodar código do PR. | confirmado | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows |
| F10 | check runs de uma ref: "'Checks' repository permissions (read)"; status combinado: "'Commit statuses' repository permissions (read)"; Get rules for a branch: "'Metadata' repository permissions (read)"; Get branch protection: "'Administration' repository permissions (read)" (inacessível ao `GITHUB_TOKEN`, F4). | confirmado | https://docs.github.com/en/rest/checks/runs, https://docs.github.com/en/rest/commits/statuses, https://docs.github.com/en/rest/repos/rules, https://docs.github.com/en/rest/branches/branch-protection |
| F11 | semantic-release: "GITHUB_TOKEN or GH_TOKEN — Required."; "pull-requests: write to be able to comment on released pull requests"; opção `branches` (padrão inclui `main`, `master`, `next`…); "requires Node version 22.14.0 or higher". O site gitbook avisa que migrou para semantic-release.org — reconferir lá na implementação. | confirmado (reconferir) | https://raw.githubusercontent.com/semantic-release/github/master/README.md, https://semantic-release.gitbook.io/semantic-release/usage/configuration, https://semantic-release.gitbook.io/semantic-release/support/node-version |
| F12 | `gh project`: "The minimum required scope for the token is: project … gh auth refresh -s project"; `field-list`, `item-list`, `view` com `--owner` e `--format json`; `item-edit --id --field-id --project-id` (e `--single-select-option-id`, a conferir na página na implementação). | confirmado | https://cli.github.com/manual/gh_project |
| F13 | `gh pr list -B/--base -H/--head`, `gh pr create`, `gh issue create`; "GitHub CLI is preinstalled on all GitHub-hosted runners. For each step that uses GitHub CLI, you must set an environment variable called GH_TOKEN". | confirmado | https://cli.github.com/manual/gh_pr_list, https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-github-cli |
| F14 | `pull_request` e `pull_request_review`: `GITHUB_SHA` = "Last merge commit on the `GITHUB_REF` branch", `GITHUB_REF` = "PR merge branch `refs/pull/PULL_REQUEST_NUMBER/merge`"; "`GITHUB_SHA` is the SHA of the merge commit on the merge branch". Logo o fluxo que roda é o do merge commit do PR, isto é, o conteúdo do próprio PR (inferência desses valores; a página não diz isso com essas palavras). Sem merge commit (conflito) o fluxo não roda. | confirmado (inferência) | https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows |

Nenhuma premissa das decisões humanas dec-014..dec-016 se mostrou falsa (dec-021).

## Pins e fontes da implementação (fechamento das pendências da Decision 3 e 7)

Lidos em 2026-09-30 com `ctx_fetch_and_index` (Princípio V). Critério de escolha: última
versão estável publicada no registro oficial, dentro do piso de Node 22 dos fluxos. Exceções,
registradas na própria linha: P13 foi reconferido em 2026-10-01 por outro meio, e P15 é decisão
da frente, não leitura de fonte.

| # | Item | Valor adotado | Fonte |
|---|------|---------------|-------|
| P1 | `semantic-release` | `25.0.9`; `engines.node` = `^22.14.0 \|\| >= 24.10.0` (Node 22 do fluxo atende) | https://registry.npmjs.org/semantic-release/latest |
| P2 | `@commitlint/cli` e `@commitlint/config-conventional` | `21.2.3` (mesma major); `engines.node` = `>=22.12.0` | https://registry.npmjs.org/@commitlint/cli/latest e https://registry.npmjs.org/@commitlint/config-conventional/latest |
| P3 | `actions/setup-node` | `v7.0.0` = `820762786026740c76f36085b0efc47a31fe5020` | https://api.github.com/repos/actions/setup-node/releases/latest e https://api.github.com/repos/actions/setup-node/commits/v7.0.0 |
| P4 | `actions/checkout` | `v7.0.1` = `3d3c42e5aac5ba805825da76410c181273ba90b1` (reconfirmado) | https://api.github.com/repos/actions/checkout/commits/v7.0.1 |
| P5 | `npm` no `ci` | `npm ci`: "The project **must** have an existing `package-lock.json`"; erra se o lock diverge do `package.json` | https://raw.githubusercontent.com/npm/cli/latest/docs/lib/content/commands/npm-ci.md |
| P6 | `pnpm` | `pnpm install --frozen-lockfile` | https://pnpm.io/cli/install |
| P7 | `yarn` | Berry: `yarn install --immutable`; v1: `yarn install --frozen-lockfile`. Escolha entre os dois pela presença de `.yarnrc.yml` (inferência: arquivo de config do Berry; não medida em fonte) | https://yarnpkg.com/cli/install e https://classic.yarnpkg.com/en/docs/cli/install |
| P8 | `bun` | `bun install --frozen-lockfile`; instalação do próprio bun por `npm install -g bun` (aba npm da página oficial) | https://bun.sh/docs/cli/install e https://bun.sh/docs/installation |
| P9 | `corepack` | acompanha o Node 22 ("Corepack will no longer be distributed starting with Node.js v25"; estabilidade "1 - Experimental"); escolhe a versão de pnpm/yarn pelo campo `packageManager` do `package.json`. O texto literal de `corepack enable` **não** foi extraído da fonte (lacuna): o `ci` usa `corepack enable` por inferência, e o projeto sem esse campo recebe a versão padrão do corepack | https://nodejs.org/docs/latest-v22.x/api/corepack.html e https://github.com/nodejs/corepack/blob/main/README.md |
| P10 | `gh project item-edit` | flags `--id`, `--project-id`, `--field-id`, `--single-select-option-id` existem; `field-list`/`item-list`/`view` aceitam `--owner`, `--format json`, `-q/--jq`, `-L/--limit` (padrão 30); `view` não tem `--limit` | https://cli.github.com/manual/gh_project_item-edit, .../gh_project_field-list, .../gh_project_item-list, .../gh_project_view |
| P11 | Filtro `branches:` com item repetido | **não documentado** (a página de sintaxe não cita duplicata). Mantém-se o plano A da Decision 7; o risco é de o provedor ignorar ou rejeitar a duplicata quando integração = produção, e a verificação final é o primeiro uso real (quickstart) | https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax |
| P12 | `state` de review na REST | exemplo oficial traz `"state": "APPROVED"` (maiúscula); o enum completo não foi extraído — o fluxo compara sem diferenciar maiúsculas e ignora `COMMENTED`/`PENDING` | https://docs.github.com/en/rest/pulls/reviews |
| P13 | `actionlint` no CI do cockpit | `v1.7.12`, asset `actionlint_1.7.12_linux_amd64.tar.gz`, SHA256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8`. Conferido em 2026-10-01 (issue #11) com `gh release download v1.7.12 --repo rhysd/actionlint`: a linha do asset em `actionlint_1.7.12_checksums.txt` e o `sha256sum` do tarball baixado dão esse valor, igual ao fixado no `ci.yml`; `releases/latest` segue em `v1.7.12` nessa data. Na frente da PR #6 o registro dizia "conferido contra o tarball baixado", mas o download para conferência tinha sido bloqueado no ambiente local e a conferência não ocorrera: o texto anterior desta linha estava errado. Método: o `ctx_fetch_and_index` falhou nesta máquina (`posix_spawn '~/.bun/bin/bun'`, ENOENT), e a leitura usou o `gh` autenticado contra o mesmo asset oficial | https://api.github.com/repos/rhysd/actionlint/releases/latest e https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_checksums.txt |
| P14 | JSON do `gh project` (usado pelo `task.sh`) | `view --format json` tem `.id` (PVT_…); `field-list` tem `.fields[]{id,name,type,options[]{id,name}}` (`options` só em single select); `item-list` tem `.items[]{id, content{title,number,url,type}, status}` (campo do projeto vira chave em camelCase, single select = nome da opção; `title` fica em `.content.title`; item rascunho não tem `number`/`url`); `--owner` aceita usuário e organização. Lido no código-fonte oficial do `gh`. Lacuna: valor literal de `type` em `field-list` e o padrão de `--limit` (o script passa `--limit 1000`) | https://raw.githubusercontent.com/cli/cli/trunk/pkg/cmd/project/shared/queries/queries.go e .../pkg/cmd/project/item-edit/item_edit.go |
| P15 | `shellcheck` no CI do cockpit | não fixado por checksum nem por versão: os jobs `shellcheck` e `configurar` rodam `apt-get install -y shellcheck` em `ubuntu-latest`, então a versão é a que o Ubuntu do runner empacota e muda quando a imagem muda (não medida). Fixar exigiria baixar o binário da release e manter versão e SHA256 à mão; o que se ganharia é reprodutibilidade, não origem. Se a verificação de assinatura do `apt` no runner cobre a origem é **não medido** (não lido em fonte oficial). Rever se o CI passar a depender de uma versão exata (issue #11) | decisão da frente; comportamento do `apt`/runner sem fonte lida |

Ajuste derivado de P12 à Decision 5: um review `COMMENTED` de um dono não desfaz a
aprovação anterior dele (comentário não é voto); vale o último review que seja aprovação,
mudança pedida ou dispensa.

## Decision 1: Todo valor de config entra no YAML por bloco literal

**Decision**: nenhum `{{CHAVE}}` fica em escalar de linha nem em expressão `${{ }}`. Comandos
entram como corpo de `run: |`; branches e gerenciador entram como `env:` com bloco
literal `|-` e são lidos pelo shell como `"$VAR"`; a lista `branches:` usa itens `- |-`.

**Rationale**: o motor insere texto literal (FR-002) e os valores são linha única (o
configurador recusa controle). Bloco literal YAML não interpreta `|`, `&`, `$`, `'`, `"`,
`#` nem `:` (edge case "valores com caracteres especiais"). Expressão `${{ }}` com valor
de config seria injeção de código.

**Alternatives considered**: aspas simples (quebra com `'` — o nome de branch pode ter);
`if:` comparando os dois nomes na expressão (mesmo problema; troca por comparação no shell).

## Decision 2: Dado de evento nunca é interpolado em `run:`

**Decision**: título do PR, número, SHAs e logins passam por `env:` (`${{ github.event.* }}`
só no valor de `env`) e o shell os lê entre aspas.

**Rationale**: título de PR é entrada de quem abre o PR; interpolado em `run:` vira comando.

**Alternatives considered**: nenhuma aceitável.

## Decision 3: `gh` e `npx` em vez de actions de terceiro

**Decision**: `promotion-pr`, `audit-merge-vermelho`, `require-codeowner-approval` e
`task.sh` usam só `gh` (pré-instalado, F13) e `--jq` do próprio `gh`; `commitlint` e
`release` rodam `@commitlint/cli` e `semantic-release` por `npx` com versão fixada.
Actions usadas: só `actions/checkout` e `actions/setup-node`, fixadas por SHA de commit
com a tag em comentário (mesmo padrão do `.github/workflows/ci.yml` do cockpit).

**Rationale**: cada action de terceiro é um pin a verificar e uma superfície de cadeia de
suprimento (CICD-SEC-8). `jq` não é dependência garantida no projeto-alvo; `gh --jq` é.

**Alternatives considered**: `peter-evans/create-pull-request`, `wagoid/commitlint-github-action`,
`cycjimmy/semantic-release-action` — mais pins, nenhum ganho.

**Pendente para a implementação** (Princípio V, via `ctx_*`, com link no registro da task):
SHA e tag de `actions/checkout` (reusar o do CI do cockpit) e `actions/setup-node`;
versões de `@commitlint/cli`, `@commitlint/config-conventional` e `semantic-release`;
opção exata `--single-select-option-id` do `gh project item-edit`; aceitação de item
repetido em `branches:` (Decision 7).

## Decision 4: Uma credencial opcional para os fluxos que criam artefato (dec-016, dec-022)

**Decision**: `release` e `promotion-pr` leem o segredo opcional `TOKEN_AUTOMACAO` (PAT ou
token de App); vazio → usam `github.token`. A escolha é feita no shell
(`GH_TOKEN="${TOKEN_AUTOMACAO:-$TOKEN_PADRAO}"`), sem operador `||` de expressão.

**Rationale**: dec-016 (humano) para o release; dec-022 estende ao `promotion-pr`, que
com `GITHUB_TOKEN` só funciona com a opção F5 ligada e deixa os checks do PR em
approval-required (F2). Um segredo só, documentado no quickstart.

**Alternatives considered**: exigir PAT (contraria dec-016); dois segredos (sem ganho).

## Decision 5: Gate de dono lê o CODEOWNERS da branch base

**Decision**: `require-codeowner-approval` roda em `pull_request` e `pull_request_review`,
lê `.github/CODEOWNERS` da **base** via API (`contents: read`), lista reviews
(`pull-requests: read`, F6), pega o último review de cada `user.login`, compara `state`
sem diferenciar maiúsculas com `approved` e passa se algum dono listado aprovou. Falha
listando os donos. Nunca aprova nem mergeia (FR-007).

**Rationale**: ler da cabeça do PR deixaria o autor se declarar dono no próprio PR. A
regra "qualquer dono basta" é a do GitHub (F8). Token somente-leitura basta, então PR de
fork funciona (F9). Só `@usuario` (dec-014, F7).

**Garantia (dec-025, block-004)**: o fluxo é **forjável** (S1): em `pull_request` e
`pull_request_review` roda o arquivo do merge commit do PR (F14), então quem abre PR de
branch do próprio repositório pode alterar o fluxo ou criar outro job com o mesmo nome e
deixar o check verde. A garantia real é a regra nativa da branch: aprovações obrigatórias
+ "Require review from Code Owners" (F8), passo **obrigatório** de setup no quickstart. O
fluxo fica como verificação extra, para visibilidade no PR.

**Alternatives considered**: só a regra nativa (sem o fluxo) — perde o check visível que
o rito cita; `pull_request_target` (roda o arquivo da base) — muda o modelo de ameaça sem
tirar a necessidade da regra nativa e fica fora do escopo desta decisão.

## Decision 6: Auditoria de merge vermelho por `pull_request_target`, sem checkout

**Decision**: `audit-merge-vermelho` em `pull_request_target: types: [closed]`, job só
quando `merged == true`; sem `actions/checkout`; permissões `checks: read`,
`statuses: read`, `issues: write`, `pull-requests: read`. Lê check runs e status do
`head.sha` (F10), filtra pelos checks obrigatórios de `GET rules/branches/{base}` quando
houver regra `required_status_checks`; sem regra legível, considera todo check vermelho e
diz na issue que a obrigatoriedade não pôde ser lida (proteção clássica exige
administração, F10). Vermelho = `failure`, `timed_out`, `cancelled`, `action_required`
(check run) ou `failure`/`error` (status). Antes de abrir, procura issue com o mesmo título
(uma por merge, dec-015).

**Rationale**: em `pull_request` de fork o token é somente-leitura (F9) e não abre issue;
`pull_request_target` roda o arquivo da base e é seguro porque nenhum código do PR é
baixado nem executado (F9).

**Alternatives considered**: `push` na base (perde o vínculo com o PR e o autor do merge).

## Decision 7: `on:` com duas branches mesmo quando iguais

**Decision**: `ci` lista `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` em `pull_request.branches` e
`push.branches`. Com integração = produção a lista tem o mesmo item duas vezes.

**Rationale**: o motor não tem condicional (FR-002). Lista YAML com item repetido é YAML
válido; se o GitHub aceita item repetido em filtro **não foi verificado** em fonte
oficial — fica como verificação da implementação (Decision 3). Plano B sem mudar o motor:
`pull_request` sem filtro de branch e `push` só com os itens.

**Alternatives considered**: condicional no motor (viola FR-002).

## Decision 8: `promotion-pr` compara as branches no shell

**Decision**: em `push` na integração, o passo lê as duas branches do `env:` (Decision 1);
iguais → mensagem e `exit 0` (FR-008). Diferentes → `gh pr list --base PROD --head INT
--state open`; existe → nada a criar (o PR aponta para a branch e se atualiza sozinho; o
fluxo reescreve só o corpo com o resumo de commits); não existe → `gh pr create`.
Permissões: `contents: read`, `pull-requests: write`.

**Rationale**: um único PR por par de branches, sem estado externo.

## Decision 9: `release` e `.releaserc.json`

**Decision**: `release` em `push` na produção; `permissions` no nível do workflow
`contents: read` e no job `contents: write`, `issues: write`, `pull-requests: write`
(F11); `fetch-depth: 0`; Node `22` (F11); `npx semantic-release@<pin>`. `.releaserc.json`:
`branches` = `["{{BRANCH_PRODUCAO}}"]` e plugins `commit-analyzer`,
`release-notes-generator`, `github` — sem `npm` (o projeto-alvo não é necessariamente
pacote publicado).

**Rationale**: FR-010/FR-011. Tag e release com `GITHUB_TOKEN` não disparam outros fluxos
(F1/F3); quem precisar disso define `TOKEN_AUTOMACAO`.

**Limite conhecido**: nome de branch de produção com `"` quebra o JSON (o configurador
aceita `"` em branch; JSON não tem forma literal sem escape). `ponytail:` aceito — branch
com aspas é raríssima; se aparecer, validar `"` no configurador.

## Decision 10: `ci` e o gerenciador de pacotes

**Decision**: um passo `Instalar dependências` com `case "$GERENCIADOR"`: `npm` → `npm ci`;
`pnpm`, `yarn`, `bun` → instalação pela forma oficial de cada um (definida e citada na
implementação); outro valor → falha com mensagem "edite este passo à mão" (FR-005).
Depois, três passos nomeados `Typecheck`, `Lint`, `Build`. Sem passo de deploy. Roda com
`PRINCIPIO_III` ligado ou desligado (FR-020): o template não usa essa chave.

## Decision 11: `commitlint`

**Decision**: `pull_request` (`opened`, `edited`, `synchronize`, `reopened`); título via
`env` + `printf '%s' "$TITULO" | npx … commitlint`; commits via `--from base.sha --to
head.sha` com `fetch-depth: 0`; regra `@commitlint/config-conventional` passada por
`--extends` (sem arquivo de config no projeto-alvo). Falha diz o formato esperado.

## Decision 12: `task.sh` sem estado e sem `jq`

**Decision**: bash, `set -euo pipefail`, `BOARD='{{BOARD}}'` (seguro: FR-015 restringe a
`dono/número`). `discover` resolve id do projeto (`gh project view`), campo `Status` e
opções (`gh project field-list`) e imprime; `move` e `list` chamam a mesma resolução a cada
execução (sem cache). Códigos de saída no contrato.

**Rationale**: cache é estado a invalidar; o board é acompanhamento (US4, P2).

## Decision 13: Validação no teste do cockpit

**Decision**: novo cenário em `scripts/testar-configurar.sh` renderiza `templates/` real com
`cockpit.config.example` (+ `DONOS_CODEOWNERS`) e com integração = produção; valida YAML com
`actionlint` (também pega injeção de expressão em `run:`), JSON com `python3 -m json.tool`,
`shellcheck` no `task.sh`, bit de execução, ausência de `{{CHAVE}}` residual, igualdade
das expressões `${{ }}` entre template e saída, e segunda execução sem alteração. No CI do
cockpit o job `configurar` instala `shellcheck` e baixa `actionlint` por versão e checksum
fixados (mesmo padrão do `gitleaks`); fora do CI, ferramenta ausente pula a checagem com
aviso — no CI, ausente é falha.

**Rationale**: FR-019; o teste já roda no CI.

**Alternatives considered**: `yq`/PyYAML (só validam sintaxe, não o schema do Actions).
