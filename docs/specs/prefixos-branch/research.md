# Research: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1, D2, D3, normativas)

Referências de linha: `configurar.sh` no commit `ec13897`. Nenhum `NEEDS CLARIFICATION` de eixo
estrutural: linguagem, persistência e plataforma são as do script existente (bash, arquivos texto,
Linux/WSL/macOS — Princípio VII).

## Decision 1: posição da chave em `CHAVES_ORDEM`

- **Decision**: `PREFIXOS_BRANCH` entra no fim de `CHAVES_ORDEM` (depois de `DESTINOS_DO_PROJETO`)
  e em `CHAVES_OPCIONAIS`.
- **Rationale**: a ordem de `CHAVES_ORDEM` é a ordem das perguntas e da gravação. No fim, a
  pergunta nova é a última do modo interativo e as entradas do cenário 14 só ganham uma resposta
  no fim (19 → 20, FR-012). Em `CHAVES_OPCIONAIS`, a chave herda sem código novo: `- para vazio`
  em `perguntar` (l.401), omissão na gravação quando vazia em `gravar_config` (l.558), pergunta
  das opcionais ausentes no config incompleto (l.1086) e o laço de `unset "CFG_$_k"` (l.85).
- **Alternatives considered**: ao lado de `BRANCH_PRODUCAO`, junto do modelo de branches —
  rejeitado: desloca todas as respostas posicionais seguintes do cenário 14 e muda a ordem das
  perguntas de quem já usa o configurador.

## Decision 2: validação em `validar_chave`

- **Decision**: ramo `PREFIXOS_BRANCH)` em `validar_chave` (l.274). `read -ra` sobre o valor (sem
  expansão de glob); zero itens = ausente, válido. Senão: quantidade diferente de 5 → erro; por
  item: começa com `-`, contém `@{` ou contém `/` → erro; `git check-ref-format --branch
  "<item>/x"` falha → erro; item igual a um já visto → erro. Controle, quebra de linha, bidi e
  UTF-8 inválido já são recusados no topo da função por `tem_controle` (l.276), antes do ramo.
- **Rationale**: é a forma que D1 fixa. A guarda `-*`/`@{` repete a de `BRANCH_INTEGRACAO` e
  `BRANCH_PRODUCAO` (l.288): o manual do git diz que `--branch` proíbe `-` no início do nome e,
  dentro de um repositório, expande primeiro a sintaxe `@{-n}`; a guarda tira a dependência dessa
  expansão. Repetição é igualdade exata de texto, como D1 descreve.
- **Fonte**: manual local `git-check-ref-format(1)`, git 2.55.0 (seção `--branch`: "a dash may
  appear at the beginning of a ref component, but it is explicitly forbidden at the beginning of
  a branch name"; "the input is first expanded for the previous checkout syntax @{-n}"). Sonda
  feita em 2026-10-05 com `git check-ref-format --branch "<p>/x"`, git 2.55.0:

  | Prefixo | Resultado | Prefixo | Resultado |
  |---|---|---|---|
  | `feat`, `fix` | aceito | `a..b` | recusado |
  | `-x` | recusado | `a.lock` | recusado |
  | `@{-1}` | recusado | `.a` | recusado |
  | `*`, `a?`, `a[` | recusado | `feat~`, `a^`, `a:b` | recusado |
  | `a b` | recusado | `a\b` | recusado |
  | `á` | aceito | `@`, `a.`, `HEAD` | aceito |

- **Alternatives considered**: regex própria de nome de ref — rejeitada: duplicaria regras que o
  git já aplica e envelheceria com ele (D1 manda usar o git).

## Decision 3: valor em branco ou só de espaços equivale a chave não declarada

- **Decision**: em `validar_todos` (l.379), a regra "só espaços equivale a não declarada" de
  `DESTINOS_DO_PROJETO` passa a valer também para `PREFIXOS_BRANCH` (mesma condição, as duas
  chaves). Vazio já é tratado pela regra geral das opcionais (l.377).
- **Rationale**: D1 ("valor em branco equivale a chave não declarada") e o Edge Case "valor só de
  espaços equivale a ausente". TAB não é espaço e continua indo para `validar_chave`, que recusa
  por controle — mesmo comportamento de `DESTINOS_DO_PROJETO`.

## Decision 4: placeholders derivados fora de `CHAVES_ORDEM`

- **Decision**: duas constantes no topo — `PREFIXOS_PADRAO='feature fix chore docs hotfix'` e
  `DERIVADAS='PREFIXO_FEATURE PREFIXO_FIX PREFIXO_CHORE PREFIXO_DOCS PREFIXO_HOTFIX'` — e uma
  função `derivar_prefixos`, chamada em `main` logo depois de `validar_todos` (l.1095), nos três
  modos. Ela lê os cinco itens de `PREFIXOS_BRANCH` (ou de `PREFIXOS_PADRAO`, se a chave não
  estiver definida) e faz `setar` de cada placeholder pela posição. `renderizar` (l.741) passa a
  montar a lista de definidas a partir de `$CHAVES_ORDEM $DERIVADAS`.
- **Rationale**: os placeholders têm sempre valor (FR-007), então nunca viram residual. Como não
  estão em `CHAVES_ORDEM`, não são perguntados (`perguntar_todos`), não são gravados
  (`gravar_config`) e, num arquivo de respostas ou config, `PREFIXO_FEATURE=...` é chave
  desconhecida (`chave_conhecida`), nunca fonte de valor. `derivar_prefixos` sempre sobrescreve
  os cinco valores antes de qualquer render, então variável de ambiente não chega ao render.
- **Alternatives considered**: (a) os cinco placeholders em `CHAVES_ORDEM` — rejeitado: seriam
  perguntados e gravados, contra D2; (b) uma segunda substituição (`sed`) depois do render —
  rejeitado: segundo mecanismo de render, sem a garantia de literalidade de `&`, `\` e `$` da
  Decision 1 da feature `configurar`.

## Decision 5: render byte a byte igual sem a chave

- **Decision**: nos dois templates, só o literal do prefixo vira placeholder (`feature/<slug>` →
  `{{PREFIXO_FEATURE}}/<slug>` e assim por diante, `hotfix` incluído); nenhum outro byte muda,
  inclusive as quebras de linha. Com a chave ausente, `derivar_prefixos` produz exatamente os
  literais de antes.
- **Evidência prevista**: (a) no cenário 20, cópia do cockpit (`cockpit_copia`) com os cinco
  placeholders trocados de volta pelos literais nos dois templates; render das duas cópias com a
  chave ausente e `cmp` dos dois documentos; (b) no quickstart, comparação manual contra o render
  de `origin/main`, registrada na PR (SC-001).

## Decision 6: pergunta interativa

- **Decision**: `perguntar_chave` ganha `PREFIXOS_BRANCH) perguntar PREFIXOS_BRANCH "Prefixos de
  branch de feature, fix, chore, docs e hotfix, nessa ordem (padrão: <PREFIXOS_PADRAO>)"`. O
  sufixo ` (- para vazio)` vem de `perguntar` por ser opcional. Enter sem valor atual e `-` dão
  vazio, ou seja, chave ausente e padrão no render.
