# Decisões do owner — modo-autonomo

Frente 2 do programa do ciclo autônomo (`rito-descoberta` → `modo-autonomo` → `frentes-paralelas`).
A Fase 0 foi conduzida com `/rito-descoberta` em 2026-11-05, na sessão da árvore principal, e é
também o smoke S4 da frente `rito-descoberta`. Cada decisão traz opções e recomendação pelos cinco
pilares (boas práticas, deduplicação, escalabilidade, performance e segurança) e foi validada por
especialistas VoltAgent: `qa-sec:architect-reviewer`, `qa-sec:security-auditor`,
`qa-sec:qa-expert`, `infra:deployment-engineer`, `dev-exp:git-workflow-manager` e
`dev-exp:dx-optimizer`. As decisões são normativas: o `specify` parte delas e o `clarify` não as
reabre.

Este arquivo é o 1º commit da worktree. A lista de caminhos válida é a deste commit (D11 da
`rito-descoberta`).

Base: `origin/main` em `0735cb4a9b0190057b158f939da9abc7acf42166`, conferida contra a API do
GitHub. Sem `cockpit.config` neste repositório: `REPO_REMOTO` e `BRANCH_INTEGRACAO` (`main`)
confirmados pelo owner.

Decisões do programa já tomadas pelo owner, que esta frente implementa e não reabre: modo autônomo
por projeto, com chave no `cockpit.config`; o próprio cockpit mantém gate humano; no modo ligado não
há aprovação humana de merge (CI verde → merge → smoke); trava no lugar da leitura humana (caminhos
tocados ⊆ caminhos previstos da Fase 0, dependência nova só se aprovada, fora disso é desvio e volta
ao owner); CI e smoke com até 2 correções automáticas, cada uma seguida de nova rodada do passo que
falhou, e na 3ª falha revert na integração, frente estacionada e owner com diagnóstico e
recomendação; promoção autônoma, salvo frente irreversível marcada na Fase 0; smokes do lote juntos
antes de promover; smoke em produção falho → rollback automático + revert da culpada na integração;
barreira `permissions.deny` contra os agentes proibidos (D14 da `rito-descoberta`); correção da lista
fechada "conteúdo só de agentes" achada no S3 da `rito-descoberta` (1ª das 2 correções dela).

## Escopo

- **E1.** Chave `MODO_AUTONOMO` no `configurar.sh` e no `cockpit.config.example`, linha literal
  `Merge autônomo:` na constituição semente e regra de leitura na base (D1).
- **E2.** Seção "Modo autônomo" na skill `rito-dev` e em `templates/docs/rito-dev.md.tmpl`, com
  ponteiro nas Fases 6 a 10 (D5 a D8, D11); textos de `CLAUDE.md` semente, papéis implementador e
  revisor, `project-context` semente e `LEIAME` alinhados.
- **E3.** Identidade própria do agente e ruleset conferidos na hora; sem eles, o modo vale como
  desligado (D2, D5).
- **E4.** PR de registro da Fase 0 nos projetos com modo ligado (D3), na skill `rito-descoberta`.
- **E5.** Workflow-template `caminhos-previstos` e ajustes em `require-codeowner-approval`,
  `audit-merge-vermelho`, `promotion-pr` e `CODEOWNERS` (D4, D5, D8).
- **E6.** Subcomando `historico.mjs plugin`, barreira `permissions.deny` e correção da lista fechada
  (D9, D10), com testes no CI.
- **E7.** README e contrato do configurar (`docs/specs/configurar/contracts/cli.md`).
- **E8.** Registro SDD em `docs/specs/modo-autonomo/`.

## Fora do escopo

- Maestro, paralelismo e merge queue: frente `frentes-paralelas`.
- Smoke como workflow (`workflow_run`): o agente roda o smoke e retoma o estado pelo GitHub.
- Emenda da constituição do cockpit: o cockpit mantém o gate humano e não ganha a linha
  `Merge autônomo:`.
