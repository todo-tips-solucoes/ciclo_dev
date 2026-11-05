# Feature Specification: rito-descoberta

**Feature**: `rito-descoberta`
**Created**: 2026-11-05
**Status**: Draft

> Fonte normativa: `docs/specs/rito-descoberta/decisoes-do-owner.md` (D1-D19, E1-E8). Esta spec parte
> dele e não reabre decisão. A emenda 2.0.0 do Princípio IV (`docs/constitution.md`, commit bf2eb06)
> já existe; aqui ela é apenas referenciada.
>
> Decisões de infraestrutura: N/A (frente só de Markdown e instruções; sem scheduler, sessão, chave
> ou estado persistente próprio).

## User Scenarios & Testing

### User Story 1 - Abrir uma frente nova pela Fase 0 (Priority: P1)

O owner pede uma frente nova. A skill `rito-descoberta` conduz a Fase 0: levanta as decisões com
opções e recomendação pelos cinco pilares (boas práticas, deduplicação, escalabilidade, performance,
segurança), cada uma validada pelo especialista do domínio, e fecha com o Gate 0. Só depois do OK
grava o `decisoes-do-owner.md` como 1º commit da worktree, instala hooks e MCP do `cstk` e entrega
um bloco único copiável para abrir a sessão e rodar o `/feature-00c`.

**Why this priority**: sem ela não há ponto de entrada para frentes novas; as demais histórias
dependem desse contrato.

**Independent Test**: rodar a skill numa frente fictícia e conferir os títulos exatos do arquivo
gerado, o bloco de caminhos não vazio e que nada foi escrito antes do OK além do histórico.

**Acceptance Scenarios**:

1. **Given** uma frente nova sem OK do owner, **When** a Fase 0 roda, **Then** nenhuma escrita
   ocorre, exceto o histórico declarado (D9).
2. **Given** o OK do Gate 0, **When** a skill conclui, **Then** o `decisoes-do-owner.md` é o 1º
   commit da worktree, com todas as seções de D11, "Irreversibilidade" preenchida ("nenhuma"
   explícito quando for o caso) e o bloco de caminhos com caminho literal ou `dir/**`.
3. **Given** a frente tem interface, **When** a Fase 0 roda, **Then** produz telas em HTML estático
   em `docs/specs/<frente>/telas/` (D6); sem interface, nenhuma tela é criada.
4. **Given** o bloco de caminhos ausente ou vazio, **When** o formato é validado, **Then** falha
   fechado e a Fase 0 não conclui.

---

### User Story 2 - Escolher o especialista certo por domínio (Priority: P1)

A skill traz o mapa papel→agente como seção (D2, D4), com a regra de proibidos. Por domínio da
decisão ela aciona um ou dois agentes (D3); o `security-auditor` entra sempre que a decisão toca
credencial, terceiro, permissão ou dado, e só valida. Pesquisa sem fonte oficial vai ao
`general-purpose` com o `ctx_fetch_and_index` obrigatório (D5).

**Why this priority**: a validação por especialista é o ganho central da Fase 0.

**Independent Test**: conferir que cada linha do mapa cita agente existente no catálogo e que
nenhum agente citado cai nas regras (a), (b) ou (c) de proibidos.

**Acceptance Scenarios**:

1. **Given** uma decisão de segurança, **When** a skill escolhe validadores, **Then** inclui o
   `security-auditor` como validador, não como decisor.
2. **Given** um agente com WebFetch, WebSearch, `mcp__`, navegador ou desktop, sem `tools:`, ou com
   Agent/Task, **When** candidato a papel, **Then** é recusado.
3. **Given** um papel sem agente elegível, **When** o mapa é aplicado, **Then** o papel volta ao
   owner como "papel sem agente".

---

### User Story 3 - Verificar plugins e instalar só sob a política (Priority: P2)

