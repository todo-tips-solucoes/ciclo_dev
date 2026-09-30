# Implementation Plan: templates-automacao

**Feature**: `templates-automacao` | **Date**: 2026-09-30 | **Spec**: [spec.md](./spec.md)

## Summary

Nove templates novos sob `templates/` que o motor existente do `configurar.sh` renderiza por
substituição literal: seis fluxos do GitHub Actions (`ci`, `commitlint`,
`require-codeowner-approval`, `promotion-pr`, `audit-merge-vermelho`, `release`),
`.github/CODEOWNERS`, `.releaserc.json` e `.claude/scripts/task.sh` (executável). A única
mudança no `configurar.sh` é a do FR-015: chave obrigatória `DONOS_CODEOWNERS` (só
`@usuario`) e validação de `BOARD` (`dono/número` ou vazio). Valores de config entram no
YAML só por bloco literal (research Decision 1), dado de evento só por `env:` (Decision 2),
e os fluxos usam `gh`/`npx` em vez de actions de terceiro (Decision 3). Limites do
`GITHUB_TOKEN` conferidos em fonte oficial (research §Fontes, F1–F13).

## Technical Context

**Language/Version**: YAML do GitHub Actions, JSON, bash (`set -euo pipefail`) no `task.sh` e no teste
**Primary Dependencies**: motor `renderizar()` do `configurar.sh` (sem mudança); nos fluxos: `gh` (pré-instalado no runner, F13), Node 22 + `npx` para `@commitlint/cli` e `semantic-release` (F11); no `task.sh`: `gh` com escopo `project` (F12)
**Storage**: arquivos texto no projeto-alvo, destino = caminho do template sem `.tmpl`
**Testing**: cenário novo em `scripts/testar-configurar.sh` (actionlint, `python3 -m json.tool`, shellcheck) + `scripts/verificar-agnostico.sh`, ambos no CI do cockpit
**Target Platform**: gerador em Linux/WSL/macOS (fonte: docs/constitution.md, Princípio VII); fluxos em runner `ubuntu-latest` (fonte: docs/briefing.md, stack GitHub Actions)
**Project Type**: conteúdo estático consumido por CLI existente
**Performance Goals**: N/A (não medido; irrelevante)
**Constraints**: só chaves conhecidas, nenhuma `URL_AMBIENTE_*` (FR-003); nenhum valor de projeto (FR-016); `${{ }}` intacto (FR-017); prosa pt-BR
**Scale/Scope**: 9 templates + ~30 linhas no `configurar.sh` + 1 cenário de teste + 1 ajuste no CI do cockpit

## Constitution Check

*GATE: antes do Phase 0 e re-checado após o Phase 1 (sem mudança).*

| Princípio (constituição do cockpit 1.1.0) | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo verificável | PASS | todo valor variável é `{{CHAVE}}`; exemplos fictícios (`@maria-exemplo`, `org-exemplo/7`); `verificar-agnostico.sh` no CI (FR-016, SC-003) |
| II. Próprio ciclo | PASS | worktree + `/feature-00c`; registro em `docs/specs/templates-automacao/`; `bmad-code-review` antes da PR |
| III. Identidade de commit | PASS | nenhum template altera `git config`; commits do semantic-release são só tag/release (sem plugin `git`) |
| IV. Terceiros não instalados pelo usuário | PASS | `gh` é dependência declarada do `task.sh` (falha cedo se faltar, FR-013); `npx` roda só no runner de CI, nunca na máquina do dev |
| V. Fonte oficial | PASS | F1–F13 lidos via `ctx_fetch_and_index` com link; pendências listadas em research Decision 3 são verificadas na implementação, com link na task |
| VI. Português do Brasil | PASS | nomes de passo, mensagens e prosa em pt-BR (FR-018) |
| VII. Portável, idempotente, contido | PASS | `task.sh` bash puro + `gh`; render idempotente com bit de execução (FR-014, SC-004) |

## Decisões e pendências

- dec-014 (humano): `DONOS_CODEOWNERS` só `@usuario` — confirmado por F7.
- dec-015 (humano): auditoria abre issue — research Decision 6.
- dec-016 (humano) + dec-022: `GITHUB_TOKEN` com `TOKEN_AUTOMACAO` opcional no `release` e no `promotion-pr` — research Decision 4.
- dec-021: nenhuma premissa humana falsa na fonte oficial.
- Pendências de verificação na implementação (não bloqueiam o plano): pins de SHA/versão e dois detalhes de CLI/filtro (research Decision 3 e 7).