- Criar repositório, identidade ou ruleset no GitHub por script: o `configurar.sh` só imprime
  (Princípios IV e VII).
- Limpeza dos registros órfãos de plugin em `installed_plugins.json` e a issue #26.

## Caminhos previstos

Só caminho literal ou `dir/**`, relativo à raiz do repositório.

```text
skills/rito-dev/SKILL.md
skills/rito-descoberta/**
templates/docs/rito-dev.md.tmpl
templates/docs/constitution.md.semente.tmpl
templates/docs/project-context.md.semente.tmpl
templates/CLAUDE.md.semente.tmpl
templates/docs/agentes/implementador.md.tmpl
templates/docs/agentes/revisor.md.tmpl
templates/.github/workflows/caminhos-previstos.yml.tmpl
templates/.github/workflows/require-codeowner-approval.yml.tmpl
templates/.github/workflows/audit-merge-vermelho.yml.tmpl
templates/.github/workflows/promotion-pr.yml.tmpl
templates/.github/CODEOWNERS.tmpl
templates/.cockpit/LEIAME.md.tmpl
configurar.sh
cockpit.config.example
scripts/testar-configurar.sh
.github/workflows/ci.yml
README.md
docs/specs/configurar/contracts/cli.md
docs/specs/modo-autonomo/**
```

## Decisões

Todas na opção A, com os ajustes dos validadores incorporados. Resposta do owner: "todas como
recomendadas".

- **D1. Chave e fonte da verdade do modo.**
  - Chave `MODO_AUTONOMO` (`ligado` ou `desligado`) no `cockpit.config`, **opcional**: ausente ou
    inválida vale `desligado` (o `--atualizar` não quebra nos projetos já configurados); a pergunta
    interativa sugere `desligado`.
  - O configurar grava na constituição semente a linha literal `Merge autônomo: ligado` ou
    `Merge autônomo: desligado`; o Princípio II da semente ganha os dois ramos, como o III.
  - O rito lê só essa linha em `origin/<BRANCH_INTEGRACAO>:docs/constitution.md`, com a regra da
    linha "Instalação pelo agente" (exatamente uma linha válida; qualquer outra coisa é
    `desligado`), escrita uma vez e citada nas duas skills. Relê antes de cada merge e de cada
    promoção.
  - `ligado` só vale com a identidade do D2 e o ruleset do D5 conferidos na hora.
  - O agente MUST NOT editar a linha nem a chave (MUST NOT na semente, ao lado da linha de
    instalação). O `rito-dev.md.tmpl` não renderiza o valor (é re-renderizado e divergiria da
    constituição). `MODO_AUTONOMO` entra na lista de chaves que o rito não consome.
  - Projetos já ratificados seguem com gate humano até emenda própria. O cockpit não tem a linha.
  - Alternativas recusadas: ler a chave direto do `cockpit.config` (a semente diria o contrário do
    comportamento); só a linha, sem chave (contraria a decisão do owner).
  - Validação: `architect-reviewer` e `security-auditor`, concordam com ajuste.
- **D2. Identidade do agente nos projetos com modo ligado.**
  - Identidade própria (conta de máquina com token fine-grained, ou GitHub App) com escrita só em
    Contents e Pull requests, sem Administration nem Workflows; regra da branch por ruleset sem
    lista de bypass. O token fica fora do repositório.
  - Sem a identidade conferida na hora, o modo vale como `desligado`.
  - Motivo: com o token do owner (admin), push direto por bypass, `--admin`, mudança da regra e
    workflow novo contornam D3 a D5; sem Workflows, o agente não altera o próprio CI.
  - Alternativas recusadas: token do owner com limite declarado; adiar para frente própria.
  - Validação: `security-auditor`, que levantou o ponto.
