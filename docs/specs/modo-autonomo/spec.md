# Feature Specification: Modo autônomo de merge por projeto

**Short name**: `modo-autonomo`
**Status**: Draft
**Fonte normativa**: `docs/specs/modo-autonomo/decisoes-do-owner.md` (Escopo E1-E8, decisões D1-D13, caminhos previstos, smoke). Esta spec descreve o QUE e o POR QUE; as decisões D1-D13 são dadas e não são reabertas aqui.

Contexto: frente 2 do programa do ciclo autônomo. O dono do projeto quer que, em projetos que optarem, uma frente com CI verde seja mergeada, verificada por smoke e promovida sem leitura humana, sem que o agente possa contornar as barreiras. O próprio cockpit mantém o gate humano.

## User Scenarios & Testing

### User Story 1 - Ligar ou desligar o modo por projeto (Priority: P1)

O dono configura o projeto com `MODO_AUTONOMO` (`ligado`/`desligado`) e o projeto gerado fica com a linha literal `Merge autônomo: ligado|desligado` na constituição semente. O rito lê só essa linha na base de integração; qualquer valor ausente, inválido ou duplicado vale `desligado`.

**Why this priority**: é a fonte da verdade de todo o resto; sozinha já entrega um modo seguro por padrão (desligado) sem quebrar projetos existentes.

**Independent Test**: rodar o configurador com a chave ausente, inválida (`Ligado`, vazia), `desligado` e `ligado`, e conferir a linha gerada; rodar a atualização num projeto sem a chave.

**Acceptance Scenarios**:

1. **Given** chave ausente, inválida ou `desligado`, **When** o configurador gera a constituição semente, **Then** a linha é `Merge autônomo: desligado`.
2. **Given** chave `ligado`, **When** gera, **Then** a linha é `Merge autônomo: ligado`.
3. **Given** projeto já configurado sem a chave, **When** roda a atualização, **Then** não falha e o comportamento segue com gate humano.
4. **Given** a constituição na base com duas linhas `Merge autônomo:` ou nenhuma, **When** o rito lê o modo, **Then** vale `desligado`.

---

### User Story 2 - Trava de caminhos previstos no lugar da leitura humana (Priority: P1)

Num projeto com modo ligado, toda PR de frente é conferida por uma verificação obrigatória que compara os arquivos tocados com o bloco "Caminhos previstos" do registro da Fase 0 já mergeado na base, e reprova desvios, caminhos de governança e dependências novas não aprovadas.

**Why this priority**: sem essa trava o merge autônomo seria merge sem controle; é a barreira que substitui a leitura humana.

**Independent Test**: PR de teste com arquivo dentro e fora da lista, renomeação, governança e manifesto: só a primeira passa.

**Acceptance Scenarios**:

1. **Given** PR cujos arquivos estão todos na lista (ou em `docs/specs/<frente>/**`), **When** a verificação roda, **Then** publica status de sucesso no HEAD.
2. **Given** arquivo fora da lista, renomeação cujo nome novo ou anterior está fora, ou total listado diferente de `changed_files`, **Then** reprova.
3. **Given** alteração em caminho de governança (constituição, config do cockpit, workflows, CODEOWNERS, configuração do agente etc.), **Then** reprova, salvo acréscimo puro em `permissions.deny`.
4. **Given** PR sem registro (docs, trivial, hotfix) ou de governança, **Then** só passa com aprovação de dono no commit atual, com reexecução após a aprovação.
5. **Given** PR de correção ou revert, **Then** só pode tocar arquivos da PR original da frente, identificada pelo registro e mergeada na mesma base, que também estejam no bloco "Caminhos previstos" dessa frente.
6. **Given** PR para a produção, **Then** passa sozinha só a PR de promoção (cabeça = branch de integração do mesmo repositório); qualquer outra só com aprovação de dono no commit atual.

---

### User Story 3 - Merge autônomo com identidade e ruleset conferidos (Priority: P1)

Com o modo ligado, o agente, usando identidade própria de privilégio mínimo, só liga o auto-merge (squash) depois de conferir no GitHub que o ruleset da integração não tem bypass e exige `ci`, `commitlint` e `caminhos-previstos`. Falhando a conferência, o modo vale `desligado` e o rito para no gate humano. O agente nunca usa `--admin`.

