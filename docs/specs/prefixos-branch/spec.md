# Feature Specification: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch`
**Created**: 2026-10-05
**Status**: Draft
**Origem**: issue #16 (correlata da #14). Decisões D1, D2 e D3 do owner, normativas e fechadas,
em `decisoes-do-owner.md` (mesmo diretório).

> Decisões de infraestrutura: N/A (script shell local, sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry).

## Problema

Os prefixos das branches de trabalho (`feature/`, `fix/`, `chore/`, `docs/`, `hotfix/`) são
literais no guia de ciclo Git gerado, no guia do rito gerado e na skill do rito. Um projeto que
adota outra convenção (por exemplo `feat/`) precisa declarar os dois documentos como mantidos
pelo projeto e a skill continua citando o prefixo antigo. O Princípio I manda que valor que varia
por projeto seja chave do `cockpit.config`.

## User Scenarios & Testing

### User Story 1 - Projeto declara seus prefixos e os documentos gerados os refletem (Priority: P1)

Quem configura o projeto declara no `cockpit.config` os cinco prefixos de branch na ordem fixa
`feature`, `fix`, `chore`, `docs`, `hotfix`. O guia de ciclo Git e o guia do rito renderizados
passam a citar esses prefixos.

**Why this priority**: é o valor central da issue: convenção própria sem reescrever documentos à
mão.

**Independent Test**: configurar um projeto de teste com `PREFIXOS_BRANCH='feat fix chore docs
hotfix'` e conferir que os dois documentos renderizados citam `feat/<slug>` e nenhum
`feature/<slug>`.

**Acceptance Scenarios**:

1. **Given** `PREFIXOS_BRANCH` com cinco prefixos válidos, **When** o configurador renderiza os
   templates, **Then** `docs/CICLO-GIT.md` e `docs/rito-dev.md` citam cada prefixo na posição do
   tipo correspondente.
2. **Given** a mesma chave, **When** o configurador grava o `cockpit.config`, **Then** a chave
   é gravada como as demais opcionais, e os placeholders derivados não são gravados.

---

### User Story 2 - Projeto sem a chave segue idêntico ao de hoje (Priority: P1)

Projetos já configurados, sem `PREFIXOS_BRANCH`, continuam funcionando, sem pergunta nem erro, e
os documentos gerados não mudam.

**Why this priority**: compatibilidade; sem ela o `--atualizar` vira mudança incompatível.

**Independent Test**: renderizar com a chave ausente e comparar byte a byte os dois documentos
com os gerados antes da mudança.

**Acceptance Scenarios**:

1. **Given** chave ausente ou em branco, **When** o configurador renderiza, **Then** vale
   `feature fix chore docs hotfix` e os dois documentos são idênticos byte a byte aos de hoje.
2. **Given** um projeto já configurado sem a chave, **When** roda `--atualizar`, **Then** não
   há pergunta nem erro.

---

### User Story 3 - Valor inválido é recusado na fronteira (Priority: P2)

Quem declara a chave com valor malformado recebe erro claro, citando a chave, antes de qualquer
escrita.

**Why this priority**: prefixo inválido produziria nome de branch inválido ou ambíguo em
documentos que o time segue.

**Independent Test**: rodar o configurador com cada valor inválido e verificar exit 1 com a
mensagem citando `PREFIXOS_BRANCH`.

**Acceptance Scenarios**:

1. **Given** quantidade de prefixos diferente de cinco, **When** o configurador valida,
   **Then** sai com exit 1 citando a chave.
2. **Given** prefixo com `/`, com caractere de controle ou que não forma nome de branch válido,
   **When** valida, **Then** exit 1 citando a chave.
3. **Given** prefixo repetido entre tipos, **When** valida, **Then** exit 1 citando a chave.

---

### User Story 4 - Modo interativo e skill do rito honram a chave (Priority: P2)

No modo interativo a chave é perguntada como opcional, com a dica do padrão. A Fase 1 da skill
do rito lê a chave do `cockpit.config` na hora e usa o padrão quando ausente.

**Why this priority**: sem isso o configurador e a skill divergem do documento gerado.

**Independent Test**: rodar o modo interativo respondendo `-` e depois um valor; ler a Fase 1 da
skill e a tabela de chaves consumidas.

**Acceptance Scenarios**:

1. **Given** modo interativo, **When** a pergunta de `PREFIXOS_BRANCH` é exibida, **Then** ela
   mostra o padrão como dica e `-` equivale a vazio.
2. **Given** o código e a prosa entregues, **When** o shellcheck e a revisão rodam, **Then**
   o bash com `set -euo pipefail` e `LC_ALL=C` passa sem findings, sem dependência nova, com
   prosa em português do Brasil acentuado e sem nomear projeto real.
3. **Given** chave declarada, **When** a skill executa a Fase 1, **Then** os nomes de branch
   usam os prefixos declarados; chave ausente usa o padrão.

