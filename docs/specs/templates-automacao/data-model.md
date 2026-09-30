# Data Model: templates-automacao

**Feature**: `templates-automacao` | **Date**: 2026-09-30

Sem banco. As "entidades" são chaves do `cockpit.config` e arquivos gerados.

## Entity: Chave do cockpit (novas regras)

| Chave | Obrigatória | Formato aceito | Recusa | Usada em |
|-------|-------------|----------------|--------|----------|
| `DONOS_CODEOWNERS` (nova) | sim | um ou mais `@usuario` separados por espaço; usuário = letras, dígitos, hífen | vazio; item sem `@`; item com `/` (`@org/time`, dec-014) | `.github/CODEOWNERS` |
| `BOARD` (validação nova) | sim (pode ser vazia) | vazio ou `dono/número`, número inteiro positivo | qualquer outro formato | `.claude/scripts/task.sh` |
| `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO` | sim | inalterado (`git check-ref-format --branch`) | inalterado | `ci`, `promotion-pr`, `release`, `.releaserc.json` |
| `GERENCIADOR_PACOTES`, `CMD_TYPECHECK`, `CMD_LINT`, `CMD_BUILD` | sim | inalterado (não vazio, linha única) | inalterado | `ci` |

Ordem em `CHAVES_ORDEM`: `DONOS_CODEOWNERS` logo após `IDENTIDADES` (16 chaves).

## Entity: Template de automação

| Campo | Valor |
|-------|-------|
| origem | `templates/<caminho>.tmpl` |
| destino | `<projeto-alvo>/<caminho>` |
| modo | segue o modo no git do cockpit; só `task.sh.tmpl` é `100755` |
| chaves | subconjunto das obrigatórias; nunca `URL_AMBIENTE_*` (FR-003) |

Estados (motor existente, sem mudança): ausente → gravado → inalterado (2ª execução) ou
editado à mão → preservado (issue #5).

## Entity: Segredo opcional `TOKEN_AUTOMACAO`

Definido pelo projeto no provedor, nunca no arquivo. Ausente → `github.token`. Lido por
`release` e `promotion-pr` (research Decision 4).
