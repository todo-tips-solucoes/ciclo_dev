# Implementation Plan: Esqueleto do cockpit-dev e instalador de máquina

**Feature**: `esqueleto-e-instalador` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Entregar os dois pilares do esqueleto do cockpit (itens 1 e 6 do MVP do briefing):
`instalar.sh`, que deixa uma máquina pronta para o ciclo num comando só, e
`scripts/verificar-agnostico.sh`, que transforma a promessa de agnosticismo em
verificação executável — mais o CI do próprio cockpit, que a cada alteração
proposta roda três garantias: portabilidade de shell, agnosticismo e ausência de
segredo (esta última acrescentada pela resposta do owner ao block-001).

Abordagem técnica: três arquivos de shell e um workflow, sem build, sem
dependência nova. `instalar.sh` é um pipeline linear de sete etapas que **acumula
status por item** em vez de abortar no primeiro erro, para poder entregar o
relatório consolidado que FR-009 pede. A instalação do `cstk` sai do one-liner
oficial (Princípio IV: dependência, nunca cópia), e a ordem `self-update` →
conferência do piso `CSTK_MIN` é literal da constituição. A varredura de
agnosticismo enumera arquivos por `git ls-files`, o que resolve de graça a
exclusão de `.git/` e do que o `.gitignore` já ignora.

## Technical Context

**Language/Version**: bash (Princípio VII: `set -euo pipefail`, shellcheck sem findings)
**Primary Dependencies**: nenhuma acrescentada. Pré-requisitos de máquina fechados pelo Princípio VII em `git` (>= 2.36), `gh`, `node` (>= 20), `jq`, `curl`. `cstk` e os plugins são provisionados, não empacotados.
**Storage**: N/A — feature stateless. A única "configuração" é `versoes.env`, texto versionado e somente leitura em runtime.
**Testing**: `shellcheck` e `gitleaks` no CI — nenhum dos dois é pré-requisito de máquina (Decisions 9 e 15 do research); cenários manuais executáveis em [quickstart.md](./quickstart.md).
**Target Platform**: Linux, WSL e macOS (briefing §5). Nenhuma extensão GNU assumida — daí a comparação de versão em bash puro (Decision 4).
**Project Type**: CLI / scripts de automação de repositório. Single-layer.
**Performance Goals**: N/A — execução única e interativa por máquina. Nenhuma meta numérica foi medida e nenhuma é afirmada.
**Constraints**: `instalar.sh` escreve **apenas** em `~/.claude/` e `~/.local/`, nunca dentro de um projeto-alvo (Princípio VII e FR-011). Idempotência obrigatória nos dois scripts. `CSTK_MIN` existe num único lugar.
**Scale/Scope**: 3 arquivos de shell + 1 workflow + 3 arquivos de dados versionados (`agnostico.lista`, `.gitleaks.toml`, `.gitleaksignore`). Um repositório varrido por execução.

## Constitution Check

*GATE: passou antes do Phase 0; re-checado após Phase 1 (ver §Re-check).*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | A feature **é** o mecanismo do princípio: `scripts/verificar-agnostico.sh` + `scripts/agnostico.lista` versionada e separada da lógica, rodando no CI com zero ocorrências. Exemplos usam nomes fictícios (`minha-org/meu-projeto`). A parte "credencial" da promessa, que o casamento literal não alcançava, passa a ser coberta pelo job `segredos` (FR-019, block-001 → dec-023). |
| II. Cockpit sob o próprio ciclo | PASS | Frente de trilha completa: toca `scripts/`, `.github/` e a raiz. Nasceu em worktree com base explícita e está sendo implementada via `/feature-00c`; o registro SDD entra na PR em `docs/specs/esqueleto-e-instalador/`. |
| III. Identidade de Commit Declarada | PASS | Nada nesta feature altera identidade de commit. O `instalar.sh` não escreve configuração de git. |
| IV. Ferramentas externas são dependências | PASS | `cstk` instalado pelo one-liner oficial e atualizado por `cstk self-update`; plugins pelos respectivos marketplaces. `CSTK_MIN` lido de `versoes.env` e de nenhum outro lugar. Ordem `self-update` → piso respeitada. Nenhum hook copiado. |
| V. Fonte Oficial Antes de Afirmar | PASS | Todo fato sobre ferramenta externa em [research.md](./research.md) carrega fonte, marcada FONTE OFICIAL (lida via `context-mode`) ou MEDIDO (sonda empírica com saída citada). A única lacuna encontrada está declarada como lacuna, não preenchida por suposição (Decision 10). |
| VI. Português do Brasil | PASS | Toda mensagem autoral dos scripts em pt-BR com acentuação. FR-012 limita o requisito às mensagens autorais; saída nativa de `git`/`gh`/`cstk`/`curl` passa como vier. |
| VII. Scripts portáveis, idempotentes e contidos | PASS | `set -euo pipefail` nos três scripts; escrita confinada a `~/.claude/` e `~/.local/`; idempotência por comparação de conteúdo antes de copiar (Decision 14); comparação de versão sem `sort -V` (Decision 4); pré-requisitos limitados à lista fechada. |