**Why this priority**: sem identidade e ruleset corretos as travas seriam contornáveis; esta story fecha o circuito do merge.

**Independent Test**: com ruleset incompleto o agente para no gate humano; com ruleset correto a PR com CI verde mergeia sozinha.

**Acceptance Scenarios**:

1. **Given** ruleset completo e identidade conferida, **When** a PR está pronta, **Then** o auto-merge é ligado e o merge ocorre quando os checks passam.
2. **Given** ruleset com bypass ou check obrigatório faltando, ou identidade sem a conferência, **Then** o modo vale `desligado` e o rito para no gate humano.
3. **Given** modo ligado, **Then** o `require-codeowner-approval` passa com aviso e o `audit-merge-vermelho` não abre issue por merge autônomo.
4. **Given** push direto, `--admin` ou status forjado com a credencial do agente, **Then** são recusados.

---

### User Story 4 - Registro da Fase 0 aprovado pelo owner (Priority: P2)

No modo ligado, depois do Gate 0, o registro de decisões vai numa PR própria aprovada e mergeada pelo owner, e a trava lê o plano dessa base, nunca da PR em análise.

**Why this priority**: sem isso a trava confere o agente contra si mesmo; é pré-condição de US2, mas só se aplica ao modo ligado.

**Independent Test**: frente trivial em repositório descartável com modo ligado: PR de registro aprovada pelo owner antes da PR de código.

**Acceptance Scenarios**:

1. **Given** modo ligado e Gate 0 dado, **Then** a skill de descoberta abre a PR de registro e espera o merge do owner antes de seguir.
2. **Given** modo desligado, **Then** o fluxo é o de hoje (1º commit da worktree), sem PR de registro.

---

### User Story 5 - Correções limitadas, revert e frente estacionada (Priority: P2)

CI vermelho antes do merge: até 2 correções na mesma branch; no 3º vermelho o auto-merge é desligado, a PR vira rascunho `estacionada` com diagnóstico e recomendação. Smoke falho na integração: até 2 PRs de correção contadas por rótulo; na 3ª falha, reverts um por vez em ordem inversa, parando e voltando ao owner se o revert tiver conflito ou CI vermelho.

**Why this priority**: define o comportamento de falha sem laço infinito.

**Independent Test**: roteiro de falha no repositório descartável: CI vermelho não mergeia; smoke vermelho gera 2 correções e reverts na 3ª, contados pela listagem de PRs.

**Acceptance Scenarios**:

1. **Given** 3 SHAs distintos com CI falho, **Then** auto-merge desligado, rascunho `estacionada`, owner avisado; rerun do mesmo SHA não conta.
2. **Given** smoke falho no merge commit da frente, **Then** correção por PR nova a partir da integração, fora da worktree, com rótulo `correcao-<n>`.
3. **Given** smoke falho em SHA que não é o da frente, **Then** volta ao owner sem correção.
4. **Given** 3ª falha, **Then** reverts em ordem inversa, cada um aguardando o merge do anterior; frente estacionada com worktree mantida e sem Fase 11.
5. **Given** ambiente de integração inutilizável afetando outras frentes, **Then** reverte primeiro e corrige depois.

---

### User Story 6 - Smoke autônomo, promoção em lote e rollback (Priority: P2)

Cada frente traz itens de smoke executáveis (`Sn | comando | esperado literal | tipo`, com ao menos um caso negativo), congelados no Gate 0. Frente sem item executável ou irreversível fica no gate humano. Para o lote, um smoke combinado roda no SHA fixado da integração e só esse SHA é promovido por PR de promoção com token de automação; smoke falho em produção reverte a promoção, reverte a culpada na integração e chama o owner.

**Why this priority**: fecha o ciclo até produção, mas depende de US1-US3.

**Independent Test**: lote com frente irreversível para no gate da promoção; smoke de produção falho dispara rollback e revert da culpada.

**Acceptance Scenarios**:

1. **Given** frente sem item de smoke executável, **Then** o merge fica no gate humano.
2. **Given** lote com frente irreversível ou smoke manual, **Then** para no gate humano da promoção.
3. **Given** ponta da integração mudou após o smoke, **Then** o smoke roda de novo antes de promover.
4. **Given** modo ligado sem token de automação, **Then** a promoção não segue autônoma.
5. **Given** smoke de produção falho, **Then** revert da promoção, revert da culpada na integração e aviso ao owner; a próxima promoção começa com o revert do revert.
6. **Given** integração = produção, **Then** a fase de promoção segue no-op e o rollback é o das correções.

