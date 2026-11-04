# Research: correções do code review retroativo do lote 21-25

**Feature**: `revisao-lote-21-25` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D7, fatos medidos, fora de
escopo e restrições, normativas)

Referências de linha no commit `a4d68aa`. Nenhum `NEEDS CLARIFICATION` de eixo estrutural:
linguagem, plataforma e entrega são as dos arquivos existentes (bash nos passos `run:` dos fluxos
do GitHub Actions gerados pelo `configurar.sh`, o próprio `configurar.sh`, o script de testes e o
texto de duas skills). Nenhuma fonte externa nova foi lida nesta frente: as afirmações sobre a API
e o `gh` vêm dos fatos medidos em `decisoes-do-owner.md` ou de fontes oficiais já registradas, com
link, nas frentes de origem (tabela abaixo).

## Fontes

| # | Afirmação usada no plano | Veredito | Fonte |
|---|--------------------------|----------|-------|
| M1 | Com `--jq`, numa resposta HTTP de erro (404 numa rota `rules/branches/…` de repositório inexistente), o `gh api` grava no stdout o corpo JSON do erro, sem filtrar, e sai com 1. | medido (gh 2.88.1, 2026-10-08) | [decisoes-do-owner.md](decisoes-do-owner.md), "Fatos medidos" |
| M2 | `repos/<o>/<r>/commits/heads/<branch com />` devolve o mesmo `commit.tree.sha` com o nome cru, com `/` codificado como `%2F` e pela rota `branches/<branch>` (repositório público). | medido (idem) | idem |
| M3 | `repos/<o>/<r>/rules/branches/<branch com />` responde 200 com `[]` cru e com `%2F`, numa branch sem regra. Se o nome cru casa as regras de uma branch que as tem: **não medido**. | medido com lacuna | idem |
| F1 | List reviews for a pull request: "The list of reviews returns in chronological order."; `commit_id` "required, string or null". | confirmado | https://docs.github.com/en/rest/pulls/reviews (registrada em `docs/specs/codeowner-aprovacao-atual/research.md`, F4) |
| F2 | Opção nativa "Dismiss stale pull request approvals when new commits are pushed": a aprovação é descartada quando "the diff changes", com commits "that affect the diff in the pull request". | confirmado | https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches (registrada em `docs/specs/codeowner-aprovacao-atual/research.md`, F3) |
| F3 | `gh api --paginate`: "all pages of results will sequentially be requested"; a página não diz se o `--jq` roda por página ou sobre o total. | confirmado com lacuna | https://cli.github.com/manual/gh_api (registrada em `docs/specs/audit-merge-vermelho/research.md`, F4) |
| F4 | `gh`: "If a command fails for any reason, the exit code will be 1". | confirmado | https://cli.github.com/manual/gh_help_exit-codes (registrada em `docs/specs/promotion-pr-arvores/research.md`, F6) |
| S1 | A suíte `scripts/testar-configurar.sh` inteira passa com `LC_ALL=C` no ambiente. | medido (2026-10-08, `LC_ALL=C bash scripts/testar-configurar.sh` → `OK: todos os cenários passaram.`, exit 0, 76 s; shellcheck ausente na máquina, checado no CI) | sonda local nesta frente |

## Decision 1: leitura das regras que falha esvazia a lista (D1, FR-001)

**Decision**: na chamada das regras (`audit-merge-vermelho.yml.tmpl`, l.50-51), o `|| true` vira
`|| : >"$obrigatorios"`. Código de saída diferente de 0 trunca o arquivo; o `if [ -s … ]` seguinte
(l.53) cai no ramo sem filtro, com a nota "Sem regra de checks obrigatórios legível na branch base:
todo check vermelho foi listado.". O `2>/dev/null` fica.

**Rationale**: M1 mostra que a falha deixa o corpo do erro no stdout, que hoje vai para
`$obrigatorios`, vira a "lista", o `grep -Fxf` esvazia os vermelhos e o passo sai com "nada a
auditar" (fail-open). Truncar no próprio `||` descarta a saída de qualquer falha, qualquer que seja
o corpo, sem depender do formato do erro. Sucesso com `[]` continua dando arquivo vazio e a mesma
nota (comportamento de hoje, US1 cenário 2 preservado).

