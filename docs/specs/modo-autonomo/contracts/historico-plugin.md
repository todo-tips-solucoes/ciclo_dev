# Contrato: `node historico.mjs plugin <installPath>` (D9, D10)

> `[PROPOSTA — a validar na implementação]`: interface nova, desenhada nesta frente. Os únicos
> dados externos são o formato da regra deny (research R1) e o `installed_plugins.json`, que o
> `historico.mjs` já lê hoje (`instalados()`, `version` 2).

Subcomando só de leitura do auxiliar existente `skills/rito-descoberta/historico.mjs`. Avalia um
plugin instalado e devolve, em JSON, o veredito da lista fechada "conteúdo só de agentes", as regras
deny dos agentes proibidos e o SHA. Nunca imprime conteúdo de arquivo.

## Entrada

| Argumento | Regra |
|---|---|
| `<installPath>` | caminho absoluto; o `realpath` MUST ficar dentro de `~/.claude/plugins/cache` (`dentro()`, já existente); nenhum componente pode ser symlink |

Uso errado (sem argumento, argumento a mais): exit 64, como os demais subcomandos.

## Saída (stdout, uma linha JSON)

```json
{"plugin":"<nome>","sha":"<gitCommitSha>","veredito":"ok","motivos":[],"deny":["Agent(<nome>:<agente>)","Agent(subagent_type:<nome>:<agente>)"]}
```

| Campo | Regra |
|---|---|
| `plugin` | `name` do `.claude-plugin/plugin.json` |
| `sha` | `gitCommitSha` da única entrada de `installed_plugins.json` cujo `installPath` é o informado |
| `veredito` | `ok` ou `reprovado` |
| `motivos` | um texto curto por violação, ordem estável; vazio quando `ok` |
| `deny` | duas regras por agente do plugin que reprova em (a), (b) ou (c) — `Agent(<plugin>:<agente>)` e `Agent(subagent_type:<plugin>:<agente>)` (research R1: a forma de plugin é ambígua e o S4 decide) —, em ordem de nome, sem repetição |

`deny` é calculado também quando o veredito é `reprovado`: a skill precisa das regras para o
estado "SHA divergente".

## Lista fechada (D10)

Na raiz do `installPath`, só é aceito:

| Entrada | Regra |
|---|---|
| `.claude-plugin/plugin.json` | arquivo regular; sem as chaves `hooks`, `mcpServers`, `lspServers`, `commands`, `skills`, `outputStyles` |
| `README.md`, `LICENSE*` | arquivos regulares |
| `.md` citados no array `agents` | arquivos regulares; frontmatter só com `name`, `description`, `tools`, `model`, `color`; item cujo 1º componente do caminho (sem `./`) é `skills`, `commands`, `hooks` ou `output-styles`, sem distinção de maiúsculas (`./Skills/x.md`, `Commands/c.md`), reprova |
| `.md` na raiz fora do array `agents` | aceito só com frontmatter de agente nas mesmas regras e `name` sem colisão com o array; entra no cálculo do `deny`; frontmatter ausente, fora do formato `chave: valor`, com chave duplicada ou com espaço Unicode reprova |
| `.in_use/` | diretório; só arquivos regulares de nome `^[0-9]+$`; sem subdiretório nem symlink; `ENOENT` durante a varredura é tolerado (os PIDs mudam) |
| `.orphaned_at` | arquivo regular |

Qualquer outro arquivo ou diretório reprova (`commands/`, `skills/`, `hooks/`, `output-styles/`,
`.mcp.json`, executável, symlink em qualquer nível).

## Regras de proibidos (critérios da skill `rito-descoberta`; a leitura abaixo só os endurece)

Aplicadas a todos os `.md` de agente do plugin, citados no array ou não:

- **(a)** `tools:` com `WebFetch` ou `WebSearch` (casados pelo nome antes de `(`, como `WebFetch(domain:…)`), item com prefixo `mcp__`, ou item que contenha
  (sem diferenciar maiúsculas) `browser`, `chrome`, `playwright`, `puppeteer`, `computer` ou
  `desktop`. A lista de termos de navegador e desktop é escolha de desenho deste plano, que só pode
  endurecer o critério (research D-P6);
