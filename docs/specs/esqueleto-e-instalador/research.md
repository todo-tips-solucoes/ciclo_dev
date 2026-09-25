# Research: Esqueleto do cockpit-dev e instalador de máquina

Documento produzido no Phase 0 do `/plan`. Resolve os `NEEDS CLARIFICATION` do
Technical Context antes do design.

> **Princípio V (Fonte Oficial Antes de Afirmar)**: toda afirmação sobre `cstk`,
> `context-mode`, `ponytail`, GitHub CLI ou Actions abaixo carrega a fonte de onde
> foi lida. Fatos marcados **MEDIDO** vêm de sonda empírica nesta máquina em
> 2026-09-25 (saída literal citada); fatos marcados **FONTE OFICIAL** vêm de
> documentação pública lida via `context-mode`. Nada aqui foi reconstruído de
> memória.
>
> **Cadeia de custódia das citações do README do `cstk`** (auditoria de veracidade
> desta onda): as frases entre aspas atribuídas a
> <https://raw.githubusercontent.com/JotJunior/cstk/main/README.md> foram lidas via
> `context-mode` por uma etapa de pesquisa delegada **dentro desta sessão**, e são
> reproduzidas aqui **conforme reportadas por ela** — não foram re-conferidas por
> leitura direta do orquestrador, que não dispõe de ferramenta de fetch. São,
> portanto, fonte oficial em **segunda mão**. O que depende dessas citações é
> apenas a *descrição de comportamento* de `cstk install`/`update`/`self-update`;
> os *nomes* dos subcomandos estão confirmados de forma independente por sonda
> local (`cstk --help`). Quem for implementar deve reconferir a página oficial
> antes de citá-la em outro artefato.

---

## Decision 1: Canal oficial de instalação do `cstk`

**Decision**: quando `cstk` não está presente na máquina, `instalar.sh` usa o
**instalador oficial** publicado nas releases do repositório `JotJunior/cstk` —
baixando-o para arquivo temporário e **só então** executando:

```sh
# Forma a implementar (endurecida na Phase 1 — ver §Superfície de Segurança do plan.md)
tmp=$(mktemp)
curl -fsSL https://github.com/JotJunior/cstk/releases/latest/download/install.sh -o "$tmp"
sh "$tmp"
```

> ⚠️ O README oficial publica este mesmo instalador como um one-liner canalizado
> direto para o shell (`curl -fsSL <url> | sh`). **Não copie essa forma**: a URL é
> a mesma e o canal continua sendo o oficial, mas canalizar para o shell faz um
> download truncado executar parcialmente. O endurecimento foi decidido no gate
> `owasp-security` da Phase 1 e é normativo — `plan.md` §Superfície de Segurança e
> `contracts/cli.md` registram a mesma regra.

O README declara, no próprio cabeçalho do bloco, que o instalador coloca o `cstk`
em `~/.local/bin/` — dentro da área que o Princípio VII autoriza (`~/.claude/` e
`~/.local/`).

**Rationale**: o Princípio IV proíbe reimplementar ou embutir o `cstk`; a
instalação tem que sair do canal oficial do próprio projeto. Reimplementar o
download (resolver release via API, baixar tarball, conferir `.sha256`) seria
reescrever à mão exatamente o que o `install.sh` oficial já faz — e passaria a
ser código do cockpit para manter quando o canal mudar.

**Fonte**: FONTE OFICIAL — <https://raw.githubusercontent.com/JotJunior/cstk/main/README.md>
(seção "Bootstrap one-liner (installs `cstk` into `~/.local/bin/`)").

**Alternatives considered**:

- *Reimplementar o download no `instalar.sh`* (resolver
  `https://api.github.com/repos/JotJunior/cstk/releases/latest`, baixar
  `cstk-<ver>.tar.gz` e verificar o `.sha256` irmão — mecânica MEDIDA em
  `~/.local/share/cstk/lib/self-update.sh:412,428`). Rejeitado: viola o
  Princípio IV (cópia em vez de dependência) e duplica lógica de verificação de
  integridade que já existe upstream.
