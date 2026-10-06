# Data Model: endurecimento do configurador (branches e manifesto)

Sem entidade nova nem mudança de formato. Duas regras mudam.

## Entity: chaves `BRANCH_INTEGRACAO` e `BRANCH_PRODUCAO` (`cockpit.config`)

| Campo | Tipo | Regra | Fonte |
|---|---|---|---|
| `BRANCH_INTEGRACAO` | texto, obrigatória | `^[A-Za-z0-9][A-Za-z0-9._/-]*$` e `git check-ref-format --branch` | D1 |
| `BRANCH_PRODUCAO` | texto, obrigatória | idem; pode repetir `BRANCH_INTEGRACAO` (Princípio I) | D1 |

### Validação (ordem em `validar_chave`)

1. Guarda geral de controle e bidi (todas as chaves, sem mudança).
2. Regex de D1 (`RE_BRANCH`, sob `LC_ALL=C`: intervalos ASCII).
3. `git check-ref-format --branch` (recusa `a..b`, `/` final, `//`, `.lock`, que a regex aceita).

2 e 3 compartilham a mensagem do [contrato](contracts/cli.md). Mesma regra de caracteres conferida
pela skill `rito-dev` ao ler o config (D2), sem o passo 3.

## Entity: manifesto (`.cockpit/manifesto.sha256`)

Formato inalterado (`<sha256>  <caminho>`, ordenado pelo caminho).

| Situação | Antes | Depois |
|---|---|---|
| sem manifesto anterior, ≥ 1 linha a registrar | grava | grava |
| sem manifesto anterior, 0 linha a registrar, ≥ 1 template | grava vazio e cria `.cockpit/` | não grava, não cria `.cockpit/` |
| sem manifesto anterior, nenhum template | não grava | não grava |
| com manifesto anterior | regrava quando o conteúdo muda | igual |

Linha a registrar: destino gerado nesta execução, linha preservada de destino pulado (`projeto`,
`semente`, `ignorado`) que já estava no manifesto anterior, ou órfã mantida. Cópia da árvore
principal nunca é linha.
