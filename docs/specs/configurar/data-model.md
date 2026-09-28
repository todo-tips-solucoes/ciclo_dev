# Data Model: configurar

**Feature**: `configurar` | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

Sem banco de dados: as entidades são arquivos texto no projeto-alvo e no
cockpit.

---

## Entity: `cockpit.config` (extensão retrocompatível)

Base: [data-model de skills-do-cockpit](../skills-do-cockpit/data-model.md)
(10 obrigatórias + 2 opcionais). Esta feature acrescenta 3 chaves e fixa a
forma de escrita.

| Campo | Obrigatória p/ `rito-dev` | Obrigatória p/ `configurar.sh` | Constraints |
|-------|:-:|:-:|---|
| `PROJETO_NOME` … `CMD_DEPLOY_PRODUCAO` (10) | sim | sim | como no data-model base |
| `URL_AMBIENTE_INTEGRACAO`, `URL_AMBIENTE_PRODUCAO` | não | não | `^https?://[^[:space:]]+$` ou ausente |
| `IDENTIDADES` | não | sim | 1+ itens `nome:email` separados por `;` — ver [Decision 5 (proposta)](./research.md) |
| `BOARD` | não | sim (pode ser vazio) | `''` = projeto sem board; senão texto não vazio de uma linha |
| `PRINCIPIO_III` | não | sim (padrão `ligado`) | `ligado` \| `desligado` |

### Regras

- **Leitura** (research Decision 2): linha a linha, sem `source`; `#` e linha
  vazia ignoradas; chave `[A-Z][A-Z0-9_]*`; um par envolvente de aspas simples
  ou duplas é removido; CRLF tolerado. Última atribuição da chave vale.
- **Escrita** (research Decision 3): `CHAVE='valor'`, `'` interno como
  `'\''`, ordem fixa da tabela acima, cabeçalho fixo, sem data. Resultado é
  legível por `source` em bash.
- Nenhum valor pode conter quebra de linha nem caractere de controle (bytes 0x00–0x1F e 0x7F) — recusado na validação, o que também impede sequência ANSI de chegar ao terminal quando os valores lidos são exibidos.
- Chave desconhecida em config existente: reportada e **não** regravada
  (spec, Edge Cases); chave obrigatória ausente: perguntada (modo
  interativo) ou erro nomeando a chave (modo não interativo).
- Um `cockpit.config` sem `IDENTIDADES`/`BOARD`/`PRINCIPIO_III` continua
  válido para `rito-dev` (FR-003).

### Validação por chave (FR-004)

| Chave | Regra |
|---|---|
| `REPO_REMOTO` | `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$` |
| `BRANCH_*` | `git check-ref-format --branch <valor>` passa |
| `CMD_*`, `PROJETO_NOME`, `GERENCIADOR_PACOTES` | não vazio após remover espaços |
| `URL_*` | vazio (ausente) ou `^https?://[^[:space:]]+$` |
| `IDENTIDADES` | ver Decision 5; ≥ 1 item |
| `PRINCIPIO_III` | `ligado` ou `desligado` |

---

## Entity: Arquivo de respostas

Mesmo formato e mesma leitura do `cockpit.config` (clarificação Q2,
dec-008). Contém os valores finais — inclusive `IDENTIDADES` já no formato
gravado. `cockpit.config.example` é um arquivo de respostas válido. Variáveis
de ambiente não são fonte de valor.

---

## Entity: Template

| Campo | Notes |
|---|---|
| origem | `<cockpit>/templates/<rel>` — arquivo regular (links simbólicos ignorados) |
| destino | `<projeto>/<rel sem sufixo .tmpl>` (research Decision 9) |
| placeholder | `{{CHAVE}}`, `CHAVE` em `[A-Z][A-Z0-9_]*`; qualquer outro `{{…}}` é literal |

Placeholder resolvido = chave presente no config (valor vazio conta como
resolvido, ex.: `BOARD=''`). Não resolvido = residual → falha (FR-010).

Templates de prova desta feature (FR-012): `templates/.cockpit/LEIAME.md.tmpl`
— resumo legível dos valores configurados, usando todas as chaves
obrigatórias e ao menos um valor com caracteres especiais nos testes.

---

## Entity: Manifesto de render

Arquivo `<projeto>/.cockpit/manifesto.sha256`, formato de `sha256sum`
(`<64 hex>  <caminho relativo>`), uma linha por arquivo renderizado,
ordenado por caminho. Não inclui `cockpit.config` (editá-lo à mão é o uso
previsto) nem o próprio manifesto.

### State transitions de um arquivo de destino

```
ausente ──render──▶ gerenciado (hash = manifesto)
gerenciado ──edição manual──▶ editado (hash ≠ manifesto)
editado ──render com conteúdo novo diferente──▶ conflito ──(--forcar | "s")──▶ gerenciado
                                                        └──(sem confirmação)──▶ editado (inalterado, aviso)
qualquer ──conteúdo novo == conteúdo atual──▶ gerenciado (sem escrita)
```

Arquivo existente fora do manifesto é tratado como `editado`.
