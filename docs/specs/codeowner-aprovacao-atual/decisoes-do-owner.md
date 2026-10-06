# Decisões do owner — codeowner-aprovacao-atual

Frente para a issue #9 (`templates/.github/workflows/require-codeowner-approval.yml.tmpl`). As
decisões abaixo foram tomadas pelo owner em 2026-10-06, antes do `/feature-00c`, e são
normativas: o `specify` parte delas e o `clarify` não as reabre.

Contexto: o fluxo lista as reviews do PR (`gh api --paginate "repos/$REPO/pulls/$PR/reviews"`),
guarda o último estado de cada usuário e considera aprovado quem terminou em `approved`, sem olhar
em que commit a review foi feita. Uma aprovação dada antes do último push continua valendo. Pela
dec-025 da frente `templates-automacao`, o fluxo é verificação extra; a garantia é a regra nativa
da branch (aprovações obrigatórias + "Require review from Code Owners").

## D1 — só conta aprovação feita sobre o commit atual do PR

- O fluxo considera apenas reviews cujo `commit_id` é o commit head atual do PR. Entre elas, vale
  o último estado de cada usuário, como hoje; aprovação feita sobre commit anterior não conta.
- Um push novo depois da aprovação deixa o check sem aprovação de dono até haver review nova.

## D2 — documentar a opção nativa de descartar aprovações antigas

- Os comentários de cabeçalho do fluxo e de `templates/.github/CODEOWNERS.tmpl` citam, ao lado de
  "Require review from Code Owners", a opção nativa da regra da branch que descarta aprovações
  antigas quando há commit novo. O nome exato vem da documentação oficial do GitHub, com o link na
  research (Princípio VI: zero fabricação).

## Fora de escopo

- Tornar o fluxo a garantia de aprovação (dec-025 continua: verificação extra).
- Mudar gatilhos (`on:`) ou permissões do fluxo além do necessário para ler o head do PR.

## Restrições

- YAML dos fluxos com shell embutido em bash, sem dependência nova; actionlint e shellcheck sem
  findings (rodam no CI).
- Prosa em português do Brasil com acentuação (Princípio VI); nada que nomeie projeto real
  (Princípio I).
- Teste em `scripts/testar-configurar.sh`, num cenário novo **22** (número reservado), logo antes
  do cenário 11, no padrão do cenário 16 (passo do fluxo extraído do YAML renderizado e executado
  com `gh` falso): aprovação no head conta; aprovação em commit anterior não conta; aprovação
  seguida de pedido de mudança no head não conta.
- Frente paralela a outras quatro (#7, #8, #10 e a de #18/#19). No rebase sobre `main`, conflito
  de inserção em `scripts/testar-configurar.sh` se resolve mantendo os dois blocos.
- Registro SDD em `docs/specs/codeowner-aprovacao-atual/`.
