# Feature Specification: endurecimento do configurador (branches e manifesto)

**Feature**: `configurar-endurecimento`
**Created**: 2026-10-06
**Status**: Draft
**Origem**: issues #19 e #18 (`configurar.sh`). Decisões D1, D2 e D3 do owner, normativas e
fechadas, em `decisoes-do-owner.md` (mesmo diretório); o clarify não as reabre.

> Decisões de infraestrutura: N/A (script shell local, sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry).

## Problema

`BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` passam hoje só por checagens de forma (vazio, hífen
inicial, `@{`) e pela validação de nome de referência do Git, que aceita metacaracteres de shell.
A skill `rito-dev` compõe comandos git com esses valores, e o `cockpit.config` é versionado e
pode ser editado à mão. Além disso, o configurador grava um manifesto vazio quando nenhum destino
é gerado, contrariando o comentário da própria função.

## User Scenarios & Testing

### User Story 1 - O configurador recusa nomes de branch com caracteres perigosos (Priority: P1)

Quem configura o projeto informa `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO`. Valores com
metacaracteres de shell ou espaço são recusados com mensagem que cita a chave e o conjunto aceito.

**Why this priority**: fecha a superfície de injeção de comando a partir de valor de configuração.

**Independent Test**: rodar o configurador com `--respostas` trazendo cada valor recusado e cada
aceito, e conferir saída, código e ausência de gravação.

**Acceptance Scenarios**:

1. **Given** `BRANCH_INTEGRACAO` ou `BRANCH_PRODUCAO` com `main;curl x`, `$(x)`, crase, `|` ou
   espaço, **When** o configurador valida as respostas, **Then** sai com código 1 citando a chave
   e o conjunto aceito, sem gravar nada.
2. **Given** valores `main` e `release/2026`, **When** o configurador valida, **Then** aceita.
3. **Given** modo interativo e valor fora da regra, **When** o configurador valida a resposta,
   **Then** pergunta de novo em vez de encerrar.
4. **Given** `cockpit.config` existente com valor fora da regra, **When** roda `--atualizar`,
   **Then** recusa sem gravar, com mensagem que diz como corrigir o valor.

---

### User Story 2 - A skill do rito confere os nomes antes de compor comandos (Priority: P1)

A skill `rito-dev` aplica a mesma regra logo depois de ler o `cockpit.config`, antes de compor
qualquer comando, porque o arquivo pode ter sido editado à mão.

**Why this priority**: a edição manual contorna o configurador; a skill é o ponto onde o valor
vira comando.

**Independent Test**: ler `skills/rito-dev/SKILL.md` e conferir que a conferência precede todo
comando composto e que o fluxo para nomeando a chave.

**Acceptance Scenarios**:

1. **Given** `cockpit.config` com `BRANCH_INTEGRACAO` ou `BRANCH_PRODUCAO` fora da regra, **When**
   a skill lê o arquivo, **Then** para, nomeia a chave e não cola o valor em nenhum comando.
2. **Given** ambos os valores dentro da regra, **When** a skill lê o arquivo, **Then** prossegue
   para a fase seguinte normalmente.

---

### User Story 3 - Sem destino a registrar, nenhum manifesto é criado (Priority: P2)

Quando todos os templates são pulados e não há manifesto anterior, o configurador não grava
`.cockpit/manifesto.sha256` vazio nem cria `.cockpit/` só por causa dele.

**Why this priority**: remove artefato inútil e alinha o comportamento ao comentário da função.

**Independent Test**: configurar um repositório sem manifesto anterior com todos os destinos
listados como mantidos pelo projeto e conferir que `.cockpit/` não existe depois.

**Acceptance Scenarios**:

1. **Given** repositório sem manifesto anterior e todos os destinos mantidos pelo projeto,
   **When** o configurador termina, **Then** `.cockpit/` e o manifesto não existem.
2. **Given** manifesto anterior existente, **When** o configurador roda sem linha nova a
   registrar, **Then** a regra de hoje continua (manifesto mantido e atualizado).

---

### Edge Cases

- Valor iniciado por `.`, `/` ou `-` é recusado pela regra de caracteres (primeiro caractere
  alfanumérico).
- `release/2026` (com barra) é aceito; `a..b` segue recusado pela validação de referência do Git,
  que continua valendo além da nova regra.
- Valor vazio segue recusado como hoje.
- Template com destino pulado por cópia da árvore principal não conta como linha a registrar.
- A guarda do manifesto considera linhas registráveis, não a contagem de templates pulados: com
  todos os templates pulados e sem manifesto anterior, não há linha registrável e nada é gravado.

## Requirements

### Functional Requirements

- **FR-001**: O configurador MUST exigir que `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` casem com
  `^[A-Za-z0-9][A-Za-z0-9._/-]*$`, além das checagens existentes (incluída a validação de
  referência do Git).
- **FR-002**: Valor recusado MUST gerar saída com código 1 citando a chave e o conjunto aceito.
- **FR-003**: No modo interativo o configurador MUST perguntar de novo; em `--respostas` e
  `--atualizar` MUST recusar sem gravar nada.
- **FR-004**: Um `cockpit.config` existente com valor fora da regra MUST ser recusado no
  `--atualizar` (fail-closed), com mensagem que diz como corrigir.
- **FR-005**: A skill `rito-dev` MUST aplicar a mesma regra às duas chaves logo após ler o
  `cockpit.config` e antes de compor qualquer comando; fora da regra, MUST parar nomeando a chave
  e NUNCA colar o valor num comando para testá-lo.
- **FR-006**: O configurador MUST sair de `gravar_manifesto` sem gravar quando não há linha a
  registrar e não existe manifesto anterior, sem criar `.cockpit/` por causa do manifesto.
- **FR-007**: Com manifesto anterior, o comportamento de hoje MUST permanecer.
- **FR-008**: A guarda MUST considerar linhas efetivamente registráveis, não a contagem de todos
  os templates (inclusive os pulados), de modo que a função e seu comentário coincidam.
- **FR-009**: Um cenário de teste novo, número 21, MUST ser inserido em
  `scripts/testar-configurar.sh` logo antes do cenário 11, cobrindo os valores recusados e
  aceitos e a ausência de `.cockpit/` quando todos os destinos são listados sem manifesto anterior.

### Fora de escopo

`REPO_REMOTO` (regra própria) e as chaves `CMD_*` (comandos por desenho) não mudam.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% dos valores de teste com metacaracteres (`;`, `$(`, crase, `|`, espaço) são
  recusados nas duas chaves, em todos os modos, sem gravação.
- **SC-002**: Os valores `main` e `release/2026` são aceitos nas duas chaves.
- **SC-003**: Em repositório sem manifesto anterior e sem destino gerado, 0 arquivos são criados
  sob `.cockpit/`.
- **SC-004**: A suíte de testes existente continua passando integralmente, e o shellcheck não
  reporta findings.

## Delta Requirements

**Skip**: feature endurece validação e corrige borda do configurador, sem alterar comportamento
ativo documentado em `docs/specs/current/` (corpus ainda inexistente neste repositório) — agente
feature-00c, 2026-10-06.

## Premissas

- A validação de referência do Git continua sendo a já usada pelo configurador.
- O padrão de conferência na skill segue o da Fase 1 com `PREFIXOS_BRANCH` (D4 da #16).
