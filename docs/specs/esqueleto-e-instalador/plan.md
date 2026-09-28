# Implementation Plan: Esqueleto do cockpit-dev e instalador de máquina

**Feature**: `esqueleto-e-instalador` | **Date**: 2026-09-25 | **Updated**: 2026-09-28 (round r02 — alinhamento à emenda 1.1.0 da constituição) | **Spec**: [spec.md](./spec.md)

## Summary

Entregar os dois pilares do esqueleto do cockpit (itens 1 e 6 do MVP do briefing):
`instalar.sh`, que deixa uma máquina pronta para o ciclo num comando só, e
`scripts/verificar-agnostico.sh`, que transforma a promessa de agnosticismo em
verificação executável — mais o CI do próprio cockpit, que a cada alteração
proposta roda três garantias: portabilidade de shell, agnosticismo e ausência de
segredo (esta última acrescentada pela resposta do owner ao block-001).

Abordagem técnica: três arquivos de shell e um workflow, sem build, sem
dependência nova. `instalar.sh` é um pipeline linear de sete etapas **sequencial
por gates** (clarify r02): para no primeiro item bloqueante, e o relatório final
(FR-009) lista só os itens avaliados até ali. Desde a emenda 1.1.0 o instalador
**verifica e imprime, nunca instala nem atualiza código de terceiro** (Princípio
IV): `cstk`, catálogo de skills e plugins são conferidos em modo somente leitura,
e para cada lacuna o script imprime o comando oficial exato — quem executa é a
pessoa. A única escrita que resta é a cópia das skills **do próprio cockpit** para
`~/.claude/skills/` (FR-007). A varredura de agnosticismo enumera arquivos por
`git ls-files` e une duas fontes de termos — `scripts/agnostico.lista`
(versionada, pode ficar vazia) e `AGNOSTICO_TERMOS` (fora do repositório) —,
falhando no CI quando as duas estão vazias (FR-022, Princípio I).

## Technical Context

**Language/Version**: bash (Princípio VII: `set -euo pipefail`, shellcheck sem findings)
**Primary Dependencies**: nenhuma acrescentada. Pré-requisitos de máquina fechados pelo Princípio VII em `git` (>= 2.36), `gh`, `node` (>= 20), `jq`, `curl`. `cstk` e os plugins são provisionados, não empacotados.
**Storage**: N/A — feature stateless. A única "configuração" é `versoes.env`, texto versionado e somente leitura em runtime.
**Testing**: `shellcheck` e `gitleaks` no CI — nenhum dos dois é pré-requisito de máquina (Decisions 9 e 15 do research); cenários manuais executáveis em [quickstart.md](./quickstart.md).
**Target Platform**: Linux, WSL e macOS (briefing §5). Nenhuma extensão GNU assumida — daí a comparação de versão em bash puro (Decision 4).
**Project Type**: CLI / scripts de automação de repositório. Single-layer.
**Performance Goals**: N/A — execução única e interativa por máquina. Nenhuma meta numérica foi medida e nenhuma é afirmada.
**Constraints**: `instalar.sh` escreve **apenas** em `~/.claude/skills/` (skills do próprio cockpit), nunca dentro de um projeto-alvo (Princípio VII e FR-011); desde a emenda 1.1.0 não escreve mais em `~/.local/`, porque não instala o `cstk`. Nenhum script executa bootstrap, `cstk self-update`, `cstk install`, `cstk update`, `claude plugin install` nem `claude plugin update` (Princípio IV). Idempotência obrigatória nos dois scripts. `CSTK_MIN` existe num único lugar.
**Scale/Scope**: 3 arquivos de shell + 1 workflow + 3 arquivos de dados versionados (`agnostico.lista`, `.gitleaks.toml`, `.gitleaksignore`). Um repositório varrido por execução.

## Constitution Check

