# Feature Specification: templates de governança do cockpit

**Feature**: `templates-governanca`
**Created**: 2026-09-29
**Status**: Draft

> Item 4 do MVP do briefing. Decisões de infraestrutura: N/A (arquivos de texto
> estáticos, sem scheduler, sessão, chave criptográfica, multi-réplica ou retry).

## User Scenarios & Testing

### User Story 1 - Receber a constituição do projeto já parametrizada (Priority: P1)

A pessoa dona de um projeto-alvo roda o configurador e recebe `docs/constitution.md`
com os princípios do ciclo (II, II-bis, III, IV, IV-bis, V, VI, VII, VIII) redigidos de
forma genérica, os valores do projeto (branches, comandos, identidades) já
substituídos e uma seção vazia, claramente marcada, para os princípios próprios do projeto.

**Why this priority**: a constituição é o documento que o `/feature-00c` lê como
pré-requisito; sem ela o ciclo não roda no projeto-alvo.

**Independent Test**: rodar o configurador com `cockpit.config.example` num repositório
temporário e conferir que `docs/constitution.md` existe, contém os nove princípios e a
seção de princípios próprios, e não contém `{{`.

**Acceptance Scenarios**:

1. **Given** um projeto configurado, **When** o configurador renderiza, **Then**
   `docs/constitution.md` lista os princípios II, II-bis, III, IV, IV-bis, V, VI, VII e VIII,
   nessa ordem, e uma seção "Princípios próprios do projeto" sem princípio preenchido.
2. **Given** `PRINCIPIO_III='ligado'`, **When** a constituição é lida, **Then** o Princípio III
   declara a validação local proibida (typecheck/lint/build só no CI, smoke em integração e produção).
3. **Given** `PRINCIPIO_III='desligado'`, **When** a constituição é lida, **Then** o Princípio III
   declara explicitamente que não se aplica ao projeto, e o texto continua coerente (sem
   contradição com o restante).
4. **Given** branch de integração igual à de produção, **When** a constituição é renderizada,
   **Then** nenhuma frase fica contraditória: o texto trata a promoção como no-op nesse caso.

---

### User Story 2 - Receber o contrato com o agente e o rito escritos no projeto (Priority: P1)

O projeto recebe `CLAUDE.md` (contrato com o agente), `docs/rito-dev.md` (o rito de 11 fases
com os comandos e branches do projeto) e `docs/CICLO-GIT.md` (modelo de branches, commits e
identidades) coerentes com as skills `rito-dev` e `parallel-work` do cockpit.

**Why this priority**: são o que o agente e o time leem no dia a dia; divergir das skills
gera instruções conflitantes.

**Independent Test**: renderizar e verificar que as onze fases do rito aparecem em
`docs/rito-dev.md`, que os nomes de branch e comandos configurados aparecem nos três
arquivos e que `CLAUDE.md` aponta para a constituição e para o rito.

**Acceptance Scenarios**:

1. **Given** um projeto configurado, **When** `docs/rito-dev.md` é lido, **Then** contém as
   fases de 1 a 11 com os mesmos gates da skill `rito-dev` (parada no review, nunca `git add -A`,
   nunca push direto em branch de integração ou produção).
2. **Given** `IDENTIDADES` configurada, **When** `docs/CICLO-GIT.md` é lido, **Then** a tabela de
   identidades do projeto aparece integralmente e a regra "cada autor com a própria identidade" está declarada.
3. **Given** `CLAUDE.md` renderizado, **When** um agente o lê, **Then** encontra o caminho da
   constituição, do rito, do contexto do projeto e dos quatro papéis de agente.

---

### User Story 3 - Receber os quatro papéis de agente (Priority: P2)

O projeto recebe `docs/agentes/guardiao.md`, `implementador.md`, `revisor.md` e `triador.md`,
cada um descrevendo responsabilidade, entradas, saídas e limites do papel, com o revisor
atrelado ao gate humano e o implementador atrelado ao `/feature-00c`.

