# Feature Specification: Correções do code review retroativo do lote 21-25

**Feature**: `revisao-lote-21-25`
**Created**: 2026-10-08
**Status**: Draft
**Origem**: `bmad-code-review` retroativo sobre `09f7cb0..04c66fd` (PRs #21 a #25, issues #7, #8, #9, #10, #18 e #19). Decisões do owner D1 a D7, fatos medidos, fora de escopo e restrições são normativos e estão em `decisoes-do-owner.md`; esta spec parte deles e não os reabre.

## User Scenarios & Testing

### User Story 1 - Merge vermelho nunca fica sem auditoria por falha na leitura das regras (Priority: P1)

Hoje, quando a consulta das regras da branch base falha, o JSON do erro vira a "lista de checks obrigatórios", o filtro esvazia os checks vermelhos e a auditoria conclui "nada a auditar". O merge vermelho passa sem registro (fail-open). Passa a valer: falha na leitura das regras nunca filtra; a auditoria lista todos os checks vermelhos e avisa que a regra estava ilegível.

**Why this priority**: é o único achado de severidade alta; derrota o propósito do fluxo de auditoria.

**Independent Test**: rodar o cenário 24 de `scripts/testar-configurar.sh` com a rota de regras devolvendo corpo de erro no stdout e código de saída 1.

**Acceptance Scenarios**:

1. **Given** a consulta das regras da branch base sai com código diferente de 0 e escreve um corpo de erro no stdout, **When** o fluxo de auditoria roda sobre um merge com checks vermelhos, **Then** a issue lista todos os checks vermelhos com a nota de regra de checks obrigatórios ilegível.
2. **Given** a consulta das regras sai com 0 e há checks obrigatórios, **When** o fluxo roda, **Then** só os vermelhos obrigatórios são listados (comportamento atual preservado).
3. **Given** o `gh` falso do cenário 24, **When** a chamada de listagem de issues omite `--paginate` ou `state=all`, **Then** o caso falha.

---

### User Story 2 - Aprovação de dono respeita o último estado por usuário e o head atual (Priority: P1)

A PR #25 passou a olhar só as reviews do commit head, e com isso um pedido de mudança enviado depois da aprovação, mas preso a um commit antigo, deixou de anular a aprovação. O fluxo passa a pegar o último estado de cada usuário em todas as reviews, em ordem cronológica, e só conta a aprovação de dono quando esse último estado é aprovado e a review que o deu tem `commit_id` igual ao head atual do PR.

**Why this priority**: regressão de segurança do controle de aprovação introduzida pela #25.

**Independent Test**: cenário 22 com históricos de reviews simulados.

**Acceptance Scenarios**:

1. **Given** um dono que aprovou o head atual e depois enviou um pedido de mudança preso a um commit antigo, **When** o check roda, **Then** a aprovação pendente falha o check.
2. **Given** um dono que aprovou um commit antigo e um não dono que aprovou o head, **When** o check roda, **Then** a aprovação pendente falha o check.
3. **Given** um dono que aprovou o commit antigo e reaprovou o head, **When** o check roda, **Then** a reaprovação no head conta e o check passa.
4. **Given** uma review `DISMISSED`, ou com `commit_id` nulo, **When** o check roda, **Then** ela nunca conta como aprovação.
5. **Given** a leitura do head do PR falha no `gh`, **When** o check roda, **Then** o check falha fechado.

---

### User Story 3 - A skill rito-dev lê o `cockpit.config` com aspas e confere o repositório remoto (Priority: P2)

A skill manda conferir os valores antes de tirar as aspas simples, e seguida à letra recusa todo `cockpit.config` válido. Passa a tirar o par de aspas antes de conferir, e a conferir também `REPO_REMOTO` com a regra do `configurar.sh` (`^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$`, sem `.` ou `..` como parte), antes de compor qualquer comando.

**Why this priority**: sem a ordem certa a skill é inutilizável; sem a conferência de `REPO_REMOTO` um valor hostil entra em comando.

**Independent Test**: leitura da skill com um `cockpit.config` de exemplo com valores entre aspas, válido e inválido.

**Acceptance Scenarios**:

1. **Given** `BRANCH_INTEGRACAO='main'` entre aspas simples, **When** a skill segue o passo de leitura, **Then** as aspas são removidas antes da conferência e o valor `main` é aceito.
2. **Given** um `REPO_REMOTO` fora da regra, **When** a skill confere os valores, **Then** ela PARA e nomeia a chave `REPO_REMOTO` sem colar o valor num comando para testá-lo.

---

### User Story 4 - A parallel-work confere as branches antes do `--base` (Priority: P2)

A cópia versionada de `skills/parallel-work/SKILL.md` aplica a `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` a regra da #19 (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`), depois de tirar as aspas e antes de compor o `--base`. Fora da regra, PARA e nomeia a chave.

**Why this priority**: fecha a mesma classe de risco da US3 na outra skill.

**Independent Test**: leitura da skill com valores válidos e inválidos.

**Acceptance Scenarios**:

1. **Given** `BRANCH_INTEGRACAO` com valor fora da regra, **When** a skill confere antes do `--base`, **Then** ela PARA e nomeia a chave.
2. **Given** `BRANCH_PRODUCAO` com valor válido entre aspas, **When** a skill confere, **Then** as aspas saem antes e o `--base` é composto.

---

### User Story 5 - Mensagens e comentários dizem a verdade (Priority: P3)

Ajustes de texto: o `configurar.sh --atualizar` com `BRANCH_*` fora da regra continua falhando fechado e passa a dizer que, se o valor é o nome real da branch, a saída é renomear a branch no remoto. Os modelos de `require-codeowner-approval` e `CODEOWNERS` dizem que a opção nativa de descartar aprovações antigas só descarta quando entra commit que altera o diff do PR (research F3) e que o check do fluxo é mais estrito. O comentário `ponytail:` do modelo `audit-merge-vermelho` segue a Decision 3 da research (`since` ou `creator`; mudar o filtro exige nova decisão do owner). O contrato `contracts/github-rest.md` cita o filtro `has("pull_request") | not`. A research de `promotion-pr-arvores` e `audit-merge-vermelho` registra os fatos medidos no lugar das afirmações sem fonte.

**Why this priority**: corrige texto enganoso sem mudar comportamento.

**Independent Test**: leitura dos arquivos alterados e o caso 6 do cenário 23.

**Acceptance Scenarios**:

1. **Given** `--atualizar` com `BRANCH_*` fora da regra, **When** o script recusa, **Then** a mensagem cita também a saída de renomear a branch no remoto.
2. **Given** os modelos `require-codeowner-approval` e `CODEOWNERS`, **When** o operador os lê, **Then** o texto sobre a opção nativa descreve o descarte por commit que altera o diff e a maior exigência do check.
3. **Given** a research das frentes `promotion-pr-arvores` e `audit-merge-vermelho`, **When** o revisor a lê, **Then** ela registra os fatos medidos, e a Decision 1 de `audit-merge-vermelho` não afirma mais que a falha cai no aviso de regra ilegível.
4. **Given** qualquer script alterado, **When** shellcheck e actionlint rodam, **Then** não há findings, e o texto alterado está em português do Brasil com acentuação, sem nomear projeto real.

---

### User Story 6 - Os testes cobrem os achados (Priority: P2)

Nos cenários existentes de `scripts/testar-configurar.sh`, sem número novo: o 24 e o 22 conforme US1 e US2; o 21 com valores que a regex aceita e o git recusa (`a..b`, `x.lock`, `a/`), primeiro caractere `-x`, `.x`, `/x` e não ASCII, a mensagem de erro no tty, manifesto anterior que ficaria vazio, nenhum arquivo gravado no caso 1 e a mensagem para todos os valores recusados no 3b; o 23 com o caso 6 conferindo as duas afirmações de D2 da frente `promotion-pr-arvores` no cabeçalho.

**Why this priority**: sem teste a correção regride em silêncio.

**Independent Test**: executar `scripts/testar-configurar.sh` e ver todos os cenários 21 a 24 verdes.

**Acceptance Scenarios**:

1. **Given** o `configurar.sh` e valores `a..b`, `x.lock`, `a/`, `-x`, `.x`, `/x` e `á`, **When** os cenários rodam, **Then** todos são recusados com a mensagem de erro.
2. **Given** um manifesto anterior que ficaria vazio, **When** o `configurar.sh` roda, **Then** vale a regra mantida pelo owner na frente `configurar-endurecimento` (D3): o manifesto continua existindo e é regravado sem linhas; e no caso 1 nenhum `cockpit.config`, modelo, manifesto ou hook é gravado.

---

### Edge Cases

- A rota de regras responde 404 com corpo JSON no stdout e código 1: tratada como regra ilegível, nunca como lista.
- Reviews de um mesmo usuário com estados mistos (aprovado, pedido de mudança, `DISMISSED`) em commits diferentes: vale o último estado em ordem cronológica.
- `cockpit.config` com aspas simples em torno do valor, ou sem aspas.
- Branch com `/` no nome: a leitura de regras com nome cru não está medida; fica fora desta frente.

## Requirements

### Functional Requirements

- **FR-001**: O fluxo `audit-merge-vermelho` MUST descartar a saída da consulta das regras da branch base quando ela sai com código diferente de 0, e seguir como regra de checks obrigatórios ilegível listando todos os checks vermelhos com a nota correspondente (D1).
- **FR-002**: O fluxo `require-codeowner-approval` MUST pegar o último estado de cada usuário em todas as reviews em ordem cronológica e contar aprovação de dono só quando esse estado é aprovado e o `commit_id` da review é o head atual do PR (D2).
- **FR-003**: A skill `rito-dev` MUST remover o par de aspas simples envolvente de cada valor do `cockpit.config` antes de conferir os valores (D3).
- **FR-004**: A skill `rito-dev` MUST conferir `REPO_REMOTO` com a regra `RE_REPO` do `configurar.sh`, depois de tirar as aspas e antes de compor comando, e PARAR nomeando a chave, sem colar o valor num comando, quando fora da regra (D4).
- **FR-005**: A skill `parallel-work` versionada MUST aplicar a `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` a regra `^[A-Za-z0-9][A-Za-z0-9._/-]*$`, depois de tirar as aspas e antes de compor o `--base`, e PARAR nomeando a chave quando fora da regra (D5).
- **FR-006**: O `configurar.sh --atualizar` com `BRANCH_*` fora da regra MUST continuar falhando fechado e a mensagem MUST também orientar a renomear a branch no remoto quando o valor é o nome real (D6).
- **FR-007**: Os modelos `require-codeowner-approval.yml.tmpl` e `CODEOWNERS.tmpl` MUST descrever a opção nativa de descartar aprovações como ativa só quando entra commit que altera o diff do PR e dizer que o check do fluxo é mais estrito (D6).
- **FR-008**: O comentário `ponytail:` de `audit-merge-vermelho.yml.tmpl` MUST seguir a Decision 3 da research, e `contracts/github-rest.md` da frente MUST citar o filtro `has("pull_request") | not` (D6).
- **FR-009**: A research das frentes `promotion-pr-arvores` e `audit-merge-vermelho` MUST registrar os fatos medidos de `decisoes-do-owner.md` no lugar das afirmações sem fonte, corrigindo a afirmação da Decision 1 de `audit-merge-vermelho` (D1, D6).
- **FR-010**: Os cenários 21, 22, 23 e 24 de `scripts/testar-configurar.sh` MUST cobrir os casos listados em D7, sem criar número novo de cenário.
- **FR-011**: Todo script alterado MUST usar `set -euo pipefail` e `LC_ALL=C`, passar em shellcheck e actionlint sem findings e não acrescentar dependência; a prosa MUST estar em português do Brasil com acentuação e sem nomear projeto real.

### Key Entities

- **Review de PR**: autor, estado (aprovado, pedido de mudança, `DISMISSED`), `commit_id` e ordem cronológica.
- **Regra de checks obrigatórios**: lista lida da branch base; pode estar ilegível.
- **Valor do `cockpit.config`**: chave com valor entre aspas simples, validado por regra por chave.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Em 100% dos casos de falha na leitura das regras, a auditoria lista todos os checks vermelhos; zero merges vermelhos saem com "nada a auditar" por falha de leitura.
- **SC-002**: Os cenários 21, 22, 23 e 24 de `scripts/testar-configurar.sh` passam, e cada caso novo de D7 falha se a correção correspondente for revertida.
- **SC-003**: Um `cockpit.config` válido com valores entre aspas simples é aceito pelas duas skills; 100% dos valores de `REPO_REMOTO` e `BRANCH_*` fora da regra param a skill nomeando a chave.
- **SC-004**: shellcheck e actionlint terminam com zero findings na PR.

## Delta Requirements

**Skip**: correção de defeitos e de texto em artefatos de um repositório de modelos, sem comportamento ativo catalogado em `docs/specs/current/` — Paulo Todo, 2026-10-08
