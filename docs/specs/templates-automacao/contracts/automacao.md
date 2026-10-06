# Contrato: arquivos de automação gerados

Interface = o que o projeto-alvo recebe. [PROPOSTA — a validar na implementação]; os
comportamentos do GitHub citados vêm de research §Fontes (F1–F13).

## Regras comuns a todo fluxo

- `permissions:` explícito no nível do workflow (o que não é listado fica `none`, F4).
- Nenhum `{{CHAVE}}` fora de bloco literal; nenhum `${{ github.event.* }}` dentro de `run:`.
- Actions só `actions/checkout` (sempre com `persist-credentials: false`) e `actions/setup-node`, por SHA com a tag em comentário.
- Nomes de job e passo em pt-BR; o nome do job é o nome do check.

## `.github/workflows/ci.yml`

- `on`: `pull_request` e `push`, `branches` = integração e produção.
- `permissions: contents: read`.
- Job `ci`: checkout → setup-node → `Instalar dependências` (`case` por gerenciador) →
  `Typecheck` → `Lint` → `Build`, cada comando literal em `run: |`. Sem deploy.

## `.github/workflows/commitlint.yml`

- `on: pull_request` (`opened`, `edited`, `synchronize`, `reopened`).
- `permissions: contents: read`.
- Job `commitlint`: valida título (via `env`) e commits `base.sha..head.sha` contra
  `@commitlint/config-conventional`; falha cita `tipo(escopo): descrição`.

## `.github/workflows/require-codeowner-approval.yml`

- `on`: `pull_request` (`opened`, `synchronize`, `reopened`) e `pull_request_review`
  (`submitted`, `edited`, `dismissed`).
- `permissions: contents: read, pull-requests: read`.
- Job `aprovacao-de-dono`: donos = `@usuario` da linha `*` de `.github/CODEOWNERS` lido na
  **base**; passa se o último review de algum dono, ignorando `COMMENTED`/`PENDING`, tem `state` aprovado (comparação sem
  diferenciar maiúsculas); senão falha com "Aprovação pendente. Podem aprovar: @a @b".
  Sem `CODEOWNERS` na base: falha com mensagem acionável. Nunca aprova nem mergeia.
- É verificação **extra**, forjável por conteúdo do PR (roda o arquivo do merge commit, F14):
  a garantia é a regra nativa "Require review from Code Owners" + aprovações obrigatórias
  (F8), passo obrigatório do quickstart (dec-025).
- Delta (frente `codeowner-aprovacao-atual`): só conta review feita sobre o commit head atual do PR;
  ver `docs/specs/codeowner-aprovacao-atual/contracts/require-codeowner-approval.md`.

## `.github/workflows/promotion-pr.yml`

- `on: push` na integração. `permissions: contents: read, pull-requests: write`.
- Branches iguais → "Integração e produção são a mesma branch: nada a promover." e sucesso.
- Senão: PR aberto `base=produção head=integração` existe → atualiza o corpo; não existe →
  cria com título `chore(release): promover <integração> para <produção>`.
- Token: `TOKEN_AUTOMACAO` ou `github.token`. Com `github.token`, requer a opção
  "Allow GitHub Actions to create and approve pull requests" (F5) e os checks do PR
  ficam aguardando aprovação (F2).

## `.github/workflows/audit-merge-vermelho.yml`

- `on: pull_request_target` (`closed`); job só com `merged == true`; sem checkout.
- `permissions: checks: read, statuses: read, issues: write, pull-requests: read`.
- Issue `Auditoria: PR #<n> mergeado com check vermelho` (uma por merge; não duplica):
  link do PR, `merged_by.login`, lista de checks vermelhos e se a obrigatoriedade foi lida.

## `.github/workflows/release.yml`

- `on: push` na produção. Workflow `contents: read`; job `contents: write, issues: write,
  pull-requests: write`. `fetch-depth: 0`, Node 22, `npx semantic-release@<pin>`.
- Token: `TOKEN_AUTOMACAO` ou `github.token` (tag/release com `github.token` não disparam
  outros fluxos, F1/F3).

## `.releaserc.json`

`{"branches": ["<produção>"], "plugins": ["@semantic-release/commit-analyzer",
"@semantic-release/release-notes-generator", "@semantic-release/github"]}` — JSON válido.

## `.github/CODEOWNERS`

Comentário em pt-BR + linha `* <DONOS_CODEOWNERS>`.

## `.claude/scripts/task.sh`

| Uso | Saída | Código |
|-----|-------|--------|
| `task.sh --help` | uso em pt-BR | 0 |
| `task.sh discover` | id do projeto, id do campo `Status`, `nome<TAB>id` de cada opção | 0 |
| `task.sh list` | `número<TAB>status<TAB>título` dos itens | 0 |
| `task.sh move <número-ou-url> "<status>"` | confirma o movimento | 0 |
| subcomando desconhecido / argumento faltando | uso | 2 |
| `BOARD` vazio | "Este projeto não tem board configurado (BOARD vazio no cockpit.config)." | 3 |
| `gh` ausente, sem autenticação ou sem escopo `project` | mensagem com o comando para resolver (`gh auth login` / `gh auth refresh -s project`) | 4 |
| `move` com status inexistente no board | `Status "<nome>" não existe no board. Opções: <a>, <b>, ...` (opções do `discover`) | 1 |
| `move` com item fora do projeto | `Item <número-ou-url> não está no board <BOARD>.` | 1 |
| outro erro do `gh` | mensagem do `gh` repassada | 1 |

Checagem de `BOARD` e de `gh` acontece antes de qualquer chamada que altere algo.