**Why this priority**: sem os papéis o agente não sabe onde termina sua autoridade; mas o
ciclo funciona minimamente sem eles.

**Independent Test**: renderizar e conferir que existem os quatro arquivos, cada um com as
seções Responsabilidade, Entradas, Saídas e Limites.

**Acceptance Scenarios**:

1. **Given** um projeto configurado, **When** os quatro arquivos são listados, **Then** todos
   existem sob `docs/agentes/` com as quatro seções.
2. **Given** `docs/agentes/revisor.md`, **When** lido, **Then** declara que o revisor nunca
   aprova nem faz merge, e que a aprovação é sempre de um humano.

---

### User Story 4 - Receber o contexto do projeto para preenchimento (Priority: P2)

O projeto recebe `docs/project-context.md`, com os parâmetros do ciclo já preenchidos e
seções guiadas (arquitetura, convenções de domínio, áreas sensíveis) que a pessoa completa à mão.

**Why this priority**: dá ao agente o contexto de domínio que o cockpit, agnóstico, não pode conhecer.

**Independent Test**: renderizar e conferir que o arquivo contém os parâmetros e as seções
guiadas, sem `{{`.

**Acceptance Scenarios**:

1. **Given** um projeto configurado, **When** `docs/project-context.md` é lido, **Then** os
   parâmetros do ciclo aparecem preenchidos e as seções de domínio estão presentes para preenchimento manual.

---

### Edge Cases

- **Board vazio**: `BOARD=''` (chave definida e vazia) MUST renderizar sem quebrar o texto
  (a frase que cita o board continua correta lida com valor vazio).
- **Chaves opcionais ausentes**: `URL_AMBIENTE_INTEGRACAO` e `URL_AMBIENTE_PRODUCAO` não são
  usadas em nenhum template, para que a ausência delas não produza placeholder residual.
- **Valores com caracteres especiais** (`|`, crases, `&`, `$`): comandos configurados são
  inseridos em blocos de código ou texto literal, sem serem reinterpretados.
- **Edição local**: o configurador já preserva arquivo editado à mão; os templates não
  exigem mudança no script para isso.
- **Vazamento**: nenhum template contém nome de projeto, organização, domínio ou credencial reais;
  o verificador de agnosticismo do repositório passa com 0 ocorrências.
- **Idioma**: a prosa dos templates fica em português do Brasil com diacríticos corretos; texto sem acentuação é defeito.
- **Segunda execução**: rodar o configurador de novo sem mudar a config não altera os arquivos gerados.

## Requirements

### Functional Requirements

- **FR-001**: O cockpit MUST entregar os templates `docs/constitution.md`, `CLAUDE.md`,
  `docs/rito-dev.md`, `docs/CICLO-GIT.md`, `docs/agentes/guardiao.md`,
  `docs/agentes/implementador.md`, `docs/agentes/revisor.md`, `docs/agentes/triador.md` e
  `docs/project-context.md`, todos sob `templates/` com sufixo `.tmpl`.
- **FR-002**: Todos os templates MUST ser renderizados pelo configurador existente sem
  alteração do script, usando apenas substituição literal de chaves do `cockpit.config`.
- **FR-003**: Nenhum template MUST usar chave opcional (URLs de ambiente) nem chave fora das
  quinze conhecidas do configurador.
- **FR-004**: A constituição gerada MUST conter os Princípios II, II-bis, III, IV, IV-bis, V, VI,
  VII e VIII com conteúdo genérico e uma seção vazia de princípios próprios do projeto.
- **FR-005**: O Princípio III MUST ser correto para `ligado` e para `desligado`, exibindo o valor
  configurado e dizendo o que vale em cada caso.
- **FR-006**: O rito gerado MUST conter as 11 fases e os gates gerais da skill `rito-dev`, e
  MUST tratar o caso "integração = produção" como válido (promoção no-op).
