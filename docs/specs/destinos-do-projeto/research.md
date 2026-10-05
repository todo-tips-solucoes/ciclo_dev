# Research: destinos do projeto no configurar.sh

**Feature**: `destinos-do-projeto` | **Date**: 2026-10-05 | **Spec**: [spec.md](spec.md)

Fonte do QUÊ: [spec.md](spec.md) e [decisoes-do-owner.md](decisoes-do-owner.md) (D1, D2 e D3,
fechadas). Aqui só se decide o COMO. Referências de código são de `configurar.sh` no commit
`3599598` (base desta frente).

Fontes de comportamento do git (Princípio V): manual oficial instalado com o git, lido com
`git help <comando>` (git 2.55.0), mesmo texto publicado em
<https://git-scm.com/docs/git-rev-parse>, <https://git-scm.com/docs/git-check-ignore> e
<https://git-scm.com/docs/git-worktree>. Cada afirmação abaixo também foi conferida numa sonda
local (repositório temporário com worktree vinculada e com repositório bare).

## Decision 1: um motivo por destino em `PULAR`, em vez de arrays novos

**Decision**: `PULAR[i]` deixa de ser 0/1 e passa a guardar o motivo de não renderizar: vazio
(renderiza, como hoje), `semente`, `projeto`, `copia` ou `ignorado`. Um array paralelo novo,
`ORIGEM[i]`, guarda o caminho na árvore principal (origem da cópia, ou caminho esperado para o
relatório). As checagens `[ "${PULAR[i]}" != 1 ]` (render, conflito, laço de contenção em
`main`) viram `[ -z "${PULAR[i]}" ]`, e `[ "${PULAR[i]}" = 1 ]` (gravação e `gravar_manifesto`)
vira `[ -n "${PULAR[i]}" ]`.

**Rationale**: todo destino listado, semente existente, copiado ou ignorado tem o mesmo
tratamento nos laços de render, conflito e manifesto (não renderiza, não compara, mantém a
linha anterior do manifesto). Só o relatório e a gravação distinguem os motivos. Um único
campo evita estado redundante (dois arrays que precisariam concordar).

**Alternatives considered**: arrays `PROJETO[i]`/`COPIA[i]` ao lado de `PULAR` 0/1, rejeitado
porque `PULAR=1` passaria a ser derivável dos outros e poderia divergir deles.

## Decision 2: validação dos itens em `validar_chave`

**Decision**: novo ramo `DESTINOS_DO_PROJETO)` em `validar_chave`, que já roda antes de
qualquer escrita (`validar_todos` em `main`, antes de `gravar_config`). Itens separados com
`read -ra itens <<<"$v"` (mesmo idioma de `DONOS_CODEOWNERS`, sem expansão de glob). Recusa,
citando a chave e o item:

- caractere de controle: já coberto por `tem_controle` no topo de `validar_chave` (a mensagem
  existente cita a chave); TAB também cai aqui;
- item composto só de aspas (`""`, `''`): todo caractere do item é `'` ou `"` (dec-006);
- item absoluto: começa com `/`;
- item com `..`: componente `..`, pelo mesmo padrão `case "/$item/" in */../*)` que
  `preparar_templates` usa para caminho de template.

O casamento com o destino de algum template só é possível depois de `preparar_templates`, então
fica em `classificar_destinos` (Decision 5): item que não é igual a nenhum `DEST_REL[i]` gera
`aviso`, nunca erro (FR-006). Comparação exata, com diferença de maiúsculas.

**Rationale**: a fronteira de confiança já existe e já recusa antes de gravar; reusar
`tem_controle` mantém uma regra só para caractere de controle. `..` como componente casa com a
regra de templates do próprio script, então as duas guardas de caminho ficam iguais.

**Alternatives considered**: recusar qualquer item que contenha a substring `..`, rejeitado
porque recusaria nome legítimo como `notas..md` sem ganho de contenção (nenhum destino de
template tem componente `..`, e a lista só restringe escrita, nunca cria caminho novo);
normalizar `./x` para `x`, rejeitado porque a spec exige igualdade com o destino (o item vira
aviso).

