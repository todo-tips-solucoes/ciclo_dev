# Feature Specification: templates de automação do cockpit

**Feature**: `templates-automacao`
**Created**: 2026-09-30
**Status**: Draft

> Item 5 do MVP do briefing. Decisões de infraestrutura: N/A (arquivos de texto e um script
> de linha de comando, sem scheduler, sessão, chave criptográfica, multi-réplica ou retry
> próprios; os agendamentos e as tentativas de repetição, se houver, são do provedor de CI do
> projeto-alvo e não do cockpit).

## User Scenarios & Testing

### User Story 1 - Receber o CI que valida o que o Princípio III manda validar só lá (Priority: P1)

A pessoa dona de um projeto-alvo roda o configurador e recebe os fluxos de CI `ci` e
`commitlint`: o primeiro roda typecheck, lint e build com os comandos configurados em todo PR
para a branch de integração e para a de produção; o segundo recusa título de PR e mensagens
fora do Conventional Commits.

**Why this priority**: com o Princípio III ligado a validação local é proibida; sem o CI
gerado não existe gate nenhum, e o ciclo inteiro perde a garantia.

**Independent Test**: renderizar com `cockpit.config.example` num repositório temporário e
conferir que `ci.yml` e `commitlint.yml` existem, são YAML válido, citam os três comandos e as
duas branches da config e não contêm `{{` residual.

**Acceptance Scenarios**:

1. **Given** um projeto configurado, **When** o fluxo `ci` é lido, **Then** executa typecheck,
   lint e build exatamente como configurados, como passos separados e nomeados, disparado em PR
   e em push para as branches de integração e de produção.
2. **Given** comandos configurados com `|`, `&`, `$` ou crase, **When** o fluxo é renderizado,
   **Then** o YAML continua válido e o comando chega ao CI como texto literal.
3. **Given** um PR com título fora do padrão Conventional Commits, **When** o fluxo
   `commitlint` roda, **Then** o check falha com mensagem que aponta o formato esperado.

---

### User Story 2 - Receber o gate humano e a promoção automatizados (Priority: P1)

O projeto recebe `require-codeowner-approval` (PR só é mergeável com aprovação de um dono
declarado), `promotion-pr` (abre ou atualiza o PR de promoção da branch de integração para a de
produção) e `audit-merge-vermelho` (registra, para auditoria, merge feito com check vermelho).

**Why this priority**: o briefing faz do gate humano a espinha do ciclo (o agente nunca aprova
nem mergeia); sem estes fluxos o gate existe só no texto.

**Independent Test**: renderizar e conferir que os três arquivos existem, são YAML válido e
que `promotion-pr` tem a condição de execução correta para branches distintas e iguais.

**Acceptance Scenarios**:

1. **Given** um PR sem aprovação de dono, **When** `require-codeowner-approval` roda, **Then**
   o check falha indicando quem pode aprovar.

   **Garantia (dec-025)**: o que torna o PR "mergeável só com aprovação de dono" é a regra
   nativa da branch (aprovações obrigatórias + "Require review from Code Owners"), aplicada
   pelo dono do projeto-alvo como passo obrigatório de setup (quickstart). O fluxo
   `require-codeowner-approval` é verificação extra, para visibilidade no PR; por rodar a
   versão do arquivo contida no próprio PR, não é garantia contra quem pode alterar o PR.
2. **Given** `BRANCH_INTEGRACAO` diferente de `BRANCH_PRODUCAO`, **When** entra commit na
   branch de integração, **Then** `promotion-pr` abre ou atualiza um único PR de promoção
   para a de produção.
3. **Given** `BRANCH_INTEGRACAO` igual a `BRANCH_PRODUCAO`, **When** o fluxo `promotion-pr`
   roda, **Then** termina sem abrir PR e sem falhar (no-op válido, coerente com a Fase 9 do rito).
4. **Given** um merge com algum check obrigatório vermelho, **When** `audit-merge-vermelho`
   roda, **Then** abre uma issue de auditoria (uma por merge) com PR, autor do merge e checks
   vermelhos.

---

### User Story 3 - Receber donos e release configurados (Priority: P2)

O projeto recebe `CODEOWNERS` com os donos informados no configurador, o fluxo `release` e o
`.releaserc.json` que publicam versão a partir da branch de produção.

**Why this priority**: donos são pré-requisito do gate da US2 (por isso P2 em sequência, mas
o arquivo é pequeno); release é desejável mas o ciclo funciona sem ele na primeira semana.

