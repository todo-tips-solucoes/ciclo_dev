# Research: templates-governanca

**Feature**: `templates-governanca` | **Date**: 2026-09-29

Nenhum eixo estrutural em aberto: linguagem, motor e plataforma já decididos pelas
frentes anteriores (`configurar`, `skills-do-cockpit`). As decisões abaixo são operacionais.

## Decision 1: Sem condicional no motor — textos que valem para qualquer valor

**Decision**: cada trecho que depende de valor (`PRINCIPIO_III`, integração = produção,
`BOARD` vazio) é redigido de forma que fique correto com qualquer valor: o valor é exibido
e as consequências de cada caso são declaradas ("Quando `ligado`… Quando `desligado`…").

**Rationale**: `renderizar()` (`configurar.sh`) só faz substituição literal de `{{CHAVE}}`;
FR-002 proíbe alterar o script.

**Alternatives considered**: adicionar `{{#if}}` ao motor (viola FR-002, e é engine nova);
dois templates alternativos (o motor renderiza todos; não há seleção).

## Decision 2: Valores de comando em bloco `text` ou código inline

**Decision**: comandos (`CMD_*`) e valores livres entram em bloco cercado `text` ou em
código inline, nunca em célula de tabela Markdown.

**Rationale**: valores podem conter `|`, crases, `&`, `$` (edge case da spec). O motor já
insere literal (research da frente `configurar`, Decision 1); a quebra possível é só de
renderização Markdown, e bloco cercado a evita — mesmo padrão do `LEIAME.md.tmpl`.

**Alternatives considered**: tabela (quebra com `|`); escapar no motor (viola FR-002).

## Decision 3: IDENTIDADES literal em bloco `text` (desvio da Clarification Q3)

**Decision**: `docs/CICLO-GIT.md` e a constituição gerada trazem `{{IDENTIDADES}}` literal num
bloco `text`, sob o título de identidades, com a legenda "uma identidade por item, `nome:e-mail`,
separadas por `;`".

**Rationale**: o formato real é `nome:email;nome:email` (`cockpit.config.example`; o
configurador valida e grava nesse formato). Um cabeçalho de tabela fixo com o valor numa só
linha produziria tabela quebrada. O bloco mostra o valor integralmente (FR-008, US2-AS2)
sem transformação.

**Alternatives considered**: cabeçalho `| Quem | user.name <user.email> |` + valor (premissa
da Q3 falsa, tabela inválida); transformar `;` em linhas no motor (viola FR-002).

## Decision 4: Princípios do projeto-alvo começam em II

**Decision**: a constituição gerada lista II, II-bis, III, IV, IV-bis, V, VI, VII, VIII
(conteúdo da seção Assumptions da spec) e termina com "Princípios próprios do projeto" vazia.
O Princípio I é do cockpit e não entra.

**Rationale**: briefing e spec (Assumptions); evita que o projeto herde regra de agnosticismo do cockpit.

**Alternatives considered**: renumerar a partir de I (quebraria a referência cruzada com as skills).

## Decision 5: Rito espelha a skill `rito-dev`, sem duplicar parâmetros opcionais

**Decision**: `docs/rito-dev.md` traz a etapa preparatória, as fases 1–11 com os nomes da skill
(Branch, Desenvolver, Commit, Abrir PR, CI, Review, Merge, Smoke no ambiente de integração,
Promoção para produção, Smoke em produção, Encerramento) e os gates gerais; as URLs de ambiente
não são citadas por valor (FR-003) — o texto diz "a URL do ambiente, perguntada na hora se não configurada".

**Rationale**: fonte = `skills/rito-dev/SKILL.md` deste repositório; coerência exigida pela US2.

**Alternatives considered**: apontar só para a skill (o time humano também lê o rito, US2).

## Decision 6: Teste como cenário novo do harness existente

**Decision**: um cenário em `scripts/testar-configurar.sh` roda o configurador com
`cockpit.config.example` num repositório temporário e verifica: os 9 destinos existem;
nenhum contém `{{`; a constituição contém os 9 títulos de princípio na ordem e a seção de
princípios próprios; o rito contém `Fase 1` a `Fase 11`; os papéis têm as 4 seções; segunda
execução com `--atualizar` mantém os hashes (FR-013, FR-014, SC-001..SC-005). Uma variação
com `PRINCIPIO_III='desligado'` e `BRANCH_PRODUCAO` igual à de integração confere que o render
segue sem residual.

**Rationale**: o harness já roda no CI e tem `novo_repo`, `rodar`, `sha`; script novo seria duplicação.

**Alternatives considered**: `scripts/testar-templates.sh` separado (mais um job, mesma infra).

## Decision 7: Papéis de agente com quatro seções fixas

**Decision**: cada `docs/agentes/*.md` tem exatamente `## Responsabilidade`, `## Entradas`,
`## Saídas`, `## Limites`. Guardião: verifica identidade, base e trilha antes de cada fase.
Triador: classifica a demanda na trilha e decide se abre frente, sem implementar. Implementador:
implementa só via `/feature-00c` em worktree. Revisor: roda `bmad-code-review`, nunca aprova nem
mergeia — a aprovação é de um humano.

**Rationale**: FR-009 e Clarification Q4.

**Alternatives considered**: seções livres por papel (não testáveis pelo cenário da Decision 6).
