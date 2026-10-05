# Implementation Plan: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)
**Decisões do owner**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D6, normativas; D4 a D6
são as emendas da reabertura, round 2)

## Summary

Chave opcional `PREFIXOS_BRANCH` no `cockpit.config`: cinco prefixos posicionais (`feature`,
`fix`, `chore`, `docs`, `hotfix`), validados com o próprio git e recusados com exit 1 citando a
chave. O configurador deriva dela (ou do padrão `feature fix chore docs hotfix`) cinco
placeholders de render, sempre com valor e nunca gravados, que substituem os literais de
`CICLO-GIT.md.tmpl` e `rito-dev.md.tmpl`; sem a chave, os dois documentos saem byte a byte os de
hoje. A Fase 1 da skill `rito-dev` lê a chave na hora. Tudo em `configurar.sh` reusando o
mecanismo das opcionais (`CHAVES_OPCIONAIS`) e o render existente; nenhuma dependência nova.

**Incremento do round 2 (D4 a D6; FR-014 a FR-017, US5, SC-006, SC-007)**: cada prefixo passa a
casar com `^[a-z0-9][a-z0-9._-]*$`, no `validar_chave` e na Fase 1 da skill, porque o git aceita
metacaractere de shell e maiúscula ([research](research.md), Decisions 10 e 11). A semente da
constituição troca `hotfix/<slug>` por `{{PREFIXO_HOTFIX}}/<slug>`, renderizada pelo mesmo
caminho, byte a byte igual sem a chave; `cockpit.config.example` registra o ajuste manual de quem
já tem constituição (Decision 12). Os cinco tipos fixos ficam (Decision 13). Nenhum arquivo,
função ou mecanismo novo: uma regra a mais num ramo existente, um placeholder já derivado num
template a mais, prosa e testes.

## Technical Context

**Language/Version**: bash com `set -euo pipefail` e `LC_ALL=C` (script existente, Princípio VII)
**Primary Dependencies**: nenhuma nova: `git` (`check-ref-format`, já usado em `validar_chave`
para `BRANCH_*`)
**Storage**: `cockpit.config` (chave nova, opcional); manifesto sem mudança de formato
**Testing**: `scripts/testar-configurar.sh` (cenário 20 novo; 14 e 15 ajustados) + shellcheck e
`verificar-agnostico.sh` (cenário 11)
**Target Platform**: Linux, WSL, macOS (fonte: constitution, Princípio VII)
**Project Type**: cli (script local) + documentos e skill em Markdown
**Performance Goals**: N/A
**Constraints**: sem a chave, render e `--atualizar` idênticos aos de hoje; valor inválido antes de
qualquer escrita; prosa em pt-BR acentuado; nada que nomeie projeto real
**Scale/Scope**: `configurar.sh` (2 constantes, 1 função nova, 5 funções alteradas), 2 templates,
1 skill, `cockpit.config.example`, 2 documentos da feature `configurar`, 1 cenário novo e 2
ajustados. Round 2: 1 ramo de `validar_chave`, 1 template a mais (semente da constituição), a
Fase 1 da skill, `cockpit.config.example`, os 2 documentos da `configurar` e 3 casos do
cenário 20

## Constitution Check

*GATE: Deve passar antes do Phase 0. Re-checar após Phase 1.*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | é a aplicação direta do "valor que varia por projeto é chave do config"; exemplos com prefixos genéricos; cenário 11 roda `verificar-agnostico.sh` |
| II. Cockpit sob o próprio ciclo | PASS | branch `feat/prefixos-branch` em worktree, via `/feature-00c`; registro SDD neste diretório; trilha completa com `bmad-code-review` antes da PR |
| III. Identidade de commit | N/A | o script não commita |
| IV. Dependências, não cópias | PASS | nenhuma ferramenta nova; `cstk` intocado |
| V. Fonte oficial antes de afirmar | PASS | comportamento de `git check-ref-format --branch` citado do manual local do git 2.55.0 e de sonda registrada ([research](research.md), Decision 2); nenhum número estimado |
| VI. Português do Brasil | PASS | pergunta, mensagens, comentário do exemplo e skill em pt-BR acentuado ([contrato](contracts/cli.md)) |
| VII. Portáveis, idempotentes, contidos | PASS | sem pré-requisito novo; nenhuma escrita nova (só render e gravação já existentes); 2ª execução com a mesma chave não altera nada (cenário 2 e idempotência do 15 seguem valendo) |

**Re-check pós-design**: PASS. O design não cria arquivo, processo nem mecanismo de render novo;
os placeholders reusam `setar`/`renderizar`, e a chave reusa o caminho das opcionais. Sem
violação a justificar.