- **FR-007**: `CLAUDE.md` gerado MUST apontar para constituição, rito, ciclo git, contexto do
  projeto e papéis de agente, e MUST declarar que o agente para no gate de review.
- **FR-008**: `docs/CICLO-GIT.md` MUST declarar modelo de branches, Conventional Commits em
  português, squash em feature e merge commit em promoção, e a tabela de identidades configurada.
- **FR-009**: Cada papel de agente MUST ter Responsabilidade, Entradas, Saídas e Limites; o
  revisor MUST NOT aprovar nem mergear e o implementador MUST usar o `/feature-00c`.
- **FR-010**: `docs/project-context.md` MUST trazer os parâmetros do ciclo preenchidos e seções
  guiadas para preenchimento manual.
- **FR-011**: Nenhum template MUST conter valor específico de projeto; o verificador de
  agnosticismo MUST passar com zero ocorrências.
- **FR-012**: A prosa MUST estar em português do Brasil com diacríticos corretos.
- **FR-013**: Um teste MUST renderizar todos os templates com `cockpit.config.example` e
  falhar se houver placeholder residual, arquivo faltante ou princípio ausente.
- **FR-014**: A renderização MUST ser idempotente: segunda execução sem mudança de config não altera nenhum arquivo.

### Key Entities

- **Template de governança**: arquivo `.tmpl` sob `templates/` cujo destino é o mesmo caminho sem o sufixo.
- **Chave do cockpit**: par `CHAVE='valor'` do `cockpit.config` que substitui `{{CHAVE}}`.

## Clarifications

### Session 2026-09-29

- Q: Como o Princípio II trata as trilhas de mudança? → A: Trilhas fixas e genéricas (docs/**, README e imagens = trilha docs; o resto = completa); constituição e reverts nunca em trilha curta.
- Q: O que o Princípio III diz quando desligado? → A: Texto único com o valor configurado: ligado = validação local proibida, só o CI valida; desligado = não se aplica, typecheck/lint/build locais permitidos, o CI segue como gate.
- Q: Como inserir IDENTIDADES? → A: Valor literal sob cabeçalho de tabela Markdown fixa (Quem | user.name <user.email>), assumindo linhas já no formato de tabela.
- Q: Responsabilidades de guardião e triador? → A: Guardião verifica gates e guardas (identidade, base, trilha) antes de cada fase; triador classifica a demanda na trilha e decide se abre frente, sem implementar.
- Q: BOARD vazio? → A: Redação neutra e opcional: "Board de acompanhamento (se houver): {{BOARD}}".

## Assumptions

- Decisão (inferência): a numeração e o conteúdo dos princípios seguem o briefing; como o
  briefing só nomeia a numeração, o conteúdo é derivado do ciclo documentado nas skills:
  II trilhas de mudança, II-bis registro da frente na PR, III validação só no CI (ligado por
  padrão), IV ferramentas externas são dependências, IV-bis identidade de commit declarada,
  V fonte oficial antes de afirmar, VI português do Brasil, VII scripts portáveis e
  idempotentes, VIII parametrização de agentes e prompts fora do rito de código.
- Decisão: sem condicional no motor, o Princípio III traz o valor e as duas consequências
  ("quando ligado… quando desligado…") num texto único.
- Decisão: o Princípio I (agnosticismo) é do cockpit, não do projeto; o template começa em II.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Render com a config de exemplo produz os 9 arquivos com 0 placeholders residuais.
- **SC-002**: 100% dos 9 princípios esperados estão presentes na constituição gerada.
- **SC-003**: O verificador de agnosticismo reporta 0 ocorrências sobre todos os arquivos rastreados.
- **SC-004**: Uma segunda execução do configurador altera 0 arquivos gerados.
- **SC-005**: As 11 fases do rito aparecem no `docs/rito-dev.md` gerado.

## Delta Requirements

**Skip**: feature puramente nova (arquivos novos sob `templates/`), sem alterar comportamento ativo do corpus — paulotodo (agente), 2026-09-29.