- *Instalar via gerenciador de pacotes do sistema*. Rejeitado: não há pacote
  oficial; e o Princípio VII limita os pré-requisitos a `git`, `gh`, `node`,
  `jq` e `curl`.

---

## Decision 2: Ordem `self-update` → conferência do piso (nunca o inverso)

**Decision**: quando o `cstk` já existe, `instalar.sh` executa `cstk self-update`
**antes** de qualquer comparação com `CSTK_MIN`. A conferência do piso é a última
palavra sobre a versão, e só falha se, **depois** da atualização, a versão
instalada ainda ficar abaixo do piso.

**Rationale**: é literal no Princípio IV — *"O instalador MUST manter a máquina na
última release do `cstk` (`cstk self-update`, idempotente) e, só depois, MUST
falhar se `cstk --version` for menor que `CSTK_MIN`: o piso é o mínimo testado,
não o alvo."* Inverter a ordem faria uma máquina desatualizada falhar em vez de
se curar sozinha, que é o cenário 3 da User Story 1.

**Fonte**: `docs/constitution.md` §Princípio IV; `cstk self-update` documentado
como *"updates the cstk binary itself + cli/lib"* — FONTE OFICIAL,
<https://raw.githubusercontent.com/JotJunior/cstk/main/README.md>.

**Alternatives considered**:

- *Conferir o piso primeiro e só atualizar se estiver abaixo*. Rejeitado:
  contraria a redação MUST do Princípio IV e deixa a máquina fora da última
  release sempre que o piso já estiver satisfeito — exatamente a deriva que o
  cockpit existe para eliminar.

---

## Decision 3: `cstk self-update` e `cstk install/update` cobrem coisas diferentes

**Decision**: `instalar.sh` executa **os dois**, em papéis distintos e não
intercambiáveis:

| Comando | O que atualiza |
|---|---|
| `cstk self-update` | o binário `cstk` e o runtime `cli/lib/*.sh` |
| `cstk install` / `cstk update` | apenas o catálogo (skills, commands, agents em `~/.claude/`) |

**Rationale**: a distinção é explícita na documentação oficial — *"`install`/`update`
touch only the catalog (skills/commands/agents in `~/.claude/`); the runtime
(`cli/lib/*.sh` + binary) updates via `cstk self-update`."* Rodar só um dos dois
deixa metade da etapa de implementação do ciclo desatualizada, sem aviso — a
falha silenciosa que o briefing aponta como problema de origem.

Política concreta: `cstk install` na primeira execução (catálogo ausente) e
`cstk update` nas seguintes, atendendo FR-006 (instalar na primeira, atualizar nas
demais, de forma idempotente).

**Fonte**: FONTE OFICIAL — <https://raw.githubusercontent.com/JotJunior/cstk/main/README.md>.
Subcomandos confirmados também por sonda: MEDIDO, `cstk --help` lista
`install`, `update`, `self-update`, `list`, `doctor`, `hooks`, entre outros.

**Alternatives considered**:

- *Rodar apenas `cstk self-update`*. Rejeitado: não instala o catálogo de skills,
  então `/feature-00c` não existiria na máquina.
- *Rodar apenas `cstk install`*. Rejeitado: não atualiza o runtime, e o briefing
  registra que o contrato do `cstk` já mudou cinco vezes num mês.

---

## Decision 4: Comparação de versões em bash puro, sem `sort -V`

**Decision**: implementar uma função `versao_ge <instalada> <minima>` que compara
`MAJOR.MINOR.PATCH` campo a campo, numericamente, em bash puro — normalizando um
prefixo `v` opcional e tratando campos ausentes como `0`.

**Rationale**: uma comparação campo a campo são poucas linhas, não acrescenta
dependência nenhuma, é determinística e tem comportamento idêntico nos três
sistemas-alvo por construção — não depende de qual implementação de `sort` a
máquina tem. Como `instalar.sh` roda justamente numa máquina **ainda não
preparada**, quanto menos ele presumir sobre o ambiente, melhor.

> **SUPOSIÇÃO NÃO VERIFICADA** (Princípio V): existe a crença comum de que
> `sort -V` é extensão GNU e não está disponível de forma garantida no `sort` do
> macOS/BSD. **Não foi confirmada em fonte oficial** nesta frente e por isso *não*
> é usada como justificativa acima — o argumento se sustenta sem ela. Se alguém
> quiser adotar `sort -V` no futuro, essa suposição precisa ser verificada antes
> (man page do BSD `sort` ou documentação do coreutils), não assumida.

