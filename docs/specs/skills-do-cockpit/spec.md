# Feature Specification: Skills do cockpit + alinhamento do briefing

**Feature**: `skills-do-cockpit`
**Created**: 2026-09-28
**Status**: Draft

## Clarifications

### Session 2026-09-28

- Q: A seção "## Fases" de `~/.claude/skills/rito-dev-nav/SKILL.md` deve ser usada
  como fonte-base para as 11 fases do rito-dev do cockpit, ou as fases devem ser
  definidas do zero nesta spec? → A: Usar como fonte-base, adaptada para ser
  agnóstica (Princípio I) — tudo que é específico do nav (staging, prod, nomes de
  projeto/org) vira parâmetro do `cockpit.config`.
- Q: A fonte candidata tem 12 seções (Fase 0 a Fase 11), mas o briefing fixa "11
  fases" — como reconciliar a contagem? → A: Fase 0/Sincronizar é etapa
  preparatória, não conta como fase do rito; as 11 fases do rito-dev do cockpit
  correspondem a Fase 1 até Fase 11 da fonte candidata.
- Q: O mapeamento fino das chaves adicionais de `cockpit.config` (ambientes, URLs,
  notificações, nomes de organização/repositório) deve ser travado agora no
  clarify, ou deferido para o `/plan`? → A: Deferir para o `/plan` — FR-005 já
  define o conjunto mínimo de chaves como extensível ("no mínimo"); mapeamento
  fino é decomposição técnica, papel do `/plan`.

## User Scenarios & Testing

### User Story 1 - Seguir o rito de desenvolvimento lendo os parâmetros do projeto-alvo (Priority: P1)

Um dev do time (ou o Claude Code em seu nome) segue o rito de desenvolvimento do ciclo,
fase a fase, usando uma skill que nunca precisa ser editada: ela lê, em tempo de
execução, os parâmetros que variam de projeto para projeto (nome, identificador do
repositório remoto, branches de integração e produção, gerenciador de pacotes, comandos
de qualidade e de deploy) a partir de um arquivo de configuração do próprio
projeto-alvo. Esta frente entrega a skill e o formato mínimo desse arquivo, com um
exemplo de referência preenchido — ainda não existe um configurador que o gere
perguntando ao owner; até lá, o arquivo é preenchido à mão a partir do exemplo.

**Why this priority**: é o fio condutor de todo o ciclo — sem ele, cada projeto continua
copiando o rito à mão e divergindo, que é exatamente o problema que motivou o cockpit
(docs/briefing.md, Problema que Resolve). Sem o formato mínimo do arquivo de
configuração também não há como a skill funcionar hoje, nem como o configurador (frente
seguinte) saber o que gravar.

**Independent Test**: preencher o arquivo de exemplo à mão para um projeto fictício e
verificar que a skill consegue percorrer as fases do rito citando os parâmetros lidos
desse arquivo (branch, comandos etc.), sem nenhuma edição da skill em si.

**Acceptance Scenarios**:

1. **Given** um projeto-alvo qualquer com o arquivo de configuração preenchido a partir
   do exemplo de referência, **When** um dev invoca a skill do rito nesse projeto,
   **Then** a skill identifica corretamente os parâmetros daquele projeto (branches,
   comandos de qualidade, comando de deploy) sem citar nenhum valor de outro projeto.
2. **Given** o arquivo de exemplo de referência, **When** alguém o lê sem qualquer outro
   contexto, **Then** consegue entender o que cada chave representa e preencher a sua
   própria versão sem consultar o código da skill.
3. **Given** duas execuções do rito em dois projetos-alvo diferentes, **When** cada um
   usa seu próprio arquivo de configuração, **Then** nenhum parâmetro de um projeto
   aparece na execução do outro.
