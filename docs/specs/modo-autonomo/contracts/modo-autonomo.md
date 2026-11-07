# Contrato: modo autônomo no rito (D1, D2, D5 a D8)

> `[PROPOSTA — a validar na implementação]`: procedimento novo da seção "Modo autônomo" da skill
> `rito-dev` e do template do rito. Comando ou campo externo só aparece aqui com o item da
> [research](../research.md) que o confirma; o resto está marcado "a confirmar" e, até ser
> confirmado na fonte oficial durante a implementação (Princípio V), vale a falha fechada indicada.

## 1. Leitura do modo (D1, FR-003)

Depois da base conferida, nunca na worktree:

```bash
git show origin/<BRANCH_INTEGRACAO>:docs/constitution.md | tr -d '\r' | grep -cFx 'Merge autônomo: ligado'
git show origin/<BRANCH_INTEGRACAO>:docs/constitution.md | tr -d '\r' | grep -cE '^Merge autônomo: (ligado|desligado)$'
```

O `tr` tira o `\r` de constituição commitada com CRLF (rodada 3, B3-1), como no configurador e na
trava. Vale `ligado` só quando o 2º dá exatamente 1 e o 1º dá 1. Qualquer outro resultado vale
`desligado`. Escrita uma vez aqui; a `rito-descoberta` cita esta seção. Relida antes de cada merge
(Fase 7) e de cada promoção (Fase 9). O agente nunca edita a linha nem a chave.

## 2. Pré-condições do modo efetivo (D2, D5, FR-005)

Conferidas na hora, depois da leitura `ligado`. Qualquer uma que falhe, ou que não possa ser lida,
faz o modo valer `desligado` e o rito para no gate humano de hoje (US3 cenário 2).

| # | Conferência | Fonte |
|---|---|---|
| P1 | O usuário autenticado no `gh` não está entre os donos do CODEOWNERS | endpoint do usuário autenticado (a confirmar) e `.github/CODEOWNERS` da base |
| P2 | `permissions.admin` falso e `permissions.maintain` não verdadeiro no repositório | R15 |
| P3 | Regra `required_status_checks` ativa na branch de integração com os contextos `ci`, `commitlint` e `caminhos-previstos` e, quando integração ≠ produção, na branch de produção com o contexto `caminhos-previstos-producao` (A1, block-001; D-P11) | R3, `GET /repos/{owner}/{repo}/rules/branches/{branch}`, uma chamada por branch |
| P4 | `current_user_can_bypass` igual a `never` em cada ruleset que alcança a integração e, quando integração ≠ produção, a produção (a identidade não enxerga `bypass_actors`); a lista de bypass vazia é conferida pelo owner (D-P7) | R3 |
| P5 | Auto-merge permitido no repositório | a confirmar (campo da configuração do repositório) |

