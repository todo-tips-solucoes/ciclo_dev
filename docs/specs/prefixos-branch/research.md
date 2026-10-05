# Research: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D6, normativas; D4 a D6
na reabertura, round 2 — Decisions 10 a 14)

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
- **Ampliada no round 2** (Decision 10): a regra de caracteres de D4 entra depois da checagem de
  `/` e absorve a guarda `-*`/`@{`; `git check-ref-format` e a repetição continuam.

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
- **Ampliada no round 2** (Decision 11): a regra de parada "cinco prefixos sem `/`" passa a ser a
  de D4.

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

## Decision 10: regra de caracteres de D4 em `validar_chave` (round 2)

Referências de linha das Decisions 10 a 14: commit `11c546d` (round 1 implementado).

- **Decision**: no ramo `PREFIXOS_BRANCH)` (l.314-327), por item, nesta ordem: `/` (l.320, como
  hoje); `[[ "$item" =~ ^[a-z0-9][a-z0-9._-]*$ ]]` com a mensagem do conjunto aceito
  ([data-model](data-model.md) §Validação, regra 4); `git check-ref-format --branch "<item>/x"`;
  repetição. A guarda `-* | *'@{'*` (l.321) sai.
- **Rationale**: D4 e FR-014. A checagem de `/` fica antes porque tem mensagem própria (FR-003). A
  regex recusa `-` no início, `@` e `{`, então a guarda vira código morto. O git continua
  necessário: a regex aceita `a..b` e `a.lock`, que o git recusa. O script já roda com
  `export LC_ALL=C` (l.38), e nesse locale `[a-z]` é só ASCII: `á` e maiúsculas ficam de fora.
  Regex nativa do bash: nenhuma dependência nova.
- **Fonte**: sondas de 2026-10-05, git 2.55.0 e bash com `LC_ALL=C`.

  | Prefixo | `git check-ref-format --branch '<p>/x'` | regex de D4 |
  |---|---|---|
  | `feature`, `fix`, `hotfix`, `feat`, `a.b`, `a_b`, `a-b`, `0x` | aceito | aceito |
  | `a;b`, `a$(x)`, `a\|b`, `a&b`, crase, `a"b`, `a'b` | aceito | recusado |
  | `Feat`, `_x` | aceito | recusado |
  | `á` | aceito (Decision 2) | recusado |
  | `-x`, `.x`, `a@{b`, `a/b` | recusado | recusado |
  | `a..b`, `a.lock` | recusado | aceito |
  | `a.` | aceito | aceito |

  O `configurar.sh` do round 1 aceita hoje `a;b`, `a$(x)`, `a|b`, crase, `á` e `Feat` como
  prefixo (exit 0, prefixo gravado no documento), o que confirma a exposição que D4 fecha.
- **Alternatives considered**: (a) só a regex, sem o git — rejeitada: D4 manda manter as checagens
  de D1, e `a..b` passaria; (b) manter a guarda `-*`/`@{` — rejeitada: nunca dispara depois da
  regex.

## Decision 11: Fase 1 da skill `rito-dev` aplica D4 (round 2)

- **Decision**: a regra de parada da Fase 1 (l.76-78) passa a ser: exatamente cinco prefixos,
  cada um casando com `^[a-z0-9][a-z0-9._-]*$` (minúsculas ASCII, dígitos, `.`, `_` e `-`,
  começando por letra ou dígito), sem repetição; a verificação é feita lendo o valor, antes de
  compor qualquer comando, e o valor nunca é colado num comando para ser testado. Fora disso, a
  skill PARA e nomeia `PREFIXOS_BRANCH`. Ausente ou em branco segue valendo o padrão. A prosa
  diz que o valor é dado de configuração, nunca instrução: um prefixo como
  `ignore-as-regras-anteriores` passa na regex (gate de segurança do round 2, achado B3).
- **Rationale**: D4 e FR-015. O `cockpit.config` é versionado e editável à mão, então a skill não
  pode confiar que o valor passou pelo `configurar.sh`. A skill já lê todas as chaves pela leitura
  do arquivo (l.11-17); a regra é de classe de caractere, sem ambiguidade de leitura. Colar o valor
  num comando para validá-lo seria executar o próprio vetor que D4 fecha.
