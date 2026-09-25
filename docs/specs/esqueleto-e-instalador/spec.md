# Feature Specification: Esqueleto do cockpit-dev e instalador de máquina

**Feature**: `esqueleto-e-instalador`
**Created**: 2026-09-25
**Status**: Draft

## Clarifications

### Session 2026-09-25

- Q: Para gh, jq e curl, o comando de preparo deve checar apenas presença (sem piso de
  versão), ou também exigir uma versão mínima definida para cada um? → A: Checar apenas
  presença de gh/jq/curl, sem piso de versão — só git (>=2.36) e node (>=20) têm piso
  mínimo exigido.
- Q: Quando a instalação/atualização do plugin recomendado (ponytail) falha, o comando de
  preparo deve terminar em falha (exit não-zero) como um todo, ou reportar a falha só
  nesse item e ainda assim relatar sucesso geral? → A: Reportar a falha apenas no item
  individual e terminar com sucesso geral — só a falha do plugin obrigatório
  (context-mode) bloqueia o comando inteiro.
- Q: O requisito de PT-BR (FR-012) cobre só as mensagens que o próprio script escreve,
  deixando passar a saída nativa (stderr) das ferramentas externas como está, ou exige
  também traduzir/suprimir essa saída nativa? → A: Cobre só as mensagens autorais do
  script; a saída nativa de ferramentas externas (git/gh/cstk/curl) pode aparecer como
  está, em qualquer idioma que a ferramenta produza.
- Q: O Princípio I promete que nada no cockpit nomeia credencial, mas o mecanismo citado
  (casamento literal contra lista de nomes próprios) não detecta segredo. Ampliar o escopo
  desta frente com varredura de segredo, ou ajustar a redação do princípio? → A: Ampliar o
  escopo desta frente com uma varredura de segredo que rode **apenas** na checagem
  automática do repositório — sem acrescentar pré-requisito à máquina do dev (Princípio VII
  preservado) e sem emenda constitucional. Decidido pelo owner (block-001/dec-023).

## User Scenarios & Testing

### User Story 1 - Preparar a máquina para o ciclo com um comando (Priority: P1)

Um dev do time, numa máquina nova ou desatualizada, roda um único comando para deixar
a máquina pronta para o ciclo de desenvolvimento agêntico: as ferramentas de base
presentes na versão mínima exigida, a etapa de implementação do ciclo instalada e
atualizada, as skills do cockpit disponíveis e os plugins necessários instalados.

**Why this priority**: sem a máquina pronta, nenhuma outra etapa do ciclo (worktree,
`/feature-00c`, revisão, PR) é possível. É o ponto de entrada de qualquer novo dev ou
máquina, e hoje esse preparo é feito à mão, de forma diferente em cada cópia do ciclo —
inclusive esquecendo de instalar a peça que implementa (o `cstk`), sem nenhum aviso.

**Independent Test**: numa máquina onde nenhuma das ferramentas está presente (ou estão
desatualizadas), rodar o comando e verificar que ao final todas respondem e estão na
versão exigida — sem precisar de nenhuma outra parte desta feature.

**Acceptance Scenarios**:

1. **Given** uma máquina sem `git`, `gh`, `node`, `jq` ou `curl` instalados, **When** o
   comando de preparo é executado, **Then** ele para com uma mensagem clara listando
   exatamente quais ferramentas estão faltando, antes de tentar qualquer instalação.
2. **Given** uma máquina com todos os pré-requisitos na versão mínima exigida, mas sem a
   ferramenta de implementação do ciclo instalada, **When** o comando de preparo é
   executado, **Then** a ferramenta é instalada pelo canal oficial e, ao final, sua versão
   é confirmada contra o piso mínimo do projeto.
3. **Given** uma máquina onde a ferramenta de implementação já está instalada numa versão
   mais antiga, **When** o comando de preparo é executado, **Then** ela é atualizada para a
   última versão disponível antes de qualquer verificação de piso.
4. **Given** uma máquina onde, mesmo após a atualização, a versão instalada da ferramenta
   de implementação fica abaixo do piso mínimo do projeto, **When** o comando de preparo é
   executado, **Then** ele falha com uma mensagem clara informando a versão instalada e o
   piso exigido.
5. **Given** uma máquina onde a ferramenta de implementação não responde a uma checagem de
   versão, **When** o comando de preparo é executado, **Then** ele falha com uma mensagem
   clara — nunca prossegue silenciosamente sem essa peça.
