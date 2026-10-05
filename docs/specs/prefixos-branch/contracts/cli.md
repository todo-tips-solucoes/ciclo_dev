# Contracts: prefixos de branch — delta do `configurar.sh`

[PROPOSTA — a validar na implementação]: delta de interface desenhado nesta feature sobre o
contrato de [`configurar`](../../configurar/contracts/cli.md). O único comportamento de terceiro
citado é o de `git check-ref-format --branch`, com fonte em
[research Decision 2](../research.md).

## Chave `PREFIXOS_BRANCH`

- Opcional. Cinco prefixos separados por espaço, na ordem `feature`, `fix`, `chore`, `docs`,
  `hotfix`. Ausente, vazia ou só de espaços: vale `feature fix chore docs hotfix`.
- Validação e mensagens: [data-model](../data-model.md) §Validação. Valor inválido no modo não
  interativo (`--respostas`, `--atualizar`): exit 1, nada gravado. No interativo: mensagem e a
  mesma pergunta de novo.
- Gravação: `PREFIXOS_BRANCH='<valor>'` como última linha de chave conhecida; omitida quando vazia.
  Os placeholders `PREFIXO_*` nunca são gravados.

## Pergunta interativa

Última pergunta, depois da de `DESTINOS_DO_PROJETO`:

```
Prefixos de branch de feature, fix, chore, docs e hotfix, nessa ordem (padrão: feature fix chore docs hotfix) (- para vazio):
```

Com valor atual no config, ele aparece entre colchetes no fim, como nas demais. Enter sem valor
atual ou `-`: chave ausente. A configuração mínima passa de 19 para 20 respostas.

## Render

- Placeholders sempre definidos: `{{PREFIXO_FEATURE}}`, `{{PREFIXO_FIX}}`, `{{PREFIXO_CHORE}}`,
  `{{PREFIXO_DOCS}}`, `{{PREFIXO_HOTFIX}}`. Nunca geram `Placeholder sem valor`.
- Sem a chave, `docs/CICLO-GIT.md` e `docs/rito-dev.md` saem byte a byte iguais aos de antes.

## Códigos de saída

Sem código novo: valor inválido é exit 1 (linha "valor inválido no modo não interativo" do
contrato base). `--atualizar` de config sem a chave: comportamento de antes, sem pergunta nem
aviso novo.

## Skill `rito-dev`, Fase 1

- Lê `PREFIXOS_BRANCH` do `cockpit.config` no momento da fase. Ausente ou em branco: padrão.
- Valor sem exatamente cinco prefixos, ou com prefixo contendo `/`: nomeia a chave e PARA.
- Nomes de branch: `<1º>/<slug>`, `<2º>/<slug>`, `<3º>/<slug>`, `<4º>/<slug>` a partir de
  `origin/<BRANCH_INTEGRACAO>`; `<5º>/<slug>` a partir de `<BRANCH_PRODUCAO>`, só com incidente
  real.
