# Quickstart: modo-autonomo

Cenários de verificação. Os de 1 a 6 rodam antes do merge (CI ou leitura do diff); os de 7 a 11 são
o smoke pós-merge do registro (S1 a S5), executado pelo agente na sessão da árvore principal e
relatado ao owner. Nenhum cenário instala nada (Instalações previstas: nenhuma).

## Scenario 1: Chave `MODO_AUTONOMO` no configurador (US1, FR-001, FR-002, SC-001)

1. `scripts/testar-configurar.sh` roda o configurador com a chave ausente, vazia, `Ligado` e
   `desligado` → **Expected**: a constituição semente gerada contém exatamente uma linha
   `Merge autônomo: desligado`; o caso inválido imprime aviso e termina com exit 0.
2. Mesmo script com `MODO_AUTONOMO='ligado'` → **Expected**: exatamente uma linha
   `Merge autônomo: ligado`.
3. `--atualizar` num projeto configurado antes da chave existir (sem `MODO_AUTONOMO` no
   `cockpit.config`) → **Expected**: exit 0, sem pergunta, constituição existente intocada (semente).
4. Rodar o configurador duas vezes com a mesma resposta → **Expected**: estado final idêntico
   (Princípio VII).

## Scenario 2: Templates renderizados continuam válidos (FR-008, FR-013, FR-019)

1. `scripts/testar-configurar.sh` renderiza todos os templates, inclusive o novo
   `caminhos-previstos.yml.tmpl` → **Expected**: o `actionlint` já usado pelo script passa sem
   achado em todos os workflows renderizados.
2. Conferir no workflow renderizado → **Expected**: gatilho `pull_request_target` com filtro na
   branch de integração; nenhum `actions/checkout`; nenhum `run` que execute arquivo do PR;
   permissões só de leitura mais `statuses: write`.

## Scenario 3: Ramo desligado idêntico ao de hoje (FR-024, D11)

1. `git diff origin/main -- skills/rito-dev/SKILL.md templates/docs/rito-dev.md.tmpl` →
   **Expected**: nas Fases 6 a 10 só aparece uma linha de ponteiro nova por fase; o texto existente
   das fases não muda; a seção "Modo autônomo" é nova.
2. `grep -c '{{MODO_AUTONOMO}}' templates/docs/rito-dev.md.tmpl` → **Expected**: `0` (o template
   do rito não renderiza o valor, D1).

## Scenario 4: Regra de leitura da linha de modo (US1 cenário 4, FR-003)

1. Na seção "Modo autônomo" da `rito-dev`, conferir os dois comandos `grep` e a regra "1 e 1" →
   **Expected**: idênticos aos da linha "Instalação pelo agente", trocando só o texto da linha.
2. Na `rito-descoberta`, conferir a citação → **Expected**: a skill aponta para a seção da
   `rito-dev` e não reescreve a regra.

## Scenario 5: `historico.mjs plugin` com fixtures (US7, FR-021, FR-022, SC-005)

`node skills/rito-descoberta/historico.test.mjs` no job novo do CI. Fixtures criados em diretório
temporário com `HOME` apontado para ele.

1. Plugin limpo (plugin.json, README.md, LICENSE, agentes do array) → **Expected**: exit 0,
   `veredito` `ok`, `motivos` vazio, `sha` igual ao do `installed_plugins.json` do fixture.
2. Plugin limpo com `.in_use/12345` e `.orphaned_at` → **Expected**: `ok`.
3. `.in_use/abc`, `.in_use/sub/`, `.in_use/1` symlink → **Expected**: `reprovado`, um motivo cada.
4. `.md` na raiz com chave extra no frontmatter ou `name` colidente com o array → **Expected**:
   `reprovado`; `.md` na raiz válido e sem colisão → `ok`, e entra no `deny` se for proibido.
5. `hooks/`, `.mcp.json`, arquivo executável → **Expected**: `reprovado`.
6. Agente com `WebFetch` no `tools:` e agente sem `tools:` → **Expected**: os dois em `deny`.
7. `installPath` symlink e `installPath` fora de `~/.claude/plugins/cache` → **Expected**: exit
   diferente de 0, sem JSON.
8. Item do array `agents` com `..`, duas entradas para o mesmo `installPath`, array `agents` vazio
   → **Expected**: exit diferente de 0, sem JSON.

