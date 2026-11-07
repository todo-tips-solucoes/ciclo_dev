# Achados do bmad-code-review: modo-autonomo

Rodada 1 em 2026-11-06, sobre o diff de código, skills e templates da worktree contra `origin/main`
(`0735cb4`, 22 arquivos, +858/−33; as specs desta pasta entraram como contexto). Três camadas em
paralelo: Blind Hunter (só o diff), Edge Case Hunter (diff e leitura do repositório, experimentos
no scratchpad) e Acceptance Auditor (diff contra spec, contratos, `decisoes-do-owner.md` e
constituição). Origem de cada achado: B = Blind, E = Edge, A = Auditor.

Escopo conferido pelo Auditor: todo arquivo tocado está em "Caminhos previstos" ou em
`docs/specs/modo-autonomo/**`, e nenhuma dependência nova entrou (FR-027, SC-007). Todo texto
sobre a regra `deny` contra `--admin` diz "não medido" até o caso `--admin` do S3.

## Decisões do owner

- [x] [Review][Decision] Contenção na produção (owner: texto declara a espera; vira correção) (B9, A8). Pela A1 do block-001, a trava manda
  qualquer PR para a produção que não seja a de promoção para a aprovação de dono. O revert da
  promoção sai de uma branch `revert-…`, então cai em `exige_dono`. Mas o item 8 da `rito-dev` e a
  decisão do programa ("smoke em produção falho → rollback automático") tratam esse revert como
  passo automático.
- [x] [Review][Decision] Autoria na trava (owner: só rejeitar fork; autor fica como limite conhecido) (B6). No modo ligado, a PR de qualquer colaborador com
  escrita fica verde: a trava não confere o autor e o `require-codeowner-approval` só avisa. Mas a
  constituição restringe a exceção à identidade própria do agente. Os registros de frentes antigas
  também não expiram.
- [x] [Review][Decision] Reordenação de chaves (owner: alinhar a spec ao código; vira correção) fora do array (A11). A FR-009 manda reprovar
  "reordenar fora do array". O contrato omite isso, e o `deny_puro` compara objetos no `jq`, que
  ignora a ordem. O teste de `scripts/testar-configurar.sh` (~l.1510) espera `success`.
- [x] [Review][Decision] `CLAUDE.md` e `.claude/` aninhados (owner: governança em qualquer pasta; vira correção) (E3). A FR-009 e o contrato tratam
  esses caminhos como governança só na raiz. `src/CLAUDE.md`, `docs/specs/f/CLAUDE.md` e
  `src/.claude/...` passam (provado). O Claude Code carrega `CLAUDE.md` de subpasta quando lê
  arquivos dali.

## Correções

ALTO

- [x] [Review][Patch] `promotion-pr` arma o auto-merge a cada push na integração. Isso passa por
  cima do SHA fixado, do smoke combinado e do corte de frente irreversível ou item `manual` (FR-017,
  FR-018, D8, contrato §7 passos 2-4). O workflow deve só criar e atualizar a PR, e quem arma é o
  agente no item 7, depois do §7 [templates/.github/workflows/promotion-pr.yml.tmpl:104] (B2, A1,
  E9)
- [x] [Review][Patch] `historico.mjs`, regra (c): `tools:` nulo, vazio, `[]` ou `*` não proíbe;
  chave duplicada vale a última; `WebFetch(...)` e `WebSearch(...)` não casam
  [skills/rito-descoberta/historico.mjs:438-450] (B1, E7, E13, E14)
- [x] [Review][Patch] `historico.mjs`: `skills/`, `commands/`, `hooks/` e `output-styles/` citados
  no array `agents` passam, contra o contrato `historico-plugin.md:49`
  [skills/rito-descoberta/historico.mjs:482-483] (E1)

MÉDIO

- [x] [Review][Patch] `fim()`: o `head -c 120 | iconv -c` sai 1 quando corta um caractere
  multibyte, e o `pipefail` derruba o job sem publicar o status
  [templates/.github/workflows/caminhos-previstos.yml.tmpl:53] (B3, E2)
- [x] [Review][Patch] "Dependências novas": qualquer texto diferente de `Nenhuma`/`Nenhuma.` conta
  como dependência aprovada. Só item de lista `- <dep>` deve aprovar (FR-009, Q1)
  [caminhos-previstos.yml.tmpl:222-225] (B4, A3, E4)
