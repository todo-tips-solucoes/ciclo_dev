# Contrato: histórico, foto e gate de temporárias (D9, D18)

`[PROPOSTA — a validar na implementação]`: interface nova, desenhada nesta frente.

**Produtor**: skill `rito-descoberta`, com o auxiliar `historico.mjs`.
**Consumidor**: gate da Fase 11 do `rito-dev` (skill e template).

## Arquivos, por frente e por máquina

| Arquivo | Conteúdo | Escrita |
|---|---|---|
| `~/.claude/cockpit/historico-<frente>.log` | eventos, um por linha | só acréscimo (`>>`) |
| `~/.claude/cockpit/historico-<frente>.base` | a linha de base (1ª foto) | uma vez, antes da 1ª rodada, por `.tmp` não vazio e `mv` |
| `~/.claude/cockpit/historico-<frente>.ultima` | a foto mais recente | sobrescrita a cada rodada |

- `~/.claude/cockpit/` fica fora das raízes da foto, para que o próprio log não apareça como
  mudança.
- O diretório é criado com permissão `0700` e os arquivos com `0600` (`umask 077`), porque a
  foto lista nomes de arquivo de `~/.ssh` e `~/.config/gh`.
- `<frente>` precisa casar com `^[a-z0-9][a-z0-9-]*$`, com até 64 caracteres; outro valor para
  antes de qualquer escrita (evita caminho fora do diretório).
- `.log` existente cujo evento `base` traz outra raiz ou outra branch é de outra frente ou projeto
  com o mesmo nome: a skill para e pede outro nome.

## Linha do log

São seis campos separados por TAB. TAB e quebra de linha dentro de um campo viram espaço.

```text
<ISO-8601 UTC>\t<máquina>\t<worktree ou raiz>\t<branch>\t<evento>\t<detalhe>
```

| `evento` | `detalhe` |
|---|---|
| `base` | caminho do arquivo `.base` e número de linhas da foto |
| `worktree` | `<BRANCH_INTEGRACAO> <SHA de nascimento>` (a 3ª coluna é o caminho); liga a worktree ao gate |
| `rodada` | rótulo da rodada e a diferença: `criados=N apagados=N alterados=N`, mais um item por linha seguinte, com quatro TABs e `+ <linha>` ou `- <linha>` |
| `install` / `enable` | `<id>\t<escopo>\t<projeto>\t<versão ou SHA>\t<classe>\t<comando exato>` |
| `uninstall` / `disable` | os mesmos campos do `install` / `enable` que desfaz |
| `desvio` | o que mudou sem comando declarado; a frente para |
| `gate0` | `OK` e o texto literal do owner |

A máquina sai de `hostname` e o branch de `git branch --show-current`. No `install`, `id` é
`<plugin>@<marketplace>` ou `marketplace:<nome>`; `escopo` é o valor literal do `-s`, ou `global`
para marketplace; `projeto` é o caminho absoluto da raiz onde o comando rodou, ou `-`. A linha
`install`/`enable` vai ao log antes do comando; falha do comando é fechada pelo desfazer
correspondente.

Na cópia versionada, `$HOME` vira `~`, a máquina vira `<máquina>`, caminho fora do `$HOME` vira
`<fora-do-home>`, linhas `!!` do `git status` entram só como contagem e as raízes sensíveis
(`~/.ssh`, `~/.config/gh`, `~/.gitconfig`) aparecem só como `alterada`.

## `node historico.mjs foto [--raiz <dir>]`

Imprime a foto em stdout, ordenada byte a byte, uma linha por item no formato `tipo\tchave\tvalor`.

- Só lê. Nunca imprime conteúdo de arquivo: imprime metadados ou sha256.
- `installed_plugins.json` ausente gera a linha `plugin\t-\tausente`.
- `installed_plugins.json` existente, mas ilegível ou com JSON inválido, faz a saída terminar com
  código diferente de zero (falha fechado).
- `--raiz` precisa estar num repositório git (a foto usa a raiz dele); fora disso, ou com o `git`
  em erro, `HOME` vazio ou relativo, ou `installed_plugins.json` que não é objeto, a saída é 1.
- O `git` é chamado só com argumentos em array, nunca por string de shell, e com
  `--no-optional-locks` (a foto não toca o índice).
- Symlink é seguido (diretório uma vez por caminho real); symlink quebrado gera `link-quebrado` e
  diretório ilegível gera `ilegivel`, nunca somem.

| `tipo` | Fonte | `valor` |
|---|---|---|
| `meta` | arquivos sob as raízes de metadados de D9 (exclusões abaixo); cache de plugins por pasta de versão | `tamanho mtimeMs ctimeMs inode`; `link:<alvo>` para symlink que sai da raiz; `dir` ou `orfa` (marca `.orphaned_at`) para pasta de versão do cache |
| `hash` | arquivos de conteúdo de D9, `crontab -l`, chave `mcpServers` de `~/.claude.json` e as `mcpServers` de cada projeto em `projects` | sha256 ou `ausente` |
| `plugin` | `installed_plugins.json` (formato `version` 2), só escopo `user` e o projeto da raiz: `id\|scope\|projectPath` | `version gitCommitSha` |
| `enabled` | `enabledPlugins` de `installed_plugins.json`, das settings de usuário e das `settings.json` e `settings.local.json` do projeto | JSON canônico |
| `marketplace` | `known_marketplaces.json`: nome | `repo` da source; URL ou caminho só como `sha256:<hash>` |
| `catalogo` | `git rev-parse HEAD` no `installLocation` de cada marketplace | SHA |
| `git` | `git -C <raiz> status --porcelain --ignored` e `git worktree list --porcelain` sem o `HEAD` | a linha |

