# Quickstart / Cenários de teste: configurar

**Feature**: `configurar` | **Spec**: [spec.md](./spec.md)

Todos os cenários são automatizados em `scripts/testar-configurar.sh`
(research Decision 11), cada um num repositório git temporário (`git init`),
com um `cstk` falso no `PATH` quando o cenário exige hooks.

## Cenário 1: configuração do zero, não interativa (US1, US5)

1. `git init "$T"` → 2. `./configurar.sh --projeto "$T" --respostas cockpit.config.example`
→ **Expected**: exit 0; `$T/cockpit.config` com as 10 obrigatórias + `IDENTIDADES`,
`BOARD`, `PRINCIPIO_III`; `bash -c 'set -u; source "$T/cockpit.config"'` sem erro;
`$T/.cockpit/LEIAME.md` sem `{{`; `$T/.cockpit/manifesto.sha256` presente;
`cstk` falso registrou `hooks install --project-path $T`.

## Cenário 2: idempotência byte a byte (US2, SC-002)

1. Cenário 1 → 2. copiar `$T` → 3. rodar de novo com as mesmas respostas
→ **Expected**: `diff -r` sem diferença (exceto `.git`).

## Cenário 3: `--atualizar` (US2)

1. Cenário 1 → 2. `./configurar.sh --projeto "$T" --atualizar </dev/null`
→ **Expected**: exit 0, nenhuma pergunta, arquivos idênticos.
3. Em repositório sem config → **Expected**: exit 1 e mensagem citando rodar sem `--atualizar`.

## Cenário 4: edição à mão preservada (US2, FR-007)

1. Cenário 1 → 2. editar `$T/.cockpit/LEIAME.md` → 3. mudar `PROJETO_NOME` nas respostas e rodar
→ **Expected**: exit 2; arquivo editado intacto; aviso com `--forcar`.
4. Rodar com `--forcar` → **Expected**: exit 0; arquivo re-renderizado; manifesto atualizado.

## Cenário 5: placeholder residual (US3, FR-010)

1. Cockpit de teste com `templates/x.md.tmpl` contendo `{{CHAVE_INEXISTENTE}}` → 2. rodar
→ **Expected**: exit 2; stderr cita `x.md.tmpl` e `{{CHAVE_INEXISTENTE}}`; `$T/x.md` não existe;
nenhum temporário restante em `$T`.

## Cenário 6: caracteres especiais (US3, FR-011)

1. Respostas com `CMD_BUILD='a/b & "c" $HOME \n'\''x'` → 2. rodar
→ **Expected**: a linha correspondente em `LEIAME.md` contém o valor literal, byte a byte;
`source cockpit.config` devolve o mesmo valor.

## Cenário 7: template novo sem mudar o script (US3, SC-004)

1. Adicionar `templates/novo/y.txt.tmpl` com `{{PROJETO_NOME}}` no cockpit de teste → 2. rodar
→ **Expected**: `$T/novo/y.txt` renderizado; `git diff configurar.sh` vazio.

## Cenário 8: contenção de caminho (FR-015, SC-007)

1. `$T/.cockpit` como link simbólico para diretório fora de `$T` → 2. rodar
→ **Expected**: exit 1; nada escrito fora de `$T`.
3. `--projeto` apontando para diretório que não é git, ou subdiretório de um repo
→ **Expected**: exit 1, mensagem clara.

## Cenário 9: validação de respostas (US1, FR-004/FR-016)

1. Respostas com `REPO_REMOTO=semBarra` → **Expected**: exit 1 citando `REPO_REMOTO`; nada gravado.
2. Respostas sem `CMD_LINT` → **Expected**: exit 1 citando `CMD_LINT`.
3. `BRANCH_PRODUCAO` igual a `BRANCH_INTEGRACAO` → **Expected**: exit 0, sem aviso.
4. `IDENTIDADES=''` → **Expected**: exit 1. E-mail não `noreply` → exit 0 com aviso.

## Cenário 10: `cstk` ausente ou abaixo do piso (US4, FR-014, SC-005)

1. `PATH` sem `cstk` → 2. rodar
→ **Expected**: exit 3; config e templates presentes; stdout com `Execute:` e o comando oficial;
nenhum processo de rede ou instalação disparado.
3. `cstk` falso respondendo versão menor que `CSTK_MIN` → **Expected**: exit 3.

## Cenário 11: qualidade estática (SC-006)

`shellcheck configurar.sh scripts/lib/versao.sh scripts/testar-configurar.sh instalar.sh`
→ 0 findings; `scripts/verificar-agnostico.sh` → 0 ocorrências.

## Roundtrip End-to-End

N/A — sem borda backend↔frontend.