A função é usada em três lugares — piso do `cstk` (`CSTK_MIN`), `git >= 2.36` e
`node >= 20` — o que já justifica extraí-la uma vez em vez de repetir a
comparação.

**Alternatives considered**:

- *`sort -V`*. Rejeitado: portabilidade macOS não garantida.
- *Comparação lexicográfica de strings*. Rejeitado: incorreto — `10.8.0` sairia
  como menor que `9.0.0`. Esse é exatamente o caso vivo do projeto
  (`CSTK_MIN=10.8.0`).
- *Delegar a `node`*. Rejeitado: acopla a checagem de pré-requisito ao próprio
  `node`, que é um dos pré-requisitos sendo checados.

---

## Decision 5: `versoes.env` é lido, nunca reescrito; nenhum outro arquivo carrega o número

**Decision**: `instalar.sh` lê `CSTK_MIN` de `versoes.env` por `source`/parse no
início da execução e trabalha com a variável. Nenhum outro arquivo do repositório
— script, workflow de CI ou documento — escreve o literal `10.8.0`; todos se
referem à chave `CSTK_MIN`.

**Rationale**: literal no Princípio IV — *"O piso de versão do `cstk` MUST existir
em um único lugar, a chave `CSTK_MIN` de `versoes.env`; nenhum outro arquivo MUST
escrever o número."* O próprio `versoes.env` já documenta a regra no cabeçalho.
Duplicar o número é a forma mais barata de o piso derivar em silêncio.

**Consequência verificável**: uma ocorrência do literal fora de `versoes.env` é um
defeito detectável por busca — candidato natural a checagem de CI numa frente
futura (fora do escopo desta, cujo CI cobre shellcheck e agnosticismo).

**Alternatives considered**:

- *Repetir o piso no workflow de CI*. Rejeitado: viola o MUST diretamente.

---

## Decision 6: A varredura de agnosticismo enumera arquivos por `git ls-files`

**Decision**: `scripts/verificar-agnostico.sh` enumera os arquivos a varrer com
`git ls-files`, e não com `find` ou `grep -r`.

**Rationale**: três problemas se resolvem de uma vez, sem código extra —
(a) `.git/` fica fora automaticamente; (b) o que o `.gitignore` já exclui
(`.claude/`, `.render/`, `.mcp.json`) não é varrido, e portanto config local de
máquina nunca dispara falso positivo; (c) só arquivos versionados são checados,
que é exatamente o universo que a garantia do Princípio I cobre — "todo arquivo do
repositório". Um `grep -r` cru varreria `.git/`, artefatos locais e a área de
estado do `feature-00c`, produzindo ruído que não é vazamento.

**Alternatives considered**:

- *`grep -r` na raiz*. Rejeitado: varre `.git/` e artefatos locais ignorados.
- *`find` com lista de exclusões à mão*. Rejeitado: reimplementa o `.gitignore`,
  e a lista de exclusões passa a ser mais uma coisa para manter em sincronia.

---

## Decision 7: A lista proibida se auto-excluiria — exclusão explícita obrigatória

**Decision**: `scripts/agnostico.lista` é **excluído da própria varredura**, de
forma explícita e comentada no script.

**Rationale**: a lista contém, por definição, todos os termos proibidos. Sem a
exclusão, a varredura casaria contra o próprio arquivo de lista em toda execução e
falharia sempre — o cenário 1 da User Story 2 (repositório limpo, zero ocorrências)
seria impossível de atingir. É a armadilha central deste script e precisa estar
explícita no código, não descoberta na primeira execução.

**Escopo da exclusão**: apenas o arquivo de lista. Documentação que *cite* um termo
proibido continua sendo reportada — coerente com o Edge Case da spec, que decide
que a lista não distingue contexto educativo de vazamento real.

**Alternatives considered**:

