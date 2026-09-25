# Project Briefing: cockpit-dev

**Data**: 2026-09-25
**Status**: Ratificado pelo owner em 2026-09-25 (junto com a constitution 1.0.0)
**Versão**: 1.0

---

## 1. Visão e Propósito

**O que é**: um cockpit de instalação e configuração de um ciclo de desenvolvimento agêntico
com Claude Code — `worktree → /feature-00c → revisão adversarial → rito de PR → registro na PR` —
que qualquer repositório GitHub adota com dois comandos: `instalar.sh` (uma vez por máquina) e
`configurar.sh` (uma vez por projeto).

**Problema que resolve**: o ciclo nasceu num projeto e foi replicado à mão em outros dois, cada
vez reescrito a partir do anterior. Não existe fonte única: cada cópia deriva, as lições
aprendidas numa não chegam às outras, e a peça mais importante (a etapa de implementação, que vem
de um toolkit externo) não é instalada por nenhum dos kits — e nenhum avisa quando falta.

**Proposta de valor**: uma fonte versionada, agnóstica ao projeto, que entrega governança
(constituição, contrato com agentes), skills, automação de CI, integração com o board e o rito
completo — parametrizados pelo que varia entre projetos e verificados por teste de que nada do
projeto de origem vazou.

## 2. Usuários e Stakeholders

| Ator | Papel | Ações Principais |
|------|-------|-----------------|
| Owner do projeto-alvo | Humano, decide | Roda `configurar.sh`, ratifica a constituição gerada, aprova PRs, promove para produção |
| Dev do time | Humano, implementa | Roda `instalar.sh`, abre frentes pelo ciclo, abre PRs, mergeia após aprovação |
| Claude Code | Agente | Conduz o rito fase a fase, implementa via `/feature-00c`, revisa via `bmad-code-review`, **para no gate de review** |
| Mantenedor do cockpit | Humano, decide | Evolui o cockpit sob o próprio ciclo (dogfooding) |

**Stakeholders de decisão**: o owner (`paulotodo`) decide prioridades, ratifica a constituição do
cockpit e aprova cada PR.

## 3. Escopo

### MVP (Essencial)

1. **`instalar.sh`** (máquina): checa pré-requisitos (`git`, `gh`, `node`, `jq`, `curl`), instala
   o `cstk` pelo one-liner oficial quando falta e o atualiza para a última release quando existe
   (`cstk self-update`), confere o piso `CSTK_MIN` de `versoes.env`, roda `cstk install`/`update`,
   instala as skills do cockpit em `~/.claude/skills/`, instala ou atualiza os plugins
   `context-mode` e `ponytail`, e valida tudo no fim — inclusive `cstk --version`, que nenhum kit
   anterior conferia.
2. **`configurar.sh`** (projeto): pergunta os parâmetros (nome, `org/repo`, branch de integração,
   branch de produção, gerenciador de pacotes, comando de typecheck/lint/build, comando de deploy
   por ambiente, tabela de identidades, board), grava `cockpit.config`, renderiza os templates,
   provisiona os guard hooks via `cstk hooks install --project-path`, e recusa terminar com
   placeholder residual.
3. **Três skills**: `parallel-work` (worktree com base explícita), `rito-dev` (as 11 fases do
   rito, com ambientes e comandos por parâmetro) e `bmad-code-review` (cópia, MIT).
4. **Templates de governança**: `docs/constitution.md` (princípios II, II-bis, III — ligado por
   padrão e desligável —, IV, IV-bis, V, VI, VII, VIII, mais seção vazia para os princípios
   próprios do projeto), `CLAUDE.md`, `docs/rito-dev.md`, `docs/CICLO-GIT.md`,
   `docs/agentes/{guardiao,implementador,revisor,triador}.md`, `docs/project-context.md`.
5. **Templates de automação**: workflows `ci`, `commitlint`, `require-codeowner-approval`,
   `promotion-pr`, `audit-merge-vermelho`, `release`; `CODEOWNERS`; `.releaserc.json`;
   `.claude/scripts/task.sh` (board GitHub Projects, com subcomando `discover` que resolve os IDs).
6. **`verificar-agnostico.sh`** + CI do próprio cockpit: lista proibida sobre todo o repositório
   = 0 ocorrências; shellcheck; render de todos os templates com a config de exemplo.
7. `README.md`, `LICENSE` (MIT), `THIRD-PARTY-NOTICES.md`.

### Pós-MVP (Desejável)

1. Encerramento de frente via `cstk session end` / `cstk session pr` (guards de dirty/unpushed/PR aberto).
2. Documentar `cstk recall`, `cstk serve` e `cstk usage` como opcionais do ciclo.
3. Guard de CI opcional que verifica, no projeto-alvo, se a PR trouxe o registro da frente.

### Fora de Escopo

- Qualquer referência a projeto, cliente, organização, domínio ou credencial específicos.
- Plataformas git além do GitHub; clientes de IA além do Claude Code.
- Skills de domínio (atendimento, produto, negócio).
- O deploy em si: o cockpit só o invoca como comando configurável por ambiente.
- Modelo trunk-based como modo separado: o modelo é um só (integração → produção), e
  "integração = produção" é um caso válido dele, não outro modo.