---

### Edge Cases

- Valor com espaços múltiplos ou nas bordas: tratado como separador de espaço; a contagem vale
  sobre os prefixos não vazios.
- Valor só de espaços: equivale a ausente.
- Prefixo com caractere que o Git recusa em nome de branch (por exemplo `..`, `~`, terminando
  em `.lock`): recusado.
- `fix` e `hotfix` com o mesmo prefixo: recusado por repetição.
- Projeto que já declarou os documentos como mantidos pelo projeto: não é afetado.

## Requirements

### Functional Requirements

- **FR-001**: O configurador MUST aceitar a chave opcional `PREFIXOS_BRANCH`: exatamente cinco
  prefixos separados por espaço, na ordem fixa `feature`, `fix`, `chore`, `docs`, `hotfix`.
- **FR-002**: O configurador MUST recusar com exit 1, citando a chave, valor com quantidade
  diferente de cinco prefixos.
- **FR-003**: O configurador MUST recusar com exit 1, citando a chave, prefixo com `/`, com
  caractere de controle ou que não forma nome de branch válido segundo o Git.
- **FR-004**: O configurador MUST recusar com exit 1, citando a chave, prefixo repetido entre
  tipos.
- **FR-005**: A chave MUST ser opcional: perguntada no modo interativo com `-` para vazio e a dica
  do padrão, gravada como as demais opcionais; valor em branco equivale a não declarada.
- **FR-006**: Com a chave ausente ou em branco, o configurador MUST usar
  `feature fix chore docs hotfix`, sem pergunta nem erro no `--atualizar`.
- **FR-007**: O configurador MUST derivar, sempre com valor, os placeholders de render
  `{{PREFIXO_FEATURE}}`, `{{PREFIXO_FIX}}`, `{{PREFIXO_CHORE}}`, `{{PREFIXO_DOCS}}` e
  `{{PREFIXO_HOTFIX}}`; eles MUST NOT ser perguntados nem gravados no `cockpit.config`.
- **FR-008**: Os templates `CICLO-GIT.md.tmpl` e `rito-dev.md.tmpl` MUST usar os placeholders
  derivados e MUST NOT usar `PREFIXOS_BRANCH` diretamente (regra do cenário 15).
- **FR-009**: Com a chave ausente, `docs/CICLO-GIT.md` e `docs/rito-dev.md` renderizados MUST ser
  byte a byte os de hoje.
- **FR-010**: A Fase 1 da skill `rito-dev` MUST ler `PREFIXOS_BRANCH` do `cockpit.config` na
  hora, usar o padrão quando ausente, e a chave MUST constar na tabela de chaves consumidas.
- **FR-011**: `cockpit.config.example` e o contrato `docs/specs/configurar/contracts/cli.md`
  MUST documentar a chave.
- **FR-012**: A suíte `scripts/testar-configurar.sh` MUST ganhar um cenário novo cobrindo chave
  ausente com render idêntico, chave válida refletida nos dois documentos, valores inválidos com
  exit 1 e modo interativo; o cenário 14 passa a exigir 20 respostas mínimas.
- **FR-013**: A implementação MUST usar bash com `set -euo pipefail`, `LC_ALL=C`, shellcheck sem
  findings e nenhuma dependência nova; prosa em português do Brasil com acentuação e sem nomear
  projeto real.

### Key Entities

- **Chave `PREFIXOS_BRANCH`**: lista posicional de cinco prefixos; a posição define o tipo.
- **Placeholders derivados**: cinco valores de render, um por tipo, calculados da chave ou do
  padrão; não persistidos.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Com a chave ausente, 100% dos documentos gerados afetados (2 de 2) são idênticos
  byte a byte aos de antes da mudança.
- **SC-002**: Com uma chave válida, 0 ocorrências do prefixo padrão substituído nos dois
  documentos gerados e 5 de 5 prefixos refletidos.
- **SC-003**: 100% dos valores inválidos listados (quantidade, `/`, controle, nome inválido,
  repetição) terminam em exit 1 citando a chave, sem escrita parcial.
- **SC-004**: Um projeto já configurado roda o `--atualizar` sem nenhuma pergunta nova e sem
  erro.
- **SC-005**: A suíte de testes do configurador passa inteira, inclusive o cenário novo.

## Delta Requirements

**Skip**: feature estende o configurador por chave opcional, sem alterar comportamento ativo
documentado em `docs/specs/current/` (corpus ainda inexistente neste repositório) — agente
feature-00c, 2026-10-05.

## Premissas

- A validação de nome de branch usa o próprio Git (`git check-ref-format --branch`), já exigido
  pelo ciclo; nenhuma dependência nova.
- Fora de escopo (D3): exemplos `fix/…` e `feat/…` de `skills/parallel-work/SKILL.md`, tipos de
  branch além dos cinco e renomear branches existentes.
