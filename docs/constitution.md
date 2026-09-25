# cockpit-dev Constitution

> Governança **deste repositório** — como o cockpit é desenvolvido. Não confundir com o template
> de constituição que o cockpit entrega aos projetos-alvo (`templates/docs/constitution.md.tmpl`).

## Core Principles

### I. Agnosticismo Verificável (NON-NEGOTIABLE)

O cockpit serve a qualquer projeto. Nada nele nomeia um projeto, cliente, organização, domínio,
credencial ou referência de infraestrutura real. O que varia entre projetos é parâmetro; o que não
varia é o ciclo. A garantia não é promessa: é teste que roda no CI.

**MUST:**

- Todo arquivo do repositório MUST passar por `scripts/verificar-agnostico.sh` no CI, com a lista
  proibida versionada em `scripts/agnostico.lista` e resultado igual a zero ocorrências.
- Exemplos e placeholders MUST usar nomes fictícios genéricos (`minha-org/meu-projeto`,
  `staging`, `main`), nunca nomes de projetos reais — inclusive dos projetos onde o ciclo nasceu.
- Um valor que muda de projeto para projeto MUST ser chave em `cockpit.config`, nunca literal em
  skill, template ou script.
- O caso "branch de integração = branch de produção" MUST ser aceito pelo configurador e pelo
  rito como configuração válida do modelo único, não como modo separado.

### II. O Cockpit Se Desenvolve Sob o Próprio Ciclo (NON-NEGOTIABLE)

O que o cockpit exige dos projetos-alvo ele exige de si mesmo. Toda mudança percorre uma das três
trilhas abaixo. A trilha é decidida pelo **caminho** dos arquivos tocados, nunca pela extensão:
neste repositório skills e templates são `.md` e são o produto, não documentação. A base é `main`;
o modelo aqui é o caso "integração = produção".

| Trilha | Quando | Etapas |
|---|---|---|
| **Completa** | qualquer arquivo fora de `docs/`, `README.md` e `THIRD-PARTY-NOTICES.md` — inclui `skills/`, `templates/`, `scripts/`, `.github/`, `versoes.env`, `cockpit.config.example` | worktree → `/feature-00c` → `bmad-code-review` até zero achado alto/crítico → PR → gate do owner → registro em `docs/specs/<short-name>/` |
| **Docs** | só `docs/**` (exceto `docs/constitution.md`), `README.md`, `THIRD-PARTY-NOTICES.md` e imagens | worktree → escrever → `validate-docs-rendered` + **uma** rodada de `bmad-code-review` (achados altos aplicados; os demais viram defer declarado na PR) → PR → gate. O registro é a própria descrição da PR |
| **Trivial** | subconjunto da Docs em que nenhuma frase nem comando muda de sentido: typo, link, formatação, pontuação | branch a partir de `origin/main` (worktree opcional) → PR → CI → gate. Sem revisão por skill: o revisor é o owner no gate |

Nunca em trilha curta: `docs/constitution.md` (emenda é trilha completa mais sign-off explícito,
mesmo sendo `.md`), revert de emergência e qualquer mudança que toque um caminho da trilha completa.

**MUST:**

- Toda mudança de trilha completa ou docs MUST nascer em worktree criada com base explícita
  (`--base origin/main`), nunca em checkout na árvore principal.
- Toda mudança de trilha completa MUST ser implementada via `/feature-00c` com `--projeto`
  apontando para a worktree.
- Toda PR de trilha completa MUST ter uma rodada de `bmad-code-review` sobre o diff antes de ser
  aberta, e uma nova rodada após aplicar achados; o ciclo termina quando uma rodada não produz
  achado alto ou crítico. Trilha docs MUST ter uma rodada; trilha trivial nenhuma.
- A trilha MUST ser declarada no corpo da PR com a lista dos caminhos tocados; um arquivo fora do
  caminho da trilha declarada torna a PR trilha completa.
- `docs/constitution.md` MUST NOT ser alterada por trilha docs ou trivial.
- Nenhuma PR MUST ser mergeada sem aprovação explícita do owner; o agente prepara, acompanha o CI
  e para no gate.
- O registro da frente de trilha completa (artefatos SDD e achados da revisão) MUST entrar na PR
  da própria frente, em `docs/specs/<short-name>/`.
- Antes de qualquer leitura que vire conclusão, a base MUST ser verificada: `git fetch origin main`
  e `git rev-parse origin/main` igual ao SHA devolvido pela API do GitHub.

### III. Identidade de Commit Declarada

Cada commit sai com a identidade do próprio autor, constante da tabela abaixo. Conta compartilhada
não commita. A rastreabilidade exige autor identificado, não autor único.

| Quem | `user.name <user.email>` |
|---|---|
| owner | `paulotodo <154374725+paulotodo@users.noreply.github.com>` |