## Decision 3: valor em branco equivale a chave não declarada

**Decision**: em `validar_todos`, a regra "opcional vazia = ausente" (`desetar`) passa a valer
também para `DESTINOS_DO_PROJETO` composta só de espaços. Assim o `cockpit.config` regravado
fica idêntico ao de quem nunca declarou a chave. TAB não é espaço aqui: segue para
`validar_chave` e é recusado como controle.

**Rationale**: o Edge Case da spec diz que valor em branco equivale a chave não declarada; sem
isso `gravar_config` gravaria `DESTINOS_DO_PROJETO='   '`.

**Alternatives considered**: aplicar "só espaços = vazio" a todas as opcionais, rejeitado porque
mudaria o comportamento atual das URLs (hoje `'  '` é recusado como URL inválida), fora do escopo.

## Decision 4: posição da chave e efeito no modo interativo

**Decision**: `DESTINOS_DO_PROJETO` entra no fim de `CHAVES_ORDEM` (última linha gravada, última
pergunta) e em `CHAVES_OPCIONAIS`. Pergunta em `perguntar_chave`:
`perguntar DESTINOS_DO_PROJETO "Destinos mantidos pelo projeto (caminhos separados por espaço)"`;
a dica `(- para vazio)` já vem de `perguntar` para toda opcional.

**Rationale**: no fim, nenhuma pergunta existente muda de posição. Ser perguntada no modo
interativo é exigência de D1/FR-007, então a configuração mínima passa de 18 para 19 respostas:
o cenário 14 de `scripts/testar-configurar.sh` (que fixa 18, SC-001 da feature `configurar`)
ganha uma resposta em cada entrada e passa a fixar 19. Com config incompleto, o laço
`for k in $CHAVES_OPCIONAIS` de `main` também pergunta a chave nova se ela não estiver definida.

**Alternatives considered**: perguntar só quando já existe no config, rejeitado porque contraria
D1 ("é perguntada no modo interativo").

## Decision 5: classificação de cada destino, uma vez por execução

**Decision**: `marcar_sementes` passa a se chamar `classificar_destinos` (uma chamada, em `main`,
logo após `preparar_templates`) e decide `PULAR[i]`/`ORIGEM[i]` nesta ordem:

1. listado em `DESTINOS_DO_PROJETO` → `projeto` (vale para semente também: listado vence);
2. senão, semente cujo destino existe (`-e` ou `-L`, regra atual) → `semente`;
3. senão → vazio (renderiza);
4. por cima de 1 e 3: se o destino é de semente ou listado, está ausente (`! -e` e `! -L`), o
   projeto é worktree vinculada (Decision 6) e o destino é ignorado pelo git (Decision 8) →
   `copia` (origem válida, Decision 9) ou `ignorado` (sem origem válida).

O relatório tem exatamente uma linha por destino pulado, a do motivo final.

**Rationale**: decidir uma vez, antes de `STG` e de qualquer escrita, é o desenho da
modo-semente (research dela, Decision 2). A precedência "listado vence semente" faz o relatório
seguir a FR-004 (todo listado sai como `mantido (projeto)`), e D3 só muda o que acontece com o
destino ausente.

**Alternatives considered**: reportar duas linhas para listado copiado (`mantido (projeto)` e
`copiado da árvore principal`), rejeitado por ser contraditório para quem lê.

## Decision 6: detecção de worktree vinculada

**Decision**: nova função `arvore_principal`, chamada uma vez em `classificar_destinos`. Compara
`git -C "$RAIZ" rev-parse --git-dir` com `--git-common-dir`, os dois resolvidos para caminho
físico com `cd` a partir de `$RAIZ` e `pwd -P`. Iguais (ou falha do git) → não é worktree
vinculada e D3 fica desligado (FR-011).

