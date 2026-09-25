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
**Escopo de escrita**: exclusivamente `~/.claude/` e `~/.local/` (Princípio VII,
FR-011). Nunca recebe nem deriva caminho de projeto-alvo.
**Idempotência**: exigida (FR-010) — segunda execução consecutiva produz o mesmo
estado final e o mesmo relatório de sucesso.

### Flags

| Flag | Obrigatória | Descrição |
|------|-------------|-----------|
| *(nenhuma)* | — | O comando não recebe parâmetro. Preparar a máquina não tem variante: o que varia entre projetos é assunto do `configurar.sh`, de outra frente. |

### Saída — relatório final (FR-009)

Uma linha por etapa, em pt-BR, com status individual. Forma proposta:

```
Relatório de preparo da máquina:
  [ok]      Pré-requisitos de máquina
  [ok]      cstk atualizado (10.8.0)
  [ok]      Versão do cstk >= CSTK_MIN (10.8.0)
  [ok]      Catálogo de skills do toolkit
  [pulada]  Skills do cockpit — diretório skills/ ainda não existe
  [ok]      Plugin context-mode
  [falhou]  Plugin ponytail — não bloqueante
```

### Códigos de saída

| Código | Significado |
|--------|-------------|
| `0` | Nenhum item **bloqueante** falhou. Itens não-bloqueantes podem ter falhado e aparecem como `[falhou]` no relatório (FR-008). |
| `1` | Ao menos um item bloqueante falhou. O relatório identifica qual. |
| `2` | Pré-requisitos de máquina ausentes ou abaixo do mínimo. Encerra antes das demais etapas, listando **todos** os faltantes de uma vez (Edge Case da spec). Também `HOME` indefinido e execução como root/sudo: recusadas antes de qualquer etapa, com mensagem própria e sem relatório (review rodada 1). |
| `3` | Permissão de escrita insuficiente em `~/.claude/` e/ou `~/.local/`, detectada por uma pré-checagem (criar e remover um arquivo temporário) dentro da etapa 1, antes de qualquer etapa escrever algo. A mensagem identifica qual área falhou. Nenhum estado parcial: a checagem roda antes de qualquer escrita real (Edge Case da spec, Acceptance Scenario 8). |

> Separar `2` de `1` e `3` de ambos é deliberado: "sua máquina não tem as ferramentas de
> base", "sua máquina não deixa escrever onde o comando precisa" e "o preparo tentou e
> falhou" são diagnósticos diferentes para o dev (SC-005) e exigem ações diferentes.

### Comandos externos invocados

Cada um com a fonte que o confirma — nenhum foi reconstruído de memória.

| Situação | Comando | Fonte |
|----------|---------|-------|
| `cstk` ausente | o instalador oficial `https://github.com/JotJunior/cstk/releases/latest/download/install.sh`, **baixado para arquivo temporário e então executado** — não canalizado direto para o shell (ver §Superfície de Segurança do plan.md). O one-liner publicado no README é `curl -fsSL <url> \| sh`; usar a mesma URL sem o pipe mantém o canal oficial e elimina a execução parcial de download truncado. | FONTE OFICIAL — README de `JotJunior/cstk` (research Decision 1) |
| `cstk` presente | `cstk self-update` | FONTE OFICIAL — README; *"updates the cstk binary itself + cli/lib"* |
| Conferir versão | `cstk --version` | MEDIDO — devolve `cstk v10.8.0` |
| Catálogo, 1ª vez | `cstk install` | FONTE OFICIAL — README; instala o perfil `sdd` em `~/.claude/skills/` |
| Catálogo, demais | `cstk update` | FONTE OFICIAL — README; *"applies new releases preserving local edits"* |
| Registrar marketplace | `claude plugin marketplace add <source>` | MEDIDO — `claude plugin marketplace add --help` |
| Instalar plugin | `claude plugin install <plugin>@<marketplace>` | MEDIDO + FONTE OFICIAL (research Decision 10) |
| Atualizar plugin | `claude plugin update <plugin>` | MEDIDO — `claude plugin update --help` |

**Ordem não-negociável**: `cstk self-update` **antes** da conferência do piso
(Princípio IV, research Decision 2).

**Fora do contrato desta frente**: `cstk hooks install --project-path`. Ele
provisiona hooks **dentro de um projeto-alvo**, o que o Princípio VII proíbe ao
`instalar.sh` — pertence ao `configurar.sh`, de outra frente.

---

## `scripts/verificar-agnostico.sh` — verificação de agnosticismo

