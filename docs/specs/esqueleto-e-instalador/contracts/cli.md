# Contracts: CLI do esqueleto do cockpit

Contratos de interface dos dois scripts entregues por esta frente.

> **[PROPOSTA — a validar na implementação]** Os dois comandos abaixo **não
> existem ainda**: esta frente os cria. Flags, códigos de saída e formato de saída
> são portanto projetados aqui, não documentação de comportamento observado.
> Distinguir isso importa (Princípio V): o que está afirmado como **real** neste
> documento são apenas os comandos de ferramenta externa invocados, cada um com
> fonte registrada em [research.md](../research.md).

---

## `instalar.sh` — preparo de máquina

**Invocação**: `./instalar.sh`
**Escopo de escrita**: exclusivamente `~/.claude/skills/` — as skills do próprio
cockpit (Princípio VII, FR-011). Desde a emenda 1.1.0 nada de terceiro é instalado
nem atualizado pelo script. Nunca recebe nem deriva caminho de projeto-alvo.
**Idempotência**: exigida (FR-010) — segunda execução consecutiva produz o mesmo
estado final e o mesmo relatório de sucesso.

### Flags

| Flag | Obrigatória | Descrição |
|------|-------------|-----------|
| *(nenhuma)* | — | O comando não recebe parâmetro. Preparar a máquina não tem variante: o que varia entre projetos é assunto do `configurar.sh`, de outra frente. |

### Saída — relatório final (FR-009)

Uma linha por etapa **avaliada**, em pt-BR, com status individual; lacuna vem com
o comando oficial impresso (`Execute: ...`) para a pessoa rodar. Execução
sequencial por gates: parada numa etapa bloqueante encerra o relatório nela.
Forma proposta (máquina com release mais nova e `ponytail` ausente):

```
Relatório de preparo da máquina:
  [ok]      Pré-requisitos de máquina
  [ok]      cstk presente
  [ok]      cstk responde à checagem de versão
  [aviso]   Versão do cstk >= CSTK_MIN (<instalada> >= <piso>) — release mais nova disponível: <latest>
            Execute: cstk self-update
  [ok]      Catálogo de skills do toolkit
  [pulada]  Skills do cockpit — diretório skills/ ainda não existe
  [ok]      Plugin context-mode (<versão>)
  [falhou]  Plugin ponytail — não bloqueante
            Execute: claude plugin install ponytail@<marketplace> -s user
```

Parada por gate (`cstk` ausente) — as etapas seguintes não aparecem:

```
Relatório de preparo da máquina:
  [ok]      Pré-requisitos de máquina
  [falhou]  cstk presente — cstk não encontrado no PATH
            Execute: curl -fsSL https://github.com/JotJunior/cstk/releases/latest/download/install.sh -o "$HOME/cstk-install.sh"
            Execute (depois de inspecionar): sh "$HOME/cstk-install.sh"
```

### Códigos de saída

| Código | Significado |
|--------|-------------|
| `0` | Nenhum item **bloqueante** falhou. Itens `aviso` e `[falhou]` não-bloqueantes (plugin recomendado) podem aparecer (FR-008). |
| `1` | Um item bloqueante falhou (`cstk` ausente, sem resposta de versão, abaixo de `CSTK_MIN`, catálogo ausente, falha na cópia de skills do cockpit, `context-mode` ausente/desabilitado). O pipeline para nele e o relatório o identifica, com o comando a executar. |
| `2` | Pré-requisitos de máquina ausentes ou abaixo do mínimo. Encerra na etapa 1, listando **todos** os faltantes de uma vez (Edge Case da spec). Também `HOME` indefinido, execução como root/sudo e raiz do script não resolvível: recusadas antes de qualquer etapa, com mensagem própria e sem relatório (review rodadas 1 e 4). |
| `3` | Permissão de escrita insuficiente em `~/.claude/skills/`, detectada por pré-checagem na etapa 1, antes de qualquer escrita (Edge Case da spec, Acceptance Scenario 8). |

> Separar `2` de `1` e `3` de ambos é deliberado: "sua máquina não tem as ferramentas de
> base", "sua máquina não deixa escrever onde o comando precisa" e "falta um
> pré-requisito do ciclo — execute este comando" são diagnósticos diferentes (SC-005).

### Comandos externos invocados — todos somente leitura

