# Implementation Plan: Skills do cockpit + alinhamento do briefing

**Feature**: `skills-do-cockpit` | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

## Summary

Entregar os itens 3 e 7 do MVP do briefing (três skills do cockpit +
`verificar-agnostico.sh` cobrindo os arquivos novos) mais uma carona de dois
pontos do item 1 (US4): alinhar o texto do briefing ao Princípio IV já
emendado (1.1.0) e registrar, em local navegável dentro de `docs/`, a exceção
de merge por commit da PR #1.

Abordagem técnica: duas das três skills (`parallel-work`, `bmad-code-review`)
são **cópia quase literal** das versões já instaladas globalmente — ambas já
são agnósticas por construção, auditadas nesta onda por grep de termos reais
(research.md Decisions 7 e 9). A terceira (`rito-dev`) é **conteúdo novo**,
derivado da seção "## Fases" de `~/.claude/skills/rito-dev-nav/SKILL.md`
(fonte fixada pelo owner no clarify, dec-013), mapeando Fase 1→11 da fonte
1:1 para as 11 fases do rito do cockpit e substituindo todo literal
específico do projeto de origem (branches, org/repo, URLs de ambiente, nomes
de workflow, reviewer) por leitura de `cockpit.config` em runtime — ou, onde
uma chave dedicada seria prematura (identidade de revisor, nome de workflow
de CI), por uma pergunta genérica ao dev/owner na hora, sem estado
persistido (research.md Decisions 3–6). `cockpit.config` reusa o formato
`CHAVE=valor` já em uso em `versoes.env` — sem parser novo, sem dependência
acrescentada (research.md Decision 2).

## Technical Context

