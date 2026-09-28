# UX-OPS Checklist: Esqueleto do cockpit-dev e instalador de máquina

**Purpose**: Validar a qualidade dos requisitos da experiência de linha de comando
do `instalar.sh` — clareza de mensagens, relatório final, idempotência percebida
pelo dev e cobertura dos caminhos de erro operacionais. Domínio customizado
(UX + Ops do instalador), combinando `ux` com foco em CLI não-interativa.
**Created**: 2026-09-25
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md) · [contracts/cli.md](../contracts/cli.md)

## Completude de Requisitos

- [x] CHK001 - O relatório final especifica o status individual de CADA etapa do
      pipeline (FR-009), incluindo o caso `pulada` com o motivo inline, e não só
      um resumo binário ok/falhou? [Completude, Plan §Arquitetura de `instalar.sh`
      — tabela de 7 etapas; Contracts/cli.md §Saída — relatório final] {auto}
- [x] CHK002 - Os três códigos de saída (`0`/`1`/`2`) têm cada um seu significado
      documentado, permitindo ao dev diferenciar "minha máquina não tem as
      ferramentas de base" de "o preparo tentou e falhou"? [Completude,
      Contracts/cli.md §Códigos de saída; Spec §SC-005] {auto}

## Clareza de Requisitos

- [x] CHK003 - O limite entre "mensagem autoral em PT-BR" (FR-012) e "saída
      nativa de ferramenta externa, em qualquer idioma" está definido de forma
      operacional, sem margem para julgamento caso a caso durante a
      implementação? [Clareza, Spec Clarifications Q3] {auto}
- [x] CHK004 - "Avisar" divergência local na idempotência (US1 cenário 6) está
      associado a um texto de status concreto no relatório
      (`atualizada (havia edicao local)`), e não deixado como promessa genérica
      de "avisar"? [Clareza, Research Decision 14 — tabela de ações] {auto}

## Consistência de Requisitos

- [x] CHK005 - A ordem das etapas no relatório final (contracts/cli.md) é
      consistente com a ordem de execução da arquitetura do pipeline (plan.md),
      inclusive a ordem não-negociável `self-update` → checagem de piso
      (Decision 2)? [Consistência, Plan §Arquitetura de `instalar.sh`;
      Contracts/cli.md §Saída] {auto}

## Qualidade de Critérios de Aceite

