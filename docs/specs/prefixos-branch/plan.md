# Implementation Plan: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1, D2, D3, normativas)

## Summary

Chave opcional `PREFIXOS_BRANCH` no `cockpit.config`: cinco prefixos posicionais (`feature`,
`fix`, `chore`, `docs`, `hotfix`), validados com o próprio git e recusados com exit 1 citando a
chave. O configurador deriva dela (ou do padrão `feature fix chore docs hotfix`) cinco
placeholders de render, sempre com valor e nunca gravados, que substituem os literais de
`CICLO-GIT.md.tmpl` e `rito-dev.md.tmpl`; sem a chave, os dois documentos saem byte a byte os de
hoje. A Fase 1 da skill `rito-dev` lê a chave na hora. Tudo em `configurar.sh` reusando o
mecanismo das opcionais (`CHAVES_OPCIONAIS`) e o render existente; nenhuma dependência nova.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` e `LC_ALL=C` (script existente, Princípio VII)
**Primary Dependencies**: nenhuma nova: `git` (`check-ref-format`, já usado em `validar_chave`
para `BRANCH_*`)
**Storage**: `cockpit.config` (chave nova, opcional); manifesto sem mudança de formato
**Testing**: `scripts/testar-configurar.sh` (cenário 20 novo; 14 e 15 ajustados) + shellcheck e
`verificar-agnostico.sh` (cenário 11)
**Target Platform**: Linux, WSL, macOS (fonte: constitution, Princípio VII)
**Project Type**: cli (script local) + documentos e skill em Markdown
**Performance Goals**: N/A
**Constraints**: sem a chave, render e `--atualizar` idênticos aos de hoje; valor inválido antes de
qualquer escrita; prosa em pt-BR acentuado; nada que nomeie projeto real
**Scale/Scope**: `configurar.sh` (2 constantes, 1 função nova, 5 funções alteradas), 2 templates,
1 skill, `cockpit.config.example`, 2 documentos da feature `configurar`, 1 cenário novo e 2
ajustados

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | é a aplicação direta do "valor que varia por projeto é chave do config"; exemplos com prefixos genéricos; cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | branch `feat/prefixos-branch` em worktree, via `/feature-00c`; registro SDD neste diretório; trilha completa com `bmad-code-review` antes da PR |
| III. Identidade de commit | N/A | o script não commita |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova; `cstk` intocado |
| V. Fonte oficial antes de afirmar | PASS | comportamento de `git check-ref-format --branch` citado do manual local do git 2.55.0 e de sonda registrada ([research](research.md), Decision 2); nenhum número estimado |
| VI. Português do Brasil | PASS | pergunta, mensagens, comentário do exemplo e skill em pt-BR acentuado ([contrato](contracts/cli.md)) |
| VII. Portáveis, idempotentes, contidos | PASS | sem pré-requisito novo; nenhuma escrita nova (só render e gravação já existentes); 2ª execução com a mesma chave não altera nada (cenário 2 e idempotência do 15 seguem valendo) |

**Re-check pós-design**: PASS. O design não cria arquivo, processo nem mecanismo de render novo;
os placeholders reusam `setar`/`renderizar`, e a chave reusa o caminho das opcionais. Sem
violação a justificar.

## Design

Referências de linha: `configurar.sh` no commit `ec13897`.

### `configurar.sh`

1. **Constantes** (l.51-53): `PREFIXOS_BRANCH` no fim de `CHAVES_ORDEM` e em `CHAVES_OPCIONAIS`;
   comentário "URLs e DESTINOS_DO_PROJETO são as únicas opcionais" atualizado. Novas
   `PREFIXOS_PADRAO` e `DERIVADAS` ([research](research.md), Decisions 1 e 4).
2. **`validar_chave`** (l.274): ramo `PREFIXOS_BRANCH)` — 0 itens válido; 5 exatos; por item, `/`,
   `-` inicial, `@{` e `git check-ref-format --branch "<p>/x"`; repetição. Mensagens no
   [data-model](data-model.md) §Validação (Decision 2).
3. **`validar_todos`** (l.379): "só espaços = não declarada" vale para `DESTINOS_DO_PROJETO` e
   `PREFIXOS_BRANCH` (Decision 3).
4. **`perguntar_chave`** (l.455): ramo `PREFIXOS_BRANCH)` com o texto do
   [contrato](contracts/cli.md), dica montada de `PREFIXOS_PADRAO` (Decision 6).
5. **`derivar_prefixos`** (nova): os cinco valores da chave ou do padrão, `setar` por posição em
   `DERIVADAS`. Chamada em `main` logo depois de `validar_todos` (l.1095).
6. **`renderizar`** (l.741): definidas a partir de `$CHAVES_ORDEM $DERIVADAS`.

Sem mudança em `ler_kv`, `gravar_config`, `aplicar_templates`, manifesto, `--ajuda` e códigos de
saída: o caminho das opcionais e o render já cobrem a chave e os placeholders.

### Templates (FR-008, FR-009)

- `templates/docs/CICLO-GIT.md.tmpl` l.12-13 e `templates/docs/rito-dev.md.tmpl` l.34-35: cada
  literal `<tipo>/<slug>` vira `{{PREFIXO_<TIPO>}}/<slug>`; nenhum outro byte muda (Decision 5).

### Skill `rito-dev` (FR-010)

- `skills/rito-dev/SKILL.md`: tabela de chaves consumidas ganha `PREFIXOS_BRANCH` (opcional) →
  Fase 1, com o padrão; linha de `BRANCH_PRODUCAO` cita "base do prefixo de hotfix"; Fase 1
  (l.73-77) passa a nomear os prefixos pelo tipo, lidos da chave na hora, PARANDO com valor
  malformado (Decision 7).

### Configuração e documentação (FR-011)

- `cockpit.config.example`: seção nova no fim, `PREFIXOS_BRANCH=''`, com ordem, padrão e exemplo
  em comentário.
- `docs/specs/configurar/contracts/cli.md`: seção delta "Prefixos de branch (`PREFIXOS_BRANCH`)"
  apontando para o [contrato desta feature](contracts/cli.md).
- `docs/specs/configurar/data-model.md`: linha da chave nas tabelas de campos e de validação
  (Decision 9).

### Testes (FR-012, SC-001 a SC-005)

- Cenário 20 "prefixos de branch", antes do 11, com os casos do [quickstart](quickstart.md) 1 a 7.
- Cenário 14: mínima de 20 respostas (a de 19 falha); +1 resposta no fim das entradas do config
  incompleto e da reentrada de identidade.
- Cenário 15: `! grep -rq 'PREFIXOS_BRANCH'` nos templates.

## Project Structure

### Documentação (esta feature)

```text
docs/specs/prefixos-branch/
├── decisoes-do-owner.md   # D1-D3 (normativas)
├── spec.md
├── plan.md                # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── cli.md
```

### Código e documentos tocados

```text
configurar.sh
cockpit.config.example
templates/docs/CICLO-GIT.md.tmpl
templates/docs/rito-dev.md.tmpl
skills/rito-dev/SKILL.md
scripts/testar-configurar.sh
docs/specs/configurar/contracts/cli.md
docs/specs/configurar/data-model.md
```

## Convenções de Borda

N/A — single-layer (script local, sem fronteira de serviço).

## Riscos

- `templates/docs/constitution.md.semente.tmpl` l.18 cita `hotfix/<slug>`: fora do escopo de D3;
  candidato a issue de acompanhamento (research, Riscos aceitos).
- Entradas posicionais do cenário 14 dependem da ordem das perguntas; a chave no fim limita o
  ajuste a uma resposta a mais por entrada.

## Complexity Tracking

Nenhuma violação de constitution a justificar.
