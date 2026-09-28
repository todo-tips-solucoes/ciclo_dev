# Feature Specification: configurar.sh — configurador de projeto do cockpit

**Feature**: `configurar`
**Created**: 2026-09-28
**Status**: Draft

> Item 2 do MVP do briefing. Decisões de infraestrutura: N/A (script local, sem
> scheduler, sessão persistente, chave criptográfica, multi-réplica ou retry de
> requisição).

## User Scenarios & Testing

### User Story 1 - Configurar um projeto do zero (Priority: P1)

A pessoa dona de um projeto-alvo roda o configurador na raiz desse projeto. Ele
pergunta os parâmetros do ciclo (nome, `org/repo`, branch de integração, branch
de produção, gerenciador de pacotes, comandos de typecheck/lint/build, comando
de deploy por ambiente, tabela de identidades, board, Princípio III ligado ou
desligado) e grava o `cockpit.config` do projeto no formato já definido pelo
cockpit.

**Why this priority**: sem `cockpit.config` a skill `rito-dev` não roda; é o
valor mínimo da feature e substitui o preenchimento manual a partir do exemplo.

**Independent Test**: em um diretório vazio inicializado como repositório git,
rodar o configurador respondendo todas as perguntas; o `cockpit.config` gerado
contém as 10 chaves obrigatórias e é lido sem erro por `source` em bash puro.

**Acceptance Scenarios**:

1. **Given** um projeto sem `cockpit.config`, **When** a pessoa responde todas
   as perguntas, **Then** o `cockpit.config` é gravado na raiz do projeto com
   as chaves obrigatórias preenchidas e nenhuma chave desconhecida.
2. **Given** uma resposta com `org/repo` fora do formato `org/repo`, **When** o
   configurador valida, **Then** ele recusa o valor, diz qual campo e pergunta
   de novo, sem gravar nada parcial.
3. **Given** branch de integração igual à branch de produção, **When** a pessoa
   confirma, **Then** o configurador aceita como configuração válida do modelo
   único, sem aviso de erro nem modo separado.
4. **Given** a pessoa responde em branco a um campo obrigatório sem valor
   padrão, **When** o configurador valida, **Then** ele repete a pergunta.

---

### User Story 2 - Rodar de novo sem perder nada (Priority: P1)

Rodar o configurador sobre um projeto já configurado relê o `cockpit.config`
existente, oferece os valores atuais como padrão e produz o mesmo estado final
quando nada muda. `--atualizar` re-renderiza os templates sem perguntar de novo.

**Why this priority**: Princípio VII (idempotência) e visão de futuro do
briefing (atualizar projeto = `git pull` do cockpit + `configurar.sh
--atualizar`).

**Independent Test**: rodar duas vezes seguidas com as mesmas respostas; os
arquivos do projeto ficam byte a byte idênticos após a segunda execução.

**Acceptance Scenarios**:

1. **Given** um projeto já configurado, **When** o configurador roda de novo e a
   pessoa aceita os padrões, **Then** o `cockpit.config` e os arquivos
   renderizados permanecem idênticos e nenhum registro é duplicado.
2. **Given** um arquivo renderizado que a pessoa editou à mão, **When** o
   configurador precisaria sobrescrevê-lo com conteúdo diferente, **Then** ele
   avisa, não sobrescreve sem confirmação e informa como forçar.
3. **Given** `--atualizar` e um `cockpit.config` válido, **When** roda, **Then**
   nenhuma pergunta é feita e os templates são re-renderizados a partir da
   config existente.
4. **Given** `--atualizar` sem `cockpit.config`, **When** roda, **Then** falha
   com mensagem clara indicando rodar o configurador sem a opção.

---

### User Story 3 - Renderizar templates sem placeholder residual (Priority: P1)

O configurador renderiza todo template presente sob `templates/` do cockpit
para dentro do projeto-alvo, substituindo placeholders pelos valores do
`cockpit.config`, e recusa terminar com sucesso se sobrar qualquer placeholder
sem valor.

**Why this priority**: os templates de governança e automação (itens 4 e 5 do
MVP) chegam nas frentes seguintes e MUST funcionar sem mexer no configurador;
placeholder residual em um projeto configurado é falha silenciosa.

**Independent Test**: com um template contendo um placeholder sem chave
correspondente, o configurador termina com exit diferente de zero, lista o
arquivo e o placeholder, e não deixa o projeto com o arquivo parcial.

**Acceptance Scenarios**:

1. **Given** um template com placeholders todos resolvidos pela config, **When**
   renderiza, **Then** o arquivo de saída aparece no mesmo caminho relativo
   dentro do projeto, sem nenhum placeholder.
2. **Given** um template com placeholder sem chave, **When** renderiza, **Then**
   o configurador termina com erro, cita arquivo e placeholder, e nenhum
   arquivo com placeholder residual permanece no projeto.
3. **Given** um novo template adicionado sob `templates/`, **When** o
   configurador roda, **Then** ele é renderizado sem qualquer alteração no
   script.
