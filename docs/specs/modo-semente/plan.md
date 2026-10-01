# Implementation Plan: modo semente no configurar.sh

**Feature**: `modo-semente` | **Date**: 2026-10-01 | **Spec**: [spec.md](spec.md)

## Summary

Templates com sufixo `.semente.tmpl` geram o destino só quando ele não existe; existindo, são
pulados antes de qualquer leitura, render, checagem de conflito ou manifesto. A mudança fica
toda em `configurar.sh` (dois arrays paralelos `SEMENTE`/`PULAR`, decididos uma vez), mais a
renomeação de três templates, ajuste de texto/ajuda/contrato e um cenário novo no teste.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` (Princípio VII; script existente)
**Primary Dependencies**: nenhuma nova — coreutils, `awk`, `sha256sum`/`shasum` já usados
**Storage**: arquivos do projeto-alvo + `.cockpit/manifesto.sha256` (existente)
**Testing**: `scripts/testar-configurar.sh` (cenários numerados) + shellcheck (cenário 11)
**Target Platform**: Linux, WSL, macOS (constitution Princípio VII)
**Project Type**: cli (script local)
**Performance Goals**: N/A
**Constraints**: escrita só dentro do projeto-alvo; idempotente; comportamento de não semente
inalterado (FR-009)
**Scale/Scope**: ~30 linhas alteradas em `configurar.sh`, 3 renomeações, 1 cenário de teste

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar apos Phase 1.*

| Principio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | só mecanismo genérico; nenhum nome real; `verificar-agnostico.sh` segue no cenário 11 |
| II. Cockpit sob o próprio ciclo | PASS | entra por branch `feat/modo-semente` + PR |
| III. Identidade de commit | N/A | sem mudança no tratamento de identidades |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova |
| V. Fonte oficial antes de afirmar | PASS | semântica de `-e`/`-L` citada de `help test` (research D2) |
| VI. Português do Brasil | PASS | mensagens novas em pt-BR (`mantido (semente)`) |
| VII. Portáveis, idempotentes, contidos | PASS | 2a execução mantém sementes (idempotente); contenção vale para tudo que é gravado; recusa de edição local preservada — semente nunca sobrescreve edição |

## Design

### `configurar.sh`

1. **`preparar_templates()`**: `case "$rel" in *.semente.tmpl) d="${rel%.semente.tmpl}"; s=1 ;; *) d="${rel%.tmpl}"; s=0 ;; esac`;
   recusar `d` vazio ou terminado em `/`; `SEMENTE+=("$s")`. Checagem de destino reservado e
   de duplicados inalterada (já cobre a colisão `X.tmpl` x `X.semente.tmpl`).
2. **Nova `marcar_sementes()`** (chamada em `main` logo após `preparar_templates`):
   `PULAR[i]=1` se `SEMENTE[i]=1` e `[ -e "$RAIZ/$d" ] || [ -L "$RAIZ/$d" ]`.
3. **`main()`**: o laço `exigir_contido` sobre `DEST_REL` pula `PULAR[i]=1`.
4. **`aplicar_templates()`**:
   - laço de render: `PULAR` → `continue` (sem render, sem residual — FR-004);
   - laço de conflito: `PULAR` → `continue` (FR-003; sem prompt, ignora `--forcar`);
   - laço de gravação: `PULAR` → `mantidos+=(rel)`, `continue`;
   - relatório: `  mantido (semente): <rel>` e sufixo `, K mantido(s) (semente)` na contagem
     só se K > 0 (FR-007, FR-009).
5. **`gravar_manifesto()`**: no laço de hashes, `PULAR` → reemitir `manifesto_hash` anterior se
   não vazio, senão nada (FR-006).
6. **`uso()` e cabeçalho**: linha do `--forcar` ganha "exceto sementes, nunca sobrescritas".

### Templates (FR-008)

`git mv` de `templates/CLAUDE.md.tmpl`, `templates/docs/constitution.md.tmpl`,
`templates/docs/project-context.md.tmpl` para `*.semente.tmpl`; trocar o parágrafo que manda
usar `--forcar` (CLAUDE.md l.15-16, constitution l.8-9, project-context l.7) por "gerado uma vez
pelo configurador; depois disso é do projeto e nunca mais é alterado".

### Documentação

- `docs/specs/configurar/contracts/cli.md`: incorporar o delta de [contracts/cli.md](contracts/cli.md).
- README e `.cockpit/LEIAME.md.tmpl`: hoje não citam `--forcar` para esses arquivos; só mudar se
  a implementação encontrar menção.

### Teste (SC-001)

`cenario "17: modo semente"` em `scripts/testar-configurar.sh` com os 8 casos de
[quickstart.md](quickstart.md). Cenários 2, 3, 4 e 15 existentes devem continuar verdes sem
alteração (FR-009, idempotência).

## Project Structure

```text
docs/specs/modo-semente/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/cli.md

configurar.sh                                   # alterado
scripts/testar-configurar.sh                    # cenário 17
templates/CLAUDE.md.semente.tmpl                # renomeado + texto
templates/docs/constitution.md.semente.tmpl     # renomeado + texto
templates/docs/project-context.md.semente.tmpl  # renomeado + texto
docs/specs/configurar/contracts/cli.md          # regra de semente
```

## Convencoes de Borda

N/A — single-layer (script CLI local).

## Riscos

| Risco | Mitigação |
|-------|-----------|
| Semente pulada recalculada no manifesto passaria a "aceitar" a edição | Decision 4: copiar a linha anterior |
| Destino diretório/link quebrado derrubar o laço de contenção | `main` pula `PULAR`; caso 8 do quickstart |
| Saída de projetos sem semente pulada mudar | sufixo de contagem condicional; cenários 1-16 intactos |

## Complexity Tracking

Nenhuma violação.
