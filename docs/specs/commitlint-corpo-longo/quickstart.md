# Quickstart: commitlint sem limite de linha no corpo

**Feature**: `commitlint-corpo-longo` | **Plan**: [plan.md](plan.md)

## Cenário 1 - Configuração gerada desliga a regra do corpo (US1, FR-001)

1. Rodar `scripts/testar-configurar.sh`.
2. Cenário 25: o fluxo `commitlint.yml` renderizado executa a linha `printf` num diretório
   temporário.
3. **Expected**: o `commitlint.config.cjs` gerado contém
   `'body-max-line-length': [0, 'always', Infinity]`.

## Cenário 2 - Configuração convencional continua valendo (US2, FR-002)

1. Mesmo cenário 25.
2. **Expected**: a configuração gerada contém `extends: ['@commitlint/config-conventional']`; o
   objeto `rules` não traz outra regra.

## Cenário 3 - Fluxo sem mudança fora da linha da configuração (FR-004)

1. `git diff origin/main -- templates/.github/workflows/commitlint.yml.tmpl`.
2. **Expected**: uma linha removida e uma adicionada, ambas a do `printf` da configuração; versões
   do `npm install`, gatilhos e mensagens intactos.

## Cenário 4 - Qualidade estática (SC-003)

1. Rodar `scripts/testar-configurar.sh` numa máquina com actionlint e shellcheck.
2. **Expected**: cenário 16 (actionlint sobre o fluxo renderizado) e cenário 11 (shellcheck e
   `verificar-agnostico.sh`) sem findings; a saída termina em `OK: todos os cenários passaram.`

## Error case - linha da configuração ausente ou alterada

1. Remover, numa cópia local do template, o trecho `rules: {...}` da linha `printf`.
2. **Expected**: o cenário 25 falha com mensagem que cita a regra `body-max-line-length`.

## Fora do teste automatizado

Rodar o commitlint de verdade contra um commit com corpo longo (US1, cenário 2 da spec) exige rede
e instalação (Princípio IV); fica para o check do próprio PR no CI do projeto-alvo, não para a
suíte local.
