# Contrato: workflow-template `caminhos-previstos` (D3, D4, D8, FR-008 a FR-011)

> `[PROPOSTA — a validar na implementação]`: workflow novo. Endpoints e campos do GitHub citados
> aqui têm o item da [research](../research.md) que os confirma; o que está "a confirmar" é lido na
> doc oficial, via context-mode, antes de entrar no YAML (Princípio V).

> Resposta do owner ao gate de segurança do plan (block-001, dec-022): a PR de promoção não fica
> fora da trava, passa nela pelo passo 2 (A1); a config do semantic-release é governança (A2); todo
> `decisoes-do-owner.md` é governança (F1). A redação "a PR de promoção fica fora da trava" do D4
> no registro é texto do owner e esta frente não o altera; vale a resposta do block-001.

Arquivo: `templates/.github/workflows/caminhos-previstos.yml.tmpl`, renderizado em
`.github/workflows/caminhos-previstos.yml` do projeto. Ele precisa estar na branch padrão (R9).

## Gatilho e permissões

| Item | Valor | Motivo |
|---|---|---|
| evento | `pull_request_target`, tipos `opened`, `synchronize`, `reopened`, `edited` | roda o arquivo da branch padrão, nunca o do PR (R9); `edited` cobre a troca de corpo e de base |
| filtro | `branches: [{{BRANCH_INTEGRACAO}}, {{BRANCH_PRODUCAO}}]` | PR para a integração e para a produção (A1), na mesma forma de lista do `ci.yml.tmpl`. Com integração = produção os dois nomes coincidem e só há o caminho da integração; o `testar-configurar.sh` confere que essa renderização passa no actionlint |
| permissões | `contents: read`, `pull-requests: read`, `statuses: write` | ler base e PR, publicar o status (R13); nada além |
| checkout | nenhum | nenhum byte do PR é executado |
| runner | `ubuntu-latest`, conferindo `gh` e `jq` antes (R11, D-P5) | |

Dados do evento (número, SHA do HEAD, refs, corpo) entram por `env:` e nunca por `${{ }}` dentro
de `run:`, no mesmo padrão do `audit-merge-vermelho`. Nome de arquivo vindo da API é dado: só passa
por `jq` e comparação de texto, nunca por `eval`, glob do shell nem regex montada a partir dele.

## Saída

Um commit status no SHA do HEAD do PR (R2), estado `success` ou `failure`, descrição com o primeiro
motivo. O contexto depende da base (D-P11): `caminhos-previstos` para a integração e
`caminhos-previstos-producao` para a produção, quando ela difere da integração. O status fica no
commit, não na PR, e o mesmo SHA pode ser HEAD de uma PR para cada base; com um contexto só, o verde
da integração valeria na produção. O job termina com sucesso depois de publicar, porque o check
automático do job fica no SHA da branch padrão, não no do PR (R2). O job só falha quando não
consegue publicar. Nesse caso o check obrigatório fica ausente e o merge não acontece.

## Algoritmo

1. **Modo**: lê `docs/constitution.md` na branch de integração pela API de conteúdo (campos a
   confirmar), também quando a base é a produção, porque a integração é a fonte da verdade do D1.
   Tira o `\r` antes, como o configurador (constituição commitada com CRLF; rodada 3 do
   `bmad-code-review`, B3-1), e o mesmo vale no `audit-merge-vermelho`, no
   `require-codeowner-approval` e no `promotion-pr`. Aplica a regra "1 e 1" da linha `Merge autônomo:` (contrato
   [modo-autonomo.md](modo-autonomo.md) §1). Se der `desligado`, publica `success` "modo
   desligado" e termina (D-P3).
2. **Base e HEAD** (A1): `GET pulls/{n}` dá o SHA do HEAD, a base e a cabeça da PR (fontes na
   [research](../research.md), R18). Se o SHA do HEAD ≠ SHA do evento: `failure` "HEAD mudou" (a
   lista seria de outro commit; o `synchronize` do HEAD novo roda de novo). Repositório da cabeça
   (`head.repo.full_name`) diferente do repositório da base, ou nulo: **PR de outro repositório**
   (fork), qualquer que seja a base (decisão do owner na rodada 1 do `bmad-code-review`). O motivo
   "PR de outro repositório" fica guardado para o passo 7 e a PR segue nos passos seguintes (ver
   "Ordem" abaixo). Base = produção, diferente da integração:
   - cabeça = `{{BRANCH_INTEGRACAO}}` (e repositório da cabeça = repositório da base): **PR de
     promoção**, `success` "PR de promoção" e termina (D8, promoção autônoma);
   - qualquer outra cabeça, ou campo ausente: vai direto ao passo 7 (sem lista de arquivos), com o
     motivo já guardado ou "PR para a produção".

   Base = integração: segue no passo 3.
