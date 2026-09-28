# Quickstart: Skills do cockpit + alinhamento do briefing

Cenários manuais que validam a implementação end-to-end. Feature single-layer
(scripts + skills + documentação estática) — nenhuma borda backend↔frontend;
o cenário de Roundtrip do template não se aplica (research.md, feature não
tem API própria).

## Scenario 1: Rito-dev lê parâmetros de dois projetos-alvo diferentes (US1, P1)

1. Preencher `cockpit.config` num diretório fictício A a partir de
   `cockpit.config.example`, com `BRANCH_INTEGRACAO=staging`,
   `BRANCH_PRODUCAO=main`, `REPO_REMOTO=org-a/repo-a`.
2. Preencher outro `cockpit.config` num diretório fictício B, com
   `BRANCH_INTEGRACAO=main`, `BRANCH_PRODUCAO=main` (caso "integração =
   produção"), `REPO_REMOTO=org-b/repo-b`.
3. Invocar a skill `rito-dev` a partir do diretório A; pedir para ela citar a
   branch de integração e o repositório remoto.
4. Repetir a partir do diretório B.
5. **Expected**: a execução em A cita `staging`/`org-a/repo-a`; a execução em
   B cita `main`/`org-b/repo-b` e trata o caso de branch única sem erro nem
   fase duplicada. Nenhum valor de A aparece na execução de B.

## Scenario 2: `cockpit.config` com chave obrigatória faltando (Edge Case)

1. Copiar `cockpit.config.example` para um projeto-alvo fictício.
2. Apagar a linha `CMD_BUILD=...`.
3. Invocar a skill `rito-dev` (qualquer fase que cite comando de build, ex:
   Fase 2).
4. **Expected**: a skill nomeia exatamente `CMD_BUILD` como a chave ausente e
   para — nunca segue com um comando presumido (ex: `npm run build` por
   inferência).

## Scenario 3: Instalação copia as três skills (US1/US2/US3, SC-001)

1. Num clone limpo do cockpit com `skills/parallel-work/`,
   `skills/rito-dev/` e `skills/bmad-code-review/` presentes, rodar
   `instalar.sh` (feature `esqueleto-e-instalador`, já entregue) num
   `$HOME` de teste.
2. **Expected**: as três skills aparecem em `~/.claude/skills/`, e o
   relatório final de `instalar.sh` não reporta o diretório de skills como
   ausente (regressão do estado atual, onde `skills/` não existe).

## Scenario 4: Proveniência de `bmad-code-review` é auditável (US3, P3)

1. Abrir `THIRD-PARTY-NOTICES.md` na raiz do cockpit.
2. Localizar a entrada de `bmad-code-review`.
3. **Expected**: a entrada cita o projeto de origem (BMAD-METHOD,
   `bmad-code-org/BMAD-METHOD`), a licença (MIT) e reproduz o texto integral
   do arquivo `LICENSE` oficial — inclusive a nota de marca registrada — sem
   paráfrase.

## Scenario 5: Agnosticismo (US1/US2/US3, SC-002) — error case

1. Rodar `scripts/verificar-agnostico.sh` sobre o repositório inteiro após
   esta feature ser implementada.
2. **Expected**: 0 ocorrências proibidas — incluindo dentro de
   `skills/rito-dev/SKILL.md`, `skills/parallel-work/SKILL.md`,
   `cockpit.config.example` e `THIRD-PARTY-NOTICES.md`.

## Scenario 6: Briefing e constitution não divergem (US4, P4, SC-004)

1. Ler o item 1 do MVP em `docs/briefing.md` lado a lado com o Princípio IV
   (emenda 1.1.0) de `docs/constitution.md`.
2. **Expected**: os dois descrevem o mesmo comportamento do instalador
   (verifica e imprime; nunca instala/atualiza terceiro por conta própria) —
   nenhuma frase remanescente do texto anterior ("instala o `cstk` pelo
   one-liner oficial quando falta e o atualiza... `cstk self-update`").

## Scenario 7: Registro da exceção de merge da PR #1 é navegável (US4, SC-005)

1. Dentro de `docs/` (sem rodar `git log`), procurar o registro da exceção de
   merge por commit da PR #1.
2. **Expected**: o registro existe em local navegável dentro de `docs/`
   (ex: `docs/specs/esqueleto-e-instalador/` ou changelog dedicado), citando
   que foi uma exceção aceita explicitamente pelo owner, sem alterar a regra
   de merge por squash do Fluxo de Trabalho.