4. **Given** um `cockpit.config` ausente no projeto-alvo, ou presente mas faltando uma
   das chaves obrigatórias definidas em FR-005, **When** um dev invoca a skill do rito
   nesse projeto, **Then** a skill interrompe antes de executar qualquer fase e informa
   explicitamente qual chave falta (ou que o arquivo está ausente), sem seguir adiante
   com um valor presumido ou de outro projeto.

---

### User Story 2 - Abrir uma frente de trabalho isolada sem hardcode (Priority: P2)

Um dev do time abre uma frente de trabalho nova numa cópia isolada do repositório
(worktree), a partir de uma base explícita, sem interromper a branch em que já estava
trabalhando — usando a skill do cockpit, não uma cópia ad-hoc mantida à mão em cada
projeto.

**Why this priority**: é o primeiro passo de toda frente do rito (User Story 1 depende
dele) e hoje é um script herdado, testado, mas sem uma cópia própria do cockpit — cada
projeto que replicou o ciclo à mão também replicou (ou desatualizou) este passo.

**Independent Test**: instalar só esta skill num ambiente novo e abrir uma worktree
informando uma base explícita; verificar que a worktree nasce daquela base, isolada da
árvore principal, sem qualquer nome de projeto real embutido na skill.

**Acceptance Scenarios**:

1. **Given** um repositório qualquer com uma branch de base explícita informada,
   **When** o dev invoca a skill, **Then** uma worktree isolada é criada a partir
   daquela base, sem alterar o checkout da árvore principal.
2. **Given** a skill instalada em qualquer projeto, **When** seu conteúdo é lido,
   **Then** nenhum nome de projeto, organização ou branch real aparece como literal —
   só como parâmetro.

---

### User Story 3 - Revisão adversarial padronizada antes da PR (Priority: P3)

O Claude Code roda, antes de abrir a PR de qualquer frente, uma revisão adversarial
padronizada do diff — a mesma ferramenta usada por qualquer projeto que adote o
cockpit — e a origem dessa ferramenta (com sua licença) fica documentada e auditável.

**Why this priority**: é o gate de qualidade que antecede a PR em toda frente de trilha
completa (docs/constitution.md, Princípio II); sem uma cópia própria do cockpit, cada
projeto dependeria de ter a skill original instalada por fora, sem garantia de
disponibilidade nem de proveniência documentada.

**Independent Test**: instalar só esta skill num ambiente novo, apontar para um diff de
exemplo e verificar que ela produz um relatório de achados triados; conferir que a
licença de origem está listada, verbatim, no registro de dependências de terceiros do
repositório.

**Acceptance Scenarios**:

1. **Given** um diff de código qualquer, **When** a skill é invocada, **Then** ela
   produz um relatório de achados organizados por categoria de ação (igual ao
   comportamento da ferramenta de origem).
2. **Given** o repositório do cockpit, **When** alguém procura a proveniência dessa
   skill, **Then** encontra a licença de origem, reproduzida na íntegra, num único
   registro de dependências de terceiros.

---

### User Story 4 - Briefing e histórico do repositório sem divergência (Priority: P4)

O owner e qualquer novo colaborador leem o escopo do MVP (docs/briefing.md) e o
histórico do repositório sem encontrar informação desatualizada ou uma decisão tomada
que não ficou registrada em lugar nenhum.

