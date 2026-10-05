# Decisões do owner — prefixos-branch

Frente para a issue #16 (correlata da #14). As decisões abaixo foram tomadas pelo owner em
2026-10-05, antes do `/feature-00c`, e são normativas: o `specify` parte delas e o `clarify` não
as reabre.

Contexto: os prefixos de branch de trabalho são literais em três lugares —
`templates/docs/CICLO-GIT.md.tmpl` (linhas 12-13), `templates/docs/rito-dev.md.tmpl` (linhas
34-35) e `skills/rito-dev/SKILL.md` (Fase 1, linhas 75-76). O Princípio I manda que valor que
varia por projeto seja chave do `cockpit.config`. Até aqui, o contorno é declarar os dois
documentos em `DESTINOS_DO_PROJETO` (#14), e a skill continua citando `feature/`.

## D1 — uma chave, cinco prefixos em ordem fixa

- Nova chave **opcional** `PREFIXOS_BRANCH` no `cockpit.config`: exatamente cinco prefixos,
  separados por espaço, na ordem fixa `feature`, `fix`, `chore`, `docs`, `hotfix` (o tipo é a
  posição). Ex.: `PREFIXOS_BRANCH='feat fix chore docs hotfix'`.
- Validação na fronteira de confiança, com exit 1 citando a chave: quantidade diferente de cinco;
  prefixo com `/`, com caractere de controle ou que não forma nome de branch válido
  (`git check-ref-format --branch '<prefixo>/x'`); prefixo repetido entre tipos (`fix` e `hotfix`
  partem de bases diferentes).
- Entra em `CHAVES_OPCIONAIS`: é perguntada no modo interativo com `- para vazio`, com a dica do
  padrão, e gravada pelo `gravar_config` como as demais. Valor em branco equivale a chave não
  declarada.

## D2 — ausente vale o padrão de hoje

- Ausente ou em branco, vale `feature fix chore docs hotfix`. Projetos já configurados seguem
  funcionando no `--atualizar`, sem pergunta nem erro.
- Com a chave ausente, `docs/CICLO-GIT.md` e `docs/rito-dev.md` renderizados são byte a byte os
  de hoje.
- O configurador deriva da chave (ou do padrão) cinco placeholders de render, sempre com valor:
  `{{PREFIXO_FEATURE}}`, `{{PREFIXO_FIX}}`, `{{PREFIXO_CHORE}}`, `{{PREFIXO_DOCS}}` e
  `{{PREFIXO_HOTFIX}}`. Eles não são chaves do config: não são perguntados nem gravados.
- A regra do cenário 15 (nenhum template usa chave opcional) continua valendo: os templates usam
  os placeholders derivados, nunca `PREFIXOS_BRANCH`.

## D3 — escopo: os três lugares medidos

- `templates/docs/CICLO-GIT.md.tmpl` e `templates/docs/rito-dev.md.tmpl` passam a usar os
  placeholders derivados.
- `skills/rito-dev/SKILL.md`: a Fase 1 lê `PREFIXOS_BRANCH` do `cockpit.config` na hora, com o
  padrão de D2 quando ausente, e a chave entra na tabela de chaves consumidas.
- Atualizar `cockpit.config.example` e o contrato `docs/specs/configurar/contracts/cli.md`.

## Fora de escopo

- Os exemplos `fix/…` e `feat/…` de `skills/parallel-work/SKILL.md` (ilustração, não regra).
- Tipos de branch além dos cinco, e renomear branches existentes.

## Restrições

- bash com `set -euo pipefail`, shellcheck sem findings, `LC_ALL=C`, nenhuma dependência nova
  (Princípio VII).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Testes em `scripts/testar-configurar.sh`, no estilo dos cenários existentes: um cenário novo
  (chave ausente com render idêntico, chave válida refletida nos dois documentos, valores
  inválidos com exit 1, modo interativo). O cenário 14 passa de 19 para 20 respostas mínimas,
  pela pergunta nova.
- Registro SDD em `docs/specs/prefixos-branch/`.