- **D3. De onde a trava lê o plano aprovado.**
  - No modo ligado, logo depois do Gate 0, o `decisoes-do-owner.md` vai numa PR de registro
    própria, aprovada e mergeada pelo owner: é o OK do Gate 0 gravado no GitHub. A trava lê o
    registro na base, nunca no PR. O 1º commit da worktree e o gate da Fase 11 seguem como hoje.
  - Alternativa recusada: ler do 1º commit do próprio PR, mesmo com force-push bloqueado (o agente
    escreveria o plano e o código no mesmo PR: a trava conferiria o agente contra o agente).
  - Validação: `deployment-engineer` (propôs ler na base) e `security-auditor`.
- **D4. Trava de caminhos.**
  - Workflow-template `caminhos-previstos` em `pull_request_target`: roda o arquivo da branch
    padrão, sem checkout nem execução de código do PR, só API; publica status no SHA do HEAD com
    fonte fixada; check obrigatório no ruleset do modo ligado.
  - Reprova: arquivo fora do bloco "Caminhos previstos" do registro na base
    (`docs/specs/<frente>/**` implícito); renomeação confere o nome novo e o anterior; total listado
    diferente de `changed_files` (paginação, teto da API); caminho de governança —
    `docs/constitution.md`, `cockpit.config`, `.github/**`, `CODEOWNERS`, `.claude/**`, `.mcp.json`,
    `.npmrc`, `.yarnrc.yml`, `.husky/**`, `CLAUDE.md`, configuração do commitlint —, salvo acréscimo
    puro em `permissions.deny` (comparação por `jq` entre o blob da base e o do HEAD); manifesto ou
    lockfile sem item permanente aprovado.
  - PR sem registro (docs, trivial, hotfix) ou de governança só passa com aprovação de dono no
    commit atual, reexecutado depois da aprovação (nunca por `pull_request_review`, que roda o
    arquivo do PR).
  - PR de correção ou de revert só toca arquivos da PR original da frente, referenciada por número e
    mergeada na mesma base. A frente sai do registro, nunca do título nem da branch.
  - A trava roda também em PR para a produção e é check obrigatório nas regras dela, com contexto
    próprio. Passa sozinha só a PR de promoção (D8): origem na branch de integração, no mesmo
    repositório. Qualquer outro PR para a produção exige aprovação de dono no commit atual
    (emenda de 2026-11-06, block-001). O workflow precisa estar na branch padrão.
  - Alternativas recusadas: só a skill confere (o agente confere a si mesmo); skill e CI juntas (dois
    parsers do mesmo bloco).
  - Validação: `deployment-engineer`, `security-auditor` e `architect-reviewer`, concordam com
    ajuste.
- **D5. Mecanismo do merge.**
  - `gh pr merge <n> --auto --squash`. Antes de ligar o auto-merge, o agente confere no GitHub o
    ruleset da integração: sem bypass e com `ci`, `commitlint` e `caminhos-previstos` obrigatórios.
    Fora disso, vale `desligado` e o rito para no gate humano.
  - Nunca `--admin`; `permissions.deny` para ele como camada extra. Branch apagada pela configuração
    do repositório, não por `--delete-branch`.
  - No modo ligado, `require-codeowner-approval` lê a linha na base e passa com aviso (não é
    obrigatório); o `audit-merge-vermelho` não pode abrir issue a cada merge autônomo.
  - O configurar só imprime a configuração do GitHub (ruleset, auto-merge, identidade).
  - Alternativas recusadas: o agente espera o CI e mergeia (a barreira volta a ser o agente); merge
    queue (fica para a `frentes-paralelas`).
  - Validação: `deployment-engineer` e `security-auditor`, concordam com ajuste.