Antes de usar os agentes mapeados, a skill verifica os plugins na raiz onde serão usados (na
worktree quando for lá), classifica cada um (ok, desabilitado, ausente, desconhecido, SHA divergente)
e, apenas se a `origin/<base>` do projeto liga a linha "Instalação pelo agente", executa `install` e
`enable` sob a política D15-D19. Sem a linha ligada, só imprime os comandos (e o fallback por cópia
de D8).

**Why this priority**: entrega a emenda 2.0.0, mas a Fase 0 funciona imprimindo antes disso.

**Independent Test**: cobrir os cinco estados e o caso negativo (plugin fora da lista é recusado
antes do `install`), conforme S3.

**Acceptance Scenarios**:

1. **Given** estado "desconhecido" (listagem falhou), **When** a verificação roda, **Then** nada é
   executado.
2. **Given** SHA divergente, **When** a verificação roda, **Then** a regra de proibidos é
   reaplicada aos agentes mapeados e o reprovado vira "papel sem agente"; nunca `update`.
3. **Given** um item fora da lista de "Instalações previstas", flag diferente ou mudança de classe,
   **When** o agente tentaria instalar, **Then** para e pede OK (desvio).
4. **Given** os proibidos de D17 (script remoto, executor que baixa na hora, `-y`,
   `--accept-command`, `update`), **When** solicitados, **Then** nunca são executados.
5. **Given** a linha "Instalação pelo agente: desligada" na `origin/<base>`, **When** a skill
   precisa instalar, **Then** só imprime, e o agente nunca edita a linha.

---

### User Story 4 - Gate da Fase 0 e das instalações temporárias no rito-dev (Priority: P2)

O `rito-dev` passa a exigir a Fase 0 na trilha completa (dispensada em docs, trivial e hotfix com
incidente) e a barrar sem a skill instalada ("rito-descoberta ausente: rode instalar.sh"). Na Fase
11, antes do "Encerrar", checa que cada install temporário do log tem um uninstall posterior e que
o estado real bate com a linha de base. A description do `rito-dev` deixa de capturar o pedido de
frente nova antes da Fase 0.

**Why this priority**: sem o gate, a Fase 0 é opcional na prática.

**Independent Test**: ler o `SKILL.md` e o template e conferir o gate na Fase 1, a dispensa nos
três casos e o gate de ciclo de vida na Fase 11.

**Acceptance Scenarios**:

1. **Given** trilha completa sem skill instalada, **When** a Fase 1 inicia, **Then** o rito para
   com a mensagem de D10.
2. **Given** install temporário sem uninstall depois dele, **When** a Fase 11 roda o gate, **Then**
   o encerramento é impedido.
3. **Given** diferença entre o estado real e a linha de base, **When** a Fase 11 roda, **Then** o
   encerramento é impedido.

---

### User Story 5 - Descoberta e adoção documentadas (Priority: P3)

O `README.md` passa a começar o fluxo por `/rito-descoberta`. A semente de constitution para
projetos-alvo ganha a política e a linha literal "Instalação pelo agente: desligada" como padrão (D19).

**Why this priority**: documentação e padrão seguro; não bloqueia o núcleo.

**Independent Test**: grep da linha literal na semente e do fluxo no README.

**Acceptance Scenarios**:

1. **Given** a semente, **When** gerada para um projeto novo, **Then** contém a linha literal
   desligada.
2. **Given** projeto já ratificado, **When** roda `configurar.sh --atualizar`, **Then** a semente
   não é regravada (comportamento existente preservado).
3. **Given** o `README.md`, **When** lido, **Then** o fluxo começa por `/rito-descoberta`.
4. **Given** a frente concluída, **When** o registro SDD é conferido, **Then** spec, plan, research
   e tasks existem em `docs/specs/rito-descoberta/`.

---

### Edge Cases

- Linha de base de instalação ausente ou ilegível na Fase 11: o encerramento falha fechado.
- Plugin cuja pasta de cache sobra após o uninstall: o smoke S3 falha e o achado volta ao owner.
- Manifesto ou lockfile alterado fora da lista do Gate 0: desvio, para e pede OK.
- Diferença no fingerprint do histórico não explicada por comando declarado ou ruído conhecido:
  para e volta ao owner.