- *Marcar ocorrências com um comentário de dispensa no próprio arquivo*.
  Rejeitado: cria um mecanismo de bypass geral para a garantia NON-NEGOTIABLE do
  Princípio I. Uma exclusão de um arquivo conhecido é menor e auditável.

---

## Decision 8: Formato da lista e semântica do casamento

**Decision**: `scripts/agnostico.lista` é texto simples — um termo por linha,
linhas começando com `#` são comentário, linhas em branco são ignoradas. O
casamento é por **substring literal, sem distinção de maiúsculas**
(`grep -i -F`), não por expressão regular.

**Rationale**: os termos são nomes próprios (projeto, cliente, organização,
domínio), que aparecem em capitalizações variadas e não são padrões. Casamento
literal elimina a classe inteira de bugs em que um termo com `.` ou `-` vira
metacaractere e a varredura passa a casar coisa demais ou de menos. O formato
"um por linha com `#`" é o mais simples que satisfaz FR-015 (editável sem tocar
no script).

**Alternatives considered**:

- *Expressões regulares por linha*. Rejeitado: poder desnecessário, e um termo
  mal escapado degrada silenciosamente a garantia.
- *JSON/YAML*. Rejeitado: acrescenta dependência de parser para uma lista de
  strings.

---

## Decision 9: `shellcheck` roda no CI, não é pré-requisito de máquina

**Decision**: a checagem de portabilidade de shell (FR-017) roda no workflow de CI.
`instalar.sh` **não** checa nem instala `shellcheck`.

**Rationale**: o Princípio VII fecha a lista de pré-requisitos em `git`, `gh`,
`node`, `jq` e `curl` — `shellcheck` não está nela, e acrescentá-lo exigiria
emenda da constituição. Além disso, MEDIDO nesta máquina: `shellcheck` não está
instalado, e mesmo assim a máquina está operacional para o ciclo — evidência
direta de que ele é ferramenta de CI, não de execução.

O workflow instala o `shellcheck` explicitamente antes de usá-lo, em vez de
depender de ele vir pré-instalado no runner: essa é uma afirmação sobre a imagem
do runner que não foi verificada em fonte oficial, e o Princípio V não deixa
afirmar sem fonte. Instalar explicitamente é correto nos dois casos.

**Alternatives considered**:

- *Assumir `shellcheck` pré-instalado no runner*. Rejeitado: afirmação sobre
  ferramenta externa sem fonte oficial lida (Princípio V).
- *Adicionar `shellcheck` aos pré-requisitos de máquina*. Rejeitado: exigiria
  emenda ao Princípio VII, e a garantia que interessa é a do CI, que barra antes
  do merge.

---

## Decision 10: Sintaxe real da CLI de plugins do Claude Code

**Decision**: o provisionamento de plugins usa as formas abaixo, todas confirmadas
na própria CLI instalada:

```sh
claude plugin marketplace add <source>      # URL, caminho ou repo GitHub
claude plugin install <plugin>@<marketplace>
claude plugin update  <plugin>
claude plugin list
```

Os dois marketplaces do cockpit, MEDIDOS via `claude plugin marketplace list`:

| Marketplace | Origem | Plugin | Papel |
|---|---|---|---|
| `context-mode` | GitHub `mksglu/context-mode` | `context-mode@context-mode` | obrigatório (Princípio V) |
| `ponytail` | GitHub `DietrichGebert/ponytail` | `ponytail@ponytail` | recomendado |

**Rationale**: FR-008 exige instalar/atualizar pelos canais oficiais de cada um.
Como cada plugin vem de um marketplace próprio, o marketplace precisa estar
registrado antes do install — daí `marketplace add` fazer parte da sequência.

**Fonte**: MEDIDO — `claude plugin marketplace add --help` devolve
`Usage: claude plugin marketplace add [options] <source>` / *"Add a marketplace
from a URL, path, or GitHub repo"*; `claude plugin update --help` devolve
`Usage: claude plugin update [options] <plugin>`; `claude plugin install --help`
devolve `Usage: claude plugin install|i [options] <plugin>` / *"use
plugin@marketplace for specific marketplace"*; `claude plugin list` devolve os
identificadores `context-mode@context-mode` e `ponytail@ponytail` (este último
na versão 4.10.0) — os dois IDs da tabela acima são **medidos**, não inferidos do
nome do marketplace. Forma `plugin@marketplace`
também confirmada em FONTE OFICIAL —
<https://code.claude.com/docs/en/discover-plugins.md>
(`claude plugin install formatter@your-org --scope project`).

