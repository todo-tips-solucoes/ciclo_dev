# Data Model: modo-autonomo

**Fonte normativa**: [decisoes-do-owner.md](decisoes-do-owner.md) (D1 a D13). A frente não tem
banco nem estado próprio: as "entidades" abaixo são linhas de texto, blocos de Markdown, objetos da
API do GitHub lidos na hora e a saída JSON de um subcomando. Nomes de campo da API do GitHub só
aparecem quando a [research.md](research.md) os cita da fonte oficial.

## Entity: Chave `MODO_AUTONOMO` (`cockpit.config`)

| Campo | Tipo | Regra |
|---|---|---|
| valor | `ligado` \| `desligado` | opcional (D1) |

### Regras

- Ausente, vazia ou fora do conjunto exato (`Ligado`, `sim`, aspas duplas): vale `desligado`, com
  aviso no stderr do configurador; nunca erro (o `--atualizar` não quebra, FR-001, SC-001).
- A pergunta interativa sugere `desligado`.
- Só o configurador lê a chave. O rito não a consome (fica na lista de chaves não consumidas da
  skill, FR-004): a fonte da verdade do rito é a linha da constituição.

## Entity: Linha de modo (`Merge autônomo: ligado|desligado`)

| Campo | Tipo | Regra |
|---|---|---|
| texto | linha literal | `Merge autônomo: ligado` ou `Merge autônomo: desligado` |
| origem | blob | `origin/<BRANCH_INTEGRACAO>:docs/constitution.md`, nunca a worktree |

### Regras

- Escrita uma vez pelo configurador, na constituição semente, a partir da chave normalizada
  (FR-002). A semente só é gerada quando o destino não existe; projeto já ratificado fica sem a
  linha e vale `desligado` até emenda própria.
- Leitura (D1, mesma regra da linha "Instalação pelo agente" da `rito-descoberta`), depois de tirar
  o `\r` (constituição commitada com CRLF): vale `ligado` só quando `grep -cE '^Merge autônomo: (ligado|desligado)$'` dá exatamente 1 e
  `grep -cFx 'Merge autônomo: ligado'` dá 1. Qualquer outro resultado (nenhuma linha, duas ou mais,
  `desligado`, leitura que falhou) vale `desligado`.
- Escrita uma vez na skill `rito-dev` (seção "Modo autônomo") e citada pela `rito-descoberta`.
- Relida antes de cada merge e de cada promoção (FR-003).
- O agente nunca edita a linha nem a chave (MUST NOT na semente, FR-004); a trava reprova
  `docs/constitution.md` como caminho de governança (lista completa, com A2/F1, em FR-009 e `contracts/caminhos-previstos.md`).

## Entity: Modo efetivo

Valor derivado na hora de cada merge e de cada promoção. Não é gravado.

| Entrada | Condição para `ligado` |
|---|---|
| Linha de modo | `ligado` pela regra acima |
| Identidade do agente (D2) | conferida na hora (contrato [modo-autonomo.md](contracts/modo-autonomo.md) §Pré-condições) |
| Ruleset da integração (D5) | `current_user_can_bypass` = `never` e `ci`, `commitlint` e `caminhos-previstos` obrigatórios (research R3, D-P7) |

Qualquer entrada que falhe ou não possa ser lida: `desligado`, e o rito para no gate humano
(FR-005, US3 cenário 2).

## Entity: Registro da Fase 0 na base

`docs/specs/<frente>/decisoes-do-owner.md` lido em `origin/<BRANCH_INTEGRACAO>` (D3), nunca no PR.

| Seção | Uso |
|---|---|
| `## Caminhos previstos` | 1º bloco cercado depois do título: um caminho por linha |
| `## Dependências novas` | formato fechado: `Nenhuma.` ou itens `` - `<pacote>` ``; só o item de lista com trecho de código entre crases conta como aprovado, e qualquer outro texto vale "nenhuma"; manifesto ou lockfile só passa se também listado literalmente em "Caminhos previstos" (Clarifications, Q1) |
| `## Smoke` | itens `Sn \| comando \| esperado literal \| tipo` (D7) |
| `## Irreversibilidade` | `Nenhuma.` ou descrição; diferente de "Nenhuma" para no gate da promoção |