Emenda 1.1.0 (Princípio IV): o `instalar.sh` **não executa** bootstrap,
`cstk self-update`, `cstk install`, `cstk update`, `claude plugin install`,
`claude plugin update`, `claude plugin enable` nem `claude plugin marketplace add`.
Fonte de cada sinal em research Decision 16.

| Verificação | Comando executado | Fonte |
|-------------|-------------------|-------|
| `cstk` presente | `command -v cstk` | builtin POSIX |
| Versão | `cstk --version` | MEDIDO — devolve `cstk v10.8.0` |
| Release mais nova | `cstk self-update --check` — rc `0` em dia, `10` há mais nova, `1` erro; imprime `latest:X current:Y` | MEDIDO — `--help` e execução (rc `10`) |
| Catálogo ausente | existência de `~/.claude/skills/.cstk-manifest` | MEDIDO |
| Skill faltando | `cstk install --dry-run --yes </dev/null`, linhas `[dry-run] install: <nome>` em **stderr**; só nome casando `^[A-Za-z0-9][A-Za-z0-9._@-]*$` entra no comando impresso (um token com hífen viraria flag na mão de quem copia) | MEDIDO (review rodadas 3-4) |
| Catálogo defasado | `cstk update --dry-run --yes </dev/null`, resumo `updated: N` e `commands:`/`agents:` com `updated=N` | MEDIDO — `--help` (*"Mostra plano sem escrever"*) e execução |
| Marketplace registrado | `claude plugin marketplace list --json`, campo `.name` | MEDIDO |
| Plugin presente/habilitado | `claude plugin list --json`, campos `.id`, `.scope` (`user`) e `.enabled` | MEDIDO |

### Comandos impressos para a pessoa executar

| Lacuna | Linha(s) `Execute:` |
|--------|---------------------|
| `cstk` ausente | dois passos com a URL do instalador oficial (research Decision 1/16): `curl -fsSL https://github.com/JotJunior/cstk/releases/latest/download/install.sh -o "$HOME/cstk-install.sh"` e, depois de inspecionar, `sh "$HOME/cstk-install.sh"`. A forma canalizada direto para o shell não é impressa (A08) |
| Abaixo do piso ou release mais nova | `cstk self-update` |
| Catálogo ausente | `cstk install` |
| Skill faltando | `cstk install <nome>...` |
| Catálogo defasado | `cstk update` |
| Marketplace ausente | `claude plugin marketplace add <fonte>` |
| Plugin ausente | `claude plugin install <plugin>@<marketplace> -s user` — **sem** `-y`/`--accept-command` |
| Plugin desabilitado | `claude plugin enable <plugin> -s user` (MEDIDO: `enable --help`) |

**Fora do contrato desta frente**: `cstk hooks install --project-path`. Ele
provisiona hooks **dentro de um projeto-alvo**, o que o Princípio VII proíbe ao
`instalar.sh` — pertence ao `configurar.sh`, de outra frente (a emenda 1.1.0
permite ao configurador executar ferramenta já instalada pela pessoa).

---

## `scripts/verificar-agnostico.sh` — verificação de agnosticismo

**Invocação**: `./scripts/verificar-agnostico.sh`
**Efeito colateral**: nenhum sobre o repositório — só leitura (FR-016). Cria e
remove arquivos temporários próprios sob `$TMPDIR` (removidos por `trap … EXIT`).
Idempotente por construção.
**Entrada de dados**: `scripts/agnostico.lista` (versionada, pode ficar vazia)
**unida** a `AGNOSTICO_TERMOS` (variável de ambiente, fora do repositório) — mesmo
formato, em [data-model.md](../data-model.md) (FR-022, research Decision 17).
`AGNOSTICO_EXIGIR_TERMOS=1` liga a guarda anti-vacuidade (exportada pelo job de CI).

### Flags

| Flag | Obrigatória | Descrição |
|------|-------------|-----------|
| *(nenhuma)* | — | Varre o repositório inteiro contra o conjunto unido de termos. Sem modo parcial: a garantia do Princípio I é sobre "todo arquivo do repositório", e um modo parcial seria um caminho para contorná-la. |

### Saída

Sucesso (zero ocorrências — FR-013):

```
Agnosticismo: OK — nenhuma ocorrência de termo proibido.
```

Falha (FR-014) — uma linha por ocorrência, com arquivo e linha exatos; ocorrência
no **caminho** do arquivo sai com linha `0`:

