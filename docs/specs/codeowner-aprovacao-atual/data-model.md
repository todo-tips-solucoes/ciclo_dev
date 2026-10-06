# Data Model: aprovação de dono sobre o commit atual

**Feature**: `codeowner-aprovacao-atual` | **Date**: 2026-10-06

Fluxo sem estado: nada é gravado. As entidades abaixo são os dados que o passo "Conferir aprovação
de dono" lê a cada execução. Fontes dos campos externos em [research](research.md) (F1 a F6).

## Entity: Review

Item da lista devolvida por "List reviews for a pull request" (REST), lida com
`gh api --paginate "repos/$REPO/pulls/$PR/reviews"`.

| Campo | Tipo | Uso no fluxo | Fonte |
|-------|------|--------------|-------|
| `user.login` | texto | chave do último estado por usuário, comparada sem diferenciar maiúsculas | F4 (já usado) |
| `state` | texto | `APPROVED` aprova; `COMMENTED`/`PENDING` ignorados; qualquer outro valor substitui o anterior e não aprova | F4 (já usado) |
| `commit_id` | texto (SHA) | **novo**: a review só entra no cálculo se `commit_id` for igual ao head do PR | F4 |

Ordem: a lista vem em ordem cronológica (F4), por isso "último estado" é a última linha do usuário.

## Entity: Head do PR

| Campo | Tipo | Uso no fluxo | Fonte |
|-------|------|--------------|-------|
| `sha` do commit head do PR | texto (SHA) | referência que filtra as reviews; vazio = falha, nunca aprovação | [research](research.md), Decision 2 |

## Entity: Dono

Sem mudança: `@usuario` da linha `*` do `.github/CODEOWNERS` lido na base do PR, em minúsculas.

## Regra do veredito

1. Head vazio → falha ("::error::" acionável), sem olhar reviews (FR-005).
2. Reviews com `state` diferente de `COMMENTED`/`PENDING` e `commit_id` igual ao head, em ordem;
   por usuário vale a última (FR-001, FR-002).
3. Aprovado = algum dono cujo último estado sobre o head é `approved` → exit 0, "Aprovado por um
   dono." (FR-002).
4. Senão → exit 1, "Aprovação pendente. Podem aprovar: @a @b" (FR-003, FR-004, FR-006).

Review sem `commit_id` (campo ausente ou nulo) nunca é igual a um head não vazio, logo não conta.

## State transitions

Não se aplica: cada execução recalcula o veredito do zero. Push novo muda o head; reviews antigas
deixam de casar com ele, e o check fica pendente até uma review nova de dono (FR-004, SC-002).