### Regras do bloco "Caminhos previstos"

- Cada linha não vazia é um caminho literal ou `dir/**`, relativo à raiz.
- Reprova o bloco (e portanto o PR): caminho absoluto, segmento `..` ou `.`, curinga fora do sufixo
  `/**`, linha com espaço nas pontas, bloco ausente ou vazio.
- `docs/specs/<frente>/**` é implícito (D4).
- Casamento: igualdade exata para literal; para `dir/**`, prefixo `dir/` exato. Sem glob geral,
  sem regex vinda do arquivo.

### State Transitions

```text
Gate 0 dado → PR de registro aberta (modo ligado) → mergeada pelo owner → registro na base
                                                   → fechada sem merge → frente não aprovada (fim)
```

No modo desligado não há PR de registro: o registro segue como 1º commit da worktree (US4 cenário 2).

## Entity: Frente de uma PR

Derivada pela trava só de dados da base e da lista de arquivos do PR (D4: "a frente sai do
registro, nunca do título nem da branch").

| Tipo de PR | Como se reconhece |
|---|---|
| PR de frente | toca `docs/specs/<x>/**` para exatamente um `<x>` cujo `decisoes-do-owner.md` existe na base |
| PR de correção ou revert | tem no corpo exatamente uma linha `Origem: #<n>`; a PR `#<n>` está mergeada na mesma base e é PR de frente; os arquivos da correção cabem nos dela e no bloco "Caminhos previstos" da frente dela |
| PR só de registros | todo arquivo é `docs/specs/<x>/decisoes-do-owner.md` (PR de registro ou de emenda): vai à aprovação de dono sem validar o bloco (decisão do owner na rodada 3) |
| PR sem registro | nenhum dos dois casos (docs, trivial, hotfix) |
| PR de promoção | base = `BRANCH_PRODUCAO` e cabeça = `BRANCH_INTEGRACAO` do mesmo repositório: passa sozinha na trava (D8; A1 do block-001) |
| PR para a produção que não é a de promoção | base = `BRANCH_PRODUCAO` e outra cabeça (ou fork): só com aprovação de dono no commit atual (A1) |
| PR de outro repositório (fork) | cabeça em outro repositório, ou sem repositório, qualquer que seja a base: só com aprovação de dono no commit atual, depois das conferências que falham direto (decisão do owner na rodada 1 do `bmad-code-review`) |

### Regras

- PR de frente que altera o próprio `docs/specs/<x>/decisoes-do-owner.md` cai em aprovação de dono
  (o registro é governança): o registro só muda com o owner.
- Dois ou mais `<x>` com registro na base: reprova (a frente é ambígua).
- `Origem:` apontando para PR aberta, de outra base ou que não é PR de frente: reprova.
- O corpo é dado escrito pelo agente, mas só serve para achar a PR original; a decisão sai da
  lista de arquivos das duas PRs, lida na API.

## Entity: Veredito da trava

| Campo | Tipo | Regra |
|---|---|---|
| sha | SHA do HEAD do PR | o status é publicado nesse SHA |
| contexto | `caminhos-previstos` (base = integração) ou `caminhos-previstos-producao` (base = produção ≠ integração) | nome do check obrigatório no ruleset de cada branch (D-P11) |
| estado | `success` \| `failure` | nunca `pending` como resultado final |
| descrição | texto curto | primeiro motivo de reprovação ou "conforme registro" |

Motivos de reprovação direta (FR-009 a FR-011; a aprovação de dono não muda): fora da lista;
renomeação com nome novo ou anterior fora; total listado diferente de `changed_files`; lista com
linha inválida (inclusive nome com caractere de controle); manifesto ou lockfile sem item aprovado;
correção ou revert fora dos arquivos da PR original ou do bloco da frente dela, ou com origem não
mergeada na mesma base ou que não é PR de frente; frente ambígua; bloco ausente, vazio ou inválido; erro de leitura.

Exigem dono (passam só com aprovação de dono no commit atual, lida depois de todas as reprovações
diretas; o contrato `caminhos-previstos.md` tem a ordem): PR sem registro; caminho de governança
(salvo acréscimo puro em `permissions.deny`, definido em FR-009), inclusive o próprio registro da
frente; PR de outro repositório (fork); PR para a produção que não é a de promoção (A1); correção
ou revert com manifesto ou lockfile; PR só de registros, sem validar o bloco. Caminho de governança
que a frente toca precisa estar no bloco: a aprovação não libera arquivo fora dele.

## Entity: Contador de correções

| Contador | Fonte | Teto |
|---|---|---|
| CI | SHAs distintos do PR com o check `ci` em falha; rerun do mesmo SHA não conta | 2 correções (3º vermelho estaciona) |
| Smoke | PRs com rótulo `correcao-<n>` e `Origem: #<pr-da-frente>`, por `gh pr list --state all` | 2 correções (3ª falha reverte) |

### State Transitions

```text
verde → merge
vermelho 1 → correção 1 → vermelho 2 → correção 2 → vermelho 3 → estacionada (CI)
smoke falho 1 → rerun único do mesmo SHA → falho → correção 1 → ... → 3ª falha → reverts em ordem inversa
revert com conflito ou CI vermelho → para, owner (sem laço)
```

## Entity: Frente estacionada

PR em rascunho com rótulo `estacionada`, auto-merge desligado, diagnóstico e recomendação ao
owner. Worktree mantida; a Fase 11 não roda (D6, FR-016).

## Entity: Item de smoke

| Campo | Tipo | Regra |
|---|---|---|
| id | `S<n>` | único no registro |
| comando | texto | não vazio para item executável |
| esperado literal | texto | substring literal do stdout, sem regex (Clarifications, Q2) |
| tipo | `positivo` \| `negativo` \| `manual` | positivo: exit 0; negativo: exit diferente de 0; manual: humano |

### Regras

- Congelado no Gate 0 (D7); mudar exige OK do owner.
- Frente elegível ao merge autônomo: ao menos um item executável e ao menos um `negativo`.
- Qualquer item `manual` ou irreversibilidade diferente de "Nenhuma": para no gate da promoção.
- Falha transitória: um único rerun do mesmo SHA antes de contar (Clarifications, Q4).

## Entity: Lote de promoção

| Campo | Regra |
|---|---|
| SHA fixado | ponta de `origin/<BRANCH_INTEGRACAO>` no início do smoke combinado |
| frentes | PRs de frente mergeadas entre `origin/<BRANCH_PRODUCAO>` e o SHA fixado |
| resultado | por frente, do smoke combinado no SHA fixado |
| rollback | SHA de `origin/<BRANCH_PRODUCAO>` antes da promoção, anotado antes do merge direto em X (sem auto-merge, decisão do owner na rodada 2) |

### Regras

- Ponta mudou depois do smoke: roda de novo (FR-018).
- Frente irreversível ou item manual no lote: gate humano.
- Integração = produção: promoção no-op; o rollback é o do D6.

## Entity: Veredito de plugin (`historico.mjs plugin`)

Saída JSON do subcomando (contrato [historico-plugin.md](contracts/historico-plugin.md)).

| Campo | Tipo | Regra |
|---|---|---|
| `plugin` | texto | nome do `plugin.json` |
| `sha` | texto | `gitCommitSha` da entrada instalada, quando lido; senão o veredito é reprovado |
| `veredito` | `ok` \| `reprovado` | lista fechada (D10) |
| `motivos` | lista de texto | vazia quando `ok` |
| `deny` | lista de regra | duas por agente do plugin que reprova em (a), (b) ou (c), nas duas formas da research R1 |

## Entity: Conjunto deny gravado

`permissions.deny` do `.claude/settings.json` da worktree (D9).

### Regras

- União idempotente: regra já presente não duplica; ordem estável.
- Mais uma negação fixa: `Edit(/.claude/settings*.json)`, que cobre edição e escrita (research R1, D-P1).
- Cobre o conjunto atual quando cada regra do `deny` do veredito está no arquivo. Não cobre:
  reprova no gate da Fase 11 e no estado "SHA divergente".

### Relationships

```text
Chave MODO_AUTONOMO --configurar--> Linha de modo (semente) --rito lê na base--> Modo efetivo
Registro na base --trava lê--> Veredito da trava --check obrigatório--> merge autônomo
Registro (Smoke, Irreversibilidade) --> Item de smoke --> Lote de promoção
Veredito de plugin --skill mescla--> Conjunto deny gravado
```
