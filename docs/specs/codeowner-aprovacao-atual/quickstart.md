# Quickstart: aprovação de dono sobre o commit atual

Cenários de verificação. Os automatizados viram o cenário 22 de `scripts/testar-configurar.sh`;
os manuais ficam registrados na PR.

Preparação comum (cenário 22): projeto renderizado com o `cockpit.config.example`; o `run:` do
passo "Conferir aprovação de dono" extraído de `.github/workflows/require-codeowner-approval.yml`
com o `awk` do cenário 16; `gh` falso no início do `PATH` que responde:

- conteúdo do CODEOWNERS → `* @maria-exemplo @jose-exemplo`;
- `repos/<repo>/pulls/<n>` com `--jq .head.sha` → o valor da variável do caso (`HEAD_ATUAL`);
- `repos/<repo>/pulls/<n>/reviews` com `--jq <programa>` → `jq -r "<programa>"` sobre a fixture
  JSON do caso.

Execução: `env PATH="<ghfalso>:$PATH" REPO=org-exemplo/repo PR=1 BASE_SHA=<sha> bash <passo>`.
Sem `jq` na máquina, o cenário é pulado com aviso; no CI (`COCKPIT_EXIGIR_FERRAMENTAS=1`), falha.

SHAs fictícios: `A` = commit anterior, `H` = head atual (40 caracteres hexadecimais cada).

## 1. Aprovação de dono no head conta (US1-1, US3-1, FR-001, FR-002)

Fixture: `maria-exemplo` `APPROVED` em `H`.
→ **Expected**: exit 0, stdout `Aprovado por um dono.`

## 2. Aprovação em commit anterior não conta (US1-2, US1-4, FR-003, FR-004, SC-002)

Fixture: `maria-exemplo` `APPROVED` em `A`; `fulano-exemplo` (não dono) `APPROVED` em `H`.
→ **Expected**: exit 1, saída com `Aprovação pendente. Podem aprovar: @maria-exemplo @jose-exemplo`.

## 3. Aprovação seguida de pedido de mudança no head não conta (US1-3, FR-002)

Fixture, em ordem: `maria-exemplo` `APPROVED` em `H`; `maria-exemplo` `CHANGES_REQUESTED` em `H`.
→ **Expected**: exit 1, `Aprovação pendente`.

## 4. Head não lido falha (FR-005, Edge Case)

`HEAD_ATUAL` vazio, fixture do caso 1.
→ **Expected**: exit 1 com `::error::` sobre o head do PR; nunca `Aprovado por um dono.`

## 5. Regressão (US3-2) — manual, na PR

Reverter só o template do fluxo para `main` e rodar `./scripts/testar-configurar.sh`.
→ **Expected**: o cenário 22 falha (o caso 2 sai 0 com o filtro antigo).

## 6. Comentários (US2, FR-007, SC-003) — cenário 22

Nos arquivos renderizados `.github/workflows/require-codeowner-approval.yml` e
`.github/CODEOWNERS`:
→ **Expected**: cada um contém `Require review from Code Owners` e
`Dismiss stale pull request approvals when new commits are pushed`.

## 7. CI existente (SC-004)

`./scripts/testar-configurar.sh` completo: cenários 16 (actionlint, `${{ }}` intactos) e 11
(shellcheck, `verificar-agnostico.sh`) verdes.