**Language/Version**: Markdown (skills, formato reconhecido pelo Claude Code) + bash (mesmo piso de `esqueleto-e-instalador`: `set -euo pipefail`, shellcheck sem findings — só se algum trecho desta feature vier a introduzir `.sh` novo, o que não é o caso: nenhuma das 3 skills traz script shell próprio além do `driver.mjs` já existente de `parallel-work`).
**Primary Dependencies**: nenhuma acrescentada. `git`, `gh`, `node` (`driver.mjs`), `jq` e `curl` já são pré-requisitos fechados (Princípio VII, herdados de `esqueleto-e-instalador`).
**Storage**: N/A — `cockpit.config` é arquivo texto por projeto-alvo (nunca versionado no cockpit); a única escrita desta feature é dentro do próprio repositório do cockpit (`skills/`, `cockpit.config.example`, `THIRD-PARTY-NOTICES.md`, `docs/briefing.md`).
**Testing**: `scripts/verificar-agnostico.sh` (já existe, feature `esqueleto-e-instalador`) passa a cobrir os arquivos novos; cenários manuais executáveis em [quickstart.md](./quickstart.md) — não há framework de teste automatizado para conteúdo de skill/Markdown.
**Target Platform**: Linux, WSL e macOS (briefing §5) — sem mudança em relação à feature anterior.
**Project Type**: skills + documentação estática. Single-layer (sem API, sem borda backend↔frontend — Convenções de Borda: N/A).
**Performance Goals**: N/A — nenhuma execução em runtime contínuo; a skill `rito-dev` é invocada interativamente por Claude Code.
**Constraints**: Princípio I (agnosticismo) é o gate central desta feature — nenhum dos três artefatos de skill MUST citar nome de projeto/org/domínio real; `cockpit.config.example` só valores fictícios genéricos. FR-007 exige que `bmad-code-review` reproduza o comportamento da origem **sem mudança** — logo, cópia literal, nunca "melhoria" no conteúdo copiado.
**Scale/Scope**: 3 diretórios novos em `skills/` (`parallel-work/`, `rito-dev/`, `bmad-code-review/`), 1 arquivo (`cockpit.config.example`) na raiz, 1 arquivo (`THIRD-PARTY-NOTICES.md`) na raiz, 2 edições em documentação existente (`docs/briefing.md` item 1; registro da exceção da PR #1 — ver §Project Structure).

## Constitution Check

*GATE: passou antes do Phase 0; re-checado após Phase 1 (ver §Re-check).*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | As três skills foram auditadas por grep de termos reais nesta onda (research.md Decisions 7 e 9): `parallel-work` e `bmad-code-review` já são agnósticas por construção. `rito-dev` é escrita do zero substituindo todo literal do projeto de origem (organização/repositório, handle de reviewer, URL de ambiente de staging, identificador de projeto de infraestrutura) por chave de `cockpit.config` ou pergunta genérica ao dev (Decisions 3–6). `cockpit.config.example` usa só valores fictícios (`minha-org/meu-projeto`, `staging`, `main`). `scripts/verificar-agnostico.sh` roda sobre o repositório completo incluindo os arquivos novos (SC-002/FR-010) — os literais reais do projeto de origem citados acima nunca são versionados neste repositório; `AGNOSTICO_TERMOS` MUST ser populada localmente/no CI (fora do repositório) com esses literais para o gate afirmar isto de fato sobre os próprios artefatos SDD desta feature, não só sobre `skills/` (dec-029, block-002; tarefa dedicada em `/create-tasks`). |
| II. Cockpit sob o próprio ciclo | PASS | Frente de trilha completa: toca `skills/` (fora de `docs/`). Nasceu em worktree com base explícita (`feat/skills-do-cockpit`) e está sendo implementada via `/feature-00c`; o registro SDD entra em `docs/specs/skills-do-cockpit/`. |
| III. Identidade de Commit Declarada | PASS | Nada nesta feature altera identidade de commit. |
| IV. Ferramentas externas são dependências — e ninguém as instala pelo usuário | PASS | Esta feature não toca `instalar.sh` nem lógica de instalação/atualização de `cstk`/plugins — só adiciona conteúdo estático que `instalar.sh` (já entregue) copia. A única cópia de terceiro (`bmad-code-review`, MIT) ganha registro em `THIRD-PARTY-NOTICES.md` com a licença reproduzida na íntegra (FR-008, research.md Decision 8) — exatamente o modelo que o Princípio IV já previa ("a única cópia é a skill `bmad-code-review`, sob licença MIT, com o aviso preservado"). |
| V. Fonte Oficial Antes de Afirmar | PASS | A licença de `bmad-code-review` (MIT + nota de marca registrada, `BMad Code, LLC`) foi verificada nesta onda contra o arquivo `LICENSE` do repositório oficial `bmad-code-org/BMAD-METHOD`, com link registrado em research.md Decision 8. O texto exato a colar em `THIRD-PARTY-NOTICES.md` MUST ser reconferido contra a fonte no momento da escrita (não copiado de memória) — nota de execução na própria Decision 8. |
| VI. Português do Brasil | PASS | `rito-dev` (conteúdo novo) é redigida em pt-BR com diacríticos. `parallel-work` e `bmad-code-review` já estão em pt-BR/inglês técnico conforme a fonte original de cada uma (FR-007 exige reproduzir o comportamento, não traduzir uma cópia literal de terceiro). |
| VII. Scripts Portáveis, Idempotentes e Contidos | PASS | Nenhum `.sh` novo. `driver.mjs` (parte de `parallel-work`) já existe e já é auditado pela feature anterior; esta feature só o copia para `skills/`, sem editá-lo. |

**Nenhum FAIL em princípio MUST.** `Complexity Tracking` fica vazio.

## Project Structure

### Documentation (this feature)

```
docs/specs/skills-do-cockpit/
├── spec.md          # Existe (clarificada — ## Clarifications, Session 2026-09-28)
├── plan.md          # Este arquivo
├── research.md      # Phase 0 — 10 decisões
├── data-model.md     # Phase 1 — formato de cockpit.config + entidades
└── quickstart.md     # Phase 1 — 7 cenários executáveis
```

Sem `contracts/` — a feature não expõe interface externa (CLI/API/evento);
skill é conteúdo de instrução, não superfície de contrato.

### Source Code (repository root)

Árvore real hoje (MEDIDO nesta onda) mais o que esta feature acrescenta:

```
.
├── skills/                           # NOVO (diretório) — FR-001
│   ├── parallel-work/
│   │   ├── SKILL.md                  # NOVO — cópia de ~/.claude/skills/parallel-work/SKILL.md
│   │   └── driver.mjs                # NOVO — cópia de ~/.claude/skills/parallel-work/driver.mjs
│   ├── rito-dev/
│   │   └── SKILL.md                  # NOVO — conteúdo original, fonte-base rito-dev-nav §Fases
│   └── bmad-code-review/
│       ├── SKILL.md                  # NOVO — cópia de ~/.claude/skills/bmad-code-review/SKILL.md
│       ├── customize.toml            # NOVO — cópia
│       └── steps/*.md                # NOVO — cópia (4 arquivos)
├── cockpit.config.example            # NOVO (raiz) — FR-006
├── THIRD-PARTY-NOTICES.md            # NOVO (raiz) — FR-008
├── docs/
│   ├── briefing.md                   # EDITADO — item 1 do MVP alinhado ao Princípio IV emenda 1.1.0 (FR-012)
│   ├── constitution.md               # existe, não editado por esta feature
│   └── specs/
│       ├── esqueleto-e-instalador/
│       │   └── plan.md               # EDITADO — nota pós-merge registrando a exceção da PR #1 (FR-013, ver Decision abaixo)
│       └── skills-do-cockpit/        # existe (artefatos SDD desta frente)
├── instalar.sh                       # existe, não editado por esta feature
├── scripts/                          # existe, não editado por esta feature
├── versoes.env                       # existe, não editado por esta feature
└── README.md                         # existe, não editado por esta feature
```

**Structure Decision — onde registrar a exceção da PR #1 (FR-013)**: a nota
vai como uma seção curta ("## Nota pós-merge") **anexada ao `plan.md` já
existente de `esqueleto-e-instalador`** — o artefato SDD da própria frente
cujo PR precisou da exceção — em vez de um novo arquivo sitewide
(`docs/CHANGELOG.md`). Motivo: `.releaserc.json`/changelog automatizado é
item 5 do MVP (Templates de automação), ainda não aberto; criar um
changelog manual agora anteciparia esse desenho. Quem procura "por que a PR
#1 não seguiu squash" naturalmente olha os artefatos SDD daquela frente
(Princípio II: "o registro da frente... entra na PR da própria frente, em
`docs/specs/<short-name>/`") — satisfaz FR-013 ("local navegável dentro de
`docs/`") sem inventar convenção nova fora de escopo.

## Design das 11 fases de `rito-dev` (resumo executável para `/create-tasks`)

Tabela de rastreamento fase-a-fase; detalhe completo de cada Decision em
[research.md](./research.md). Todas as fases MUST citar apenas chaves de
`cockpit.config` ([data-model.md](./data-model.md)) ou perguntar
genericamente ao dev — nunca um literal do projeto de origem.

| Fase (fonte → cockpit) | Parametrizado por | Literal do projeto de origem descartado/generalizado |
|---|---|---|
| 0 → preparatória (não numerada) | `REPO_REMOTO`, `BRANCH_INTEGRACAO` | `gh api repos/<org>/<repo>/...` (literal real do projeto de origem) → `gh api repos/<REPO_REMOTO>/...` |
| 1 → Fase 1 (Branch) | `BRANCH_INTEGRACAO` | prefixos de branch (`feature/`, `fix/` etc.) e `--base origin/<BRANCH_INTEGRACAO>` — já genéricos na fonte |
| 2 → Fase 2 (Desenvolver) | — | checklist de domínio do projeto de origem (módulos, RLS, `SERVICE_ROLE_KEY`) **não é portado**: é regra de arquitetura de UM projeto (Supabase multi-tenant), não do rito. Generaliza para "consulte a convenção de domínio do próprio projeto-alvo, se houver" |
| 3 → Fase 3 (Commit) | — | Conventional Commits PT-BR mantido fixo (Princípio VI do cockpit, não é literal de projeto) |
| 4 → Fase 4 (Abrir PR) | `BRANCH_INTEGRACAO` | reviewer (handle real do projeto de origem) → pergunta genérica (Decision 4); `hotfix` usa `BRANCH_PRODUCAO` |
| 5 → Fase 5 (CI) | — | ressalva "EFs Deno" (Supabase-específica) descartada; texto genérico sobre integrações não cobertas pelo typecheck do CI |
| 6 → Fase 6 (Review, ponto de parada) | `REPO_REMOTO` (para `gh pr view`) | reviewer/owner → pergunta genérica (Decision 4); formato do gate (pontos de alteração + recomendação + comando pronto) mantido — é processo, não literal |
| 7 → Fase 7 (Merge) | `BRANCH_INTEGRACAO`, `CMD_DEPLOY_INTEGRACAO` | nome de workflow e número de execução reais do projeto de origem descartados; texto genérico "se o projeto tem deploy automático no push, ele dispara aqui" (Decision 5) |
| 8 → Fase 8 (Smoke integração) | `URL_AMBIENTE_INTEGRACAO` (opcional), `CMD_DEPLOY_INTEGRACAO` | `gh run list --workflow=<nome-real>.yml` → `gh run list` filtrado por branch, sem nome de workflow fixo (Decision 5) |
| 9 → Fase 9 (Promoção) | `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`, `CMD_DEPLOY_PRODUCAO` | radar automático (nome e número de PR reais do projeto de origem) → texto condicional: "se existir PR draft `<BRANCH_INTEGRACAO>→<BRANCH_PRODUCAO>`, promova-o; senão, abra um" (Decision 5); **caso `BRANCH_INTEGRACAO == BRANCH_PRODUCAO`**: fase inteira vira no-op explícito (Princípio I — modelo único) |
| 10 → Fase 10 (Smoke produção) | `URL_AMBIENTE_PRODUCAO` (opcional), `CMD_DEPLOY_PRODUCAO` | `project ref` Supabase específico descartado (Decision 6); regra "rollback anotado antes" mantida (processo, não literal) |
| 11 → Fase 11 (Encerramento) | `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO` conforme o caso | procedimento de worktree/branch já é genérico na fonte (usa `<branch>`, `<caminho-da-worktree>` como placeholders) |

`docs/rito-dev-nav.md`/`docs/skills/CICLO-GIT.md` (documentos-irmãos mais
extensos, citados pela fonte para contexto/troubleshooting) **não são
portados** — fora do escopo desta feature (research.md Decision 10; FR-001
lista só as três `SKILL.md`).

## Convenções de Borda

N/A — single-layer (skills + documentação estática, sem backend/frontend,
sem banco, sem API própria).

## Re-check

Revalidado após Phase 1 (data-model.md, quickstart.md): nenhuma tabela de
`cockpit.config` introduziu literal de projeto real; nenhuma chave nova além
das justificadas em research.md Decisions 3–4 (URLs opcionais; identidade de
revisor explicitamente **fora** do config). Constitution Check acima
permanece válido sem alteração — nenhum FAIL introduzido pelo design.

## Complexity Tracking

*Vazio — nenhuma violação de princípio MUST a justificar.*

## Artefatos

| Arquivo | Status |
|---------|--------|
| docs/specs/skills-do-cockpit/plan.md | Criado (este arquivo) |
| docs/specs/skills-do-cockpit/research.md | Criado |
| docs/specs/skills-do-cockpit/data-model.md | Criado |
| docs/specs/skills-do-cockpit/quickstart.md | Criado |

**NEEDS CLARIFICATION restantes**: 0 (FR-014 fechado no clarify; nenhum eixo
estrutural pendente — linguagem/stack/arquitetura/persistência/ambiente-alvo
já herdados de `esqueleto-e-instalador`).

### Próximos Passos

1. `/checklist` — gerar quality gate antes de implementar
2. `/create-tasks` — decompor este plano (tabela de 11 fases + registro de
   licença + alinhamento do briefing) em backlog executável — MUST incluir
   tarefa dedicada (dec-029, resolução de CHK012/CHK018): popular
   `AGNOSTICO_TERMOS` localmente/no CI com os literais reais do projeto de
   origem (nunca versionados neste repositório) e rodar
   `scripts/verificar-agnostico.sh` confirmando zero ocorrências também
   sobre os artefatos SDD desta própria feature (`spec.md`, `plan.md`,
   `research.md`, `data-model.md`, `checklists/`), não só sobre `skills/`
3. `/analyze` — validar consistência entre spec, plan e tasks (após tasks)
