# Data Model: Skills do cockpit + alinhamento do briefing

Feature stateless — não há banco nem sessão. O "dado" desta feature é o
formato de um arquivo texto (`cockpit.config`) e a estrutura fixa das três
skills entregues. Este documento fixa os dois.

---

## Entity: Arquivo de configuração do projeto-alvo (`cockpit.config`)

Formato `CHAVE=valor`, uma por linha; linhas iniciadas por `#` são comentário
(mesmo formato de `versoes.env`, já em uso neste repositório — research.md
Decision 2). Vive em cada projeto-alvo, na raiz; **nunca** versionado dentro
do cockpit — só `cockpit.config.example` (FR-006) o é.

| Campo | Tipo | Obrigatória | Constraints | Notes |
|-------|------|:-----------:|-------------|-------|
| `PROJETO_NOME` | string | sim | não vazio | nome legível do projeto-alvo |
| `REPO_REMOTO` | string | sim | formato `org/repo` | usado em chamadas `gh api repos/<REPO_REMOTO>/...` |
| `BRANCH_INTEGRACAO` | string | sim | nome de branch válido | branch default de PRs de feature/fix/chore/docs |
| `BRANCH_PRODUCAO` | string | sim | nome de branch válido; **pode ser igual a** `BRANCH_INTEGRACAO` | Princípio I do cockpit: modelo único, "integração=produção" é caso válido, não modo separado |
| `GERENCIADOR_PACOTES` | string | sim | um de `npm`\|`pnpm`\|`yarn`\|`bun` ou outro identificador de comando | usado só para citar no relatório da Fase 2; a skill não invoca instalação de dependências por conta própria |
| `CMD_TYPECHECK` | string | sim | comando de shell não vazio | roda no CI, nunca localmente (briefing §7) |
| `CMD_LINT` | string | sim | comando de shell não vazio | idem |
| `CMD_BUILD` | string | sim | comando de shell não vazio | idem |
| `CMD_DEPLOY_INTEGRACAO` | string | sim | comando de shell não vazio | referenciado na Fase 7 (relatório de deploy automático) |
| `CMD_DEPLOY_PRODUCAO` | string | sim | comando de shell não vazio; **pode repetir** `CMD_DEPLOY_INTEGRACAO` | referenciado na Fase 9 |
| `URL_AMBIENTE_INTEGRACAO` | string | não | URL válida ou ausente | Fase 8 (smoke); se ausente, a skill pergunta ao dev |
| `URL_AMBIENTE_PRODUCAO` | string | não | URL válida ou ausente | Fase 10 (smoke); se ausente, a skill pergunta ao dev |

### Regras

- Chave obrigatória ausente → a skill `rito-dev` MUST dizer qual chave falta,
  **nunca** seguir com um valor presumido (Edge Case da spec).
- `cockpit.config.example` (FR-006) contém as 10 chaves obrigatórias + as 2
  opcionais, todas preenchidas com valores fictícios genéricos
  (`minha-org/meu-projeto`, `staging`, `main` — nunca nome de projeto real,
  Princípio I da constitution do cockpit).
- Nenhum parser além de `grep`/`source` em bash puro — sem dependência nova
  (research.md Decision 2).

### Relationships

- **Skill `rito-dev`** lê 1 `cockpit.config` por invocação → 1:1 com o
  projeto-alvo onde está instalada.
- **`cockpit.config.example`** N:1 com o repositório do cockpit — um único
  exemplo de referência, reaproveitado por todo projeto-alvo até existir um
  `configurar.sh` (Pós-MVP do briefing, fora desta feature).

### State Transitions

N/A — arquivo estático, sem ciclo de vida (não é criado/atualizado por esta
feature; é preenchido à mão pelo dev a partir do exemplo, User Story 1).

---

## Entity: Skill do cockpit

Pacote de instrução copiado por `instalar.sh` (feature `esqueleto-e-instalador`,
já entregue) para `~/.claude/skills/`. Três instâncias nesta feature.

| Campo | `parallel-work` | `rito-dev` | `bmad-code-review` |
|-------|------------------|------------|---------------------|
| Origem | cópia de `~/.claude/skills/parallel-work/` | conteúdo novo, derivado de `~/.claude/skills/rito-dev-nav/SKILL.md` §"## Fases" | cópia de `~/.claude/skills/bmad-code-review/` |
| Arquivos | `SKILL.md`, `driver.mjs` | `SKILL.md` | `SKILL.md`, `customize.toml`, `steps/*.md` |
| Adaptação de conteúdo | 2 referências de path corrigidas (research.md Decision 9) | íntegra — cada valor variável vira leitura de `cockpit.config` (research.md Decisions 1, 3, 5, 6) | nenhuma (research.md Decision 7) |
| Licença/proveniência | própria do cockpit (sem terceiro) | própria do cockpit (conteúdo derivado, não cópia de código) | MIT, `bmad-code-org/BMAD-METHOD` — registrada em `THIRD-PARTY-NOTICES.md` (research.md Decision 8) |

### Relationships

- **Skill do cockpit** 1:1 **Diretório em `skills/`** — um diretório por
  skill (FR-001), pronto para `instalar.sh` copiar.
- **`rito-dev`** N:1 **`cockpit.config`** — a mesma skill roda contra qualquer
  projeto-alvo que tenha o arquivo preenchido; nenhum valor de projeto vive na
  skill (FR-003/FR-004).

### State Transitions

N/A — skills são arquivos estáticos versionados; não têm ciclo de vida em
runtime além de "instalada" / "não instalada" (responsabilidade de
`instalar.sh`, fora desta feature).

---

## Entity: Registro de dependências de terceiros (`THIRD-PARTY-NOTICES.md`)

| Campo | Tipo | Notes |
|-------|------|-------|
| Nome do projeto de origem | string | `BMAD-METHOD` |
| Repositório | URL | `https://github.com/bmad-code-org/BMAD-METHOD` |
| Licença | string | `MIT` (com nota de marca registrada — research.md Decision 8) |
| Texto da licença | texto verbatim | copiado byte a byte do arquivo `LICENSE` oficial |
| Skill copiada | string | `bmad-code-review` |

### Relationships

- 1:N — um registro de dependência por cópia de terceiro; hoje só
  `bmad-code-review` qualifica (Constraints da constitution, Princípio IV:
  "a única cópia é a skill `bmad-code-review`").

### State Transitions

N/A — documento estático, atualizado só quando uma nova cópia de terceiro
entrar no cockpit (fora do escopo desta feature).