6. **Given** uma máquina já preparada com sucesso, **When** o comando de preparo é
   executado uma segunda vez, **Then** o resultado final é o mesmo (nada duplicado,
   nenhuma configuração local sobrescrita sem aviso) e o comando ainda relata sucesso.
7. **Given** o comando de preparo terminou, **When** o dev consulta o relatório final,
   **Then** cada item verificado (ferramentas de base, ferramenta de implementação,
   skills, plugins) aparece com seu status individual de sucesso ou falha.

---

### User Story 2 - Verificar que o cockpit não vazou nada de um projeto real (Priority: P2)

O mantenedor do cockpit quer confirmar, a qualquer momento, que nenhum arquivo do
repositório menciona nome de projeto, cliente, organização, domínio ou credencial reais —
a garantia de que o cockpit serve a qualquer projeto deixa de ser promessa e vira algo que
se roda e confere.

**Why this priority**: é a garantia central do cockpit (agnosticismo verificável); sem
ela, cada cópia do ciclo volta a divergir e a vazar contexto de onde nasceu — o problema
que esta feature existe para resolver. Depende de existir algo para verificar (a User
Story 1 não é pré-requisito técnico, mas ambas nascem juntas nesta frente por serem os
dois pilares do esqueleto).

**Independent Test**: adicionar deliberadamente um termo da lista proibida em um arquivo
qualquer do repositório, rodar a verificação isoladamente e confirmar que ela aponta o
arquivo e a linha exatos — sem depender de CI nem do instalador.

**Acceptance Scenarios**:

1. **Given** o repositório sem nenhum termo proibido, **When** a verificação de
   agnosticismo é executada, **Then** ela termina com sucesso e zero ocorrências
   reportadas.
2. **Given** um arquivo do repositório contendo um termo da lista proibida, **When** a
   verificação de agnosticismo é executada, **Then** ela falha e reporta o arquivo e a
   linha exatos de cada ocorrência.
3. **Given** a lista de termos proibidos, **When** alguém revisa o histórico do
   repositório, **Then** encontra a lista como um arquivo versionado e independente do
   script de verificação, editável sem tocar na lógica de varredura.

---

### User Story 3 - Barrar automaticamente uma quebra antes do merge (Priority: P3)

O mantenedor do cockpit confia que toda alteração proposta é checada automaticamente
antes de poder ser mergeada: nenhum script shell com problema de portabilidade, nenhuma
menção a projeto/cliente/organização real e nenhum segredo passam despercebidos por
revisão manual.

**Why this priority**: automatiza a garantia das User Stories 1 e 2 a cada mudança, sem
depender de alguém lembrar de rodar as checagens manualmente antes de abrir a PR. É a
menor prioridade das três porque seu valor só se realiza depois que o script de
verificação (US2) e os scripts a verificar (US1) já existem.

**Independent Test**: abrir uma alteração de teste com um problema de portabilidade de
shell conhecido, outra com um termo proibido e outra com um segredo de teste, e confirmar
que a checagem automática da mudança falha nos três casos, apontando qual checagem barrou.

**Acceptance Scenarios**:

1. **Given** uma alteração que introduz um script shell com um problema de portabilidade
   conhecido, **When** a checagem automática da mudança roda, **Then** ela falha apontando
   o script e o problema.
2. **Given** uma alteração que introduz um termo da lista proibida, **When** a checagem
   automática da mudança roda, **Then** ela falha pelo mesmo motivo que a User Story 2
   reportaria rodando manualmente.
3. **Given** uma alteração que introduz um segredo (credencial, token, chave privada ou
   string de conexão) em qualquer arquivo versionado, **When** a checagem automática da
   mudança roda, **Then** ela falha apontando o arquivo e a linha, sem reproduzir o valor
   do segredo no relatório.
4. **Given** uma alteração sem nenhum dos três problemas, **When** a checagem automática da
   mudança roda, **Then** ela termina com sucesso e libera a mudança para revisão humana.

---

### Edge Cases

- O que acontece quando mais de um pré-requisito de máquina está ausente ao mesmo tempo?
  A mensagem de falha deve listar todos os ausentes, não parar no primeiro.
- O que acontece quando a máquina não tem permissão de escrita na área onde o comando de
  preparo grava suas configurações? Deve falhar com mensagem clara em vez de falhar a
  meio caminho deixando estado parcial.
- O que acontece quando a ferramenta de implementação do ciclo está instalada, na versão
  exigida, mas um dos plugins necessários está ausente? A execução deve instalar apenas o
  que falta, sem reinstalar o que já está correto.