---

### User Story 7 - Barreira contra agentes proibidos e lista fechada de plugins (Priority: P2)

Um subcomando de leitura do histórico avalia um plugin instalado e devolve veredito da lista fechada "conteúdo só de agentes" (corrigida: aceita `.in_use/` só com PIDs numéricos, `.orphaned_at` regular e `.md` de agente na raiz com frontmatter válido e nome sem colisão), as regras de deny dos agentes que reprovam nos critérios (a), (b) e (c) e o SHA. A skill mescla essas regras, de forma idempotente, nas permissões da worktree, além de negar edição das próprias configurações.

**Why this priority**: troca o "limite declarado" por barreira técnica e destrava o uso dos plugins do mapa.

**Independent Test**: fixtures de plugin (limpo, `.in_use/` inválido, `.md` colidente, symlink, caminho fora do cache) e, na worktree, a regra gravada bloqueia um agente proibido.

**Acceptance Scenarios**:

1. **Given** plugin limpo, **Then** veredito ok com regras e SHA.
2. **Given** `.in_use/` com nome não numérico, subdiretório ou symlink; `.md` com chave extra ou nome colidente; `hooks/`, `.mcp.json` ou executável, **Then** reprova.
3. **Given** symlink ou `installPath` fora do cache de plugins, **Then** falha fechado.
4. **Given** nome com `..`, plugin duplicado ou lista vazia, **Then** falha.
5. **Given** regra deny gravada que não cobre o conjunto atual (gate da Fase 11 ou SHA divergente), **Then** reprova.

---

### Edge Cases

- Modo ligado na constituição, mas identidade ou ruleset ausentes: vale `desligado` na hora do merge e da promoção (releitura antes de cada um).
- O agente tentar editar a linha `Merge autônomo:` ou a chave: proibido por regra MUST NOT; a trava de governança também reprova.
- Job homônimo `caminhos-previstos` em outro workflow tentando forjar o status: o status só vale com a fonte esperada fixada.
- Renomeação a partir de `.github/**`: reprova pelo nome anterior.
- Revert com conflito ou CI vermelho: para e volta ao owner, sem laço.
- Branch de correção remota já existente: é retomada, não recriada.
- Projeto já ratificado sem a linha: segue com gate humano até emenda própria.
- Sintaxe da regra de deny para agente de plugin não confirmada em fonte oficial ou que não bloqueia no smoke: o rito para.
- Pull request com mais arquivos que o teto de listagem da API: reprova (total diferente de `changed_files`).

## Requirements

### Functional Requirements