**Independent Test**: renderizar com duas configs (um dono; vários donos) e conferir o
`CODEOWNERS` e que `.releaserc.json` é JSON válido com a branch de produção da config.

**Acceptance Scenarios**:

1. **Given** `DONOS_CODEOWNERS='@maria-exemplo @jose-exemplo'`, **When** renderizado, **Then**
   `CODEOWNERS` atribui a todos os arquivos os dois donos.
2. **Given** um projeto configurado, **When** `.releaserc.json` é lido, **Then** é JSON válido
   e a única branch de release é a de produção configurada.
3. **Given** um push na branch de produção, **When** o fluxo `release` roda, **Then** executa o
   release com permissão mínima de escrita, sem segredo embutido no arquivo.

---

### User Story 4 - Receber o script de board (Priority: P2)

O projeto recebe `.claude/scripts/task.sh`, executável, que move e consulta cartões do board
(GitHub Projects) e tem o subcomando `discover`, que resolve e imprime os identificadores
(projeto, campo de status e opções) necessários aos demais subcomandos.

**Why this priority**: o board é acompanhamento, não gate; o ciclo roda sem ele.

**Independent Test**: renderizar com `BOARD='org-exemplo/7'` e com `BOARD=''`; rodar
`shellcheck` no resultado e `task.sh --help`; conferir o bit de execução.

**Acceptance Scenarios**:

1. **Given** `BOARD='dono/7'`, **When** `task.sh discover` roda com `gh` autenticado, **Then**
   imprime os IDs resolvidos e sai com 0.
2. **Given** `BOARD=''`, **When** qualquer subcomando roda, **Then** termina com mensagem
   clara de que o projeto não tem board e código de saída distinto de erro de execução.
3. **Given** `gh` ausente ou sem autenticação, **When** o script roda, **Then** falha cedo
   com mensagem acionável, sem alterar nada.

---

### Edge Cases

- **Expressões do GitHub Actions**: `${{ github.x }}` e `${{ secrets.X }}` têm espaços ou
  letras minúsculas e não casam com o padrão `{{CHAVE}}` do configurador; MUST passar intactas
  para o arquivo gerado. Regra de escrita: expressão do Actions sempre com espaço após `{{` e
  antes de `}}`, e nunca com nome todo em maiúsculas e sublinhado colado às chaves.
- **Integração = produção**: `promotion-pr` vira no-op; `ci` não duplica disparo (mesma
  branch não aparece duas vezes em destas listas que o provedor rejeitaria como duplicata).
- **BOARD vazio**: o script gerado continua sintaticamente válido e se recusa a agir com
  mensagem clara; o configurador aceita a chave vazia como hoje.
- **Valores com caracteres especiais**: comandos entram em bloco de texto literal do YAML;
  `BOARD` e donos só são aceitos no formato restrito (FR-015), de modo que nenhum valor
  quebra aspas do script ou injeta em YAML.