- [x] CHK006 - SC-005 ("diagnóstico que identifica exatamente qual ferramenta e
      qual versão falta — sem precisar investigar log nenhum") é mensurável por
      um formato de saída fixo (lista completa antes de qualquer instalação,
      código `2`), e não por interpretação subjetiva de "exatamente"?
      [Mensurabilidade, Spec §SC-005; Quickstart Scenario 2] {auto}
- [x] CHK007 - SC-002 ("mesmo relatório de sucesso... sem nenhuma duplicação
      perceptível") tem "duplicação perceptível" concretizado por um critério
      verificável (nenhum registro de marketplace/plugin repetido), em vez de
      ficar subjetivo? [Mensurabilidade, Spec §SC-002; Quickstart Scenario 6,
      passo 3] {auto}

## Cobertura de Cenários

- [x] CHK008 - Existe cenário cobrindo a segunda execução sem nenhuma mudança
      entre as duas (idempotência do caminho feliz)? [Cobertura, Quickstart
      Scenario 6, passos 1-3] {auto}
- [x] CHK009 - Existe cenário cobrindo divergência local detectada (edição manual
      de uma skill já instalada) e o aviso correspondente no relatório?
      [Cobertura, Quickstart Scenario 6, passos 4-5] {auto}

## Cobertura de Edge Cases

- [x] CHK010 - O Edge Case "máquina sem permissão de escrita na área de
      configuração" agora tem Acceptance Scenario (spec.md User Story 1 cenário 8),
      cenário de quickstart (Scenario 12), código de saída dedicado (contracts/cli.md
      exit `3`) e mecanismo de arquitetura (pré-checagem de escrita na etapa 1,
      plan.md §Arquitetura de `instalar.sh`) que sustenta "falhar... sem estado
      parcial" — a checagem roda antes de qualquer escrita real. {auto}
- [x] CHK011 - O Edge Case "plugin necessário ausente mas ferramenta de
      implementação já correta → instala apenas o que falta" agora tem Acceptance
      Scenario (spec.md User Story 1 cenário 9), cenário de quickstart dedicado
      (Scenario 13, distinto do Scenario 7 de falha do plugin recomendado) e
      mecanismo de arquitetura (etapa 7 decide por plugin, plan.md §Arquitetura de
      `instalar.sh`). {auto}

## Requisitos Não-Funcionais

- [x] CHK012 - Nem spec.md nem plan.md especificam se o dev recebe algum sinal de
      progresso durante etapas potencialmente demoradas (download/instalação do
      `cstk`, registro de marketplace, instalação de plugin) ou se fica sem
      feedback algum até o relatório final de sete etapas. Ausência não
      confirmada como decisão deliberada (silêncio-até-o-fim é uma escolha de UX
      válida, mas não está registrada como tal). [Gap, Spec (ausente); Plan
      (ausente)] {humano} — **Resolvido (rodada r02)**: plan.md §Arquitetura de
      `instalar.sh` — "Feedback de progresso (CHK012-ux-ops, block-002 →
      dec-036, respondido pelo owner)" registra a decisão explícita: cada etapa
      imprime uma linha autoral em pt-BR ao iniciar e outra ao concluir, além do
      relatório final consolidado; flag `--quiet`/spinner fica fora de escopo
      (YAGNI). Deixa de ser gap. [Plan §Arquitetura de `instalar.sh`]

## Dependências e Premissas

- [x] CHK013 - A leitura do piso `CSTK_MIN` a partir de `versoes.env` está
      especificada com o mecanismo exato (parse explícito via grep/cut, nunca
      `source`), evitando que uma implementação ingênua transforme um arquivo de
      dados em script executável? [Premissa, Plan §Superfície de Segurança —
      linha "`versoes.env` interpretado como código"] {auto}

## Emenda 1.1.0 (rodada r02) — verificar-e-imprimir, sequencial por gates

- [x] CHK014 - Para cada uma das quatro lacunas que a emenda 1.1.0 converteu de
      "instala" para "verifica e imprime" (etapas 2/`cstk` ausente, 4/piso ou
      release mais nova, 5/catálogo de skills, 7/plugins), existe o comando
      `Execute:` exato documentado — nenhuma etapa fica com instrução genérica
      sem o comando literal a copiar? [Completude, Plan §Arquitetura de
      `instalar.sh` tabela de 7 etapas; Contracts/cli.md §Comandos impressos
      para a pessoa executar] {auto}
- [x] CHK015 - A coluna "Bloqueante?" da tabela de 7 etapas (plan.md) é
      consistente com a enumeração do código de saída `1` em contracts/cli.md
      (mesmos itens: `cstk` ausente, sem resposta de versão, abaixo do piso,
      catálogo ausente, falha na cópia de skills do cockpit, `context-mode`
      ausente/desabilitado — nem mais, nem menos)? [Consistência, Plan
      §Arquitetura de `instalar.sh`; Contracts/cli.md §Códigos de saída] {auto}
- [x] CHK016 - A regra "sequencial por gates — para no primeiro item
      bloqueante; o relatório cobre só os itens avaliados" (FR-009, clarify
      Session 2026-09-28) tem cenário concreto que demonstra a parada, e não
      só a declaração textual do requisito? [Cobertura, Quickstart Scenario 1
      — "o relatório lista só Pré-requisitos de máquina e cstk presente — as
      etapas seguintes não aparecem"; Contracts/cli.md exemplo "Parada por
      gate"] {auto}
- [x] CHK017 - research.md Decision 17 agora cita fonte oficial lida para as
      duas perguntas (rodada r02/FASE 6, tarefa 6.7.2): (1) a sintaxe
      `${{ vars.AGNOSTICO_TERMOS }}` em `env:` é a forma documentada
      (docs.github.com/en/actions/learn-github-actions/variables), sem
      seção específica sobre valor multilinha; (2) PRs de fork: três páginas
      oficiais lidas só documentam a restrição de `secrets`/`GITHUB_TOKEN`,
      nunca de `vars` — permanece lacuna factual, agora **pesquisada e
      citada**, não mais "nenhuma fonte lida". Nenhuma das duas respostas
      diverge do desenho de 6.7.1/plan.md — nenhum ajuste foi necessário.
      [Gap fechado com fonte, Research.md Decision 17] {auto}

## Notes

- Items `{auto}` já vêm resolvidos pelo agente (`[x]` com citação, ou marcador
  `[Gap]`).
- Items `{humano}` ficam `[ ]` aguardando decisão do dono do produto.
- Gate `requirement-coverage.sh` rodado de novo sobre `spec.md` nesta rodada
  (r02, pós-clarify Session 2026-09-28): `requirements=22|covered=22|errors=0`,
  exit 0 — todos os FRs (incluindo o novo FR-022) têm cenário associado.
- CHK017 é a mesma lacuna citada em Research Decision 17 (verificação de
  sintaxe/exposição `vars` do GitHub Actions) — não duplica um `[Gap]` novo,
  só o traz para o checklist para virar tarefa em `/create-tasks`.