**Rationale**: o manual diz que o caminho de `--git-dir`, quando relativo, é relativo ao
diretório corrente, e que `--git-common-dir` mostra `$GIT_COMMON_DIR` se definido, senão
`$GIT_DIR`. A sonda confirmou: na árvore principal os dois saem `.git` (relativos); na worktree
vinculada saem absolutos e diferentes (`<principal>/.git/worktrees/<nome>` e
`<principal>/.git`). Resolver com `pwd -P` é o mesmo recurso de `destino_contido`.

**Alternatives considered**: opção de formato absoluto do `rev-parse`, rejeitada porque a
resolução com `cd`/`pwd -P` já existe no script e não depende de opção adicional.

## Decision 7: árvore principal e recusa de repositório bare

**Decision**: em `arvore_principal`, se vinculada, ler o primeiro registro de
`git -C "$RAIZ" worktree list --porcelain` (linhas até a primeira vazia). Aceito só se:

- a primeira linha é `worktree <caminho>` com caminho absoluto de diretório existente, sem
  caractere de controle (`tem_controle`, a mesma regra dos valores do config: o caminho é
  impresso no relatório e não pode levar sequência de terminal);
- o registro não tem a linha `bare`;
- confirmação: `git -C "<caminho>" rev-parse --git-dir`, resolvido como na Decision 6, é igual
  ao `--git-common-dir` resolvido da worktree.

Aceito → `PRINCIPAL=<caminho físico>`. Recusado → `PRINCIPAL=""` e um `aviso` com o motivo
(repositório bare ou árvore principal não confirmada); os destinos de D3 seguem como
`ignorado` sem origem (US4-4).

**Rationale**: o manual diz que a árvore principal é listada primeiro, que o primeiro atributo
de cada registro é sempre `worktree`, que linha vazia encerra o registro e que atributos
booleanos como `bare` só aparecem quando verdadeiros (sonda: o primeiro registro de um
repositório bare é `worktree <repo.git>` seguido de `bare`). Também diz que, numa worktree
vinculada, `$GIT_COMMON_DIR` aponta para o `$GIT_DIR` da árvore principal, o que fundamenta a
confirmação. Sem `-z`, o manual avisa que caminho com quebra de linha não é analisável; a
confirmação recusa esse caso (o caminho truncado não tem o `$GIT_DIR` esperado).

**Alternatives considered**: `--porcelain -z` com `read -d ''`, rejeitado porque a confirmação já
cobre o caso e mantém a leitura linha a linha; derivar a árvore principal do pai de
`--git-common-dir`, rejeitado porque D3 fixa a primeira entrada do `worktree list`.

## Decision 8: destino ignorado pelo git

**Decision**: `git -C "$RAIZ" check-ignore -q -- "<rel>"`, um caminho por chamada, só para
destinos candidatos (semente ou listado, ausente, em worktree vinculada). Só exit 0 conta como
ignorado; 1 (não ignorado) e 128 (erro) mantêm o comportamento atual.

**Rationale**: o manual diz que `-q` só vale com um único caminho e que o exit é 0 se algum
caminho é ignorado, 1 se nenhum, 128 em erro fatal; diz também que arquivo rastreado não é
afetado por regras de exclusão, então destino rastreado e apagado segue o caminho atual. A
sonda confirmou exit 0 para `CLAUDE.md` ausente coberto por `.gitignore` commitado e exit 1 para
caminho não coberto.

## Decision 9: a cópia

**Decision**: nova função `origem_valida REL` (só leitura), chamada por `classificar_destinos`.
Origem `"$PRINCIPAL/$REL"` aceita só se: é arquivo regular (`-f`) e não é link (`! -L`), e o pai
resolvido com `pwd -P` é igual ao pai lógico (`$PRINCIPAL` ou `$PRINCIPAL/<dirname>`), o que
recusa link em qualquer componente e garante que a origem está fisicamente dentro da árvore
principal. Origem com link → `aviso` com o motivo e `ignorado`; origem ausente → `ignorado`
(o relatório mostra o caminho esperado).