*GATE: passou antes do Phase 0; re-checado após Phase 1 (ver §Re-check).*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | A feature **é** o mecanismo do princípio: `scripts/verificar-agnostico.sh` une `scripts/agnostico.lista` (versionada, só termos que não identificam ninguém, pode ficar vazia) e `AGNOSTICO_TERMOS` (variável de Actions no CI; exportada pelo dev a partir de arquivo local fora do git), roda no CI com zero ocorrências e **falha no CI com as duas fontes vazias** (FR-022, emenda 1.1.0 — a garantia não passa por vacuidade). Exemplos usam nomes fictícios (`minha-org/meu-projeto`). A parte "credencial" da promessa, que o casamento literal não alcançava, passa a ser coberta pelo job `segredos` (FR-019, block-001 → dec-023). |
| II. Cockpit sob o próprio ciclo | PASS | Frente de trilha completa: toca `scripts/`, `.github/` e a raiz. Nasceu em worktree com base explícita e está sendo implementada via `/feature-00c`; o registro SDD entra na PR em `docs/specs/esqueleto-e-instalador/`. |
| III. Identidade de Commit Declarada | PASS | Nada nesta feature altera identidade de commit. O `instalar.sh` não escreve configuração de git. |
| IV. Ferramentas externas são dependências — e ninguém as instala pelo usuário | PASS | Emenda 1.1.0: o instalador só **verifica** (`command -v cstk`, `cstk --version` contra `CSTK_MIN`, `cstk self-update --check`, `cstk install/update --dry-run`, `claude plugin list --json`) e **imprime** o comando oficial de cada lacuna; nenhum bootstrap, `self-update`, `install`, `update` ou `claude plugin install/update` é executado. Pré-requisito faltando → exit ≠ 0. Release mais nova acima do piso → aviso com `cstk self-update` impresso. `CSTK_MIN` lido de `versoes.env` e de nenhum outro lugar. Nenhum hook copiado. |
| V. Fonte Oficial Antes de Afirmar | PASS | Todo fato sobre ferramenta externa em [research.md](./research.md) carrega fonte, marcada FONTE OFICIAL (lida via `context-mode`) ou MEDIDO (sonda empírica com saída citada). A única lacuna encontrada está declarada como lacuna, não preenchida por suposição (Decision 10). |
| VI. Português do Brasil | PASS | Toda mensagem autoral dos scripts em pt-BR com acentuação. FR-012 limita o requisito às mensagens autorais; saída nativa de `git`/`gh`/`cstk`/`curl` passa como vier. |
| VII. Scripts portáveis, idempotentes e contidos | PASS | `set -euo pipefail` nos três scripts; escrita confinada a `~/.claude/skills/`; idempotência por comparação de conteúdo antes de copiar (Decision 14); comparação de versão sem `sort -V` (Decision 4); pré-requisitos limitados à lista fechada. |

**Nenhum FAIL em princípio MUST.** `Complexity Tracking` fica vazio.

## Project Structure

### Documentation (this feature)

```
docs/specs/esqueleto-e-instalador/
├── spec.md
├── plan.md          # Este arquivo
├── research.md      # Phase 0 — 17 decisões com fonte (16 e 17 na round r02)
├── data-model.md    # Phase 1 — formatos de versoes.env, agnostico.lista, relatório
├── quickstart.md    # Phase 1 — cenários de teste executáveis
└── contracts/
    └── cli.md       # Phase 1 — contrato de CLI dos dois scripts
```

### Source Code (repository root)

Árvore real hoje (MEDIDO) mais o que esta feature acrescenta:

```
.
├── .github/
│   └── workflows/
│       └── ci.yml                    # NOVO — shellcheck + agnosticismo + segredos
├── .gitleaks.toml                    # NOVO — allowlists de placeholder (FR-021)
├── .gitleaksignore                   # NOVO — exceções por fingerprint (FR-021)
├── docs/
│   ├── briefing.md                   # existe
│   ├── constitution.md               # existe
│   └── specs/esqueleto-e-instalador/ # existe (artefatos SDD desta frente)
├── scripts/                          # NOVO (diretório)
│   ├── verificar-agnostico.sh        # NOVO
│   └── agnostico.lista               # NOVO
├── instalar.sh                       # NOVO
├── versoes.env                       # existe — chave CSTK_MIN (única fonte do piso)
├── README.md                         # existe
├── LICENSE                           # existe
└── .gitignore                        # existe
```

Fora desta frente, entregues por outras: `configurar.sh`, `skills/`, `templates/`,
`cockpit.config.example`, `THIRD-PARTY-NOTICES.md`.

**Structure Decision**: `instalar.sh` fica na **raiz**, não em `scripts/`, porque é
um dos dois pontos de entrada que o README anuncia ao usuário (`instalar.sh` por
máquina, `configurar.sh` por projeto) — descoberta imediata ao abrir o repositório.
`scripts/` guarda ferramental de manutenção do próprio cockpit, invocado pelo CI e
pelo mantenedor, não pelo dev que está instalando. Os caminhos
`scripts/verificar-agnostico.sh` e `scripts/agnostico.lista` não são escolha livre:
o Princípio I os nomeia literalmente.

## Arquitetura de `instalar.sh`

Pipeline linear de sete etapas, **sequencial por gates** (clarify, Session
2026-09-28): cada etapa registra um status (`ok` | `aviso` | `falhou` | `pulada`)
numa lista acumulada; a **primeira** etapa bloqueante com `falhou` encerra a
execução, e o relatório final (FR-009) imprime uma linha por etapa **avaliada até
ali** — etapas não alcançadas não aparecem (não viram `pulada`). Item não
bloqueante (`aviso`, ou `falhou` de item recomendado) não para o pipeline.

