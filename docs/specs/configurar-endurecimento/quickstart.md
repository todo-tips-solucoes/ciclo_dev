# Quickstart: endurecimento do configurador (branches e manifesto)

Todos os casos viram o cenário 21 de `scripts/testar-configurar.sh` (antes do 11), cada um num
repositório git temporário (`novo_repo`), com o `cstk` falso. Rodar: `./scripts/testar-configurar.sh`.

## 1. Valores recusados, nas duas chaves (US1, SC-001)

1. Para cada chave (`BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO`) e cada valor (`main;curl x`, `$(x)`,
   `` `x` ``, `a|b`, `a b`): arquivo de respostas do exemplo com a chave trocada.
2. `configurar.sh --projeto <repo> --respostas <arq>`.
3. **Expected**: exit 1; stderr cita a chave e `^[A-Za-z0-9][A-Za-z0-9._/-]*$`; `cockpit.config`
   e `.cockpit/` inexistentes.

## 2. Valores aceitos (US1, SC-002)

1. Respostas com `BRANCH_INTEGRACAO='release/2026'` e `BRANCH_PRODUCAO='main'`, depois o inverso.
2. `configurar.sh --respostas`.
3. **Expected**: exit 0; os dois valores gravados no `cockpit.config`.

## 3. `--atualizar` com config editado à mão (US1 cenário 4, FR-004)

1. Configurar um repositório com o exemplo; guardar cópia do `cockpit.config` e do manifesto.
2. Trocar à mão `BRANCH_PRODUCAO` por `'$(x)'` no `cockpit.config`.
3. `configurar.sh --projeto <repo> --atualizar </dev/null`.
4. **Expected**: exit 1; stderr cita `BRANCH_PRODUCAO`, o conjunto aceito e `Corrija o valor no
   cockpit.config`; `cockpit.config` (o editado) e manifesto byte a byte iguais aos de antes.

## 4. Modo interativo pergunta de novo (US1 cenário 3)

1. Com `script(1)` disponível: entrada mínima do cenário 14 com `a|b` antes do valor válido de
   `BRANCH_INTEGRACAO`.
2. **Expected**: a mensagem da chave aparece, a pergunta se repete e o valor válido é gravado.
   Sem `script(1)`: caso pulado com aviso, como no cenário 14.

## 5. Todos os destinos listados, sem manifesto anterior (US3, SC-003)

1. `DESTINOS_DO_PROJETO` com todos os destinos derivados de `templates/` (sufixo
   `.semente.tmpl` ou `.tmpl` removido), num repositório novo.
2. `configurar.sh --respostas`.
3. **Expected**: exit 0; `.cockpit/` inexistente; saída lista cada destino como `mantido
   (projeto)`.

## 6. Com manifesto anterior, regra de hoje (US3 cenário 2, FR-007)

1. Configurar com o exemplo (manifesto criado); depois rodar de novo com todos os destinos
   listados.
2. **Expected**: exit 0; manifesto continua existindo com as linhas dos destinos listados
   preservadas.

## 7. Regressão (SC-004)

Suíte inteira verde, incluído o cenário 13 ("sem templates: sem manifesto vazio") e o cenário 11
(shellcheck sem findings e `verificar-agnostico.sh`).

## Skill `rito-dev` (US2)

Conferência por leitura de `skills/rito-dev/SKILL.md`: a regra das duas chaves aparece na seção
de parâmetros, antes da Etapa preparatória e de qualquer bloco de comando, com PARAR nomeando a
chave e a proibição de colar o valor num comando.
