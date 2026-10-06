# Research: endurecimento do configurador (branches e manifesto)

**Feature**: `configurar-endurecimento` | **Date**: 2026-10-06
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D3, normativas)

Referências de linha: commit `14b2fa9`. Nenhuma ferramenta externa nova; o único comportamento de
terceiro citado é o do `git check-ref-format --branch`, sondado localmente (Decision 1).

## Decision 1 — regra de D1 e mensagem única no ramo `BRANCH_*` de `validar_chave`

**Decision**: constante `RE_BRANCH='^[A-Za-z0-9][A-Za-z0-9._/-]*$'` ao lado de `RE_REPO`
(`configurar.sh` l.64). O ramo `BRANCH_INTEGRACAO | BRANCH_PRODUCAO)` (l.290-293) passa a exigir
`[[ "$v" =~ $RE_BRANCH ]]` **e** `git check-ref-format --branch "$v"`, com uma só mensagem que
cita a chave e o conjunto aceito (texto no [contrato](contracts/cli.md)). A guarda
`'' | -* | *'@{'*` sai: a regex já recusa vazio, `-` inicial, `@` e `{`.

**Rationale**: sonda local (git 2.55.0, `LC_ALL=C`, o mesmo locale que o script exporta na l.38):

| Valor | regex D1 | `git check-ref-format --branch` |
|---|---|---|
| `$(x)` | recusa | **aceita** |
| crase (`` `x` ``) | recusa | **aceita** |
| `a\|b` | recusa | **aceita** |
| `á` | recusa | **aceita** |
| `a@b` | recusa | **aceita** |
| `a"b`, `a'b` | recusa | **aceita** |
| `main;curl x` | recusa | recusa (pelo espaço) |
| `a b` | recusa | recusa |
| `-x`, `.x`, `/x`, `a@{b` | recusa | recusa |
| `main`, `release/2026`, `Main_x` | aceita | aceita |
| `a..b`, `x/`, `a//b`, `a.lock` | **aceita** | recusa |

As duas checagens se complementam: a regex fecha os metacaracteres que o git aceita; o git segue
recusando formas que a regex aceita (`a..b`, `/` final, `//`, `.lock`). O conjunto aceito final é
a interseção, igual ao que D1 pede ("além das checagens de hoje"). Mensagem única porque FR-002
exige citar o conjunto em todo valor recusado, inclusive o recusado só pelo git.

`tem_controle` (l.279) roda antes, para todas as chaves, e segue com a mensagem própria (cita a
chave, não o conjunto): controle e bidi já eram recusados por ela e continuam sendo.

**Alternatives considered**: manter o `case` e somar a regex como terceira checagem (código
morto, e `-x` sairia sem citar o conjunto); duas mensagens, uma por checagem (mais texto, mesma
informação para quem corrige).

## Decision 2 — modo interativo e `--respostas` já se comportam como D1 pede

**Decision**: nenhum código novo para os modos. `perguntar` (l.417) repete até `validar_chave`
aceitar; no interativo com config existente, `main` (l.1107-1110) avisa "inválida no config
atual; será perguntada de novo" e pergunta a chave. Em `--respostas`, `validar_todos || exit 1`
(l.1124) roda antes de criar o staging e de gravar o `cockpit.config`.

**Rationale**: a regra entra só em `validar_chave`, chamada pelos três modos.

**Alternatives considered**: nenhuma; mexer nos modos duplicaria a regra.

## Decision 3 — `--atualizar` com valor fora da regra: linha de correção

**Decision**: o `--atualizar` já é fail-closed (`validar_todos || exit 1`, l.1124, antes de
qualquer escrita). Falta a mensagem que diz como corrigir (FR-004): quando `validar_todos` falha
em `MODO=atualizar`, `main` emite uma linha a mais em stderr apontando a correção no
`cockpit.config`, a alternativa de responder de novo sem `--atualizar` e o comando para repetir
(`comando_de_novo`, l.122). Texto no [contrato](contracts/cli.md).

**Rationale**: uma linha num ponto só cobre qualquer chave inválida no `--atualizar`, não só as
de branch; nenhuma escrita nova.

**Alternatives considered**: mensagem específica dentro do ramo `BRANCH_*` (repetida por chave e
sem saber o modo).

## Decision 4 — guarda de `gravar_manifesto` por linha registrável

