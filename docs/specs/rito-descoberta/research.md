# Research: rito-descoberta

Phase 0 do `/plan`. Resolve as pendências de `decisoes-do-owner.md` (seção "Pendências para a
research do plan") e as incógnitas de desenho. Não reabre D1 a D19.

## Fontes

Fonte externa só via `ctx_fetch_and_index` e `ctx_search` (Princípio V), lida em 2026-11-05 por
um subagente `general-purpose` com WebFetch, WebSearch e curl proibidos no prompt (D5). Conteúdo
indexado tratado como dado.

| # | URL |
|---|---|
| U1 | https://code.claude.com/docs/en/plugins/cli-reference |
| U2 | https://code.claude.com/docs/en/plugins/loading |
| U3 | https://code.claude.com/docs/en/plugins/marketplace-reference |
| U4 | https://code.claude.com/docs/en/discover-plugins |
| U5 | https://code.claude.com/docs/en/worktrees |
| U6 | https://code.claude.com/docs/en/settings |
| U7 | https://docs.npmjs.com/cli/v10/commands/npm-install |
| U8 | https://docs.npmjs.com/cli/v10/using-npm/config |
| U9 | https://pnpm.io/cli/install |
| U10 | https://classic.yarnpkg.com/en/docs/cli/install |
| U11 | https://yarnpkg.com/configuration/yarnrc |
| U12 | https://yarnpkg.com/cli/install |
| U13 | https://pip.pypa.io/en/stable/topics/secure-installs/ |
| U14 | https://pip.pypa.io/en/stable/cli/pip_install/ |

Também consultadas, sem trecho citado aqui: `https://code.claude.com/docs/en/plugins-reference`,
`https://code.claude.com/docs/en/plugin-marketplaces`, `https://code.claude.com/docs/en/cli-reference`
e `https://code.claude.com/docs/en/plugins/install` (as três primeiras hoje apontam para U1 a U3).

Fontes locais, somente leitura, na máquina da frente:

- **L1.** `claude plugin <sub> --help` do Claude Code `2.1.318`.
- **L2.** Chaves observadas por `jq` em `~/.claude/plugins/installed_plugins.json`,
  `claude plugin list --json` e `claude plugin marketplace list --json`.
- **L3.** Clone do catálogo em `~/.claude/plugins/marketplaces/voltagent-subagents`.

L2 e L3 são medição de uma versão da CLI, não documentação: valem como "observado em 2.1.318".

## Decision 1: Campos para classificar o estado do plugin (D7)

**Decision**: o estado sai de `claude plugin list --json` (`id`, `scope`, `projectPath`,
`enabled`, `version`) e o SHA sai de `installed_plugins.json` (`gitCommitSha`), lido por `jq`.
`gitCommitSha` ausente na entrada = estado "desconhecido" (falha fechado).
**Rationale**:
- U1 lista os campos de `list --json`: `id`, `version`, `scope`, `enabled`, `installPath`,
  `readFromFolder`, `folderVersion`, `installedAt`, `lastUpdated`, `projectPath`, `mcpServers`,
  `errors` e `notes`. Citações: "`projectPath` | string | Project the install belongs to. `project`
  and `local` scope only"; `enabled` é "Whether the plugin is enabled in your merged settings".
- `list --json` não traz SHA. L2 confirma em 2.1.318: as chaves são `enabled`, `id`,
  `installPath`, `installedAt`, `lastUpdated`, `mcpServers`, `projectEnabled`, `projectPath`,
  `scope` e `version`.
- `gitCommitSha` **não aparece na documentação oficial** (busca sem resultado em U1 a U6).
  Existe em L2: as entradas de `installed_plugins.json` têm `directoryRepositoryKey`,
  `gitCommitSha`, `installPath`, `installedAt`, `lastUpdated`, `projectPath`, `scope` e
  `version`, e o arquivo tem `enabledPlugins` no topo. O campo é medição, não contrato: por isso
  o caso ausente falha fechado.
- `list` mostra entradas de todos os projetos. Por isso o filtro de D7 é
  `scope == "project"` e `projectPath` igual à raiz.

**Alternatives considered**: usar `projectEnabled` (L2), que não está no trecho lido de U1;
descartado, porque `enabled` está documentado.

## Decision 2: Escopo, padrão do uninstall e onde fica `enabledPlugins` (D13, D18)

**Decision**: todo `install`, `enable` e `uninstall` de plugin leva `-s project` explícito. O
escopo project grava `enabledPlugins` em `<raiz>/.claude/settings.json`, que entra na foto por
hash.
**Rationale**:
- U1, sobre o install: "Installation scope: `user`, `project`, or `local`. Defaults to `user`".
- U1, sobre o uninstall: "Uninstall from scope: `user`, `project`, or `local`. Defaults to `user`".
- U4: "Project scope: ... The entry goes in `.claude/settings.json`, which you commit."
- U4: "`enable` and `disable` act on the most specific scope whose settings already list the
  plugin. `install` and `uninstall` act on user scope." Sem `-s project`, o uninstall erra o
  escopo, o que confirma D18.
- L1 em 2.1.318: `enable -s` tem "(default: auto-detect)". O `-s project` explícito evita a
  detecção.

**Alternatives considered**: deixar o escopo implícito no `enable`. Descartado, porque a detecção
depende do que já estiver nas settings.

## Decision 3: Worktree (D13)

**Decision**: a verificação roda na raiz onde o agente vai ser usado. Se a worktree não herda o
`enabledPlugins` (settings do projeto não versionado), o plugin conta como "desabilitado" ou
"ausente" ali, e o item listado se aplica na worktree, com `-s project`.
**Rationale**:
- U5: "plugins installed at project scope from the main checkout also load in worktrees of the
  same repository, so you don't need to reinstall them per worktree".
- Mas U4 põe a entrada em `.claude/settings.json`, "which you commit". Neste repositório esse
  arquivo não é versionado (`git ls-files .claude/settings.json` vazio na worktree). A árvore
  principal tem os quatro `voltagent-*` em `enabledPlugins`; a worktree, não.
- L2 em 2.1.318: rodando `claude plugin list --json` na worktree, as quatro entradas aparecem
  com `projectPath` da árvore principal, `enabled: false` e `projectEnabled: false`.
- U6: "In a worktree, it uses the file at the main checkout's root" (sobre o
  `settings.local.json`).

**Não verificado**: se o `install` rodado dentro da worktree grava em `projectPath` o caminho dela
ou o da árvore principal (U1 a U6 não dizem). O S3 mede isso, porque instala na worktree e confere
o estado.

**Alternatives considered**: confiar só em U5. Descartado pela medição L2 neste repositório.

## Decision 4: O install relê o catálogo e a fixação de SHA (D7, D17)

**Decision**:
- Antes do install, a skill confere que o HEAD do clone do catálogo é o SHA registrado (S2).
- Depois do install, confere o `gitCommitSha` contra o registrado. Divergente: desinstala com
  `-s project` e para (D17).
- A skill não fixa ref nem SHA por conta própria: isso exigiria `marketplace add` com `#ref`, um
  item que teria de constar da lista do Gate 0.

**Rationale**:
- U2: "When you install a plugin, Claude Code looks it up in its local copy of the marketplace
  catalog."
- U2, na tabela de refresh: "`name@marketplace` | `/plugin install` or `claude plugin install` |
  The named marketplace, before the lookup". **O install com `@marketplace` atualiza o
  marketplace antes de buscar o plugin.** Por isso o clone pode sair do SHA registrado no próprio
  install do S3.
- U1, sobre o `marketplace add`, que aceita `owner/repo#ref` ou `owner/repo@ref`: "Clones the
  GitHub repository, pinned to `ref` when given".
- U3: `ref` (branch ou tag) na source de marketplace. `sha` aparece na source de **plugin**:
  "When you set both `ref` and `sha`, Claude Code checks out `sha`".
- **Não verificado**: se a source de marketplace aceita `sha`, e o que faz o install com o nome
  do plugin sozinho (a linha da tabela de U2 foi cortada).

**Achado para o owner, sem reabrir D16**: o comando aprovado no S3,
`claude plugin install voltagent-core-dev@voltagent-subagents -s project`, pode mover o catálogo.
Se mover, a foto mostra o HEAD novo do catálogo e o `gitCommitSha` diverge. Pelo D17, o agente
desinstala e para. O achado volta ao owner, como prevê o S3.

**Alternatives considered**: instalar pelo nome sozinho (comportamento não verificado e diferente
do item listado, logo desvio de D16); bloquear agora (nada se instala durante a construção).

## Decision 5: `-y`, `--accept-command`, `--prune`, `--marketplace` (D17, D18)

**Decision**:
- `claude plugin install` nunca leva `-y`, `--accept-command` nem `--marketplace`.
- `uninstall` nunca leva `--prune` nem `-y`.
- `claude plugin prune` nunca roda.

**Rationale**:
- U1, sobre o `-y` do install: "Accept the displayed install command without the `Run this
  command now?` prompt". O `--accept-command` aceita o comando "whose `sha256` a previous `--json`
  run reported". Os dois aceitam comando declarado pelo marketplace (proibidos em D17).
- U1, sobre o `--prune`: "Also remove auto-installed dependencies that no remaining plugin needs".
  Pode remover dependência que já estava na máquina antes da frente, e D18 proíbe isso.
- U1: no uninstall, o `-y` só existe para o `--prune`. Sem `--prune`, não há `-y`.
- L1 em 2.1.318, sobre o `--marketplace`: "A marketplace not added yet is added first, in user
  settings". É um `marketplace add` implícito, fora da lista.

**Alternatives considered**: nenhuma; D17 já decide e aqui só se confirmam as flags.

## Decision 6: `marketplace add` e `marketplace remove` (D17, D18)

**Decision**:
- `marketplace add` é sempre temporária (D17).
- `marketplace remove` só vale para marketplace que **não** está na linha de base, isto é, um
  adicionado pela própria frente.

**Rationale**:
- U2: o `marketplace add` grava "to `extraKnownMarketplaces` in your user settings as well as to
  disk"; `known_marketplaces.json` é "one ... per user". Isso confirma o escopo global de D17.
- U1, sobre o `marketplace remove` no último escopo: "Claude Code also deletes its cache and
  uninstalls every plugin you installed from it". Remover um marketplace da linha de base
  desinstalaria plugins anteriores à frente, o que D18 proíbe.
- L1 em 2.1.318: `marketplace add --scope` aceita user (padrão), project ou local. No
  `marketplace remove`, omitir `--scope` "remove it from every scope". O clone continua em
  `~/.claude/plugins/marketplaces/` (L2), seja qual for o escopo.

**Alternatives considered**: permitir remove de qualquer marketplace listado. Descartado pelo
efeito em cascata citado de U1.

## Decision 7: Cache e dados do plugin (D18, S3)

**Decision**: a foto mede `~/.claude/plugins/cache` por metadados. A pasta de dados
`~/.claude/plugins/data/<id>/` fica fora das raízes de D9.
**Rationale**:
- U2: o cache fica em "`cache/<marketplace>/<plugin>/<version>/` | One directory per installed
  version of a marketplace plugin". A raiz muda com `CLAUDE_CODE_PLUGIN_CACHE_DIR`; se a variável
  estiver definida, a skill a cita e para (raiz fora da foto).
- U1: o uninstall do último escopo "also deletes the plugin's stored options and secrets and its
  data directory".
- **Não verificado**: se o uninstall apaga a pasta do cache. O S3 mede e, havendo sobra, falha e
  volta ao owner, como D18 e o S3 já preveem.

**Alternatives considered**: incluir `data/` na foto. Fica fora porque D9 fecha a lista de raízes
e este plano não a amplia.

## Decision 8: Pacotes (D17)

**Decision**: o item de pacote só passa se cumprir tudo isto:
- versão exata;
- npm e pnpm com `--ignore-scripts`; yarn classic com `--ignore-scripts`; yarn berry com
  `enableScripts` em false;
- pip com `--only-binary=:all:` e `--require-hashes`, sobre requirements com `==` e hash em todas
  as dependências;
- registro conferido em `.npmrc` e `.yarnrc.yml` antes.

**Rationale**:
- U7: "If true, npm does not run scripts specified in package.json files." Há uma ressalva:
  comandos que pedem um script de propósito ainda o rodam, sem os pre e post.
- U9 (pnpm) e U10 (yarn classic): "Do not execute any scripts defined in the project
  `package.json` and its dependencies."
- U11 (yarn berry): "If false (the default), Yarn will not execute the `postinstall` scripts from
  third-party packages". Um `.yarnrc.yml` do repositório pode ligar a opção, por isso é conferido.
- U8: existe um "per-project configuration file (`/path/to/my/project/.npmrc`)" e `registry` é
  "The base URL of the npm registry". Confirma o redirecionamento de D17.
- U13: "Requirements must be pinned (either to a URL, filesystem path or using `==`)" e "Hashes
  are required for _all_ dependencies".
- U14: o modo hash "is implied when any package in a requirements file has a --hash option".
- U13: "Disallow source distributions, by passing `--only-binary :all:`".
- **Não verificado**: o valor `skip-build` do `--mode` do yarn berry (U12 confirma só a flag).
  Por isso não é citado.

**Alternatives considered**: nenhuma; os canais são de D17.

## Decision 9: Linguagem do auxiliar da foto e do gate

**Decision**:
- Um único auxiliar `skills/rito-descoberta/historico.mjs`, em Node, só de leitura, com dois
  subcomandos: `foto` e `pendentes`.
- O `rito-dev` (Fase 11) chama o mesmo arquivo instalado.

**Rationale**:
- `node` é pré-requisito do cockpit (Princípio VII) e o mesmo em Linux, WSL e macOS. Já
  `stat` e `find -printf` diferem entre GNU e BSD.
- Há precedente no repositório: `skills/parallel-work/driver.mjs`.
- Um arquivo atende os dois consumidores (deduplicação): a foto da Fase 0 e o gate da Fase 11.
- Fica em `skills/rito-descoberta/**`, um caminho previsto.

**Alternatives considered**:
- Comandos soltos no `SKILL.md` (saída não determinística entre plataformas).
- Script `.sh` com ramos GNU e BSD (mais código e dois caminhos para testar).

## Decision 10: Restrições dos templates (E4, E8)

**Decision**: as mudanças nos templates não criam placeholder, chave opcional, princípio nem
título de fase novos.
**Rationale**: o cenário 15 de `scripts/testar-configurar.sh` (fora dos caminhos previstos,
portanto intocável) exige:
- nenhum `{{` residual;
- nenhum `URL_AMBIENTE`, `DESTINOS_DO_PROJETO` ou `PREFIXOS_BRANCH` em `templates/`;
- princípios da semente na ordem `II II-bis III IV IV-bis V VI VII VIII`;
- `## Fase N — ` para N de 1 a 11 no `rito-dev.md` gerado.

Por isso a política entra **dentro** do IV da semente e os gates entram **dentro** das Fases 1
e 11 do template.
**Alternatives considered**: um `### IV-ter` ou um `## Fase 0 — ` no template. Descartado, porque
quebra a ordem testada ou acrescenta um título sem necessidade.

## Decision 11: Pré-checagem do mapa contra o catálogo (S2, SC-003)

**Decision**: o mapa de D4 segue como está; a checagem do S2 no pós-merge repete esta medição.
**Rationale**: L3 em 2026-11-05:
- clone em `ed74d115b7fb7026a22a4f816a8e3250f425e3b4`, sem alteração local;
- `agents` somando 164 nos dez `plugin.json`;
- os 13 agentes citados presentes no array `agents` do seu plugin;
- nenhum deles com WebFetch, WebSearch, `mcp__`, navegador, desktop, Agent ou Task no `tools:`;
- os dois nomes da regra (b) existem;
- nenhum dos dez plugins tem `hooks/` ou `.mcp.json`, só `agents`, que é a condição de D17.

**Alternatives considered**: nenhuma (medição de controle).

## Decision 12: Onde a Fase 0 entra no rito e quem cria a worktree (D1, D10, E1)

**Decision**:
- Na trilha completa, a Fase 1 do `rito-dev` delega à `/rito-descoberta`.
- A skill conduz a Fase 0 na árvore principal. Depois do OK, cria a worktree pelo
  `/parallel-work` com base explícita (o mesmo comando da Fase 1), grava e commita o
  `decisoes-do-owner.md`, roda `cstk hooks install` e `cstk mcp install --project-path <worktree>`
  e entrega o bloco copiável.
- O rito segue na Fase 2 dentro da worktree.

**Rationale**:
- E1 põe o 1º commit da worktree na skill.
- D10 põe o gate na Fase 1.
- Os parâmetros (`BRANCH_INTEGRACAO`, `REPO_REMOTO`) vêm do `cockpit.config` com as mesmas regras
  da seção "Parâmetros" do `rito-dev`. Sem `cockpit.config`, como no próprio cockpit, a skill
  pede os valores explícitos ao owner e nunca os presume.

**Alternatives considered**: uma Fase 0 numerada dentro do `rito-dev`. Descartado por D1 (skill
nova) e pela Decision 10.

## Decision 13: Leitura da linha "Instalação pelo agente" (D19)

**Decision**:
```text
git show origin/<base>:docs/constitution.md
```
A leitura conta as linhas inteiras que casam com
`^Instalação pelo agente: (ligada|desligada)$`. A política vale como ligada só quando há
exatamente uma dessas linhas e ela diz `ligada`. Qualquer outro resultado (a linha diz
`desligada`, nenhuma linha, duas ou mais linhas, mesmo que uma esteja num comentário, ou falha de
leitura) faz a skill só imprimir.

A leitura roda depois de a base ser conferida contra o SHA da `gh api`, no mesmo passo, para não
ler uma ref local velha.
**Rationale**:
- D19 manda ler na `origin/<base>` e nunca na worktree.
- A comparação de linha inteira não aceita variação de redação nem texto embutido.
- Hoje o cockpit tem a linha ligada em `docs/constitution.md`.

**Alternatives considered**: ler pela regex do valor. Descartado por aceitar variações.