- [x] [Review][Patch] Correção (`Origem: #n`) passa manifesto e lockfile sem a regra D-P9. Com
  manifesto ou lockfile na correção, deve exigir dono [caminhos-previstos.yml.tmpl:176-188]
  (B5, E5)
- [x] [Review][Patch] Trava aceita PR de fork (cabeça em outro repositório). Deve exigir dono
  [caminhos-previstos.yml.tmpl] (B6, parte mecânica)
- [x] [Review][Patch] A lista de arquivos vem do HEAD atual, e o status vai para o `EVENT_SHA`.
  Deve reconferir o HEAD depois de listar [caminhos-previstos.yml.tmpl:151-159] (E8)
- [x] [Review][Patch] `configurar.sh` imprime a configuração do GitHub pelo `cockpit.config`, mesmo
  quando a constituição mantida diz outro valor. Deve avisar a divergência [configurar.sh:398-399]
  (E6)
- [x] [Review][Patch] O `success "modo desligado"` fica no SHA depois que o modo liga. Antes do
  auto-merge, o agente confere o status do commit atual [skills/rito-dev/SKILL.md, item 3] (B7)
- [x] [Review][Patch] `audit-merge-vermelho` lê o modo na ponta da integração depois do merge. Deve
  ler no `base.sha` da PR [templates/.github/workflows/audit-merge-vermelho.yml.tmpl:65] (B8, E12)