**Verificar e imprimir, nunca instalar (emenda 1.1.0, Princípio IV)**: nenhuma
etapa executa bootstrap de terceiro, `cstk self-update`, `cstk install`,
`cstk update`, `claude plugin install`, `claude plugin update` ou
`claude plugin marketplace add`. Toda lacuna encontrada vira uma linha
`Execute: <comando oficial exato>` impressa junto do item — quem executa é a
pessoa. Os únicos comandos de terceiro que o script roda são **somente leitura**:
`--version`, `--check`, `--dry-run` e `list --json` (research Decision 16).

**Feedback de progresso (CHK012-ux-ops, block-002 → dec-036, respondido pelo
owner)**: além do relatório final consolidado, cada etapa imprime uma linha
autoral em pt-BR ao **iniciar** e outra ao **concluir**
(ex.: `Etapa 2/7: verificando cstk...` / `Etapa 2/7: concluída`). A saída nativa
das ferramentas externas invocadas passa sem filtro, no idioma que a própria
ferramenta produzir — coerente com FR-012. Fora de escopo por ora (YAGNI): flag
`--quiet` e indicador visual tipo *spinner*.

| # | Etapa | O que verifica (somente leitura) | Lacuna → o que imprime | FR | Bloqueante? |
|---|-------|----------------------------------|------------------------|-----|-------------|
| 1 | Pré-requisitos de máquina | presença de `git`, `gh`, `node`, `jq`, `curl` + versão de `git` (>= 2.36) e `node` (>= 20) + pré-checagem de escrita em `~/.claude/skills/` | lista **todos** os ausentes de uma vez | FR-001, FR-011 | **Sim** — exit `2` (ferramentas) ou `3` (escrita) |
| 2 | `cstk` presente | `command -v cstk` | `cstk` ausente → imprime a URL do instalador oficial em dois passos — baixar para arquivo, inspecionar, executar (research Decisions 1 e 16; a forma canalizada direto para o shell não é impressa, A08) | FR-002 | **Sim** — exit `1` |
| 3 | `cstk --version` responde | chamada de versão | falha → mensagem clara | FR-005 | **Sim** |
| 4 | Versão >= `CSTK_MIN` **+ release mais nova** | compara `cstk --version` com `CSTK_MIN` (lido de `versoes.env`); depois `cstk self-update --check` (rc `0` em dia, `10` há release mais nova, `1` erro — MEDIDO) | abaixo do piso → `falhou` + `Execute: cstk self-update`; acima do piso com release mais nova → `aviso` + `Execute: cstk self-update`; `--check` com erro (ex.: sem rede) → `aviso` "não foi possível verificar release" | FR-003, FR-004 | Piso: **sim**. Release mais nova / checagem indisponível: **não** |
| 5 | Catálogo de skills do toolkit | manifest `~/.claude/skills/.cstk-manifest` + `cstk install --dry-run` (o que falta) + `cstk update --dry-run` (o que está defasado) | ausente → `falhou` + `Execute: cstk install`; presente com skill faltando → `aviso` + `Execute: cstk install <nomes>`; presente com artefato defasado → `aviso` + `Execute: cstk update`; dry-run com erro → `aviso` "não foi possível verificar" | FR-006 | Ausente: **sim**. Faltando/defasado/indisponível: **não** |
| 6 | Skills do cockpit | `skills/` do repositório → `~/.claude/skills/` (código do próprio cockpit — **a única escrita** do instalador) | — | FR-007 | Sim quando **falha**; `pulada` quando `skills/` ainda não existe (Decision 13) |
| 7 | Plugins `context-mode` e `ponytail` | `claude plugin list --json`: instalado no escopo `user` e `enabled == true` (MEDIDO) | ausente → `Execute:` com `claude plugin marketplace add <fonte>` (se o marketplace faltar) e `claude plugin install <plugin>@<marketplace> -s user`; desabilitado → `Execute: claude plugin enable <plugin> -s user`; presente e habilitado → `ok`, sem comando impresso (Acceptance Scenario 9: o plugin correto não é mencionado; research Decision 16: não há sinal somente leitura de "desatualizado") | FR-008 | `context-mode` **sim**; `ponytail` **não** |
| — | Relatório final | status por item avaliado + comandos impressos | — | FR-009 | — |

**Ordem**: o piso (etapa 4) é conferido contra a versão **instalada** — não há mais
`self-update` antes dele (research Decision 2, revisada). Abaixo do piso o script
para; a pessoa atualiza e roda de novo. O piso é o mínimo testado, não o alvo:
acima dele, release mais nova é só aviso.

**Restrição de implementação (Decision 12)**: com `set -e`, uma etapa que produz
`aviso` ou `falhou` não-bloqueante precisa ter o status capturado explicitamente,
senão o script aborta antes do relatório. Continua sendo a principal armadilha do
arquivo — e agora vale também para o `rc 10` do `self-update --check`, que é
resultado esperado, não erro.

