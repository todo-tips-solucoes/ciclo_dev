---
name: parallel-work
description: 'Trabalhar numa branch à parte com isolamento real via git worktree, sem interromper a branch atual nem dar git checkout na working tree principal. Invoque como /parallel-work <branch> --base origin/<base> — a base vai SEMPRE explícita, derivada de BRANCH_INTEGRACAO/BRANCH_PRODUCAO em cockpit.config (como o rito-dev faz); sem ela para abrir frente de código, recuse e peça a base ao chamador — nunca assuma um nome fixo de branch, senão a branch nasce do HEAD da árvore principal, que apodrece. Chame da raiz da árvore principal, nunca de dentro de outra worktree. SEM branch → cria branch provisória + worktree (só para trabalho exploratório, não para frente de código). COM branch existente → anexa worktree a ela e DESCARTA --base sem avisar. COM branch nova → cria a branch + worktree a partir da base. Abrindo frente que vai rodar /feature-00c, acrescente --short-name <short-name> — sem ele o vínculo de state é nomeado pelo slug da BRANCH e a guarda, que procura por <short-name>, fica inerte em silêncio. Use para: trabalho paralelo, branch isolada, desenvolver feature em separado.'
---

# Parallel Work (worktrees isoladas)

Cria uma **git worktree** em diretório irmão (`../<repo>-<slug>`) para trabalhar numa branch sem tocar na working tree principal. É dirigida pelo `driver.mjs` que acompanha esta skill.

**Rode da raiz da árvore principal**, nunca de dentro de outra worktree: o driver resolve o destino da worktree pelo `git rev-parse --show-toplevel` do diretório corrente, então chamado de dentro de uma worktree ele cria a próxima como irmã DELA, com o nome concatenado. O **vínculo de state** é robusto a esse erro — ele resolve a árvore principal por `git rev-parse --git-common-dir`, e nasce no lugar certo mesmo assim —, mas o destino da worktree, não: você acaba com um diretório aninhado que ninguém procura.

## Como usar

**Rode o driver IMEDIATAMENTE e trabalhe no `path` que ele retornar.** Não decida nada antes nem pare para perguntar — o driver resolve tudo sozinho a partir do argumento (ou da falta dele).

> A única coisa a completar antes de rodar é o `--base`: invocada com branch e **sem** base explícita, para abrir frente de código a skill não deve criar a worktree a partir do `HEAD` — **recuse** e peça a `--base` explícita ao chamador, derivada de `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` em `cockpit.config` (como o `rito-dev` já faz), conforme o Princípio IV.

> ⚠️ **Invocada sem tarefa definida? Rode o driver mesmo assim, na hora.** NUNCA use `AskUserQuestion` nem pare para perguntar "o que você quer fazer" antes de criar a worktree. A worktree provisória vem **primeiro**; a tarefa é definida depois, já dentro dela.
>
> Isso vale para trabalho **exploratório**. Para abrir frente de código, a branch e o `--base` são obrigatórios (Princípio IV) — invocada com branch, a skill nunca cria worktree provisória.

A cópia instalada por `instalar.sh` (`~/.claude/skills/`) é cópia literal da
versionada (`skills/`) — o instalador faz `cp -r`. Rode a instalada:

```
node ~/.claude/skills/parallel-work/driver.mjs new <branch> --base origin/<base>
```

⚠️ **Enquanto você não reinstalar, a sua cópia é mais velha que a versionada.** A criação do vínculo de state é recente: a
cópia instalada na sua máquina só passa a criá-lo depois de você rodar `bash instalar.sh`
com a versão que a contém. Enquanto não rodar, abrir frente **não** cria o vínculo e o guard do
`/feature-00c` fica inerte para ela — sem erro e sem aviso. Confira uma vez:

```
grep -c linkState ~/.claude/skills/parallel-work/driver.mjs   # 0 = precisa reinstalar
```