**Nenhum FAIL em princípio MUST.** `Complexity Tracking` fica vazio.

## Project Structure

### Documentation (this feature)

```
docs/specs/esqueleto-e-instalador/
├── spec.md
├── plan.md          # Este arquivo
├── research.md      # Phase 0 — 14 decisões com fonte
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

Pipeline linear de sete etapas. Cada etapa registra um status
(`ok` | `falhou` | `pulada`) numa lista acumulada e o relatório final (FR-009,
cenário 7) imprime uma linha por etapa.

**Feedback de progresso (CHK012-ux-ops, block-002 → dec-036, respondido pelo
owner)**: além do relatório final consolidado, cada uma das sete etapas
imprime uma linha autoral em pt-BR ao **iniciar** e outra ao **concluir**
(ex.: `Etapa 2/7: atualizando cstk...` / `Etapa 2/7: concluída` —
`instalar.sh` não fica em silêncio até o fim). A saída nativa das
ferramentas externas invocadas (`curl`, `cstk`, `claude plugin ...`) passa
sem filtro, no idioma que a própria ferramenta produzir — coerente com a
clarificação de FR-012 (o requisito de pt-BR cobre só a mensagem autoral do
script). Fora de escopo por ora, por decisão do owner (YAGNI): flag
`--quiet` e indicador visual tipo *spinner*.

| # | Etapa | FR | Bloqueante? |
|---|-------|-----|-------------|
| 1 | Pré-requisitos de máquina: presença de `git`, `gh`, `node`, `jq`, `curl` + versão de `git` (>= 2.36) e `node` (>= 20) **+ pré-checagem de escrita** (criar e remover arquivo temporário em `~/.claude/` e `~/.local/`) | FR-001, FR-011 | **Sim — e encerra aqui**, listando todos os ausentes de uma vez (exit `2`) ou a área sem permissão de escrita (exit `3`) |
| 2 | `cstk` ausente → one-liner oficial; presente → `cstk self-update` | FR-002, FR-003 | Sim |
| 3 | `cstk --version` responde? | FR-005 | Sim |
| 4 | Versão do `cstk` >= `CSTK_MIN` (lido de `versoes.env`) | FR-004 | Sim |
| 5 | catálogo de skills: `cstk install` cheio só sem manifest; senão cherry-pick do que falta + `cstk update` | FR-006 | Sim |
| 6 | Skills do cockpit de `skills/` → `~/.claude/skills/` | FR-007 | Não (ver Decision 13: `skills/` ainda não existe → item `pulada`) |
| 7 | Plugins: `context-mode` e `ponytail` pelos marketplaces, **por plugin**: ausente → instala; presente → atualiza (mesmo padrão da etapa 2 com o `cstk`) | FR-008 | `context-mode` sim; `ponytail` **não** |
| — | Relatório final com status por item | FR-009 | — |

**Corte em dois momentos**: a etapa 1 encerra a execução se algo faltar, porque
tentar instalar `cstk` sem `curl` só produziria erro derivado. Das etapas 2 a 7 as
falhas são acumuladas e reportadas juntas.

**Restrição de implementação (Decision 12)**: com `set -e`, uma etapa não-fatal
precisa ter o status capturado explicitamente, senão o script aborta antes do
relatório. Esta é a principal armadilha do arquivo.

**Ordem não-negociável (Decision 2)**: etapa 3 → etapa 4, nunca o inverso. O piso é
o mínimo testado, não o alvo.

**Confinamento (FR-011)**: as únicas áreas escritas são `~/.local/` (binário e
runtime do `cstk`, via one-liner oficial) e `~/.claude/` (catálogo, skills do
cockpit, plugins). Nenhuma etapa aceita ou deriva um caminho de projeto-alvo.

**Pré-checagem de escrita (CHK010, Acceptance Scenario 8)**: a etapa 1 cria e
remove um arquivo temporário em `~/.claude/` e em `~/.local/` (criando os
diretórios se ainda não existirem) antes de qualquer etapa 2-7 rodar. Se
qualquer uma das duas áreas não aceitar a escrita, o script encerra com exit
`3` (contracts/cli.md) identificando a área — sem estado parcial, porque
nenhuma escrita real (`cstk`, catálogo, skills, plugins) ainda aconteceu. A
checagem cabe dentro do mesmo confinamento do parágrafo acima: ela só toca as
duas áreas já autorizadas por FR-011, nunca um caminho de projeto-alvo
(validado em 1.1.3 — nenhuma mudança de confinamento necessária para
implementar isto na FASE 2).

**Instalação seletiva de plugin (CHK011, Acceptance Scenario 9)**: a etapa 7
decide por plugin, não em bloco — o mesmo padrão "ausente instala, presente
atualiza" da etapa 2 com o `cstk`. Um plugin já instalado e correto não é
tocado quando só o outro está ausente.

## Arquitetura de `scripts/verificar-agnostico.sh`

Três passos:

1. Ler `scripts/agnostico.lista` — um termo por linha, `#` comenta, linhas em
   branco ignoradas (Decision 8).