**Confinamento (FR-011)**: a única área escrita é `~/.claude/skills/` (etapa 6).
Nenhuma etapa aceita ou deriva um caminho de projeto-alvo. `~/.local/` deixou de
ser escrito — quem instala o `cstk` lá é a pessoa, pelo one-liner oficial.

**Pré-checagem de escrita (CHK010, Acceptance Scenario 8)**: a etapa 1 cria e
remove um arquivo temporário em `~/.claude/skills/` (criando o diretório se ainda
não existir) antes de qualquer outra etapa. Sem permissão, exit `3` identificando
a área — sem estado parcial.

**Verificação por plugin (CHK011, Acceptance Scenario 9)**: a etapa 7 decide por
plugin, não em bloco. Um plugin presente e habilitado sai `ok` mesmo quando o
outro está ausente; só a lacuna do ausente gera comando impresso.

**Idempotência (FR-010)**: como o instalador só lê — exceto a cópia de skills do
cockpit, já idempotente por comparação de conteúdo (Decision 14) —, rodar duas
vezes sem a pessoa executar nada produz o mesmo relatório e os mesmos comandos
impressos.

## Arquitetura de `scripts/verificar-agnostico.sh`

Três passos:

1. Montar o conjunto de termos a partir de **duas fontes complementares**
   (FR-022, emenda 1.1.0 do Princípio I):
   - `scripts/agnostico.lista` (versionada): só termos que não identificam
     ninguém; **pode ficar vazia**;
   - `AGNOSTICO_TERMOS` (variável de ambiente): no CI, preenchida pela variável de
     Actions do repositório ou da organização; na máquina, exportada pelo dev a
     partir de arquivo local ignorado pelo git. Mesmo formato da lista — um termo
     por linha, `#` comenta, linhas em branco ignoradas (data-model §Lista).
   Os dois conjuntos passam pelo mesmo trim/remoção de CR/BOM e são unidos.
2. **Guarda anti-vacuidade**: se o conjunto unido ficar vazio **e** a execução for
   de CI, sair com erro — a garantia nunca volta a ser vazia por construção. Fora
   do CI, lista vazia segue sendo estado inicial legítimo (sucesso). A detecção de
   CI é **explícita**: o job `agnostico` exporta `AGNOSTICO_EXIGIR_TERMOS=1`
   (research Decision 17) — não se infere por variável ambiente do runner.
3. Enumerar os arquivos versionados por `git ls-files` (Decision 6) **excluindo
   `scripts/agnostico.lista`** (Decision 7) e casar por substring literal, sem
   distinção de maiúsculas (`grep -i -a -F`, todo arquivo tratado como texto,
   independente de locale), reportando `arquivo:linha` por ocorrência. O caminho
   de cada entrada versionada (inclusive gitlink) entra na varredura e sai como
   `arquivo:0:(caminho)`; o alvo textual de um symlink, sem seguir o link, sai
   como `arquivo:0:(alvo do symlink)`; entrada no índice ausente do disco (sparse
   checkout) tem o blob varrido (review rodadas 1-3).

Saída: `0` com zero ocorrências (FR-013); `1` listando arquivo e linha de cada
ocorrência (FR-014); `2` erro de uso, **incluindo** a guarda anti-vacuidade do
passo 2. Sem efeito colateral — o script só lê (FR-016).

**Não-vazamento dos termos de `AGNOSTICO_TERMOS`**: a saída de falha imprime
`arquivo:linha:<trecho da linha>` — o trecho contém o termo encontrado, o que é o
propósito do relatório. O script **nunca** imprime a lista de termos em si, nem em
modo de erro, e o workflow não faz `echo` da variável — os termos só aparecem no
log quando um deles de fato vazou para o repositório.

## CI do cockpit (`.github/workflows/ci.yml`)

Dispara em `pull_request` e em `push` para `main`. Três jobs independentes, para
que o relatório diga qual garantia barrou (User Story 3, cenários 1 a 3):

| Job | O que faz | FR |
|-----|-----------|-----|
| `shellcheck` | instala `shellcheck` explicitamente e roda sobre todo `.sh` do repositório | FR-017 |
| `agnostico` | executa `scripts/verificar-agnostico.sh` com `AGNOSTICO_TERMOS` mapeada do secret de Actions e `AGNOSTICO_EXIGIR_TERMOS=1` (falha com a fonte externa vazia) | FR-018, FR-022 |
| `segredos` | instala o binário do `gitleaks` (release fixada, checksum conferido) e roda `gitleaks dir . --redact -v` (e, no pull_request, `gitleaks git` sobre o range base..head) | FR-019, FR-020, FR-021 |

O `shellcheck` é instalado pelo job em vez de assumido pré-instalado no runner:
afirmar o conteúdo da imagem do runner sem fonte oficial lida violaria o
Princípio V (Decision 9). O `gitleaks` segue o mesmo padrão — binário baixado e
conferido dentro do job, nunca a Action de terceiro (Decision 15).