3. **Arquivos**: `GET pulls/{n}/files` paginado com `per_page=100`, guardando `filename`,
   `previous_filename` (quando houver) e `status` (R8). Também lê `changed_files` do `GET pulls/{n}`
   do passo 2. Se o total de linhas não vazias listadas ≠ `changed_files`: `failure` "lista
   incompleta". Antes dessa contagem, `failure` "lista inválida" para: nome, nome anterior ou
   `status` com caractere de controle (0x00 a 0x1f, inclusive o separador 0x1f e a quebra de linha,
   marcados já no `jq`), linha com campo a mais, nome vazio ou `status` fora de `added`, `removed`,
   `modified`, `renamed`, `copied`, `changed`, `unchanged`. A quebra de linha num nome partiria a
   entrada em duas linhas válidas, e no teto de 3000 arquivos a contagem poderia fechar com isso.
   **Corrida de HEAD**: depois de listar, relê o SHA do HEAD em `GET pulls/{n}`; se
   deixou de ser o SHA do evento, publica `failure` "HEAD mudou" no SHA do evento e termina. A
   lista pode ser do commit novo, então nenhum veredito sai dela; o status vermelho fica num commit
   que já não é HEAD (inofensivo), e o push novo dispara outro run, que publica no SHA novo. Foi
   escolhido publicar, e não encerrar calado, para o run nunca terminar sem status (mesma regra do
   passo 2).
4. **Governança**: algum `filename` ou `previous_filename` casa com a lista abaixo → a PR é de
   governança; o 1º motivo "governança: <caminho>" fica guardado para o passo 7. A exceção é
   `.claude/settings.json` da raiz com acréscimo puro em `permissions.deny` (D-P10), que não conta
   como governança; `.claude/settings.json` de subpasta, renomeado (com `previous_filename`) ou que
   não é arquivo comum nunca tem a exceção (ver "Acréscimo puro" abaixo).

   **PR que só toca registros** (todo nome, atual e anterior, é `docs/specs/<x>/decisoes-do-owner.md`:
   PR de registro ou de emenda, decisão do owner na rodada 3) vai direto ao passo 7, sem os passos 5
   e 6: o bloco não é validado, para que um bloco inválido na base não trave a própria emenda. A
   aprovação do owner é o gate; depois do merge, a trava vale pela versão emendada.
5. **Tipo da PR** (D-P2; nunca pelo título nem pela branch):
   - corpo com exatamente uma linha `Origem: #<n>`: **correção ou revert**;
   - senão, `docs/specs/<x>/**` tocado para exatamente um `<x>` com
     `docs/specs/<x>/decisoes-do-owner.md` na base: **frente**;
   - dois ou mais `<x>` com registro: `failure` "frente ambígua";
   - nenhum: **sem registro**, e cai no passo 7.

   A existência do registro na base é lida na API de conteúdo: resposta 404 vale "sem registro";
   qualquer outro erro de leitura é `failure` "erro de leitura: registro" e nunca vira "sem
   registro". O 404 é reconhecido pelo texto `(HTTP 404)` no erro do `gh`, formato **assumido e não
   confirmado na fonte** (research R18, a provar no S3): erro sem esse texto vale erro de leitura.
   "Sem registro" guarda o motivo e vai ao passo 7.