Escopo mínimo do `TOKEN_AUTOMACAO` (A2, spec FR-019): escrita só em Contents e Pull requests, sem
Administration nem Workflows, restrito a este repositório, identidade fora do CODEOWNERS. Fonte da
conferência de "sem bypass" (P4): `GET /repos/{owner}/{repo}/rules/branches/{branch}` e
`current_user_can_bypass` (<https://docs.github.com/en/rest/repos/rules>, research R3).

A falta de Administration e de Workflows na credencial não é verificável por API com fonte
encontrada: o configurador imprime as permissões exigidas e o S3 prova as recusas (push direto,
`--admin`, push de workflow, status forjado). O status forjado é recusado por permissão: criar
status exige "Commit statuses" (R13), que a identidade não tem.

## 3. Merge (Fase 7, D5, FR-012)

```bash
gh pr merge <n> --auto --squash
```

(R14: `--auto` "Automatically merge only after necessary requirements are met"; `--squash`.)

- Só depois de §1 e §2, e com os itens de smoke elegíveis (§6).
- Antes de armar: o status `caminhos-previstos` mais recente do commit atual da PR (`GET
  /repos/{owner}/{repo}/commits/{ref}/statuses`: "The first status in the list will be the latest
  one", <https://docs.github.com/en/rest/commits/statuses>) é `success` com descrição diferente de
  `modo desligado`. Ausente, outro estado ou `modo desligado` (status de antes de o modo ligar): não
  arma e volta ao owner.
- Nunca `--admin`. Camada extra: regra `permissions.deny` para o `--admin` na worktree:
  `Bash(gh pr merge *--admin*)` e `Bash(gh * pr merge *--admin*)` (sintaxe conferida, dec-047,
  <https://code.claude.com/docs/en/permissions>; o efeito de bloquear é não medido até o caso
  `--admin` do S3).
- Nunca `--delete-branch`: a branch é apagada pela configuração do repositório (impressa pelo
  configurador).
- O `headRefOid` vem de `gh pr view --json` (campo listado em "JSON Fields",
  <https://cli.github.com/manual/gh_pr_view>, R18).
- A trava exige aprovação de dono em: PR sem registro (docs, trivial, hotfix); PR de governança;
  PR para a produção que não é a de promoção; PR de outro repositório (fork); correção ou revert
  com manifesto ou lockfile (contrato [caminhos-previstos.md](caminhos-previstos.md), passo 7).
  A aprovação de dono não libera arquivo fora do bloco nem as outras falhas diretas da trava
  (mesmo contrato, "Ordem"): elas falham mesmo aprovadas (A3-2).
- Leitura `desligado` (§1 ou §2): o agente desarma cada PR de frente dele aberta com o auto-merge
  armado, com `gh pr merge <n> --disable-auto` ("Disable auto-merge for this pull request", R14), e
  segue no gate humano.
- Leitura diferente da anterior (troca de modo, em qualquer sentido): o agente avisa o owner para
  reexecutar a trava e o `require-codeowner-approval` em cada PR aberta, porque os status delas
  saíram do modo antigo (A3-7).

## 4. CI vermelho antes do merge (D6, FR-014)

- Conta SHAs distintos do PR com o check `ci` em falha; rerun do mesmo SHA não conta (consulta por
  SHA na API de checks, campos a confirmar).
- Até 2 correções por commit na mesma branch.
- No 3º vermelho:
  - `gh pr merge <n> --disable-auto` (R14);
  - `gh pr ready <n> --undo` (R12, "If supported by your plan"; sem suporte, o rótulo basta);
  - rótulo `estacionada` (R12: "Pull requests" write basta para rotular);
  - diagnóstico e recomendação ao owner.

## 5. Smoke falho na integração (D6, FR-015, FR-016)

- Conta só se o run foi no merge commit da frente; outro SHA volta ao owner sem correção.
- Falha transitória: um único rerun do mesmo SHA antes de contar.
- Correção: PR nova a partir de `origin/<BRANCH_INTEGRACAO>`, fora da worktree da frente, com
  rótulo `correcao-<n>` e a linha `Origem: #<pr-da-frente>` no corpo. Contagem por
  `gh pr list --state all` filtrada pelo rótulo e pela linha. Branch remota existente é retomada,
  não recriada.
- 3ª falha: reverts um por vez, em ordem inversa (correções primeiro), cada um esperando o merge do
  anterior, com `gh pr revert <n>` (R7: existe; comportamento com squash a provar no S3) e
  `Origem: #<pr-da-frente>` no corpo. Revert com conflito ou CI vermelho para e volta ao owner, sem
  laço. A frente fica estacionada, worktree mantida, sem Fase 11.
- Revert que remove regras de `permissions.deny` ou toca governança (por exemplo, o
  `.claude/settings.json` da frente) cai na aprovação de dono (A2-7 da rodada 2): o agente abre,
  avisa o owner e espera a aprovação.
- Ambiente de integração inutilizável, afetando outras frentes: reverte primeiro, corrige depois.
- `gh pr revert` indisponível na versão instalada (R7, versão mínima não confirmada): para e volta
  ao owner.

## 6. Smoke da frente e elegibilidade (D7, FR-017)

- Itens `Sn | comando | esperado literal | tipo` do registro na base; `tipo` em `positivo`,
  `negativo` ou `manual`.
- Passa quando o stdout contém o esperado como substring literal e o exit é 0 (positivo) ou
  diferente de 0 (negativo).
- Sem item executável, ou sem ao menos um `negativo`: o merge fica no gate humano.
- Irreversibilidade diferente de "Nenhuma": merge autônomo na integração e parada no gate da
  promoção.

## 7. Promoção em lote (Fase 9, D8 com a emenda da rodada 2, FR-018, FR-019)

Dispara ao fim do smoke de cada frente mergeada (Clarifications, Q5). Sem `--auto`: o agente
mergeia direto em `X` (decisão do owner na rodada 2 do `bmad-code-review`).

1. Relê o modo (§1) e as pré-condições (§2) no repositório.
2. Lote = frentes na integração e não na produção. Fixa o SHA `X` da ponta da integração.
3. Smoke combinado em `X`, com resultado por frente.
4. Lote com frente irreversível ou item `manual`: para no gate humano.
5. PR de promoção pelo `promotion-pr` com `TOKEN_AUTOMACAO` (R6: PR criada com o `GITHUB_TOKEN`
   não dispara o CI). O workflow só cria e atualiza a PR; não arma o auto-merge. Sem o segredo no
   modo ligado, o workflow falha e o rito para. A PR de promoção passa sozinha na trava, que a
   reconhece pela cabeça = branch de integração do mesmo repositório (contrato
   [caminhos-previstos.md](caminhos-previstos.md) passo 2, A1 do block-001); qualquer outra PR
   para a produção exige aprovação de dono no commit atual.
6. Rollback anotado antes: SHA de `origin/<BRANCH_PRODUCAO>` pré-promoção, no corpo da PR, gravado
   pelo `promotion-pr` e recalculado a cada push na integração. O agente confere, com
   `gh pr view <n> --json headRefOid,body` (R18) e
   `gh api repos/<REPO_REMOTO>/branches/<BRANCH_PRODUCAO> --jq .commit.sha`:
   - a cabeça da PR é `X`; diferente, volta ao passo 2;
   - o SHA de rollback do corpo é a ponta atual de `origin/<BRANCH_PRODUCAO>` (A2-12); diferente,
     para e volta ao owner;
   - o repositório permite merge commit.
7. Espera os checks obrigatórios verdes com a cabeça em `X` (R18, <https://cli.github.com/manual/gh_pr_checks>):
   `gh pr checks <n> --required --watch --fail-fast` e, em seguida,
   `gh pr checks <n> --required --json bucket --jq '[.[].bucket] | length > 0 and all(. == "pass")'`,
   que precisa imprimir `true`; outro resultado para e volta ao owner. Não confirmado: se a lista
   do `--required` inclui commit status, como o `caminhos-previstos-producao` da trava (R18,
   Pendências). Se não incluir, a garantia desse check é o ruleset da produção, que recusa o merge
   sem ele (A3-4).
8. Mergeia: `gh pr merge <n> --merge --match-head-commit X` (R14). A recusa com outra cabeça vem
   do manual do `gh`: `--match-head-commit <SHA>` é o "Commit SHA that the pull request head must
   match to allow merge" (<https://cli.github.com/manual/gh_pr_merge>). O 409 do REST de merge
   ("409 Conflict if sha was provided and pull request head did not match",
   <https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request>) fica como referência: não há
   fonte que diga qual chamada o `gh` faz (A3-5). Merge com erro, qualquer que seja: o agente relê a
   cabeça (`gh pr view <n> --json headRefOid`); diferente de `X`, volta ao passo 2; igual, para e
   volta ao owner.

Integração = produção: a Fase 9 segue no-op e o rollback é o do §5. O `release.yml` pode gerar
versão a partir do rollback (§8; conferência, não afirmação). Ele roda o semantic-release com o
`TOKEN_AUTOMACAO` sobre config lida do repositório (R17): por isso essa config é governança na
trava, e o token é de GitHub App ou fine-grained de identidade não dona, só deste repositório,
nunca o token pessoal do owner (A2, block-001). O `release.yml` não muda.

## 8. Smoke em produção falho (Fase 10, D8, FR-020)

1. Revert da PR de promoção como contenção (mais o deploy manual, quando houver), com
   `gh pr revert` (R7; com merge commit a provar no S3), aberto na hora. O revert é PR para a
   produção que não é a de promoção: a trava exige aprovação de dono no commit atual (A1,
   block-001), e a contenção aguarda essa aprovação. O dono aprova no commit atual e reexecuta o
   workflow da trava ("Re-run", R10).
2. Revert da culpada na integração, pelo §5.
3. Owner avisado na hora, com diagnóstico e recomendação.
4. A próxima promoção começa com o revert do revert, para o resto do lote voltar à produção. Ele
   também é PR para a produção que não é a de promoção: o agente abre, avisa o owner e espera a
   aprovação de dono antes de promover (A2-7 da rodada 2).
5. Sem culpada isolável: reverte o lote.

Depois do merge do revert na produção, o agente confere se o `release.yml` gerou versão a partir
dele e informa o owner (sem fonte que diga o que o semantic-release faz com um commit de revert;
A2-11). Integração = produção: não há PR de promoção, e o rollback é o do §5.