- **Edição local**: arquivo gerado editado à mão é preservado pelo configurador (issue #5);
  os templates não exigem mudança no motor para isso.
- **Segunda execução**: rodar o configurador de novo sem mudar a config não altera nenhum
  arquivo, inclusive o modo executável do `task.sh`.
- **Config antiga**: `cockpit.config` sem `DONOS_CODEOWNERS` faz o configurador perguntar só
  essa chave (comportamento de chave faltante já existente).
- **Vazamento**: nenhum template contém nome de projeto, organização, domínio, e-mail pessoal
  ou credencial reais; o verificador de agnosticismo passa com 0 ocorrências.
- **Idioma**: prosa e mensagens em português do Brasil com diacríticos corretos.

## Requirements

### Functional Requirements

- **FR-001**: O cockpit MUST entregar, sob `templates/` com sufixo `.tmpl`, os fluxos
  `ci`, `commitlint`, `require-codeowner-approval`, `promotion-pr`, `audit-merge-vermelho` e
  `release` (diretório de fluxos do provedor de CI), `CODEOWNERS`, `.releaserc.json` e
  `.claude/scripts/task.sh`.
- **FR-002**: Todos os templates MUST ser renderizados pelo motor existente do configurador,
  por substituição literal de chaves do `cockpit.config`, sem nenhuma mudança no motor de
  renderização (as mudanças permitidas em `configurar.sh` são só as do FR-015).
- **FR-003**: Nenhum template MUST usar chave opcional (`URL_AMBIENTE_*`) nem chave fora das
  conhecidas do configurador (as quinze atuais mais `DONOS_CODEOWNERS`).
- **FR-004**: O fluxo `ci` MUST executar `CMD_TYPECHECK`, `CMD_LINT` e `CMD_BUILD` como passos
  distintos, em PR e em push para as branches de integração e de produção, com o comando
  inserido como texto literal (nunca interpretado pelo YAML).
- **FR-005**: O fluxo `ci` MUST preparar o ambiente de dependências usando
  `GERENCIADOR_PACOTES`, com suporte a npm, pnpm, yarn e bun (outros valores viram passo a
  editar à mão) e MUST NOT conter passo de deploy; deploy é do rito, não do CI.
- **FR-006**: O fluxo `commitlint` MUST validar o título do PR e as mensagens de commit contra
  o padrão Conventional Commits.
- **FR-007**: O fluxo `require-codeowner-approval` MUST falhar enquanto o PR não tiver
  aprovação de ao menos um dono declarado em `CODEOWNERS`, e MUST NOT aprovar nem mergear nada.
  A garantia de aprovação de dono é a regra nativa da branch (aprovações obrigatórias +
  "Require review from Code Owners"), não este fluxo: ele é verificação extra e forjável por
  conteúdo do PR (dec-025). Cada dono de `DONOS_CODEOWNERS` MUST ter permissão de escrita no
  repositório; um dono sem ela é aceito pelo fluxo (que só compara o login do review) mas não
  conta para a regra nativa, e o PR fica sem aprovação válida até outro dono aprovar.
- **FR-008**: O fluxo `promotion-pr` MUST abrir ou atualizar um único PR de promoção da branch
  de integração para a de produção, e MUST ser no-op sem falha quando as duas branches forem
  iguais.
- **FR-009**: O fluxo `audit-merge-vermelho` MUST registrar, abrindo uma issue de auditoria por
  merge, todo merge ocorrido com check obrigatório vermelho (PR, responsável pelo merge,
  checks vermelhos).
- **FR-010**: O fluxo `release` MUST rodar só na branch de produção, com permissões mínimas,
  usando por padrão o `GITHUB_TOKEN` do provedor e, se o projeto definir o segredo opcional de
  PAT/App, usando-o no lugar; credenciais só pelo mecanismo de segredos do provedor, sem
  embutir segredo; os limites do `GITHUB_TOKEN` (ex.: não dispara outros fluxos, escopo de
  permissões) MUST ser confirmados em fonte oficial no plano (Princípio V).
- **FR-011**: `.releaserc.json` MUST ser JSON válido, com a branch de produção configurada como
  única branch de release.
- **FR-012**: `CODEOWNERS` MUST atribuir todos os caminhos aos donos de `DONOS_CODEOWNERS`.
- **FR-013**: `task.sh` MUST ser executável, ter os subcomandos `discover`, `move`, `list` e
  `--help` (`move` por nome de opção de status, resolvido no `discover`), resolver
  no `discover` os identificadores do board a partir de `BOARD`, falhar cedo e com mensagem
  acionável se `gh` faltar ou não estiver autenticado, e, com `BOARD` vazio, recusar agir com
  mensagem clara e código de saída próprio.
- **FR-014**: `task.sh` renderizado MUST passar em `shellcheck` sem findings e ser
  idempotente na renderização (bit de execução incluído).
- **FR-015**: O configurador MUST ganhar a chave obrigatória `DONOS_CODEOWNERS` (pergunta,
  validação, gravação no `cockpit.config`, constante de chaves e `cockpit.config.example`):
  um ou mais donos separados por espaço, cada um `@usuario` (usuário individual); `@org/time`
  MUST ser recusado com mensagem clara (resolver membros de time exige credencial com leitura
  da organização, fora do escopo); e MUST passar a
  validar `BOARD` como vazio ou `dono/número` (número inteiro positivo).
- **FR-016**: Nenhum template MUST conter valor específico de projeto, e-mail pessoal ou
  credencial; o verificador de agnosticismo MUST passar com zero ocorrências.
- **FR-017**: Expressões `${{ ... }}` do provedor de CI MUST atravessar a renderização
  intactas, e o teste MUST falhar se alguma delas for alterada ou se sobrar `{{CHAVE}}`.
- **FR-018**: A prosa e as mensagens MUST estar em português do Brasil com diacríticos
  corretos.
- **FR-019**: Um teste MUST renderizar todos os templates com `cockpit.config.example` e falhar
  se houver placeholder residual, arquivo faltante, YAML ou JSON inválido, `shellcheck` com
  finding no `task.sh`, modo não executável no `task.sh` ou segunda execução que altere
  algum arquivo.
- **FR-020**: Os templates MUST ser coerentes com o Princípio III da constituição do projeto
  (validação só no CI quando ligado): o `ci` roda em ambos os valores de `PRINCIPIO_III`, por
  ser o gate de qualquer modo.

### Key Entities

- **Template de automação**: arquivo `.tmpl` sob `templates/` cujo destino é o mesmo caminho
  sem o sufixo.
- **Chave do cockpit**: par `CHAVE='valor'` do `cockpit.config` que substitui `{{CHAVE}}`.
- **Dono**: handle de usuário individual do provedor, declarado em `DONOS_CODEOWNERS`.
- **Board**: projeto do provedor identificado por `dono/número`.

## Clarifications

### Session 2026-09-30

- Q: Donos do CODEOWNERS — chave nova ou derivação de IDENTIDADES? → A: Chave nova
  `DONOS_CODEOWNERS`. O motor só faz substituição literal (derivar exigiria mudar o script do
  mesmo jeito), e o e-mail `noreply` nem sempre carrega o login (formato antigo sem ID),
  então derivar seria frágil; a chave explícita é auditável.
- Q: `${{ expr }}` conflita com `{{CHAVE}}`? → A: Não: o padrão do motor exige só
  maiúsculas, dígitos e sublinhado entre as chaves, sem espaço; expressões do Actions têm
  espaço e passam intactas. Regra de escrita nos Edge Cases; teste em FR-017.
- Q: Formato de `BOARD`? → A: `dono/número`, ou vazio (sem board). Restringir evita
  injeção de aspas no script gerado.
- Q: `BOARD` vazio faz `task.sh` ser no-op ou falhar? → A: recusa com mensagem clara e
  código de saída próprio, para que ninguém ache que movimentou cartão.
- Q: `@org/time` em `DONOS_CODEOWNERS`? → A: recusado (só `@usuario`); resolver membros de
  time exige credencial com leitura da organização (resposta humana, block-001; Princípio V
  a confirmar no plano).
- Q: Registro do `audit-merge-vermelho`? → A: uma issue de auditoria por merge (block-002).
- Q: Credencial do `release`? → A: `GITHUB_TOKEN` com PAT/App opcional via segredo
  (block-003); limites a confirmar em fonte oficial no plano.
- Q: Gerenciadores suportados no `ci`? → A: npm, pnpm, yarn, bun (dec-009).
- Q: Subcomandos do `task.sh`? → A: `discover`, `move`, `list` (dec-010).
- Q: Release do projeto-alvo? → A: fluxo e `.releaserc.json` publicam a partir da branch de
  produção; o release do próprio cockpit é tag manual e fica fora desta feature.

## Assumptions

- Decisão (inferência): o provedor de CI e o de board são o GitHub (briefing, stack: `gh` CLI,
  GitHub Actions); o projeto-alvo é assumido hospedado lá.
- Decisão: a preparação de dependências do `ci` usa `GERENCIADOR_PACOTES`; projetos sem
  gerenciador de pacotes editam o arquivo à mão (preservado pelo configurador, issue #5).
- Decisão: `DONOS_CODEOWNERS` entra como chave obrigatória (sem padrão sugerido), na ordem
  após `IDENTIDADES`.
- Decisão: a lista de passos e nomes exatos de checks fica para o plano; aqui só o contrato
  observável.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Render com a config de exemplo produz os 9 arquivos de automação com 0
  placeholders residuais e 0 expressões `${{ }}` alteradas.
- **SC-002**: 100% dos YAML e JSON gerados são válidos e `shellcheck` reporta 0 findings no
  `task.sh`.
- **SC-003**: O verificador de agnosticismo reporta 0 ocorrências sobre todos os arquivos
  rastreados.
- **SC-004**: Uma segunda execução do configurador altera 0 arquivos gerados.
- **SC-005**: Com branches iguais, o fluxo de promoção termina sem PR e sem falha em 100% dos
  cenários de teste.

## Delta Requirements

**Skip**: arquivos novos sob `templates/`; a mudança em `configurar.sh` (FR-015) é aditiva e não há corpus `docs/specs/current/` a referenciar — paulotodo (agente), 2026-09-30.