```
Agnosticismo: FALHOU — 3 ocorrência(s) de termo proibido:
  docs/exemplo.md:42:<trecho da linha>
  README.md:7:<trecho da linha>
  docs/<termo>-contrato.md:0:(caminho)
  docs/link:0:(alvo do symlink)
```

### Códigos de saída

| Código | Significado |
|--------|-------------|
| `0` | Zero ocorrências (FR-013). Inclui o conjunto de termos vazio **quando `AGNOSTICO_EXIGIR_TERMOS` não é `1`** (máquina local). |
| `1` | Uma ou mais ocorrências; todas listadas com arquivo e linha (FR-014); ocorrência no caminho sai como `arquivo:0:(caminho)`. |
| `2` | Erro de uso — conjunto de termos vazio com `AGNOSTICO_EXIGIR_TERMOS=1` (mensagem diz que nenhuma das duas fontes tem termo, **sem** imprimir termos); raiz do script não resolvível, `scripts/agnostico.lista` ausente ou ilegível, execução fora de um repositório git (a enumeração depende de `git ls-files`), `git ls-files` falhando ou sem listar o próprio script (cópia sem `.git` dentro de outro repositório), arquivo versionado ilegível, ou falha ao criar arquivo temporário. Erro de leitura nunca é engolido como "OK". |

### Regras de varredura

