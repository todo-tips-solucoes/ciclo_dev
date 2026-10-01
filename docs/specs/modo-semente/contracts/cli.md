# Contrato (delta): configurar.sh com sementes

**Base**: [`docs/specs/configurar/contracts/cli.md`](../../configurar/contracts/cli.md). Só o que
muda está aqui; o resto do contrato vale igual (FR-009).

## Marcação

- `templates/<caminho>.semente.tmpl` → destino `<caminho>`. Colisão com `<caminho>.tmpl`:
  `Templates com o mesmo destino (<caminho>): ...`, exit 1.

## Regra

| Destino da semente | Efeito | Manifesto |
|--------------------|--------|-----------|
| não existe (`! -e` e `! -L`) | renderiza e grava como os demais | hash novo |
| existe (qualquer tipo) | intacto, sem leitura, sem prompt, ignora `--forcar` | linha anterior mantida (ou nenhuma) |

Semente a gravar com placeholder sem valor: exit 2, `Placeholder sem valor: {{NOME}} em <template>`
(igual ao não semente).

## Saída (stdout)

- Por semente pulada: `  mantido (semente): <rel>`
- Contagem: `Templates: N gravado(s), M inalterado(s), K mantido(s) (semente).` — o trecho
  `, K mantido(s) (semente)` só aparece com K > 0.

## Códigos de saída

Sem código novo. Só sementes mantidas → 0. Semente pulada nunca causa 2 (nem por residual,
nem por edição local).

## `--ajuda`

Linha do `--forcar`: sobrescreve arquivos editados à mão sem confirmação, exceto sementes, que
nunca são sobrescritas.
