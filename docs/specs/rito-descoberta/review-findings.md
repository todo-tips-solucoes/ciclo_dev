# Revisão de código — rito-descoberta

Trilha completa (Princípio II): `bmad-code-review` sobre `git diff origin/main...HEAD` antes da PR.
As três camadas rodaram como subagentes `general-purpose` com o papel no prompt, porque os skills
de camada não estão instalados: Blind Hunter (só o diff), Edge Case Hunter (diff e leitura do
projeto, com execução do `historico.mjs` em HOME falso) e Acceptance Auditor (diff, spec e
`decisoes-do-owner.md`).

## Rodada 1 (2026-11-05, base `36e7774`, ponta `1d14231`)

Depois de juntar os duplicados: 4 altos, 2 decididos pelo owner; os demais corrigidos.

### Decididos pelo owner

- [x] **Gate da Fase 11 comparava o estado global da máquina** (Edge, Blind M5, Auditor): frente
  com plugin permanente nunca encerrava, e atualização automática ou outra frente travavam o
  encerramento. Resposta do owner: "Só o que a frente toca (Recomendado)". Feito: subcomando
  `historico.mjs gate <frente>` compara os ids temporários do log e a presença dos plugins das
  raízes da frente; permanente é diferença esperada.
- [x] **Install com `@marketplace` atualiza o catálogo antes de buscar o plugin** (Blind A2): o S3
  instalaria num SHA mais novo, a regra "SHA divergente desinstala e para" o derrubaria e toda Fase
  0 seguinte pararia em "mapa não verificado". Resposta do owner: "Reverificar e seguir
  (Recomendado)" e, para o conflito com a constituição, "Ajustar a 2.0.0 (Recomendado)". Feito: o
  mapa e o conteúdo são reverificados no SHA instalado; reprovado desinstala e para. Emenda 2.0.0
  ajustada antes do merge em `docs/constitution.md` e no IV da semente, com o motivo no Sync Impact
  Report.

### Corrigidos

- [x] [alto] `pendentes` ignorava em silêncio linha de install mal formada (classe com maiúscula,
  espaço no lugar de TAB, `echo` sem `-e`, log vazio) e o gate passava. Agora sai 2: linha com
  menos de 6 colunas, evento desconhecido, abertura ou desfazer sem 11 colunas ou classe fora de
  `permanente`/`temporária`, log vazio ou sem `base` [skills/rito-descoberta/historico.mjs].
- [x] [alto] Célula de comando entre crases reprovava na checagem 5, e executar "byte a byte" a
  célula com crase seria substituição de comando. Agora a célula é um trecho de código e o valor é
  o texto entre as crases, com lista fechada de caracteres permitidos [SKILL.md, checagem 5].
- [x] `enable` temporário sem forma válida de desfazer: `disable` entra nas formas permitidas e
  `pendentes` fecha `enable` com `disable`.
- [x] Checagem 6 rodava antes de existir o 1º commit: agora roda logo depois do commit, e saída
  vazia reprova.
- [x] Foto anterior da rodada sem lugar declarado: arquivo `.ultima` ao lado do log; rodada grava
  itens `+` e `-`; retomada compara com o `.ultima`.
- [x] Base vazia permanente quando a foto falhava: base por `.tmp` não vazio e `mv`; foto que falha
  para tudo.
- [x] Nome de frente reutilizado herdava log e base de outra frente: log com outra raiz ou branch
  para e pede outro nome. Nome limitado a 64 caracteres.
- [x] Regex de caminhos aceitava `.git/**` e `.claude/**`: segmento `.git` e `**` sob `.claude/`
  reprovam.
- [x] Lista de metacaracteres incompleta e flags de registro: lista fechada de caracteres e
  `-g`, `--global`, `--registry`, `--index-url`, `--extra-index-url`, `--trusted-host` reprovam.
- [x] `marketplace remove` podia apagar marketplace anterior à frente: `add` só com nome fora da
  base; `remove` só do que a frente adicionou.
- [x] Conferência "só agentes" contornável por `hooks`/`mcpServers` inline no `plugin.json`: as
  chaves `hooks`, `mcpServers`, `lspServers`, `commands`, `skills` e `outputStyles` reprovam;
  `README.md` e `LICENSE` passam.
- [x] Sem reverificação de plugins na worktree depois de criada: passo novo, antes de aplicar a
  lista; ação fora da lista é desvio.
- [x] Log gravado depois do comando (queda deixava item invisível): `install`/`enable` vai ao log
  antes de executar; falha é fechada pelo desfazer.