## Project Structure

### Documentation (this feature)

```text
docs/specs/templates-automacao/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── automacao.md
```

### Source Code (repository root)

```text
templates/
├── .github/
│   ├── CODEOWNERS.tmpl
│   └── workflows/
│       ├── ci.yml.tmpl
│       ├── commitlint.yml.tmpl
│       ├── require-codeowner-approval.yml.tmpl
│       ├── promotion-pr.yml.tmpl
│       ├── audit-merge-vermelho.yml.tmpl
│       └── release.yml.tmpl
├── .releaserc.json.tmpl
└── .claude/scripts/task.sh.tmpl      # modo 100755 no git
configurar.sh                          # FR-015: DONOS_CODEOWNERS + validação de BOARD
cockpit.config.example                 # + DONOS_CODEOWNERS; BOARD documentado como dono/número
scripts/testar-configurar.sh           # + cenário de render dos templates de automação
.github/workflows/ci.yml               # job configurar: shellcheck + actionlint fixado
```

`CODEOWNERS` vai em `.github/` (primeiro local procurado, F8), para não competir com um
`CODEOWNERS` na raiz ou em `docs/` que o projeto já tenha.

## Mudança no `configurar.sh` (FR-015)

- `CHAVES_ORDEM`: `DONOS_CODEOWNERS` depois de `IDENTIDADES`.
- `validar_chave`: `DONOS_CODEOWNERS` = um ou mais itens separados por espaço, cada um
  `@` + letras, dígitos e hífen; item com `/` recusado com "times (@org/time) não são
  aceitos: informe usuários individuais"; vazio recusado. `BOARD` = vazio ou
  `dono/número` (dono: letras, dígitos, hífen; número inteiro positivo sem zero à esquerda).
- `perguntar_chave`: pergunta "Donos do CODEOWNERS (@usuario separados por espaço)".
- `cockpit.config.example`: `DONOS_CODEOWNERS='@maria-exemplo @jose-exemplo'`; comentário do
  `BOARD` passa a `dono/número`.
- Config antiga sem a chave: comportamento de chave faltante existente (pergunta só ela).

## Convenções de Borda

N/A — single-layer (arquivos gerados; a única borda é config → texto, coberta pela
research Decision 1).

## Complexity Tracking

Sem violação de princípio.

## Superfície de Segurança (gate `owasp-security`, 2026-09-30)

| # | Achado | Severidade | Tratamento |
|---|--------|------------|------------|
| S1 | Check `aprovacao-de-dono` é forjável: em `pull_request`/`pull_request_review` o fluxo roda a versão do arquivo que está no PR, então quem abre PR de branch do próprio repositório (inclusive um agente) pode editar o fluxo ou criar outro job com o mesmo nome e deixar o check verde (CICD-SEC-1/4). Só a regra nativa de review (aprovações obrigatórias + "Require review from Code Owners", F8) não é forjável por conteúdo do PR | alta | **resolvido por dec-025 (block-004, humano)**: o fluxo fica como verificação extra (visibilidade); a garantia é a regra nativa da branch — aprovações obrigatórias + "Require review from Code Owners" (F8) —, passo **obrigatório** de setup no quickstart. F14 confirma que o fluxo roda a versão do merge commit do PR (research Decision 5) |
| S2 | Ligar "Allow GitHub Actions to create and approve pull requests" (F5) permite que fluxos também **aprovem** PR, o que enfraquece o gate humano | média | quickstart recomenda `TOKEN_AUTOMACAO` (App ou PAT de granularidade fina restrito ao repositório: contents, pull-requests, issues) e manter a opção desligada; o `GITHUB_TOKEN` fica como alternativa mínima |
| S3 | `npx semantic-release@<pin>` resolve dependências transitivas sem lockfile, num job com `contents: write` (CICD-SEC-3) | média | versão fixada; job sem outros segredos; risco residual **aceito pelo dono do produto (block-005, dec-031)** |
| S4 | Credencial persistida pelo `actions/checkout` fica disponível a passos seguintes (CICD-SEC-6) | baixa | `persist-credentials: false` em todo checkout |
| S5 | Nomes de check e título de PR entram no corpo da issue de auditoria | baixa | corpo montado em arquivo e passado por `gh issue create --body-file`; nenhum dado de evento em `run:` (research Decision 2) |
| S6 | `pull_request_target` no `audit-merge-vermelho` | baixa | sem checkout e sem executar nada do PR; permissões mínimas (research Decision 6, F9) |