4. **Given** um valor de config contendo caracteres especiais (barra, `&`,
   aspas, `$`), **When** renderiza, **Then** o valor aparece literalmente no
   arquivo de saída.

---

### User Story 4 - Provisionar guard hooks pela ferramenta oficial (Priority: P2)

Ao final, o configurador provisiona os guard hooks do runtime no projeto via
`cstk hooks install --project-path`. Se o `cstk` não estiver instalado ou abaixo
do piso, ele verifica, imprime o comando oficial exato e termina com erro; nunca
instala nem atualiza terceiro.

**Why this priority**: sem os hooks o ciclo autônomo roda sem guardas, mas o
`cockpit.config` e os templates já têm valor sem eles.

**Independent Test**: com `cstk` ausente do PATH, o configurador imprime o
comando oficial de instalação e sai diferente de zero, sem executar nada de
terceiro.

**Acceptance Scenarios**:

1. **Given** `cstk` presente e na versão mínima, **When** o configurador chega ao
   fim, **Then** executa `cstk hooks install --project-path <raiz do projeto>`
   e reporta o resultado.
2. **Given** `cstk` ausente ou abaixo do piso de `versoes.env`, **When** chega
   ao passo dos hooks, **Then** imprime o comando oficial e termina com exit
   diferente de zero, sem instalar nada.
3. **Given** hooks já instalados, **When** roda de novo, **Then** o resultado é
   idempotente (sem duplicar hooks).

---

### User Story 5 - Modo não interativo (Priority: P3)

Para CI e testes, o configurador aceita todos os valores por um arquivo de
respostas ou por variáveis, sem terminal interativo.

**Why this priority**: viabiliza o teste automatizado exigido pelo briefing
(render de templates com a config de exemplo no CI do cockpit).

**Independent Test**: rodar com `cockpit.config.example` como fonte de valores,
sem stdin, e obter projeto configurado.

**Acceptance Scenarios**:

1. **Given** valores completos fornecidos de forma não interativa, **When**
   roda, **Then** não faz nenhuma pergunta e produz o mesmo resultado do modo
   interativo com essas respostas.
2. **Given** valor obrigatório faltando no modo não interativo, **When** roda,
   **Then** falha dizendo qual chave falta, sem presumir valor.

### Edge Cases

- Diretório-alvo que não existe ou não é repositório git: recusar com mensagem
  clara; nunca escrever fora do projeto informado.
- Caminho de saída de template que escaparia do projeto (`..`, link simbólico
  para fora): recusar.
- Interrupção no meio (Ctrl-C): nenhum `cockpit.config` truncado nem arquivo
  renderizado pela metade.
- `cockpit.config` existente com chave obrigatória ausente ou desconhecida:
  reportar a chave e perguntar somente o que falta.
- Board não usado pelo projeto: resposta vazia é válida e a ausência é
  registrada explicitamente, não como placeholder residual.
- Tabela de identidades vazia: recusar; ao menos uma identidade é obrigatória
  (Princípio III).
- `cockpit.config` existente com valores que a pessoa não reconhece como seus
  (ex.: outro projeto): o configurador mostra os valores lidos antes de
  aceitá-los como padrão.
- Nenhum template existente sob `templates/`: passo de renderização termina com
  sucesso e informa que nada havia a renderizar.

## Requirements

### Functional Requirements

- **FR-001**: O configurador MUST perguntar: nome do projeto, `org/repo`,
  branch de integração, branch de produção, gerenciador de pacotes, comandos de
  typecheck, lint e build, comando de deploy de integração e de produção, URLs
  de ambiente (opcionais), tabela de identidades, board e se o Princípio III
  fica ligado (padrão) ou desligado.
- **FR-002**: O configurador MUST gravar `cockpit.config` na raiz do projeto-alvo
  no formato `CHAVE=valor` já definido por `cockpit.config.example` e por
  `docs/specs/skills-do-cockpit/data-model.md`, legível por `source` em bash
  puro, com as 10 chaves obrigatórias e as 2 opcionais quando informadas.
- **FR-003**: As chaves novas (identidades, board, Princípio III) MUST ser
  acrescentadas ao formato como extensão retrocompatível, registradas em
  `cockpit.config.example` e no `data-model.md`, de modo que um
  `cockpit.config` sem elas continue válido para `rito-dev`.
- **FR-004**: O configurador MUST validar cada resposta (`org/repo` no formato
  certo, nomes de branch válidos, comandos não vazios, URL válida quando
  informada) e MUST repetir a pergunta em caso de valor inválido.
- **FR-005**: O configurador MUST aceitar branch de integração igual à de
  produção como configuração válida do modelo único.
- **FR-006**: O configurador MUST ser idempotente: sobre projeto já configurado,
  relê o `cockpit.config`, oferece os valores atuais como padrão e, sem
  mudanças, deixa todos os arquivos byte a byte idênticos.
