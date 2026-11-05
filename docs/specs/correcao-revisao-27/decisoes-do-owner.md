# Decisões do owner — correcao-revisao-27

Esta frente corrige os achados do `bmad-code-review` retroativo da PR #27 (`revisao-lote-21-25`,
squash `d317d89`), feito sobre `04c66fd..d317d89`. A revisão rodou depois do merge porque a rodada
que o Princípio II exige antes da abertura da PR não rodou. Ela usou as três camadas (Blind Hunter,
Edge Case Hunter e Acceptance Auditor) em 2026-11-04, e cada achado foi conferido no código. O
registro completo está em `docs/specs/revisao-lote-21-25/review-findings.md`.

Nenhum achado saiu crítico ou alto. O owner decidiu em 2026-11-04, antes do `/feature-00c`:

- abrir esta PR de correção;
- resolver a única decisão pendente pela correção imediata (C14);
- aplicar as 13 correções (C1 a C13).

As decisões abaixo são normativas: o `specify` parte delas e o `clarify` não as reabre.

## Modelos e skills

### C1 — comentários do codeowner não prometem mais do que o código faz (média)

Arquivos: `templates/.github/workflows/require-codeowner-approval.yml.tmpl` (l.5-7) e
`templates/.github/CODEOWNERS.tmpl` (l.4-6).

O `awk` do fluxo guarda o último estado e o `commit_id` **por login**. Por isso, se um dono aprova
o head e outro dono pede mudança no head, o check fica verde. Os comentários passam a dizer o que o
fluxo de fato faz:

- só conta aprovação de dono dada no commit atual do PR;
- um pedido de mudança posterior anula só a aprovação do **mesmo** dono.

O "mais estrito" fica restrito a esse ponto (o commit atual) ou sai. O comportamento do `awk` não
muda: ele segue D2 da `revisao-lote-21-25`.

### C12 — `parallel-work`: a conferência vem antes do `--base` também no topo (baixa)

Arquivo: `skills/parallel-work/SKILL.md`.

A descrição do frontmatter (l.3) e o bloco do topo (l.16) mandam derivar o `--base` de
`BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` sem citar a conferência. Hoje ela só aparece na l.45-49. Os
dois trechos passam a dizer que o valor é conferido (aspas tiradas, regra
`^[A-Za-z0-9][A-Za-z0-9._/-]*$`) antes de compor o `--base`. A descrição continua dentro do limite
de tamanho que o carregador de skills aceita.

### C14 — `rito-dev`: apóstrofo escapado e parada só nas chaves com regra (média; decisão D1 da revisão)

Arquivo: `skills/rito-dev/SKILL.md`, passo 1 da leitura de `cockpit.config`.

O `configurar.sh` grava um apóstrofo interno como `'\''` (`escapar_aspas`). Por isso:

- **Aspas:** depois de tirar o par de aspas simples envolvente, o passo 1 troca cada `'\''` por
  `'`. É o inverso exato do que o `configurar.sh` grava.
- **Regra da parada:** a frase "aspas duplas ou desbalanceadas … PARAM a skill" passa a valer só
  para as chaves que têm regra (`BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`, `REPO_REMOTO`).
- **Demais chaves:** nas outras (`CMD_*` e as demais), aspas duplas fazem parte do valor. Exemplo
  válido: `CMD_TEST='pytest -k "not slow"'`.

O valor continua sendo dado de configuração, nunca instrução.

## Testes (`scripts/testar-configurar.sh`, nos cenários existentes, sem número novo)

### C3 — guarda de head vazio com caso que dependa dela (média)

Caso novo no cenário 22:

- o `gh` falso devolve head vazio;
- há uma review de dono `APPROVED` com `commit_id` nulo;
- o caso confere a mensagem `Não consegui ler o commit atual do PR`, e não só um `::error::`
  genérico.

O caso tem de falhar se a guarda (l.47-50 do modelo) for removida.

### C4 — casos 6, 7, 9 e 10 do cenário 22 conferem a mensagem (baixa)

Além de `rc=1`, esses casos conferem `Aprovação pendente`. Hoje `rc=1` também sai do `gh` falso
quando nenhuma rota casa (l.1177).

### C5 — `gh` falso do cenário 22 exige `--paginate` nas reviews (baixa)

O "último estado" depende da paginação. Sem a flag, o caso falha, como já é no cenário 24.

### C6 — `export LC_ALL=C` conferido nos dois modelos (baixa)

