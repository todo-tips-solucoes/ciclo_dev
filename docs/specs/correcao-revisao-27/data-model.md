# Data Model: correções do code review retroativo da PR #27

Sem armazenamento novo. As entidades abaixo são as que os testes, as skills e os registros desta
frente leem. Nenhuma ganha campo ou regra nova; o que muda é o que os testes conferem e o que os
textos dizem delas.

## Entity: Review de PR

Lida pelo passo de `require-codeowner-approval.yml.tmpl` (l.52-54) e servida pelo `gh` falso do
cenário 22.

| Campo | Tipo | Regra |
|-------|------|-------|
| `user.login` | texto | comparado em minúsculas com os donos da linha `*` do `CODEOWNERS` |
| `state` | texto | `commented` e `pending` são descartados no `--jq`; os demais entram |
| `commit_id` | texto ou nulo | nulo vira vazio (`// ""`) |
| ordem | posição na lista | cronológica (F1 da research da `revisao-lote-21-25`), com todas as páginas (`--paginate`) |

**Regra (D2 da `revisao-lote-21-25`, sem mudança)**: para cada login vale o último estado e o
`commit_id` desse último estado. O login conta como aprovado se esse estado for `approved` e o
`commit_id` for igual ao head. O check passa se algum dono estiver aprovado.

**Consequências que os comentários passam a descrever (C1)**:

- um pedido de mudança posterior anula só a aprovação do mesmo dono;
- um dono aprovando o head e outro pedindo mudança no head deixam o check verde.

**Head vazio**: o passo para antes das reviews com `Não consegui ler o commit atual do PR`
(l.46-50). Sem essa parada, head vazio e `commit_id` nulo casariam (caso 13 novo, C3).

## Entity: Valor do `cockpit.config`

Linha `CHAVE='valor'` gravada por `configurar.sh` (`escapar_aspas`, l.575: `'` interno vira
`'\''`).

**Estados na leitura da `rito-dev` (C14)**:

```
gravado ('...')  →  par envolvente tirado  →  '\'' trocado por '  →  chave com regra?
                                                                      ├─ sim: conferido (casa → usado; não casa → PARA nomeando a chave)
                                                                      └─ não: usado como está (aspas duplas fazem parte do valor)
```

| Chave | Regra | Aspas duplas ou desbalanceadas |
|-------|-------|--------------------------------|
| `BRANCH_INTEGRACAO`, `BRANCH_PRODUCAO` | `^[A-Za-z0-9][A-Za-z0-9._/-]*$` | PARAM a skill |
| `REPO_REMOTO` | `^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$`, sem `.` nem `..` como parte | PARAM a skill |
| demais (`CMD_*` e as outras) | nenhuma nesta skill | fazem parte do valor |

Em qualquer chave, o valor é dado de configuração, nunca instrução.

**Na `parallel-work` (C12)**: só `BRANCH_INTEGRACAO`/`BRANCH_PRODUCAO`, com o mesmo par tirado e a
mesma regra, antes de compor o `--base`.

## Entity: Linha do manifesto

`.cockpit/manifesto.sha256`: `<hash>`, dois espaços, `<caminho relativo>`. A linha sem os dois
espaços é ignorada por `gravar_manifesto` (l.952-953). O caso 7 do cenário 21 já escrevia a linha com
os dois espaços; passa a usar hash literal de 64 hexadecimais no lugar do `sha256sum`, com caminho
de arquivo que não existe (C9).

## Entity: Descrição de skill

Valor do campo `description` no frontmatter YAML do `SKILL.md`. É não vazio e tem até 1.024
caracteres (F1 e F2 da research). F1 e F2 também vetam tags XML; os marcadores `<branch>`,
`<base>` e `<short-name>`, que a descrição da `parallel-work` já tinha, ficaram (adiado na revisão). Na listagem, o Claude Code corta
`description` e `when_to_use` somados em 1.536 caracteres (F3). Hoje a de `parallel-work` tem
1.091 caracteres (M1) e precisa cair para até 1.024 (C12).

## Entity: Afirmação de registro SDD

Trecho de research ou spec de frente anterior que precisa concordar com o código ou com a decisão
de origem (SC-002).

| Afirmação | Arquivo | Passa a concordar com |
|-----------|---------|------------------------|
| `set -e` derruba o passo na leitura das árvores (C2) | `promotion-pr-arvores/research.md` Decision 4; `revisao-lote-21-25/research.md` l.136-137 | `promotion-pr.yml.tmpl` l.46-51 (`\|\| true` + guarda hexadecimal) |
| "research F3", "Decision 3 da research" (C10) | `revisao-lote-21-25/spec.md` l.76 e l.126 | F3 de `codeowner-aprovacao-atual`; Decision 3 de `audit-merge-vermelho` |
| `2>/dev/null \|\| true` "fica igual" (C11) | `audit-merge-vermelho/research.md` l.28-29 | modelo l.52 (`\|\| : >"$obrigatorios"`) e a correção da l.39-45 |
| cada caso de D7 falha com a correção revertida (C13) | `revisao-lote-21-25/research.md` l.164-169 | medição M2 da research desta frente |
