# Code review — templates-governanca

**Data:** 2026-09-30
**Diff:** `main...feat/templates-governanca`, restrito a `templates/` e `scripts/` (10 arquivos, +457)
**Método:** `bmad-code-review` com três camadas em paralelo (Blind Hunter, Edge Case Hunter,
Acceptance Auditor), seguida de conferência manual dos achados contra `configurar.sh`,
`skills/rito-dev/SKILL.md`, `docs/constitution.md` e o pre-flight do `/feature-00c`.

**Resultado:** 1 decisão do owner, 14 correções aplicadas, 1 adiada, 6 descartadas.

## Decisão do owner

- [x] **Seções editadas à mão x manifesto do configurador.** O `configurar.sh` recusa o lote
  inteiro quando um destino foi editado à mão, e só `--forcar` sobrescreve, perdendo a edição.
  Isso atinge os princípios próprios da constituição, as seções "A preencher" do
  `project-context.md` e um `CLAUDE.md` pré-existente no projeto-alvo. Decisão: documentar nos
  templates que o arquivo editado passa a ser do projeto (re-render com `--forcar` e reaplicação
  manual) e abrir follow-up para um modo "semente" no `configurar.sh`, fora desta frente (FR-002).

## Correções aplicadas

- [x] Constituição passa no pre-flight do `/feature-00c`: bloco `## Core Principles` e rodapé
  `**Version**: 1.0.0` (achado da conferência manual; nenhuma camada o apontou).
- [x] Hotfix nasce de `BRANCH_PRODUCAO` e abre PR com essa base; Princípio II, rito e ciclo git
  alinhados à skill `rito-dev`.
- [x] "Trilha curta" trocada por "trilha Docs"; a constituição é sempre trilha completa.
- [x] "Nenhuma PR MUST ser mergeada" corrigido para "MUST NOT"; relação squash/título invertida
  corrigida no `CICLO-GIT.md`.
- [x] Worktree antes de editar (não só antes do commit), com o comando `/parallel-work`.
- [x] Gates da skill `rito-dev` que faltavam: promover sem smoke é proibido; checar PR de promoção
  existente; conferir o alvo de deploy manual.
- [x] Título do Princípio III neutro, coerente com `ligado` e `desligado`.
- [x] Princípio IV sem contradição entre "não embute" e o aviso de licença de cópias.
- [x] Princípio VIII com a regra central como MUST.
- [x] Constituição cita o no-op de promoção quando integração e produção coincidem.
- [x] `BOARD` vazio não deixa rótulo solto (`CLAUDE.md` e triador apontam para o
  `project-context.md`).
- [x] Conferência de sincronia da base falha de fato (exit diferente de 0) quando diverge ou o
  `gh api` não responde.
- [x] Cenário 15: ordem dos princípios, `## Core Principles`, seção de princípios próprios, rodapé
  de versão, `--atualizar`, variação `PRINCIPIO_III=desligado` com branch única e guarda de
  diretório antes do `! grep`.
- [x] Cenário 15 mantido antes do 11: o 11 (qualidade estática) já fica por último por convenção
  do harness (12, 13 e 14 também vêm antes dele). Sem mudança.

## Adiado

- [x] `gh pr merge --squash --delete-branch` falha quando a branch está em uso numa worktree. O
  texto vem da skill `rito-dev`, que tem o mesmo comando; a correção vai para a skill, não para o
  template.

## Descartados

- Valores do `cockpit.config` com caracteres de shell ou Markdown: vêm do próprio owner; o
  configurador valida nomes de branch e o gate OWASP (dec-015) aceitou o risco.
- E-mail não-noreply versionado nos docs: o configurador já avisa; risco aceito no gate OWASP.
- `{{` dentro de um valor aparece como resíduo falso no teste: só com config atípica.
- Ausência do Princípio I: intencional pela spec (o I é o agnosticismo do próprio cockpit).
- "Imagens" contra "nunca pela extensão": mesma redação da constituição do cockpit.
- `REPO_REMOTO` como URL: o formato `dono/repo` é o que o configurador pede.

## Verificação

- `bash scripts/testar-configurar.sh` → `OK: todos os cenários passaram.` (shellcheck ausente
  nesta máquina; coberto no CI).
- `bash scripts/verificar-agnostico.sh` → `Agnosticismo: OK — nenhuma ocorrência de termo
  proibido.` A lista local está vazia; a lista secreta do CI só roda na PR.
- `configurar.sh` idêntico ao da `main`.
