# Implementation Plan: Esqueleto do cockpit-dev e instalador de máquina

**Feature**: `esqueleto-e-instalador` | **Date**: 2026-09-25 | **Spec**: [spec.md](./spec.md)

## Summary

Entregar os dois pilares do esqueleto do cockpit (itens 1 e 6 do MVP do briefing):
`instalar.sh`, que deixa uma máquina pronta para o ciclo num comando só, e
`scripts/verificar-agnostico.sh`, que transforma a promessa de agnosticismo em
verificação executável — mais o CI do próprio cockpit que roda as duas garantias a
cada alteração proposta.

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
**Testing**: `shellcheck` no CI (não é pré-requisito de máquina — Decision 9 do research); cenários manuais executáveis em [quickstart.md](./quickstart.md).
**Target Platform**: Linux, WSL e macOS (briefing §5). Nenhuma extensão GNU assumida — daí a comparação de versão em bash puro (Decision 4).
**Project Type**: CLI / scripts de automação de repositório. Single-layer.
**Performance Goals**: N/A — execução única e interativa por máquina. Nenhuma meta numérica foi medida e nenhuma é afirmada.
**Constraints**: `instalar.sh` escreve **apenas** em `~/.claude/` e `~/.local/`, nunca dentro de um projeto-alvo (Princípio VII e FR-011). Idempotência obrigatória nos dois scripts. `CSTK_MIN` existe num único lugar.
**Scale/Scope**: 3 arquivos de shell + 1 workflow + 1 arquivo de lista. Um repositório varrido por execução.

## Constitution Check

*GATE: passou antes do Phase 0; re-checado após Phase 1 (ver §Re-check).*

| Princípio | Status | Notas |
|-----------|--------|-------|
| I. Agnosticismo Verificável | PASS | A feature **é** o mecanismo do princípio: `scripts/verificar-agnostico.sh` + `scripts/agnostico.lista` versionada e separada da lógica, rodando no CI com zero ocorrências. Exemplos usam nomes fictícios (`minha-org/meu-projeto`). |
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
│       └── ci.yml                    # NOVO — shellcheck + agnosticismo
├── docs/
│   ├── briefing.md                   # existe
│   ├── constitution.md               # existe
│   └── specs/esqueleto-e-instalador/ # existe (artefatos SDD desta frente)
├── scripts/                          # NOVO (diretório)
│   ├── verificar-agnostico.sh        # NOVO
│   └── agnostico.lista               # NOVO
├── instalar.sh                       # NOVO
├── versoes.env                       # existe — CSTK_MIN=10.8.0
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

| # | Etapa | FR | Bloqueante? |
|---|-------|-----|-------------|
| 1 | Pré-requisitos de máquina: presença de `git`, `gh`, `node`, `jq`, `curl` + versão de `git` (>= 2.36) e `node` (>= 20) | FR-001 | **Sim — e encerra aqui**, listando todos os ausentes de uma vez |
| 2 | `cstk` ausente → one-liner oficial; presente → `cstk self-update` | FR-002, FR-003 | Sim |
| 3 | `cstk --version` responde? | FR-005 | Sim |
| 4 | Versão do `cstk` >= `CSTK_MIN` (lido de `versoes.env`) | FR-004 | Sim |
| 5 | `cstk install` (1ª vez) / `cstk update` (demais) — catálogo de skills | FR-006 | Sim |
| 6 | Skills do cockpit de `skills/` → `~/.claude/skills/` | FR-007 | Não (ver Decision 13: `skills/` ainda não existe → item `pulada`) |
| 7 | Plugins: `context-mode` e `ponytail` pelos marketplaces | FR-008 | `context-mode` sim; `ponytail` **não** |
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

## Arquitetura de `scripts/verificar-agnostico.sh`

Três passos:

1. Ler `scripts/agnostico.lista` — um termo por linha, `#` comenta, linhas em
   branco ignoradas (Decision 8).
2. Enumerar os arquivos versionados por `git ls-files` (Decision 6) **excluindo
   `scripts/agnostico.lista`** (Decision 7 — sem isso a varredura casa contra a
   própria lista e falha sempre).
3. Casar por substring literal, sem distinção de maiúsculas (`grep -i -F`),
   reportando `arquivo:linha` por ocorrência.

Saída: `0` com zero ocorrências (FR-013); `1` listando arquivo e linha de cada
ocorrência (FR-014). Sem efeito colateral — o script só lê (FR-016).

**Lista vazia ou só com comentários**: resultado é zero ocorrências, saída `0`. É o
estado inicial legítimo de um cockpit que ainda não catalogou termos, não um erro.

## CI do cockpit (`.github/workflows/ci.yml`)

Dispara em `pull_request` e em `push` para `main`. Dois jobs independentes, para
que o relatório diga qual garantia barrou (User Story 3, cenário 1 e 2):

| Job | O que faz | FR |
|-----|-----------|-----|
| `shellcheck` | instala `shellcheck` explicitamente e roda sobre todo `.sh` do repositório | FR-017 |
| `agnostico` | executa `scripts/verificar-agnostico.sh` | FR-018 |

O `shellcheck` é instalado pelo job em vez de assumido pré-instalado no runner:
afirmar o conteúdo da imagem do runner sem fonte oficial lida violaria o
Princípio V (Decision 9).

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
| `versoes.env` interpretado como código | Ler `CSTK_MIN` por **parse explícito** (grep/cut), não por `source`. O arquivo é versionado e confiável, mas `source` transforma um arquivo de dados em script executável sem necessidade. | A08 |

### Risco residual aceito — decidido pela constituição, não por esta frente

Dois riscos permanecem **por desenho**, porque a constituição ratificada os escolhe
explicitamente. Ficam registrados aqui para que sejam visíveis, não invisíveis:

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
2. **Ausência de janela de maturação (*soak*) nas atualizações.** O Princípio IV
   determina, com redação MUST, manter a máquina na última release. Isso é uma
   decisão de compatibilidade, e `CSTK_MIN` é um piso de **compatibilidade, não um
   controle de segurança** — ele impede versão velha demais, nunca versão
   maliciosa nova.

> **Nota de escopo do Princípio I**: a varredura de agnosticismo é um controle de
> **vazamento de nome próprio**, não de segredo. Casamento literal contra uma lista
> de nomes não detecta chave de API, token, chave privada ou string de conexão.
> Essa lacuna está registrada como bloqueio humano desta onda — ver §Pendência de
> governança abaixo.

### Pendência de governança (bloqueio humano registrado nesta onda)

O Princípio I (NON-NEGOTIABLE) afirma que nada no cockpit nomeia *"projeto,
cliente, organização, domínio, **credencial** ou referência de infraestrutura
real"*, e nomeia `scripts/verificar-agnostico.sh` + `scripts/agnostico.lista` como
o mecanismo que torna a garantia verificável. O mecanismo, porém, é casamento
literal contra nomes próprios — estruturalmente incapaz de detectar credencial.
A garantia declarada excede o que o mecanismo entrega, e fechar a diferença exige
decisão do owner (ampliar o escopo desta frente com varredura de segredo, ou
ajustar a redação do princípio). Não é decisão desta skill nem deste agente.

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
  plausível.

**Resultado**: PASS em todos os sete princípios, sem violação a justificar.

## Complexity Tracking

> Vazio. Constitution Check não produziu nenhum FAIL, logo não há violação a
> justificar.

| Violação | Por Que Necessário | Alternativa Simples Rejeitada Porque |
|----------|-------------------|--------------------------------------|
| — | — | — |
