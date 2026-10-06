# Feature Specification: Aprovação de dono sobre o commit atual

**Feature**: `codeowner-aprovacao-atual`
**Created**: 2026-10-06
**Status**: Draft
**Origem**: issue #9; decisões do owner normativas em `decisoes-do-owner.md` (D1, D2, fora de escopo, restrições).

## User Scenarios & Testing

### User Story 1 - Aprovação antiga deixa de valer após novo push (Priority: P1)

Hoje o check `require-codeowner-approval` aprova o PR quando algum dono terminou em "aprovado", sem
olhar em que versão do PR a aprovação foi dada. Quem faz push de código novo depois da aprovação
continua com o check verde. O check passa a contar somente aprovação de dono feita sobre o commit
atual (head) do PR.

**Why this priority**: fecha a brecha que a issue #9 descreve; é o valor central da frente.

**Independent Test**: executar o passo do fluxo com um histórico de reviews simulado e verificar o
veredito para cada combinação de commit e estado.

**Acceptance Scenarios**:

1. **Given** um dono cuja última review é uma aprovação sobre o commit head atual, **When** o check
   roda, **Then** o resultado é "aprovado por um dono" (sucesso).
2. **Given** um dono cuja única aprovação foi dada sobre um commit anterior ao head atual, **When**
   o check roda, **Then** o resultado é aprovação pendente (falha), listando quem pode aprovar.
3. **Given** um dono que aprovou no commit head atual e depois pediu mudanças no mesmo commit,
   **When** o check roda, **Then** o resultado é aprovação pendente (vale o último estado do
   usuário sobre o head).
4. **Given** um dono que aprovou o commit antigo e um não-dono que aprovou o head atual, **When** o
   check roda, **Then** o resultado é aprovação pendente (aprovação de não-dono nunca conta).

---

### User Story 2 - Operador sabe da opção nativa de descartar aprovações antigas (Priority: P2)

Quem configura a proteção da branch precisa saber que a regra nativa tem uma opção que descarta
aprovações antigas quando há commit novo. Os comentários de cabeçalho do fluxo e do modelo de
CODEOWNERS citam essa opção ao lado de "Require review from Code Owners", com o nome exato
conforme a documentação oficial do GitHub.

**Why this priority**: a garantia real continua sendo a regra nativa da branch; documentar a opção
orienta o operador a ativá-la, mas não altera o comportamento do check.

**Independent Test**: ler os dois arquivos renderizados e conferir a menção e o link/fonte da
opção.

**Acceptance Scenarios**:

1. **Given** o fluxo renderizado, **When** o operador lê o cabeçalho, **Then** encontra a opção
   nativa de descartar aprovações antigas citada junto da exigência de revisão de donos.
2. **Given** o CODEOWNERS renderizado, **When** o operador lê os comentários, **Then** encontra a
   mesma citação, com o mesmo nome da opção.

---

### User Story 3 - Regressão coberta por teste automatizado (Priority: P3)

O comportamento da User Story 1 fica protegido por um cenário de teste que roda no CI junto dos
demais, sem rede nem credenciais.

**Why this priority**: sem teste, a correção volta a quebrar sem aviso.

**Independent Test**: executar o script de testes e ver o cenário novo passar; reverter a correção e
ver o cenário falhar.

**Acceptance Scenarios**:

1. **Given** o cenário de teste novo, **When** o script de testes roda, **Then** os três casos
   (aprovação no head conta; aprovação em commit anterior não conta; aprovação seguida de pedido de
   mudança no head não conta) passam.
2. **Given** o fluxo sem a correção, **When** o script de testes roda, **Then** ao menos um dos
   casos falha.

---

### Edge Cases

- Dono aprovou o commit antigo e depois reaprovou o head atual: conta (último estado sobre o head).
- Review sem `commit_id` utilizável ou lista de reviews vazia: não conta como aprovação; o resultado
  é pendente, nunca sucesso por omissão.
- Push novo sem nenhuma review depois dele: check falha até haver review nova de dono.
- Review "comentada" ou pendente continua não alterando o estado do usuário (comportamento atual).
- Maiúsculas/minúsculas em logins continuam tratadas sem distinção (comportamento atual).
- Review descartada (dismissed) sobre o head não é aprovação.

