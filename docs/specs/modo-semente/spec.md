# Feature Specification: modo semente no configurar.sh

**Feature**: `modo-semente`
**Created**: 2026-10-01
**Status**: Draft
**Origem**: issue #5 (follow-up do code review de `templates-governanca`, "Decisão do owner").

> Decisões de infraestrutura: N/A (script shell local, sem scheduler, sessão, chave
> criptográfica, multi-réplica ou retry).

## Problema

`configurar.sh` recusa o lote inteiro quando um destino foi editado à mão (exit 2, nada é
gravado) e só `--forcar` sobrescreve, perdendo a edição. Isso atinge arquivos que o projeto-alvo
é feito para editar: `docs/constitution.md` (princípios próprios), `docs/project-context.md`
(seções "A preencher") e um `CLAUDE.md` que o projeto já tinha antes do cockpit.

## User Scenarios & Testing

### User Story 1 - Arquivo semente é criado uma vez e nunca mais tocado (Priority: P1)

Quem configura o projeto roda o configurador. Os templates marcados como semente geram o
arquivo só se o destino não existe; se existe, ficam intactos, com aviso, e o resto do lote é
renderizado normalmente.

**Independent Test**: num projeto-alvo temporário com `CLAUDE.md` próprio, rodar o
configurador; conferir que `CLAUDE.md` mantém o conteúdo original byte a byte, que os demais
templates foram gravados e que o exit é 0.

**Acceptance Scenarios**:
1. **Given** destino de semente inexistente, **When** configura, **Then** é renderizado e gravado.
2. **Given** destino de semente existente (editado ou não), **When** configura, **Then** não é
   alterado e a saída diz que foi mantido.
3. **Given** destino de semente existente, **When** roda com `--forcar`, **Then** continua
   intacto (semente nunca é sobrescrita).
4. **Given** semente existente e outro template (não semente) editado à mão, **When** configura,
   **Then** vale a regra atual para o não semente (recusa o lote); a semente existente não entra
   na lista de conflitos.

### User Story 2 - Re-render com `--atualizar` não recusa por causa de semente (Priority: P1)

Após o dono editar `constitution.md`, `--atualizar` não deve mais falhar por causa dele.

**Acceptance Scenarios**:
1. **Given** semente editada e demais templates sem edição local, **When** `--atualizar`,
   **Then** exit 0 e semente intacta.

### User Story 3 - Marcar um template como semente é declarativo (Priority: P2)

Quem mantém o cockpit marca um template como semente só pelo nome do arquivo.

**Acceptance Scenarios**:
1. **Given** `templates/docs/constitution.md.semente.tmpl`, **Then** o destino é
   `docs/constitution.md` (o sufixo `.semente.tmpl` sai inteiro).

## Requirements

- **FR-001**: template cujo nome termina em `.semente.tmpl` é semente; o destino é o caminho
  sem esse sufixo.
- **FR-002**: semente é renderizada e gravada somente se o destino não existe (`-e` nem
  link simbólico quebrado); se existe, é pulada sem leitura de conteúdo, sem comparação e
  sem consulta ao manifesto.
- **FR-003**: semente existente nunca conta como conflito de edição local, nem sob `--forcar`
  nem em modo interativo (sem prompt de sobrescrita).
- **FR-004**: placeholder sem valor numa semente é tratado como nos demais templates, mas só
  quando a semente será de fato gravada; semente pulada não renderiza nem acusa residual.
- **FR-005**: destinos de semente passam pelas mesmas guardas de caminho dos demais (destino
  reservado, `..`, contenção na raiz do projeto, destinos duplicados incluindo a colisão
  `X.tmpl` x `X.semente.tmpl`).
- **FR-006**: semente gravada recebe hash no manifesto como qualquer destino gerado; semente
  pulada não entra nem sai do manifesto (entrada anterior é mantida).
- **FR-007**: o relatório final lista as sementes mantidas (`mantido (semente): <rel>`) e a
  contagem as separa de gravados/inalterados.
- **FR-008**: os templates `docs/constitution.md`, `docs/project-context.md` e `CLAUDE.md`
  passam a ser sementes; os demais ficam como estão. O texto dos templates e a documentação
  (README, `.cockpit/LEIAME.md`, usage) deixam de dizer que o `--forcar` é o caminho para
  recuperar esses três arquivos.
- **FR-009**: nenhum comportamento de não-semente muda (recusa do lote por edição local,
  `--forcar`, interativo).

## Edge Cases

- Semente existente como diretório ou link quebrado: tratada como "existe", pulada (a guarda de
  contenção continua valendo só para o que será gravado).
- Duas passagens seguidas: a 1a grava, a 2a mantém — idempotente.
- Template semente removido do cockpit depois de gravado: segue a regra de órfã atual do manifesto.

## Success Criteria

- **SC-001**: `scripts/testar-configurar.sh` cobre os cenários 1-4 de US1, o de US2 e a colisão
  de FR-005, e passa inteiro.
- **SC-002**: reconfigurar um projeto com os 3 arquivos editados à mão não perde nenhuma edição
  e não exige `--forcar`.

## Fora de escopo

- Marcação por arquivo de lista ou front-matter.
- Mesclar/atualizar o conteúdo de uma semente existente.
- Mudar a recusa de lote para não-semente.
