# Feature Specification: commitlint sem limite de linha no corpo

**Feature**: `commitlint-corpo-longo`
**Created**: 2026-10-06
**Status**: Draft
**Origem**: issue #8. Decisão D1 do owner, normativa e fechada, em `decisoes-do-owner.md`
(mesmo diretório); não se reabre no clarify.

> Decisões de infraestrutura: N/A (arquivo de template e script de teste locais, sem scheduler,
> sessão, chave criptográfica, multi-réplica ou retry).

## Problema

O fluxo de validação de commits gerado pelo cockpit cria a configuração do commitlint na hora,
estendendo a configuração convencional. Essa configuração inclui o limite de tamanho de linha do
corpo da mensagem. Commits de bots (por exemplo, atualização de dependências) trazem corpos com
linhas longas, e o check do PR fica vermelho sem que haja erro real de padrão.

## User Scenarios & Testing

### User Story 1 - PR de bot com corpo longo passa no check (Priority: P1)

Quem mantém um projeto gerado pelo cockpit recebe PRs de bots cujos commits têm linhas longas no
corpo. O check de mensagens de commit não reprova por tamanho de linha do corpo.

**Why this priority**: é o valor central da issue: eliminar o falso vermelho.

**Independent Test**: renderizar o fluxo de validação de commits e conferir que a configuração
que ele gera desliga a regra de tamanho de linha do corpo.

**Acceptance Scenarios**:

1. **Given** o fluxo renderizado, **When** a configuração é gerada na execução, **Then** a regra
   de tamanho máximo de linha do corpo está desligada.
2. **Given** um commit com linha de corpo acima do limite padrão e cabeçalho válido, **When** o
   check roda, **Then** o check não reprova por causa do corpo.

---

### User Story 2 - O restante do padrão continua valendo (Priority: P1)

As demais regras da configuração convencional, inclusive as do cabeçalho, seguem valendo para
todos os autores.

**Why this priority**: sem isso, desligar a regra viraria afrouxar o padrão inteiro.

**Independent Test**: conferir que a configuração gerada mantém a extensão da configuração
convencional.

**Acceptance Scenarios**:

1. **Given** o fluxo renderizado, **When** a configuração é gerada, **Then** ela continua
   estendendo a configuração convencional.
2. **Given** um commit com cabeçalho fora do padrão, **When** o check roda, **Then** o check
   reprova, como hoje.

### Edge Cases

- Commit de autor humano com corpo longo: passa igualmente (a regra é desligada para todos os
  autores; não há tratamento diferenciado de bots).
- Título do PR e commits são validados com a mesma configuração; o título não tem corpo, então
  nada muda para ele.
- A forma de desligar a regra segue a documentação oficial do commitlint, com o link na pesquisa
  da feature.
- O fluxo não ganha dependência nova nem muda versões fixadas do commitlint ou gatilhos do
  fluxo: o diff do fluxo se limita à linha que gera a configuração.
- Rodapé longo continua sujeito à regra de rodapé da configuração convencional (fora de escopo).

## Requirements

### Functional Requirements

- **FR-001**: O fluxo de validação de commits gerado MUST produzir uma configuração do commitlint
  com a regra de tamanho máximo de linha do corpo desligada, para todos os autores.
- **FR-002**: A configuração gerada MUST continuar estendendo a configuração convencional, de modo
  que as demais regras (cabeçalho e rodapé inclusos) sigam valendo.
- **FR-003**: A forma de desligar a regra MUST seguir a documentação oficial do commitlint, cujo
  link consta na pesquisa da feature (Princípio V, Fonte Oficial Antes de Afirmar).
- **FR-004**: O fluxo MUST NOT introduzir dependência nova, nem alterar versões fixadas do
  commitlint ou gatilhos do fluxo.
- **FR-005**: Um cenário de teste automatizado (cenário 25, antes do cenário 11 em
  `scripts/testar-configurar.sh`) MUST conferir que o fluxo renderizado gera a configuração com a
  regra desligada e mantém a extensão da configuração convencional.

## Success Criteria

- **SC-001**: 100% dos commits com cabeçalho válido deixam de reprovar por tamanho de linha do
  corpo.
- **SC-002**: 0 regras do cabeçalho enfraquecidas: um cabeçalho fora do padrão continua
  reprovando.
- **SC-003**: a suíte de testes do configurador passa com o cenário novo, e as verificações de
  sintaxe do fluxo (actionlint e shellcheck) não apontam nenhum problema.

## Fora de escopo

- Tratar autores bot de forma diferente dos humanos.
- Outras regras da configuração convencional (rodapé incluído), versões fixadas do commitlint e
  gatilhos do fluxo.