6. **Conferência por tipo**:
   - **frente**:
     - registro lido na base (nunca no PR);
     - cada `filename` e cada `previous_filename` está no bloco "Caminhos previstos" (literal ou
       `dir/**`, data-model §Registro) ou em `docs/specs/<x>/**`;
     - `docs/specs/<x>/decisoes-do-owner.md` tocado é governança (passo 4): exige dono;
     - manifesto ou lockfile (D-P9, lista abaixo) só passa se listado literalmente e com
       dependência aprovada. **Formato fechado** da seção "Dependências novas" (rodada 3, B3-4;
       rodada 4, E4-8): ou `Nenhuma.`, ou itens de lista que começam com o pacote entre crases, um
       por linha (`` - `<pacote>` ``, com observação opcional depois de um espaço:
       `` - `lodash` (permanente) ``). O formato é o mesmo na checagem 6 da `rito-descoberta`, que
       grava a seção, e na trava. A trava só conta como dependência aprovada a linha que casa
       `` ^- `[^`[:space:]]+`( .*)?$ ``: o trecho entre crases vem logo depois do `- `, sem espaço
       dentro. Qualquer outro item ou texto vale "nenhuma": `Nenhuma.`, `- Nenhuma.`, `- Não há.`,
       `- N/A`, `- Sem dependências novas`, `- nada`, `- 0`, `- Ver seção X`, `- lodash` (sem
       crases), `` - Nenhuma (o `package.json` só muda `scripts`). `` e `` - Não há; ver `docs/x.md` ``
       (crases fora do começo), `` - `lodash`, uso permanente `` (sem espaço depois das crases),
       item com crases vazias ou só com espaço e trecho de código fora de item de lista. **Limite
       conhecido**: a trava confere que existe item aprovado, não que o pacote do manifesto é o do
       item;
     - bloco ausente, vazio ou com linha inválida: `failure`.
   - **correção ou revert**:
     - `#<n>` precisa estar mergeada na mesma base (campos `merged` e `base.ref`, R18) e ser PR de
       frente, pela regra do passo 5 aplicada aos arquivos dela;
     - cada `filename` e `previous_filename` da PR atual está entre os nomes, atuais e anteriores,
       de `#<n>`;
     - cada um também está no bloco "Caminhos previstos" do registro da frente de `#<n>`, lido na
       base (literal, `dir/**` ou `docs/specs/<x>/**`), como na frente; fora dele, `failure` "fora
       do bloco" (rodada 3, E3-4: a origem pode ter sido mergeada no modo desligado, sem trava,
       tocando fora do bloco). Bloco ausente, vazio ou inválido também falha;
     - qualquer outra situação: `failure`;
     - passadas as conferências acima, manifesto ou lockfile (D-P9) na PR atual cai no passo 7 com
       o motivo "manifesto em correção" (a correção não tem registro próprio que aprove
       dependência); no bloco, ele só precisa caber, sem a regra de dependência aprovada.
7. **Aprovação**: roda no fim, só quando nenhuma conferência dos passos 2 a 6 falhou direto, com o
   1º motivo guardado. Passa só com review `APPROVED` de um dono do `CODEOWNERS` da base, no commit
   atual (HEAD). A leitura é a mesma do `require-codeowner-approval`, com os campos já citados na frente
   `codeowner-aprovacao-atual`. Sem aprovação: `failure` "aguarda aprovação de dono (<motivo>)". O
   owner aprova no commit atual e reexecuta o run ("Re-run", R10). Nunca por
   `pull_request_review`, que roda o arquivo do PR. Caem aqui, e só aqui:
   - PR sem registro;
   - caminho de governança (passo 4, inclusive a chave `release` de `package.json`);
   - PR de outro repositório (fork, passo 2);
   - PR para a produção que não é a de promoção (passo 2);
   - correção ou revert com manifesto ou lockfile (passo 6);
   - PR que só toca registros (passo 4), sem validar o bloco.
8. Nenhum motivo: `success` "conforme registro de `<x>`" (frente) ou "correção de #`<n>`".

**Ordem** (rodada 2 do `bmad-code-review`, E2-2): os motivos de dono (fork, governança, sem
registro, manifesto em correção) só são guardados; o primeiro vira o motivo do passo 7. Todas as
conferências que falham direto rodam antes, e a aprovação de dono nunca libera uma delas: PR de
governança com arquivo fora do bloco, ou correção com origem não mergeada, falha mesmo aprovada.
Por isso o caminho de governança que a frente toca precisa estar no bloco (ou em
`docs/specs/<x>/**`): ele exige dono além disso, e a aprovação não libera o arquivo fora do bloco.
A única PR de governança que não passa pelo bloco é a que só toca registros (passo 4).

**Limites conhecidos** (rodada 3, B3-5 e E3-9; a saída é dividir a PR):

- PR de governança que também toca duas frentes falha direto em "frente ambígua", mesmo aprovada;
- PR que só muda a chave `release` de um `package.json` falha direto em "manifesto sem dependência
  aprovada" quando a frente não tem dependência aprovada ou o `package.json` não está literal no
  bloco, mesmo aprovada;
- PR que mistura o registro de outra frente com outros arquivos (o registro novo de `x` junto de
  `docs/specs/f/spec.md`) não tem a saída da PR só de registros: o registro de `x` fica fora do
  bloco de `f` e falha direto. O registro da própria frente cabe em `docs/specs/<f>/**` e só exige
  dono. A `rito-descoberta` põe o registro em PR própria.

