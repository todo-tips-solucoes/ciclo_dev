# Contrato: conteúdo dos arquivos gerados

Interface = o texto que o projeto-alvo recebe. Verificado pelo cenário de teste
(research Decision 6). Tudo aqui é novo.

## `docs/constitution.md` [PROPOSTA — a validar na implementação]

- Títulos `### II.`, `### II-bis.`, `### III.`, `### IV.`, `### IV-bis.`, `### V.`, `### VI.`,
  `### VII.`, `### VIII.` nessa ordem (FR-004).
- III exibe `{{PRINCIPIO_III}}` e as duas consequências (FR-005).
- IV-bis traz `{{IDENTIDADES}}` em bloco `text` (research Decision 3).
- Seção `## Princípios próprios do projeto` sem princípio preenchido.
- Sem `{{URL_AMBIENTE_*}}`.

## `CLAUDE.md` [PROPOSTA — a validar na implementação]

- Aponta para `docs/constitution.md`, `docs/rito-dev.md`, `docs/CICLO-GIT.md`,
  `docs/project-context.md` e `docs/agentes/` (FR-007).
- Declara que o agente para no gate de review.
- Board: "Board de acompanhamento (se houver): {{BOARD}}".

## `docs/rito-dev.md` [PROPOSTA — a validar na implementação]

- Etapa preparatória + `## Fase 1` a `## Fase 11` (FR-006, SC-005).
- Gates gerais: nunca `git add -A`, nunca push direto em `{{BRANCH_INTEGRACAO}}`/`{{BRANCH_PRODUCAO}}`,
  parada no review.
- Fase 9 no-op quando as duas branches coincidem.

## `docs/CICLO-GIT.md` [PROPOSTA — a validar na implementação]

- Modelo de branches, Conventional Commits em português, squash em feature, merge commit em
  promoção, identidades em bloco `text`, regra "cada autor com a própria identidade" (FR-008).

## `docs/agentes/{guardiao,implementador,revisor,triador}.md` [PROPOSTA — a validar na implementação]

- Seções `## Responsabilidade`, `## Entradas`, `## Saídas`, `## Limites` (FR-009).
- `revisor.md`: nunca aprova nem mergeia. `implementador.md`: usa `/feature-00c`.

## `docs/project-context.md` [PROPOSTA — a validar na implementação]

- Parâmetros do ciclo em bloco `text` (padrão do `LEIAME.md.tmpl`).
- Seções guiadas: Arquitetura, Convenções de domínio, Áreas sensíveis (FR-010).
