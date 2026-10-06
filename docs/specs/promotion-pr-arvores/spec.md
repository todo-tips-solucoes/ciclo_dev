# Feature Specification: PR de promoção decidido pelo conteúdo das árvores

**Feature**: `promotion-pr-arvores`
**Created**: 2026-10-06
**Status**: Draft
**Origem**: issue #7. Decisões D1 e D2 do owner, normativas e fechadas, em
`decisoes-do-owner.md` (mesmo diretório); o clarify não as reabre.

> Decisões de infraestrutura: N/A (passo de fluxo de CI sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry próprio).

## Problema

O fluxo de promoção gerado pelo cockpit decide se há o que promover contando os commits da
integração que a produção ainda não contém. Quando a integração entra na produção por squash, a
produção nunca passa a conter esses commits: a contagem segue positiva e o PR de promoção é
aberto de novo a cada push na integração, mesmo sem nada novo de fato. A Fase 9 do rito já manda
promover por merge commit, mas o fluxo gerado não pode depender dessa disciplina.

## User Scenarios & Testing

### User Story 1 - Sem PR quando o conteúdo já é igual (Priority: P1)

Quem mantém um projeto com branches de integração e de produção distintas promove a integração
por squash. No push seguinte na integração, o fluxo constata que o conteúdo das duas branches é
idêntico e não abre nem reabre PR de promoção.

**Why this priority**: é o defeito da issue: PR fantasma a cada push, ruído e risco de merge
desnecessário.

**Independent Test**: executar o passo do fluxo com as duas árvores iguais e a contagem de
commits à frente positiva; conferir que nenhum PR é criado nem editado.

**Acceptance Scenarios**:

1. **Given** produção e integração com árvore igual e commits à frente positivos (pós-squash),
   **When** o fluxo roda após um push na integração, **Then** termina com sucesso, informa que não
   há o que promover e não cria nem edita PR.
2. **Given** a mesma situação e um PR de promoção já aberto, **When** o fluxo roda, **Then** não
   cria outro PR e termina com sucesso sem alterar o existente.

---

### User Story 2 - Árvores diferentes mantêm o comportamento atual (Priority: P1)

Quando a integração tem conteúdo que a produção não tem, o fluxo continua abrindo um único PR de
promoção, ou atualizando o aberto, com a lista de commits no corpo.

**Why this priority**: a correção não pode regredir o caso que justifica o fluxo (FR-008 da
frente `templates-automacao`).

**Independent Test**: executar o passo com árvores diferentes; conferir criação do PR quando não
há aberto e atualização quando há.

**Acceptance Scenarios**:

1. **Given** árvores diferentes e nenhum PR aberto, **When** o fluxo roda, **Then** abre um PR
   de promoção.
2. **Given** árvores diferentes e um PR aberto, **When** o fluxo roda, **Then** atualiza o corpo
   do PR existente e não abre outro.

---

### User Story 3 - Cabeçalho documenta o efeito do tipo de merge (Priority: P2)

Quem lê o fluxo gerado encontra, no comentário de cabeçalho, a orientação de promover por merge
commit (como na Fase 9 do rito) e o aviso de que, com squash, o fluxo deixa de reabrir o PR
quando o conteúdo já é igual.

**Why this priority**: evita que o comportamento pareça acidental; não altera execução.

**Independent Test**: ler o cabeçalho do template e conferir as duas afirmações.

**Acceptance Scenarios**:

1. **Given** o template renderizado, **When** o cabeçalho é lido, **Then** cita a promoção
   recomendada por merge commit e o efeito do squash sobre a reabertura do PR.

---

### Edge Cases

- Integração e produção são a mesma branch: continua saindo sem nenhuma consulta (modelo de
  branch única inalterado).
- Falha ao obter uma das árvores (erro de API ou branch ausente): o passo falha de forma visível,
  sem abrir PR com base em comparação incompleta.
- Produção à frente da integração com árvores diferentes: segue o comportamento atual (a
  decisão passa a depender só do conteúdo, não da direção).
- Contagem de commits à frente igual a zero com árvores diferentes: não ocorre por construção
  quando há conteúdo a promover; se ocorrer, prevalece a decisão pelo conteúdo de hoje (há o que
  promover).
- Comportamento da API do GitHub citado nos artefatos: sem fonte na documentação oficial e sem
  link na research, o dado não entra; nenhum nome de campo é suposto.
- Prosa dos artefatos: em português do Brasil com acentuação, sem nomear nenhum projeto real.

## Requirements

### Functional Requirements

- **FR-001**: O fluxo MUST decidir que não há o que promover quando a árvore de arquivos do
  commit da produção é igual à do commit da integração, qualquer que seja o tipo de merge usado
  antes e a contagem de commits à frente.
- **FR-002**: Nesse caso o fluxo MUST terminar com sucesso, informando em mensagem que não há o
  que promover, sem criar nem editar PR.
- **FR-003**: Com árvores diferentes, o fluxo MUST manter o comportamento atual: um único PR de
  promoção, criado se não houver aberto e com o corpo atualizado se houver (FR-008 de
  `templates-automacao`).
- **FR-004**: O modelo de branch única (integração igual à produção) MUST continuar saindo antes
  de qualquer chamada à API.
- **FR-005**: Falha na leitura de qualquer das duas árvores MUST fazer o passo falhar, sem abrir
  PR.
- **FR-006**: O comentário de cabeçalho do template MUST registrar que a promoção recomendada é
  por merge commit (Fase 9 do `rito-dev`) e que, com squash, o fluxo deixa de reabrir o PR quando
  o conteúdo já é igual.
- **FR-007**: O template MUST permanecer sem dependência nova além do que o passo já usa, com
  shell embutido em bash, e passar em actionlint e shellcheck sem findings.
- **FR-008**: Gatilhos, permissões e tipo de merge da promoção MUST permanecer como estão, salvo
  o mínimo necessário para ler as duas árvores; a Fase 9 do `rito-dev` não muda.
- **FR-009**: Um cenário de teste novo, numerado 23, MUST ser inserido em
  `scripts/testar-configurar.sh` logo antes do cenário 11, no padrão do cenário 16 (passo
  extraído e executado com `gh` falso), cobrindo árvores iguais com commits à frente positivos
  (sem PR) e árvores diferentes (caminho atual).
- **FR-010**: Todo comportamento da API do GitHub citado nos artefatos MUST vir da documentação
  oficial, com link na research; nenhum nome de campo é suposto.
- **FR-011**: Prosa em português do Brasil com acentuação; nenhum artefato nomeia projeto real.

### Key Entities

- **Árvore do commit**: conteúdo de arquivos de um commit, independente do histórico que o
  levou até lá; é o critério de igualdade entre produção e integração.
- **PR de promoção**: PR único da integração para a produção, aberto ou atualizado pelo fluxo.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Em 100% das execuções com árvores iguais, nenhum PR é criado nem editado.
- **SC-002**: Em 100% das execuções com árvores diferentes, existe exatamente um PR de promoção
  aberto ao final.
- **SC-003**: O cenário 23 passa nas duas situações e a suíte existente segue verde.
- **SC-004**: actionlint e shellcheck reportam zero findings sobre o template renderizado.

## Delta Requirements

**Skip**: ajuste de template de automação, sem capability ativa catalogada em
`docs/specs/current/` (corpus inexistente neste projeto) — feature-00c, 2026-10-06
