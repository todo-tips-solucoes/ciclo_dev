# Decisões do owner — audit-merge-vermelho

Frente para a issue #10 (`templates/.github/workflows/audit-merge-vermelho.yml.tmpl`). As
decisões abaixo foram tomadas pelo owner em 2026-10-06, antes do `/feature-00c`, e são
normativas: o `specify` parte delas e o `clarify` não as reabre.

Contexto: dois pontos frágeis no fluxo, deferidos no code review da PR #6. (1) A consulta das
regras da branch usa `gh api "repos/$REPO/rules/branches/$BASE"` com o nome cru: branch base com
`/` quebra a rota, e o fluxo cai para listar todos os checks vermelhos (reporta a mais). (2) A
busca de issue duplicada usa `gh issue list --search "\"$TITULO\" in:title"`, que depende do
índice de busca: logo depois de criar uma issue, a busca pode não encontrá-la.

## D1 — nome da branch codificado na rota

- O nome da branch base é codificado para uso em caminho de URL antes de entrar na rota
  `rules/branches/…`. Branch com `/` (ex.: `release/2026`) passa a consultar as regras dela, sem
  cair no fallback.

## D2 — busca de duplicada sem depender do índice de busca

- A checagem de issue duplicada usa uma consulta que não passa pelo índice de busca (listagem
  direta de issues, filtrada pelo título exato), mantendo a regra de hoje: título idêntico, em
  qualquer estado, não gera issue nova.
- A forma exata da consulta (rota, filtros, paginação) é decidida no `plan`, com a documentação
  oficial do GitHub como fonte e o link na research (Princípio VI).

## Fora de escopo

- Mudar o que conta como merge vermelho ou o conteúdo da issue aberta.
- Gatilhos e permissões do fluxo além do necessário.

## Restrições

- YAML dos fluxos com shell embutido em bash, sem dependência nova; actionlint e shellcheck sem
  findings (rodam no CI).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Teste em `scripts/testar-configurar.sh`, num cenário novo **24** (número reservado), logo antes
  do cenário 11, no padrão do cenário 16 (passo do fluxo extraído do YAML renderizado e executado
  com `gh` falso): branch base com `/` chega codificada à rota; issue de mesmo título já existente
  não gera outra.
- Frente paralela a outras quatro (#7, #8, #9 e a de #18/#19). No rebase sobre `main`, conflito
  de inserção em `scripts/testar-configurar.sh` se resolve mantendo os dois blocos.
- Registro SDD em `docs/specs/audit-merge-vermelho/`.