**O job `segredos` em detalhe** (justificativa completa em research Decision 15):

- **`--redact` é obrigatório, não cosmético**: o console default do gitleaks
  imprime o campo `Secret:` com o valor encontrado. Sem `--redact`, barrar um
  vazamento publicaria o segredo no log da PR — FR-019 exige apontar arquivo e
  linha *sem* reproduzir o valor.
- **Exceções versionadas (FR-021)**: `.gitleaksignore` na raiz (uma linha por
  *fingerprint* `<file>:<ruleID>:<line>`, três campos no modo `dir`, precedido de um comentário com o motivo) para achados pontuais, e
  `.gitleaks.toml` na raiz (blocos `[[allowlists]]` com `paths`/`regexes`/
  `stopwords`) para classes de placeholder. Os dois são lidos por default quando
  estão na raiz, sem flag. Nenhuma exceção é possível fora do repositório — é o
  que mantém a garantia revisável na própria PR.
- **`dir` e não `git`**: varre a árvore, o mesmo recorte de
  `verificar-agnostico.sh`. Varrer o histórico faria qualquer achado antigo barrar
  toda PR até alguém produzir um *baseline*.
- **Ordem em relação ao `agnostico`**: jobs independentes e paralelos. São
  garantias distintas — nome próprio vs. credencial — e o valor de serem
  separados é o relatório dizer qual das duas barrou.
- **Arquivo binário (CHK012-security)**: diferente de `verificar-agnostico.sh`
  (que declara explicitamente assumir conteúdo textual — spec.md Edge Cases),
  o comportamento do `gitleaks` diante de arquivo binário **não é declarado**
  aqui — a documentação oficial lida (research Decision 15) não cobre esse
  caso, e não há fonte adicional a citar sem violar o Princípio V. É uma
  lacuna factual conhecida, não uma suposição.

**Fora do escopo desta frente**: o render de templates com a config de exemplo —
o briefing o lista no item 6, mas não há templates ainda, e a spec o difere
explicitamente nos Edge Cases.

## Superfície de Segurança

Gate `owasp-security` executado sobre esta arquitetura em 2026-09-25. A feature
não tem autenticação, sessão, banco nem endpoint — o risco é quase todo de
**cadeia de suprimentos e execução de código** (A03, A08, CICD-SEC-4, ASI04/ASI05),
porque o CI executa código de PR. Desde a emenda 1.1.0 o `instalar.sh` **não**
executa mais código de instalação de terceiro na máquina do dev — só comandos
somente leitura de ferramentas que a própria pessoa já instalou.

### Controles adotados no desenho