- O que acontece quando a instalação/atualização do plugin recomendado falha? O comando
  reporta a falha apenas no status individual desse item e ainda assim relata sucesso
  geral; só a falha do plugin obrigatório bloqueia o comando inteiro.
- O que acontece quando um arquivo binário do repositório contém, por acaso, uma sequência
  de bytes igual a um termo da lista proibida? Fica fora do escopo desta feature tratar
  colisões binárias; a varredura assume conteúdo textual.
- O que acontece quando um termo proibido aparece dentro de um exemplo que o próprio
  cockpit usa para *ensinar* o que não fazer? A lista proibida não distingue contexto
  educativo de vazamento real — qualquer ocorrência é reportada; ajustar a lista ou o
  texto do exemplo é responsabilidade de quem escreve o conteúdo.
- O que acontece quando a varredura de segredo acusa um placeholder de exemplo (uma chave
  fictícia num template ou numa skill) como se fosse credencial real? A exceção é
  registrada num arquivo versionado do repositório, revisável na própria PR — nunca
  suprimida por edição de configuração fora do repositório nem por desligar a checagem.
- O que acontece quando um segredo real é detectado? A checagem barra a mudança apontando
  arquivo e linha, mas não reproduz o valor detectado no relatório — o relatório da
  checagem automática é legível por qualquer um com acesso ao repositório.
- O que acontece quando a checagem automática da mudança roda sobre um repositório onde
  ainda não existem templates a renderizar? Ela cobre apenas as checagens desta feature
  (portabilidade de shell e agnosticismo); a checagem de render de templates com a
  configuração de exemplo fica para quando os templates existirem, em frente futura.

## Requirements

### Functional Requirements

- **FR-001**: O sistema MUST verificar, antes de qualquer instalação, a presença de cada
  ferramenta de base da máquina (git, gh, node, jq, curl) e, adicionalmente, a versão
  mínima exigida de git (>=2.36) e node (>=20) — gh, jq e curl MUST ser checados apenas
  por presença, sem piso de versão — e MUST falhar listando claramente cada uma que
  estiver ausente ou (no caso de git/node) abaixo do mínimo.
- **FR-002**: O sistema MUST instalar a ferramenta de implementação do ciclo pelo canal
  oficial quando ela não estiver presente na máquina.
- **FR-003**: O sistema MUST atualizar a ferramenta de implementação do ciclo para a
  última versão disponível quando ela já estiver presente, antes de qualquer verificação
  de piso mínimo.
- **FR-004**: O sistema MUST conferir, após a instalação ou atualização, se a versão da
  ferramenta de implementação atende a um piso mínimo mantido em um único lugar
  versionado, e MUST falhar apenas quando a versão instalada ficar abaixo desse piso.
- **FR-005**: O sistema MUST falhar com mensagem clara quando a ferramenta de
  implementação não responder a uma checagem de versão.
- **FR-006**: O sistema MUST provisionar (instalar na primeira execução, atualizar nas
  seguintes) o que a ferramenta de implementação exige para operar sobre a máquina, de
  forma idempotente.
- **FR-007**: O sistema MUST disponibilizar as skills do cockpit no diretório de skills
  global do usuário.
- **FR-008**: O sistema MUST instalar ou atualizar, pelos canais oficiais de cada um, um
  plugin obrigatório de consulta externa e um plugin recomendado de simplicidade de
  código. Falha na instalação/atualização do plugin obrigatório MUST falhar o comando
  inteiro; falha na instalação/atualização do plugin recomendado MUST ser reportada
  apenas no status individual desse item (FR-009), sem falhar o comando.
- **FR-009**: O sistema MUST, ao final da execução, validar que cada item preparado
  (ferramentas de base, ferramenta de implementação, skills, plugins) responde
  corretamente, e MUST relatar o status individual de cada um.
- **FR-010**: O comando de preparo da máquina MUST ser idempotente — executá-lo mais de
  uma vez MUST produzir o mesmo estado final, sem duplicar registros nem sobrescrever
  configuração local sem aviso.
- **FR-011**: O comando de preparo da máquina MUST escrever apenas na área de
  configuração da máquina do usuário — nunca dentro de um diretório de projeto-alvo.
- **FR-012**: Toda mensagem autoral produzida pelo próprio comando de preparo da máquina
  MUST estar em português do Brasil. Este requisito não se estende à saída nativa
  (stdout/stderr) de ferramentas externas invocadas (git, gh, cstk, curl), que MAY
  aparecer no idioma que a ferramenta produzir.
