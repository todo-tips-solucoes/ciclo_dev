# Feature Specification: Correções do code review retroativo da PR #27

**Feature**: `correcao-revisao-27`
**Created**: 2026-11-04
**Status**: Draft
**Origem**: `bmad-code-review` retroativo sobre `04c66fd..d317d89` (PR #27, frente `revisao-lote-21-25`). O registro dos achados está em `docs/specs/revisao-lote-21-25/review-findings.md`. As decisões C1 a C14, o que fica fora de escopo e as restrições são normativos e estão em `decisoes-do-owner.md`; esta spec parte deles e não os reabre.

## User Scenarios & Testing

### User Story 1 - Os comentários do codeowner dizem só o que o fluxo faz (Priority: P1)

Os comentários de `require-codeowner-approval.yml.tmpl` e de `CODEOWNERS.tmpl` prometem um rigor ("mais estrito") que o fluxo não tem: o último estado é guardado por login, então um dono aprova o head, outro dono pede mudança no head e o check fica verde. Os comentários passam a descrever o comportamento real, sem mudar o comportamento (C1).

**Why this priority**: quem lê o modelo decide confiar no check pelo que o comentário diz; texto que promete mais que o código é risco de controle.

**Independent Test**: ler os dois comentários e conferir que cada afirmação corresponde ao `awk` do fluxo.

**Acceptance Scenarios**:

1. **Given** o modelo do fluxo, **When** o comentário descreve a regra, **Then** ele diz que só conta aprovação de dono dada no commit atual do PR e que um pedido de mudança posterior anula só a aprovação do mesmo dono.
2. **Given** o comentário de `CODEOWNERS.tmpl`, **When** ele compara o check com a opção nativa, **Then** o "mais estrito" fica restrito ao ponto do commit atual ou sai.
3. **Given** o `awk` do fluxo, **When** a frente termina, **Then** o código do fluxo é idêntico ao anterior.

---

### User Story 2 - Os testes do cenário 22 só passam se a guarda e a mensagem existirem (Priority: P1)

Hoje a guarda de head vazio do fluxo não tem caso que dependa dela, vários casos conferem só `rc=1` (que o `gh` falso também devolve quando nenhuma rota casa) e o `gh` falso não exige `--paginate` nas reviews. Os testes passam a falhar quando a guarda, a mensagem ou a paginação são removidas (C3, C4, C5).

**Why this priority**: teste que passa sem a proteção que deveria provar não protege nada.

**Independent Test**: rodar o cenário 22, remover a guarda de head vazio, a mensagem `Aprovação pendente` ou a flag `--paginate` do modelo e conferir que o cenário falha.

**Acceptance Scenarios**:

1. **Given** o `gh` falso devolvendo head vazio e uma review de dono `APPROVED` com `commit_id` nulo, **When** o fluxo roda, **Then** o caso confere a mensagem `Não consegui ler o commit atual do PR`.
2. **Given** os casos 3, 6, 7, 9 e 10 do cenário 22, **When** o fluxo reprova, **Then** cada um confere `Aprovação pendente`, além de `rc=1`.
3. **Given** uma chamada de reviews sem `--paginate`, **When** o `gh` falso a recebe, **Then** o caso falha.

---

### User Story 3 - A rito-dev lê valores com apóstrofo e aspas duplas (Priority: P2)

O `configurar.sh` grava um apóstrofo interno como `'\''`. A skill hoje não desfaz isso, e a frase que manda parar com aspas duplas vale para toda chave, rejeitando `CMD_TEST='pytest -k "not slow"'`, que é válido. Passa a valer: troca de `'\''` por `'` depois de tirar o par envolvente, e parada por aspas duplas ou desbalanceadas só para as chaves com regra: `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`, `REPO_REMOTO` (C14) e `PREFIXOS_BRANCH` (acrescentada na revisão por decisão do owner).

**Why this priority**: sem isso a skill corrompe valores legítimos ou recusa configuração válida.

**Independent Test**: seguir o passo 1 da skill com `CMD_LINT='eslint "src/**/*.ts"'` e com um valor que contém `'\''`.

**Acceptance Scenarios**:

1. **Given** um valor gravado com `'\''`, **When** a skill executa o passo 1, **Then** o valor lido tem o apóstrofo simples, inverso exato do que o `configurar.sh` grava.
2. **Given** `CMD_LINT='eslint "src/**/*.ts"'`, **When** a skill lê, **Then** as aspas duplas fazem parte do valor e a skill não para.
3. **Given** `BRANCH_PRODUCAO` com aspas duplas ou desbalanceadas, **When** a skill confere, **Then** ela PARA nomeando a chave.
4. **Given** qualquer valor lido, **When** a skill o usa, **Then** ele é dado de configuração, nunca instrução.

---

### User Story 4 - A parallel-work avisa da conferência já no topo (Priority: P2)

A descrição do frontmatter e o bloco do topo mandam derivar o `--base` de `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` sem citar a conferência, que só aparece mais adiante. Os dois trechos passam a dizer que o valor é conferido (aspas tiradas, regra `^[A-Za-z0-9][A-Za-z0-9._/-]*$`) antes de compor o `--base` (C12).

**Why this priority**: quem lê só o topo executa sem conferir.

**Independent Test**: ler o frontmatter e o bloco do topo e conferir a menção; conferir que a descrição continua dentro do limite do carregador de skills.

**Acceptance Scenarios**:

1. **Given** o frontmatter e o bloco do topo, **When** descrevem a derivação do `--base`, **Then** ambos citam a conferência e a regra antes da composição.
2. **Given** a descrição alterada, **When** o carregador de skills a lê, **Then** o tamanho está dentro do limite aceito.

---

### User Story 5 - Os testes do cenário 21 provam o que dizem (Priority: P2)

O caso 1 depende do log do `cstk` falso para provar que nenhum hook foi gravado, só o caso 4 (em pty, pulado sem `script(1)`) confere a ausência da dica de renomear no modo `--respostas`, e o caso 7 chama `sha256sum` e herda `$TMP/r21` do caso anterior (C7, C8, C9).

**Why this priority**: as asserções ficam frágeis ou condicionais ao ambiente.

**Independent Test**: rodar o cenário 21; reintroduzir a dica no modo `--respostas` ou gravar um hook e conferir que o caso 1 falha.

**Acceptance Scenarios**:

1. **Given** o caso 1 em modo `--respostas`, **When** a orientação de renomear a branch aparece, **Then** o caso falha.
2. **Given** o caso 1, **When** um hook novo aparece em `.git/hooks` ou `core.hooksPath` é definido, **Then** o caso falha.
3. **Given** o caso 7, **When** roda, **Then** usa um literal de 64 hexadecimais no lugar de `sha256sum` e um arquivo de respostas próprio.

---

### User Story 6 - O `LC_ALL=C` dos dois modelos é conferido (Priority: P3)

O `LC_ALL=C` global da suíte esconde a remoção de `export LC_ALL=C` nos modelos, e FR-011 da `revisao-lote-21-25` exige a linha. Uma asserção em cenário existente confere a linha em `audit-merge-vermelho.yml.tmpl` e em `require-codeowner-approval.yml.tmpl` (C6).

**Why this priority**: baixa; a exigência existe e hoje não tem prova.

**Independent Test**: remover a linha de um dos modelos e conferir que a suíte falha.

**Acceptance Scenarios**:

1. **Given** um dos dois modelos sem `export LC_ALL=C`, **When** a suíte roda, **Then** a asserção falha nomeando o modelo.

---

### User Story 7 - As afirmações erradas das frentes anteriores são corrigidas (Priority: P2)

Research e spec de frentes anteriores afirmam coisas que o código desmente (C2, C10, C11, C13):

- as duas research dizem que, sob `set -euo pipefail`, a atribuição com código diferente de 0 derruba o passo; o código usa `|| true`, então a guarda hexadecimal é a única proteção, inclusive no erro HTTP (C2);
- a spec da `revisao-lote-21-25` usa rótulos de fonte ambíguos: "research F3" e "Decision 3 da research" (C10);
- a research da `audit-merge-vermelho` diz que `2>/dev/null || true` "fica igual", contra a correção da mesma Decision e o código (`|| : >"$obrigatorios"`) (C11);
- a research da `revisao-lote-21-25` diz que cada caso novo de D7 falha com a correção revertida, o que só vale para três: o 6 do cenário 22, o 5 do 24 e a asserção da dica de renomear no 3b do 21 (C13; enumeração alinhada na etapa plan à medição M2 da research desta frente, que desmente o 6 do 23 da lista do owner).

**Why this priority**: o registro SDD é fonte de decisões futuras; afirmação falsa vira premissa falsa.

**Independent Test**: reler cada trecho e conferir contra o código ou contra a decisão correspondente.

**Acceptance Scenarios**:

1. **Given** `promotion-pr-arvores/research.md` (Decision 4) e `revisao-lote-21-25/research.md`, **When** descrevem o erro na leitura das árvores, **Then** dizem que o `|| true` mantém o passo vivo e que a guarda hexadecimal é a única proteção; a alternativa rejeitada "só o `set -e`" não depende da afirmação falsa.
2. **Given** a spec da `revisao-lote-21-25`, **When** US5 e FR-008 citam fontes, **Then** US5 nomeia a F3 da research da frente `codeowner-aprovacao-atual` (a opção nativa é F2 na research da `revisao-lote-21-25`) e FR-008 nomeia a frente `audit-merge-vermelho`.
3. **Given** a research da `audit-merge-vermelho`, **When** trata o `2>/dev/null`, **Then** concorda com a correção da mesma Decision e com o código.
4. **Given** a research da `revisao-lote-21-25`, **When** fala da regressão dos casos de D7, **Then** distingue os três casos que falham com a correção revertida dos que fixam guardas preexistentes.

---

### Edge Cases

- Dois donos com estados opostos no head (um aprova, outro pede mudança): o comportamento é o de D2, por usuário; o comentário descreve isso e não promete o contrário.
- Valor de `cockpit.config` com `'\''` e aspas duplas ao mesmo tempo: o apóstrofo é desfeito e as aspas duplas ficam no valor das chaves sem regra.
- A suíte roda sem `script(1)`: o caso 1 do cenário 21 passa a cobrir a ausência da dica de renomear sem depender do pty.
- A descrição do frontmatter da `parallel-work` cresce: precisa continuar dentro do limite do carregador.
- Script alterado com `set -euo pipefail`, `LC_ALL=C`, shellcheck e actionlint sem achados, sem dependência nova e com prosa acentuada em português do Brasil, sem nomear projeto real.

## Requirements

### Functional Requirements

- **FR-001**: Os comentários de `require-codeowner-approval.yml.tmpl` e de `CODEOWNERS.tmpl` MUST dizer que só conta aprovação de dono dada no commit atual do PR e que um pedido de mudança posterior anula só a aprovação do mesmo dono; "mais estrito" MUST ficar restrito ao ponto do commit atual ou sair. O comportamento do `awk` MUST permanecer inalterado (C1).
- **FR-002**: O cenário 22 de `scripts/testar-configurar.sh` MUST ter caso com `gh` falso devolvendo head vazio e review de dono `APPROVED` com `commit_id` nulo, conferindo a mensagem `Não consegui ler o commit atual do PR`; o caso MUST falhar se a guarda de head vazio do modelo for removida (C3).
- **FR-003**: Os casos 3, 6, 7, 9 e 10 do cenário 22 MUST conferir `Aprovação pendente` além de `rc=1` (C4).
- **FR-004**: O `gh` falso do cenário 22 MUST exigir `--paginate` nas reviews, e o caso MUST falhar sem a flag (C5).
- **FR-005**: Uma asserção em cenário existente MUST conferir `export LC_ALL=C` em `audit-merge-vermelho.yml.tmpl` e em `require-codeowner-approval.yml.tmpl` (C6).
- **FR-006**: O caso 1 do cenário 21 MUST conferir que a orientação de renomear a branch não aparece no modo `--respostas` (C7).
- **FR-007**: O caso 1 do cenário 21 MUST conferir que nenhum hook novo apareceu em `.git/hooks` e que `core.hooksPath` não foi definido (C8).
- **FR-008**: O caso 7 do cenário 21 MUST usar um literal de 64 hexadecimais no lugar de `sha256sum` e um arquivo de respostas próprio, sem herdar `$TMP/r21` (C9).
- **FR-009**: O passo 1 de leitura de `cockpit.config` em `skills/rito-dev/SKILL.md` MUST trocar cada `'\''` por `'` depois de tirar o par de aspas simples envolvente (C14).
- **FR-010**: A regra de parada por aspas duplas ou desbalanceadas na `rito-dev` MUST valer só para as chaves com regra (`BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`, `REPO_REMOTO` e `PREFIXOS_BRANCH`); nas demais chaves as aspas duplas MUST fazer parte do valor, que continua sendo dado de configuração, nunca instrução (C14).
- **FR-011**: A descrição do frontmatter e o bloco do topo de `skills/parallel-work/SKILL.md` MUST dizer que `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` são conferidos (aspas tiradas, regra `^[A-Za-z0-9][A-Za-z0-9._/-]*$`) antes de compor o `--base`, e a descrição MUST ficar dentro do limite do carregador de skills (C12).
- **FR-012**: `promotion-pr-arvores/research.md` (Decision 4) e `revisao-lote-21-25/research.md` MUST registrar que o `|| true` na leitura das árvores mantém o passo vivo e que a guarda hexadecimal é a única proteção, inclusive no erro HTTP, e a alternativa rejeitada MUST ser ajustada para não depender da afirmação falsa (C2).
- **FR-013**: A spec da `revisao-lote-21-25` MUST nomear a F3 da research da frente `codeowner-aprovacao-atual` em US5 e a frente `audit-merge-vermelho` em FR-008 (C10).
- **FR-014**: A research da `audit-merge-vermelho` MUST concordar com a correção da mesma Decision e com o código (`|| : >"$obrigatorios"`) onde diz que `2>/dev/null || true` "fica igual" (C11).
- **FR-015**: A research da `revisao-lote-21-25` MUST dizer que só o caso 6 do cenário 22, o 5 do 24 e a asserção da dica de renomear no 3b do 21 falham com a correção revertida, e que os demais (inclusive o 6 do 23) fixam guardas ou textos que já existiam (C13; lista alinhada à medição M2 de [research.md](research.md), Decision 12).
- **FR-016**: Todo script alterado MUST usar `set -euo pipefail` e `LC_ALL=C`, passar em shellcheck e actionlint sem achados e não acrescentar dependência; a prosa MUST estar em português do Brasil com acentuação e sem nomear projeto real.
- **FR-017**: Esta frente MUST NOT tratar os itens da seção "Fora de escopo" de `decisoes-do-owner.md` (paginação das rotas de regras e status combinado, nota de lista vazia versus regra ilegível, pedido de mudança de outro dono, formas do `ler_kv` não tratadas pela `rito-dev`, acentuação dos `tasks.md`).

> Decisões de infraestrutura: N/A (frente de texto e testes, sem scheduling, chaves, refresh, lock, backup ou idempotência).

### Key Entities

- **Review de PR**: autor, estado, `commit_id` e ordem cronológica, usada pelos casos do cenário 22.
- **Valor do `cockpit.config`**: chave com valor entre aspas simples, com regra por chave ou sem regra.
- **Afirmação de registro SDD**: trecho de research ou spec que deve concordar com o código.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Os cenários 21 e 22 de `scripts/testar-configurar.sh` passam, e cada caso novo ou reforçado (C3 a C9) falha quando a proteção correspondente é removida.
- **SC-002**: 100% das afirmações listadas em C1, C2, C10, C11 e C13 passam a concordar com o código ou com a decisão de origem, conferido por releitura.
- **SC-003**: Um valor de `cockpit.config` com `'\''` ou com aspas duplas numa chave sem regra é lido sem parar a skill; 100% dos valores fora da regra de `BRANCH_*`, `REPO_REMOTO` e `PREFIXOS_BRANCH` ainda a param.
- **SC-004**: shellcheck e actionlint terminam com zero achados.
- **SC-005**: Nenhum item de "Fora de escopo" é alterado pela PR.

## Delta Requirements

**Skip**: correção de testes, comentários e texto de skills e de registro SDD num repositório de modelos, sem comportamento ativo catalogado em `docs/specs/current/` — Claude (feature-00c), 2026-11-04