| Risco | Controle | Referência |
|-------|----------|------------|
| Bootstrap de terceiro sem assinatura executado por script | **Eliminado pela emenda 1.1.0**: o instalador não baixa nem executa bootstrap; imprime a URL oficial em dois passos (baixar, inspecionar, executar) e para. A decisão de executar canal sem assinatura passa a ser da pessoa, com o risco à vista (§Risco residual 1). | A08, ASI04 |
| Execução acidental como root | `instalar.sh` **recusa** rodar como root/`sudo`. O alvo é `~/.claude/skills/` do próprio usuário; como root, a cópia de skills escreveria no `HOME` errado e a verificação leria a máquina errada. | A01 |
| Comando declarado por marketplace auto-aceito | **Eliminado pela emenda 1.1.0** — o instalador não instala nem atualiza plugin; o registro abaixo fica como regra para o comando impresso: ele **nunca** inclui `-y`/`--accept-command`. A CLI exige confirmação de comandos declarados pelo marketplace justamente para que um humano os veja (MEDIDO: `claude plugin update --help` documenta `--accept-command <sha256>` como aceitação restrita a um comando específico). Auto-aceitar converteria uma atualização hostil de marketplace em execução silenciosa. | ASI04, ASI05 |
| `GITHUB_TOKEN` com permissão além do necessário | Workflow declara `permissions: contents: read` no nível do workflow. | CICD-SEC-2 |
| Pwn-request | Gatilho é `pull_request`, **nunca** `pull_request_target`. É deliberado e não deve ser "corrigido": `pull_request` roda o código do fork com token somente-leitura e sem segredos; `pull_request_target` rodaria código não-confiável com token de escrita e acesso a segredos. | CICD-SEC-4 |
| Ação de terceiro mutável | Actions de terceiro fixadas por **SHA de commit**, não por tag móvel. | A03, CICD-SEC-8 |
| Injeção por variável não citada em shell | `shellcheck` no CI é o controle — é exatamente a classe que ele detecta (variável sem aspas, `eval`, expansão de glob). | A05 |
| Execução de código do PR no runner | Aceita: com `pull_request`, token somente-leitura e sem segredos, o raio de alcance é o runner efêmero. | CICD-SEC-4 |
| Segredo real commitado por engano no repositório | Job `segredos` no CI (`gitleaks dir .`) barra a alteração antes do merge. É o mecanismo que faltava para o Princípio I entregar a parte "credencial" da sua promessa — a varredura de agnosticismo nunca detectou isso. | FR-019 |
| O próprio relatório do CI vaza o segredo que acabou de detectar | `--redact` **obrigatório** na invocação: o console default do gitleaks imprime o campo `Secret:` com o valor. Sem a flag, barrar o vazamento seria publicá-lo no log da PR, legível por quem tem acesso ao repositório. | FR-019 |
| Exceção de falso positivo vira porta dos fundos permanente | Exceção só existe em `.gitleaksignore` / `.gitleaks.toml` **versionados**, e portanto aparece no diff da PR que a introduz. Não há toggle fora do repositório, e desligar o job é mudança visível no workflow. | FR-021 |
| Ferramenta de varredura de terceiro executando no CI | Binário fixado por versão de release e conferido contra um sha256 literal fixado no workflow (copiado do `checksums.txt` da release no bump — o arquivo lido na hora vem da mesma origem mutável), baixado e extraído em `$RUNNER_TEMP` dentro do job — **não** a Action de terceiro (que exigiria `GITLEAKS_LICENSE` para repositório de organização e não é mais MIT), **não** tag/branch móvel. O `shellcheck` **não** segue essa disciplina: vem do `apt` da imagem do runner, então sua versão flutua e um bump de regra pode reprovar PR que não mudou shell. Risco aceito (falha fechada, nunca falso verde); pinar o binário por versão+sha256 é a saída se incomodar — review rodada 4. | A03, CICD-SEC-8 |
| Texto de terceiro ecoado no terminal / no comando impresso (round r02) | Todo valor vindo de stdout/stderr de ferramenta externa que entra numa linha autoral ou num `Execute:` passa por allowlist antes de ser impresso: nome de skill `^[A-Za-z0-9][A-Za-z0-9._@-]*$`; versões (`latest:X`, `.version` de plugin) só se casarem `^v?[0-9]+(\.[0-9]+)*$`, senão saem como `desconhecida`. Evita sequência de escape/ANSI e token-flag chegando ao terminal ou à área de transferência de quem copia o comando. | A05, LLM05 |
| Arquivo baixado pelo comando impresso cai dentro do repositório | O `Execute:` de bootstrap grava em `$HOME/cstk-install.sh`, nunca no diretório corrente (que costuma ser o próprio clone) | A08 |
| `versoes.env` interpretado como código | Ler `CSTK_MIN` por **parse explícito** (grep/cut), não por `source`. O arquivo é versionado e confiável, mas `source` transforma um arquivo de dados em script executável sem necessidade. | A08 |

### Risco residual aceito

Cinco riscos permanecem **por desenho**. Os dois primeiros porque a constituição
ratificada os escolhe explicitamente; os dois últimos porque são o teto conhecido
da varredura de segredo. Ficam registrados aqui para que sejam visíveis, não
invisíveis:

1. **Confiança no canal upstream do `cstk`, sem verificação de assinatura e sem
   pinning.** O bootstrap resolve sempre a última release e o `self-update` mantém
   a máquina nela. Um comprometimento da conta/release upstream vira execução de
   código em toda máquina do time, na execução seguinte do instalador.
   *Por que não é mitigado aqui*: verificar assinatura exigiria (a) que o upstream
   publicasse assinaturas e (b) uma ferramenta de verificação fora da lista fechada
   do Princípio VII — emenda constitucional. Reimplementar o download verificando o
   `.sha256` irmão **não resolveria**: quem publica uma release maliciosa publica o
   checksum correspondente, então o `.sha256` de mesma origem só protege contra
   corrupção em trânsito, que o TLS já cobre. O Princípio IV, além disso, proíbe
   essa reimplementação.
   *Estado após a emenda 1.1.0*: o risco **não é mais assumido por script**. O
   instalador imprime o comando oficial; quem o executa decide. O texto acima
   permanece como a informação que a pessoa precisa para decidir.
   *Correção de registro (2026-09-28)*: a redação anterior afirmava "aceito
   formalmente pelo owner em 2026-09-25, na rodada 4". O owner não havia sido
   consultado — a rodada 4 registrou o aceite em nome dele. Consultado em
   2026-09-28, o owner **recusou** o risco, e recusou também as instâncias da
   mesma classe (`cstk self-update`, `cstk install/update`,
   `claude plugin install/update`). A resposta é a emenda 1.1.0 (Princípio IV):
   nenhum script do cockpit executa bootstrap nem atualização de terceiro; o
   instalador verifica e imprime o comando oficial, e a pessoa executa. A
   alternativa "exigir o `cstk` como pré-requisito" — antes recusada por mudar
   FR-002/FR-003 — é a que vale, e o incremento desta frente altera esses
   requisitos. O risco passa a ser **de quem executa o comando**, com a
   informação acima à vista; deixa de ser risco que um script assume por ela.