⚠️ **Substitua `<branch>` e `<base>` antes de rodar.** Colado literalmente o bloco não executa nada
(erro de sintaxe), mas `node ~/.claude/skills/parallel-work/driver.mjs new` **sem argumento nenhum**
cria worktree e branch provisória a partir do `HEAD` atual, sem base — o defeito que a `--base`
existe para evitar. Essa forma existe e serve para trabalho exploratório; para abrir frente, nunca.

**Em frente de código a base vai SEMPRE explícita** (Princípio IV da `docs/constitution.md`):
`--base origin/<branch-de-integracao>`, derivada de `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` em
`cockpit.config` — nunca um nome fixo de branch. Sem a flag, a branch nova sai do `HEAD` da árvore
principal — que, num fluxo de worktrees, ninguém mais atualiza; para abrir frente de código,
**recuse** e peça a base ao chamador em vez de assumir uma topologia de branches. A forma sem
argumento existe para trabalho exploratório (branch provisória a partir do `HEAD` atual) e não
serve para abrir frente.

Comportamentos esperados (o driver escolhe automaticamente):

- **SEM argumento** → cria uma **branch provisória nova** (`parallel/wip-<timestamp>`) **partindo da branch atual** e abre a worktree. (`status: created`)
- **COM argumento de branch que JÁ existe** → **vai para essa branch** e abre a worktree nela, sem recriá-la. (`status: created` se ainda não estava aberta; `exists` se já houver worktree dela; `declare` se ela for a da working tree principal.)
- **COM argumento de branch que NÃO existe** → **cria a branch com esse nome partindo da branch atual** e abre a worktree. (`status: created`)

### O vínculo de state no relatório

Ao abrir worktree — tanto `status: "created"` quanto `status: "exists"` — o relatório traz
**exatamente um** destes dois campos, nunca ambos, nunca nenhum:

| Campo | Significado |
|---|---|
| `stateLink` | caminho do vínculo criado na árvore principal, sob `.claude/feature-00c-state/<nome>`. É o que faz a guarda do `/feature-00c` encontrar o state da frente dentro da worktree. |
| `stateLinkSkipped` | motivo pelo qual o vínculo **não** foi criado, em conjunto fechado: `slug-vazio`, `slug-invalido`, `caminho-ocupado-por-diretorio-real`, `vinculo-aponta-para-outra-worktree-viva`, `worktree-registrada-sem-diretorio`, `raiz-de-state-nao-e-diretorio`, `arvore-principal-nao-resolvida`, `sem-permissao-de-symlink`, um código `errno`, ou `erro-de-io`. |

O symlink normalmente nasce **pendurado**: o state só é criado quando o `/feature-00c` roda depois.
Isso é o estado esperado entre os dois comandos, não erro.

`exists` **repara**: reabrir uma frente cuja worktree foi criada por um driver antigo (sem vínculo)
é a única passagem por aqui, e é onde o vínculo que faltava é criado. Só o `declare` não traz
nenhum dos dois campos — lá não há worktree, e o alvo seria o próprio vínculo.

A exceção é a worktree **sem checkout utilizável**: o registro sobrevive, o `git worktree add` na
mesma branch continua recusando, e o relatório sai `exists` com
`worktree-registrada-sem-diretorio` e um `note` dizendo o que destravar/podar. Ali o driver **não**
repara — criar vínculo para um diretório que não existe seria prometer o que não há.

São **três** montagens, e o remédio difere: (a) diretório apagado à mão → `git worktree prune`;
(b) worktree **travada** (`git worktree lock`) com o diretório apagado → o `prune` sozinho é
**no-op**, porque o lock isenta o registro de prune por design: `git worktree unlock <caminho>`
**primeiro**; (c) **registro órfão** (o `.git` da worktree sumiu) → o diretório **continua no
disco**, possivelmente com trabalho não commitado — `mv` o remanescente antes de reabrir, porque o
`add` recusa destino existente.

