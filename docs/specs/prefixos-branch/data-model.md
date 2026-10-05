# Data Model: prefixos de branch de trabalho configuráveis

**Feature**: `prefixos-branch` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

Sem banco de dados: a chave vive no `cockpit.config` do projeto-alvo; os placeholders só existem
durante uma execução do `configurar.sh`.

## Entity: `cockpit.config` — chave `PREFIXOS_BRANCH`

| Campo | Obrigatória p/ `rito-dev` | Obrigatória p/ `configurar.sh` | Constraints |
|-------|:-:|:-:|---|
| `PREFIXOS_BRANCH` | não | não (opcional; ausente, vazia ou só espaços = não declarada) | exatamente 5 prefixos separados por espaço, na ordem `feature`, `fix`, `chore`, `docs`, `hotfix`; cada um sem `/`, casando com `^[a-z0-9][a-z0-9._-]*$` (D4), formando nome de branch válido com `/x` no fim; sem repetição |

- Posição em `CHAVES_ORDEM`: a última, depois de `DESTINOS_DO_PROJETO` (gravação e pergunta).
- Gravada como as demais opcionais: `PREFIXOS_BRANCH='<valor>'`, omitida quando vazia.
- O tipo é a posição: o 1º prefixo é o de feature, o 5º o de hotfix.

### Validação (fronteira de confiança, antes de qualquer escrita)

| Ordem | Regra | Mensagem (stderr, exit 1 no modo não interativo) |
|---|---|---|
| 1 | sem controle, quebra de linha, bidi ou UTF-8 inválido (`tem_controle`, já existente) | `Valor inválido para PREFIXOS_BRANCH: contém quebra de linha, caractere de controle ou de direção de texto.` |
| 2 | 0 itens após separar por espaço = ausente (válido); senão exatamente 5 | `Valor inválido para PREFIXOS_BRANCH: esperados 5 prefixos (feature fix chore docs hotfix, nessa ordem), recebidos N.` |
| 3 | item sem `/` | `Valor inválido para PREFIXOS_BRANCH: o prefixo '<p>' contém '/'.` |
| 4 | item casa com `^[a-z0-9][a-z0-9._-]*$` (D4, round 2) | `Valor inválido para PREFIXOS_BRANCH: o prefixo '<p>' deve casar com ^[a-z0-9][a-z0-9._-]*$ (minúsculas ASCII, dígitos, '.', '_' e '-', começando por letra ou dígito).` |
| 5 | `git check-ref-format --branch '<p>/x'` aceito | `Valor inválido para PREFIXOS_BRANCH: o prefixo '<p>' não forma nome de branch válido.` |
| 6 | item diferente dos anteriores | `Valor inválido para PREFIXOS_BRANCH: o prefixo '<p>' está repetido.` |

No modo interativo, valor inválido mostra a mesma mensagem e repete a pergunta. A regra 4 recusa
`-` inicial e `@{`, antes cobertos por uma guarda própria na regra 5 (round 1); o texto da
mensagem 4 é [PROPOSTA — a validar na implementação], mas MUST citar a chave e o conjunto aceito
(FR-014).

A Fase 1 da skill `rito-dev` aplica as regras 2, 4 e 6 sobre o valor lido do `cockpit.config`
(FR-015); fora delas, PARA e nomeia a chave.

## Entity: Placeholders derivados (estado de uma execução)

Calculados por `derivar_prefixos` depois de `validar_todos`, nos três modos, sempre com valor.
Não são chaves: não são perguntados, gravados nem lidos de arquivo (num config ou arquivo de
respostas, `PREFIXO_*=` é chave desconhecida).

| Posição | Placeholder | Valor padrão (chave ausente) |
|:-:|---|---|
| 1 | `{{PREFIXO_FEATURE}}` | `feature` |
| 2 | `{{PREFIXO_FIX}}` | `fix` |
| 3 | `{{PREFIXO_CHORE}}` | `chore` |
| 4 | `{{PREFIXO_DOCS}}` | `docs` |
| 5 | `{{PREFIXO_HOTFIX}}` | `hotfix` |

Constantes do script: `PREFIXOS_PADRAO` (os cinco valores padrão, na ordem) e `DERIVADAS` (os
cinco nomes, na mesma ordem). `renderizar` trata `$CHAVES_ORDEM $DERIVADAS` como fonte de valores.

## Entity: documentos que consomem os prefixos

| Documento | Fonte | Como consome |
|---|---|---|
| `docs/CICLO-GIT.md` | `templates/docs/CICLO-GIT.md.tmpl` (l.12-13) | os cinco placeholders |
| `docs/rito-dev.md` | `templates/docs/rito-dev.md.tmpl` (l.34-35) | os cinco placeholders |
| `docs/constitution.md` (round 2, D5) | `templates/docs/constitution.md.semente.tmpl` (l.18) | só `{{PREFIXO_HOTFIX}}`; semente: gerada só com destino inexistente |
| skill `rito-dev` | `skills/rito-dev/SKILL.md` (Fase 1, l.76-83; tabela l.19-33) | lê `PREFIXOS_BRANCH` do `cockpit.config` na hora; ausente ou em branco = padrão; malformado (regras 2, 4 e 6) = PARA |

Nenhum template usa `PREFIXOS_BRANCH` (regra do cenário 15).