**MUST:**

- Antes de commitar, `git var GIT_AUTHOR_IDENT` e `git var GIT_COMMITTER_IDENT` MUST ambos bater
  com uma linha da tabela — as duas variáveis, não `git config`, que não enxerga o ambiente.
- Entrar na tabela, sair dela ou mudar a própria identidade MUST ser emenda desta constituição.
- O agente MUST NOT alterar a identidade configurada por conta própria.

### IV. Ferramentas Externas São Dependências, Não Cópias

O cockpit compõe `cstk`, `context-mode` e `ponytail`; não os reimplementa nem os embute. A única
cópia é a skill `bmad-code-review`, sob licença MIT, com o aviso preservado.

**MUST:**

- `cstk`, `context-mode` e `ponytail` MUST ser instalados pelos canais oficiais de cada um.
- O piso de versão do `cstk` MUST existir em um único lugar, a chave `CSTK_MIN` de `versoes.env`;
  nenhum outro arquivo MUST escrever o número — scripts e documentos referem-se à chave. O piso
  sobe por PR de trilha completa quando o cockpit passa a depender de recurso de versão mais nova.
- O instalador MUST manter a máquina na última release do `cstk` (`cstk self-update`, idempotente)
  e, só depois, MUST falhar se `cstk --version` for menor que `CSTK_MIN`: o piso é o mínimo
  testado, não o alvo. O mesmo vale para os plugins via `claude plugin update`.
- Os guard hooks do runtime MUST ser provisionados por `cstk hooks install --project-path`, nunca
  copiados pelo cockpit.
- Toda cópia de código de terceiro MUST constar de `THIRD-PARTY-NOTICES.md` com a licença verbatim.
- O instalador MUST falhar com mensagem clara quando `cstk --version` não responder — a etapa de
  implementação do ciclo não existe sem ele.

### V. Fonte Oficial Antes de Afirmar (NON-NEGOTIABLE)

Nenhuma afirmação sobre comportamento de ferramenta externa entra no cockpit sem a documentação
oficial lida antes, via `context-mode`, com o link registrado. Nenhum número, contagem ou
comportamento é inventado: o que não foi medido diz "não medido".

**MUST:**

- Toda consulta a conteúdo externo MUST passar pelas ferramentas `ctx_*` do `context-mode`;
  `WebFetch`, `curl` e `wget` para ler conteúdo MUST NOT ser usados.
- Toda afirmação sobre `cstk`, `context-mode`, `ponytail`, GitHub CLI ou Actions MUST citar a
  página oficial com link, no registro da frente que a introduziu.
- Um dado factual sem fonte MUST ser marcado como não medido ou removido — nunca estimado como
  se fosse medição.

### VI. Português do Brasil

O cockpit é lido por pessoas antes de ser lido por agentes. O texto é em português do Brasil, com
acentuação correta; identificadores, comandos e chaves de configuração ficam como são no código.

**MUST:**

- Prosa em skills, templates, README e mensagens de script MUST estar em português do Brasil com
  diacríticos corretos.
- Mensagens de commit MUST seguir Conventional Commits com descrição em português.

### VII. Scripts Portáveis, Idempotentes e Contidos

Um script do cockpit roda igual em Linux, WSL e macOS, pode ser executado duas vezes sem efeito
colateral, e só escreve onde foi mandado.

**MUST:**

- Todo `.sh` MUST usar bash com `set -euo pipefail` e passar no shellcheck sem findings.
- `instalar.sh` MUST escrever apenas em `~/.claude/` e `~/.local/`; `configurar.sh` MUST escrever
  apenas dentro do projeto-alvo informado.
- Rodar qualquer script uma segunda vez MUST produzir o mesmo estado final, sem duplicar
  registros nem sobrescrever edição local sem aviso.
- Os pré-requisitos MUST se limitar a `git`, `gh`, `node`, `jq` e `curl`, além do que o `cstk`
  exige por conta própria.

## Fluxo de Trabalho

Cada entrega é uma onda, e cada onda uma PR para `main`, mergeada por squash após o gate do owner.
Trilha completa: `parallel-work --base origin/main` → `/feature-00c … --projeto <worktree>` →
`bmad-code-review` → PR → CI verde → gate → merge → registro em `docs/specs/<short-name>/`.
As trilhas docs e trivial estão na tabela do Princípio II.

## Governance

Esta constituição vence qualquer outro documento deste repositório. Emenda é PR com sign-off
explícito do owner registrado no corpo da PR; a versão segue SemVer (MAJOR: princípio removido ou
redefinido; MINOR: princípio ou regra adicionada; PATCH: redação). Ratificação inicial pelo owner.

**Version**: 1.0.0 | **Ratified**: 2026-09-25 (owner, sign-off explícito na sessão) | **Last Amended**: 2026-09-25
