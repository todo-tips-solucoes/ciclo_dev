# Decisões do owner — commitlint-corpo-longo

Frente para a issue #8 (`templates/.github/workflows/commitlint.yml.tmpl`). As decisões abaixo
foram tomadas pelo owner em 2026-10-06, antes do `/feature-00c`, e são normativas: o `specify`
parte delas e o `clarify` não as reabre.

Contexto: o fluxo gera a config na hora
(`module.exports = { extends: ['@commitlint/config-conventional'] };`). A regra
`body-max-line-length` da config convencional reprova commits de bots (por exemplo, atualização de
dependências) com linhas longas no corpo, e o PR do bot fica vermelho sem erro real.

## D1 — desligar o limite de linha do corpo

- A config gerada pelo fluxo desliga `body-max-line-length`, para todos os autores. O restante da
  config convencional continua valendo, inclusive as regras do cabeçalho.
- A forma de desligar a regra segue a documentação oficial do commitlint, com o link na research
  (Princípio VI).

## Fora de escopo

- Tratar autores bot de forma diferente dos humanos.
- Outras regras da config convencional (rodapé incluído), versões fixadas do commitlint e
  gatilhos do fluxo.

## Restrições

- YAML dos fluxos com shell embutido em bash, sem dependência nova; actionlint e shellcheck sem
  findings (rodam no CI).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Teste em `scripts/testar-configurar.sh`, num cenário novo **25** (número reservado), logo antes
  do cenário 11: o fluxo renderizado gera a config com `body-max-line-length` desligada e mantém
  o `extends` da config convencional. Rodar o commitlint de verdade exigiria rede e instalação
  (Princípio IV), então o teste confere a config gerada.
- Frente paralela a outras quatro (#7, #9, #10 e a de #18/#19). No rebase sobre `main`, conflito
  de inserção em `scripts/testar-configurar.sh` se resolve mantendo os dois blocos.
- Registro SDD em `docs/specs/commitlint-corpo-longo/`.
