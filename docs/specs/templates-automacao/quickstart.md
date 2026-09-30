# Quickstart: templates-automacao

Cenários do teste (`scripts/testar-configurar.sh`) e da validação manual.

## Cenário 1 — render completo (FR-019, SC-001, SC-002)

1. Repositório git temporário com `cockpit.config.example` como respostas.
2. `./configurar.sh --respostas cockpit.config.example`.
3. **Expected**: os 9 arquivos existem; 0 `{{CHAVE}}`; `actionlint` sem finding nos 6
   fluxos; `.releaserc.json` passa em `python3 -m json.tool` com `branches` = `["main"]`;
   `shellcheck` sem finding e bit de execução no `task.sh`; cada `${{ … }}` do template
   aparece idêntico na saída.

## Cenário 2 — segunda execução (SC-004)

1. Após o cenário 1, `./configurar.sh --atualizar`.
2. **Expected**: nenhum arquivo muda (hash e modo iguais).

## Cenário 3 — integração = produção (SC-005)

1. Config com `BRANCH_INTEGRACAO='main'` e `BRANCH_PRODUCAO='main'`.
2. **Expected**: fluxos válidos no `actionlint`; o passo do `promotion-pr`, rodado com as
   duas variáveis iguais, sai 0 sem chamar `gh`.

## Cenário 4 — caracteres especiais (US1 cenário 2)

1. `CMD_LINT` com `|`, `&&`, `$`, aspas e crase, por exemplo:

   ```text
   npm run lint -- --fix | tee "$X" && echo `ok`
   ```

2. **Expected**: `actionlint` passa e o `run:` contém o comando byte a byte.

## Cenário 5 — `DONOS_CODEOWNERS` (FR-015)

1. Respostas com `@maria-exemplo @jose-exemplo` → `CODEOWNERS` tem `* @maria-exemplo @jose-exemplo`.
2. Respostas com `@org-exemplo/time` → configurador sai com erro citando times.
3. Config antiga sem a chave em `--atualizar` não interativo → erro de chave faltante.

## Cenário 6 — `BOARD` (FR-013, FR-015)

1. `BOARD='org-exemplo/7'` aceito; `BOARD='x y'` e `BOARD='org/0'` recusados.
2. Com `BOARD=''`, `task.sh list` sai 3 com a mensagem de sem board.
3. Com `BOARD='org-exemplo/7'` e `PATH` sem `gh`, `task.sh discover` sai 4.

## Validação manual no projeto-alvo (fora do teste; exige GitHub real)

- Definir o segredo `TOKEN_AUTOMACAO` **ou** ligar "Allow GitHub Actions to create and
  approve pull requests" (Settings → Actions → General) para o `promotion-pr` (F5); sem
  `TOKEN_AUTOMACAO`, os checks do PR de promoção aguardam "Approve workflows to run" (F2).
- **Obrigatório** (dec-025): na proteção das branches de integração e produção, exigir
  aprovações de PR e ligar "Require review from Code Owners" (F8). É esta regra que garante
  a aprovação de dono; o check `aprovacao-de-dono` é forjável por conteúdo do PR (F14) e
  serve só de visibilidade.
- Cada dono de `DONOS_CODEOWNERS` precisa de permissão de escrita no repositório (F8). Dono
  sem ela passa no check `aprovacao-de-dono`, mas a regra nativa não conta a aprovação dele:
  o PR fica sem aprovação válida até um dono com escrita aprovar.
- Tornar `ci`, `commitlint` e `aprovacao-de-dono` checks obrigatórios na proteção da branch.
- `gh auth refresh -s project` antes de usar `task.sh` (F12).
- Abrir PR sem aprovação → `aprovacao-de-dono` vermelho listando donos; aprovar como dono →
  verde.