**Invocação**: `./scripts/verificar-agnostico.sh`
**Efeito colateral**: nenhum — só leitura (FR-016). Idempotente por construção.
**Entrada de dados**: `scripts/agnostico.lista` (formato em
[data-model.md](../data-model.md)).

### Flags

| Flag | Obrigatória | Descrição |
|------|-------------|-----------|
| *(nenhuma)* | — | Varre o repositório inteiro contra a lista versionada. Sem modo parcial: a garantia do Princípio I é sobre "todo arquivo do repositório", e um modo parcial seria um caminho para contorná-la. |

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
```

### Códigos de saída

| Código | Significado |
|--------|-------------|
| `0` | Zero ocorrências (FR-013). Inclui o caso de lista vazia ou só com comentários. |
| `1` | Uma ou mais ocorrências; todas listadas com arquivo e linha (FR-014); ocorrência no caminho sai como `arquivo:0:(caminho)`. |
| `2` | Erro de uso — `scripts/agnostico.lista` ausente, execução fora de um repositório git (a enumeração depende de `git ls-files`), ou arquivo versionado ilegível (erro de leitura nunca é engolido como "OK"). |

### Regras de varredura

| Regra | Razão |
|-------|-------|
| Enumera por `git ls-files` | exclui `.git/` e o que o `.gitignore` já ignora, sem lista de exclusão manual (research Decision 6) |
| **Exclui `scripts/agnostico.lista`** | a lista contém todos os termos; sem isso casaria contra si mesma e falharia sempre (research Decision 7) |
| Casamento literal, case-insensitive (`grep -i -F`); termos passam por trim e remoção de CR antes | termos são nomes próprios, não padrões (research Decision 8); lista salva com CRLF ou espaço final não pode silenciar um termo (review rodada 1) |
| Varre também o **caminho** de cada arquivo versionado | o caminho vai para o remoto tanto quanto o conteúdo (review rodada 1, decisão do owner); ocorrência sai como `arquivo:0:(caminho)` |
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
| `agnostico` | `./scripts/verificar-agnostico.sh` | há termo proibido | FR-018 |
| `segredos` | instala o binário do `gitleaks` e roda `gitleaks dir . --redact -v` | há segredo em arquivo versionado | FR-019, FR-020, FR-021 |

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

**Invocação**: `gitleaks dir . --redact -v`

| Elemento | Valor | Razão |
|----------|-------|-------|
| Subcomando `dir` | varre a árvore de arquivos | mesmo recorte de `verificar-agnostico.sh`; `git` varreria o histórico e exigiria *baseline* (research Decision 15) |
| `--redact` | **obrigatória** | o console imprime o campo `Secret:` com o valor achado; FR-019 exige arquivo e linha sem reproduzir o valor |
| `-v` | **obrigatória** | sem ela o console só diz `leaks found: N`, sem `File:`/`Line:`, e a PR barrada não aponta onde está o segredo; com `--redact`, `Secret:` sai como `REDACTED` (medido com 8.30.1, review rodada 1) |
| *(sem `-c`)* | `.gitleaks.toml` da raiz é lido por default | exceção precisa estar versionada e visível na PR (FR-021). **O arquivo precisa do bloco `[extend] useDefault = true`**: um `.gitleaks.toml` na raiz *substitui* a configuração embutida (README oficial), e sem o bloco o job rodaria com zero regras (review rodada 1, crítico) |
| *(sem `-i`)* | `.gitleaksignore` da raiz é lido por default (`--gitleaks-ignore-path` já é `.`) | idem |

**Entrada de dados versionada** (FR-021):

| Arquivo | Conteúdo | Uso |
|---------|----------|-----|
| `.gitleaksignore` | uma linha por *fingerprint* `<file>:<ruleID>:<line>` — três campos, sem commit, no modo `dir` (medido com 8.30.1; o formato de quatro campos é do modo `git`) | ignorar um achado pontual já revisado |
| `.gitleaks.toml` | `[extend] useDefault = true` obrigatório, mais blocos `[[allowlists]]` / `[[rules.allowlists]]` com `paths`, `regexes`, `stopwords` | ignorar uma **classe** de placeholder (ex.: chaves de exemplo de template) |

Nenhum dos dois é editável fora do repositório — toda exceção entra por PR e é
revisada no diff.

### Códigos de saída — job `segredos`

| Código | Significado |
|--------|-------------|
| `0` | Nenhum achado. Job verde. |
| `1` | Um ou mais achados, **ou** erro de execução. Barra a mudança (FR-019). |
| `126` | Flag desconhecida — erro de uso do próprio workflow. |