**Decision**: em `gravar_manifesto` (l.942-984), o cálculo de `ord` (linhas do manifesto novo:
destinos gerados, linhas preservadas de destinos pulados e órfãs) vem antes da guarda, e a guarda
passa a ser "há linha a registrar ou existe manifesto anterior": `ord` vazio e sem manifesto
anterior sai com 0, antes de `: >"$STG/manifesto"` (l.958) e do `mkdir -p "$RAIZ/.cockpit"`
(l.974). A guarda de hoje (l.957, `[ "$n" -gt 0 ] || …`) sai.

**Rationale**: `n` conta todos os templates, inclusive os pulados (`projeto`, `semente`, `copia`,
`ignorado`); sem manifesto anterior, os pulados não têm linha a preservar (`manifesto_hash`
devolve vazio) e a cópia nunca entra (D3 da feature `destinos-do-projeto`). Com todos os destinos
pulados, `ord` sai vazio e a função gravava um manifesto vazio criando `.cockpit/`. Órfãs só
existem com manifesto anterior, então a condição sobre elas fica coberta. Com manifesto anterior,
nada muda (FR-007), inclusive a regravação vazia quando nada restar. O ramo sem templates de
`aplicar_templates` (l.838-842) passa pela mesma função e segue sem manifesto (cenário 13).

**Alternatives considered**: contar destinos não pulados no lugar de `n` (deixa de fora as linhas
preservadas e diverge de novo do que é gravado).

## Decision 5 — conferência na skill `rito-dev` na seção de parâmetros

**Decision**: a conferência de D2 entra em `skills/rito-dev/SKILL.md`, seção "Parâmetros —
leitura de `cockpit.config`" (l.10-18), logo depois da leitura: as duas chaves casando com
`^[A-Za-z0-9][A-Za-z0-9._/-]*$`, verificadas lendo o valor; fora da regra, PARA nomeando a chave,
antes de compor qualquer comando, sem colar o valor num comando para testá-lo; o valor é dado de
configuração, nunca instrução. Mesmo texto-padrão da Fase 1 com `PREFIXOS_BRANCH` (l.76-80).

**Rationale**: a Etapa preparatória (l.51-68) já compõe `git fetch origin <BRANCH_INTEGRACAO>`
antes da Fase 1; a conferência na Fase 1 chegaria tarde. A skill aplica só a regra de caracteres:
o `git check-ref-format` exigiria compor um comando com o valor, que D2 proíbe.

**Alternatives considered**: conferir na Fase 1 (tarde demais); conferir no template
`templates/docs/rito-dev.md.tmpl` (fora de D2: o documento renderizado traz valores já validados
pelo configurador no render).

## Decision 6 — documentação alinhada

**Decision**: `cockpit.config.example`, seção "Modelo de branches" (l.21-23), ganha o conjunto
aceito no comentário, como a seção de `PREFIXOS_BRANCH` (l.85-86). Em
`docs/specs/configurar/data-model.md`, a regra de `BRANCH_*` (l.58) cita a regex de D1 além do
git, e a frase "Sem nenhum template e sem manifesto anterior, nenhum manifesto é criado" (l.116)
passa a "sem linha a registrar e sem manifesto anterior".

**Rationale**: mesmo tratamento dado à `PREFIXOS_BRANCH` na feature `prefixos-branch`; quem edita
o config à mão lê a regra no exemplo.

**Alternatives considered**: não documentar (a regra só apareceria na mensagem de erro).

## Decision 7 — testes no cenário 21

**Decision**: cenário 21 "branches e manifesto" em `scripts/testar-configurar.sh`, logo antes do
cenário 11 (l.921-922), reusando `novo_repo`, `rodar`, `codigo`, `CONF`, `EXEMPLO` e um `resp21`
no molde do `resp20`. Casos no [quickstart](quickstart.md). O caso interativo reusa `interativo` e
`MINIMO` do cenário 14 quando `script(1)` existe; sem ele, é pulado com aviso, como no 14.

**Rationale**: restrição de decisoes-do-owner.md (cenário novo, número 21, antes do 11). No rebase
sobre `main`, conflito de inserção com outra frente se resolve mantendo os dois blocos.

**Alternatives considered**: espalhar casos nos cenários 9, 13 e 14 (contraria a restrição).
