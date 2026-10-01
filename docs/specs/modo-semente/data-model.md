# Data Model: modo semente

**Feature**: `modo-semente` | **Date**: 2026-10-01

Sem persistência nova. Estado vive em arrays bash paralelos dentro de uma execução de
`configurar.sh` e no manifesto já existente.

## Entity: Template

| Campo | Tipo | Origem | Notas |
|-------|------|--------|-------|
| `TPL_ORIG[i]` | caminho absoluto | existente | arquivo sob `templates/` |
| `DEST_REL[i]` | caminho relativo | existente | sem `.tmpl`; sem `.semente.tmpl` se semente |
| `SEMENTE[i]` | 0/1 | **novo** | 1 se o nome termina em `.semente.tmpl` (FR-001) |
| `PULAR[i]` | 0/1 | **novo** | 1 se `SEMENTE[i]=1` e destino existe (`-e` ou `-L`) (FR-002) |

**Estados de uma semente numa execução**:

- destino ausente → `PULAR=0` → renderizada, checada por residual, gravada, hash no manifesto
  (mesmo caminho de qualquer template; nunca é conflito porque não existe).
- destino existe (arquivo, diretório, link, link quebrado) → `PULAR=1` → nada lido, nada
  renderizado, sem conflito, sem prompt, relatório `mantido (semente)`.

## Entity: Manifesto (`.cockpit/manifesto.sha256`) — existente

Linha `<sha256>  <rel>`. Mudança: para `PULAR[i]=1` a linha anterior é copiada como está (ou
ausente continua ausente). Demais regras (órfãs, ordenação `sort -k2`) inalteradas.