- [x] Foto: `git status` pegava o `index.lock` (`--no-optional-locks`); erro do git, `--raiz` fora
  de repositório, `HOME` vazio ou relativo e `CLAUDE_CONFIG_DIR` definido viravam foto fraca com
  saída 0 (agora saída 1); symlink de raiz ou de diretório ficava cego (agora seguido, com guarda
  de ciclo; quebrado vira `link-quebrado`); diretório ilegível sumia (agora `ilegivel`); filtro
  `-shm`/`-wal` escondia qualquer arquivo com esse sufixo (agora só sob `<raiz>/.claude`, mais
  `-journal`); MCP de escopo local (`projects[*].mcpServers`) e `settings.local.json` fora da foto;
  URL ou caminho de marketplace em claro (agora hash); `installed_plugins.json` com `null`
  derrubava com stack trace (agora mensagem e saída 1); linha `git worktree` mudava a cada commit em
  worktree paralela (sem `HEAD`); raízes `~/.claude/CLAUDE.md`, `commands` e `hooks` acrescentadas.
- [x] Ruído conhecido não batia com a foto: a atualização automática aparece como linha `catalogo`
  do `claude-plugins-official`.
- [x] Cópia versionada vazava máquina, caminhos fora do `$HOME` e nomes de arquivos ignorados.
- [x] Worktree removida antes do uninstall sem caminho de recuperação: recriar no mesmo caminho,
  desfazer e só então remover.
- [x] Origem do campo `escopo` no log indefinida: valor literal do `-s`, ou `global`.
- [x] Template do `rito-dev` mandava criar a branch antes do gate da Fase 0: gate movido para antes.
- [x] Description do `rito-dev` ainda capturava "iniciar qualquer feature" (D1).
- [x] Semente com "Nenhum script MUST instalar" (não proibia nada): "MUST NOT".
- [x] Bloco copiável sem `--projeto`; `PREFIXOS_BRANCH` fora dos parâmetros; referência fixa a
  `docs/CICLO-GIT.md`.
- [x] Mermaid do `tasks.md` com parênteses sem aspas.

### Adiados

- [x] [Defer] "Temporárias globais rodam uma por vez" sem trava entre frentes — frente
  `frentes-paralelas`.
- [x] [Defer] Pacote temporário dentro de diretório ignorado já existente (`node_modules/`) não
  aparece no `git status`: pacotes dependem do par no log, que agora falha fechado.
- [x] [Defer] Retenção do `.base` (cerca de 8 MB por frente nesta máquina).
- [x] [Defer] Constituição e semente descrevem a trilha completa sem citar a Fase 0 — emenda futura.
- [x] [Defer] S1 sobrescreve `~/.claude/skills/rito-dev` sem cópia: o smoke faz cópia antes.

### Descartados

- `settings.local.json` da árvore principal muda quando o owner aprova uma permissão: continua
  desvio, de propósito (falha fechado; o owner explica).

### Processo

- O Edge Case Hunter gravou 9 fotos de teste (`f0` a `f8`) na raiz da worktree, contra a ordem de
  escrever só no scratchpad. Conteúdo inofensivo (HOME falso); removidas antes do commit.

## Rodada 2 (2026-11-05, ponta `ad1ce2b`)

Depois de juntar os duplicados: 6 altos, nenhum crítico. O owner decidiu 3 pontos; o resto foi
corrigido.

### Decididos pelo owner

- [x] **Foto da Fase 0 com rotatividade alta** (Edge F): 39 `.in_use/<pid>` em 24h no cache,
  `plugin.json` reescrito por install de outra sessão e `~/.local/bin/claude` reapontado pela
  atualização automática viravam desvio em quase toda rodada. Resposta: "Granularidade por versão
  (Recomendado)". Feito: cache por pasta de versão (`dir`/`orfa`), linhas `plugin` só do escopo
  `user` e do projeto da raiz, symlink que sai da raiz vira `link:<alvo>`, reapontamento do
  `claude` no ruído conhecido.
- [x] **Uninstall deixa a pasta do cache** (Edge A): medido, a CLI marca `.orphaned_at` e coleta
  depois. Resposta: "Pasta marcada órfã = desinstalado (Recomendado)". Feito no gate e no S3.
- [x] **Fase 11 desta frente sem log** (Auditor, Edge): a Fase 0 da `rito-descoberta` foi manual,
  antes da skill. Resposta: "Exceção declarada (Recomendado)". Só esta frente encerra sem o
  `gate`; a verificação do S3 (par install/uninstall e estado conferido) faz o papel dele. O gate
  vale para registro com os 14 títulos da skill e worktree ligada ao log pelo evento `worktree`.