- [x] [Review][Patch] No modo ligado, o registro entra no diff da PR de frente, e a trava (F1) o
  barra. Depois do merge da PR de registro, a skill manda fazer merge de
  `origin/<BRANCH_INTEGRACAO>` com registro idêntico (D3) [skills/rito-descoberta/SKILL.md, "Depois
  do OK"] (A2)
- [x] [Review][Patch] O `deny` da barreira não chega à PR, como a D9 pede. A skill deve mandar
  commitar o `.claude/settings.json` mesclado e listá-lo em "Caminhos previstos"
  [skills/rito-descoberta/SKILL.md:335-351] (A4)
- [x] [Review][Patch] Na Fase 11, a nova execução da barreira "não bloqueia o fluxo do rito-dev",
  contra a FR-023. A reprovação deve parar o gate da Fase 11
  [skills/rito-descoberta/SKILL.md:351] (A5)
- [x] [Review][Patch] Faltam fontes oficiais dos campos de API: `.head.ref`, `.head.repo.full_name`,
  `.merged`, `.base.ref` e `allow_auto_merge`/`allow_merge_commit` (Princípio V). Conferir via
  `ctx_fetch_and_index` e registrar em `research.md` (A6)
- [x] [Review][Patch] Testes sem os casos `MODO_AUTONOMO` vazio (sobrescrito) e `Ligado` (D13,
  FR-025) [scripts/testar-configurar.sh:1297-1305] (A7, B14, E17)
- [x] [Review][Patch] Veracidade: `Edit(/.claude/settings*.json)` "nega a edição", mas só bloqueia
  a ferramenta Edit (R1) e não a edição por Bash. O texto deve dizer isso
  [skills/rito-descoberta/SKILL.md:339] (B10, A14)

BAIXO

- [x] [Review][Patch] Nome de arquivo com 0x1f (campo extra) passa sem conferência
  [caminhos-previstos.yml.tmpl:164-173] (B11)
- [x] [Review][Patch] O cabeçalho da trava promete "o dono aprova e reexecuta" em falhas que são
  `failure` direto [caminhos-previstos.yml.tmpl:7-8] (B12)
- [x] [Review][Patch] O `gh` falso dos testes devolve a constituição para qualquer `ref`
  [scripts/testar-configurar.sh:~1024,~1100,~1208] (B13)
- [x] [Review][Patch] SHA de rollback no corpo da PR, mas contrato e skill dizem "comentário".
  Alinhar ao que o P1 decidir [promotion-pr.yml.tmpl:88] (B16, A13)
- [x] [Review][Patch] README e configurador não avisam que a trava precisa estar na branch padrão
  (R9, D4) (A9)
- [x] [Review][Patch] A semente diz "teto de duas correções por frente", mas a D6 define contadores
  separados (2 de CI e 2 de smoke) [templates/docs/constitution.md.semente.tmpl:47] (A10)
- [x] [Review][Patch] Falta documentar o `release.yml` no rollback (D8) e "integração = produção"
  no item 8 [skills/rito-dev/SKILL.md] (A12)
- [x] [Review][Patch] O template usa `<BRANCH_INTEGRACAO>`/`<BRANCH_PRODUCAO>` sem renderizar
  [templates/docs/rito-dev.md.tmpl:192,212] (A15)
- [x] [Review][Patch] A impressão da identidade omite P1/P2 (fora do CODEOWNERS, sem admin ou
  maintain) [configurar.sh:404] (A16)
- [x] [Review][Patch] `frentes_de`: erro de leitura vale "sem registro" em vez de `failure` "erro de
  leitura" [caminhos-previstos.yml.tmpl:113-117] (A17, E10)
- [x] [Review][Patch] As instruções ao owner não dizem que ele precisa reexecutar a trava depois de
  aprovar (FR-010, D4) (A18)
- [x] [Review][Patch] Sementes e papéis repetem "sempre de um humano" em vez de só apontar para o
  Princípio II (FR-024) [templates/CLAUDE.md.semente.tmpl, templates/docs/agentes/revisor.md.tmpl]
  (A19)
- [x] [Review][Patch] Lista vazia com `changed_files=1` passa na conta (`wc -l` de "" dá 1)
  [caminhos-previstos.yml.tmpl:71] (E11)
- [x] [Review][Patch] Com integração = produção, a orientação do `TOKEN_AUTOMACAO` some, embora o
  `release.yml` o use [configurar.sh:407] (E15)
- [x] [Review][Patch] O teste "cria o PR e arma o auto-merge" não tem asserção
  [scripts/testar-configurar.sh:1070] (E16)
- [x] [Review][Patch] Os testes de symlink e de "fora do cache" não discriminam: o mutante passa
  [skills/rito-descoberta/historico.test.mjs:71-72] (E18)

## Descartados

- Symlink acima do cache reprova todos os plugins (no macOS, `/var` → `/private/var`) (B15): é a
  falha fechada que o contrato pede (5.1.2); o CI é Linux.
- Teto de duas correções conferido na trava (parte de B5): pela D6, o contador é do rito, não da
  trava; o contrato não pede.

# Rodada 2

Rodada 2 em 2026-11-06, sobre o delta das correções da rodada 1 (15 arquivos, cerca de 1060
linhas), com as mesmas três camadas. O Acceptance Auditor confirmou resolvidos todos os achados da
rodada 1, menos dois:
- B2/A1/E9: resolvido só em parte; virou o primeiro item das decisões abaixo.
- A6: faltam as fontes que as próprias correções trouxeram; virou uma das correções abaixo.

As quatro decisões da emenda foram aplicadas. A da reordenação valeu no efeito, mas a letra da
FR-009 ainda a cita.

## Decisões do owner

- [x] [Review][Decision] Promoção com `--auto` e `--match-head-commit` (owner: merge direto em X, sem `--auto`; vira correção) (A2-1, B2-6). O manual do
  `gh` descreve a flag para o merge, e o REST de merge devolve 409 quando o `sha` não bate com a
  cabeça. Não está medido se o auto-merge armado respeita o SHA até o merge. Na janela entre armar e
  mergear, um push na integração pode levar Y à produção sem smoke e sem o corte de frente
  irreversível.
- [x] [Review][Decision] "Histórico" do registro (owner: arquivo próprio `docs/specs/<frente>/historico.md`; vira correção) (A2-4). A correção da rodada 1 passou o histórico
  para o corpo da PR de frente, contra o que foi decidido na `rito-descoberta`
  (`docs/specs/rito-descoberta/decisoes-do-owner.md:251`: copiado para o registro antes da PR). No
  modo ligado, copiar para o registro faz a trava exigir dono em toda PR de frente.

## Correções

ALTO

- [x] [Review][Patch] `historico.mjs`: o `tools` escrito em YAML válido (comentário, tag, âncora,
  alias, escape, `{}`, lista em bloco) escapa da (a) e da (c). O item deve seguir um formato fechado
  (`Nome` ou `Nome(...)` ou `mcp__…`); o resto conta como proibido. `DIRS_PROIBIDOS` passa a ignorar
  maiúsculas [skills/rito-descoberta/historico.mjs:432-455,484] (B2-1, E2-1, E2-7)

MÉDIO

- [x] [Review][Patch] Trava: o `exige_dono` encerra no 1º motivo, e a aprovação de dono libera
  também "fora do bloco" e manifesto sem dependência. As falhas diretas devem rodar antes, e o
  `exige_dono` só no fim [caminhos-previstos.yml.tmpl:135-191] (E2-2)
- [x] [Review][Patch] `audit-merge-vermelho`: filtra `aprovacao-de-dono` só com `ligado` no
  `base.sha` E na ponta da integração (D1); na dúvida, audita [audit-merge-vermelho.yml.tmpl:65]
  (A2-5, E2-3, B2-7)
- [x] [Review][Patch] Governança: a entrada `.claude` em si (symlink ou submódulo), `.github` e
  `.husky` como entrada, e nomes sem distinção de maiúsculas (`claude.md`, `.Claude/`)
  [caminhos-previstos.yml.tmpl:86-94] (B2-2, E2-6)
- [x] [Review][Patch] "Dependências novas": item tipo "nenhuma" (`- Nenhuma.`, `- (nenhuma)`) não
  aprova. O contrato registra como limite que a trava confere a existência da aprovação, não o nome
  do pacote [caminhos-previstos.yml.tmpl:246] (B2-3, E2-5)
- [x] [Review][Patch] Status velhos ao trocar o modo (B2-4, B2-5):
  - o agente desarma (`--disable-auto`) as próprias PRs de frente armadas quando o modo vira
    desligado;
  - o owner reexecuta a trava e o `require-codeowner-approval` nas PRs abertas depois de trocar o
    modo (README, configurador, skill).
- [x] [Review][Patch] Commit do `.claude/settings.json` sem os `enabledPlugins` temporários: o
  conteúdo commitado é o da base mais a união do `deny`
  [skills/rito-descoberta/SKILL.md:355-358] (A2-3)
- [x] [Review][Patch] Reverts que exigem dono: o revert que remove regras de `deny` ou toca
  governança, e o "revert do revert" para a produção, aguardam o dono. O rito diz isso nos itens 5
  e 8 (A2-7)
- [x] [Review][Patch] O limite conhecido da autoria (a trava não confere o autor; registros
  antigos não expiram) aparece no README, no configurador e no Princípio II da semente
  (A2-6, B2-8)
- [x] [Review][Patch] Quickstart: o S3 ganha os casos que a research aponta para ele (campos R18,
  fork, push durante a trava, registro idêntico, contenção aguardando dono, promoção pelo SHA fixado,
  formato `(HTTP 404)`, `base.sha`) e o S4 diz "pela ferramenta Edit" (A2-2, A2-13)

BAIXO

- [x] [Review][Patch] Na FR-009, tirar o "reordenar" da letra [spec.md:158] (A2-8)
- [x] [Review][Patch] Listas de "exige dono" desatualizadas (fork, correção com manifesto) em
  `CODEOWNERS.tmpl`, `rito-dev`/template e `data-model.md`; o data-model ainda diz "reprova" para a
  PR que altera o próprio registro (A2-9, B2-10)
- [x] [Review][Patch] `docs/specs/configurar/contracts/cli.md` com a regra de divergência da
  constituição (A2-10)
- [x] [Review][Patch] Veracidade (A2-11):
  - ordem dos statuses e `gh pr view --json headRefOid,body` com fonte no R18;
  - "release.yml publica o revert como versão nova" vira conferência, não afirmação;
  - o formato "(HTTP 404)" é marcado como assumido e não confirmado nos três lugares.
- [x] [Review][Patch] O agente confere que o SHA de rollback no corpo é a ponta atual da produção,
  não só que ele existe (A2-12)
- [x] [Review][Patch] SIGPIPE no `tr | head` da descrição: cortar no próprio bash
  [caminhos-previstos.yml.tmpl:59] (E2-4)
- [x] [Review][Patch] `configurar.sh`: avisar quando a constituição está ausente e o modo é
  `ligado`; tirar o `\r` antes de ler a linha [configurar.sh:396-418] (E2-8)
- [x] [Review][Patch] Testes: erro de leitura do registro da origem numa correção, guarda de
  `BASE_SHA` vazio do audit (E2-9)
- [x] [Review][Patch] Lockfiles e manifestos fora da lista: `bun.lock`, `bun.lockb`, `deno.lock`,
  `uv.lock` e `pnpm-workspace.yaml` (B2-11)
- [x] [Review][Patch] Nome de arquivo com caractere de controle (0x1f e quebra de linha) dá
  `failure "lista inválida"` antes da contagem (B2-9)

## Descartados (rodada 2)

- Registro de frente antiga vale para sempre (B2-8, parte "frente antiga"): faz parte do limite
  conhecido de autoria que o owner aceitou. Só a documentação desse limite virou correção.

# Rodada 3

Rodada 3 em 2026-11-06, sobre o delta das correções da rodada 2 (13 arquivos, cerca de 910
linhas). **Nenhum achado alto nem crítico nas três camadas.** O Auditor confirmou resolvidos os
achados da rodada 2, menos um: o B2-4/B2-5 ficou parcial (falta a orientação ao owner na skill). Os
dois Hunters mataram todos os mutantes nocivos das correções da rodada 2.

## Decisões do owner

- [x] [Review][Decision] Emenda do registro durante a frente (A3-3; owner: emenda por PR de registro aprovada, a trava passa a valer pela versão emendada; vira correção). A correção da rodada 2 criou
  um fluxo que não foi decidido: emenda por PR de registro própria. Ele conflita com dois pontos:
  - "registro intocado depois do Gate 0";
  - a regra da `rito-descoberta` de que "a lista de caminhos válida é a do 1º commit; caminho
    acrescentado depois não amplia o limite (D11)".

  Como a trava lê o registro na base, a emenda mergeada amplia o limite.

## Correções

MÉDIO

- [x] [Review][Patch] Constituição commitada com CRLF: o configurador tira o `\r` e lê `ligado`,
  mas a trava, o audit, o `require-codeowner-approval`, o `promotion-pr` e a `rito-dev` leem
  `desligado`. Resultado: ruleset sem gate humano e trava inerte. Todos devem tirar o `\r`
  (B3-1, E3)
- [x] [Review][Patch] Commit do `.claude/settings.json` com os temporários na working tree. Hoje
  ele quebra o merge de `origin/<BRANCH_INTEGRACAO>` (alterações locais e conflito no `deny` entre
  frentes paralelas) e confere contra o merge-base em vez da ponta da base. Além disso, um jq que
  falha deixa blob vazio no índice, a diferença só de formatação causa parada falsa, e `commit -am`
  posterior leva os temporários (B3-2, B3-3, B3-8, E3, A3-11)
- [x] [Review][Patch] "Dependências novas" em formato fechado dos dois lados. Na skill, a seção é
  `Nenhuma.` exato ou itens `` - `pacote` ``; na trava, só conta item com trecho de código
  (B3-4, E3, A3-9)
- [x] [Review][Patch] Correção (`Origem: #n`): os arquivos também precisam estar no bloco da frente
  da origem. A origem pode ter sido mergeada sem trava, no modo desligado (E3)
- [x] [Review][Patch] Cabeçalho do `promotion-pr` e comentário e asserção do teste ainda falam em
  `--auto` [promotion-pr.yml.tmpl:8-9; testar-configurar.sh:1062,1090] (A3-1, B3-7)
- [x] [Review][Patch] "Governança também precisa estar no bloco" nos textos: `rito-dev`, os "Itens
  do registro" da `rito-descoberta` (listar todo caminho de governança que a frente vai tocar) e a
  ordem explícita na FR-009/FR-010 (A3-2)
- [x] [Review][Patch] `historico.mjs`:
  - `tools` com valor YAML tipado (`true`, `false`, `null`, `yes`, `no`, `on`, `off`, em qualquer
    caixa, também dentro de lista) e frontmatter que não é YAML (`tools:Read`, colchete
    desbalanceado) contam como proibido;
  - `*` entre parênteses (`Bash(npm run test:*)`) deixa de dar falso positivo.

  (E3, B3-9)

BAIXO

- [x] [Review][Patch] `gh pr checks --required`: ressalva de que não está confirmado se a lista
  inclui commit status, e de que a garantia é o ruleset da produção no merge (A3-4, B3-10)
- [x] [Review][Patch] A recusa do `--match-head-commit` se atribui ao manual do `gh` ("must match
  to allow merge"), não ao 409. O critério para a falha: reler a cabeça; diferente de X, volta ao
  passo 2; igual, para (A3-5)
- [x] [Review][Patch] Texto velho de auto-merge na FR-019 e no data-model:173 (A3-6)
- [x] [Review][Patch] `rito-dev`: ao ler troca de modo, avisar o owner para reexecutar a trava e o
  `require-codeowner-approval` nas PRs abertas (A3-7, resto do B2-4/B2-5)
- [x] [Review][Patch] PR que só toca `docs/specs/<x>/decisoes-do-owner.md` (registro ou emenda) vai
  para o dono sem validar o bloco, para que um bloco inválido na base não trave a própria correção.
  Governança com frente ambígua e mudança só da chave `release` ficam documentadas como limite
  (A3-10, B3-5)
- [x] [Review][Patch] Quickstart: o caso do fork separa integração de produção [quickstart.md:116-118]
  (A3-13)
- [x] [Review][Patch] `configurar.sh`: com constituição ausente e `ligado`, depois do aviso imprime
  como `desligado` (E3)
- [x] [Review][Patch] `.claude/settings.json` como symlink: reprovar `type` diferente de `file` na
  leitura de conteúdo, com fonte, ou provar no S3 (E3)
- [x] [Review][Patch] Teste da guarda de renomeação para `.claude/settings.json` no `deny_puro` (E3)

## Descartados (rodada 3)

- Registro da `rito-descoberta` não emendado (A3-8): editar o registro antigo seria governança e
  contrariaria o "intocado". A emenda da rodada 2 nesta frente já faz a remissão, e a PR a cita.
- `docs/specs/modo-autonomo/historico.md` ainda inexistente (A3-12): é passo do "Antes da PR", e a
  sessão o cria no fechamento.
- Mutantes inofensivos que sobrevivem (sem `iconv`, quatro segmentos, `#!&` entre parênteses):
  deixam o código mais restritivo ou não mudam o resultado.

# Rodada 4

Rodada 4 em 2026-11-06, leve: só o Edge Case Hunter, sobre o delta das correções da rodada 3 (13
arquivos, cerca de 950 linhas). Não houve regressão na trava, no `configurar.sh` nem nos leitores
de `\r`. O procedimento novo de merge trouxe um achado alto.

## Correções

ALTO

- [x] [Review][Patch] O "Merge da integração com o arquivo commitado" apaga os hooks do cstk da
  working tree. O `cstk hooks install` sem `--local` grava `hooks` no `.claude/settings.json`
  rastreado, e o procedimento restaura o commitado e reaplica só os `enabledPlugins`. As sessões
  seguintes da worktree ficam sem o `bash-guard`. A correção tem duas partes:
  - reaplicar da cópia guardada toda diferença local, não só os `enabledPlugins`, preservando o que
    a integração trouxe;
  - avaliar `cstk hooks install --local` com as linhas do `.git/info/exclude` que o próprio cstk
    recomenda.

  [skills/rito-descoberta/SKILL.md:449-457,592] (E4-1)

MÉDIO

- [x] [Review][Patch] `historico.mjs`: o separador `\s*` aceita espaço Unicode (NBSP), que o YAML
  real rejeita. Usar `[ \t]*` e falhar fechado com outro espaço [historico.mjs:443] (E4-2)

BAIXO

- [x] [Review][Patch] Ordem do 3.bis × escopo do procedimento: antes do passo 5 da barreira, o
  merge é simples (rodado como está, o procedimento falha e para à toa) (E4-3)
- [x] [Review][Patch] `git commit --no-edit` só quando o merge parou em conflito (merge limpo ou
  "Already up to date" sai com 1) (E4-4)
- [x] [Review][Patch] O ramo "conflito em outro arquivo / jq com erro: pare" precisa dizer como
  voltar: abortar o merge, restaurar a cópia e religar o skip-worktree (E4-5)
- [x] [Review][Patch] `add -A` posterior leva `.claude/hooks/*.sh` e `.claude/settings.json.bak` do
  cstk; mesma correção do achado alto (`--local` + `info/exclude`) (E4-7)
- [x] [Review][Patch] "Dependências novas" com um formato só no contrato, na checagem 6 da skill e
  na trava: o item começa com `` `pacote` `` e pode ter observação depois (E4-8)
- [x] [Review][Patch] `ESCALARES` com `y` e `n` (YAML 1.1) [historico.mjs:456] (E4-9)
- [x] [Review][Patch] `rito-dev`: o revert de origem fora do bloco falha direto mesmo aprovado, e o
  rollback exige emenda antes (E4-10)
- [x] [Review][Patch] Teste da guarda `-s "$NOMES"` do caminho "só registros" (E4-11)

## Descartados (rodada 4)

- Merge limpo segue a integração quando ela remove item do `deny` (E4-6): a remoção na integração
  é governança e já passou pela aprovação de dono, então seguir a integração está certo. A união em
  caso de conflito é o lado mais restritivo.

# Rodada 5

Rodada 5 em 2026-11-06, verificação final focada no procedimento de merge e no `--local` (Edge
Case Hunter, com os blocos da skill extraídos e rodados um por processo, como o agente roda). **Não
há achado alto.** A correção da rodada 4 fecha o E4-1 no caminho padrão. As suítes passam. Os
médios são todos de procedimento: falha fechada em caso legítimo, ou working tree divergente em
silêncio.

## Correções

MÉDIO

- [x] [Review][Patch] Depois de um merge, a decisão dos hooks (`--local` ou não) não é refeita. Se
  a integração tira o registro do `settings.json`, o resultado é `registro=none` e as sessões ficam
  sem `bash-guard`; se acrescenta, é `both` e a contagem fica em dobro. O fim do procedimento, nos
  dois ramos, refaz a decisão pelo `cstk hooks status` [skills/rito-descoberta/SKILL.md:470-494,629-636]
  (E5-1)
- [x] [Review][Patch] A mesma mudança feita dos dois lados (cópia e `HEAD` com o mesmo valor novo)
  dá "mudou dos dois lados" e para à toa. Valor igual dos dois lados vale como acordo
  [SKILL.md:479-488] (E5-2)
- [x] [Review][Patch] Os blocos dependem de `$pre` e `$tmp` entre chamadas do Bash. Com `$pre`
  vazio, a working tree perde em silêncio o que a integração trouxe. Guarda `: "${pre:?}"
  "${tmp:?}"` e remoção do `$tmp` no fim [SKILL.md:440,460,477] (E5-3)

BAIXO

- [x] [Review][Patch] O bloco 5 falha depois do merge já commitado sem dizer como deixar a worktree
  (cópia e skip-worktree) [SKILL.md:463-468] (E5-4)
- [x] [Review][Patch] Merge depois do gate da Fase 11 cai no caminho simples e é recusado. A
  detecção de "barreira já commitou" não pode depender só da flag `S` [SKILL.md:242-245,411-414,426-432]
  (E5-5)
- [x] [Review][Patch] A reaplicação reordena as chaves e deixa ` M` no fim, o que faz o `git
  worktree remove` falhar. Preservar a ordem do `HEAD`, ou restaurar o arquivo antes de "Encerrar"
  [SKILL.md:483] (E5-6)
- [x] [Review][Patch] Na mescla de listas, item mudado dos dois lados vira dois itens (hook
  duplicado). Declarar como limite, ou dar erro [SKILL.md:487] (E5-7)
- [x] [Review][Patch] Ponta que andou entre o nascimento e o passo 5 da barreira: declarar a
  precondição (merge da integração antes do passo 5) [SKILL.md:377-391] (E5-8)
- [x] [Review][Patch] `info/exclude`: criar `info/` se faltar e falhar fechado; declarar ao owner
  que as linhas ficam no diretório git comum e valem para a árvore principal [SKILL.md:638-643]
  (E5-9)
- [x] [Review][Patch] Com o skip-worktree ligado, o `gh pr merge --delete-branch` não troca a
  worktree de branch. O agente confere o estado da PR, não o código de saída
  [SKILL.md:282-285; rito-dev:201] (E5-10)
- [x] [Review][Patch] Quebra de linha que começa com "11." no rito-dev [rito-dev/SKILL.md:393-394]
  (E5-12)

## Descartados (rodada 5)

- `` - `Nenhuma` `` conta como dependência aprovada (E5-11): está dentro do limite conhecido
  declarado. A trava confere que existe item aprovado, não o nome do pacote.
