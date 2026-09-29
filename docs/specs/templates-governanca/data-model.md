# Data Model: templates-governanca

## Entity: Template de governança

| Campo | Tipo | Regra |
|-------|------|-------|
| origem | caminho sob `templates/` | termina em `.tmpl` |
| destino | caminho relativo no projeto-alvo | `origem` sem `templates/` e sem `.tmpl` |
| chaves | conjunto de nomes | subconjunto das 13 chaves obrigatórias (FR-003) |

**Relationships**: consome N chaves do `cockpit.config`; registrado 1:1 no manifesto
`.cockpit/manifesto.sha256` pelo configurador (já existente).

**State transitions** (do configurador, inalteradas): ausente → gerado; gerado → editado
à mão (preservado, aviso); gerado → re-renderizado (config mudou, sem edição local).

## Entity: Chave do cockpit

| Chave | Usada em |
|-------|----------|
| `PROJETO_NOME` | todos |
| `REPO_REMOTO` | `CLAUDE.md`, `CICLO-GIT.md`, `project-context.md` |
| `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO` | `constitution.md`, `rito-dev.md`, `CICLO-GIT.md`, `project-context.md` |
| `GERENCIADOR_PACOTES` | `rito-dev.md`, `project-context.md` |
| `CMD_TYPECHECK`, `CMD_LINT`, `CMD_BUILD` | `constitution.md` (Princípio III), `rito-dev.md`, `project-context.md` |
| `CMD_DEPLOY_INTEGRACAO`, `CMD_DEPLOY_PRODUCAO` | `rito-dev.md`, `project-context.md` |
| `IDENTIDADES` | `constitution.md` (IV-bis), `CICLO-GIT.md`, `project-context.md` |
| `BOARD` | `CLAUDE.md`, `project-context.md` |
| `PRINCIPIO_III` | `constitution.md`, `project-context.md` |
| `URL_AMBIENTE_INTEGRACAO`, `URL_AMBIENTE_PRODUCAO` | nenhum (FR-003) |

A tabela é o mínimo esperado; a implementação pode usar menos chaves por arquivo, nunca
chave fora da lista.
