# Implementation Plan: templates-governanca

**Feature**: `templates-governanca` | **Date**: 2026-09-29 | **Spec**: [spec.md](./spec.md)

## Summary

Nove templates de texto sob `templates/` (sufixo `.tmpl`) que o `configurar.sh`
existente já sabe renderizar por substituição literal de `{{CHAVE}}`: constituição,
`CLAUDE.md`, rito, ciclo git, quatro papéis de agente e contexto do projeto. Nenhuma
mudança no script (FR-002): o motor já trata destino por caminho relativo, residual,
manifesto (edição local, idempotência) e caracteres especiais. A garantia vem de um
cenário novo em `scripts/testar-configurar.sh`, que já roda no CI: renderiza com
`cockpit.config.example` e falha em arquivo faltante, placeholder residual, princípio
ausente, fase ausente ou segunda execução que altere arquivo (FR-013, FR-014).

## Technical Context

**Language/Version**: Markdown (templates); bash com `set -euo pipefail` para o teste (já existente)
**Primary Dependencies**: `configurar.sh` (motor awk de substituição literal, `renderizar()`); nenhuma nova
**Storage**: arquivos texto no projeto-alvo, mesmo caminho do template sem `.tmpl`
**Testing**: `scripts/testar-configurar.sh` (cenário novo) + `scripts/verificar-agnostico.sh`, ambos já no CI
**Target Platform**: Linux, WSL, macOS (fonte: docs/constitution.md, Princípio VII)
**Project Type**: conteúdo estático consumido por CLI existente
**Performance Goals**: N/A — nove arquivos pequenos, render de milissegundos (não medido; irrelevante)
**Constraints**: só as 13 chaves obrigatórias do `CHAVES_ORDEM` (URLs opcionais proibidas, FR-003); nenhum valor de projeto; prosa em pt-BR com diacríticos
**Scale/Scope**: 9 templates novos + 1 cenário de teste

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checado após Phase 1 (sem mudança).*

| Princípio (constituição do cockpit 1.1.0) | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo verificável | PASS | todo valor variável é `{{CHAVE}}`; exemplos fictícios; `verificar-agnostico.sh` no CI (FR-011, SC-003); integração = produção tratado como válido no rito e na constituição gerada (FR-006) |
| II. Próprio ciclo | PASS | trilha completa (`templates/`, `scripts/`); worktree + `/feature-00c` em curso; `bmad-code-review` antes da PR; registro em `docs/specs/templates-governanca/` |
| III. Identidade de commit | PASS | templates só descrevem a regra; nada altera `git config` |
| IV. Terceiros não instalados | PASS | nenhum template manda instalar ferramenta; o rito cita `/feature-00c` e skills já instaladas |
| V. Fonte oficial | PASS | conteúdo derivado de fontes do próprio repositório (skills `rito-dev`, `parallel-work`, `configurar.sh`, briefing); nenhuma afirmação sobre ferramenta externa nova |
| VI. Português do Brasil | PASS | prosa dos templates em pt-BR com diacríticos (FR-012); commits Conventional em português |
| VII. Portável, idempotente, contido | PASS | sem script novo; o cenário de teste reusa o harness existente; idempotência verificada por hash (FR-014) |

## Decisões e pendências

- Decisões técnicas: [research.md](./research.md) Decisions 1–7.
- **Desvio da Clarification Q3 (IDENTIDADES)**: a premissa "linhas já no formato de
  tabela" não vale — o formato real da chave é `nome:email;nome:email`
  (`cockpit.config.example`, validação em `configurar.sh`). Sem transformação no motor
  (FR-002), o valor entra literal num bloco `text` sob a seção de identidades, com a
  legenda do formato (research Decision 3). A PR MUST sinalizar o desvio ao owner.

## Project Structure

### Documentation (this feature)

```
docs/specs/templates-governanca/
├── spec.md
├── plan.md               # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── templates.md      # contrato de conteúdo de cada arquivo gerado
```

### Source Code (repository root)

```
templates/
├── .cockpit/LEIAME.md.tmpl          # existente, inalterado
├── CLAUDE.md.tmpl                   # novo
└── docs/
    ├── constitution.md.tmpl         # novo (caminho já citado na constituição do cockpit)
    ├── rito-dev.md.tmpl             # novo
    ├── CICLO-GIT.md.tmpl            # novo
    ├── project-context.md.tmpl      # novo
    └── agentes/
        ├── guardiao.md.tmpl         # novo
        ├── implementador.md.tmpl    # novo
        ├── revisor.md.tmpl          # novo
        └── triador.md.tmpl          # novo
scripts/
└── testar-configurar.sh             # + 1 cenário (render dos templates reais)
```

**Structure Decision**: destino = caminho sob `templates/` sem `.tmpl` (comportamento
atual de `preparar_templates()`); nenhum destino reservado é tocado. Teste no harness
existente em vez de script novo.

## Convenções de Borda

N/A — single-layer (texto estático renderizado por um script existente).

## Complexity Tracking

Sem violações.