- **FR-013**: O sistema MUST fornecer uma verificação que varre todo o repositório contra
  uma lista de termos proibidos e MUST reportar sucesso quando a varredura encontrar zero
  ocorrências.
- **FR-014**: A verificação de agnosticismo MUST falhar e MUST listar arquivo e linha de
  cada ocorrência encontrada, quando houver alguma.
- **FR-015**: A lista de termos proibidos MUST ser mantida como um arquivo versionado
  independente da lógica de varredura, editável sem alterar o script.
- **FR-016**: A verificação de agnosticismo MUST ser idempotente e portátil, sem efeito
  colateral em execuções repetidas.
- **FR-017**: O sistema MUST checar automaticamente, a cada alteração proposta ao
  repositório, se todo script shell do repositório está livre de problemas de
  portabilidade conhecidos, e MUST barrar a alteração quando encontrar algum.
- **FR-018**: O sistema MUST checar automaticamente, a cada alteração proposta ao
  repositório, o agnosticismo do repositório inteiro (FR-013), e MUST barrar a alteração
  quando encontrar alguma ocorrência proibida.
- **FR-019**: O sistema MUST checar automaticamente, a cada alteração proposta ao
  repositório, se algum segredo (credencial, token, chave privada ou string de conexão)
  foi introduzido em arquivo versionado, MUST barrar a alteração quando encontrar algum, e
  MUST apontar arquivo e linha sem reproduzir o valor detectado.
- **FR-020**: A varredura de segredo MUST rodar apenas na checagem automática do
  repositório, sem acrescentar nenhum pré-requisito à máquina do dev (Princípio VII).
- **FR-021**: As exceções da varredura de segredo (placeholders de exemplo reconhecidos
  como falso positivo) MUST ser mantidas em arquivo versionado do repositório, revisável
  na mesma alteração que as introduz.

> Decisões de infraestrutura: N/A — feature stateless, sem scheduler, sessão persistente,
> refresh de token externo, rotação de chave ou lock multi-processo. É um comando de
> preparo de máquina de execução única e verificações determinísticas de repositório.

### Key Entities

- **Pré-requisito de máquina**: nome da ferramenta de base (ex.: controlador de
  versão, cliente de linha de comando de repositório, runtime, processador de JSON,
  cliente HTTP) e a versão mínima exigida.
- **Piso de versão da ferramenta de implementação**: um único valor versionado,
  referenciado por chave em todo o resto do sistema — nunca duplicado como literal.
- **Lista de termos proibidos**: coleção versionada de termos que não podem aparecer em
  nenhum arquivo do repositório, mantida separada do mecanismo que a aplica.
- **Exceção de varredura de segredo**: registro versionado de um achado reconhecido como
  falso positivo, com a localização do achado e o motivo da exceção.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Uma máquina nova fica com todas as ferramentas do ciclo confirmadas
  rodando um único comando, sem nenhuma etapa manual adicional.
- **SC-002**: Rodar o comando de preparo da máquina uma segunda vez consecutiva produz o
  mesmo relatório de sucesso da primeira vez, sem nenhuma duplicação perceptível.
- **SC-003**: 100% das tentativas de introduzir um termo proibido em qualquer arquivo do
  repositório são detectadas antes de chegarem a ser mergeadas.
- **SC-004**: 100% dos problemas de portabilidade conhecidos introduzidos em um script
  shell do repositório são detectados antes de chegarem a ser mergeados.
- **SC-005**: Uma máquina com uma ferramenta abaixo da versão mínima recebe, na primeira
  execução do comando de preparo, um diagnóstico que identifica exatamente qual
  ferramenta e qual versão falta — sem precisar investigar log nenhum.
- **SC-006**: 100% das tentativas de introduzir um segredo em arquivo versionado do
  repositório são detectadas antes de chegarem a ser mergeadas, sem que o valor detectado
  apareça no relatório da checagem.
- **SC-007**: A lista de pré-requisitos da máquina do dev continua com os mesmos cinco
  itens depois da varredura de segredo entrar no ar — nenhuma ferramenta nova é exigida
  localmente.

## Delta Requirements

**Skip**: repositório novo, sem corpus `docs/specs/current/` ainda publicado — nenhum
comportamento hoje ativo do cockpit para esta feature alterar; é a primeira frente de
código do MVP (item 1 e item 6 do briefing) — agente-00c-feature-orchestrator,
2026-09-25.