- **D6. Correções e frente estacionada.**
  - Contadores separados: até 2 correções de CI e até 2 de smoke, como na decisão do owner (o
    `qa-expert` sugeriu contador único; não incorporado).
  - CI vermelho antes do merge: correção por commit na mesma branch, contando SHAs distintos com
    falha (rerun não conta). No 3º vermelho: `gh pr merge --disable-auto`, PR em rascunho com rótulo
    `estacionada`, diagnóstico e recomendação ao owner.
  - Smoke falho na integração: conta só se o run foi no merge commit da frente (outro SHA volta ao
    owner). Correção por PR nova a partir de `origin/<integração>`, fora da worktree da frente, com
    rótulo `correcao-<n>`; contagem por `gh pr list --state all`; branch remota existente é
    retomada, não recriada.
  - Na 3ª falha: reverts um por vez, em ordem inversa (correções primeiro), cada um esperando o
    merge do anterior. Revert com conflito ou com CI vermelho para e volta ao owner, sem laço. Frente
    estacionada: worktree mantida, Fase 11 não roda.
  - Ambiente de integração inutilizável (fluxo crítico fora, afetando outras frentes): reverte
    primeiro, corrige depois. Falha isolada no fluxo da frente: corrige.
  - Alternativas recusadas: correção na branch da frente (apagada depois do squash); revert na 1ª
    falha (contraria a decisão do owner).
  - Validação: `git-workflow-manager` e `deployment-engineer`, concordam com ajuste.
- **D7. Smoke autônomo e elegibilidade.**
  - Cada item do Smoke da Fase 0 no formato `Sn | comando | esperado literal | tipo`, com asserção
    além do exit code e ao menos um caso negativo; congelado no Gate 0 (mudar exige OK do owner).
  - Frente sem item executável fica com gate humano no merge. Irreversibilidade diferente de
    "Nenhuma": merge autônomo na integração e parada no gate da promoção.
  - Alternativas recusadas: smoke sempre humano; navegador automatizado.
  - Validação: `qa-expert`, concorda com ajuste.
- **D8. Promoção, lote e rollback.**
  - Lote = o que está na integração e não na produção. Um smoke combinado roda no SHA fixado da
    integração, com resultado por frente; só esse SHA é promovido (ponta mudou, roda de novo). Lote
    com frente irreversível ou com smoke manual para no gate humano.
  - PR de promoção pelo `promotion-pr` com `TOKEN_AUTOMACAO` obrigatório no modo ligado (PR criada
    com o `GITHUB_TOKEN` não dispara o CI); `--auto --merge`, com merge commit permitido conferido;
    rollback anotado antes (SHA pré-promoção).
  - Smoke em produção falho: revert da promoção como contenção (mais o deploy manual, quando houver),
    revert da culpada na integração (D6) e owner. A próxima promoção começa com o revert do revert,
    para o resto do lote voltar à produção. Sem culpada isolável, reverte o lote.
  - Integração = produção: a Fase 9 segue no-op e o rollback é o D6. O `release.yml` transforma
    rollback em versão nova (documentar).
  - Alternativas recusadas: promoção sempre humana; promoção por frente.
  - Validação: `deployment-engineer` discordou da forma inicial (revert de merge commit sem revert
    do revert deixa o resto do lote fora da produção; promoção sem SHA fixado; `GITHUB_TOKEN`); a
    forma acima é a correção dele.
- **D9. Barreira `permissions.deny`.**
  - Subcomando `historico.mjs plugin <installPath>`, só leitura, saída JSON: veredito da lista
    fechada (D10), regras `permissions.deny` dos agentes que reprovam nas regras (a), (b) e (c) —
    todos os `.md` de agente do plugin, citados ou não — e o SHA. Falha fechado com symlink e com
    `installPath` fora de `~/.claude/plugins/cache`.
  - A skill mescla as regras (união, idempotente) no `.claude/settings.json` da worktree, mais
    `deny` de Edit e Write em `.claude/settings*.json`. Nos projetos-alvo vai na PR, como acréscimo
    puro (D4); no cockpit, `.claude/` é ignorado pelo git e a escrita vai ao histórico.
  - Roda de novo no gate da Fase 11 e no estado "SHA divergente"; reprova se o deny gravado não
    cobre o conjunto atual.
  - A sintaxe da regra para agente de plugin é confirmada em fonte oficial antes do plan e provada
    no smoke; regra que não bloqueia para o rito.
  - Alternativas recusadas: lista estática na skill; hook próprio do cockpit (Princípio IV); deny
    global em `~/.claude/settings.json`.
  - Validação: `dx-optimizer` e `security-auditor`, concordam com ajuste.