2. Enumerar os arquivos versionados por `git ls-files` (Decision 6) **excluindo
   `scripts/agnostico.lista`** (Decision 7 — sem isso a varredura casa contra a
   própria lista e falha sempre).
3. Casar por substring literal, sem distinção de maiúsculas (`grep -i -a -F`,
   todo arquivo tratado como texto, independente de locale), reportando
   `arquivo:linha` por ocorrência. O caminho de cada entrada versionada
   (inclusive gitlink) entra na varredura e sai como `arquivo:0:(caminho)`; o
   alvo textual de um symlink, sem seguir o link, sai como
   `arquivo:0:(alvo do symlink)`; entrada no índice ausente do disco (sparse
   checkout) tem o blob varrido. Termos passam por remoção de CR/BOM e trim
   antes de casar (review rodadas 1-3).

Saída: `0` com zero ocorrências (FR-013); `1` listando arquivo e linha de cada
ocorrência (FR-014). Sem efeito colateral — o script só lê (FR-016).

**Lista vazia ou só com comentários**: resultado é zero ocorrências, saída `0`. É o
estado inicial legítimo de um cockpit que ainda não catalogou termos, não um erro.

## CI do cockpit (`.github/workflows/ci.yml`)

Dispara em `pull_request` e em `push` para `main`. Três jobs independentes, para
que o relatório diga qual garantia barrou (User Story 3, cenários 1 a 3):

| Job | O que faz | FR |
|-----|-----------|-----|
| `shellcheck` | instala `shellcheck` explicitamente e roda sobre todo `.sh` do repositório | FR-017 |
| `agnostico` | executa `scripts/verificar-agnostico.sh` | FR-018 |
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
porque o `instalar.sh` executa código de terceiro na máquina do dev e o CI executa
código de PR.

### Controles adotados no desenho