| Regra | Razão |
|-------|-------|
| Enumera por `git ls-files` | exclui `.git/` e o que o `.gitignore` já ignora, sem lista de exclusão manual (research Decision 6) |
| **Exclui `scripts/agnostico.lista`** | a lista contém todos os termos; sem isso casaria contra si mesma e falharia sempre (research Decision 7) |
| Casamento literal, case-insensitive (`grep -i -F`); termos passam por trim e remoção de CR antes | termos são nomes próprios, não padrões (research Decision 8); lista salva com CRLF ou espaço final não pode silenciar um termo (review rodada 1) |
| Varre também o **caminho** de cada arquivo versionado | o caminho vai para o remoto tanto quanto o conteúdo (review rodada 1, decisão do owner); ocorrência sai como `arquivo:0:(caminho)` |
| Symlink: casa o **alvo textual**, sem seguir o link | é o alvo que o git versiona; seguir o link varreria arquivo fora do repositório. Ocorrência sai como `arquivo:0:(alvo do symlink)` (review rodadas 2-3) |
| Arquivo no índice mas ausente do disco (sparse checkout, `skip-worktree`): varre o blob do índice | o que vai ao remoto é o blob, não o worktree (review rodada 3) |
| Não abre exceção para contexto educativo | decidido nos Edge Cases da spec — qualquer ocorrência é reportada |
| Trata todo arquivo como texto (`grep -a`), prefixo por `grep -H` | o resultado não pode depender do locale do runner: sem `-a`, um `.md` em Latin-1 era classificado como binário em `C.UTF-8` e a ocorrência sumia em silêncio; `-H` evita interpolar o nome do arquivo num programa `sed` (nome com `\|`, `&`, `\` ou newline quebrava e o achado era descartado). Colisão em binário de verdade é reportada como qualquer outra (review rodada 1) |

---

## Workflow de CI (`.github/workflows/ci.yml`)

**Gatilho**: `pull_request` e `push` para `main`. **Nunca `pull_request_target`** —
ver §Superfície de Segurança do [plan.md](../plan.md).

**Permissões**: `permissions: contents: read` declarado no nível do workflow
(menor privilégio — CICD-SEC-2). Actions de terceiro fixadas por SHA de commit,
não por tag móvel.

| Job | Comando | Barra a mudança quando | FR |
|-----|---------|------------------------|-----|
| `shellcheck` | instala `shellcheck` e roda sobre todo `.sh` do repositório | há problema de portabilidade de shell | FR-017 |
| `agnostico` | `./scripts/verificar-agnostico.sh` com `env:` `AGNOSTICO_TERMOS` (da variável de Actions) e `AGNOSTICO_EXIGIR_TERMOS: "1"`; nunca `echo` da variável | há termo proibido, **ou** as duas fontes de termos estão vazias | FR-018, FR-022 |
| `segredos` | instala o binário do `gitleaks` e roda dois passos: `gitleaks dir . --redact -v` (árvore) e, no `pull_request`, `gitleaks git . --redact -v --log-opts="origin/<base>..HEAD"` (histórico da PR) | há segredo em arquivo versionado, **ou** em qualquer commit do range da PR | FR-019, FR-020, FR-021 |

Jobs independentes, para que a falha identifique **qual** garantia barrou (User
Story 3, cenários 1 a 3).

O `shellcheck` é instalado explicitamente pelo job, não assumido pré-instalado na
imagem do runner: afirmar o conteúdo da imagem sem fonte oficial lida violaria o
Princípio V (research Decision 9). O `gitleaks` segue o mesmo padrão.

### Job `segredos` — varredura de segredo (FR-019, FR-020, FR-021)

**Instalação no job**: tarball da release fixada por versão
(`gitleaks_<versao>_linux_x64.tar.gz` — o padrão é `linux_x64`, **não**
`linux_amd64`), conferido contra um **sha256 literal fixado no workflow**, copiado
do `gitleaks_<versao>_checksums.txt` da release no momento do bump (review rodada
1, decisão do owner: o `checksums.txt` lido na hora vem da mesma origem mutável que
o tarball e só cobriria corrupção de download, não troca de asset). Download e
extração acontecem em `$RUNNER_TEMP`, fora do diretório varrido. Nunca a Action de
terceiro: ela exige `GITLEAKS_LICENSE` em repositório de organização e não é mais
MIT (research Decision 15). A versão fixada mora no workflow, não em `versoes.env`
— não é piso de pré-requisito e o instalador não a lê (research Decision 15).

**Invocação**: dois passos, ambos com `--redact -v`:

| Passo | Comando | Quando |
|-------|---------|--------|
| árvore | `gitleaks dir . --redact -v` | sempre |
| histórico da PR | `gitleaks git . --redact -v --log-opts="origin/<base>..HEAD"` | só `pull_request` |

O checkout do job usa `fetch-depth: 0` — o raso (default `1`) não teria os
patches do range (input documentado no README de `actions/checkout`).

| Elemento | Valor | Razão |
|----------|-------|-------|
| Subcomando `dir` | varre a árvore de arquivos | mesmo recorte de `verificar-agnostico.sh` (research Decision 15) |
| Subcomando `git` com `--log-opts="origin/<base>..HEAD"` | varre os patches só do range da PR | a árvore final não basta: segredo que entra num commit e sai no seguinte passa no `dir` e entra no histórico de `main` após o merge (reproduzido, review rodada 3). O range dispensa o *baseline* que tornaria inviável varrer o histórico inteiro |
| `--redact` | **obrigatória** | o console imprime o campo `Secret:` com o valor achado; FR-019 exige arquivo e linha sem reproduzir o valor |
| `-v` | **obrigatória** | sem ela o console só diz `leaks found: N`, sem `File:`/`Line:`, e a PR barrada não aponta onde está o segredo; com `--redact`, `Secret:` sai como `REDACTED` (medido com 8.30.1, review rodada 1) |
| *(sem `-c`)* | `.gitleaks.toml` da raiz é lido por default | exceção precisa estar versionada e visível na PR (FR-021). **O arquivo precisa do bloco `[extend] useDefault = true`**: um `.gitleaks.toml` na raiz *substitui* a configuração embutida (README oficial), e sem o bloco o job rodaria com zero regras (review rodada 1, crítico) |
| *(sem `-i`)* | `.gitleaksignore` da raiz é lido por default (`--gitleaks-ignore-path` já é `.`) | idem |

**Entrada de dados versionada** (FR-021):

| Arquivo | Conteúdo | Uso |
|---------|----------|-----|
| `.gitleaksignore` | um comentário `# motivo:` e o *fingerprint*: `<file>:<ruleID>:<line>` (três campos, impresso pelo passo da árvore, e conferido também no passo de histórico) ou `<commit>:<file>:<ruleID>:<line>` (quatro campos, impresso pelo passo de histórico) — ver o cabeçalho do próprio arquivo | ignorar um achado pontual já revisado |
| `.gitleaks.toml` | `[extend] useDefault = true` obrigatório, mais blocos `[[allowlists]]` / `[[rules.allowlists]]` com `paths`, `regexes`, `stopwords` | ignorar uma **classe** de placeholder (ex.: chaves de exemplo de template) |

Nenhum dos dois é editável fora do repositório — toda exceção entra por PR e é
revisada no diff.

### Códigos de saída — job `segredos`

| Código | Significado |
|--------|-------------|
| `0` | Nenhum achado. Job verde. |
| `1` | Um ou mais achados, **ou** erro de execução. Barra a mudança (FR-019). |
| `126` | Flag desconhecida — erro de uso do próprio workflow. |