> **Lacuna declarada**: a documentação oficial pública não forneceu um bloco
> literal da forma genérica `claude plugin marketplace add <owner/repo>` — só o
> exemplo específico `--claudeai`. A forma usada aqui vem do `--help` da CLI
> instalada (fonte primária, mais forte que o doc para efeito de sintaxe), e está
> registrada como MEDIDO, não como citação de página oficial.

**Alternatives considered**:

- *Instalar os plugins por cópia para dentro do cockpit*. Rejeitado: viola o
  Princípio IV — só `bmad-code-review` é cópia, e ela está fora do escopo desta
  feature.

---

## Decision 11: Falha de plugin obrigatório vs. recomendado

**Decision**: falha em `context-mode` derruba o `instalar.sh` inteiro (saída
não-zero); falha em `ponytail` marca apenas o item como falho no relatório final
e o comando ainda termina com sucesso.

**Rationale**: decidido no `/clarify` desta feature e gravado em FR-008 e nos Edge
Cases da spec. A assimetria tem base de governança: o Princípio V torna
`context-mode` a única via autorizada de consulta externa, então uma máquina sem
ele não consegue cumprir a constituição; `ponytail` é qualidade de código, que o
briefing classifica como recomendado.

**Alternatives considered**:

- *Tratar os dois como bloqueantes*. Rejeitado pela resposta do `/clarify`.
- *Tratar os dois como não-bloqueantes*. Rejeitado: `context-mode` é obrigatório
  por princípio.

---

## Decision 12: Relatório por item com falha diferida

**Decision**: `instalar.sh` acumula o status de cada item numa lista e imprime um
relatório final com uma linha por item, ao fim da execução — em vez de abortar no
primeiro erro. A saída do processo é não-zero se algum item **bloqueante** falhou.

Exceção deliberada: a checagem de pré-requisitos de máquina (FR-001) roda antes de
tudo e, se algo faltar, encerra ali mesmo — mas listando **todos** os ausentes de
uma vez, nunca parando no primeiro.

**Rationale**: FR-009 pede status individual de cada item e o cenário 7 da User
Story 1 pede o relatório consolidado; o Edge Case pede a lista completa de
ausentes. Abortar no primeiro erro faria o dev descobrir os problemas um por
execução. O corte em dois momentos existe porque não faz sentido tentar instalar
`cstk` numa máquina sem `curl` — a mensagem seria ruído derivado.

**Interação com `set -euo pipefail`** (Princípio VII): como `-e` aborta no primeiro
comando com saída não-zero, cada etapa não-fatal precisa ter o status capturado
explicitamente em vez de deixar o erro propagar. É a principal restrição de
implementação deste script e está registrada aqui para não ser redescoberta na
execução.

**Alternatives considered**:

- *Abortar na primeira falha*. Rejeitado: contraria FR-009 e o cenário 7.

---

## Decision 13: `skills/` ainda não existe — degradação explícita, não falha

**Decision**: FR-007 instala as skills do cockpit de `skills/` (raiz do
repositório) para `~/.claude/skills/`. Como `skills/` é o item 3 do MVP e **não
faz parte desta feature**, `instalar.sh` trata a ausência do diretório como
resultado legítimo: reporta o item como "nenhuma skill do cockpit a instalar" e
segue, sem falhar.

**Rationale**: o escopo desta frente são os itens 1 e 6 do MVP. Um `instalar.sh`
que falha porque um diretório de outra frente ainda não nasceu seria inutilizável
justamente durante a construção do próprio cockpit — que se desenvolve sob o
próprio ciclo (Princípio II). A verificação empírica: MEDIDO, a raiz do
repositório hoje contém `docs/`, `versoes.env`, `README.md`, `LICENSE` e
`.gitignore` — não há `skills/`.

**Alternatives considered**:

- *Falhar se `skills/` não existir*. Rejeitado: quebra o dogfooding e acopla esta
  frente à entrega da frente de skills.
