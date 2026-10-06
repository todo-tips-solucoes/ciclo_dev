# Contrato: passo "Conferir aprovação de dono" (delta)

Delta sobre [§require-codeowner-approval de templates-automacao](../../templates-automacao/contracts/automacao.md).
Só o que muda está marcado como **novo**; o resto é o comportamento atual, preservado (FR-006).

## Entradas

| Entrada | Origem | Mudança |
|---------|--------|---------|
| `GH_TOKEN`, `REPO`, `PR`, `BASE_SHA` | `env:` do passo | nenhuma |
| `on:` | `pull_request` (`opened`, `synchronize`, `reopened`), `pull_request_review` (`submitted`, `edited`, `dismissed`) | nenhuma |
| `permissions:` | `contents: read`, `pull-requests: read` | nenhuma ("Pull requests" read cobre Get a pull request, [research](../research.md) F5) |

## Chamadas à API, em ordem

1. `gh api -H "Accept: application/vnd.github.raw+json" "repos/$REPO/contents/.github/CODEOWNERS?ref=$BASE_SHA"` — sem mudança.
2. **novo**: `gh api "repos/$REPO/pulls/$PR" --jq .head.sha` — head do PR na hora da execução
   ([research](../research.md), Decision 2).
3. `gh api --paginate "repos/$REPO/pulls/$PR/reviews" --jq '<filtro>'` — o filtro projeta
   **também** `(.commit_id // "")` como terceira coluna do `@tsv` (Decision 3).

## Saídas

| Situação | Exit | Mensagem | Mudança |
|----------|------|----------|---------|
| Sem `.github/CODEOWNERS` na base | 1 | `::error::Não há .github/CODEOWNERS na branch base; crie o arquivo (rode o configurador do cockpit).` | nenhuma |
| Linha `*` sem `@usuario` | 1 | `::error::A linha '*' do .github/CODEOWNERS não lista nenhum dono (@usuario).` | nenhuma |
| Head do PR não lido (chamada falhou ou valor vazio) | 1 | `::error::` em pt-BR dizendo que não foi possível ler o commit head do PR — texto final na implementação | **novo** (FR-005) |
| Algum dono com último estado `approved` entre as reviews cujo `commit_id` é o head | 0 | `Aprovado por um dono.` | regra **nova** (FR-001 a FR-003); mensagem igual |
| Caso contrário (inclui aprovação só em commit anterior, aprovação seguida de pedido de mudança no head, aprovação só de não-dono, nenhuma review no head) | 1 | `::error::Aprovação pendente. Podem aprovar: @a @b` | regra **nova**; mensagem igual |

## Comentários de cabeçalho (FR-007, FR-008)

- `require-codeowner-approval.yml`: segue dizendo que o check é verificação extra e forjável, e
  que a garantia é a regra nativa da branch; a frase da garantia passa a citar "Require review from
  Code Owners" **e** "Dismiss stale pull request approvals when new commits are pushed"; uma linha
  diz que só conta aprovação feita sobre o commit atual do PR.
- `CODEOWNERS`: a linha da regra da branch passa a citar as mesmas duas opções.
- Nenhum `${{ }}` novo no template (o cenário 16 compara as expressões entre template e render).