### Corrigidos

- [x] [alto] Linha iniciada por TAB era tratada como item de rodada e um `install` com a 1ª coluna
  vazia sumia (Blind, Edge, Auditor): só `^\t{4}[+-] ` logo depois de `rodada`; o resto sai 2.
- [x] [alto] Gate ignorava a worktree onde roda e não pegava install fora do log (Blind): a
  worktree atual entra nas raízes, precisa aparecer no log (evento `worktree` novo) e nenhum
  plugin pode ficar com `projectPath` nela, salvo permanente.
- [x] [alto] Ids temporários eram comparados em todos os projetos e no cache compartilhado
  (Blind, Edge, Auditor): presença só nas raízes da frente (fora a raiz principal); cache só como
  pasta de versão sem plugin instalado e sem marca de órfã.
- [x] [alto] "Só agentes" contornável por `skills/` e `commands/` (Blind): lista fechada de
  arquivos (`plugin.json`, `README.md`, `LICENSE*`, os `.md` do array `agents`) e frontmatter só
  com `name`, `description`, `tools`, `model` e `color` (medido nos 166 agentes do catálogo).
- [x] Classe do desfazer diferente da abertura tirava o id do gate: falha fechado; a classe vem da
  abertura.
- [x] `gate0` contava sem `OK`; branch atual não conferida; `installed_plugins.json` fora do formato
  `version` 2 dava foto vazia; `git status` acima de 1 MiB derrubava a foto (`maxBuffer`);
  `mcpServers: {}` vazio virava desvio; settings commitadas não eram lidas (agora `HEAD` também).
- [x] Checagem 5: `marketplace add`/`remove` só temporária; flags `--location`, `--prefix`,
  `--user`, `-i`, `-f`, `--find-links`, a palavra `global` e pacote por URL ou `git+` reprovam;
  origem de id, escopo e projeto para pacote.
- [x] Nome reusado de Fase 0 concluída (log com `gate0`) para e pede outro nome.
- [x] Política: SHA de plugin vale depois da conferência pós-install.
- [x] `contracts/decisoes-do-owner.md`, `contracts/historico.md`, `quickstart.md`, `research.md`,
  `plan.md`, `data-model.md` e `spec.md` (FR-016) alinhados às decisões; `tasks.md` 6.1.2 anotada.
- [x] Texto do `rito-dev` (saída 1 inclui foto que falhou) e do template (`enable`/`disable`).

### Adiados

- [x] [Defer] `docs/constitution.md` diz "Nenhum script do cockpit MUST executar…" (RFC 2119
  invertido), texto já na `main` desde a 1.1.0 — emenda futura.
- [x] [Defer] Caminhos literais sob `.claude/` (por exemplo `.claude/settings.json`) passam na
  checagem 3: o owner os vê no Gate 0; a trava técnica é da `modo-autonomo`.
- [x] [Defer] `perm` isenta a tripla inteira; a classe certa depende do log e da tabela do 1º
  commit.

## Rodada 3 (2026-11-05, ponta `43055e9`)

Blind Hunter: nenhum alto ou crítico. Acceptance Auditor: 2 altos. Edge Case Hunter: 1 alto. Todos
corrigidos.

- [x] [alto] A exceção desta frente só estava no `review-findings.md`, e o critério de quando o
  gate vale divergia entre contrato, skill, `rito-dev` e template (Auditor): critério único (branch
  com `decisoes-do-owner.md`, trilha completa, falha fechado) e a exceção `rito-descoberta` nomeada
  na seção "Gate da Fase 11" da skill, citada pelo `rito-dev` e pelo contrato.
- [x] [alto] Quickstart, spec e plan ainda com o critério antigo do cache e da constituição
  (Auditor): Scenario 10 pelo critério do gate (pasta sumida ou `orfa`), Scenario 7 com `ad1ce2b`,
  FR-019, caso-limite da spec e R3 alinhados.
- [x] [alto] O Claude Code registra sozinho, na 1ª sessão da worktree, os plugins habilitados na
  principal (medido: 19 de 23 worktrees do `bos_v1`), e a presença os tratava como install fora do
  log (Edge): id herdado (instalado ou habilitado na raiz principal na linha de base) fica isento.
  `false` em `enabledPlugins` conta como ausente, para o `disable` que grava `false` (não medido).