- **Rationale**: D1 pede a dica do padrão e `-` para vazio. O texto da dica é montado a partir de
  `PREFIXOS_PADRAO`, sem repetir o literal no código.

## Decision 7: skill `rito-dev`

- **Decision**: a Fase 1 passa a nomear os prefixos pelo tipo (`<prefixo de feature>/<slug>`
  etc.), lidos de `PREFIXOS_BRANCH` no `cockpit.config` na hora, na ordem fixa; ausente ou em
  branco, `feature fix chore docs hotfix`. Valor que não tenha exatamente cinco prefixos sem `/`:
  a skill nomeia a chave e PARA, como já faz com chave obrigatória ausente (l.13-15). A tabela de
  chaves consumidas ganha a linha `PREFIXOS_BRANCH` (opcional) → Fase 1, e a linha
  `BRANCH_PRODUCAO` passa a dizer "base do prefixo de hotfix" em vez de `hotfix/`.
- **Rationale**: FR-010 e D3. A regra "nunca siga com valor presumido" da própria skill vale
  também para valor malformado; o padrão só vale para chave ausente ou em branco.
- **Fora de escopo** (D3): a `description` do frontmatter cita os tipos (`feature/fix/chore/docs`)
  como gatilho de uso, não como prefixo de branch; fica como está.

## Decision 8: testes

- **Decision**: cenário 20 novo em `scripts/testar-configurar.sh`, entre o 19 e o 11 (o 11 é o
  último a rodar): chave ausente com `cmp` contra o render dos literais (Decision 5); chave válida
  com cinco prefixos distintos do padrão refletidos nos dois documentos e nenhum literal padrão
  substituído; gravação da chave e nenhuma linha `PREFIXO_*` no config; só espaços = ausente;
  `--atualizar` de config sem a chave sem pergunta nem erro; inválidos (4 e 6 itens, `/`, TAB,
  `a..b`, `-x`, repetido) com exit 1 citando a chave e sem `cockpit.config` criado; parte
  interativa (pergunta, dica, `-`, valor inválido perguntado de novo) sob a mesma guarda do
  cenário 14 (`script(1)` disponível). Ajustes: cenário 14 — mínima de 20 respostas e a de 19
  falha; as entradas do config incompleto e da reentrada de identidade ganham uma resposta no fim.
  Cenário 15 — `! grep -rq 'PREFIXOS_BRANCH' templates/`.
- **Rationale**: FR-012 e o estilo dos cenários 18 e 19 (função auxiliar de respostas, `codigo`,
  `falha`).

## Decision 9: documentação

- **Decision**: `cockpit.config.example` ganha a seção `PREFIXOS_BRANCH=''` no fim, com comentário
  da ordem, do padrão e um exemplo; `docs/specs/configurar/contracts/cli.md` ganha a seção delta
  "Prefixos de branch (`PREFIXOS_BRANCH`)", como a de `DESTINOS_DO_PROJETO`; e
  `docs/specs/configurar/data-model.md` ganha uma linha em cada uma das duas tabelas de chaves.
- **Rationale**: FR-011 nomeia o exemplo e o contrato. O data-model entra porque o comentário de
  `CHAVES_ORDEM` (l.51) o aponta como fonte da ordem de gravação; sem a linha, a fonte fica
  desatualizada. Valor vazio no exemplo mantém iguais os cenários que o usam como respostas.

## Riscos aceitos

- `templates/docs/constitution.md.semente.tmpl` (l.18) também cita `hotfix/<slug>`. Fica fora do
  escopo medido por D3; por ser semente, o projeto passa a mantê-la depois da primeira geração.
  Candidato a issue de acompanhamento.
- Repetição é igualdade exata: `Fix` e `fix` passam, embora colidam em sistema de arquivos sem
  distinção de caixa. D1 define repetição como texto igual.
- Prefixo não ASCII (`á`) é aceito, porque o git aceita (sonda da Decision 2).