**Why this priority**: é a menor das quatro entregas e não bloqueia as demais, mas sua
ausência deixa uma contradição documentada (o briefing descreve um comportamento que a
própria constitution já revogou) e uma decisão do owner (a exceção da PR #1) que hoje só
existe na memória de quem participou da sessão.

**Independent Test**: ler o item 1 do MVP em docs/briefing.md lado a lado com o
Princípio IV da constitution e confirmar que descrevem o mesmo comportamento; procurar,
dentro de docs/, o registro da exceção de merge da PR #1 sem precisar rodar `git log`.

**Acceptance Scenarios**:

1. **Given** o item 1 do MVP em docs/briefing.md, **When** comparado ao Princípio IV
   (emenda 1.1.0) da constitution, **Then** os dois descrevem o mesmo comportamento do
   instalador (verifica e imprime; nunca instala nem atualiza terceiro por conta
   própria).
2. **Given** o histórico do repositório, **When** alguém procura por que a PR #1 não
   seguiu a regra de merge por squash do Fluxo de Trabalho, **Then** encontra, dentro de
   docs/, o registro de que foi uma exceção aceita explicitamente pelo owner — sem que a
   regra em si tenha mudado.

---

### Edge Cases

- O que acontece quando o arquivo de configuração do projeto-alvo está ausente ou com
  uma chave obrigatória faltando? A skill do rito precisa dizer qual chave falta, nunca
  seguir adiante com um valor presumido.
- O que acontece quando alguém tenta preencher o arquivo de configuração copiando um
  valor de outro projeto real (nome, org/repo) para dentro do próprio exemplo de
  referência versionado no cockpit? O exemplo em si nunca pode conter esse valor — só o
  arquivo de cada projeto-alvo, que não é versionado no cockpit.
- O que acontece se a skill de revisão adversarial for atualizada na origem depois desta
  cópia? Não é tratado por esta frente (a cópia é estática; atualização da cópia é
  trabalho futuro, não automático — Princípio IV da constitution).

## Requirements

### Functional Requirements

- **FR-001**: O repositório MUST conter, em `skills/`, um diretório por skill do
  cockpit (`parallel-work`, `rito-dev`, `bmad-code-review`), no formato de skill
  reconhecido pelo Claude Code, pronto para a etapa de instalação copiar para o
  diretório de skills do usuário.
- **FR-002**: A skill `parallel-work` do cockpit MUST permitir abrir uma worktree
  isolada a partir de uma base explícita, sem interromper o checkout da árvore
  principal e sem citar nome de projeto ou organização reais.
- **FR-003**: A skill `rito-dev` MUST descrever, fase a fase, o rito de desenvolvimento
  do ciclo, sem nenhum parâmetro que varie entre projetos-alvo embutido como literal na
  skill.
- **FR-004**: A skill `rito-dev` MUST ler, em tempo de execução, os parâmetros do
  projeto-alvo a partir de um arquivo de configuração presente nesse projeto — nunca de
  um valor fixo na própria skill.
- **FR-005**: O cockpit MUST definir o conjunto mínimo de chaves que o arquivo de
  configuração precisa conter para a skill `rito-dev` operar — no mínimo: nome do
  projeto, identificador do repositório remoto, branch de integração, branch de
  produção, gerenciador de pacotes e comandos de qualidade (typecheck/lint/build) e de
  deploy por ambiente — cada chave com seu propósito documentado.
- **FR-006**: O repositório MUST conter um arquivo de exemplo de configuração na raiz,
  preenchido com valores fictícios genéricos, cobrindo todas as chaves mínimas do
  FR-005, servindo de referência para preenchimento manual antes de existir um
  configurador automático.
- **FR-007**: A skill `bmad-code-review` do cockpit MUST reproduzir o comportamento da
  skill de origem (revisão adversarial em camadas paralelas, com triagem estruturada dos
  achados), sem mudança de comportamento em relação à origem.
- **FR-008**: O repositório MUST conter um registro de dependências de terceiros na
  raiz, listando a cópia da skill de revisão adversarial com a licença de origem
  reproduzida na íntegra e a atribuição ao projeto de origem.
- **FR-009**: Nenhum arquivo entregue por esta feature (as três skills, o exemplo de
  configuração, o registro de dependências de terceiros) MUST citar nome de projeto,
  cliente, organização, domínio ou credencial reais — inclusive não pode citar o próprio
  repositório do cockpit como se fosse um projeto-alvo.
- **FR-010**: A checagem de agnosticismo do repositório, executada sobre o repositório
  inteiro após esta feature, MUST continuar reportando zero ocorrências da lista
  proibida.
- **FR-011**: Rodar a etapa de instalação das skills do cockpit num ambiente onde
  `skills/` está presente MUST resultar nas três skills copiadas para o diretório de
  skills do usuário, sem reportar o diretório como ausente.
- **FR-012**: O item 1 do MVP em docs/briefing.md MUST descrever o comportamento atual
  do instalador (verifica e imprime o comando oficial; nunca instala nem atualiza
  terceiro por conta própria) — consistente com a emenda vigente do Princípio IV da
  constitution, sem reintroduzir a descrição anterior de instalação automática.
- **FR-013**: O repositório MUST registrar, em local navegável dentro de `docs/`, que a
  PR #1 foi mesclada por merge commit como exceção aceita explicitamente pelo owner à
  regra de merge por squash do Fluxo de Trabalho — sem alterar a regra em si na
  constitution.
- **FR-014**: A skill `rito-dev` MUST cobrir as 11 fases do rito de desenvolvimento
  citadas em docs/briefing.md (item 3 do MVP), usando como fonte-base a seção
  "## Fases" de `~/.claude/skills/rito-dev-nav/SKILL.md` — especificamente Fase 1
  (Branch) até Fase 11 (Encerramento) dessa fonte; a Fase 0 (Sincronizar) da fonte é
  etapa preparatória e não conta como uma das 11 fases do rito. A skill `rito-dev`
  MUST adaptar cada fase para ser agnóstica de projeto (Princípio I): todo valor
  específico do projeto de origem na fonte (nomes de branch como `staging`/`main`, ambientes,
  URLs, nome de projeto/organização/repositório) MUST virar parâmetro lido do
  `cockpit.config` (FR-004/FR-005), nunca literal na skill. O mapeamento fino de
  quais chaves adicionais de `cockpit.config` cada fase específica consome fica
  para o `/plan` (decomposição técnica), respeitando o conjunto mínimo já fixado
  pelo FR-005.

> Decisões de infraestrutura: N/A (feature entrega documentação e skills estáticas —
> sem scheduler, sessão persistente, refresh de token externo ou rotação de chave).

### Key Entities

- **Arquivo de configuração do projeto-alvo**: conjunto mínimo de parâmetros que variam
  de projeto para projeto (branches, comandos, identificadores), lido em tempo de
  execução pela skill `rito-dev`; cada projeto-alvo tem o seu, nunca versionado dentro
  do cockpit — só o exemplo de referência é.
- **Skill do cockpit**: pacote de instrução copiado pela etapa de instalação para o
  diretório de skills do usuário; três instâncias nesta feature (`parallel-work`,
  `rito-dev`, `bmad-code-review`).
- **Registro de dependências de terceiros**: lista, com licença verbatim, de toda cópia
  de código de terceiro trazida pelo cockpit.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A etapa de instalação das skills do cockpit deixa de reportar o diretório
  de skills como ausente e instala as três skills em 100% das execuções em que `skills/`
  está presente no cockpit.
- **SC-002**: A checagem de agnosticismo do repositório reporta 0 ocorrências proibidas
  ao rodar sobre o repositório inteiro, incluindo os arquivos novos desta feature.
- **SC-003**: Um dev consegue percorrer as 11 fases do rito usando só a skill `rito-dev`
  e um arquivo de configuração preenchido a partir do exemplo, sem editar a skill nem
  consultar o repositório do cockpit.
- **SC-004**: O item 1 do MVP em docs/briefing.md e o Princípio IV da constitution, lidos
  lado a lado, descrevem exatamente o mesmo comportamento do instalador — nenhuma
  divergência entre os dois textos.
- **SC-005**: Um leitor encontra o registro da exceção de merge da PR #1 navegando
  apenas dentro de docs/, sem precisar consultar o histórico do git.

## Delta Requirements

**Skip**: não há corpus canônico em `docs/specs/current/` neste repositório ainda — as
três skills e o alinhamento do briefing são capacidade nova, não alteração de
comportamento hoje documentado como ativo. — agente-00c-feature-orchestrator, 2026-09-28