- *Criar `skills/` vazio agora*. Rejeitado: diretório vazio não é versionável em
  git e antecipa escopo de outra frente.

---

## Decision 14: Idempotência de cópia com aviso, nunca sobrescrita silenciosa

**Decision**: ao instalar uma skill do cockpit em `~/.claude/skills/`, comparar o
conteúdo de destino com o de origem:

| Situação | Ação |
|---|---|
| destino ausente | copia, reporta `instalada` |
| destino idêntico à origem | não faz nada, reporta `ja atualizada` |
| destino difere da origem | **avisa** que há divergência local e o que fez, reporta `atualizada (havia edicao local)` |

**Rationale**: o Princípio VII exige que a segunda execução produza o mesmo estado
final *"sem duplicar registros nem sobrescrever edição local sem aviso"* — o
"sem aviso" é a parte operante. Detectar divergência por comparação de conteúdo
custa uma linha e transforma perda silenciosa de trabalho em mensagem.

**Alternatives considered**:

- *Sobrescrever sempre*. Rejeitado: viola a cláusula explícita do Princípio VII.
- *Nunca sobrescrever quando difere*. Rejeitado: deixaria a máquina permanentemente
  desatualizada após qualquer edição local acidental, sem caminho de volta.

---

## Decision 15: Varredura de segredo no CI — binário do `gitleaks`, não a Action nem o recurso nativo

**Decision**: FR-019/FR-020/FR-021 são atendidos por `gitleaks` chamado como
**binário** dentro do job de CI (release fixada por versão, baixada e conferida
contra o `checksums.txt` publicado ao lado), com `--redact` e exceções em
`.gitleaksignore`/`.gitleaks.toml` versionados. **Não** se usa a
`gitleaks/gitleaks-action`, nem o secret scanning nativo do GitHub, nem
`trufflehog`.

**Rationale** — as três restrições que decidem, nesta ordem:

1. *Zero pré-requisito de máquina* (FR-020, Princípio VII): vale para as três
   candidatas, já que todas rodam só no CI. Não desempata.
2. *Exceção precisa ser arquivo versionado e revisável na PR* (FR-021). Isto
   **elimina o recurso nativo do GitHub**: FONTE OFICIAL — em repositório privado
   de organização, secret scanning "Available with GitHub Secret Protection
   enabled on GitHub Team or GitHub Enterprise Cloud" e push protection "Requires
   GitHub Secret Protection to be enabled"
   (<https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning>,
   <https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection>).
   É produto pago e ligado por *Settings* do repositório, não por arquivo no
   repositório — a garantia não ficaria verificável por quem lê a PR.
3. *Sem dependência de cadastro externo nem de tag móvel*. Isto **elimina a
   Action oficial do gitleaks**: FONTE OFICIAL — o README da
   `gitleaks/gitleaks-action` documenta `GITLEAKS_LICENSE` como *"required for
   organizations, not required for user accounts"*, e a licença da própria Action
   deixou de ser MIT na v2.0.0 (a API do GitHub reporta `NOASSERTION`). O
   **binário** do gitleaks continua MIT (`spdx_id: "MIT"`) e não exige chave
   nenhuma. E elimina também o `trufflehog`, cuja forma documentada de uso em
   Actions é `uses: trufflesecurity/trufflehog@main` — um *branch móvel*, o oposto
   direto do controle já adotado nesta frente (actions de terceiro fixadas por SHA).