## Scenario 6: Caminhos previstos desta frente (FR-027, SC-007)

1. `git diff --name-only origin/main...HEAD` na worktree → **Expected**: todo caminho está no bloco
   "Caminhos previstos" do registro ou em `docs/specs/modo-autonomo/**`.
2. `git diff origin/main...HEAD -- package.json package-lock.json` → **Expected**: vazio
   (nenhuma dependência nova).

## Scenario 7: S1, cópia das skills (pós-merge)

1. `cp -r` de `skills/rito-descoberta` e `skills/rito-dev` da `main` para `~/.claude/skills/` →
   2. `diff -r` → **Expected**: vazio; `name:` correto no frontmatter das duas.

## Scenario 8: S2, plugins da árvore principal (pós-merge)

1. `node ~/.claude/skills/rito-descoberta/historico.mjs plugin <installPath>` nos três plugins do
   mapa → **Expected**: `veredito` `ok` nos três; `deny` e `sha` presentes.
2. Caso negativo: o mesmo comando com um `installPath` fora do cache → **Expected**: exit
   diferente de 0.

## Scenario 9: S3, repositório descartável com modo ligado (pós-merge)

Precondições conferidas por comando antes de qualquer passo: visibilidade; ruleset da integração
com `ci`, `commitlint` e `caminhos-previstos` obrigatórios e sem bypass (e, com integração ≠
produção, o da produção com `caminhos-previstos-producao`, A1); auto-merge habilitado;
`Merge autônomo: ligado` na base; identidade do D2.

1. Frente trivial: PR de registro aprovada pelo owner → PR de código → **Expected**: CI verde,
   `caminhos-previstos` verde, auto-merge mergeia sem ação humana; o smoke da frente roda (SC-003).
2. CI vermelho com auto-merge ligado → **Expected**: não mergeia; três SHAs vermelhos distintos
   terminam em rascunho `estacionada` (FR-014).
3. Smoke vermelho pós-merge → **Expected**: duas PRs `correcao-<n>` e, na 3ª falha, reverts em
   ordem inversa contados por `gh pr list --state all` (SC-004).
4. Casos negativos, cada um → **Expected**: para, sem merge (SC-002): caminho fora da lista;
   `docs/constitution.md`; job homônimo `caminhos-previstos` noutro workflow; renomeação a partir
   de `.github/**`; `.claude/settings.json` com hook; push direto com a credencial do
   agente; status forjado por API com a credencial do agente; PR que se declara de outra frente;
   PR sem registro sem aprovação; revert com CI vermelho (para, sem laço); linha ausente ou
   inválida (vale desligado); frente irreversível (para na promoção). Com integração ≠ produção,
   também os casos do block-001: PR de outra branch direto para a produção sem aprovação de dono;
   mesmo SHA verde na integração e aberto para a produção (o verde não vale lá); mudança em
   `.releaserc*`, `release.config.*` ou na chave `release` do `package.json`.
   Caso `--admin` (separado, com as regras `Bash(gh pr merge *--admin*)` e
   `Bash(gh * pr merge *--admin*)` gravadas) → **Expected**: `gh pr merge <n> --admin` e
   `gh -R <repo> pr merge <n> --admin` recusados pela ferramenta (`deny`), sem chamada ao GitHub;
   além disso, sem merge pela identidade (D2). Até este caso ser registrado, o bloqueio pela
   regra é não medido.
5. Itens da research marcados "a provar no S3" (R2, R5, R7, R8) → **Expected**: cada um com o
   resultado observado registrado no relatório ao owner; qualquer um que não se confirme para o
   rito e volta ao owner.