- **D10. Lista fechada "conteúdo só de agentes".**
  - `.in_use/`: diretório só com arquivos regulares de nome `^[0-9]+$`, sem subdiretório nem
    symlink; ENOENT tolerado na varredura (os PIDs mudam). `.orphaned_at`: arquivo regular.
  - `.md` na raiz do plugin fora do array `agents`: aceito só com frontmatter de agente nas mesmas
    regras e `name` sem colisão com o array; `README.md` é exceção explícita. Entra no cálculo do
    D9.
  - Qualquer outro arquivo ou diretório continua reprovando.
  - Alternativas recusadas: aceitar só `.in_use/` e `.orphaned_at` (o `voltagent-dev-exp` sairia do
    mapa); ignorar dotfiles (`.mcp.json` é dotfile).
  - Validação: `security-auditor` e `dx-optimizer`, concordam com ajuste.
- **D11. Forma do produto.**
  - Uma seção "Modo autônomo" na skill `rito-dev` e no template, com uma linha de ponteiro em cada
    Fase de 6 a 10; o ramo desligado fica igual ao de hoje. `CLAUDE.md` semente e papéis apontam
    para o Princípio II em vez de repetir a regra.
  - Alternativas recusadas: skill nova (duplica as fases); dentro do cstk (Princípio IV).
  - Validação: `architect-reviewer`, concorda com ajuste.
- **D12. Agente de stack e instalações.**
  - Agente de stack `infra:deployment-engineer` (CI/CD, merge, rollback), com exceção declarada no
    mapa (a linha de stack prevê `lang:` ou `core-dev:`, e não há agente de bash no `lang:`).
  - Usado só como validador na sessão da árvore principal, com prompt de somente leitura (roda com
    `model: haiku` no SHA conferido); não é citado na descrição do `/feature-00c`, porque não carrega
    na worktree.
  - Instalações previstas: nenhuma. Na worktree, a conferência pós-install reprovaria pela `.in_use/`
    até o D10 entrar.
  - Validação: `architect-reviewer` e `dx-optimizer`, concordam com ajuste.
- **D13. Smoke desta frente:** ver a seção "Smoke".
  - Validação: `qa-expert` e `security-auditor`, concordam com ajuste.

## Mapa papel→agente

Catálogo `voltagent-subagents` no SHA `ed74d115b7fb7026a22a4f816a8e3250f425e3b4`, igual ao `HEAD`
do clone, com `status --porcelain` vazio: o mapa da skill `rito-descoberta` vale sem reverificação.

| Domínio nesta frente | Agente |
|---|---|
| arquitetura, estrutura, deduplicação | `qa-sec:architect-reviewer` |
| segurança, credencial, permissões | `qa-sec:security-auditor` |
| qualidade, smoke, testes | `qa-sec:qa-expert` |
| CI/CD, merge, rollback (e stack, D12) | `infra:deployment-engineer` |
| git | `dev-exp:git-workflow-manager` |
| ferramentas, CLI, scripts | `dev-exp:dx-optimizer` |

Verificação de plugins na árvore principal: `voltagent-qa-sec`, `voltagent-infra` e
`voltagent-dev-exp` em `-s project`, habilitados, `gitCommitSha` igual ao SHA do mapa, sem chaves
proibidas no `plugin.json` e frontmatter só com chaves permitidas. A lista fechada "conteúdo só de
agentes" reprova os três pela `.in_use/` e o `voltagent-dev-exp` também pelo `docs-drift-editor.md`
na raiz, fora do array `agents` (achado novo; o agente não carrega na sessão). Exceção declarada
pelo owner para usar os três como validadores desta Fase 0; a correção é o D10.

Na worktree, nenhum plugin VoltAgent é necessário: "ausente" é o estado esperado e não pede ação.

