# Contrato: histórico, foto e gate de temporárias (D9, D18)

`[PROPOSTA — a validar na implementação]`: interface nova, desenhada nesta frente.

**Produtor**: skill `rito-descoberta`, com o auxiliar `historico.mjs`.
**Consumidor**: gate da Fase 11 do `rito-dev` (skill e template).

## Arquivos, por frente e por máquina

| Arquivo | Conteúdo | Escrita |
|---|---|---|
| `~/.claude/cockpit/historico-<frente>.log` | eventos, um por linha | só acréscimo (`>>`) |
| `~/.claude/cockpit/historico-<frente>.base` | a linha de base (1ª foto) | uma vez, antes da 1ª rodada |

- `~/.claude/cockpit/` fica fora das raízes da foto, para que o próprio log não apareça como
  mudança.
- O diretório é criado com permissão `0700` e os arquivos com `0600` (`umask 077`), porque a
  foto lista nomes de arquivo de `~/.ssh` e `~/.config/gh`.
- `<frente>` precisa casar com `^[a-z0-9][a-z0-9-]*$`; outro valor para antes de qualquer
  escrita (evita caminho fora do diretório).

## Linha do log

São seis campos separados por TAB. TAB e quebra de linha dentro de um campo viram espaço.

```text
<ISO-8601 UTC>\t<máquina>\t<worktree ou raiz>\t<branch>\t<evento>\t<detalhe>
```

| `evento` | `detalhe` |
|---|---|
| `base` | caminho do arquivo `.base` e número de linhas da foto |
| `rodada` | rótulo da rodada e a diferença: `criados=N apagados=N alterados=N`, mais um item por linha seguinte `\t\t\t\t+ <linha>` |
| `install` | `<id>\t<escopo>\t<projeto>\t<versão ou SHA>\t<classe>\t<comando exato>` |
| `uninstall` | os mesmos campos do `install` |
| `desvio` | o que mudou sem comando declarado; a frente para |
| `gate0` | `OK` e o texto literal do owner |

A máquina sai de `hostname` e o branch de `git branch --show-current`. Na cópia versionada,
`$HOME` vira `~` e as raízes sensíveis (`~/.ssh`, `~/.config/gh`, `~/.gitconfig`) aparecem só
como `alterada`.

## `node historico.mjs foto [--raiz <dir>]`

Imprime a foto em stdout, ordenada byte a byte, uma linha por item no formato `tipo\tchave\tvalor`.

- Só lê. Nunca imprime conteúdo de arquivo: imprime metadados ou sha256.
- `installed_plugins.json` ausente gera a linha `plugin\t-\tausente`.
- `installed_plugins.json` existente, mas ilegível ou com JSON inválido, faz a saída terminar com
  código diferente de zero (falha fechado).
- `--raiz` precisa ser um diretório existente.
- O `git` é chamado só com argumentos em array, nunca por string de shell.

| `tipo` | Fonte | `valor` |
|---|---|---|
| `meta` | arquivos sob as raízes de metadados de D9 (exclusões abaixo) | `tamanho mtimeMs ctimeMs inode` |
| `hash` | arquivos de conteúdo de D9, `crontab -l`, chave `mcpServers` de `~/.claude.json` | sha256 ou `ausente` |
| `plugin` | `installed_plugins.json`: `id\|scope\|projectPath` | `version gitCommitSha` |
| `enabled` | `enabledPlugins` de `installed_plugins.json` e das settings de usuário e do projeto | JSON canônico |
| `marketplace` | `known_marketplaces.json`: nome | `repo` da source |
| `catalogo` | `git rev-parse HEAD` no `installLocation` de cada marketplace | SHA |
| `git` | `git -C <raiz> status --porcelain --ignored` e `git worktree list` | a linha |

- **Raízes de metadados**: `~/.claude/skills` (sem `synced/`), `~/.claude/agents`,
  `~/.claude/plugins/cache`, `<raiz>/.claude` (sem `feature-00c-state/` e
  `enforcement-log.jsonl`), `git rev-parse --git-path hooks`, `~/.ssh`, `~/.config/gh`,
  `~/.local/bin`, `~/.gitconfig`, `~/.bashrc` e `~/.profile`.
- **Hash de conteúdo**: `~/.claude/settings.json`, `<raiz>/.claude/settings.json`,
  `<raiz>/.claude/settings.local.json` e `git rev-parse --git-path config`.
- **Ausências**: raiz ausente gera a linha `meta\t<raiz>\tausente`. A chave `lastUpdated` nunca
  entra na foto.
- **Cache fora do lugar**: com `CLAUDE_CODE_PLUGIN_CACHE_DIR` definido, a foto falha e cita a
  variável.

## Ruído conhecido

Lista fechada de mudanças que não são desvio, quando aparecem na diferença entre duas fotos:

- sincronização de `skills/synced` do Claude Code (já fora da foto, por exclusão);
- atualização automática de `known_marketplaces.json` do marketplace oficial;
- arquivos `-shm` e `-wal` do SQLite.

Qualquer outra mudança sem comando declarado é desvio: o evento `desvio` é gravado e a frente para.

**Diferença entre duas fotos**: `diff` das duas saídas. Uma linha só na nova é criada, uma só na
velha é apagada, e a mesma chave com valor diferente é alterada.

## `node historico.mjs pendentes <log>`

Lista cada `install` de classe `temporária` sem `uninstall` posterior com o mesmo `id`, `escopo`
e `projeto`. Termina com código 0 quando não há pendentes, 1 quando há (e imprime cada um) e 2
quando o log está ausente ou ilegível.

## Correspondência de `install` e `uninstall`

A chave de correspondência é a tripla `id`, `escopo` e `projeto` do log.

- `uninstall` sem `install` anterior com a mesma chave é ignorado.
- `install` repetido com a mesma chave: cada `uninstall` fecha o último `install` ainda aberto.

## Retomada de sessão interrompida

Ao retomar a Fase 0, a skill lê o `.log` e o `.base` da frente e tira uma foto nova. A diferença
contra a última foto registrada vira um evento `rodada` (explicada por comando declarado ou
ruído conhecido) ou `desvio` (qualquer outra). A linha de base existente nunca é recriada.

## Gate da Fase 11 (`rito-dev`)

Aplica-se quando a branch tem `docs/specs/<frente>/decisoes-do-owner.md`, isto é, na trilha
completa. Roda dentro da worktree, antes do "Encerrar".

1. `pendentes` termina com 0.
2. As linhas `plugin`, `enabled` e `meta` de `~/.claude/plugins/cache` de
   `foto --raiz <raiz do evento base>` são iguais às da linha de base. A raiz é a mesma da linha
   de base, para que as settings do projeto comparadas sejam as mesmas.
3. Arquivo `.log` ou `.base` ausente ou ilegível impede o encerramento (falha fechado).

Qualquer diferença impede o "Encerrar" e volta ao owner.