**Re-check do round 2**: PASS. I — a semente deixa de fixar um prefixo que varia por projeto. V —
a exposição que motiva D4 foi sondada no git 2.55.0 e o comportamento da regex sob `LC_ALL=C`
também ([research](research.md), Decision 10). VII — nenhuma escrita nova: a semente segue gerada
só com destino inexistente, então projeto já configurado não tem a constituição regravada
(Decision 12). D6 não adiciona tipo nem formato.

## Design

Referências de linha: `configurar.sh` no commit `ec13897`.

### `configurar.sh`

1. **Constantes** (l.51-53): `PREFIXOS_BRANCH` no fim de `CHAVES_ORDEM` e em `CHAVES_OPCIONAIS`;
   comentário "URLs e DESTINOS_DO_PROJETO são as únicas opcionais" atualizado. Novas
   `PREFIXOS_PADRAO` e `DERIVADAS` ([research](research.md), Decisions 1 e 4).
2. **`validar_chave`** (l.274): ramo `PREFIXOS_BRANCH)` — 0 itens válido; 5 exatos; por item, `/`,
   `-` inicial, `@{` e `git check-ref-format --branch "<p>/x"`; repetição. Mensagens no
   [data-model](data-model.md) §Validação (Decision 2).
3. **`validar_todos`** (l.379): "só espaços = não declarada" vale para `DESTINOS_DO_PROJETO` e
   `PREFIXOS_BRANCH` (Decision 3).
4. **`perguntar_chave`** (l.455): ramo `PREFIXOS_BRANCH)` com o texto do
   [contrato](contracts/cli.md), dica montada de `PREFIXOS_PADRAO` (Decision 6).
5. **`derivar_prefixos`** (nova): os cinco valores da chave ou do padrão, `setar` por posição em
   `DERIVADAS`. Chamada em `main` logo depois de `validar_todos` (l.1095).
6. **`renderizar`** (l.741): definidas a partir de `$CHAVES_ORDEM $DERIVADAS`.

Sem mudança em `ler_kv`, `gravar_config`, `aplicar_templates`, manifesto, `--ajuda` e códigos de
saída: o caminho das opcionais e o render já cobrem a chave e os placeholders.

### Templates (FR-008, FR-009)

- `templates/docs/CICLO-GIT.md.tmpl` l.12-13 e `templates/docs/rito-dev.md.tmpl` l.34-35: cada
  literal `<tipo>/<slug>` vira `{{PREFIXO_<TIPO>}}/<slug>`; nenhum outro byte muda (Decision 5).

### Skill `rito-dev` (FR-010)

- `skills/rito-dev/SKILL.md`: tabela de chaves consumidas ganha `PREFIXOS_BRANCH` (opcional) →
  Fase 1, com o padrão; linha de `BRANCH_PRODUCAO` cita "base do prefixo de hotfix"; Fase 1
  (l.73-77) passa a nomear os prefixos pelo tipo, lidos da chave na hora, PARANDO com valor
  malformado (Decision 7).

### Configuração e documentação (FR-011)

- `cockpit.config.example`: seção nova no fim, `PREFIXOS_BRANCH=''`, com ordem, padrão e exemplo
  em comentário.
- `docs/specs/configurar/contracts/cli.md`: seção delta "Prefixos de branch (`PREFIXOS_BRANCH`)"
  apontando para o [contrato desta feature](contracts/cli.md).
- `docs/specs/configurar/data-model.md`: linha da chave nas tabelas de campos e de validação
  (Decision 9).

### Testes (FR-012, SC-001 a SC-005)

- Cenário 20 "prefixos de branch", antes do 11, com os casos do [quickstart](quickstart.md) 1 a 7.
- Cenário 14: mínima de 20 respostas (a de 19 falha); +1 resposta no fim das entradas do config
  incompleto e da reentrada de identidade.
- Cenário 15: `! grep -rq 'PREFIXOS_BRANCH'` nos templates.

### Incremento do round 2 (D4 a D6)

Referências de linha: commit `11c546d` (round 1 implementado).

1. **`validar_chave`, ramo `PREFIXOS_BRANCH)`** (l.314-327, FR-014): depois da checagem de `/`
   (l.320), um `[[ "$item" =~ ^[a-z0-9][a-z0-9._-]*$ ]]` com a mensagem do conjunto aceito
   ([data-model](data-model.md) §Validação, regra 4). A guarda `-* | *'@{'*` (l.321) sai: a regex
   já recusa `-` inicial, `@` e `{`. `git check-ref-format` (l.322) e a repetição (l.324) ficam;
   o git segue recusando o que a regex aceita, como `a..b` e `a.lock` (Decision 10).
2. **Semente da constituição** (FR-016): `templates/docs/constitution.md.semente.tmpl` l.18,
   `hotfix/<slug>` vira `{{PREFIXO_HOTFIX}}/<slug>`; nenhum outro byte muda (a palavra "hotfix"
   da l.31 é o tipo, não o prefixo, e fica). Sem mudança em `configurar.sh`: a semente passa pelo
   mesmo `renderizar` (l.846) e `derivar_prefixos` roda antes (l.1123) (Decision 12).