**Forma concreta** (tudo FONTE OFICIAL, README do gitleaks em
<https://github.com/gitleaks/gitleaks/blob/master/README.md>):

| Item | Valor | Observação |
|---|---|---|
| Subcomando | `gitleaks dir .` | `gitleaks detect` **não existe mais**; os subcomandos são `dir`, `git`, `stdin`, `version` |
| Redação do valor | `--redact` (default 100%) | **obrigatório**: o console default imprime o campo `Secret:` com o valor achado. FR-019 exige apontar arquivo e linha sem reproduzir o valor |
| Códigos de saída | `0` sem achado · `1` achado ou erro · `126` flag desconhecida | o `1` é o que barra a PR |
| Exceções | `.gitleaksignore` na raiz, uma linha por *fingerprint* `<commit>:<file>:<ruleID>:<line>` | pego por default (`-i/--gitleaks-ignore-path`, default `.`); o README marca o recurso como *"experimental and is subject to change"* |
| Exceções por padrão | `.gitleaks.toml` na raiz, blocos `[[allowlists]]` / `[[rules.allowlists]]` (`paths`, `regexes`, `stopwords`) | pego por default quando está na raiz do alvo, sem flag (`-c` é opcional) |
| Instalação no job | tarball da release fixada: `gitleaks_<versao>_linux_x64.tar.gz` + `gitleaks_<versao>_checksums.txt` | atenção ao padrão: é `linux_x64`, **não** `linux_amd64` |

**Por que `dir` e não `git`**: `dir` varre os arquivos como estão na árvore, que é
exatamente o recorte de FR-019 ("arquivo versionado") e o mesmo recorte que
`verificar-agnostico.sh` já usa (`git ls-files`, Decision 6). `git` varreria o
histórico inteiro, o que faria qualquer achado histórico barrar toda PR até
alguém produzir um *baseline* — custo de operação desproporcional numa frente
cujo repositório acabou de nascer.

**Por que a versão fixada mora no workflow e não em `versoes.env`**: `versoes.env`
é, pelo seu próprio cabeçalho, o arquivo de **pisos de versão de pré-requisito**,
lido por `instalar.sh` em runtime (Decision 5). A versão do gitleaks não é piso
(é pino exato) e não é pré-requisito de máquina (é ferramenta de CI, FR-020) —
colocá-la lá poria no arquivo que o instalador parseia um valor que o instalador
nunca usa. O workflow é o único consumidor; o pino mora no único consumidor.

**Lacunas declaradas (Princípio V — não preenchidas por suposição)**:

- **NÃO VERIFICADO**: se o binário do gitleaks faz alguma chamada de rede para
  validar candidatos a segredo. O README não afirma nem nega; o que ele afirma do
  motor é regex + entropia (`entropy`, `secretGroup`). Como o job roda com
  `permissions: contents: read` e sem segredos, o risco de uma eventual chamada é
  limitado, mas a afirmação "é 100% offline" **não pode ser feita** com o que foi
  lido.
- **Teto conhecido**: o README do gitleaks abre com *"Gitleaks is feature
  complete. I'm not merging new features into Gitleaks. Future releases will be
  security patches only"*, com o autor migrando o foco para outro projeto. Ou
  seja: correções de segurança continuam, **detectores novos não**. Caminho de
  saída se isso pesar: trocar a ferramenta por outra chamada do mesmo jeito
  (binário pinado dentro do job) — a troca fica contida no workflow e nos dois
  arquivos de exceção, sem tocar spec nem `instalar.sh`.

**Alternatives considered**:

- *`gitleaks/gitleaks-action`*. Rejeitada: exige `GITLEAKS_LICENSE` em repositório
  de organização (cadastro externo + secret de org) e sua licença não é mais MIT.
- *Secret scanning + push protection nativos do GitHub*. Rejeitada: pagos em
  repositório privado e configurados fora do repositório, o que quebra FR-021.
- *`trufflehog`*. Rejeitada nesta rodada: a forma oficialmente documentada em
  Actions é `@main`, branch móvel, incompatível com o controle de fixação por SHA
  já adotado. É a candidata mais forte de substituição se o teto de manutenção do
  gitleaks pesar — está mais ativa (release de 2026-09-24) e não exige chave.

---

## Unknowns remanescentes

Nenhum eixo estrutural (linguagem/runtime, stack, arquitetura, persistência,
ambiente-alvo, tier de entrega) ficou em aberto: todos vêm decididos do briefing
§6 (bash, GitHub Actions, sem persistência) e da constituição §Princípios IV e
VII, sem inferência desta skill.

Uma lacuna factual permanece declarada, não suprida por suposição: **se o binário
do gitleaks faz chamada de rede ao avaliar candidatos a segredo** — a
documentação oficial lida não afirma nem nega (Decision 15). Nenhuma afirmação
sobre isso é feita em nenhum artefato desta frente.