- Fonte oficial da CLI `claude plugin` indisponível: os campos factuais ficam como pendência e não
  são afirmados (Princípio VI).
- Instalação temporária global entre frentes paralelas: uma por vez.

## Requirements

### Functional Requirements

- **FR-001**: A skill `skills/rito-descoberta/SKILL.md` MUST conduzir a Fase 0 agnóstica de qualquer
  frente, com decisões em opções e recomendação pelos cinco pilares (E1, D1).
- **FR-002**: Cada decisão MUST ser validada pelo especialista do domínio conforme o mapa; fonte
  externa só via `ctx_*` (Princípio V) (E1, D3, D5).
- **FR-003**: A skill MUST gerar telas HTML estáticas em `docs/specs/<frente>/telas/` somente
  quando a frente tem interface (D6).
- **FR-004**: A skill MUST coletar smoke, irreversibilidade, caminhos previstos, dependências,
  instalações previstas e o Gate 0 com OK para todas as ondas (E1).
- **FR-005**: Nada MUST ser escrito antes do Gate 0, exceto o histórico declarado (D9).
- **FR-006**: Após o OK, a skill MUST gravar o `decisoes-do-owner.md` como 1º commit da worktree,
  rodar `cstk hooks install` e `cstk mcp install --project-path <worktree>` e entregar um bloco
  único copiável com `cd <worktree> && claude` e o `/feature-00c` (descrição de até 500 caracteres)
  (E1).
- **FR-007**: O `decisoes-do-owner.md` MUST seguir D11: títulos exatos, bloco de caminhos com caminho
  literal ou `dir/**` relativo à raiz, bloco ausente ou vazio falha fechado, "Irreversibilidade"
  sempre preenchida.
- **FR-008**: A skill MUST conter o mapa papel→agente como seção, registrando o id
  `plugin@voltagent-subagents`, a regra de proibidos (a)(b)(c) e o limite declarado de D14 (E2, D2,
  D4, D12).
- **FR-009**: A verificação de plugins MUST classificar ok, desabilitado, ausente, desconhecido e
  SHA divergente, filtrando por `scope == "project"` e `projectPath` igual à raiz de uso, e
  conferindo marketplace por nome e por `repo` (E3, D7).
- **FR-010**: Quando a política de instalação está ligada, o agente MUST executar `install` e
  `enable` somente para itens da seção "Instalações previstas", com o comando exato, escopo e
  SHA/versão listados; qualquer divergência MUST parar e pedir OK (D15, D16).
- **FR-011**: A skill MUST aplicar os canais e proibidos de D17 (plugin só com `agents/`, pacotes
  com versão exata e sem scripts, `marketplace add/remove` como temporária, proibição de script
  remoto, executores sob demanda, `-y`, `--accept-command`, `update`).
- **FR-012**: A skill MUST aplicar o ciclo de vida de D18 (classe vem da lista do Gate 0; temporária
  desinstalada ao fim do uso com `-s project` explícito, no máximo na Fase 11; o já instalado antes
  nunca é reinstalado, atualizado ou removido).
- **FR-013**: A skill MUST ler o valor de "Instalação pelo agente" na `origin/<base>`, nunca na
  worktree; sem a linha ligada, MUST apenas imprimir comandos (D19) e o fallback por cópia de D8,
  sem executá-lo.
- **FR-014**: A skill MUST manter o histórico da Fase 0 conforme D9 (log por frente e máquina,
  linha de base, diferenças por rodada, impressão digital das raízes listadas, `$HOME` como `~`).
  O ruído conhecido é a lista fechada de `contracts/historico.md` (seção "Ruído conhecido"); qualquer
  outra mudança sem comando declarado é desvio.
- **FR-015**: O `rito-dev` (`skills/rito-dev/SKILL.md` e `templates/docs/rito-dev.md.tmpl`) MUST ter
  o gate da Fase 0 na description e na Fase 1, obrigatório na trilha completa e dispensado em
  docs, trivial e hotfix com incidente, parando com "rito-descoberta ausente: rode instalar.sh"
  quando a skill falta (E4, D10).