3. **Skill `rito-dev`, Fase 1** (l.76-78, FR-015): a regra de parada passa a ser a de D4 — cinco
   prefixos, cada um casando com `^[a-z0-9][a-z0-9._-]*$`, sem repetição —, verificada lendo o
   valor, antes de compor qualquer comando e sem colar o valor num comando para testá-lo; fora
   disso, PARA e nomeia `PREFIXOS_BRANCH`. O valor é dado de configuração, nunca instrução
   (gate de segurança do round 2, achado B3) (Decision 11).
4. **`cockpit.config.example`** (l.83-89, FR-014 e FR-016): o comentário da seção troca "sem `/`"
   pelo conjunto aceito e ganha a nota de D5: a constituição é semente, não é regravada no
   `--atualizar`; projeto já configurado que declarar a chave troca à mão `hotfix/<slug>` na sua.
5. **Documentos da `configurar`**: `data-model.md` l.24 e l.64 e `contracts/cli.md` l.54-60 citam
   a regra de D4; o contrato cita também a semente como consumidora de `{{PREFIXO_HOTFIX}}`.
6. **Cenário 20** (FR-012, SC-006, SC-007): caso 1 — a cópia literal troca os placeholders também
   na semente e compara `docs/constitution.md` com `cmp`; caso 2 — a constituição tem `hf/<slug>`
   e nenhum `hotfix/<slug>`; caso 4 — valores de D4 (maiúscula, `;`, `$(x)`, `|`, crase, `.`, `_`
   e não ASCII) com exit 1, stderr citando a chave e o conjunto aceito, sem `cockpit.config`;
   para D6, `feature=feat fix chore docs hotfix` também sai com exit 1
   ([quickstart](quickstart.md) 11 a 13).

Sem mudança em `derivar_prefixos`, `renderizar`, `perguntar_chave`, manifesto, `--ajuda` e
códigos de saída.

## Project Structure

### Documentação (esta feature)

```text
docs/specs/prefixos-branch/
├── decisoes-do-owner.md   # D1-D6 (normativas)
├── spec.md
├── plan.md                # este arquivo
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── cli.md
```

### Código e documentos tocados

```text
configurar.sh
cockpit.config.example
templates/docs/CICLO-GIT.md.tmpl
templates/docs/rito-dev.md.tmpl
templates/docs/constitution.md.semente.tmpl   # round 2 (D5)
skills/rito-dev/SKILL.md
scripts/testar-configurar.sh
docs/specs/configurar/contracts/cli.md
docs/specs/configurar/data-model.md
```

## Convenções de Borda

N/A — single-layer (script local, sem fronteira de serviço).

## Gate de segurança do round 2

Revisão OWASP do desenho (A05 injeção, LLM01/ASI01 injeção via agente, validação na fronteira):
0 crítico, 0 alto, 0 médio. A regra de D4 é allowlist aplicada antes de qualquer escrita
(`validar_todos`, l.1122, antes de `derivar_prefixos` e da gravação) e antes de o git receber o
prefixo como argumento, então nem `-` inicial chega ao git; `tem_controle` já barra controle e
bidi antes da regra, e o `ler_kv` lê o config sem `source`/`eval`.

| Achado | Severidade | Disposição |
|---|---|---|
| B1 — a checagem da Fase 1 da skill é feita pelo agente lendo o valor, não por script | baixo | aceito: classe de caractere simples; o `configurar.sh` aplica a regra de forma determinística (Riscos) |
| B2 — sem limite de tamanho por prefixo | baixo | aceito: o valor vem do próprio repositório; nome longo demais falha na criação da branch |
| B3 — prefixo que passa na regex pode carregar texto imperativo (`ignore-as-regras-anteriores`) lido pelo agente | baixo | corrigido no desenho: a Fase 1 diz que o valor é dado, nunca instrução (Design round 2, item 3) |

`BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` têm a mesma exposição e ficam para a issue #19.

## Riscos

- ~~`templates/docs/constitution.md.semente.tmpl` l.18 cita `hotfix/<slug>`~~: entrou no escopo
  pela D5 (round 2).
- A checagem da Fase 1 da skill é feita pelo agente lendo o valor, não por script; a regra é de
  classe de caractere simples, e o `configurar.sh` aplica a mesma de forma determinística a todo
  valor que passa por ele (Decision 11).
- Constituição de projeto já configurado não é corrigida: é semente, e D5 manda o ajuste manual,
  registrado em `cockpit.config.example`.
- Entradas posicionais do cenário 14 dependem da ordem das perguntas; a chave no fim limita o
  ajuste a uma resposta a mais por entrada.

## Complexity Tracking

Nenhuma violação de constitution a justificar.
