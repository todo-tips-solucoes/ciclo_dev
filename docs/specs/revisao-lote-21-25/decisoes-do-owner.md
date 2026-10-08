# Decisões do owner — revisao-lote-21-25

Frente de correção dos achados do `bmad-code-review` retroativo sobre o lote já mergeado em
`main` (`09f7cb0..04c66fd`, PRs #21 a #25, issues #7, #8, #9, #10, #18 e #19). A revisão rodou
as três camadas (Blind Hunter, Edge Case Hunter e Acceptance Auditor) em 2026-10-08, sobre o
diff de código; os achados foram conferidos no código e, onde dependiam da API do GitHub, por
leituras GET. As decisões abaixo foram tomadas pelo owner em 2026-10-08, antes do
`/feature-00c`, e são normativas: o `specify` parte delas e o `clarify` não as reabre.

## Fatos medidos (fonte para a research)

Medidos em 2026-10-08 com `gh version 2.88.1`, só leitura:

- Em resposta HTTP de erro (404 numa rota `rules/branches/…` de repositório inexistente), o
  `gh api` com `--jq` grava no **stdout** o corpo JSON do erro, sem filtrar, e sai com 1.
- `repos/<o>/<r>/commits/heads/<branch com />` devolve o mesmo `commit.tree.sha` com o nome cru,
  com `/` codificado como `%2F` e pela rota `branches/<branch>` (repositório público, branch
  cujo nome tem `/`).
- `repos/<o>/<r>/rules/branches/<branch com />` responde 200 com `[]` tanto cru quanto com
  `%2F`, numa branch sem regra. Não decide se o nome cru casa as regras de uma branch que as
  tem: segue **não medido**.

## D1 — audit-merge-vermelho: falha na leitura das regras nunca filtra (alta)

- Se a consulta das regras da branch base sai com código diferente de 0, a saída é descartada e
  o fluxo segue como "sem regra de checks obrigatórios legível": lista **todos** os checks
  vermelhos, com a nota correspondente. O stdout de uma chamada que falhou nunca é usado como
  lista de checks obrigatórios.
- Hoje o JSON do erro vira a lista, o filtro esvazia os vermelhos e o fluxo sai com "nada a
  auditar": o merge vermelho fica sem auditoria (fail-open). A afirmação da research da frente
  `audit-merge-vermelho` (Decision 1) de que a falha "cai no aviso de regra ilegível" é corrigida.

## D2 — require-codeowner-approval: último estado por usuário, depois o head (média)

- O fluxo pega o último estado de cada usuário em **todas** as reviews, em ordem cronológica, e
  só conta aprovação de dono quando esse último estado é `approved` **e** a review que o deu tem
  `commit_id` igual ao head atual do PR.
- Corrige a regressão da PR #25: um pedido de mudança enviado depois da aprovação, mas preso a um
  commit antigo, voltou a anular a aprovação, como antes.

## D3 — rito-dev: aspas antes da conferência (média)

- `skills/rito-dev/SKILL.md` manda remover o par de aspas simples envolvente **antes** de
  conferir os valores. Hoje a conferência vem antes e, seguida à letra, recusa todo
  `cockpit.config` válido (`'main'` não casa com a regra).

## D4 — rito-dev confere também `REPO_REMOTO`

- A skill aplica a `REPO_REMOTO` a mesma regra que o `configurar.sh` usa (`RE_REPO`:
  `^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$`, sem `.` ou `..` como parte),
  depois de tirar as aspas e antes de compor qualquer comando. Fora da regra, PARA e nomeia a
  chave, sem colar o valor num comando para testá-lo.

## D5 — parallel-work confere as branches antes do `--base`

- `skills/parallel-work/SKILL.md` (a cópia versionada) aplica a `BRANCH_INTEGRACAO` e
  `BRANCH_PRODUCAO` a regra da #19 (`^[A-Za-z0-9][A-Za-z0-9._/-]*$`), depois de tirar as aspas e
  antes de compor o `--base`. Fora da regra, PARA e nomeia a chave.

## D6 — mensagens e comentários

- `configurar.sh`, `--atualizar` com `BRANCH_*` fora da regra: o fail-closed continua; a
  mensagem passa a dizer também que, se o valor é o nome real da branch, a saída é renomear a
  branch no remoto.
- `require-codeowner-approval.yml.tmpl` e `CODEOWNERS.tmpl`: o texto sobre a opção nativa
  ("Dismiss stale pull request approvals when new commits are pushed") diz que ela descarta
  aprovações quando entra commit que altera o diff do PR (research F3), e que o check do fluxo é
  mais estrito.
- `audit-merge-vermelho.yml.tmpl`: o comentário `ponytail:` segue a research Decision 3 (`since`
  ou `creator`, e mudar o filtro exige nova decisão do owner, porque altera a regra de D2 daquela
  frente). O contrato `contracts/github-rest.md` da frente passa a citar o filtro jq que o código
  usa (`has("pull_request") | not`).
- A research das frentes `promotion-pr-arvores` e `audit-merge-vermelho` registra os fatos
  medidos acima, no lugar das afirmações sem fonte.

## D7 — testes

Nos cenários existentes de `scripts/testar-configurar.sh`, sem número novo:

- **24**: o `gh` falso exige `--paginate` e `state=all` (sem eles, o caso falha); guarda de `jq`
  igual à do 22; caso novo em que a rota de regras devolve corpo de erro no stdout com exit 1, e a
  issue lista todos os vermelhos com a nota de regra ilegível.
- **22**: pedido de mudança posterior preso a commit antigo anula a aprovação no head; dono
  aprova commit antigo e não dono aprova o head (US1-4); reaprovação no head conta; review
  `DISMISSED`; `commit_id` nulo; falha do `gh` ao ler o head.
- **21**: valores que a regex aceita e o git recusa (`a..b`, `x.lock`, `a/`); primeiro caractere
  `-x`, `.x`, `/x` e não ASCII (`á`); o caso 4 confere a mensagem de erro no tty; manifesto
  anterior que ficaria vazio; o caso 1 confere que nenhum `cockpit.config`, template, manifesto
  ou hook foi gravado; o 3b confere a mensagem para todos os valores recusados.
- **23**: o caso 6 confere as duas afirmações de D2 da frente `promotion-pr-arvores` no
  cabeçalho.

## Fora de escopo (adiados no review)

- Limite de linha do rodapé do commitlint (fora de escopo por decisão anterior do owner).
- Custo da varredura de issues do `audit-merge-vermelho`, que cresce com o repositório.
- PR de promoção que continua aberto quando as árvores ficam iguais.
- `promotion-pr`: primeira execução sem a branch de produção e `.commits[:50]` com squash
  (preexistentes).
- Endpoint de commits mais pesado que o necessário no `promotion-pr` (funcional, medido acima).
- Head do PR lido da API e não do payload do evento (teórico).
- Skills aplicando só a regex, sem as regras de nome do git (`a..b` não abre injeção).
- A disputa entre a `parallel-work` instalada em `~/.claude/skills/` e a de outro projeto: issue
  própria.

## Restrições

- bash com `set -euo pipefail`, shellcheck e actionlint sem findings (rodam no CI), `LC_ALL=C`,
  nenhuma dependência nova (Princípio VII).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I); comportamento de API citado com fonte oficial ou medição registrada.
- Registro SDD em `docs/specs/revisao-lote-21-25/`; os ajustes de D6 nos artefatos das frentes
  de origem entram na mesma PR.
