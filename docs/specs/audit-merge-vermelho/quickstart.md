# Quickstart: audit-merge-vermelho

**Feature**: `audit-merge-vermelho` | **Date**: 2026-10-06

Os casos abaixo viram o cenário **24** de `scripts/testar-configurar.sh`, inserido logo antes do
cenário 11, no padrão do cenário 16: renderiza o cockpit num repositório temporário, extrai o
bloco `run:` do passo "Registrar merge com check vermelho" do
`.github/workflows/audit-merge-vermelho.yml` renderizado e o executa com `bash` e um `gh` falso
à frente do `PATH`. Sem rede.

## `gh` falso do cenário 24

- Registra cada chamada (`$*`) num log do cenário.
- `gh api <rota> ... --jq <filtro>`: escolhe a fixture JSON pela rota e aplica o **filtro
  recebido** com `jq -r` (o `TITULO` exportado pelo passo fica no ambiente, como no `--jq` do
  `gh`). Na rota de issues, emula `--paginate` aplicando o filtro a cada página em sequência.
- `gh issue create ... --body-file <arquivo>`: copia o corpo para o diretório do cenário e
  registra a criação.
- Qualquer outro subcomando (inclusive `gh issue list`): sai 64, como o `cstk` falso do script.
- Variável de controle para simular falha da listagem de issues (exit diferente de zero).

Fixtures mínimas: check-runs com `ci` e `opcional` em `failure`; status sem falhas; regras com
`required_status_checks` contendo só `ci`; páginas de issues por caso.

## Caso 1: base com barra consulta as regras dela (US1, FR-001, FR-002, SC-001)

1. Páginas de issues: página 1 com um PR (chave `pull_request`) de título idêntico e uma issue
   de título parecido (`Auditoria: PR #4 mergeado com check vermelho`); página 2 vazia de
   coincidências.
2. Rodar o passo com `PR=42`, `BASE=release/2026`.
3. **Expected**: exit 0; o log tem a rota `repos/<REPO>/rules/branches/release%2F2026`; o log tem
   `issue create`; o corpo lista `- ci`, não lista `opcional` e traz "Lista filtrada pelos
   checks obrigatórios da branch base." (US2 cenário 2: título parecido e PR de mesmo título não
   impedem a criação).

## Caso 2: issue de mesmo título além da primeira página (US2, FR-004, FR-005, FR-006, SC-002)

1. Páginas de issues: página 1 sem coincidência; página 2 com issue **fechada** de título
   idêntico `Auditoria: PR #42 mergeado com check vermelho`.
2. Rodar o passo com `PR=42`, `BASE=main`.
3. **Expected**: exit 0; saída com "Já existe issue de auditoria para o PR #42."; nenhuma linha
   `issue create` no log; a rota de regras é `rules/branches/main`, igual à de hoje (FR-003);
   nenhuma chamada a `issue list` (a busca por índice saiu).

## Caso 3: caracteres além de `/` (Edge Cases)

1. Mesmas páginas do caso 2.
2. Rodar o passo com `BASE='feat/ação+1#x'`.
3. **Expected**: o log tem `rules/branches/feat%2Fa%C3%A7%C3%A3o%2B1%23x` (bytes UTF-8 em
   `%XX` maiúsculo; valor conferido contra `jq @uri` na research, Decision 1).

## Caso 4: listagem de issues falha (FR-010)

1. `gh` falso com a falha da listagem ligada.
2. Rodar o passo com `BASE=main`.
3. **Expected**: exit diferente de zero; nenhuma linha `issue create` no log.

## Qualidade estática (FR-008, SC-003)

O cenário 16 já roda `actionlint` (com shellcheck embutido) sobre os fluxos renderizados com os
valores do exemplo, e o cenário 11 roda `shellcheck` sobre `scripts/testar-configurar.sh`. No CI
(`COCKPIT_EXIGIR_FERRAMENTAS=1`) a ausência das ferramentas é falha. Nada novo a acrescentar.

**Expected**: `./scripts/testar-configurar.sh` termina com "OK: todos os cenários passaram." e o
job `configurar` do CI fica verde.
