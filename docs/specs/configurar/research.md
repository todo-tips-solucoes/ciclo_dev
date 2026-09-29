# Research: configurar

**Feature**: `configurar` | **Date**: 2026-09-28 | **Spec**: [spec.md](./spec.md)

Nenhum `NEEDS CLARIFICATION` estrutural: linguagem (bash), dependências
(`git`, `gh`, `node`, `jq`, `curl`), plataforma (Linux/WSL/macOS) e tipo de
entrega (script local) já estão fixados pela constituição (Princípio VII) e
pelo briefing (§Stack). As decisões abaixo são de implementação dentro dessa
stack.

---

## Decision 1: Motor de render — `awk` com `index()`/`substr()`, valores via `ENVIRON`

**Decision**: o render percorre cada linha do template com `awk`, localiza
`{{CHAVE}}` com `match()` sobre `\{\{[A-Z][A-Z0-9_]*\}\}` e monta a saída por
concatenação de `substr()`. O valor de cada chave chega ao `awk` por
`ENVIRON["CFG_<CHAVE>"]`, nunca por `-v` nem por `gsub()`.

**Rationale**: FR-011 exige valor literal com `/`, `&`, aspas, `$` e `\`.
`gsub()` trata `&` como "texto casado"; `-v` interpreta escapes com `\`; a
substituição de parâmetro do bash (`${s//pat/rep}`) muda de semântica entre o
bash 3.2 do macOS e o bash 5.2 (`patsub_replacement` trata `&` como especial).
Concatenar `substr()` não reinterpreta nada. `awk` é utilitário base das três
plataformas — mesma classe de `grep`/`tr`/`cut` que `instalar.sh` já usa.

**Alternatives considered**:
- `sed s///` — exige escapar o valor para o delimitador e para `&`; frágil.
- `node -e` — dependência permitida, mas um processo `node` por arquivo para
  algo que `awk` faz em uma linha é peso sem ganho.
- Engine de template — o briefing fixa "render por substituição literal, sem
  engine".

**Consequência conhecida**: `awk` sempre termina a última linha com `\n`. Um
template sem quebra final ganha uma. É determinístico, logo não quebra a
idempotência (FR-006); fica registrado no contrato.

---

## Decision 2: Leitura do `cockpit.config` sem `source`

**Decision**: o configurador lê `cockpit.config` (e o arquivo de respostas,
mesmo formato) linha a linha: ignora vazias e `#`, separa no primeiro `=`,
remove um par envolvente de aspas simples ou duplas, tolera CRLF. Chave fora
de `[A-Z][A-Z0-9_]*` é erro de formato.

**Rationale**: o arquivo é do projeto-alvo, e `source` executaria qualquer
coisa escrita nele. É o mesmo padrão de `ler_cstk_min` em `instalar.sh`
(sem `source`, tolerante a CRLF/aspas). `cockpit.config.example` hoje tem
valores sem aspas com espaço (`CMD_TYPECHECK=npm run typecheck`) — a leitura
precisa aceitar essa forma.

**Alternatives considered**: `source` em subshell — ainda executa comandos.

---

## Decision 3: Escrita do `cockpit.config` com aspas simples

**Decision**: cada linha é gravada como `CHAVE='valor'`, com `'` interno
escapado como `'\''`. Ordem fixa das chaves (a do data-model), cabeçalho de
comentário fixo, sem timestamp.

**Rationale**: FR-002 exige "legível por `source` em bash puro"; o formato sem
aspas do exemplo atual não é (`CMD_TYPECHECK=npm run typecheck` executaria
`run`). Aspas simples são a única forma POSIX sem expansão. Ordem fixa e
ausência de timestamp tornam a saída byte a byte idêntica entre execuções
(FR-006, SC-002). `cockpit.config.example` passa a usar a mesma forma com
aspas (a leitura da Decision 2 aceita as duas).

**Alternatives considered**: `printf %q` — saída varia entre bash 3.2 e 5.x
(`$'...'`), quebrando a idempotência entre máquinas.

---

## Decision 4: Chaves novas — `IDENTIDADES`, `BOARD`, `PRINCIPIO_III`

**Decision**:
- `IDENTIDADES='nome1:email1;nome2:email2'` — obrigatória para o configurador,
  opcional para `rito-dev` (retrocompatível, FR-003).
- `BOARD=''` quando o projeto não usa board; senão o identificador informado
  (texto livre não vazio, sem validação de formato — os templates que o
  consomem chegam no item 5 do MVP).
- `PRINCIPIO_III='ligado'|'desligado'`, padrão `ligado` (briefing §Decisões
  explícitas: "ligado por padrão e desligável").

**Rationale**: formato de `IDENTIDADES` e de `BOARD` vêm da clarificação Q3
(dec-012, resposta humana). O nome `PRINCIPIO_III` segue a convenção
`MAIÚSCULAS_COM_SUBLINHADO` das chaves existentes; valores por extenso em
português em vez de `true/false` (Princípio VI).

**Alternatives considered**: `PRINCIPIO_III_LIGADO=sim|nao` — mais longo, sem
ganho.

---

## Decision 5: FR-018 — nome e e-mail perguntados separadamente, gravação `nome:email` [RATIFICADA pelo owner em 2026-09-29]

**Status**: **Ratificada pelo owner na revisão da PR #3 (2026-09-29)**, pela
alternativa: nome e e-mail perguntados separadamente. O aviso (sem recusa)
para e-mail que não é `noreply` também foi confirmado (CHK025). O texto
abaixo registra a proposta original da onda-003, substituída por esta
decisão.

**Decisão ratificada**: para cada identidade, a pergunta pede o nome e, em
seguida, o e-mail; nome vazio encerra a lista (ou mantém as atuais, se nada
foi informado); mínimo uma. Gravação inalterada: `nome:email` unidos por `;`
em `IDENTIDADES`. A mudança ficou restrita à função `perguntar_identidades`.

**Proposta**: a pergunta pede uma identidade por vez no formato
`nome <email>` (o mesmo de `git var GIT_AUTHOR_IDENT` e da tabela do
Princípio III da constituição); resposta vazia encerra a lista; mínimo uma. O
configurador converte cada uma para `nome:email` e junta com `;` em
`IDENTIDADES` (formato de dec-012). No arquivo de respostas, `IDENTIDADES` já
vem no formato gravado. Validação: nome sem `:`, `;`, `<`, `>`; e-mail com
um `@`, sem espaço, `:` ou `;`. E-mail que não termina em
`@users.noreply.github.com` gera aviso, nunca recusa.

**Por que é só proposta**: a clarificação Q3 fixou o formato gravado; a
forma da pergunta (`nome <email>`) vem do texto de FR-018 e não foi
confirmada pelo owner como a interface desejada. Alternativa que o owner pode
preferir: perguntar nome e e-mail separadamente.

---

## Decision 6: Manifesto de hashes em `.cockpit/manifesto.sha256`

**Decision**: após cada render bem-sucedido, grava
`<projeto>/.cockpit/manifesto.sha256` no formato de `sha256sum`
(`<hash>  <caminho relativo>`), ordenado por caminho. Hash via `sha256sum`
quando existe, senão `shasum -a 256` (macOS).

**Regra de sobrescrita** (FR-007): para cada saída, se o arquivo de destino
existe e (a) não está no manifesto ou (b) o hash atual difere do registrado,
e o conteúdo novo difere do atual, é "editado à mão": o configurador lista
e não sobrescreve sem `--forcar` (modo não interativo) ou confirmação `s/N`
(interativo). Destino idêntico ao conteúdo novo nunca é conflito.

**Rationale**: clarificação Q1 (dec-007). Formato `sha256sum` é legível e
verificável à mão. `.cockpit/` agrupa os metadados do cockpit no projeto-alvo
em um único diretório.

---

## Decision 7: Atomicidade — render em temporários, depois `mv`

**Decision**: todos os templates são renderizados para arquivos temporários
criados com `mktemp` **no diretório de destino** (mesmo filesystem). Só
depois que nenhum tem placeholder residual e nenhum conflito de edição foi
recusado, cada temporário é movido com `mv -f` para o destino. `trap` em
`EXIT INT TERM` remove temporários restantes. `cockpit.config` e o
manifesto seguem o mesmo padrão.

**Rationale**: FR-010 ("nenhum arquivo com placeholder residual permanece")
e FR-017 (sem arquivo truncado). `mv` no mesmo filesystem é `rename(2)`,
atômico.

---

## Decision 8: Contenção de caminho

**Decision**: a raiz do projeto é resolvida com `cd <dir> && pwd -P` e MUST
ser o topo de um repositório git (`git -C <dir> rev-parse --show-toplevel`
igual ao caminho resolvido). Templates são listados com
`find templates -type f` (links simbólicos ficam de fora). Cada caminho
relativo com componente `..` é recusado; o diretório pai de cada destino é
criado com `mkdir -p` e resolvido com `pwd -P`, que MUST começar pela raiz do
projeto; destino que já é link simbólico é recusado.

**Rationale**: FR-015, SC-007, Edge Cases de escape por `..` e link
simbólico. `pwd -P` existe nas três plataformas (ao contrário de
`realpath`/`readlink -f` no macOS antigo).

---

## Decision 9: Sufixo `.tmpl` removido no destino

**Decision**: `templates/<rel>.tmpl` renderiza para `<projeto>/<rel>`;
arquivo sem `.tmpl` renderiza para o mesmo `<rel>`.

**Rationale**: a constituição já nomeia o template futuro como
`templates/docs/constitution.md.tmpl` (nota de abertura). Sem o sufixo, o
CI do cockpit trataria os templates `.sh` e `.yml` do item 5 como arquivos
do próprio cockpit (shellcheck, actions). Uma linha: `${rel%.tmpl}`.

---

## Decision 10: Checagem e provisionamento do `cstk` — reuso de `instalar.sh`

**Decision**: `versao_ge` e `ler_cstk_min` saem de `instalar.sh` para
`scripts/lib/versao.sh`, carregado por `source` pelos dois scripts. No fim,
o configurador: `command -v cstk` → `cstk --version` → extrai `x.y.z` →
compara com `CSTK_MIN`. Falha em qualquer passo: imprime o comando oficial
de instalação/atualização (o mesmo texto de `instalar.sh`) e sai com exit 3,
mantendo config e templates (FR-014). Sucesso: roda
`cstk hooks install --project-path <raiz>`.

**Fonte do comportamento do `cstk`** (Princípio V): saída observada de
`cstk hooks --help` em `cstk v10.8.0` nesta máquina (2026-09-28): "cstk hooks
install [--project-path PATH] ... Copia pretooluse-bash-guard.sh +
posttooluse-tool-call-tick.sh + posttooluse-agent-usage.sh para
<PATH>/.claude/hooks/ e mescla o bloco de registro em
<PATH>/.claude/settings.json" e "Idempotente como o fluxo padrao". O link da
documentação oficial (repositório `JotJunior/cstk`, o mesmo de
`CSTK_INSTALL_URL` em `instalar.sh`) MUST ser lido via `context-mode` e
registrado na implementação.

**Registro da fonte (2026-09-28, execução de `execute-task`)**: a leitura
da documentação **publicada** do repositório `JotJunior/cstk` **não foi
possível** — o `bash-guard` da execução autônoma bloqueou o domínio
(`raw.githubusercontent.com` fora da whitelist) e o subagente não dispunha
das ferramentas `context-mode`. Fontes efetivamente lidas, ambas da própria
distribuição oficial instalada (`cstk v10.8.0`, `~/.local/share/cstk/VERSION`):
(1) `cstk hooks --help` — confirma `cstk hooks install [--project-path PATH]`,
cópia dos 3 hooks para `<PATH>/.claude/hooks/` e mescla do registro em
`<PATH>/.claude/settings.json`, comportamento idempotente; (2)
`~/.local/share/cstk/lib/setup.sh` — o próprio `cstk` invoca e documenta
`cstk hooks install --project-path <raiz>` na mensagem de remediação.
Comportamento observado (execução real num repositório git temporário: exit
0, 3 hooks provisionados, `settings.json` criado) **coincide** com o `--help`;
`provisionar_hooks` e o contrato não precisaram de ajuste. ~~Pendência aberta (CHK023)~~ — atendida em 2026-09-29, abaixo.

**Registro da fonte oficial (2026-09-29, revisão da PR #3)**: documentação
publicada do repositório oficial https://github.com/JotJunior/cstk (indicado
pelo owner), `README.pt-BR.md`, seção "Hooks do runtime 00c (`cstk hooks`)",
lida via `gh api` no commit `561552a` do branch `main`. Confirma:
`cstk hooks install --project-path ../outro-projeto` como forma documentada;
o comando "toca só `.claude/hooks/` + `settings.json`"; é idempotente; sem TTY
e sem `--remove-classic`, um bloco clássico duplicado é **mantido** com aviso
("o `settings.json` é do operador e nunca é reescrito sem consentimento
explícito") — o `configurar.sh` chama o `cstk` com stdin fechado, então nunca
fica preso num prompt; e "Rode `cstk hooks install` de novo após todo upgrade
do cstk que toque os hooks" — o que `./configurar.sh --atualizar` faz. A doc
também oferece `--local` (registro em `settings.local.json`) para repositórios
cujo `.claude/settings.json` é versionado pelo time: não é usado por padrão
nesta frente. Nada diverge do comportamento implementado.

**Rationale**: um único lugar para comparar versão e ler o piso (Princípio
IV: o número só existe em `versoes.env`). Extrair duas funções é menor que
duplicá-las.

**Alternatives considered**: duplicar as funções — dois lugares para o mesmo
bug.

---

## Decision 11: Teste — `scripts/testar-configurar.sh` + job de CI

**Decision**: um script de teste em bash cria repositórios git temporários,
põe um `cstk` falso no `PATH` (imprime a versão de `versoes.env` e registra
os argumentos) e exercita os cenários do [quickstart](./quickstart.md):
config do exemplo, idempotência byte a byte, placeholder residual,
caracteres especiais, escape de caminho, edição à mão, `--atualizar` sem
config, `cstk` ausente. O `ci.yml` ganha um job `configurar` que o roda.

**Rationale**: briefing §MVP item 6 exige "render de todos os templates com a
config de exemplo" no CI; SC-002..SC-007 precisam de verificação executável.
Sem framework — o repositório não tem nenhum.
