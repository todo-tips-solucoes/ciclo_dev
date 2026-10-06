# Feature Specification: auditoria de merge vermelho sem falsos achados

**Feature**: `audit-merge-vermelho`
**Created**: 2026-10-06
**Status**: Draft
**Origem**: issue #10 (pontos deferidos no code review da PR #6). Decisões D1 e D2 do owner,
normativas e fechadas, em `decisoes-do-owner.md` (mesmo diretório); o clarify não as reabre.

> Decisões de infraestrutura: N/A (passo de fluxo de CI sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry).

## Problema

O fluxo de auditoria de merge vermelho do template tem dois pontos frágeis. (1) As regras da
branch base são consultadas com o nome cru da branch na rota: um nome com `/` (por exemplo
`release/2026`) quebra a rota, a consulta falha em silêncio e o fluxo lista todo check vermelho,
inclusive os não obrigatórios (reporta a mais). (2) A checagem de issue duplicada depende do
índice de busca, que pode não refletir uma issue recém-criada: o mesmo PR pode gerar issue
repetida.

## User Scenarios & Testing

### User Story 1 - Branch base com barra consulta as regras dela (Priority: P1)

Quando o PR mergeado tem como base uma branch cujo nome contém `/`, o fluxo consulta as regras
dessa branch e filtra os checks vermelhos pelos obrigatórios, em vez de cair no aviso de regra
ilegível.

**Why this priority**: evita auditoria com ruído (checks não obrigatórios listados como se
fossem relevantes), o defeito de efeito mais visível.

**Independent Test**: executar o passo do fluxo renderizado com base `release/2026` e `gh`
falso; conferir que a consulta de regras recebe o nome codificado.

**Acceptance Scenarios**:

1. **Given** um PR mergeado em `release/2026`, **When** o passo consulta as regras da base,
   **Then** o nome da branch chega codificado para caminho de URL à rota de regras.
2. **Given** uma base sem `/` (ex.: `main`), **When** o passo consulta as regras, **Then** a rota
   é a mesma de hoje.

---

### User Story 2 - Issue de mesmo título já existente não gera outra (Priority: P1)

A checagem de duplicada não passa pelo índice de busca: encontra a issue de mesmo título exato,
aberta ou fechada, mesmo criada segundos antes.

**Why this priority**: o índice de busca atrasado reabre o defeito de duplicidade; a regra
"título idêntico, em qualquer estado, não gera issue nova" precisa valer sempre.

**Independent Test**: executar o passo com `gh` falso cuja listagem direta devolve uma issue de
mesmo título; conferir que nenhuma issue é criada.

**Acceptance Scenarios**:

1. **Given** uma issue (aberta ou fechada) com título idêntico ao da auditoria, **When** o passo
   roda, **Then** encerra sem criar issue.
2. **Given** issues com títulos parecidos mas não idênticos (ex.: outro número de PR), **When**
   o passo roda, **Then** a issue é criada normalmente.
3. **Given** a issue idêntica existir além da primeira página de resultados da listagem,
   **When** o passo roda, **Then** ela ainda é encontrada.

---

### Edge Cases

- Nome de branch com caracteres além de `/` que exigem codificação em caminho de URL.
- Falha real na consulta de regras (permissão, rota inexistente) continua caindo no aviso de
  regra ilegível, sem abortar o fluxo.
- Template com shell embutido em bash, sem dependência nova: actionlint e shellcheck sem findings.
- Repositório com muitas issues: a busca de duplicada não pode parar na primeira página.

## Clarifications

### Session 2026-10-06

- Q: Se a listagem de issues falhar ao checar duplicada, o passo cria a issue mesmo assim ou encerra sem criar? → A: Falha o passo com erro visível, sem criar issue (o `set -euo pipefail` do template já produz esse comportamento; a troca de consulta não o altera). Falha na consulta de regras segue como aviso de regra ilegível.

## Requirements

### Functional Requirements

- **FR-001**: O passo MUST codificar o nome da branch base para uso em caminho de URL antes de
  compô-lo na rota de regras da branch (D1).
- **FR-002**: Branch base com `/` MUST consultar as regras dela e aplicar o filtro de checks
  obrigatórios, sem cair no aviso de regra ilegível (D1).
- **FR-003**: Branch base sem caracteres especiais MUST manter o comportamento atual.
- **FR-004**: A checagem de issue duplicada MUST NOT depender do índice de busca; usa listagem
  direta de issues filtrada pelo título exato (D2).
- **FR-005**: A checagem MUST considerar issues em qualquer estado (aberta ou fechada) e MUST
  NOT criar issue quando houver título idêntico (D2).
- **FR-006**: A checagem MUST cobrir todas as issues do repositório, não só a primeira página
  de resultados. A forma exata (rota, filtros, paginação) é decidida no plan, com a documentação
  oficial do GitHub como fonte (Princípio VI).
- **FR-007**: O que conta como merge vermelho, o conteúdo da issue aberta, gatilhos e permissões
  do fluxo MUST permanecer inalterados.
- **FR-008**: O template MUST seguir usando apenas shell embutido em bash, sem dependência nova,
  e passar em actionlint e shellcheck sem findings.
- **FR-009**: O cenário 24 de `scripts/testar-configurar.sh`, posicionado logo antes do cenário
  11, MUST extrair o passo do YAML renderizado e executá-lo com `gh` falso, cobrindo: base com
  `/` chega codificada à rota; issue de mesmo título já existente não gera outra.

- **FR-010**: Falha na listagem de issues da checagem de duplicada MUST falhar o passo com erro visível, sem criar issue.

### Key Entities

- **Issue de auditoria**: registro por PR mergeado com check vermelho; identificada pelo título
  exato derivado do número do PR.
- **Regras da branch base**: conjunto de checks obrigatórios consultado pelo nome da branch.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Com base `release/2026`, 100% das execuções do cenário de teste chegam à rota de
  regras com o nome codificado.
- **SC-002**: Em 100% das execuções do cenário de teste com issue de título idêntico existente,
  nenhuma issue nova é criada.
- **SC-003**: Zero findings de actionlint e shellcheck sobre o template e a suíte de testes
  continua verde.

## Delta Requirements

**Skip**: correção de passo de template de CI, sem comportamento canônico em `docs/specs/current/` — Claude (feature-00c), 2026-10-06