- **(b)** agente da lista nominal da skill (`meta:it-ops-orchestrator`, `meta:codebase-orchestrator`),
  casado pelo `name` do frontmatter (`it-ops-orchestrator`, `codebase-orchestrator`) em qualquer
  plugin, o que só endurece o critério;
- **(c)** sem linha `tools:`; `tools:` nulo (`tools:`, `~`, `null`), vazio (`""`), `[]` ou `*`, que equivalem a linha
  ausente (o agente herda todas as ferramentas); ou `tools:` com `Agent` ou `Task`, casados pelo nome antes
  de `(`. Escalar tipado do YAML (`true`, `false`, `null`, `yes`, `no`, `y`, `n`, `on`, `off`, `~`, em
  qualquer caixa, solto ou dentro de `[...]`) também conta, porque o leitor de verdade não o lê como
  nome de ferramenta.

Formato fechado do `tools:`. O valor é lido como texto: tira o par `[` `]` quando ele está nas duas
pontas, corta nas vírgulas e faz `trim` em cada item. Cada item MUST casar
`^[A-Za-z][A-Za-z0-9_]*(\([^()]*\))?$`, sem `#`, `!`, `&`, `\`, aspas, `{`, `}`, `[`, `]` nem `: `
(dois-pontos e espaço) em parte alguma; `*` só entre parênteses (`Bash(npm run test:*)`,
`Bash(git:*)` e `Bash(*)` passam; `*` e `Read*` não). Item fora desse formato, item vazio (vírgula
sobrando), escalar tipado (ver (c)) e linha recuada ou `- X` logo depois de `tools:` (lista em bloco,
emendada no valor) contam como proibido: o agente entra no `deny`. Frontmatter que não é YAML na
chave `tools` também: `tools:Read` (sem espaço depois dos dois-pontos) e colchete numa ponta só
(`[Read`, `Read]`), que fica no item. Assim, YAML que um leitor de verdade lê de outro jeito
(comentário, `!!null`, `!!str`, âncora, alias, escape como `\x46`, lista com comentário, `{}`,
escalar tipado) ou não lê (YAML inválido) nunca passa como lista limpa. Item `mcp__…` segue proibido
pela (a) em qualquer forma. `NotebookEdit`, `Read, Skill` e `Bash(npm test)` passam.

## Falhas fechadas (exit diferente de zero, sem JSON)

| Situação | Exit |
|---|---|
| `installPath` fora de `~/.claude/plugins/cache`, inexistente ou com symlink no caminho | 1 |
| `installed_plugins.json` ausente, em formato não reconhecido ou sem entrada para o `installPath` | 1 |
| mais de uma entrada para o mesmo `installPath` (plugin duplicado) | 1 |
| `gitCommitSha` ausente na entrada | 1 |
| array `agents` ausente ou vazio (lista vazia) | 1 |
| item do array `agents` ou `name` de agente com `..`, `/` no nome, ou caminho absoluto | 1 |
| `name` do plugin ou de agente fora de `^[A-Za-z0-9][A-Za-z0-9._-]*$` (nome que entra na regra `deny`: parêntese, `:`, `*`, espaço ou vírgula deixariam a regra sem casar com o agente, e a barreira abriria sem aviso) | 1 |
| `plugin.json` ilegível ou `name` inválido | 1 |
| frontmatter de agente citado ausente, fora do formato `chave: valor` (inclusive `chave:valor` sem espaço; salvo a emenda e o `tools:Read` do `tools:`, ver formato fechado), com chave duplicada (qual das duas vale depende do leitor) ou com espaço que não é espaço comum nem TAB (NBSP U+00A0 e afins) em qualquer linha, que o YAML não lê como separador (`tools:` ou `name:` seguidos de NBSP) | 1 |

Plugin lido por inteiro e com veredito: exit 0 quando `ok`, exit 1 quando `reprovado` (o JSON sai
nos dois casos).

## Testes (CI, FR-025)

`skills/rito-descoberta/historico.test.mjs`, script Node sem dependência, rodado por um job novo
no `.github/workflows/ci.yml`. Os fixtures são criados em diretório temporário na hora do teste,
com `HOME` apontado para ele (nenhum symlink nem executável versionado). Casos do
[quickstart](../quickstart.md) Scenario 5.