- **FR-001**: O configurador MUST aceitar a chave opcional `MODO_AUTONOMO` (`ligado`/`desligado`); ausente ou inválida MUST valer `desligado`, e a atualização de projetos sem a chave MUST NOT falhar.
- **FR-002**: A constituição semente MUST conter a linha literal `Merge autônomo: ligado` ou `Merge autônomo: desligado`, e o Princípio II da semente MUST descrever os dois ramos.
- **FR-003**: O rito MUST ler o modo apenas dessa linha na base de integração, com regra de leitura única citada nas duas skills (exatamente uma linha válida, lida sem o `\r` do CRLF; qualquer outra situação é `desligado`), relendo antes de cada merge e de cada promoção.
- **FR-004**: O agente MUST NOT editar a linha nem a chave; `MODO_AUTONOMO` MUST ser listada entre as chaves que o rito não consome, e o template do rito MUST NOT renderizar o valor.
- **FR-005**: O modo `ligado` MUST valer somente com identidade própria do agente (escrita só em Contents e Pull requests, sem Administration nem Workflows, token fora do repositório) e ruleset sem bypass conferidos na hora; sem eles, vale `desligado`. A fonte da conferência de "sem bypass" é `GET /repos/{owner}/{repo}/rules/branches/{branch}` mais o campo `current_user_can_bypass` de cada ruleset, que deve valer `never`; campo ausente ou outro valor vale `desligado` (a identidade não enxerga `bypass_actors`; a lista vazia é conferida pelo owner). Fonte: <https://docs.github.com/en/rest/repos/rules> (research R3, D-P7).
- **FR-006**: O configurador MUST apenas imprimir a configuração necessária no GitHub (ruleset, auto-merge, identidade) e MUST NOT criar repositório, identidade ou ruleset.
- **FR-007**: No modo ligado, o registro de decisões da Fase 0 MUST ir em PR própria aprovada e mergeada pelo owner, e a trava MUST ler o plano da base, nunca do PR sob análise; no modo desligado o fluxo atual MUST permanecer.
- **FR-008**: MUST existir um workflow-template `caminhos-previstos` que roda a partir da branch padrão sem executar código do PR, publica status no SHA do HEAD com fonte fixada e é check obrigatório no ruleset do modo ligado.
- **FR-009**: A trava MUST reprovar arquivo fora do bloco "Caminhos previstos" (com `docs/specs/<frente>/**` implícito), renomeação com nome novo ou anterior fora, total listado diferente de `changed_files`, caminho de governança e manifesto ou lockfile sem item permanente aprovado (formato fechado da seção "Dependências novas": `Nenhuma.` ou itens `` - `<pacote>` ``; só conta como aprovado o item de lista com trecho de código entre crases, e qualquer outro item ou texto vale "nenhuma"). São governança: `docs/constitution.md`, `cockpit.config`, `.github` e `.github/**`, CODEOWNERS, qualquer componente `.claude` do caminho, em qualquer pasta, `.mcp.json`, `.npmrc`, `.yarnrc.yml`, `CLAUDE.md` e `CLAUDE.local.md` em qualquer pasta (`.claude`, `CLAUDE.md` e `CLAUDE.local.md` sem distinção de maiúsculas; o Claude Code carrega os de subpasta sob demanda, <https://code.claude.com/docs/en/memory>), `.husky` e `.husky/**`, config do commitlint, config do semantic-release (`.releaserc*`, `release.config.*` e a chave `release` do `package.json`, em qualquer pasta; A2) e todo `decisoes-do-owner.md` de qualquer frente (F1); a lista completa e o parse ficam em `contracts/caminhos-previstos.md`. Única exceção: `.claude/settings.json` da raiz com acréscimo puro em `permissions.deny`, definido como: fora de `permissions.deny` os dois JSON (base e HEAD) são iguais, todo item do deny da base continua no do HEAD, e sem o arquivo na base o do HEAD é exatamente `{"permissions":{"deny":[...]}}`; remover regra ou alterar qualquer outra chave reprova; `settings.local.json`, `.claude/settings.json` de subpasta, a renomeação para `.claude/settings.json` e o `.claude/settings.json` que não é arquivo comum (link, conferido pelo `type` da API de conteúdo) nunca passam. Ordem: as reprovações diretas (desta FR e da FR-011, mais lista, HEAD, bloco, frente ambígua e erro de leitura) rodam antes da aprovação de dono, e a aprovação nunca libera arquivo fora do bloco; por isso o caminho de governança que a frente toca MUST estar no bloco, e só passa com o bloco e a aprovação.
- **FR-010**: PR sem registro ou de governança MUST exigir aprovação de dono no commit atual, com reexecução da verificação após a aprovação, e nunca por evento que rode o arquivo do PR. A aprovação é lida só depois de todas as reprovações diretas da FR-009 e da FR-011 e não libera nenhuma delas. PR que só toca registros (`docs/specs/<x>/decisoes-do-owner.md`: PR de registro ou de emenda) MUST ir à aprovação de dono sem validar o bloco, para que um bloco inválido na base não trave a própria emenda; depois do merge, a trava vale pela versão emendada (decisão do owner na rodada 3).
- **FR-011**: PR de correção ou revert MUST tocar só arquivos da PR original da frente, referenciada por número e mergeada na mesma base, que também estejam no bloco "Caminhos previstos" do registro da frente da origem (a origem pode ter sido mergeada no modo desligado, sem trava); a frente MUST ser identificada pelo registro, nunca pelo título ou branch. A trava MUST rodar também em PR para a produção, como check obrigatório nas regras dela: passa sozinha só a PR de promoção (cabeça = branch de integração do mesmo repositório), e qualquer outra PR para a produção MUST exigir aprovação de dono no commit atual (A1 do block-001; a promoção segue autônoma).
- **FR-012**: O merge MUST usar auto-merge por squash, só após conferir ruleset (sem bypass; `ci`, `commitlint` e `caminhos-previstos` obrigatórios; "sem bypass" conferido por `current_user_can_bypass` = `never`, conforme FR-005); MUST NOT usar `--admin` (com `permissions.deny` como camada extra); a branch MUST ser apagada pela configuração do repositório.
- **FR-013**: No modo ligado, `require-codeowner-approval` MUST ler a linha na base e passar com aviso, e `audit-merge-vermelho` MUST NOT abrir issue a cada merge autônomo.
- **FR-014**: CI vermelho antes do merge: até 2 correções por commit na mesma branch contando SHAs distintos com falha (rerun não conta); no 3º vermelho MUST desligar o auto-merge, marcar a PR como rascunho com rótulo `estacionada` e entregar diagnóstico e recomendação.
- **FR-015**: Smoke falho na integração MUST contar só se o run for no merge commit da frente; correção por PR nova a partir da integração, fora da worktree da frente, com rótulo `correcao-<n>`, contagem por listagem de PRs e retomada de branch remota existente; até 2 correções.
- **FR-016**: Na 3ª falha MUST reverter um por vez em ordem inversa (correções primeiro), cada um aguardando o merge do anterior; revert com conflito ou CI vermelho MUST parar e voltar ao owner; a frente fica estacionada, worktree mantida, sem Fase 11. Ambiente inutilizável: reverte primeiro, corrige depois.
- **FR-017**: Cada item de smoke MUST ter o formato `Sn | comando | esperado literal | tipo`, com asserção além do exit code e ao menos um caso negativo, congelado no Gate 0; frente sem item executável MUST ficar com gate humano no merge; irreversibilidade diferente de "Nenhuma" MUST parar no gate da promoção.
- **FR-018**: A promoção MUST usar lote = integração menos produção, smoke combinado no SHA fixado com resultado por frente, promovendo só esse SHA (ponta mudou, roda de novo); lote com frente irreversível ou smoke manual MUST parar no gate humano.
- **FR-019**: No modo ligado a PR de promoção MUST ser criada com token de automação obrigatório (escopo mínimo: escrita só em Contents e Pull requests, sem Administration nem Workflows, restrito a este repositório, identidade fora do CODEOWNERS, nunca o token pessoal do owner; A2/R17), merge commit permitido conferido (o auto-merge segue permitido para as PRs de frente) e rollback anotado antes (SHA pré-promoção). A promoção é por merge direto em X, sem auto-merge: depois do smoke combinado no SHA fixado X e com os checks obrigatórios verdes e a cabeça da PR em X, `gh pr merge <n> --merge --match-head-commit X` (decisão do owner na rodada 2).
- **FR-020**: Smoke de produção falho MUST reverter a promoção como contenção, reverter a culpada na integração, acionar o owner e começar a próxima promoção com o revert do revert; sem culpada isolável, reverte o lote. Com integração = produção, a fase de promoção MUST seguir no-op.
- **FR-021**: MUST existir subcomando de leitura `historico.mjs plugin <installPath>` com saída JSON: veredito da lista fechada, regras deny dos agentes que reprovam em (a), (b) e (c) (todos os `.md` de agente do plugin) e o SHA; MUST falhar fechado com symlink e com `installPath` fora do cache de plugins.
- **FR-022**: A lista fechada MUST aceitar `.in_use/` só com arquivos regulares `^[0-9]+$` (sem subdiretório nem symlink, ENOENT tolerado), `.orphaned_at` regular e `.md` na raiz fora do array de agentes apenas com frontmatter de agente válido e `name` sem colisão (`README.md` exceção); qualquer outro arquivo ou diretório MUST reprovar.
- **FR-023**: A skill MUST mesclar as regras deny (união, idempotente) nas permissões da worktree, mais negação de Edit e Write nas configurações do agente; MUST rodar de novo no gate da Fase 11 e em SHA divergente, reprovando se o deny gravado não cobre o conjunto atual; regra que não bloqueia MUST parar o rito.
- **FR-024**: A skill `rito-dev` e o template do rito MUST ter uma seção "Modo autônomo" com ponteiro nas Fases 6 a 10, mantendo o ramo desligado idêntico ao atual; `CLAUDE.md` semente, papéis implementador e revisor, `project-context` semente e `LEIAME` MUST apontar para o Princípio II em vez de repetir a regra.
- **FR-025**: README e contrato do configurador MUST documentar a chave e o comportamento; testes no CI MUST cobrir os cenários do configurador e do subcomando de plugin.
- **FR-026**: O cockpit MUST manter o gate humano e MUST NOT ganhar a linha `Merge autônomo:`.
- **FR-027**: A frente MUST tocar somente caminhos da lista "Caminhos previstos" do registro de decisões e não introduzir dependência nova.

> Decisões de infraestrutura: N/A para scheduling, rotação de chave, refresh e backup (feature de bash/YAML/Markdown/JS sem estado próprio). Idempotência: a mescla de regras deny (FR-023) é idempotente por união.

### Key Entities

- **Registro da Fase 0**: `decisoes-do-owner.md` mergeado na base; contém caminhos previstos, smoke e irreversibilidade.
- **Modo autônomo**: valor `ligado`/`desligado` derivado da linha da constituição na base.
- **Frente**: unidade de trabalho identificada pelo registro, com PRs de código, correção e revert.
- **Lote de promoção**: conjunto de frentes na integração ainda ausentes da produção, com SHA fixado.
- **Regra deny**: bloqueio de agente proibido ou de edição de configuração, gravado nas permissões da worktree.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% dos projetos já configurados sem a chave continuam atualizando sem erro e com gate humano no merge.
- **SC-002**: Nos casos negativos de trava definidos no smoke (caminho fora da lista, constituição, job homônimo, renomeação de `.github/**`, configuração com hook, status forjado, PR de outra frente, PR sem registro sem aprovação, linha ausente/inválida), 100% resultam em parada, sem merge.
- **SC-003**: Uma frente trivial com CI verde, smoke executável e modo ligado chega de PR aprovada ao merge e ao smoke sem nenhuma ação humana além da aprovação do registro.
- **SC-004**: Em falha roteirizada, o número de PRs de correção nunca passa de 2 por tipo de falha e a 3ª falha termina em revert com o owner avisado, em zero laços.
- **SC-005**: 100% dos fixtures do subcomando de plugin dão o veredito esperado (limpo passa; todos os casos de reprovação e falha reprovam).
- **SC-006**: Na sessão de uma frente, 100% das tentativas de invocar um agente proibido cobertas pelas regras gravadas são bloqueadas.
- **SC-007**: Nenhum arquivo fora dos caminhos previstos aparece no diff da frente.

## Delta Requirements

**Skip**: frente sobre templates, skills e scripts do próprio cockpit, sem corpus canônico `docs/specs/current/` existente — Claude (feature-00c), 2026-11-05

## Clarifications

### Session 2026-11-05

- Q: Como a trava reconhece dependência nova aprovada? → A: pela seção "Dependências novas" do registro da Fase 0 na base, com o manifesto/lockfile listado literalmente em "Caminhos previstos"; sem isso reprova (D2/D3 do registro; decisão operacional, o detalhe de parse fica para o plan).
- Q: Como o smoke compara a saída com o "esperado literal"? → A: substring literal do stdout, sem regex, e exit code coerente com o tipo (0 no positivo, diferente de 0 no negativo) (FR-017/D7).
- Q: O que o rito faz com a PR de registro aberta ou fechada sem merge? → A: para sem polling longo, avisa o owner e retoma só por comando explícito; fechada sem merge encerra a frente como não aprovada, sem abrir nova PR sozinho (FR-007/D3).
- Q: Falha transitória de smoke consome correção? → A: um único rerun do mesmo SHA antes de contar; falhando de novo, conta (FR-015/D6, paralelo ao "rerun não conta" do CI).
- Q: Quando a promoção autônoma dispara no modo ligado? → A: ao fim do smoke de cada frente mergeada, com lote = integração menos produção (FR-018/D8; promoção por frente isolada foi recusada, o SHA do lote é fixado).
- Q: O que é "acréscimo puro em `permissions.deny`"? → A: fora de `permissions.deny` os JSON da base e do HEAD são iguais e todo item do deny da base permanece no HEAD; remoção, alteração de outra chave ou hook reprova, com caso de teste negativo na Fase 4 (CHK014; D-P10).