A cópia é feita no laço de gravação de `aplicar_templates`, depois das checagens de residual e
de conflito (exit 2 não deixa nada copiado): `exigir_contido`, `mkdir -p` do pai, `exigir_contido`
de novo (mesma sequência do render), `cp` da origem para `$STG/c$i` e `mv -f` para o destino.
Falha de cópia → `falhar` (exit 1, mesma linha "falha de escrita" do contrato). Em `main`, o laço
de `exigir_contido` antes de `STG` também cobre os destinos `copia`.

Manifesto: regra de destino pulado (Decision 1), isto é, linha anterior mantida se houver, nada
novo. Na 2ª execução o arquivo copiado já existe e cai em `semente` ou `projeto`.

**Rationale**: reusa as guardas de contenção e o staging que todo destino gravado já usa
(FR-009, FR-012). `cp` de arquivo regular produz arquivo regular; a árvore principal só é lida.

**Alternatives considered**: link simbólico para a árvore principal, recusado por D3; `cp -p`,
rejeitado porque a spec só pede cópia regular idêntica em conteúdo.

## Decision 10: testes

**Decision**: dois cenários novos em `scripts/testar-configurar.sh`, depois do 17 e antes do 11
(que roda por último): `18: destinos do projeto` (D1/D2) e `19: worktree e destino ignorado`
(D3). Cenário 14 ajustado (Decision 4) e o cenário 15 passa a recusar template que use
`DESTINOS_DO_PROJETO` (chave opcional ausente deixaria residual). No 19:

- commits com `git -c user.name=… -c user.email=… -c commit.gpgsign=false`, para não depender da
  configuração da máquina; `.gitignore` commitado (a worktree só o vê se estiver no commit);
- repositório bare criado sem rede: `cp -R <repo>/.git <bare>.git` e
  `git -C <bare>.git config core.bare true` (conferido na sonda), seguido de
  `git -C <bare>.git worktree add`.

**Rationale**: D1/D2 e D3 pedem um cenário cada, no estilo dos existentes (`novo_repo`,
`cockpit_copia`, `codigo`, `rodar`).

## Decision 11: documentação

**Decision**: `cockpit.config.example` ganha a seção da chave com `DESTINOS_DO_PROJETO=''` e o
exemplo de D1 em comentário. O valor fica vazio porque o exemplo é o arquivo de respostas dos
cenários 1 a 17; listar destinos ali mudaria o que eles geram. Atualizar também `uso()` (linha
do `--forcar`), o cabeçalho de `configurar.sh`, `docs/specs/configurar/contracts/cli.md` (delta
de [contracts/cli.md](contracts/cli.md)) e a tabela de chaves de
`docs/specs/configurar/data-model.md`. Nenhum template passa a usar `{{DESTINOS_DO_PROJETO}}`.

## Riscos aceitos

Revisão de segurança do desenho (gate `owasp-security`, 2026-10-05): nenhum achado crítico ou
alto. Limites que reduzem a superfície: a lista nunca vira caminho de escrita (só impede
escrita); só destinos de template (de `templates/`, já sem componente `..`) podem ser
copiados; toda chamada ao git usa `--` antes do caminho ou caminho absoluto; erro de qualquer
consulta ao git desliga a cópia (nunca a habilita).

- Entre `origem_valida` e o `cp`, a origem pode ser trocada por um link (corrida de tempo de
  checagem). A árvore principal é do próprio usuário e o efeito é ler um arquivo dele para
  dentro do projeto dele; não há escalada. Registrar o limite num comentário junto do `cp`.
- Destino com espaço no nome não pode ser listado (o espaço é o separador, D1). Nenhum
  template atual tem espaço no destino.
- Origem que é link físico (hard link) para arquivo fora da árvore principal passa como
  arquivo regular. Criá-lo exige acesso de escrita à árvore principal, isto é, ser o próprio
  usuário; fica registrado, sem mitigação.
- Troca de um diretório-pai do destino por link entre `exigir_contido` e `mv` já existe para
  todo destino renderizado; a cópia herda o mesmo limite, sem piorá-lo.