2. **`CSTK_MIN` é piso de compatibilidade, não controle de segurança.** Ele
   impede versão velha demais, nunca versão maliciosa nova. Desde a emenda 1.1.0 a
   atualização deixou de ser automática — release mais nova vira aviso com
   `cstk self-update` impresso —, então a janela de maturação (*soak*) passa a ser
   de fato a da pessoa, que decide quando atualizar. O que continua sem controle é
   o conteúdo da release que ela escolher executar.
3. **A varredura de segredo é regex + entropia, não prova de ausência.** Ela
   detecta o que os detectores conhecem; segredo em formato não coberto passa. E
   o gitleaks está declarado *feature complete* pelo próprio autor — só correções
   de segurança, sem detectores novos (Decision 15). O caminho de saída está
   contido: a troca por outra ferramenta afeta o workflow e os dois arquivos de
   exceção, nada mais.
4. **Termos de `AGNOSTICO_TERMOS` legíveis por quem controla um job (round r02).**
   *Superado na review rodada 6 (2026-09-28):* a fonte passou a ser
   `secrets.AGNOSTICO_TERMOS` — mascarado pelo runner e não repassado a PR de fork,
   onde a guarda (que agora exige a fonte externa) falha fechada. Resta o risco de
   um PR interno que altere o script contornar a máscara; aceito pelo owner. O texto
   original abaixo fica como histórico.
   A variável de Actions não é segredo (Decision 17) e um PR que altere o
   workflow ou o script pode imprimi-la no log (CICD-SEC-4). Os termos não são
   credencial — a exigência do Princípio I é não citá-los *no repositório* —, então
   o risco é de exposição de nomes, não de acesso. **NÃO VERIFICADO**: se variáveis
   de Actions chegam a workflows disparados por PR de fork; se não chegarem, o job
   `agnostico` desses PRs falha fechado pela guarda anti-vacuidade (nunca falso
   verde). A conferir na documentação oficial ao implementar.
5. **NÃO VERIFICADO**: se o binário do gitleaks faz chamada de rede ao avaliar
   candidatos. A documentação oficial lida não afirma nem nega, e o Princípio V
   não deixa afirmar sem fonte. Mitigação estrutural já em vigor: o job roda com
   `permissions: contents: read` e sem segredos disponíveis.

> **Nota de escopo do Princípio I**: a varredura de agnosticismo é um controle de
> **vazamento de nome próprio**, não de segredo. Casamento literal contra uma lista
> de nomes não detecta chave de API, token, chave privada ou string de conexão.
> Essa lacuna foi levada ao owner como bloqueio humano e está fechada — ver
> §Resolução de governança abaixo.

### Resolução de governança (block-001, respondido pelo owner)

O Princípio I (NON-NEGOTIABLE) afirma que nada no cockpit nomeia *"projeto,
cliente, organização, domínio, **credencial** ou referência de infraestrutura
real"*, e nomeia `scripts/verificar-agnostico.sh` + `scripts/agnostico.lista` como
o mecanismo que torna a garantia verificável. O mecanismo, porém, é casamento
literal contra nomes próprios — estruturalmente incapaz de detectar credencial.
A garantia declarada excedia o que o mecanismo entrega.

**Decisão do owner (block-001 → dec-023)**: ampliar o escopo desta frente com uma
varredura de segredo que roda **apenas no CI**, sem acrescentar pré-requisito à
máquina do dev e **sem emenda constitucional**. As duas restrições são o que torna
a decisão compatível com o texto ratificado:

| Restrição | Por quê |
|---|---|
| Só CI, nunca `instalar.sh` | o Princípio VII fecha os pré-requisitos de máquina em `git`, `gh`, `node`, `jq` e `curl`; uma ferramenta de CI não é pré-requisito de máquina — mesma lógica já aplicada ao `shellcheck` (Decision 9) |
| Sem emenda ao Princípio I | o princípio já prometia a garantia; faltava o mecanismo. Acrescentar o mecanismo *cumpre* o texto ratificado em vez de reescrevê-lo |

Requisitos derivados: FR-019 (detectar, barrar, não reproduzir o valor), FR-020
(só CI, zero pré-requisito local) e FR-021 (exceções em arquivo versionado). O
desenho concreto está em §CI do cockpit e em research Decision 15.

## Convenções de Borda

**N/A — single-layer.** A feature não atravessa fronteira backend↔frontend,
DB↔backend nem broker↔consumer: são scripts de shell locais e um workflow de CI,
sem serviço, sem payload serializado e sem persistência. Não há convenção de
case style nem camada de mapeamento a declarar.