- **FR-007**: O configurador MUST NOT sobrescrever arquivo editado à mão sem
  aviso e confirmação explícita; MUST oferecer opção para forçar.
- **FR-008**: O configurador MUST oferecer `--atualizar`, que re-renderiza os
  templates a partir do `cockpit.config` existente sem perguntar nada, e MUST
  falhar com mensagem clara se não houver config.
- **FR-009**: O configurador MUST renderizar todo template existente sob
  `templates/` do cockpit para o mesmo caminho relativo dentro do projeto,
  substituindo placeholders pelos valores do `cockpit.config`, sem exigir mudança
  no script quando um template novo é adicionado.
- **FR-010**: O configurador MUST recusar terminar com sucesso se qualquer
  arquivo renderizado contiver placeholder sem valor; MUST listar arquivo e
  placeholder, e MUST NOT deixar no projeto o arquivo com placeholder residual.
- **FR-011**: O valor substituído MUST aparecer literalmente no arquivo de
  saída, inclusive com caracteres especiais.
- **FR-012**: A feature MUST trazer 1 ou 2 templates mínimos de prova sob
  `templates/`, genéricos e sem conteúdo de projeto real, exercitando o motor;
  os templates de governança e automação ficam fora desta feature.
- **FR-013**: O configurador MUST provisionar os guard hooks executando
  `cstk hooks install --project-path <raiz do projeto>`, e MUST NOT copiá-los.
- **FR-014**: Se `cstk` estiver ausente ou abaixo do piso `CSTK_MIN` de
  `versoes.env`, o configurador MUST imprimir o comando oficial exato e terminar
  com exit diferente de zero; MUST NOT instalar, atualizar nem executar
  bootstrap de terceiro (Princípio IV). O número do piso MUST ser lido de
  `versoes.env`, nunca repetido.
- **FR-015**: O configurador MUST escrever somente dentro do projeto-alvo
  informado; MUST recusar caminho de saída que escape dele (Princípio VII).
- **FR-016**: O configurador MUST permitir execução não interativa, com todos os
  valores fornecidos por arquivo ou variáveis, e MUST falhar dizendo a chave
  faltante em vez de presumir valor.
- **FR-017**: A gravação do `cockpit.config` e dos arquivos renderizados MUST ser
  atômica: uma interrupção não deixa arquivo truncado ou parcial.
- **FR-018**: A tabela de identidades MUST exigir ao menos uma identidade no
  formato `nome <email>`; MUST avisar (sem recusar) quando o e-mail não for
  endereço `noreply` do GitHub, por não constar e-mail pessoal em template.
- **FR-019**: O configurador MUST ser bash portável (Linux, WSL, macOS) com
  `set -euo pipefail`, passar em shellcheck sem findings e depender apenas de
  `git`, `gh`, `node`, `jq` e `curl` (Princípio VII).
- **FR-020**: Nenhum valor de projeto, nome de organização ou termo proibido MUST
  constar do script, dos templates de prova ou dos exemplos; MUST passar em
  `scripts/verificar-agnostico.sh` (Princípio I).
- **FR-021**: Mensagens, perguntas e erros MUST estar em português do Brasil com
  acentuação correta (Princípio VI).

### Key Entities

- **cockpit.config**: arquivo `CHAVE=valor` na raiz do projeto-alvo; fonte única
  dos valores que variam por projeto. Ganha chaves opcionais de identidades,
  board e Princípio III.
- **Tabela de identidades**: lista de autores do projeto (`nome <email>`),
  usada pelos templates que declaram identidade de commit.
- **Template**: arquivo sob `templates/` com placeholders, renderizado para o
  mesmo caminho relativo no projeto-alvo.
- **Placeholder residual**: marcador de valor ainda não resolvido em arquivo
  renderizado; condição de falha do configurador.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Uma pessoa configura um projeto novo respondendo às perguntas em
  menos de 5 minutos, sem editar nenhum arquivo à mão.
- **SC-002**: Duas execuções consecutivas com as mesmas respostas produzem 0
  diferenças de arquivo entre a primeira e a segunda.
- **SC-003**: 100% dos templates presentes sob `templates/` são renderizados, e
  0 arquivos com placeholder residual permanecem no projeto após qualquer
  execução que termine com sucesso.
- **SC-004**: Adicionar um template novo não exige nenhuma linha alterada no
  script (0 alterações).
- **SC-005**: Em máquina sem `cstk`, 0 comandos de instalação de terceiro são
  executados e a saída contém o comando oficial exato.
- **SC-006**: O script passa em shellcheck com 0 findings e em
  `verificar-agnostico.sh` com 0 ocorrências.
- **SC-007**: Nenhuma escrita ocorre fora do projeto-alvo em 100% das execuções,
  inclusive com caminhos hostis.

## Delta Requirements

**Skip**: feature nova (script novo); único ponto que toca comportamento existente é a extensão aditiva do formato do `cockpit.config`, coberta por FR-003 — sem corpus `docs/specs/current/` — orquestrador feature-00c, 2026-09-28.