| Risco | Controle | Referência |
|-------|----------|------------|
| Download truncado do bootstrap executa parcialmente | Baixar para arquivo temporário e **só então** executar — nunca `curl \| sh` direto. Continua sendo o canal oficial (não é reimplementação), apenas não canaliza para o shell. | A08 |
| Execução acidental como root | `instalar.sh` **recusa** rodar como root/`sudo`. Os alvos são `~/.claude/` e `~/.local/` do próprio usuário; como root, o bootstrap rodaria com privilégio total e escreveria no `HOME` errado. | A01 |
| Comando declarado por marketplace auto-aceito | **Não** passar `-y`/`--accept-command` de forma cega na instalação de plugins. A CLI exige confirmação de comandos declarados pelo marketplace justamente para que um humano os veja (MEDIDO: `claude plugin update --help` documenta `--accept-command <sha256>` como aceitação restrita a um comando específico). Auto-aceitar converteria uma atualização hostil de marketplace em execução silenciosa. | ASI04, ASI05 |
| `GITHUB_TOKEN` com permissão além do necessário | Workflow declara `permissions: contents: read` no nível do workflow. | CICD-SEC-2 |
| Pwn-request | Gatilho é `pull_request`, **nunca** `pull_request_target`. É deliberado e não deve ser "corrigido": `pull_request` roda o código do fork com token somente-leitura e sem segredos; `pull_request_target` rodaria código não-confiável com token de escrita e acesso a segredos. | CICD-SEC-4 |
| Ação de terceiro mutável | Actions de terceiro fixadas por **SHA de commit**, não por tag móvel. | A03, CICD-SEC-8 |
| Injeção por variável não citada em shell | `shellcheck` no CI é o controle — é exatamente a classe que ele detecta (variável sem aspas, `eval`, expansão de glob). | A05 |
| Execução de código do PR no runner | Aceita: com `pull_request`, token somente-leitura e sem segredos, o raio de alcance é o runner efêmero. | CICD-SEC-4 |
| Segredo real commitado por engano no repositório | Job `segredos` no CI (`gitleaks dir .`) barra a alteração antes do merge. É o mecanismo que faltava para o Princípio I entregar a parte "credencial" da sua promessa — a varredura de agnosticismo nunca detectou isso. | FR-019 |
| O próprio relatório do CI vaza o segredo que acabou de detectar | `--redact` **obrigatório** na invocação: o console default do gitleaks imprime o campo `Secret:` com o valor. Sem a flag, barrar o vazamento seria publicá-lo no log da PR, legível por quem tem acesso ao repositório. | FR-019 |
| Exceção de falso positivo vira porta dos fundos permanente | Exceção só existe em `.gitleaksignore` / `.gitleaks.toml` **versionados**, e portanto aparece no diff da PR que a introduz. Não há toggle fora do repositório, e desligar o job é mudança visível no workflow. | FR-021 |
| Ferramenta de varredura de terceiro executando no CI | Binário fixado por versão de release e conferido contra um sha256 literal fixado no workflow (copiado do `checksums.txt` da release no bump — o arquivo lido na hora vem da mesma origem mutável), baixado e extraído em `$RUNNER_TEMP` dentro do job — **não** a Action de terceiro (que exigiria `GITLEAKS_LICENSE` para repositório de organização e não é mais MIT), **não** tag/branch móvel. O `shellcheck` **não** segue essa disciplina: vem do `apt` da imagem do runner, então sua versão flutua e um bump de regra pode reprovar PR que não mudou shell. Risco aceito (falha fechada, nunca falso verde); pinar o binário por versão+sha256 é a saída se incomodar — review rodada 4. | A03, CICD-SEC-8 |
| `versoes.env` interpretado como código | Ler `CSTK_MIN` por **parse explícito** (grep/cut), não por `source`. O arquivo é versionado e confiável, mas `source` transforma um arquivo de dados em script executável sem necessidade. | A08 |

### Risco residual aceito

Quatro riscos permanecem **por desenho**. Os dois primeiros porque a constituição
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
   *Aceito formalmente pelo owner em 2026-09-25*, na revisão de código desta
   frente (rodada 4), depois de o achado ser levantado nas quatro rodadas e
   classificado como alto por uma delas. As alternativas foram postas e
   recusadas: pinar versão + sha256 do `install.sh` contradiz `versoes.env`
   ("o instalador mantém a máquina na última release") e não impediria o
   `self-update` seguinte de trazer a release nova; exigir o `cstk` como
   pré-requisito de máquina mudaria FR-002/FR-003 e tiraria a conveniência de
   máquina zero. **Decisão de escopo, não descuido** — revisão futura que
   reabrir o tema deve tratar este parágrafo como a resposta.
2. **Ausência de janela de maturação (*soak*) nas atualizações.** O Princípio IV
   determina, com redação MUST, manter a máquina na última release. Isso é uma
   decisão de compatibilidade, e `CSTK_MIN` é um piso de **compatibilidade, não um
   controle de segurança** — ele impede versão velha demais, nunca versão
   maliciosa nova.
3. **A varredura de segredo é regex + entropia, não prova de ausência.** Ela
   detecta o que os detectores conhecem; segredo em formato não coberto passa. E
   o gitleaks está declarado *feature complete* pelo próprio autor — só correções
   de segurança, sem detectores novos (Decision 15). O caminho de saída está
   contido: a troca por outra ferramenta afeta o workflow e os dois arquivos de
   exceção, nada mais.
4. **NÃO VERIFICADO**: se o binário do gitleaks faz chamada de rede ao avaliar
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

As duas convenções de interface que de fato existem — formato de
`scripts/agnostico.lista` e da chave `CSTK_MIN` em `versoes.env` — estão em
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

**Resultado**: PASS em todos os sete princípios, sem violação a justificar.

## Complexity Tracking

> Vazio. Constitution Check não produziu nenhum FAIL, logo não há violação a
> justificar.

| Violação | Por Que Necessário | Alternativa Simples Rejeitada Porque |
|----------|-------------------|--------------------------------------|
| — | — | — |