- **FR-016**: O `rito-dev` MUST ter, na Fase 11 antes do "Encerrar", o gate de instalações
  temporárias: cada install temporário do log com uninstall posterior e estado real (id, escopo,
  projeto, versão, SHA, `enabledPlugins`, cache) igual à linha de base (D18).
- **FR-017**: O `README.md` MUST começar o fluxo por `/rito-descoberta` (E5).
- **FR-018**: O IV de `templates/docs/constitution.md.semente.tmpl` MUST trazer a política e a linha
  literal "Instalação pelo agente: desligada" como padrão (E8, D19).
- **FR-019**: A frente MUST tocar apenas os caminhos previstos e MUST NOT instalar nada durante a
  construção (Vigência); a emenda 2.0.0 de `docs/constitution.md` MUST ser apenas referenciada
  (E7).
- **FR-020**: Todo dado factual da CLI `claude plugin` (campos de `list --json`, `-s project`,
  `--prune`, `-y`, `--accept-command`, comportamento em worktree, fixação de ref) e de
  `--ignore-scripts`/`--require-hashes` MUST vir de fonte oficial via `ctx_fetch_and_index` na
  research do plan; até lá fica como pendência, nunca afirmado.
- **FR-022**: Ao retomar uma Fase 0 interrompida, a skill MUST ler o `.log` e o `.base` da frente,
  tirar nova foto e registrar a diferença como evento `rodada` ou `desvio`; a linha de base
  existente MUST NOT ser recriada.
- **FR-021**: O registro SDD completo (spec, plan, research, tasks) MUST viver em
  `docs/specs/rito-descoberta/` (E6).

### Key Entities

- **decisoes-do-owner.md**: registro normativo da Fase 0 por frente; seções de título exato, bloco de
  caminhos, instalações previstas, smoke, irreversibilidade e histórico.
- **Mapa papel→agente**: tabela domínio → agente (`plugin:agente`, ferramentas) com regra de proibidos.
- **Item de instalação**: comando de instalar, comando de desfazer, escopo, versão/SHA, classe
  (permanente ou temporária).
- **Linha de base**: fotografia do estado de plugins, marketplaces e raízes antes da frente, base
  do gate da Fase 11.
- **Histórico**: log só-acrescentado por frente e máquina.

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% dos títulos de seção de D11 presentes e exatos em um `decisoes-do-owner.md`
  produzido pela skill, verificáveis por busca textual.
- **SC-002**: 0 arquivos escritos entre o início da Fase 0 e o OK do Gate 0, exceto o histórico.
- **SC-003**: 100% das citações do mapa existem no catálogo no SHA registrado e passam nas regras de
  proibidos (S2).
- **SC-004**: Após o ciclo de smoke S3, a diferença entre o estado de plugins antes e depois é
  vazia (0 itens), incluindo a pasta de cache.
- **SC-005**: 100% dos installs temporários do log têm uninstall posterior no gate da Fase 11; 1
  faltando impede o encerramento. A chave de correspondência é a tripla `id`, `escopo` e `projeto`
  do log (`contracts/historico.md`, seção "Correspondência de `install` e `uninstall`").
- **SC-006**: 0 comandos de instalação executados fora da lista aprovada em um ciclo de smoke,
  inclusive no caso negativo.
- **SC-007**: Diff da PR contém somente caminhos previstos (0 arquivos fora).

## Delta Requirements

**Skip**: frente só de Markdown e instruções, sem comportamento ativo catalogado em `docs/specs/current/` para alterar — rito-descoberta, 2026-11-05

## Clarifications

### Session 2026-11-05

Nenhuma pergunta aberta: a spec deriva de `decisoes-do-owner.md` (normativo, D1-D19/E1-E8) e nao ha ambiguidade material. Dados factuais da CLI `claude plugin` seguem como pendencia roteada para a research do plan (FR-020).
