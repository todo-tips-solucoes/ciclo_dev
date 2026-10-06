# Quickstart: PR de promoção decidido pelo conteúdo das árvores

**Feature**: `promotion-pr-arvores` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

Cenários de verificação. Os automatizados viram o cenário 23 de `scripts/testar-configurar.sh`,
logo antes do cenário 11 (FR-009); actionlint e shellcheck sobre o fluxo renderizado já rodam no
cenário 16 e seguem valendo (SC-004).

Preparação comum (no próprio cenário 23): o passo `run:` do `promotion-pr` já extraído pelo
cenário 16 para `$TMP/promocao.sh` (o passo não contém nome de branch, que chega pelo `env:`);
um `gh` falso no `PATH` que registra cada chamada num log e responde pelas variáveis do caso:
contagem de commits à frente, árvore da produção, árvore da integração, número do PR aberto (vazio
= nenhum) e falha simulada na leitura da árvore. `INTEGRACAO` e `PRODUCAO` diferentes; `REPO`,
`TOKEN_PADRAO` com valores de teste.

## 1. Árvores iguais, sem PR aberto (US1-1, FR-001, FR-002, SC-001)

1. `gh` falso: commits à frente `2`, as duas árvores com o mesmo SHA, nenhum PR aberto.
2. `bash "$TMP/promocao.sh"`.
→ **Expected**: exit 0; saída com `nada a promover`; o log do `gh` sem `pr create` e sem
`pr edit`.

## 2. Árvores iguais, PR aberto (US1-2, FR-002)

1. Como no 1, com PR aberto `7`.
2. Rodar o passo.
→ **Expected**: exit 0; log sem `pr create` e sem `pr edit` (o PR existente não é tocado).

## 3. Árvores diferentes, sem PR aberto (US2-1, FR-003, SC-002)

1. `gh` falso: commits à frente `2`, árvores com SHAs diferentes, nenhum PR aberto.
2. Rodar o passo.
→ **Expected**: exit 0; log com exatamente um `pr create` e nenhum `pr edit`.

## 4. Árvores diferentes, PR aberto (US2-2, FR-003, SC-002)

1. Como no 3, com PR aberto `7`.
2. Rodar o passo.
→ **Expected**: exit 0; log com `pr edit 7` e sem `pr create`.

## 5. Falha na leitura da árvore (edge case, FR-005)

1. Como no 3, em duas variantes: (a) o `gh` falso sai `1` na leitura de uma árvore; (b) sai `0`
   e imprime `null` na leitura de uma árvore (resposta sem o campo, [research](research.md),
   Decision 4).
2. Rodar o passo em cada variante.
→ **Expected**: nas duas, exit diferente de 0; log sem `pr create` e sem `pr edit`.

## 6. Cabeçalho do template (US3-1, FR-006)

1. Ler as primeiras linhas de comentário de `templates/.github/workflows/promotion-pr.yml.tmpl`.
→ **Expected**: citam a promoção por merge commit (Fase 9 do `rito-dev`) e que, com squash, o
fluxo não reabre o PR quando o conteúdo já é igual. No cenário 23, um `grep` por `merge commit`
no template.

## 7. Branch única e regressões (FR-004, SC-003, SC-004)

- Integração = produção sai 0 sem chamar o `gh`: coberto pelo cenário 16, sem mudança.
- actionlint (com shellcheck embutido) sem findings sobre o fluxo renderizado: cenário 16.
- Suíte inteira verde: `scripts/testar-configurar.sh` termina com `OK: todos os cenários
  passaram.`

Manual (PR): nenhum. O comportamento real da API é o documentado na [research](research.md);
o cenário 23 cobre a decisão do passo com `gh` falso, sem rede (padrão do cenário 16).