6. Casos que a research (R18 e Pendências) e as rodadas do `bmad-code-review` apontam para o S3,
   cada um com o resultado observado no relatório ao owner → **Expected**:
   - campos do R18 lidos numa PR real: `head.ref`, `head.sha`, `head.repo.full_name`, `base.ref`,
     `base.sha` e `merged` em `GET pulls/{n}`, `allow_merge_commit` no GET do repositório e
     `pull_request.base.sha` no payload do `closed`, com os valores esperados; campo ausente ou
     diferente para o rito e volta ao owner;
   - PR de fork (cabeça em outro repositório) para a integração → a trava lista os arquivos e
     publica `failure` "aguarda aprovação de dono (PR de outro repositório)"; com arquivo fora do
     bloco, falha direto ("fora do bloco") mesmo aprovada;
   - com integração ≠ produção, PR de fork para a produção → vai direto à aprovação de dono, sem
     lista de arquivos: `failure` "aguarda aprovação de dono (PR de outro repositório)" no contexto
     `caminhos-previstos-producao`, e `success` "aprovado por dono" depois da aprovação no commit
     atual e da reexecução;
   - push na PR enquanto a trava roda → `failure` "HEAD mudou" no SHA antigo e novo run no SHA novo;
   - PR de frente depois do merge de `origin/<BRANCH_INTEGRACAO>` com a PR de registro já mergeada
     → o registro, idêntico ao da base, sai da lista de arquivos e a trava passa sem exigir dono;
   - contenção na produção (integração ≠ produção): o revert da PR de promoção fica em `failure`
     "aguarda aprovação de dono (PR para a produção)" até o owner aprovar no commit atual e
     reexecutar a trava;
   - promoção por merge direto, sem `--auto`: com os checks obrigatórios verdes e a cabeça da PR de
     promoção em X, `gh pr merge <n> --merge --match-head-commit X` mergeia; com push na integração
     depois de X (cabeça diferente), o merge é recusado (manual do `gh pr merge`:
     `--match-head-commit` é o "Commit SHA that the pull request head must match to allow merge",
     <https://cli.github.com/manual/gh_pr_merge>) e nada chega à produção; registrar a mensagem
     observada;
   - constituição commitada com CRLF (o blob na integração com `\r\n` em cada linha, inclusive em
     `Merge autônomo: ligado`) → a trava confere a PR (não
     publica "modo desligado"), o `require-codeowner-approval` passa com o aviso do modo ligado, o
     `audit-merge-vermelho` não abre issue só pelo `aprovacao-de-dono` e o `promotion-pr` exige o
     `TOKEN_AUTOMACAO`, como com LF;
   - emenda do registro durante a frente (decisão do owner na rodada 3): PR que só toca
     `docs/specs/<frente>/decisoes-do-owner.md`, inclusive com o bloco da base inválido → a trava
     publica `failure` "aguarda aprovação de dono (governança: ...)" sem validar o bloco e passa
     depois da aprovação do owner no commit atual e da reexecução; depois do merge, a PR de código
     que toca um caminho acrescentado pela emenda passa ("conforme registro"), porque a trava lê a
     versão emendada na base;
   - `.claude/settings.json` como link para um arquivo do bloco, com conteúdo de acréscimo puro →
     `failure` "aguarda aprovação de dono (governança: .claude/settings.json)"; registrar o `type` e
     o `path` que a API de conteúdo devolve para esse link (o `path` do alvo não está confirmado na
     fonte, contrato `caminhos-previstos.md`);
   - formato do erro do `gh api` para arquivo ausente (registro de frente inexistente na base) →
     contém `(HTTP 404)`; sem esse texto, a trava dá "erro de leitura" e o formato assumido no R18
     volta ao owner;
   - `audit-merge-vermelho` num merge real com `aprovacao-de-dono` vermelho → o modo é lido no
     `base.sha` do payload e na ponta da integração; com `ligado` nos dois não abre issue, e com o
     modo trocado entre a abertura e o merge abre;
   - `gh pr checks --required` na PR de promoção lista o commit status `caminhos-previstos-producao`
     (não confirmado na fonte; a garantia é o ruleset da produção no merge).
7. No fim, o owner apaga o repositório e revoga a credencial.

## Scenario 10: S4, deny bloqueia agente proibido (pós-merge, SC-006)

1. Na sessão da worktree de uma frente, com as regras gravadas pela skill, invocar um agente
   coberto pelo `deny` → **Expected**: a ferramenta recusa a chamada.
2. Na mesma sessão, pedir edição de `.claude/settings.json` pela ferramenta Edit → **Expected**:
   recusada. A regra cobre a ferramenta Edit; edição pelo Bash não é coberta por ela.
3. Se a regra não bloquear → **Expected**: o rito para e volta ao owner (D9).

## Scenario 11: S5, Fase 0 da `frentes-paralelas` (pós-merge)

1. Rodar a Fase 0 da próxima frente com a `rito-descoberta` nova → **Expected**: no cockpit (modo
   desligado, sem a linha) não há PR de registro; o registro segue como 1º commit da worktree.
