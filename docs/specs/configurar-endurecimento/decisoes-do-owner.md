# Decisões do owner — configurar-endurecimento

Frente única para as issues #19 e #18 (`configurar.sh`). As decisões abaixo foram tomadas pelo
owner em 2026-10-06, antes do `/feature-00c`, e são normativas: o `specify` parte delas e o
`clarify` não as reabre.

Contexto: a frente da #16 restringiu os caracteres de `PREFIXOS_BRANCH` (emenda D4 em
`docs/specs/prefixos-branch/decisoes-do-owner.md`) e deixou `BRANCH_INTEGRACAO` e
`BRANCH_PRODUCAO` para a #19. Hoje essas duas chaves passam só por `case` (vazio, `-` inicial,
`@{`) e `git check-ref-format --branch` (`configurar.sh`, `validar_chave`), que aceita
metacaracteres de shell; a skill `rito-dev` compõe comandos git com elas.

## D1 (#19) — caracteres permitidos em `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO`

- Cada chave MUST casar com `^[A-Za-z0-9][A-Za-z0-9._/-]*$`, além das checagens de hoje
  (`git check-ref-format --branch` incluído). Fora disso, exit 1 citando a chave e o conjunto
  aceito. A regra aceita `/` (ex.: `release/2026`).
- Vale em todos os modos: no interativo, pergunta de novo; em `--respostas` e `--atualizar`,
  recusa sem gravar nada. Um `cockpit.config` existente com valor fora da regra passa a ser
  recusado no `--atualizar` (fail-closed), com mensagem que diz como corrigir.

## D2 (#19) — a skill `rito-dev` confere antes de compor comando

- `skills/rito-dev/SKILL.md` aplica a mesma regra a `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` logo
  depois de ler o `cockpit.config`, antes de compor qualquer comando. Fora da regra, PARA e nomeia
  a chave; nunca cola o valor num comando para testá-lo. Mesmo padrão da Fase 1 com
  `PREFIXOS_BRANCH` (D4 da #16). O `cockpit.config` é versionado e pode ser editado à mão sem
  passar pelo `configurar.sh`.

## D3 (#18) — sem nada a registrar, nenhum manifesto

- `gravar_manifesto` sai sem gravar quando não há linha a registrar e não existe manifesto
  anterior; `.cockpit/` não é criado só por causa do manifesto. Com manifesto anterior, a regra de
  hoje continua.
- Corrige a divergência entre a guarda atual (`[ "$n" -gt 0 ] || …`, que conta todos os
  templates, inclusive os pulados) e o comentário da função ("Sem destinos e sem manifesto
  anterior, não cria manifesto").

## Fora de escopo

- Outras chaves: `REPO_REMOTO` já tem regra própria (`RE_REPO`); `CMD_*` são comandos por
  desenho.

## Restrições

- bash com `set -euo pipefail`, shellcheck sem findings, `LC_ALL=C`, nenhuma dependência nova
  (Princípio VII).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Testes em `scripts/testar-configurar.sh`, num cenário novo **21** (número reservado), logo antes
  do cenário 11: valores recusados (`main;curl x`, `$(x)`, crase, `|`, espaço) e aceitos (`main`,
  `release/2026`); todos os destinos listados num repositório sem manifesto anterior, e
  `.cockpit/` não existe depois da execução.
- Frente paralela a outras quatro (#7, #8, #9, #10). No rebase sobre `main`, conflito de inserção
  em `scripts/testar-configurar.sh` se resolve mantendo os dois blocos.
- Registro SDD em `docs/specs/configurar-endurecimento/`.