As convenções de interface que de fato existem — formato de
`scripts/agnostico.lista` (e de `AGNOSTICO_TERMOS`, mesmo formato) e da chave `CSTK_MIN` em `versoes.env` — estão em
[data-model.md](./data-model.md); os contratos de CLI (flags, saídas, códigos de
saída) estão em [contracts/cli.md](./contracts/cli.md).

## Re-check de Constitution (pós-Phase 1)

O design não introduziu camada, serviço nem dependência além do que a spec pedia:
continuam sendo três arquivos de shell e um workflow, sem build e sem pacote novo.
Os três pontos que mereciam nova conferência após o design:

- **Princípio IV** — o design agora distingue `cstk self-update` (binário +
  runtime) de `cstk install`/`update` (catálogo), o que *reforça* o princípio:
  a versão anterior do plano rodaria só um dos dois e deixaria metade
  desatualizada em silêncio (Decision 3).
- **Princípio VII** — a comparação de versão em bash puro (Decision 4) foi
  adotada justamente para não depender de `sort -V`, que quebraria a portabilidade
  macOS exigida. A idempotência ganhou regra explícita de aviso em divergência
  local (Decision 14), fechando a cláusula "sem sobrescrever edição local sem
  aviso".
- **Princípio V** — a lacuna da forma genérica de `claude plugin marketplace add`
  na documentação pública foi **declarada como lacuna** em research.md e suprida
  pela fonte primária (`--help` da CLI instalada), nunca por reconstrução
  plausível. A varredura de segredo acrescentou uma segunda lacuna declarada (o
  comportamento de rede do binário do gitleaks) — igualmente declarada, não
  suposta (Decision 15).

**Re-check após a ampliação de escopo do block-001** (varredura de segredo no CI):

- **Princípio I** — a ampliação *fecha* a distância entre o texto do princípio,
  que já prometia "credencial", e o mecanismo, que só detectava nome próprio.
  Nenhuma emenda constitucional foi necessária porque o princípio não muda: ganha
  o mecanismo que faltava.
- **Princípio VII** — a lista fechada de pré-requisitos (`git`, `gh`, `node`,
  `jq`, `curl`) continua com os mesmos cinco itens. A ferramenta vive só no job de
  CI, exatamente como o `shellcheck` (Decision 9), e FR-020 grava essa restrição
  como requisito verificável em vez de convenção tácita (SC-007).
- **Princípio IV** — a ferramenta é usada como dependência, chamada pelo binário
  oficial pinado; nada dela é copiado nem reimplementado no repositório.

**Re-check após a emenda 1.1.0 (round r02, 2026-09-28)**:

- **Princípio IV** — conferido comando a comando: das chamadas de terceiro que
  restam no `instalar.sh` (`cstk --version`, `cstk self-update --check`,
  `cstk install --dry-run`, `cstk update --dry-run`, `claude plugin list --json`,
  `claude plugin marketplace list --json`), nenhuma instala nem atualiza — todas
  são leitura (research Decision 16, com a fonte de cada `--check`/`--dry-run`).
  Research Decisions 1, 2 e 3 foram revisadas: o one-liner passa a ser **texto
  impresso**, o piso é conferido contra a versão instalada, e a distinção
  `self-update` × `install/update` determina **qual** comando imprimir, não qual
  executar.
- **Princípio I** — os termos proibidos saem do repositório (`AGNOSTICO_TERMOS`),
  e a guarda anti-vacuidade no CI (Decision 17) fecha a brecha que a 1.0.0 deixava
  (lista vazia passando por construção).
- **Princípio VII** — a escrita encolheu para `~/.claude/skills/`; a lista fechada
  de pré-requisitos não muda. Idempotência fica mais simples: o instalador quase só
  lê.
- **Clarify r02 (sequencial por gates)** — o pipeline deixa de acumular falhas
  bloqueantes das etapas 2-7: para na primeira, e o relatório cobre só o avaliado.
  Consistente com FR-009 revisado.

**Resultado**: PASS em todos os sete princípios, sem violação a justificar.

## Complexity Tracking

> Vazio. Constitution Check não produziu nenhum FAIL, logo não há violação a
> justificar.

| Violação | Por Que Necessário | Alternativa Simples Rejeitada Porque |
|----------|-------------------|--------------------------------------|
| — | — | — |

## Nota pós-merge

A PR #1 (`todo-tips-solucoes/feat/esqueleto-e-instalador` → `main`, commit
`d45c1ce33a4e4e75865b8c55494571465a6fe19e`, 2026-09-28) foi mesclada por
**merge commit**, não por squash — uma **exceção aceita explicitamente pelo
owner** à regra de merge por squash do Fluxo de Trabalho da
`docs/constitution.md`. A regra em si **não foi alterada**: continua valendo
squash para toda PR de onda seguinte; esta é a única exceção registrada até
o momento (feature `skills-do-cockpit`, FR-013).