Recusar o vínculo **não** falha a worktree — o exit continua `0` e o `status`, `created`/`exists`.
Se o campo que veio foi o `stateLinkSkipped`, a frente fica sem o vínculo e a guarda do
`/feature-00c` fica inerte para ela. O que fazer depende do motivo:

| Motivo | O que fazer |
|---|---|
| `caminho-ocupado-por-diretorio-real` | **Não** crie o link: existe state real ali (máquina que já rodou o `/feature-00c` antes do vínculo). Para migrar, `mv` o diretório para dentro da worktree e só então crie o link. |
| `vinculo-aponta-para-outra-worktree-viva` | Colisão de nome com **outra frente aberta** (worktree registrada e viva). Reabra com `--short-name <outro-nome>`; não apague o link alheio. |
| `worktree-registrada-sem-diretorio` | O registro da worktree sobreviveu ao checkout. Na árvore principal: `git worktree unlock <caminho>` **se estiver travada** (o `prune` sozinho é no-op nela), depois `git worktree prune`; se o diretório ainda existir com trabalho dentro (registro órfão), `mv` antes de reabrir. **Não** é colisão de nome, e trocar o `--short-name` não resolve. |
| `slug-vazio` / `slug-invalido` | O nome saiu do slug da **branch** e não serve como nome de arquivo. Reabra com `--short-name <nome-kebab-case>`. |
| `raiz-de-state-nao-e-diretorio` / `arvore-principal-nao-resolvida` | Layout do repositório fora do esperado (`.claude` ocupado, ou `.git` fora de `<raiz>/.git`). Resolva o que o motivo aponta — criar o link à mão o poria fora do repositório. |
| `sem-permissao-de-symlink` / `errno` | Ajuste a permissão e reexecute o comando (o ramo `exists` repara). |

Criar à mão, quando o motivo permite — **da raiz da árvore principal**, e sem barra no fim:

```bash
ln -s <path-da-worktree>/.claude/feature-00c-state/<short-name> .claude/feature-00c-state/<short-name>
```

### `--short-name` — quando a branch não se chama como a frente

O nome do vínculo sai de `slugify(<branch>)`, mas a guarda do `/feature-00c` procura o state por
`<short-name>`. Pela Fase 1 do rito a branch vem prefixada (`fix/…`, `feat/…`), então os dois
divergem **por padrão** — e o vínculo nasce apontando para um caminho que a pipeline nunca cria:
pendurado para sempre, guarda inerte, tudo verde.

Abrindo frente que vai rodar `/feature-00c`, passe o mesmo `<short-name>`:

```
node ~/.claude/skills/parallel-work/driver.mjs new fix/o-defeito --base origin/<branch-de-integracao> --short-name o-defeito
```