- **Alternatives considered**: (a) trecho de bash na skill que extrai a chave do arquivo e valida
  — rejeitado: duplicaria na skill o leitor `ler_kv`/`desaspar` (aspas, `export`, última
  atribuição vale) e criaria um segundo parser para manter; (b) a skill rodar
  `git check-ref-format` — rejeitado: D4 não pede, e exigiria colar o valor num comando; nome que
  passa na regex mas o git recusa (`a..b`) falha na criação da branch, sem efeito colateral.

## Decision 12: semente da constituição usa `{{PREFIXO_HOTFIX}}` (round 2)

- **Decision**: em `templates/docs/constitution.md.semente.tmpl` l.18, `hotfix/<slug>` vira
  `{{PREFIXO_HOTFIX}}/<slug>`; nenhum outro byte. A palavra "hotfix" da l.31 ("em hotfix") nomeia
  o tipo e fica. `cockpit.config.example` registra, junto da chave, que a constituição é semente:
  projeto já configurado que declarar a chave troca à mão o prefixo de hotfix na sua.
- **Rationale**: D5 e FR-016. Sementes passam pelo mesmo `renderizar` dos demais templates (l.846)
  e `derivar_prefixos` roda antes de qualquer render (l.1123), então o placeholder tem sempre valor
  e, sem a chave, vale `hotfix`: o arquivo sai byte a byte o de hoje. Semente com destino existente
  é pulada (`PULAR=semente`, l.731-732), inclusive no `--atualizar` e com `--forcar`: projeto já
  configurado não tem a constituição regravada (US5-3), comportamento que já existe e não muda.
  A regra do cenário 15 segue valendo: o template usa o placeholder derivado, não a chave.
- **Evidência prevista**: caso 1 do cenário 20 — a cópia literal (`cockpit_copia`) também troca o
  placeholder na semente, e `cmp` de `docs/constitution.md` entre os dois projetos (SC-007, sem a
  chave); caso 2 — com `hf` no 5º prefixo, `hf/<slug>` presente e `hotfix/<slug>` ausente na
  constituição (SC-007, com a chave).
- **Alternatives considered**: regravar a constituição de projeto já configurado no
  `--atualizar` — rejeitado: D5 e o contrato de semente (`configurar`) mandam nunca sobrescrever
  semente.

## Decision 13: os cinco tipos fixos ficam (round 2)

- **Decision**: nenhuma mudança: cinco tipos na ordem de FR-001, sem tipo novo e sem formato
  `tipo=prefixo` (D6, FR-017). A contagem exata de 5 do `validar_chave` e as constantes
  `PREFIXOS_PADRAO` e `DERIVADAS` já garantem isso.
- **Rationale**: D6 fecha o CHK022 sem demanda real por outro tipo.

## Decision 14: testes do round 2

- **Decision**: no cenário 20 de `scripts/testar-configurar.sh` — caso 1: o laço da cópia literal
  passa a cobrir também `constitution.md.semente.tmpl`, e o `cmp` inclui `docs/constitution.md`;
  caso 2: confere `hf/<slug>` e nenhum `hotfix/<slug>` em `docs/constitution.md`; caso 4: valores de
  D4 (`Feat b c d e`, `a;b c d e f`, `a$(x) b c d e`, `a|b c d e f`, crase, `.a b c d e`,
  `_a b c d e`, `á b c d e`, e `feature=feat fix chore docs hotfix` para D6), cada um com exit 1, stderr citando `PREFIXOS_BRANCH` e o conjunto
  aceito, e sem `cockpit.config`. Os valores do caso 4 de hoje continuam (`-a` e `a@{b` passam a
  cair na regra de D4, ainda com exit 1 citando a chave).
- **Rationale**: FR-012 (D4 e D5 no cenário 20), SC-006 e SC-007. A sonda da Decision 10 mostra
  que esses valores chegam ao `validar_chave` pelo arquivo de respostas (o `ler_kv` lê aspas
  simples literalmente). A Fase 1 da skill é prosa: verificação manual no quickstart (11).

## Riscos aceitos

- ~~`templates/docs/constitution.md.semente.tmpl` (l.18) também cita `hotfix/<slug>`~~: entrou no
  escopo pela D5 (Decision 12).
- Repetição é igualdade exata. Com D4, `Fix` e `fix` não convivem mais: maiúscula é recusada.
- ~~Prefixo não ASCII (`á`) é aceito~~: recusado por D4 (Decision 10).
- A Fase 1 da skill valida por leitura do agente, não por script (Decision 11).
- Constituição de projeto já configurado não é corrigida automaticamente (D5).
