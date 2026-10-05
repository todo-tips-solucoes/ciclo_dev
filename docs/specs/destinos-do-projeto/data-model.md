# Data Model: destinos do projeto

**Feature**: `destinos-do-projeto` | **Date**: 2026-10-05

Sem persistência nova. A chave nova vive no `cockpit.config` existente; o resto é estado de uma
execução de `configurar.sh` (arrays bash paralelos indexados como `DEST_REL`) e o manifesto já
existente.

## Entity: `cockpit.config` — chave `DESTINOS_DO_PROJETO`

| Campo | Obrigatória | Constraints |
|-------|:-:|---|
| `DESTINOS_DO_PROJETO` | não (opcional, em `CHAVES_OPCIONAIS`) | lista de caminhos relativos à raiz, separados por espaço; ausente, vazia ou só espaços = não declarada |

- Posição: última de `CHAVES_ORDEM` (última linha gravada, última pergunta).
- Escrita: `gravar_config` sem mudança (`CHAVE='valor'`); não declarada não é gravada.
- Leitura: `ler_kv`/`desaspar` sem mudança; as aspas de um item (`''`, `""`) só sobrevivem
  dentro de valor entre aspas do outro tipo, e aí são recusadas pela validação.

### Validação (fronteira de confiança, antes de qualquer escrita)

| Regra | Resultado |
|---|---|
| valor com caractere de controle (inclui TAB) | exit 1, mensagem atual de `tem_controle`, citando a chave |
| item só de aspas (`''`, `""`) | exit 1, `Valor inválido para DESTINOS_DO_PROJETO: item '…' vazio (só aspas).` |
| item que começa com `/` | exit 1, `… item '…' é absoluto.` |
| item com componente `..` | exit 1, `… item '…' contém '..'.` |
| item diferente de todo `DEST_REL[i]` | `Aviso:` em stderr; o lote segue |

No modo interativo, valor inválido é perguntado de novo (contrato atual de `perguntar`).

## Entity: Destino (estado de uma execução)

| Campo | Tipo | Origem | Notas |
|-------|------|--------|-------|
| `DEST_REL[i]` | caminho relativo | existente | destino do template |
| `SEMENTE[i]` | 0/1 | existente | template `.semente.tmpl` |
| `PULAR[i]` | motivo | **muda** (era 0/1) | vazio = renderiza; `semente`, `projeto`, `copia`, `ignorado` |
| `ORIGEM[i]` | caminho absoluto ou vazio | **novo** | `copia`: arquivo a copiar; `ignorado`: caminho esperado na árvore principal (vazio se ela está indisponível) |

### Regra de classificação (`classificar_destinos`)

| Condição | `PULAR[i]` |
|---|---|
| listado em `DESTINOS_DO_PROJETO` | `projeto` |
| não listado, semente, destino existe (`-e` ou `-L`) | `semente` |
| demais | vazio |
| sobrepõe as linhas acima: (semente ou listado) e destino ausente e worktree vinculada e `check-ignore` exit 0, com origem válida | `copia` |
| idem, sem origem válida (ausente, link, bare, não confirmada) | `ignorado` |

### Efeito por motivo

| `PULAR[i]` | Render / residual | Conflito / `--forcar` / prompt | Gravação | Manifesto | Relatório (stdout) |
|---|---|---|---|---|---|
| vazio | sim | sim (regra atual) | grava | hash novo | `gravado:` / `inalterado:` |
| `semente` | não | não | nada | linha anterior | `mantido (semente): <rel>` |
| `projeto` | não | não | nada | linha anterior | `mantido (projeto): <rel>` |
| `copia` | não | não | `cp` da origem, sob as guardas de contenção | linha anterior (nada novo) | `copiado da árvore principal: <rel>` |
| `ignorado` | não | não | nada | linha anterior | `mantido (ignorado pelo git): <rel> (esperado em <ORIGEM>)` |

### State transitions de um destino listado ou de semente numa worktree vinculada

```
ausente + ignorado + origem válida ──1ª execução──▶ copiado (fora do manifesto)
copiado ──2ª execução──▶ existe ──▶ semente | projeto (intacto)
ausente + ignorado + sem origem ──▶ ausente (aviso; nada gerado)
ausente + não ignorado ──▶ semente: renderizada (regra atual) | listado: ausente (não gerado)
```

## Entity: Árvore principal (estado de uma execução)

| Campo | Tipo | Notas |
|-------|------|-------|
| `VINCULADA` | true/false | `git-dir` ≠ `git-common-dir`, ambos resolvidos com `pwd -P` |
| `PRINCIPAL` | caminho físico ou vazio | primeiro registro de `git worktree list --porcelain`, absoluto, sem caractere de controle, sem `bare`, confirmado pelo `git-dir` dele = `git-common-dir` da worktree |

Só leitura: nada é escrito fora de `$RAIZ` (FR-012).

## Entity: Manifesto (`.cockpit/manifesto.sha256`) — existente

Sem mudança de formato. A regra "destino pulado reemite a linha anterior, ou nenhuma" passa a
valer para todo `PULAR[i]` não vazio (antes só `PULAR=1`).
