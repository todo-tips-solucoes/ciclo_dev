# Research: commitlint sem limite de linha no corpo

**Feature**: `commitlint-corpo-longo` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

## Decision 1 - Desligar a regra pelo nível 0 na configuração gerada

- **Decision**: a configuração gerada passa a declarar, no objeto `rules`, a regra
  `body-max-line-length` com nível 0 (desligada), mantendo o `extends` da configuração
  convencional (decisão D1 do owner). Forma escolhida, no mesmo formato de array de três posições
  do exemplo oficial: `'body-max-line-length': [0, 'always', Infinity]`.
- **Rationale**: a documentação oficial define o nível 0 como regra desabilitada e diz que as
  regras declaradas na configuração sobrepõem as da configuração estendida. O valor `Infinity` é o
  valor documentado da própria regra; com nível 0 ele não é avaliado, e entra só para seguir o
  formato de três posições que a documentação mostra.
- **Fonte (Princípio V)**, lida em 2026-10-06 com `ctx_fetch_and_index` do `context-mode` (as
  quatro páginas indexadas sem erro; trechos abaixo copiados da busca no índice):
  - https://commitlint.js.org/reference/rules-configuration.html: "Rules are made up by a name and
    a configuration array. The configuration array contains: Level [0..2]: 0 disables the rule.
    For 1 it will be considered a warning for 2 an error. Applicable always|never: never inverts
    the rule. Value: value to use for this rule." Exemplo da página:
    `"header-max-length": [0, "always", 72]`.
  - https://commitlint.js.org/reference/rules.html: "body-max-line-length — condition: body lines
    have value or less characters, or contain a URL; rule: always; value: Infinity".
  - https://commitlint.js.org/reference/configuration.html: exemplo com
    `extends: ["@commitlint/config-conventional"]` e o comentário "Any rules defined here will
    override rules from @commitlint/config-conventional"; nota "CJS format is supported as well:
    `module.exports = Configuration;`" (o fluxo gera `commitlint.config.cjs`).
  - https://commitlint.js.org/concepts/shareable-config.html: "The rules found in
    commitlint-config-example are merged with the rules in commitlint.config.js, if any."
- **O que a fonte não afirma**: as páginas acima não listam o valor que a configuração
  convencional usa para `body-max-line-length`; a research não afirma esse número, e a mudança não
  depende dele.
- **Alternatives**: regra condicionada ao autor bot (descartada, fora de escopo por D1); aumentar o
  limite em vez de desligar (descartada por D1); array só com o nível (`[0]`) ou com nível e
  aplicabilidade (`[0, 'always']`) (descartados: a documentação conferida não mostra essas formas).