**Alternatives considered**:
- Validar o conteúdo (por exemplo, recusar linha que começa com `{`): depende do formato do erro,
  que só foi medido para 404 (M1).
- Capturar em variável com `if ! x="$(gh api …)"`: mesmo efeito com mais linhas.
- Deixar o passo falhar (sem auditoria): contraria D1, que manda listar todos os vermelhos.

## Decision 2: último estado por usuário em todas as reviews, depois o head (D2, FR-002)

**Decision**: o `--jq` de hoje (l.51 de `require-codeowner-approval.yml.tmpl`, que ignora
`commented` e `pending` e projeta login, estado e `commit_id // ""`) fica. O `awk` (l.52) deixa de
filtrar `$3 == head` antes de guardar o estado: guarda, por login em minúsculas, o estado e o
`commit_id` da última linha; no fim imprime o login quando o estado é `approved` **e** o
`commit_id` guardado é igual ao head.

**Rationale**: a lista vem em ordem cronológica (F1) e o `--paginate` pede as páginas em sequência
(F3), então a última linha de cada usuário é o último estado dele. Com o filtro antes, um pedido de
mudança preso a commit antigo nunca chegava ao `awk` e não anulava a aprovação no head (regressão
da PR #25). `DISMISSED` vira o último estado e não conta; `commit_id` nulo vira coluna vazia e
nunca é igual a um head não vazio (F1); a guarda de head vazio (l.44-48) segue. O `awk` sobre todas
as linhas não depende de o `--jq` rodar por página ou sobre o total (lacuna de F3).

**Alternatives considered**:
- Agrupar no `--jq` (`group_by(.user.login)`): com `--paginate` o agrupamento pode valer só por
  página (F3 não diz), e o último estado de um usuário com reviews em duas páginas sairia errado.
- Contar só a última review do PR inteiro: ignora os outros donos.

**Artefatos da frente de origem**: o contrato e a research de `codeowner-aprovacao-atual` ficam
como registro daquela frente; a regra vigente passa a ser a de [data-model.md](data-model.md) e
[contracts/passos.md](contracts/passos.md). D6 não manda editá-los.

## Decision 3: aspas antes da conferência e `REPO_REMOTO` na `rito-dev` (D3, D4, FR-003, FR-004)

**Decision**: em `skills/rito-dev/SKILL.md`, seção "Parâmetros — leitura de `cockpit.config`"
(l.10-23), o parágrafo de conferência (l.20-23) passa a dizer, nesta ordem: (1) ao ler cada valor,
remova o par de aspas simples envolvente; (2) confira `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` com
`^[A-Za-z0-9][A-Za-z0-9._/-]*$`; (3) confira `REPO_REMOTO` com
`^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$`, sem `.` nem `..` como parte; fora da
regra, PARE nomeando a chave, sem colar o valor num comando para testá-lo. A frase das aspas da
lista de regras (l.53-54) sai, para não haver duas instruções em ordens diferentes.

**Rationale**: D3 e D4 ao pé da letra. A regra de `REPO_REMOTO` é a `RE_REPO` de `configurar.sh`
(l.64) mais a exclusão de `.` e `..` (l.289-291), copiadas como texto: a skill não executa o
script. O `configurar.sh` grava os valores entre aspas simples (`escapar_aspas` e `gravar_config`, l.574-583); sem a
remoção antes, `'main'` não casa com a regra e a skill recusa todo `cockpit.config` válido.

**Alternatives considered**: manter a frase da l.53-54 e só acrescentar "antes" (duas instruções
sobre o mesmo passo em lugares diferentes, a mesma armadilha de ordem).

## Decision 4: conferência das branches antes do `--base` na `parallel-work` (D5, FR-005)

**Decision**: em `skills/parallel-work/SKILL.md` (a cópia versionada), o parágrafo "Em frente de
código a base vai SEMPRE explícita" (l.43-49) ganha: ao derivar a base, tire o par de aspas simples
envolvente de `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` e confira cada valor com
`^[A-Za-z0-9][A-Za-z0-9._/-]*$` antes de compor o `--base`; fora da regra, PARE nomeando a chave,
sem colar o valor num comando.

**Rationale**: é o ponto em que o texto manda derivar o `--base` do `cockpit.config`; a regra é a da
#19 (`RE_BRANCH`, `configurar.sh` l.67). A cópia instalada em `~/.claude/skills/` está fora de
escopo (decisoes, "Fora de escopo").

## Decision 5: mensagem do `--atualizar` com `BRANCH_*` fora da regra (D6, FR-006)

**Decision**: em `validar_chave` (`configurar.sh`, l.293-298), no ramo `BRANCH_INTEGRACAO |
BRANCH_PRODUCAO`, depois do `erro` de hoje e antes do `return 1`, uma linha a mais só quando
`$MODO` é `atualizar`: se esse valor é o nome real da branch, a saída é renomear a branch no remoto
para um nome dentro do conjunto e atualizar a chave no `cockpit.config`. A mensagem nomeia a chave
e não repete o valor. O exit 1 e a linha "Corrija o valor no cockpit.config …" (l.1129) ficam.

**Rationale**: a linha genérica da l.1129 vale para qualquer chave; a dica de renomear só faz
sentido para as duas chaves de branch, e `validar_chave` já sabe qual chave falhou. `MODO` é global
(l.75, l.1077). No modo interativo a mensagem não muda (D6 fala só do `--atualizar`).

**Alternatives considered**: acrescentar a dica à l.1129 (sairia também para `REPO_REMOTO` e as
demais chaves).

## Decision 6: textos dos modelos e registros das frentes de origem (D6, FR-007 a FR-009)

**Decision**:
- `require-codeowner-approval.yml.tmpl` (l.1-6) e `CODEOWNERS.tmpl` (l.3-4): mantêm os nomes
  literais das duas opções nativas (o cenário 22, caso 5, confere) e dizem que "Dismiss stale pull
  request approvals when new commits are pushed" descarta a aprovação quando entra commit que
  altera o diff do PR (F2), e que o check `require-codeowner-approval` é mais estrito: só conta
  aprovação de dono dada no commit atual do PR, e um pedido de mudança posterior a anula.
- `audit-merge-vermelho.yml.tmpl` (l.69): o comentário `ponytail:` nomeia o teto (a varredura cresce
  com o total de issues e PRs) e o caminho da Decision 3 da research de origem: filtrar por `since`
  ou `creator`, o que exige nova decisão do owner, porque muda a regra de D2 daquela frente.
- `docs/specs/audit-merge-vermelho/contracts/github-rest.md`: o filtro citado (l.62) passa a ser o
  do código, `.[] | select((has("pull_request") | not) and .title == env.TITULO) | .number`; o
  "Erro" das regras (l.34-36) passa a descrever o mecanismo de Decision 1 desta frente.
- `docs/specs/audit-merge-vermelho/research.md`, Decision 1: a frase "se a API recusar, a chamada já
  está sob `2>/dev/null || true` e o fluxo cai no aviso de regra ilegível" e a "Lacuna registrada"
  dão lugar a M1 e M3, com a correção desta frente; o casamento do nome cru com as regras de uma
  branch que as tem segue **não medido**.
- `docs/specs/promotion-pr-arvores/research.md`, Decision 4: a falta de código de saída documentado
  dá lugar ao que há: medido para 404 em `rules/branches` (M1: corpo no stdout, sai com 1); para a
  rota `commits/heads/…` e para 5xx vale F4 ("exit code will be 1"), com a ressalva da própria
  página de que um comando pode ter outros códigos. Sob `set -euo pipefail` a atribuição com código
  diferente de 0 derruba o passo; a guarda de SHA hexadecimal segue para resposta sem o campo. O
  "Limite conhecido" registra M2 para `/`.

**Rationale**: D6 ao pé da letra; cada afirmação com fonte da tabela acima (Princípio V).

## Decision 7: testes nos cenários 21 a 24 (D7, FR-010)

**Decision**: casos novos dentro dos cenários existentes, sem número de cenário novo; detalhe em
[quickstart.md](quickstart.md).
- **24**: o bloco inteiro entra na guarda de `jq` do 22 (pula fora do CI, falha no CI com
  `COCKPIT_EXIGIR_FERRAMENTAS=1`). O `gh` falso guarda `$*` antes de percorrer os argumentos e, na
  rota de issues, sai com código próprio se faltar `--paginate` ou `state=all`. Caso novo: a rota
  de regras, sob uma variável de controle, imprime um corpo JSON de erro no stdout e sai com 1
  (forma de M1); a issue lista `ci` e `lint` com a nota de regra ilegível.
- **22**: casos novos com o `gh` falso de hoje e uma variável que faz a rota `pulls/<n>` sair com
  1: pedido de mudança posterior preso a commit antigo; dono aprova commit antigo e não dono aprova
  o head (o fixture ganha um segundo login, fora do `CODEOWNERS` falso); reaprovação no head;
  `DISMISSED`; `commit_id` nulo; falha do `gh` ao ler o head.
- **21**: uma lista única de valores recusados usada nos casos 1 e 3b: os cinco de hoje mais
  `a..b`, `x.lock`, `a/`, `-x`, `.x`, `/x` e `á`. O caso 1 confere que o repositório continua sem
  nenhum arquivo fora de `.git` e que o `cstk` falso não recebeu `hooks install`. O 3b confere a
  mensagem completa (chave, conjunto, linha de correção e dica de renomear). O caso 4 confere a
  mensagem de erro no tty. Caso novo de manifesto anterior que ficaria vazio (Decision 8).
- **23**: o caso 6 confere, só nas linhas de comentário antes de `name:`, as duas afirmações de D2
  de `promotion-pr-arvores`: merge commit como na Fase 9 do `rito-dev`, e com squash o fluxo não
  abre nem reabre o PR quando o conteúdo já é igual.

**Rationale**: SC-002 pede que cada caso falhe se a correção for revertida: o caso de regras
ilegíveis falha com o `|| true` de hoje (lista vira o JSON, sai "nada a auditar"); os casos de
pedido de mudança antigo falham com o filtro `$3 == head` antes do estado; a exigência de
`--paginate`/`state=all` falha se a chamada perder uma das duas. Os valores `a..b`, `x.lock` e
`a/` casam com `RE_BRANCH` e só são recusados pelo `git check-ref-format --branch` (l.294), que já
está no código: o teste fixa essa guarda.

## Decision 8: manifesto anterior que ficaria vazio (D7, cenário 21)

**Decision**: o teste fixa a regra vigente, sem mudar `gravar_manifesto`: com manifesto anterior e
nenhuma linha a registrar, o configurador sai com 0, `.cockpit/manifesto.sha256` continua existindo
e é regravado sem linhas. Construção: configurar com o exemplo; trocar o conteúdo do manifesto por
uma única linha de um arquivo que não existe; rodar de novo com todos os destinos listados em
`DESTINOS_DO_PROJETO`.

**Rationale**: D1 a D6 desta frente não mudam o manifesto, e D7 é só de testes. A regra vem da
frente `configurar-endurecimento`: D3 do owner ("Com manifesto anterior, a regra de hoje
continua") e a research daquela frente, Decision 4 ("Com manifesto anterior, nada muda (FR-007),
inclusive a regravação vazia quando nada restar"). O caso cobre o terceiro ramo da guarda
`[ -n "$ord" ] || [ -f "$alvo" ] || return 0` (l.974): sem manifesto anterior (caso 5) e com linhas
(caso 6) já estão cobertos. A redação do cenário 2 da US6 na spec, que dizia "não grava manifesto
vazio" para esse caso, foi alinhada a esta regra nesta etapa (Decisão `dec-012` da execução, no
estado da frente).

**Alternatives considered**: não regravar quando `ord` sai vazio com manifesto anterior (deixa
linhas de arquivos que não existem e muda uma regra que o owner manteve, sem decisão nova).

## Decision 9: `LC_ALL=C` nos scripts alterados (FR-011)

**Decision**: `export LC_ALL=C` logo depois de `set -euo pipefail` em `scripts/testar-configurar.sh`
e nos dois passos `run:` alterados (`audit-merge-vermelho` e `require-codeowner-approval`).
`configurar.sh` já exporta (l.38). A função `codificar` mantém o `local LC_ALL=C` dela.

**Rationale**: FR-011 é literal ("todo script alterado"). S1 mostra a suíte verde com `LC_ALL=C`.
Nos passos, a locale só afeta a ordem do `sort -u` do corpo da issue (o teste confere presença, não
ordem) e o `tolower` de logins; com `C` ficam determinísticos.

**Alternatives considered**: `LC_ALL=C` só onde há regex ou byte (não cumpre FR-011 ao pé da letra;
o custo da forma literal é uma linha por script).
