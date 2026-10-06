# Research: commitlint sem limite de linha no corpo

**Feature**: `commitlint-corpo-longo` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

## Decision 1 - Desligar a regra pelo nível 0 na configuração gerada

- **Decision**: a configuração gerada passa a declarar a regra de tamanho de linha do corpo com
  nível 0 (desligada), mantendo o `extends` da configuração convencional (decisão D1 do owner).
- **Rationale**: a documentação oficial do commitlint define o nível 0 como regra desabilitada.
- **Fonte (Princípio V)**: https://commitlint.js.org/reference/rules-configuration.html (níveis de
  regra) e https://commitlint.js.org/reference/rules.html (regra de tamanho de linha do corpo).
  O conteúdo dessas páginas não pôde ser baixado na onda de specify (rede fora da lista de
  permissão da execução); o plan MUST confirmar a sintaxe contra a fonte antes de implementar.
- **Alternatives**: regra condicionada ao autor bot (descartada, fora de escopo por D1); aumentar o
  limite em vez de desligar (descartada por D1).