## Regra de proibidos

A da skill `rito-descoberta`, sem mudança nos critérios (a), (b) e (c). Esta frente acrescenta a
barreira técnica `permissions.deny` (D9), que substitui o "limite declarado" do D14 da
`rito-descoberta` para os plugins do mapa. Nesta Fase 0 os controles foram o prompt de somente
leitura dos validadores e a foto antes e depois da rodada.

## Instalações previstas

Nenhuma.

## Smoke

Pós-merge, executado pelo agente na sessão da árvore principal e relatado ao owner (as Fases 8 a 10
do rito são no-op neste repositório). No CI, antes do merge:

- `scripts/testar-configurar.sh`: chave ausente, inválida (`Ligado`, vazia) e `desligado` geram
  `Merge autônomo: desligado`; `ligado` gera `Merge autônomo: ligado`; o `--atualizar` de projeto
  sem a chave não falha.
- Testes do `historico.mjs plugin` com fixtures: plugin limpo passa; `.in_use/` com nome não
  numérico, subdiretório ou symlink reprova; `.md` da raiz com chave extra ou `name` colidente
  reprova; `hooks/`, `.mcp.json` e executável reprovam; symlink e `installPath` fora do cache
  reprovam; nome com `..`, plugin duplicado e lista vazia falham.

Depois do merge:

- **S1.** `cp -r` de `skills/rito-descoberta` e `skills/rito-dev` a partir da `main` para
  `~/.claude/skills/`; `diff -r` vazio e `name:` correto no frontmatter.
- **S2.** `historico.mjs plugin` nos três plugins da árvore principal dá "ok"; as regras deny saem
  com o SHA.
- **S3.** Repositório descartável criado pelo owner (público e sem segredos, ou privado se o plano
  da conta tiver ruleset e auto-merge), com a identidade do D2, ruleset e auto-merge. Precondições
  conferidas por comando (visibilidade, ruleset com os checks obrigatórios e sem bypass, linha
  `Merge autônomo: ligado` na base).
  - Uma frente trivial ponta a ponta: PR de registro aprovada pelo owner, merge autônomo, smoke.
  - Falha roteirizada: CI vermelho com auto-merge ligado não mergeia; smoke vermelho pós-merge →
    2 PRs de correção → reverts na 3ª, contados por `gh pr list`.
  - Casos negativos que param: caminho fora da lista; constituição; job homônimo
    `caminhos-previstos` noutro workflow; renomeação a partir de `.github/**`; `.claude/settings.json`
    com hook; push direto e `--admin` com a credencial do agente; status forjado por API; PR que se
    declara de outra frente; PR sem registro sem aprovação; revert com CI vermelho (para, sem laço);
    linha ausente ou inválida (vale desligado); frente irreversível para na promoção.
  - No fim, o owner apaga o repositório e revoga a credencial.
- **S4.** Na sessão da worktree de uma frente, a regra deny gravada bloqueia um agente proibido.
- **S5.** A Fase 0 da `frentes-paralelas` roda com o registro novo (PR de registro só no modo
  ligado; aqui, desligado).
- **Falha:** até 2 correções, cada uma por PR com gate. Na 3ª, PR de revert na `main` (com gate) e
  diagnóstico ao owner.

## Telas

Não há: a frente não tem interface.

## Irreversibilidade

Nenhuma. A frente muda Markdown, bash, YAML e JavaScript, e tudo se desfaz com revert por PR. O
repositório descartável do S3 e a credencial dele são criados e apagados pelo owner.

## Dependências novas

Nenhuma no repositório. Os workflows usam só o `gh` e o `jq` do runner e as actions já fixadas por
SHA.

## Histórico

Log em `~/.claude/cockpit/historico-modo-autonomo.log`, com a linha de base ao lado. Cópia
versionada: `$HOME` vira `~`, a máquina vira `<máquina>`, hashes de conteúdo viram `<hash>`.

