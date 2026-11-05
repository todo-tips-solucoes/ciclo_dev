# Data Model: rito-descoberta

Entidades da frente. Não há banco: cada entidade é um arquivo Markdown, uma linha de texto ou a
saída de um comando. Fonte normativa: `decisoes-do-owner.md` desta pasta (D1 a D19). Os formatos
de leitura por máquina estão em `contracts/`.

## Entity: Registro da Fase 0 (`docs/specs/<frente>/decisoes-do-owner.md`)

Produzido pela skill `rito-descoberta` depois do OK do Gate 0; 1º commit da worktree da frente (D11).

| Campo (título de seção `## `) | Obrigatório | Regra |
|---|---|---|
| `Escopo` | sim | itens E1..En |
| `Fora do escopo` | sim | texto não vazio |
| `Caminhos previstos` | sim | bloco ```` ```text ```` com 1 ou mais linhas válidas (ver contrato) |
| `Decisões` | sim | itens D1..Dn com a resposta do owner |
| `Mapa papel→agente` | sim | agentes usados na frente, com o agente de stack escolhido (D2) e o SHA do catálogo |
| `Regra de proibidos` | sim | as regras (a), (b), (c) aplicadas, ou referência à skill no SHA usado |
| `Instalações previstas` | sim | tabela de 5 colunas ou a palavra `Nenhuma.` |
| `Smoke` | sim | itens S1..Sn e a regra de falha |
| `Telas` | sim | caminho de `telas/` ou `Não há: a frente não tem interface.` |
| `Irreversibilidade` | sim | texto não vazio; `Nenhuma.` explícito quando for o caso |
| `Dependências novas` | sim | lista ou `Nenhuma no repositório.` |
| `Histórico` | sim | tabela de alterações fora do repositório na Fase 0 (D9) |
| `Pendências para a research do plan` | sim | lista ou `Nenhuma.` |
| `OK do owner` | sim | data, respostas por decisão e o OK final literal |

O título H1 é `# Decisões do owner — <frente>`.

### Regras

- Cada título acima aparece exatamente uma vez, escrito igual (comparação de linha inteira).
- Seção ausente, duplicada ou vazia falha fechado: a Fase 0 não conclui (FR-007).
- O arquivo é lido pela frente `modo-autonomo` no 1º commit da branch, não na ponta (D11).

### State Transitions

`rascunho na conversa` → (OK do Gate 0) → `gravado e validado` → (commit) → `1º commit da worktree`.
Antes do OK não existe arquivo (FR-005).

## Entity: Mapa papel→agente (seção da skill)

| Campo | Tipo | Regra |
|---|---|---|
| Domínio | texto | um por linha (D3) |
| Agente | `plugin:agente` | existe no array `agents` do `plugin.json` no SHA registrado |
| Ferramentas | texto | resumo do `tools:` (só leitura, leitura e Bash, escreve, varia) |
| Id do plugin | `voltagent-<plugin>@voltagent-subagents` | registrado na seção (D2) |
| SHA do catálogo | 40 hexadecimais | `ed74d115b7fb7026a22a4f816a8e3250f425e3b4` nesta frente |

### Regras

- Todo agente citado passa nas regras (a) e (c) de proibidos; os nomes da regra (b) existem no
  catálogo (S2, SC-003).
- Papel sem agente elegível volta ao owner como "papel sem agente" (US2).
- O `security-auditor` entra como validador sempre que a decisão toca credencial, terceiro,
  permissão ou dado, e nunca escolhe (D3).

## Entity: Item de instalação (linha de `Instalações previstas`)

| Campo | Regra |
|---|---|
| Instalar | comando exato, dentro dos canais de D17 |
| Desfazer | comando exato; plugin sempre com `-s project` explícito (D18) |
| Escopo | onde vale (worktree, projeto) |
| Versão ou SHA | versão exata de pacote ou SHA de 40 caracteres do catálogo |
| Classe | `permanente` ou `temporária` |