## Requirements

### Functional Requirements

- **FR-001**: O check MUST considerar apenas reviews feitas sobre o commit head atual do PR ao
  decidir se há aprovação de dono.
- **FR-002**: Entre as reviews sobre o head atual, o check MUST usar o último estado de cada
  usuário (regra atual preservada) e tratar como aprovado somente quem terminou em aprovação.
- **FR-003**: Aprovação feita sobre commit anterior ao head atual MUST NOT contar, mesmo que seja o
  último estado do usuário.
- **FR-004**: Um push novo depois de uma aprovação MUST deixar o check sem aprovação de dono até
  haver review nova de dono sobre o novo head.
- **FR-005**: O fluxo MUST obter o commit head atual do PR de fonte rastreável (a ser confirmada no
  plano), com o mínimo de alteração de permissões, e MUST falhar (não aprovar) se não o obtiver.
- **FR-006**: O comportamento de aprovação de não-dono, mensagens de erro existentes e códigos de
  saída para CODEOWNERS ausente ou sem donos MUST permanecer inalterados.
- **FR-007**: Os comentários de cabeçalho do fluxo e do modelo de CODEOWNERS MUST citar, ao lado de
  "Require review from Code Owners", a opção nativa da regra da branch que descarta aprovações
  antigas quando há commit novo, com o nome exato extraído da documentação oficial do GitHub (link
  registrado na pesquisa do plano).
- **FR-008**: O texto do fluxo MUST seguir dizendo que o check é verificação extra e que a garantia
  é a regra nativa da branch (dec-025 da frente `templates-automacao` preservada).
- **FR-009**: O script `scripts/testar-configurar.sh` MUST ganhar o cenário 22 (número reservado),
  posicionado antes do cenário 11, no padrão do cenário 16: o passo do fluxo é extraído do YAML
  renderizado e executado com `gh` falso, cobrindo os três casos da User Story 3.
- **FR-010**: O fluxo e os testes MUST permanecer em bash sem dependência nova, sem findings de
  actionlint e shellcheck, e sem nomear projeto real; prosa em português do Brasil com acentuação.

### Fora de escopo

- Tornar o fluxo a garantia de aprovação (continua verificação extra).
- Mudar gatilhos (`on:`) ou permissões além do necessário para ler o head do PR.

> Decisões de infraestrutura: N/A (fluxo sem estado, sem agendamento, chaves ou refresh).

## Success Criteria

- **SC-001**: Em 100% dos casos simulados do cenário 22, o veredito do check coincide com o esperado
  (head aprovado passa; commit anterior e pedido de mudança no head falham).
- **SC-002**: Após um push novo, nenhuma aprovação anterior ao push mantém o check verde.
- **SC-003**: Um operador encontra a opção nativa de descartar aprovações antigas lendo apenas o
  cabeçalho do fluxo ou do CODEOWNERS renderizados.
- **SC-004**: O CI existente (testes, actionlint, shellcheck, gate agnóstico) continua verde.

## Delta Requirements

**Skip**: feature restrita a templates e testes do próprio cockpit, sem comportamento ativo em `docs/specs/current/` — Claude (feature-00c), 2026-10-06

## Clarifications

### Session 2026-10-06

Rodada inline (mediação sem spawn): a leitura estruturada da spec contra `decisoes-do-owner.md`,
briefing e constitution não deixou ambiguidade que mude escopo, testes ou modelo de dados. Pontos
verificados e resolvidos:

- Review descartada (dismissed): o estado `DISMISSED` substitui o anterior do usuário e não é
  aprovação; já coberto pelas Edge Cases e por FR-002. Sem mudança.
- Review sem `commit_id` utilizável: não conta (Edge Cases, FR-001). Sem mudança.
- Nome exato da opção nativa e fonte do head do PR: pesquisa do plan (Princípio VI), não pergunta
  de clarify (decisoes-do-owner.md, D2 e fora de escopo).
- Gatilhos, permissões e papel de verificação extra do fluxo: fora de escopo, normativos em
  `decisoes-do-owner.md`.

Nenhuma pergunta pendente; nenhum bloqueio humano.