- 2026-11-05T22:53:10Z · `~/ciclo_dev` · `main` · **base** ·
  `~/.claude/cockpit/historico-modo-autonomo.base`, 31584 linhas
- 2026-11-05T22:57:45Z · `~/ciclo_dev` · `main` · **rodada** · pesquisa oficial via context-mode e
  `git fetch origin main`: criados=0 apagados=0 alterados=0
- 2026-11-05T23:04:57Z · `~/ciclo_dev` · `main` · **rodada** · antes da 1ª rodada de validadores:
  criados=0 apagados=0 alterados=0
- 2026-11-05T23:14:33Z · `~/ciclo_dev` · `main` · **rodada** · depois da 1ª rodada de validadores
  (6: architect-reviewer, security-auditor, deployment-engineer, git-workflow-manager, qa-expert,
  dx-optimizer): criados=0 apagados=0 alterados=0
- 2026-11-05T23:46:15Z · `~/ciclo_dev` · `main` · **gate0** · OK "ok para todas as ondas"
- 2026-11-05T23:46:27Z · `~/ciclo_dev-modo-autonomo` · `feat/modo-autonomo` · **worktree** · `main`
  `0735cb4a9b0190057b158f939da9abc7acf42166`
- 2026-11-05T23:46:28Z · `~/ciclo_dev` · `main` · **rodada** · `parallel-work` (comando declarado
  no Gate 0): criados=1 apagados=0 alterados=1
  - `+ git worktree ~/ciclo_dev-modo-autonomo branch refs/heads/feat/modo-autonomo`
  - `~/ciclo_dev/.git/config` alterado (tracking da branch nova)

Fora das raízes da foto: o `/tmp` foi conferido antes e depois da rodada de validadores. Apareceram
quatro arquivos `.ts` de outra sessão do Claude na máquina, de outro projeto, sem relação com esta
frente. Nenhum validador escreveu. Helpers desta sessão ficaram só no scratchpad dela. Risco que
fica: escrita fora das raízes da foto e qualquer coisa feita como root.

## Pendências para a research do plan

Via `ctx_fetch_and_index` (Princípio V), antes de afirmar no artefato:

- sintaxe da regra `permissions.deny` para agente de plugin e para Edit e Write em caminho, e a
  precedência entre `settings.json` e `settings.local.json` do projeto;
- status publicado por `pull_request_target` valendo como check obrigatório no HEAD do PR, e
  fixação da fonte esperada;
- `GET rules/branches` devolve só rulesets?; ruleset sem bypass; ruleset e auto-merge em repositório
  privado conforme o plano da conta;
- permissões de token fine-grained (Contents, Pull requests, Workflows, Administration) e de GitHub
  App;
- merge feito pelo auto-merge dispara `push` e `pull_request` `closed` como o manual?;
- eventos criados com o `GITHUB_TOKEN` não disparam workflows;
- `gh pr revert` em PR mergeada por merge commit e por squash; versão mínima do `gh`;
- `pulls/N/files`: paginação, teto de arquivos e `previous_filename`.

Fontes já lidas nesta Fase 0: <https://cli.github.com/manual/gh_pr_merge>,
<https://cli.github.com/manual/gh_pr_revert>,
<https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request>,
<https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows>,
<https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches>,
<https://code.claude.com/docs/en/sub-agents>, <https://code.claude.com/docs/en/permissions> e
<https://code.claude.com/docs/en/plugins-reference>.

## OK do owner

Em 2026-11-05, na sessão da árvore principal:

- parâmetros: "Sim, use esses (Recomendado)";
- validadores com a lista fechada reprovada: "Usar os 3, exceção declarada (Recomendado)";
- decisões D1 a D13: "todas como recomendadas";
- OK final: "ok para todas as ondas".

O OK para todas as ondas cobre: a worktree; este arquivo como 1º commit; `cstk hooks install` e
`cstk mcp install`; todas as ondas do `/feature-00c` com os spawns liberados em auto mode;
`bmad-code-review` até zerar achados altos e críticos; commit, push, PR e CI. A sessão para no gate
de merge, que continua com o owner (o cockpit mantém gate humano). Depois do merge: smoke e Fase 11.