### Regras

- Executar exige a linha "Instalação pelo agente: ligada" na `origin/<base>` (D19); sem ela, o
  agente só imprime o par instalar/desfazer.
- Comando, flag, escopo ou classe diferente do registrado é desvio: para e pede OK (D16).
- Nunca permitidos: script remoto, executor que baixa na hora, `-y` e `--accept-command` no
  `claude plugin install`, `update`, `marketplace update`, `self-update` (D17).
- `marketplace add` e `marketplace remove` são sempre `temporária` (D17).
- Nada `permanente` é global; `permanente` aparece no diff da PR com manifesto e lockfile (D18).

### State Transitions

`listado no Gate 0` → `instalado` (linha `install` no histórico) → `conferido` (SHA ou versão
batem) → `desinstalado` (linha `uninstall`, só para `temporária`). SHA divergente depois do
install: `desinstalado` e a frente para (D17).

## Entity: Estado de plugin (verificação de D7)

Calculado por plugin do mapa, na raiz onde o agente vai ser usado (na worktree, quando é lá).

| Estado | Condição | Ação |
|---|---|---|
| ok | entrada com `scope == "project"`, `projectPath` igual à raiz, habilitada, `gitCommitSha` igual ao registrado e o `installPath` só com `.claude-plugin/` e os `.md` de agentes (sem `hooks/` nem `.mcp.json`) | nenhuma |
| desabilitado | entrada existe na raiz, mas não habilitada | `enable -s project` sob a política |
| ausente | nenhuma entrada para a raiz | `install` do item listado, sob a política |
| desconhecido | listagem falhou ou saída ilegível | nada é executado; volta ao owner |
| SHA divergente | `gitCommitSha` difere do registrado | reaplica a regra de proibidos aos agentes mapeados; reprovado vira "papel sem agente"; nunca `update` |

O marketplace é conferido antes, por nome (`voltagent-subagents`) e por `repo`
(`VoltAgent/awesome-claude-code-subagents`); divergência equivale a "desconhecido".

## Entity: Linha de autorização (`Instalação pelo agente: ligada|desligada`)

Conta as linhas inteiras que casam com `^Instalação pelo agente: (ligada|desligada)$` em
`origin/<base>:docs/constitution.md`, lida depois de a base ser conferida.

| Resultado da contagem | Efeito |
|---|---|
| exatamente 1 linha, e ela diz `ligada` | o agente executa os itens listados |
| exatamente 1 linha, e ela diz `desligada` | só imprime |
| 0 ou 2 ou mais linhas (inclusive dentro de comentário), ou a leitura falhou | só imprime (falha fechado) |

O agente nunca edita a linha, em nenhuma constituição (Princípio IV).

## Entity: Foto (impressão digital das raízes)

Saída canônica, ordenada, de `historico.mjs foto` (contrato em `contracts/historico.md`). Uma linha
por item: metadados de arquivo, hash de conteúdo, registro de plugin, `enabledPlugins`,
marketplace, HEAD do catálogo e o resultado de `git status --porcelain --ignored` e
`git worktree list`.

A **linha de base** é a primeira foto da frente, gravada ao lado do log. Cada rodada grava a
diferença contra a foto anterior: criados, apagados e alterados.

## Entity: Histórico (`~/.claude/cockpit/historico-<frente>.log`)

Log só acrescentado, por frente e por máquina (D9). Uma linha por evento; formato em
`contracts/historico.md`. É a única escrita antes do Gate 0.

### Relationships

- Registro da Fase 0 → Item de instalação: a seção `Instalações previstas` lista os itens.
- Item de instalação → Histórico: cada install e uninstall vira uma linha.
- Foto → Histórico: cada rodada grava a diferença; a linha de base é a referência do gate da
  Fase 11 do `rito-dev`.
- Mapa → Estado de plugin: só plugins do mapa são verificados.
