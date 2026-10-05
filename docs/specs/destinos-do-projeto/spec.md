# Feature Specification: destinos do projeto no configurar.sh

**Feature**: `destinos-do-projeto`
**Created**: 2026-10-05
**Status**: Draft
**Origem**: issues #14 e #15 (`configurar.sh`). Decisões D1, D2 e D3 do owner, normativas e
fechadas, em `decisoes-do-owner.md` (mesmo diretório).

> Decisões de infraestrutura: N/A (script shell local, sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry).

## Problema

Hoje `PULAR` só vale para semente (`.semente.tmpl`) cujo destino existe. Qualquer outro destino
editado à mão é conflito e recusa o lote inteiro (exit 2), salvo `--forcar`, que apaga a versão
do projeto. Projetos que mantêm à mão um arquivo gerado por template (por exemplo o fluxo de CI)
ficam sem saída que preserve a edição (#14). Além disso, numa worktree vinculada, destinos
ignorados pelo git (como um `CLAUDE.md` local) não existem no checkout novo, e o configurador
os regeneraria ou os deixaria ausentes, apesar de existirem na árvore principal (#15).

## Clarifications

### Session 2026-10-05

As decisões abaixo vêm do owner e não são reabertas:

- Q: Destino mantido pelo projeto vale também sob `--forcar` e no modo interativo? → A: sim, é
  tratado como semente existente (D1).
- Q: A recusa do lote por edição local muda? → A: não; só a mensagem passa a sugerir
  `DESTINOS_DO_PROJETO` (D2).
- Q: Cópia da árvore principal entra no manifesto? → A: não, não foi gerada por template (D3).
- Q: Origem da árvore principal que é link simbólico? → A: recusada sempre, sem seguir o link;
  tratada como sem origem, com aviso (consistente com D3: arquivo regular, não link).
- Q: O que é "item vazio" numa lista separada por espaço? → A: só o item composto de aspas vazias;
  espaços repetidos não geram item e valor em branco é chave não declarada (D1 mantida).
- Q: Prefixos de branch fixos e conflito por arquivo? → A: fora de escopo (issue #16; recusado em D2).

## User Scenarios & Testing

### User Story 1 - Projeto declara os destinos que mantém à mão (Priority: P1)

Quem mantém um arquivo gerado por template declara o caminho em `DESTINOS_DO_PROJETO`. O
configurador não o renderiza, não o compara e não o conta como conflito.

**Independent Test**: num projeto-alvo temporário, editar um destino à mão, listá-lo na chave e
rodar o configurador (inclusive com `--forcar` e `--atualizar`); o arquivo mantém o conteúdo
byte a byte, o exit é 0 e o relatório traz `mantido (projeto): <rel>`.

**Acceptance Scenarios**:
1. **Given** destino listado e editado à mão, **When** configura, **Then** não é alterado, não é
   conflito e sai `mantido (projeto): <rel>`, contado à parte das sementes.
2. **Given** destino listado, **When** roda com `--forcar` ou no modo interativo, **Then** segue
   intacto, sem prompt de sobrescrita.
3. **Given** destino listado com entrada no manifesto, **When** configura, **Then** a entrada é mantida.
4. **Given** destino listado que é de semente e ausente, **When** configura, **Then** não é gerado.
5. **Given** destino listado e outro template editado à mão e não listado, **When** configura,
   **Then** o lote é recusado (exit 2) e a mensagem sugere `--forcar` e `DESTINOS_DO_PROJETO`.

### User Story 2 - Chave validada na fronteira de confiança (Priority: P1)

O valor da chave vem do `cockpit.config` e não é confiável; entradas inválidas são recusadas
antes de qualquer escrita.

**Acceptance Scenarios**:
1. **Given** item absoluto, com `..`, vazio (só aspas) ou com caractere de controle, **When** configura,
   **Then** exit 1 citando `DESTINOS_DO_PROJETO` e nada é gravado.
2. **Given** item que não bate com destino de nenhum template, **When** configura, **Then** aviso
   e o lote segue (não é erro).

### User Story 3 - Chave é opcional e configurável como as demais (Priority: P2)

**Acceptance Scenarios**:
1. **Given** chave ausente, **When** configura, **Then** comportamento idêntico ao atual.
2. **Given** modo interativo, **When** o configurador pergunta as chaves opcionais, **Then**
   pergunta `DESTINOS_DO_PROJETO` (`-` para vazio) e a grava no config como as demais.

### User Story 4 - Worktree recebe os arquivos ignorados da árvore principal (Priority: P1)

Numa worktree vinculada, um destino ausente de semente ou de destino do projeto, ignorado pelo
git, é copiado da árvore principal quando existe lá.

**Independent Test**: criar repositório com `.gitignore` cobrindo `CLAUDE.md`, um `CLAUDE.md`
na árvore principal, uma worktree vinculada; configurar a worktree e conferir que o arquivo é
uma cópia regular (não link), idêntica à da árvore principal, fora do manifesto.

**Acceptance Scenarios**:
1. **Given** worktree vinculada, destino ausente e ignorado, arquivo existente na árvore
   principal, **When** configura, **Then** copia e sai `copiado da árvore principal: <rel>`.
2. **Given** o mesmo caso sem o arquivo na árvore principal, **When** configura, **Then** não
   gera nada e avisa `mantido (ignorado pelo git)` com o caminho esperado na árvore principal.
3. **Given** checkout comum (não worktree) ou destino não ignorado, **When** configura,
   **Then** o comportamento atual não muda.
4. **Given** repositório principal bare, **When** configura na worktree, **Then** a cópia é
   recusada e o destino segue o comportamento de ausente ignorado sem origem.

## Requirements

### Functional Requirements

- **FR-001**: o `cockpit.config` aceita a chave opcional `DESTINOS_DO_PROJETO`: caminhos
  relativos à raiz do projeto, separados por espaço, iguais ao destino de algum template.
- **FR-002**: destino listado é tratado como semente existente: não é renderizado nem
  comparado e não conta como conflito, nem com `--forcar` nem no modo interativo.
- **FR-003**: a entrada anterior do destino listado no manifesto é mantida (mesma regra da
  FR-006 do modo semente).
- **FR-004**: o relatório lista cada destino listado como `mantido (projeto): <rel>`, com
  contagem própria, separada da de sementes.
- **FR-005**: destino de semente listado nunca é gerado, nem quando ausente.
- **FR-006**: item absoluto, com `..`, vazio (só aspas) ou com caractere de controle encerra com exit 1
  citando a chave, antes de qualquer escrita; item que não bate com destino de nenhum template
  gera aviso, não erro.
- **FR-007**: a chave integra as chaves opcionais: é perguntada no modo interativo (`-` para
  vazio) e gravada pelo `gravar_config` como as demais; `cockpit.config.example` e a
  documentação de uso a descrevem.
- **FR-008**: a recusa do lote por edição local permanece (FR-009 do modo semente intacta e
  contrato do exit 2 inalterado); apenas a mensagem de conflito passa a sugerir também declarar
  o destino em `DESTINOS_DO_PROJETO`.
- **FR-009**: quando o projeto é worktree vinculada (`git rev-parse --git-dir` difere de
  `--git-common-dir`) e um destino ausente de semente ou de destino do projeto é ignorado pelo
  git (`git check-ignore -q`), e o arquivo existe na árvore principal (primeira entrada de
  `git worktree list --porcelain`, recusando repositório bare), o configurador o copia de lá
  como arquivo regular (não link), sob as mesmas guardas de contenção do destino, sem entrada
  no manifesto, e reporta `copiado da árvore principal: <rel>`.
- **FR-010**: nas mesmas condições da FR-009, se o arquivo não existe na árvore principal,
  nada é gerado e o relatório avisa `mantido (ignorado pelo git)` com o caminho esperado.
- **FR-011**: fora de worktree, ou com destino não ignorado, o comportamento atual não muda.
- **FR-012**: o script escreve só dentro do projeto-alvo; a árvore principal é apenas lida.

## Edge Cases

- Lista com espaços repetidos ou nas bordas: o separador é o espaço e sequências dele não geram
  item; valor em branco equivale a chave não declarada (não é erro). O "item vazio" da FR-006 é o
  item explícito sem caminho, isto é, composto só de aspas (`""` ou `''`): exit 1 citando a chave.
- Destino listado inexistente e não semente: não é gerado (FR-002) e não gera conflito.
- Destino de cópia cujo diretório-pai não existe: o pai é criado dentro do projeto.
- Arquivo da árvore principal que é link simbólico (o arquivo ou algum componente do caminho de
  origem): a cópia é recusada sempre, sem seguir o link; o destino segue como ausente ignorado
  sem origem (`mantido (ignorado pelo git)`) e o relatório avisa o motivo. Só arquivo regular,
  fisicamente dentro da árvore principal, é copiado.
- Duas passagens seguidas: a 2a encontra o arquivo copiado já existente e o mantém.

## Success Criteria

- **SC-001**: `scripts/testar-configurar.sh` ganha um cenário para US1-US3 (D1/D2) e outro para
  US4 (D3, com worktree real e `.gitignore` cobrindo `CLAUDE.md`) e passa inteiro.
- **SC-002**: reconfigurar um projeto com um destino não-semente editado e listado não perde a
  edição e não exige `--forcar`.
- **SC-003**: o shellcheck do script não tem findings e nenhuma dependência nova é exigida.

## Fora de escopo

- Prefixos de branch fixos (`feature/<slug>` …): issue #16.
- Conflito tratado por arquivo em vez de por lote: recusado em D2.