Em 2026-11-06, na sessão da worktree (`/feature-00c`, gate `owasp-security` do plan, block-001):

- PR direto para a produção fora da trava (crítico): "A1: trava também na prod (Recomendado)".
  Emenda a D4 acima.
- configuração do semantic-release com o `TOKEN_AUTOMACAO` (alto): "A2: config vira governança
  (Recomendado)". `.releaserc*`, `release.config.*` e a chave `release` do `package.json` entram na
  lista de governança da D4. O token é de GitHub App ou fine-grained de identidade não dona,
  restrito ao repositório, nunca o pessoal do owner. O `release.yml` não muda.
- registro forjado (alto): "Confirmo (Recomendado)". Todo `docs/specs/*/decisoes-do-owner.md` é
  caminho de governança.
- checklist de segurança: CHK015 "Emendar agora"; CHK026 "Coberto pela D8" (o modo autônomo nunca
  promove lote com frente irreversível); CHK033 "Aceito, documentado" (`extends` para arquivo
  local, limitado aos caminhos previstos aprovados e ao escopo do token); CHK034 "Aceito como
  decidido" (promoção autônoma salvo frente irreversível marcada na Fase 0).

Em 2026-11-06, na rodada 1 do `bmad-code-review` (achados em `review-findings.md`):

- contenção na produção: "Texto declara a espera (Recomendado)". A A1 continua valendo: o revert da
  PR de promoção é PR para a produção e exige aprovação de dono. O agente abre o revert na hora e
  avisa o owner com diagnóstico, e o texto do rito diz que a contenção aguarda essa aprovação.
- autoria na trava: "Só rejeitar fork (Recomendado)". PR cuja cabeça está em outro repositório
  exige dono. O autor não é conferido pela trava (limite conhecido): a identidade segue conferida
  pelo agente antes do merge (P1 a P5).
- reordenação de chaves no `.claude/settings.json`: "Alinhar a spec ao código (Recomendado)".
  Reordenar chave JSON não muda efeito, e a FR-009 deixa de citar "reordenar".
- `CLAUDE.md` e `.claude/` em subpastas: "Governança em qualquer pasta (Recomendado)".
  `CLAUDE.md` e `CLAUDE.local.md` em qualquer pasta, e qualquer componente `.claude/` do caminho,
  são governança. Fonte: <https://code.claude.com/docs/en/memory> (`CLAUDE.md` e `CLAUDE.local.md`
  de subpasta carregam sob demanda).

Em 2026-11-06, na rodada 2 do `bmad-code-review`:

- promoção: "Merge direto em X (Recomendado)". Emenda a D8. O agente espera os checks
  obrigatórios verdes com a cabeça da PR de promoção em X e faz `gh pr merge <n> --merge
  --match-head-commit X`, sem `--auto`. Com cabeça diferente o GitHub recusa (REST de merge: "409
  Conflict if sha was provided and pull request head did not match",
  <https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request>).
- histórico da frente: "Arquivo próprio (Recomendado)". O histórico vai para
  `docs/specs/<frente>/historico.md`, nos dois modos. O registro fica intocado depois do Gate 0.
  Emenda a decisão de `docs/specs/rito-descoberta/decisoes-do-owner.md` (histórico copiado para o
  registro antes da PR).

Em 2026-11-06, na rodada 3 do `bmad-code-review`:

- emenda do registro durante a frente: "Emenda por PR aprovada (Recomendado)". No modo ligado, o
  registro só muda por PR de registro própria, aprovada pelo owner (governança). Depois do merge, a
  trava passa a valer pela versão emendada, porque a aprovação do owner é o gate. Por isso
  "registro intocado depois do Gate 0" e a D11 da `rito-descoberta` ("caminho acrescentado depois
  não amplia o limite") passam a valer "sem aprovação do owner". No modo desligado segue como hoje.