## 4. Prioridades e Trade-offs

**Ordem de prioridade**: Agnosticismo > Fidelidade ao ciclo > Simplicidade de instalação > Abrangência

**Decisões explícitas** (owner, 2026-09-24/25):
- GitHub only; Claude Code only.
- Modelo de branches fixo `integração → produção`, nomes parametrizáveis; o cockpit se adapta ao
  projeto (uma branch só é caso válido), nunca o contrário.
- `cstk` instalado pela CLI (o plugin de marketplace não traz o binário).
- `context-mode` obrigatório (princípio); `ponytail` recomendado.
- `bmad-code-review` copiada para dentro do cockpit (licença MIT, aviso preservado); as demais
  ferramentas são dependências instaladas pelos canais oficiais.
- Princípio III (typecheck só no CI, sem ambiente local, smoke em staging/prod) entra **ligado por
  padrão e desligável** no `configurar.sh`.
- Identidade de commit: cada autor com a própria identidade, tabela nominal por projeto.
- Idioma: português do Brasil.
- O cockpit é desenvolvido **sob o próprio ciclo** (dogfooding), neste repositório, em três
  trilhas decididas pelo caminho dos arquivos (completa / docs / trivial — Princípio II).
- Versão do `cstk`: piso único em `versoes.env`; o instalador sempre atualiza para a última
  release e falha só abaixo do piso; o piso sobe por PR.
- Release do cockpit: tag manual `v1.0.0` ao fim da última onda do MVP.

## 5. Restrições

| Restrição | Valor | Notas |
|-----------|-------|-------|
| Prazo | flexível | entrega por ondas, cada onda uma PR |
| Equipe | owner + Claude Code | revisão adversarial por skill; gate humano do owner |
| Budget | não definido | — |
| Técnica | bash (scripts), Node (driver do `parallel-work`, herdado), Markdown, YAML | pré-requisitos: `git ≥ 2.36`, `gh`, `node ≥ 20`, `jq`, `curl`; Linux/WSL/macOS |

## 6. Stack Técnica

| Camada | Tecnologia | Justificativa |
|--------|-----------|---------------|
| Instalador / configurador | bash, `set -euo pipefail`, shellcheck limpo | portável, sem build, mesma linguagem dos hooks do `cstk` |
| Worktrees | Node (`driver.mjs` do `parallel-work`) | herdado e testado; Node já é pré-requisito do `context-mode` |
| Skills e templates | Markdown com placeholders `{{NOME}}` | formato nativo do Claude Code; render por substituição literal, sem engine |
| Implementação (etapa 2 do ciclo) | `cstk` (`/feature-00c`, pipeline SDD, guard hooks) | dependência externa; piso em `versoes.env`, máquina mantida na última release |
| Consulta externa | plugin `context-mode` | obrigatório por princípio |
| CI do cockpit | GitHub Actions | shellcheck + agnosticismo + render dos templates |
| Integrações | `gh` CLI (PR, checks, Projects via GraphQL) | espinha do rito |

## 7. Qualidade e Padrões

**Padrões adotados**:
- Teste de agnosticismo no CI: lista proibida versionada, 0 ocorrências.
- Render de todos os templates com `cockpit.config.example`: nenhum `{{...}}` residual.
- shellcheck sem findings em todo `.sh`.
- Conventional Commits em PT-BR; PR pequena por onda; revisão adversarial antes de abrir a PR.
- Toda afirmação sobre ferramenta externa tem link para a documentação oficial, lida via `context-mode`.

**Compliance**: nenhum específico. Nenhum e-mail pessoal nos templates — identidades de commit
usam o endereço `noreply` do GitHub.

## 8. Visão de Futuro

**6 meses**: em uso em três ou mais projetos; atualização de um projeto = `git pull` do cockpit +
`configurar.sh --atualizar` (re-render sem perder a config).

**12 meses**: guard de CI opcional no projeto-alvo; `cstk session` no encerramento; ciclo
documentado como padrão da organização.

**Riscos conhecidos**:
- O `cstk` muda contrato entre versões (já mudou 5 vezes num mês) e o instalador mantém a máquina
  na última release. Mitigação: piso `CSTK_MIN` em `versoes.env` (único lugar), conferido no
  instalador e no configurador, e o CI do cockpit rodando contra a última release do `cstk` para
  detectar quebra antes de um projeto-alvo.
- O Claude Code muda o formato de skills/hooks/settings. Mitigação: os hooks são provisionados
  pelo `cstk`, não copiados; as skills seguem só o frontmatter documentado.
- Os projetos que já replicaram o ciclo à mão divergem do cockpit. Mitigação: o cockpit passa a
  ser a fonte; migrar um projeto é rodar `configurar.sh` sobre ele.

---

## Itens a Definir

| Item | Dimensão | Impacto |
|------|----------|---------|
| Nenhum — os dois itens de 25/09 foram decididos: piso do `cstk` em `versoes.env` com atualização contínua; release do cockpit por tag manual (`semantic-release` pós-MVP) | — | — |

---

**Próximo passo recomendado**: ratificar `docs/constitution.md` e abrir a Onda 1.