O nome vale só para o vínculo — o diretório da worktree continua saindo do slug da branch. Sem a
flag, nada muda em relação ao comportamento anterior. Nomes recusados por **forma** (`.`, `..`,
`.git`, com `/` ou `\`) saem como `stateLinkSkipped`, sem tocar no disco.

⚠️ **Reabrir a mesma frente com `--short-name` diferente deixa o vínculo anterior órfão** — ficam
dois symlinks na raiz de state, o antigo pendurado para sempre, e o `rm -rf` do encerramento
remove um nome só. Se trocar o nome, apague o vínculo antigo à mão
(`rm .claude/feature-00c-state/<nome-antigo>` — sem barra no fim: sobre symlink, a barra entra
pelo link e esvazia o state DENTRO da worktree).

### As duas formas de flag, e o que o driver recusa

`--base origin/<branch-de-integracao>` e `--base=origin/<branch-de-integracao>` são equivalentes; idem `--short-name`. O que o
driver **não** entende ele recusa, com mensagem em `stderr` e exit `1`, **antes** de criar
qualquer coisa — nada de worktree, branch ou raiz de state:

| Invocação | O que acontece |
|---|---|
| `--shortname o-defeito` (digitação errada) | `ERRO: opção desconhecida: --shortname` |
| `--base` sem valor, `--base=`, `--short-name=` | `ERRO: <flag> exige um valor` |
| `--base --force` | `ERRO: valor de --base não pode começar com "-"` |
| `new frente sobra` (posicional a mais) | `ERRO: argumentos demais` |
| `new ""` (wrapper com variável não setada) | `ERRO: o nome da branch não pode ser vazio` |
| `list` com qualquer argumento | `ERRO: list não aceita argumentos: <args>` |

Isso é recente e vale a pena saber por quê: antes, **flag desconhecida era ignorada em silêncio**.
`--base=origin/<branch-de-integracao>` — a forma natural de escrever — não era reconhecida, a branch nascia do
`HEAD` da árvore principal e o relatório declarava `"base": "HEAD"`. Quem escrevia assim cumpria a
Cláusula de Base Verificada na intenção e a violava no efeito, sem nenhum sinal. `--short-name=`
tinha o gêmeo: o vínculo nascia com o slug da **branch** e a guarda ficava inerte — o defeito exato
que a flag existe para evitar.

⚠️ **`--base` só vale para branch NOVA.** Quando a branch já existe (local ou remota) o driver
anexa a worktree e **descarta `--base` sem avisar** (comentário no próprio `driver.mjs`) — o JSON
nem traz o campo `base`.
Ao reabrir frente, confira o SHA da worktree contra a base antes de concluir qualquer coisa. E sem
`--base` a branch nova sai do `HEAD` atual, que é o defeito que a flag existe para evitar.

O stdout é JSON puro. Leia o campo `status`:

- **`created`** — worktree nova em `path` (branch nova, ou existente que não estava aberta). Trabalhe lá.
- **`exists`** — a branch já está numa outra worktree (`path` aponta pra ela). Não duplica: vá trabalhar lá.
- **`declare`** — a branch é a que está em checkout na working tree **principal** (git não abre 2ª worktree dela). Trabalhe na tree atual mesmo, sem worktree.

## Trabalhar na worktree

`cd <path>` e edite/builde/commite/`push` dentro dela.

> ⚠️ **Caminho absoluto sempre.** O working directory do Claude Code continua apontando para o repo principal mesmo depois de criar a worktree. Toda operação de arquivo (`Read`/`Edit`/`Write`/`Glob`/`Grep`) **deve** usar o caminho absoluto prefixado com `<path>` da worktree — ex.: `<path>\apps\crm\src\foo.ts` — nunca relativo nem começando pelo repo principal. Comandos shell: `cd <path>` antes de git/pnpm.

> **`pnpm install --frozen-lockfile` é lazy.** A worktree não traz `node_modules`. Só instale no momento do 1º build/typecheck/teste/`push`. Para só ler/editar, não instale.

## Encerrar

**Os guards abaixo — com os modos de falha e os exit codes medidos — evitam o trabalho perdido
mais comum ao encerrar uma frente.**

**Da árvore principal, nesta ordem:** conferir → `git worktree remove` → `git branch -D` →
atualizar a base → apagar o state do `/feature-00c`. De dentro da worktree o `remove` sai 0, apaga
o próprio diretório corrente e o comando seguinte morre com
`Unable to read current working directory`.

Os avisos que custam trabalho perdido:

- **Confira antes, e olhe o exit de cada conferência.** São quatro: `git -C <caminho-da-worktree>
  symbolic-ref --short HEAD` (tem de imprimir `<branch>` — é o que amarra o caminho à branch),
  `git -C <caminho-da-worktree> status --short` (exit 0 **e** vazio), `gh pr view <número> --json
  state,headRefOid` e `git rev-parse refs/heads/<branch>` (SHA **idêntico** ao `headRefOid` — o `refs/heads/` importa: com tag homônima o nome curto devolve o SHA da tag, com exit 0). Saída
  vazia com exit 128 **não** é "limpo". `state` diferente de `MERGED` muda o caminho — com `OPEN`
  **não encerre**; com `CLOSED`, encerre — preservando a branch remota **se ela ainda existir**.
  SHA diferente: **pare**.
- **`worktree remove` recusando é o guard, não obstáculo.** Commite ou salve o que está ali e
  repita. **Nunca `--force`**: ele apaga sem deixar nada no `git stash list`, e o que está ali
  costuma ser o registro `_bmad-output/` não commitado.
- **`rm -rf` do state da raiz da árvore principal** (de um subdiretório ele sai 0 sem fazer nada),
  **sem barra no fim, sem `<short-name>` vazio, e só depois de o `remove` ter saído 0.** Com barra, e sendo symlink, ele entra pelo link e esvazia **o
  diretório de state dentro da worktree**, com exit 0; vazio, leva o state de todas as frentes da
  máquina.
- **Confira em que branch a árvore principal está antes de atualizar a base.** **Isto erra com exit 0**: com a principal parada noutra branch, `git pull --ff-only origin <base>` fast-forwarda
  *aquela* branch e deixa a `<base>` real atrás. Escrever `origin <base>` não protege — confirme
  com `git branch --show-current` antes de rodar o `pull` (ou use
  `git fetch origin <base>:<base>` quando a principal não está na base).

⚠️ O Claude Code executa a cópia **instalada** das skills, não a versionada. Depois de puxar
qualquer mudança neste procedimento, rode `bash instalar.sh` — sem isso a máquina segue
com o texto antigo.

Variantes que este guia não cobre em detalhe: **frente sem PR** (worktree provisória
`parallel/wip-*`, cujo guard é `git log origin/<base>..<branch>`), **PR fechada sem merge**, o modo
**`declare`**, a worktree travada (`git worktree unlock`, não `--force`) e a branch **remota**
sobrevivente (`git ls-remote --heads origin refs/heads/<branch>` antes de apagar).

A sequência, para quem já conferiu o passo 1 pelos guards acima — **é sequência copiável, não script**: sem
`&&` nem `set -e`, colada inteira ela roda os passos seguintes mesmo que o `remove` recuse, e
executa os dois ramos do passo 4, dos quais só um se aplica:

```bash
git worktree remove <caminho-da-worktree>
git branch -D <branch>                          # só se o remove acima saiu 0
git symbolic-ref --short HEAD                   # na base? → git pull --ff-only origin <base>
                                                # noutra, ou 128 (detached)? → git fetch origin <base>:<base>
rm -rf .claude/feature-00c-state/<short-name>   # só se o remove acima saiu 0
```

No Windows, se o `remove` der "Permission denied" (handle aberto por antivírus/indexador), o
contorno é `git worktree prune` e depois `Remove-Item <path> -Recurse -Force`. ⚠️ Isso é o
`--force` com outro nome — apaga o diretório sem consultar o git. Confira antes que não há registro
`_bmad-output/` não commitado ali.

## Outros comandos

```
node ~/.claude/skills/parallel-work/driver.mjs list   # lista worktrees ativas (branch<TAB>path)
```

O `list` **não aceita argumentos** — `list --base X` sai com `ERRO: list não aceita argumentos` e
exit `1`, em vez de "funcionar" ignorando o `X`. Mesma política do `new`.

**Piso de versões**: Node ≥ 14.14 (`rmSync`) e git ≥ 2.9 (`worktree add --track -b`). Em git
< 2.36 o porcelain não emite `prunable`: uma worktree **alheia** que virou cadáver volta a bloquear
o slug (motivo `vinculo-aponta-para-outra-worktree-viva`, remédio `git worktree prune`). O ramo
`exists` não degrada — ali a morte também é medida pela existência do diretório.

## Constraints

- Nunca `git checkout`/`git switch` na working tree principal — todo trabalho paralelo é dentro da worktree.
- Toda mudança chega via **PR**; nunca commitar/mergear na `main` (cláusula pétrea).