- **Raízes de metadados**: `~/.claude/skills` (sem `synced/`), `~/.claude/agents`,
  `~/.claude/commands`, `~/.claude/hooks`, `~/.claude/CLAUDE.md`, `~/.claude/plugins/cache`, `<raiz>/.claude` (sem `feature-00c-state/` e
  `enforcement-log.jsonl`), `git rev-parse --git-path hooks`, `~/.ssh`, `~/.config/gh`,
  `~/.local/bin`, `~/.gitconfig`, `~/.bashrc` e `~/.profile`.
- **Hash de conteúdo**: `~/.claude/settings.json`, `<raiz>/.claude/settings.json`,
  `<raiz>/.claude/settings.local.json` e `git rev-parse --git-path config`.
- **Ausências**: raiz ausente gera a linha `meta\t<raiz>\tausente`. A chave `lastUpdated` nunca
  entra na foto.
- **Configuração fora do lugar**: com `CLAUDE_CODE_PLUGIN_CACHE_DIR` ou `CLAUDE_CONFIG_DIR`
  definido, a foto falha e cita a variável.

## Ruído conhecido

Lista fechada de mudanças que não são desvio, quando aparecem na diferença entre duas fotos:

- sincronização de `skills/synced` do Claude Code (já fora da foto, por exclusão);
- mudança da linha `catalogo` do marketplace `claude-plugins-official` (atualização automática);
- mudança do alvo `link:` de `~/.local/bin/claude` (atualização automática do Claude Code);
- arquivos `-shm`, `-wal` e `-journal` do SQLite sob `<raiz>/.claude` (já fora da foto).

Qualquer outra mudança sem comando declarado é desvio: o evento `desvio` é gravado e a frente para.

**Diferença entre duas fotos**: `diff` das duas saídas. Uma linha só na nova é criada, uma só na
velha é apagada, e a mesma chave com valor diferente é alterada.

## `node historico.mjs pendentes <log>`

Lista cada `install` ou `enable` de classe `temporária` sem `uninstall` ou `disable` posterior com
o mesmo `id`, `escopo` e `projeto`. Termina com código 0 quando não há pendentes, 1 quando há (e
imprime cada um) e 2 quando o log está ausente, ilegível, vazio ou sem evento `base`, ou tem linha
mal formada: menos de 6 colunas, evento fora da lista, ou abertura/desfazer sem 11 colunas ou com
classe diferente de `permanente`/`temporária` (falha fechado).

## Correspondência de `install` e `uninstall`

A chave de correspondência é a tripla `id`, `escopo` e `projeto` do log.

- `uninstall` sem `install` anterior com a mesma chave é ignorado.
- `install` repetido com a mesma chave: cada `uninstall` fecha o último `install` ainda aberto.

## Retomada de sessão interrompida

Ao retomar a Fase 0, a skill lê o `.log`, o `.base` e o `.ultima` da frente e tira uma foto nova.
A diferença contra o `.ultima` vira um evento `rodada` (explicada por comando declarado ou
ruído conhecido) ou `desvio` (qualquer outra). A linha de base existente nunca é recriada.

## Gate da Fase 11 (`rito-dev`)

Aplica-se quando a branch tem `docs/specs/<frente>/decisoes-do-owner.md` (falha fechado); docs, trivial e hotfix com incidente dispensam a Fase 0, não têm o registro e não rodam o gate. Roda dentro da worktree, antes do "Encerrar". Exceção única, decidida pelo
owner na revisão: a própria `rito-descoberta`, sem log porque a Fase 0 dela precede a skill, encerra
pela verificação do S3.

`node historico.mjs gate <frente>`, dentro da worktree da frente (decisões do owner na revisão de
código, 2026-11-05: comparar só o que a frente toca; pasta de cache marcada órfã conta como
desinstalada):

1. Saída 2 (falha fechado): fora de repositório git; branch que não é `<frente>` nem termina em
   `/<frente>`; frente na raiz do evento `base`, sem worktree própria; worktree atual fora do log
   (evento `worktree` ou projeto de install); evento `worktree` sem a branch de integração e o SHA
   de nascimento; commits próprios da frente que não partem do SHA de nascimento (o mais antigo da cadeia do 1º pai fora da integração precisa ter o nascimento como pai): branch absorvida pela integração por merge commit, fast-forward, `pull --rebase` ou `reset`, com ou sem commit novo depois, ou rebaseada (o rito manda squash na PR e merge da integração, nunca rebase): volta ao owner; `.log` ou
   `.base` ausente, ilegível ou vazio; log sem `base` ou sem `gate0` com `OK`; linha mal formada.
   Foto que falha dá saída 1.
2. Saída 1 com `pendente\t<linha>`: `install`/`enable` temporário sem desfazer.
3. Saída 1 com linhas `-`/`+`: plugin com `projectPath` numa raiz da frente (fora a raiz do evento
   `base`) que não seja tripla permanente nem registro automático do Claude Code (id fora do log:
   entrada `local` de id habilitado no usuário ou na settings local da raiz; entrada `project` de id
   habilitado no `.claude/settings.json` commitado da worktree); `enabledPlugins` diferente da base
   (ids temporários no usuário, no `installed_plugins.json` e na raiz; no `.claude/settings.json`
   commitado no `HEAD` das raízes da frente, mapa inteiro igual ao do `merge-base` com a branch de
   integração do evento `worktree`, salvo permanentes; ids temporários na working tree e na
   `settings.local.json` delas; `false` só vale como ausente quando a referência não tem a chave,
   nunca no `HEAD`); `merge-base` não encontrado sai 2; linhas `marketplace` temporárias diferentes da base; pasta de
   versão de id temporário sem plugin instalado e sem `.orphaned_at`.

Saída diferente de 0 impede o "Encerrar" e volta ao owner.