**Falham direto** (`failure` que aprovação de dono não muda; corrige-se a PR ou o registro): erro
de leitura na API em qualquer passo (falha fechada), "HEAD mudou", "lista incompleta", "lista
inválida" (inclusive nome com caractere de controle), "frente ambígua", bloco "Caminhos previstos"
ausente, vazio ou com linha inválida, "fora do bloco" (na correção, o bloco da frente da origem), "manifesto sem dependência aprovada", correção com origem não mergeada na mesma
base, origem que não é PR de frente ou arquivo fora da PR de origem, e "CODEOWNERS sem dono na
linha `*`". O cabeçalho do workflow repete as duas listas.

## Caminhos de governança (D4, block-001)

| Padrão | Casa |
|---|---|
| `docs/constitution.md` | literal |
| `cockpit.config` | literal |
| `.github`, `.github/**` | a entrada da raiz em si (arquivo, link ou submódulo) e o prefixo |
| `CODEOWNERS`, `docs/CODEOWNERS` | literal (o de `.github/` já cai no prefixo) |
| `.claude` em qualquer pasta | qualquer componente `.claude` do caminho, também como último (a entrada em si: arquivo, link ou submódulo `.claude`, `src/.claude`), sem distinção de maiúsculas (`(^\|/)\.claude(/\|$)` sobre o caminho em minúsculas: `.claude/**`, `src/.CLAUDE/**`, `docs/specs/f/.claude/**`). Exceção só para `.claude/settings.json` da raiz, grafado assim, com acréscimo puro em `permissions.deny` (D-P10) |
| `CLAUDE.md`, `CLAUDE.local.md` | nome de base, em qualquer pasta e sem distinção de maiúsculas (`claude.md`, `src/Claude.Local.MD`): o Claude Code carrega os de subpasta sob demanda (<https://code.claude.com/docs/en/memory>; decisão do owner na rodada 1 do `bmad-code-review`). `CLAUDE.md.semente.tmpl` e afins não casam |
| `.mcp.json`, `.npmrc`, `.yarnrc.yml` | literal |
| `.husky`, `.husky/**` | a entrada da raiz em si e o prefixo |
| commitlint | nome de base `commitlint.config.*` ou `.commitlintrc*`, em qualquer pasta |
| semantic-release | nome de base `.releaserc*` ou `release.config.*`, em qualquer pasta (A2): a config vem do repositório e roda com o `TOKEN_AUTOMACAO` (R17) |
| chave `release` de `package.json` | qualquer pasta (A2): `jq -c '.release // null'` no blob da base (pelo `previous_filename`, quando houver) e no do HEAD, lidos pela API de conteúdo como no D-P10; arquivo ausente vale `null`; valores diferentes: governança |
| `docs/specs/<qualquer>/decisoes-do-owner.md` | exatamente 4 segmentos; registro de qualquer frente, criado, alterado, apagado ou renomeado (D3: só o owner mergeia registro; F1, ratificado no block-001). Sem isto, uma frente cujo bloco liste `docs/**` criaria o registro de outra frente e o mergearia sozinha |

## Manifestos e lockfiles (D-P9)

Pelo nome de base, em qualquer pasta: `package.json`, `package-lock.json`, `npm-shrinkwrap.json`,
`yarn.lock`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `bun.lock`, `bun.lockb`, `deno.lock`,
`requirements*.txt`, `pyproject.toml`, `poetry.lock`, `uv.lock`, `Pipfile`, `Pipfile.lock`,
`go.mod`, `go.sum`, `Cargo.toml`, `Cargo.lock`, `Gemfile`, `Gemfile.lock`, `composer.json`,
`composer.lock`. `pnpm-workspace.yaml`, `bun.lock`, `bun.lockb`, `deno.lock` e `uv.lock` entraram na
rodada 2 do `bmad-code-review` (B2-11).

## Acréscimo puro em `permissions.deny` (D-P10, CHK014)

Definição objetiva (igual à da spec, FR-009): fora de `.permissions.deny` os JSON da base e do HEAD
são iguais; todo item do deny da base continua no do HEAD; sem o arquivo na base, o do HEAD é
exatamente `{"permissions":{"deny":[...]}}`; `settings.local.json` nunca passa. Remover ou alterar
regra, ou mudar qualquer outra chave, reprova (casos negativos testados na Fase 4, tarefa 4.1.6).
Reordenar chaves não muda o efeito e passa: o `jq` compara objetos sem olhar a ordem das chaves
(decisão do owner na rodada 1 do `bmad-code-review`; caso "CHK014 sem mudança de conteúdo" do
`testar-configurar.sh`). Só vale para `.claude/settings.json` da raiz, sem `previous_filename`
(renomear para ele nunca passa, E3-12).

**Arquivo comum, nunca link** (rodada 3, E3-11): antes de ler o conteúdo, a trava lê o objeto da
API de conteúdo (sem o `Accept` raw) no HEAD e, quando o arquivo existe na base, também na base, e
exige `type` = `file` e `path` = `.claude/settings.json`; qualquer outra resposta, ou erro, conta
como governança (dono). Fonte (<https://docs.github.com/en/rest/repos/contents>): o campo `type`
vale `file`, `dir`, `symlink` ou `submodule`; "If the content is a symlink and the symlink's target
is a normal file in the repository, then the API responds with the content of the file. Otherwise,
the API responds with an object describing the symlink itself." O link para fora do repositório,
para pasta ou quebrado dá `type` `symlink`, coberto pela fonte. O link para arquivo do repositório
responde com o objeto do alvo, e que o `path` dessa resposta seja o do alvo **não está confirmado na
fonte**: é pendência do S3 (quickstart, Scenario 9). Sem a conferência, o link para um arquivo do
bloco passaria com conteúdo de acréscimo puro, e a frente mudaria depois o alvo, fora da
governança.

## Casos negativos (S3, SC-002)

| Caso | Passo que reprova |
|---|---|
| arquivo fora da lista | 6 |
| `docs/constitution.md` | 4 → 7 |
| job homônimo `caminhos-previstos` noutro workflow | 4 → 7 (`.github/**`); a identidade sem Workflows nem chega a enviar o push (R4, a provar) |
| renomeação a partir de `.github/**` | 4, pelo `previous_filename` |
| `.claude/settings.json` com hook | 4 → 7 (não é acréscimo puro) |
| status forjado com a credencial do agente | recusado por permissão (R13); fonte esperada (R2) |
| PR que se declara de outra frente | 5/6: a frente sai dos arquivos e do registro, não do texto |
| PR sem registro sem aprovação | 7 |
| frente com `docs/**` no bloco cria `docs/specs/<outra>/decisoes-do-owner.md` | 4 → 7 |
| HEAD do PR diferente do SHA do evento | 2 |
| lista truncada (acima de 3000 arquivos) | 3 |
| PR de outra branch, ou de fork com branch homônima da integração, direto para a produção | 2 → 7 |
| PR de fork (ou cabeça sem repositório) para a integração | 2 → 7 |
| push durante a trava: HEAD muda depois de listar | 3 ("HEAD mudou") |
| lista vazia com `changed_files` = 1; nome com 0x1f; `status` desconhecido | 3 |
| nome ou nome anterior com caractere de controle (quebra de linha que forja duas linhas válidas, TAB) | 3 ("lista inválida", antes da contagem) |
| governança, fork ou manifesto em correção junto de falha direta (arquivo fora do bloco, manifesto sem dependência, origem não mergeada), com aprovação de dono no HEAD | a falha direta (6 ou 5): a aprovação não a libera |
| item "Dependências novas" que é variação de "nenhuma" (`- Nenhuma.`, `- (nenhuma)`) e manifesto no diff | 6 |
| entrada `.claude`, `.github` ou `.husky` em si; `claude.md` ou `.CLAUDE/` em qualquer pasta | 4 → 7 |
| correção cuja origem toca duas frentes, com erro (não 404) ao ler um dos registros | 5 ("erro de leitura: registro da origem") |
| registro ilegível por erro que não é 404 | 5 ("erro de leitura") |
| "Dependências novas" sem linha `- <dep>` e manifesto no diff | 6 |
| correção com manifesto ou lockfile | 6 → 7 |
| `CLAUDE.md`, `CLAUDE.local.md` ou `.claude/` em subpasta | 4 → 7 |
| mesmo SHA como HEAD de PR verde para a integração e de PR para a produção | contextos separados: o verde da integração não conta na produção (D-P11) |
| `.releaserc*`, `release.config.*` ou chave `release` de `package.json` alterados | 4 → 7 |
| constituição commitada com CRLF e `ligado` | 1 lê `ligado` (o `\r` sai antes); a trava confere |
| "Dependências novas" com item que não começa pelo pacote entre crases (`- Não há.`, `- N/A`, `- lodash`, `` - Nenhuma (o `package.json` só muda `scripts`). ``, `` - Não há; ver `docs/x.md` ``) e manifesto no diff | 6 |
| correção cuja origem (mergeada no modo desligado) tocou arquivo fora do bloco da frente | 6 ("fora do bloco") |
| PR só do registro com bloco inválido na base, sem aprovação | 4 → 7 (com aprovação de dono no HEAD, passa) |
| `.claude/settings.json` que é link (no HEAD ou na base), mesmo com acréscimo puro | 4 → 7 |
| renomeação para `.claude/settings.json`, mesmo com acréscimo puro | 4 → 7 |