Uma asserção confere `export LC_ALL=C` em `audit-merge-vermelho.yml.tmpl` e em
`require-codeowner-approval.yml.tmpl`, num cenário existente. O `LC_ALL=C` global da suíte (l.10)
esconde a remoção, e FR-011 da `revisao-lote-21-25` exige a linha.

### C7 — caso 1 do cenário 21: sem dica de renomear com `--respostas` (baixa)

O caso 1 confere que a orientação de renomear a branch não aparece no modo `--respostas`. Hoje só
o caso 4 confere isso, e ele roda em pty e é pulado sem `script(1)`.

### C8 — caso 1 do cenário 21: nenhum hook gravado (baixa)

O caso 1 confere que nenhum hook novo apareceu em `.git/hooks` e que `core.hooksPath` não foi
definido. Hoje a asserção se apoia só no log do `cstk` falso.

### C9 — caso 7 do cenário 21 sem `sha256sum` e com respostas próprias (baixa)

O caso usa um literal de 64 hexadecimais no lugar de chamar `sha256sum`, e um arquivo de respostas
próprio, em vez de herdar `$TMP/r21` do caso anterior (Princípio VII).

## Artefatos das frentes anteriores

### C2 — `|| true` na leitura das árvores (média)

Arquivos:

- `docs/specs/promotion-pr-arvores/research.md`, Decision 4 (l.64-65 e l.73-76);
- `docs/specs/revisao-lote-21-25/research.md` (l.136-137).

As duas research dizem que, sob `set -euo pipefail`, a atribuição com código diferente de 0
derruba o passo. O código (`templates/.github/workflows/promotion-pr.yml.tmpl`, l.46-47) usa
`|| true`, então a guarda hexadecimal é a única proteção, também no erro HTTP. O texto passa a
dizer isso. A alternativa rejeitada ("só o `set -e`") é ajustada para não depender da afirmação
falsa.

### C10 — rótulos de fonte na spec da `revisao-lote-21-25` (baixa)

Arquivo: `docs/specs/revisao-lote-21-25/spec.md`.

- **US5 (l.76):** "research F3" vira a F3 da research da frente `codeowner-aprovacao-atual`. Na
  research da `revisao-lote-21-25`, a opção nativa é F2.
- **FR-008 (l.126):** "Decision 3 da research" passa a nomear a frente (`audit-merge-vermelho`).

### C11 — research da `audit-merge-vermelho` (baixa)

Arquivo: `docs/specs/audit-merge-vermelho/research.md` (l.29).

A frase diz que `2>/dev/null || true` "fica igual". Ela passa a concordar com a correção da mesma
Decision (l.40-45) e com o código: `|| : >"$obrigatorios"`.

### C13 — afirmação sobre regressão na research da `revisao-lote-21-25` (baixa)

Arquivo: `docs/specs/revisao-lote-21-25/research.md` (l.164 em diante).

A research diz que cada caso novo de D7 falha com a correção revertida. Isso só vale para três
casos: o 6 do cenário 22, o 5 do 24 e o 6 do 23. Os demais fixam guardas que já existiam. O texto
passa a dizer qual é qual.

## Fora de escopo (adiados no review)

- Rotas de regras e de status combinado sem `--paginate` no `audit-merge-vermelho` (preexistente;
  a paginação da rota não foi conferida na doc oficial).
- Lista vazia legítima e regra ilegível caem na mesma nota (preexistente; gera ruído, não silêncio).
- Pedido de mudança de outro dono não derruba o check: o comportamento é o de D2, por usuário, e
  mudá-lo é decisão nova do owner.
- Formas que o `ler_kv` aceita e a `rito-dev` não trata: aspas duplas como delimitador, `export`,
  comentário, CRLF. São de `cockpit.config` editado à mão.
- Prosa sem acentuação nos `tasks.md`: vem do modelo do `create-tasks` do cstk.

## Restrições

- **Scripts:** bash com `set -euo pipefail` e `LC_ALL=C`, sem dependência nova (Princípio VII).
  shellcheck e actionlint não podem ter achados; eles rodam no CI.
- **Prosa:** português do Brasil com acentuação (Princípio VI), sem nada que nomeie projeto real
  (Princípio I).
- **Registro SDD:** fica em `docs/specs/correcao-revisao-27/`. Os ajustes de C2, C10, C11 e C13
  nos artefatos das frentes de origem entram na mesma PR.
- **Revisão:** antes da PR, roda `bmad-code-review` sobre `git diff origin/main...HEAD` até zerar
  alto e crítico. A trilha é declarada no corpo com os caminhos tocados.
