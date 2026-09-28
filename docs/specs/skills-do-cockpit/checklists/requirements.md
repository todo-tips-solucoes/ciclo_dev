# Requirements Checklist: Skills do cockpit + alinhamento do briefing

**Purpose**: Quality gate de requisitos ("unit tests for English") sobre `spec.md`
(4 user stories, FR-001..FR-014) e `plan.md` (Constitution Check, tabela das 11
fases, data-model.md, research.md) — gerado de forma autônoma pelo
`agente-00c-feature-orchestrator` na fase `checklist`, sem interação humana na
Etapa 2 (defaults: profundidade Standard, audiência Reviewer, foco nos clusters
de maior risco: agnosticismo/Princípio I e cobertura das 11 fases).
**Created**: 2026-09-28
**Feature**: [spec.md](../spec.md) | [plan.md](../plan.md)

## Completude de Requisitos

- [x] CHK001 - Os requisitos de US1 (skill `rito-dev` lê parâmetros em runtime) especificam a fonte (arquivo de config) e o conjunto mínimo de chaves? [Completude, Spec §US1/FR-004/FR-005] {auto}
- [x] CHK002 - Os requisitos de US2 (worktree isolada sem hardcode) especificam a ausência de literal de projeto/org na skill? [Completude, Spec §US2/FR-002] {auto}
- [x] CHK003 - Os requisitos de US3 (revisão adversarial + proveniência) cobrem tanto o comportamento (FR-007) quanto o registro de licença (FR-008)? [Completude, Spec §US3/FR-007/FR-008] {auto}
- [x] CHK004 - Os requisitos de US4 (briefing + histórico sem divergência) cobrem os dois pontos citados no Why-this-priority (briefing desatualizado E exceção da PR #1 sem registro)? [Completude, Spec §US4/FR-012/FR-013] {auto}
- [x] CHK005 - Todas as 11 fases do rito (mais a etapa 0 preparatória) têm requisito de origem e parametrização mapeados? [Completude, Plan §Design das 11 fases] {auto}
- [x] CHK006 - O conjunto mínimo de chaves de `cockpit.config` (FR-005) está fechado numa tabela sem ambiguidade de tipo/obrigatoriedade, pronta para `/create-tasks` decompor sem nova pergunta ao dev? [Completude, Spec FR-005 + data-model.md §Entity] {auto}

## Clareza e Mensurabilidade

- [x] CHK007 - Os 5 Success Criteria (SC-001..SC-005) são verificáveis objetivamente (sim/não), sem adjetivo vago? [Mensurabilidade, Spec §Success Criteria] {auto}
- [x] CHK008 - "sem mudança de comportamento" (FR-007, cópia de `bmad-code-review`) tem critério de verificação objetivo (diff contra a fonte), em vez de depender de julgamento subjetivo de equivalência? [Clareza, Spec FR-007 + research.md Decision 7] {auto}
- [ ] CHK009 - "reproduzido na íntegra" (FR-008, licença) já foi confirmado com reverificação contra a fonte oficial nesta mesma execução (não copiado de memória), e essa confirmação continua válida no momento em que `THIRD-PARTY-NOTICES.md` for de fato escrito em `/execute-task`? [Mensurabilidade, Spec FR-008 + research.md Decision 8, Assumption] {auto}

## Consistência de Requisitos

- [x] CHK010 - FR-005 (chaves mínimas) e a tabela de `cockpit.config` em `data-model.md` citam exatamente o mesmo conjunto de chaves, sem chave a mais ou a menos? [Consistência, Spec FR-005 vs data-model.md §Entity] {auto}
- [x] CHK011 - O tratamento de "branch de integração == branch de produção" é consistente entre `data-model.md` (constraint da chave `BRANCH_PRODUCAO`) e a tabela de fases do `plan.md` (Fase 9, no-op explícito)? [Consistência, data-model.md + Plan §Design das 11 fases linha 9] {auto}
- [x] CHK012 - **[Ambiguity/Conflict] RESOLVIDO (dec-029/block-002)** - O Constitution Check do `plan.md` marcava "I. Agnosticismo Verificável = PASS" citando, na MESMA célula da tabela, literais reais do projeto de origem do rito (organização/repositório, handle de reviewer, URL de ambiente de staging, identificador de projeto de infraestrutura — plan.md linha 46 então) e repetia esses mesmos literais/nomes de workflow reais na tabela de fases (plan.md linhas 124/128/131-133 então). A constitution deste repositório (Princípio I, NON-NEGOTIABLE) exige que "todo arquivo do repositório" passe pelo verificador de agnosticismo e que exemplos/placeholders usem "nomes fictícios genéricos... nunca nomes de projetos reais — **inclusive dos projetos onde o ciclo nasceu**" (`docs/constitution.md` linhas 36-45), sem exceção textual para artefatos SDD (spec/plan/research). **Decisão do owner (opção a)**: generalizar todos os literais do projeto de origem em `plan.md`/`research.md`/demais artefatos versionados para texto genérico, sem emenda à constitution. **Evidência da correção**: grep, sobre `plan.md`/`research.md`, pelos 4
literais reais (org/repo, handle de reviewer, URL de staging, identificador
de projeto de infraestrutura) + 2 nomes/números de workflow reais citados em
dec-029 (nunca reproduzidos neste arquivo, para não reintroduzir a mesma
violação) → 0 ocorrências (rodado nesta onda, pós-edição). `AGNOSTICO_TERMOS` (populada localmente/CI, fora do repo, com os literais reais) para o gate `verificar-agnostico.sh` afirmar isto de fato sobre os artefatos SDD vira tarefa dedicada em `/create-tasks` (plan.md §Próximos Passos item 2). [Conflict resolvido, Constitution §Princípio I vs Plan — literais generalizados] {humano}

## Cobertura de Cenários e Edge Cases

- [x] CHK013 - Gate determinístico de cobertura de cenário por FR (`requirement-coverage.sh`) rodou sobre `spec.md` com resultado limpo? [Cobertura] {auto} — `RESULT|docs/specs/skills-do-cockpit/spec.md|requirements=14|covered=14|errors=0` (rodado nesta onda).
- [x] CHK014 - **RESOLVIDO (tasks.md FASE 7 tarefa 7.1)** - O Edge Case "chave obrigatória faltando no `cockpit.config`" (spec.md §Edge Cases) tem um Acceptance Scenario numerado próprio, ou só o comportamento esperado em prosa? Acrescentado o Acceptance Scenario 4 em `spec.md` §US1: "Given um `cockpit.config` ausente no projeto-alvo, ou presente mas faltando uma das chaves obrigatórias definidas em FR-005, When um dev invoca a skill do rito nesse projeto, Then a skill interrompe antes de executar qualquer fase e informa explicitamente qual chave falta (ou que o arquivo está ausente), sem seguir adiante com um valor presumido ou de outro projeto." Gate `requirement-coverage.sh` reconfirma zero gaps pós-edição (ver CHK013). [Gap resolvido, Spec §US1 Acceptance Scenario 4] {auto}
- [x] CHK015 - O Edge Case "skill de revisão adversarial atualizada na origem depois desta cópia" está explicitamente marcado como fora do escopo desta frente, sem deixar expectativa implícita de atualização automática? [Cobertura, Spec §Edge Cases + Constitution Princípio IV] {auto}
- [x] CHK016 - O Edge Case "alguém preenche o exemplo versionado com valor de projeto real" está coberto pelo requisito de que `cockpit.config.example` use só valores fictícios (FR-006)? [Cobertura, Spec §Edge Cases + FR-006] {auto}

## Requisitos Não-Funcionais (Agnosticismo / Verificabilidade)

- [x] CHK017 - FR-009/FR-010 (nenhum literal real; checagem de agnosticismo) têm mecanismo de verificação determinístico (script de CI), não apenas alegação textual? [NFR, Spec FR-009/FR-010] {auto}
- [x] CHK018 - **[Gap/Ambiguity] RESOLVIDO (dec-029/block-002 — mesma decisão do CHK012)** - O escopo de FR-009 ("Nenhum arquivo entregue por esta feature (as três skills, o exemplo de configuração, o registro de dependências de terceiros)...") é mais estreito que o MUST do Princípio I da constitution ("Todo arquivo do repositório MUST passar por `scripts/verificar-agnostico.sh`... zero ocorrências", sem recorte por tipo de artefato). O owner optou por generalizar (opção a) em vez de emendar a constitution — logo os artefatos SDD desta feature (`spec.md`, `plan.md`, `research.md`, `data-model.md`, `checklists/`) ficam DENTRO da mesma garantia de agnosticismo que FR-009/FR-010/SC-002 prometem para `skills/`, sem precisar de emenda de escopo em FR-009 (a garantia de fato já é mais ampla que a redação literal do FR; não há conflito a resolver na spec, só a correção de conteúdo já aplicada — ver CHK012). [Ambiguity resolvida, Spec FR-009 + Constitution §Princípio I] {humano}
- [x] CHK019 - A identidade de revisor/aprovador (Decision 4, fora do `cockpit.config`) está documentada como pergunta genérica em runtime, sem persistir estado nem virar literal na skill? [NFR, Plan §Re-check linha 151-152] {auto}

## Dependências e Premissas

- [x] CHK020 - O mapeamento fino de chaves adicionais de `cockpit.config` por fase, deferido pelo clarify para o `/plan` (spec.md Clarification Q3), foi de fato fechado em `plan.md`/`data-model.md` sem chave pendente? [Dependência, Spec §Clarifications Q3 + Plan §Re-check + Plan §Artefatos "NEEDS CLARIFICATION restantes: 0"] {auto}
- [x] CHK021 - A tabela de 11 fases do `plan.md` é suficiente, por si só, como base de decomposição do `/create-tasks` (conforme os "Próximos Passos" do próprio plan.md), sem exigir nova leitura linha-a-linha de `research.md` para cada fase? [Dependência, Plan §Design das 11 fases + §Próximos Passos] {auto}
- [x] CHK022 - A premissa "nenhuma dependência nova" (Technical Context: reusa formato `CHAVE=valor` de `versoes.env`) está registrada com a decisão que a sustenta (não é suposição solta)? [Premissa, Plan §Technical Context + research.md Decision 2] {auto}

## Notes

- Items `{auto}` já vêm resolvidos pelo agente (`[x]` com citação, ou `[ ]` com
  marcador `[Gap]`/`[Ambiguity]`/`[Conflict]` quando a evidência mostra que o
  requisito não está satisfeito).
- Items `{humano}` — CHK012 e CHK018 resolveram-se com a MESMA decisão do
  owner (block-002/dec-028, resposta em dec-029: opção a — generalizar) —
  ver evidência em cada item acima.
- Gate `requirement-coverage.sh` (CHK013): `errors=0`, os 14 FRs têm cenário
  associado — nenhum `[Gap]` adicional gerado por essa via.

### Resolução

- **{auto} resolvidos**: 19 (`[x]` com evidência citada, incluindo CHK014 — ver evidência no item)
- **{humano} resolvidos**: 2 (CHK012, CHK018 — mesma decisão de fundo, dec-029/block-002, opção a)
- **Gaps abertos** (`[Gap]`/`[Ambiguity]`/`[Conflict]`): nenhum — CHK014 resolvido nesta onda (Acceptance Scenario 4 de spec.md §US1); CHK012/CHK018 resolvidos. CHK009 permanece `[ ]` (não é `[Gap]`/`[Ambiguity]`/`[Conflict]` — é uma reverificação a confirmar no momento de `/execute-task` escrever `THIRD-PARTY-NOTICES.md`, fora do escopo desta tarefa)

### Próximos Passos

- CHK012/CHK018: resolvidos (dec-029/block-002, opção a) — literais do
  projeto de origem generalizados em `plan.md`/`research.md`; tarefa de
  popular `AGNOSTICO_TERMOS` + rodar `verificar-agnostico.sh` sobre os
  artefatos SDD entra em `/create-tasks` (plan.md §Próximos Passos item 2).
- CHK014: resolvido (tasks.md FASE 7 tarefa 7.1) — Acceptance Scenario 4
  acrescentado a spec.md §US1 para o Edge Case de chave faltando.
- `/create-tasks` — demais `[Gap]` (nenhum crítico) viram tarefa de requisito
  quando fizer sentido; a tabela de 11 fases do plan.md segue como base
  principal da decomposição.
