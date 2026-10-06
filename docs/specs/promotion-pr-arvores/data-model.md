# Data Model: PR de promoção decidido pelo conteúdo das árvores

**Feature**: `promotion-pr-arvores` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

Sem persistência: tudo vive dentro de uma execução do passo `Abrir ou atualizar o PR de promoção`
do fluxo `promotion-pr`. Nenhuma variável nova no `env:` do passo nem chave nova no
`cockpit.config`.

## Entity: Árvore do commit

| Campo | Origem | Constraints |
|-------|--------|-------------|
| SHA da árvore da produção | `commit.tree.sha` de `GET /repos/{owner}/{repo}/commits/heads/$PRODUCAO` ([research](research.md), F1 e Decision 1) | hexadecimal não vazio (senão falha, Decision 4); só comparado por igualdade |
| SHA da árvore da integração | idem, com `heads/$INTEGRACAO` | idem |

- Igualdade dos dois SHAs = mesmo conteúdo de arquivos ([research](research.md), Decision 2).
- Lidos só quando a contagem de commits à frente é positiva (Decision 3).

## Entity: PR de promoção

Sem mudança: PR único com base `$PRODUCAO` e head `$INTEGRACAO`, procurado por `gh pr list
--state open` e criado ou com o corpo reescrito (FR-008 de `templates-automacao`).

## Decisão do passo (state transitions)

Avaliada em ordem; a primeira linha que casa decide.

| # | Condição | Saída | Efeito no PR | Mensagem |
|---|----------|-------|--------------|----------|
| 1 | `$INTEGRACAO` = `$PRODUCAO` | 0 | nenhum, sem chamar o `gh` | `Integração e produção são a mesma branch: nada a promover.` (hoje) |
| 2 | commits à frente = `0` | 0 | nenhum | `A produção já contém a integração: nada a promover.` (hoje) |
| 3 | leitura de uma das árvores falha: `gh` sai ≠ 0, ou o valor lido não é hexadecimal não vazio | ≠ 0 | nenhum | erro do `gh`, ou no stderr `Não consegui ler as árvores de $PRODUCAO e $INTEGRACAO: nada promovido.` (FR-005, Decision 4) |
| 4 | árvores iguais | 0 | nenhum (PR aberto fica como está) | `Produção e integração têm o mesmo conteúdo: nada a promover.` (nova) |
| 5 | árvores diferentes, PR aberto | 0 | corpo reescrito | `PR de promoção #N atualizado.` (hoje) |
| 6 | árvores diferentes, sem PR aberto | 0 | PR criado | saída do `gh pr create` (hoje) |

Linhas 1, 2, 5 e 6 são o comportamento de hoje, sem mudança de texto; 3 e 4 são o incremento.
