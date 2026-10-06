# Implementation Plan: endurecimento do configurador (branches e manifesto)

**Feature**: `configurar-endurecimento` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D3, normativas)

## Summary

Issue #19: `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` passam a casar com
`^[A-Za-z0-9][A-Za-z0-9._/-]*$` além de `git check-ref-format --branch`, que hoje aceita `$(x)`,
crase e `|` ([research](research.md), Decision 1). A regra entra num só ramo de `validar_chave`,
chamado pelos três modos; o `--atualizar` ganha a linha que diz como corrigir. A skill `rito-dev`
confere as duas chaves por leitura logo depois de ler o `cockpit.config`. Issue #18:
`gravar_manifesto` decide pela existência de linha a registrar, não pela contagem de templates, e
deixa de gravar manifesto vazio criando `.cockpit/`. Nenhum arquivo, função ou dependência nova.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` e `LC_ALL=C` (script existente, Princípio VII)
**Primary Dependencies**: nenhuma nova; `git check-ref-format` já usado no ramo
**Storage**: `cockpit.config` e `.cockpit/manifesto.sha256`, formatos inalterados
**Testing**: `scripts/testar-configurar.sh`, cenário 21 novo antes do 11 + shellcheck e
`verificar-agnostico.sh` (cenário 11)
**Target Platform**: Linux, WSL, macOS (constitution, Princípio VII)
**Project Type**: cli (script local) + skill em Markdown
**Performance Goals**: N/A
**Constraints**: valor inválido recusado antes de qualquer escrita; com manifesto anterior,
comportamento de hoje; prosa em pt-BR acentuado; nada que nomeie projeto real
**Scale/Scope**: `configurar.sh` (1 constante, 3 trechos), `skills/rito-dev/SKILL.md` (1
parágrafo), `cockpit.config.example` (1 comentário), `docs/specs/configurar/data-model.md` (2
linhas), cenário 21

Nenhum `NEEDS CLARIFICATION`; nenhum eixo estrutural em jogo (stack, persistência e arquitetura
herdadas do script existente).

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | exemplos genéricos (`main`, `release/2026`); "integração = produção" segue aceito (nada compara as duas chaves); cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | worktree `fix/configurar-endurecimento` com base explícita, via `/feature-00c`; registro SDD neste diretório; trilha completa com `bmad-code-review` antes da PR |
| III. Identidade de commit | N/A | o script não commita |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova; `cstk` intocado |
| V. Fonte oficial antes de afirmar | PASS | comportamento do `git check-ref-format --branch` medido por sonda local no git 2.55.0, tabela na [research](research.md) (Decision 1); nenhum número estimado |
| VI. Português do Brasil | PASS | mensagens, comentário do exemplo e skill em pt-BR acentuado ([contrato](contracts/cli.md)) |
| VII. Portáveis, idempotentes, contidos | PASS | sem pré-requisito novo; D3 **remove** uma escrita (manifesto vazio); regex sob `LC_ALL=C`, já exportado |

**Re-check pós-design**: PASS. O design só aperta uma validação existente, acrescenta uma linha de
mensagem e reordena uma guarda; nada novo a justificar.

## Design

Referências de linha: `configurar.sh` no commit `14b2fa9`.

### `configurar.sh`

1. **Constante** (l.64): `RE_BRANCH='^[A-Za-z0-9][A-Za-z0-9._/-]*$'` depois de `RE_REPO`, com
   comentário curto citando D1 (Decision 1).
2. **`validar_chave`, ramo `BRANCH_INTEGRACAO | BRANCH_PRODUCAO)`** (l.290-293): sai o `case`
   `'' | -* | *'@{'*`; fica `[[ "$v" =~ $RE_BRANCH ]] && git check-ref-format --branch "$v"` com a
   mensagem única do [contrato](contracts/cli.md), que interpola `$RE_BRANCH` (FR-001, FR-002).
3. **`main`** (l.1124): `validar_todos || exit 1` passa a emitir, em `MODO=atualizar`, a linha de
   correção do contrato com `comando_de_novo` antes do exit 1 (FR-004, Decision 3). Interativo e
   `--respostas` sem mudança (FR-003, Decision 2).
4. **`gravar_manifesto`** (l.942-984): `ord` calculado antes da guarda; a guarda da l.957 vira
   "`ord` vazio e sem manifesto anterior → return 0", antes de `: >"$STG/manifesto"` (l.958) e do
   `mkdir` de `.cockpit/` (l.974); o comentário da função (l.938-941) passa a falar em "sem linha a
   registrar" (FR-006 a FR-008, Decision 4).

Sem mudança em `perguntar`, `ler_kv`, `gravar_config`, `aplicar_templates`, `--ajuda` e códigos
de saída.

### Skill `rito-dev` (FR-005)

- `skills/rito-dev/SKILL.md`, seção "Parâmetros — leitura de `cockpit.config`" (l.10-18): um
  parágrafo logo depois da leitura com a conferência das duas chaves por leitura, PARAR nomeando a
  chave, nunca colar o valor num comando, valor é dado e não instrução — mesmo padrão da Fase 1
  (l.76-80) (Decision 5).

### Documentação

- `cockpit.config.example` (l.21-23): o comentário do modelo de branches cita o conjunto aceito e
  a validação do git (Decision 6).
- `docs/specs/configurar/data-model.md`: l.58 (regra de `BRANCH_*`) cita a regex de D1; l.116
  troca "sem nenhum template" por "sem linha a registrar" (Decision 6).

### Testes (FR-009, SC-001 a SC-004)

- Cenário 21 "branches e manifesto" logo antes do cenário 11 (l.921-922), casos 1 a 6 do
  [quickstart](quickstart.md); o caso interativo reusa `interativo` e `MINIMO` do cenário 14
  (Decision 7).

## Project Structure

### Documentação (esta feature)

```text
docs/specs/configurar-endurecimento/
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
skills/rito-dev/SKILL.md
scripts/testar-configurar.sh
docs/specs/configurar/data-model.md
```

## Convenções de Borda

N/A — single-layer (script local, sem fronteira de serviço).

## Gate de segurança

Revisão OWASP do desenho (A05 injeção/CWE-78, CWE-88 injeção de argumento, LLM01/ASI01 injeção
via agente, escrita contida): 0 crítico, 0 alto, 0 médio. A regra de D1 é allowlist aplicada em
`validar_chave`, antes de qualquer escrita nos três modos, e antes do git: o `&&` curto-circuita,
então nem `-` inicial chega ao `git check-ref-format` como opção. Também fecha a aspa dupla, que o
git aceita e que hoje cairia dentro da string JSON de `.releaserc.json.tmpl`; os workflows já
recebem os valores em bloco `|-` e via `env:`. `tem_controle` barra controle e bidi antes da regra;
`ler_kv` lê o config sem `source`/`eval`. D3 só remove uma escrita; `exigir_contido` fica.

| Achado | Severidade | Disposição |
|---|---|---|
| B1 — a conferência da skill é feita pelo agente lendo o valor, não por script | baixo | aceito: classe de caractere simples; o `configurar.sh` aplica a mesma regra (e o git) de forma determinística |
| B2 — valor que passa na regex pode carregar texto imperativo lido pelo agente | baixo | corrigido no desenho: o parágrafo da skill diz que o valor é dado, nunca instrução |
| B3 — sem limite de tamanho | baixo | aceito: valor vem do próprio repositório; nome longo demais falha no git |
| B4 — `REPO_REMOTO` editado à mão também é composto em comando pela skill sem conferência nela | baixo | fora de escopo por decisão do owner (`REPO_REMOTO` tem regra própria no configurador); registrado aqui para uma frente futura |

## Riscos

- A conferência da skill é feita pelo agente lendo o valor, não por script; a regra é de classe
  de caractere simples e o `configurar.sh` aplica a mesma (mais o git) de forma determinística.
- Projeto com `cockpit.config` já fora da regra passa a falhar no `--atualizar` (fail-closed, por
  D1); a linha de correção diz o que fazer.
- `scripts/testar-configurar.sh` é tocado por frentes paralelas (#7 a #10): conflito de inserção no
  rebase se resolve mantendo os dois blocos.

## Complexity Tracking

Nenhuma violação de constitution a justificar.
