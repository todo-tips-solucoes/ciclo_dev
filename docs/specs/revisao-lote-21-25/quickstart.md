# Quickstart: correções do code review retroativo do lote 21-25

**Feature**: `revisao-lote-21-25` | **Date**: 2026-10-08

Tudo roda em `scripts/testar-configurar.sh`, sem rede, com os `gh` e `cstk` falsos de hoje. Cada
caso abaixo entra num cenário existente (21 a 24), sem número de cenário novo. Execução:
`bash scripts/testar-configurar.sh` → **Expected**: `OK: todos os cenários passaram.` e exit 0.
No CI (`COCKPIT_EXIGIR_FERRAMENTAS=1`) shellcheck, actionlint e `jq` são obrigatórios.

## Cenário 24 — regras ilegíveis e chamada de issues (US1, FR-001, FR-010)

0. O bloco inteiro fica sob a guarda de `jq` do cenário 22 → sem `jq` fora do CI: aviso e pula; no
   CI: falha "jq ausente no CI".
1. Todos os casos de hoje (1 a 4) seguem passando com o `gh` falso que exige `--paginate` e
   `state=all` na rota de issues → **Expected**: inalterado.
2. Mutação de prova: com uma chamada de issues sem `--paginate` ou sem `state=all`, o `gh` falso sai
   com código próprio → **Expected**: o caso falha (conferido uma vez na implementação, revertendo
   a chamada localmente; não fica no script).
3. Regras ilegíveis: ligar a variável que faz a rota de regras imprimir
   um corpo JSON de erro no stdout (fixture ilustrativa, por exemplo `{"message":"Not Found"}`; M1
   só garante um corpo JSON no stdout com exit 1) e sair com 1; checks `ci` e `lint` vermelhos;
   nenhuma issue de mesmo título → **Expected**: exit 0, `issue create` no log, corpo com `- ci` e
   `- lint` e a nota "Sem regra de checks obrigatórios legível"; com o `|| true` de hoje o passo
   sairia com "nada a auditar" (o caso falha).

## Cenário 22 — último estado por usuário e head (US2, FR-002)

Casos de hoje (1 a 5) seguem. `H` = head, `A` = commit antigo; `Maria-Exemplo` é dona, um segundo
login fictício não é dono.

1. `approved@H` → `changes_requested@A` (Maria) → **Expected**: exit 1, "Aprovação pendente".
2. `approved@A` (Maria) e `approved@H` (não dono) → **Expected**: exit 1, "Aprovação pendente".
3. `approved@A` → `approved@H` (Maria) → **Expected**: exit 0, "Aprovado por um dono.".
4. `approved@H` → `dismissed@H` (Maria) → **Expected**: exit 1.
5. `approved` com `commit_id` nulo (Maria) e head `H` → **Expected**: exit 1.
6. A rota `pulls/<n>` do `gh` falso sai com 1 → **Expected**: exit 1 com `::error::`.

## Cenário 21 — branches e manifesto (US6, FR-010)

1. Valores recusados (lista única para os casos 1 e 3b): `main;curl x`, `$(x)`, `` `x` ``, `a|b`,
   `a b`, `a..b`, `x.lock`, `a/`, `-x`, `.x`, `/x`, `á`, nas duas chaves.
2. Caso 1 (`--respostas`) → **Expected**: exit 1; stderr com a chave e o conjunto; o repositório
   continua sem nenhum arquivo fora de `.git` (nem `cockpit.config`, nem modelo, nem `.cockpit/`);
   o log do `cstk` falso sem `hooks install` desta execução.
3. Caso 3b (`--atualizar`) → **Expected**: exit 1; stderr com chave, conjunto, a dica de renomear a
   branch no remoto e "Corrija o valor no cockpit.config"; `cockpit.config` e manifesto byte a byte
   iguais.
4. Caso 4 (interativo, pty) → **Expected**: o tty mostra "Valor inválido para BRANCH_INTEGRACAO" e o
   conjunto, e o valor final gravado é `dev` (hoje).
5. Manifesto anterior que ficaria vazio: configurar com o exemplo; trocar o manifesto por uma linha
   de um arquivo que não existe; rodar com todos os destinos em `DESTINOS_DO_PROJETO` →
   **Expected**: exit 0; `.cockpit/manifesto.sha256` existe e está vazio.

## Cenário 23 — cabeçalho do promotion-pr (FR-010)

1. Caso 6: só nas linhas antes de `name:` do modelo → **Expected**: há "merge commit" e "Fase 9 do
   rito-dev"; há "squash" e a afirmação de que o fluxo não abre nem reabre o PR quando o conteúdo já
   é igual.

## Leituras sem teste automático (US3, US4, US5)

1. `skills/rito-dev/SKILL.md` com `cockpit.config` de exemplo `BRANCH_INTEGRACAO='main'`,
   `REPO_REMOTO='minha-org/meu-projeto'` → **Expected**: o texto manda tirar as aspas antes de
   conferir; `main` e `minha-org/meu-projeto` passam.
2. Mesma leitura com `REPO_REMOTO='minha-org/..'` → **Expected**: a skill PARA nomeando
   `REPO_REMOTO`, sem compor comando.
3. `skills/parallel-work/SKILL.md` com `BRANCH_PRODUCAO='release/2026'` e com
   `BRANCH_INTEGRACAO='a b'` → **Expected**: o primeiro vira `--base origin/release/2026`; o
   segundo PARA nomeando a chave.
4. Modelos `require-codeowner-approval` e `CODEOWNERS`, comentário `ponytail:`, contrato e research
   das frentes de origem → **Expected**: textos de research Decision 6, sem afirmação sem fonte.
5. `./scripts/verificar-agnostico.sh` → **Expected**: zero ocorrências.
