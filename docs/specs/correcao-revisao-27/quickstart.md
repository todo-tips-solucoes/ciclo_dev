# Quickstart: correções do code review retroativo da PR #27

Cenários que validam a frente. Rode tudo a partir da raiz da worktree.

**Mutações:** as que provam que um teste falha sem a proteção rodam numa cópia descartável, nunca
na worktree:

```bash
S="$(mktemp -d)"
tar --exclude=.git -cf - . | tar -xf - -C "$S"
```

Na cópia, aplique **uma** mutação por vez, rode `bash "$S/scripts/testar-configurar.sh"` e confira
a linha `FALHOU:`. A cópia não tem `.git`, e o cenário 11 pode acusar ocorrência do verificador de
agnosticismo nela (research, M2). Como ele roda por último, isso não mascara as falhas dos
cenários 21 e 22. Depois de cada sonda, confira que não sobrou processo da suíte
(`pgrep -fa testar-configurar`).

## Scenario 1: suíte inteira verde (happy path)

1. `bash scripts/testar-configurar.sh`
2. **Expected**: a suíte imprime `OK: todos os cenários passaram.`, com os cenários 11
   (shellcheck), 16 (actionlint), 21 e 22 incluídos (SC-001, SC-004).

## Scenario 2: head vazio depende da guarda (C3)

1. Na cópia, apague as quatro linhas da guarda
   (`if [ -z "$head" ]; then` … `fi`, l.47-50 de
   `templates/.github/workflows/require-codeowner-approval.yml.tmpl`).
2. Rode a suíte da cópia.
3. **Expected**: `FALHOU: cenário 22 … caso 13`, porque o passo sai 0 com "Aprovado por um dono."
   em vez da mensagem de head ilegível.

## Scenario 3: mensagem `Aprovação pendente` exigida (C4)

1. Leia os casos 3, 6, 7, 9 e 10 do cenário 22.
2. **Expected**: cada um tem `grep -q 'Aprovação pendente' "$TMP/out"` na própria linha de asserção,
   além de `rc=1`. Sem isso, um `rc=1` vindo da rota não casada do `gh` falso passaria como
   reprovação. Não há mutação aqui: trocar o texto da l.60 do modelo não distingue C4, porque o
   caso 2 já conferia a mensagem antes desta frente.

## Scenario 4: `--paginate` exigido nas reviews (C5)

1. Na cópia, tire `--paginate` da l.52 do mesmo modelo.
2. **Expected**: `FALHOU: cenário 22 … caso 1` (o `gh` falso sai 97 e o passo não aprova).

## Scenario 5: `export LC_ALL=C` nos dois modelos (C6)

1. Na cópia, apague a linha `export LC_ALL=C` de
   `templates/.github/workflows/audit-merge-vermelho.yml.tmpl`. Rode a suíte.
2. Repita, numa cópia nova, com `require-codeowner-approval.yml.tmpl`.
3. **Expected**: nas duas, o cenário 22 falha antes da guarda de `jq`, com mensagem que nomeia o
   modelo sem a linha.

## Scenario 6: caso 1 do cenário 21 sem dica e sem hook (C7, C8)

1. Na cópia, troque `[ "$MODO" != atualizar ] ||` por `false ||` na linha da dica de renomear de
   `configurar.sh` (l.296), para que a dica saia também em `--respostas`.
2. **Expected**: `FALHOU: cenário 21 … caso 1`, por causa da dica.
3. Numa cópia nova, acrescente ao fim de `resolver_raiz` (`configurar.sh`, depois da conferência
   da raiz, l.521-522) a linha `: >"$RAIZ/.git/hooks/pre-commit"`.
4. Numa terceira cópia, no mesmo ponto, `git -C "$RAIZ" config core.hooksPath x`.
5. **Expected**: `FALHOU: cenário 21 … caso 1` em cada uma das duas mutações. Elas rodam antes da
   validação das chaves, que é o que o caso 1 recusa.

## Scenario 7: caso 7 do cenário 21 isolado (C9)

1. Leia o caso 7.
2. **Expected**: ele não chama `sha256sum` nem `sha`, escreve um literal de 64 hexadecimais com dois
   espaços antes do caminho e usa um arquivo de respostas próprio (não `$TMP/r21`). `DEST21` fica
   no topo do cenário, junto de `RE_B` e `respb`, e não dentro do caso 5.

## Scenario 8: leitura de valores na `rito-dev` (C14)

1. Siga o passo 1 da skill com `CMD_BUILD='npm run build -- --env "producao"'`.
2. **Expected**: o valor lido é `npm run build -- --env "producao"` e a skill não para.
3. Siga com um valor gravado pelo configurador a partir de `it's` (`'it'\''s'`).
4. **Expected**: o valor lido é `it's`.
5. Siga com `BRANCH_PRODUCAO='"main"'` e, separado, com `BRANCH_PRODUCAO='main`.
6. **Expected**: nos dois, a skill PARA nomeando `BRANCH_PRODUCAO`, sem colar o valor num comando.

## Scenario 9: `parallel-work` cita a conferência no topo (C12)

1. Leia a l.3 (descrição) e o bloco do topo de `skills/parallel-work/SKILL.md`.
2. **Expected**: os dois dizem que o valor é conferido (aspas tiradas, regra
   `^[A-Za-z0-9][A-Za-z0-9._/-]*$`) antes de compor o `--base`.
3. Meça a descrição:

   ```bash
   node -e 'const l=require("fs").readFileSync("skills/parallel-work/SKILL.md","utf8").split("\n")[2];let v=l.replace(/^description: /,"");if(v[0]==="\x27")v=v.slice(1,-1).replace(/\x27\x27/g,"\x27");console.log([...v].length)'
   ```

4. **Expected**: até `1024`.

## Scenario 10: registros das frentes anteriores (C2, C10, C11, C13)

1. Releia cada trecho da tabela "Afirmação de registro SDD" de [data-model.md](data-model.md).
2. **Expected**: cada um concorda com a fonte da última coluna. Nenhuma frase que diga que o
   `set -e` derruba o passo na leitura das árvores sobrevive (leia os trechos de
   `grep -n 'derruba o passo'` nas duas research; "não derruba o passo" é a frase correta). A research da `revisao-lote-21-25` lista como regressão o 6 do 22, o 5 do 24 e a
   dica do 3b do 21.

## Scenario 11: escopo (SC-005)

1. `git diff --stat origin/main...HEAD`
2. **Expected**: nenhum arquivo ou trecho dos itens de "Fora de escopo" de
   [decisoes-do-owner.md](decisoes-do-owner.md) alterado. Em `require-codeowner-approval.yml.tmpl`
   e `CODEOWNERS.tmpl`, só mudam linhas que começam com `#`.
