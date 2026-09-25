# Security Checklist: Esqueleto do cockpit-dev e instalador de máquina

**Purpose**: Validar a qualidade dos requisitos de segurança desta frente — foco na
varredura de segredo no CI (job `gitleaks`, FR-019/020/021, block-001/dec-023) e na
superfície de execução de código de terceiro (`instalar.sh`, CI). Não valida
implementação (o job `segredos` ainda não existe no repositório — plan.md é o desenho).
**Created**: 2026-09-25
**Feature**: [spec.md](../spec.md) · [plan.md](../plan.md)

## Completude de Requisitos

- [x] CHK001 - As classes de segredo cobertas pela varredura estão explicitamente
      listadas (credencial, token, chave privada, string de conexão), em vez de um
      termo genérico "segredo"? [Completude, Spec §FR-019] {auto}
- [x] CHK002 - O formato e a granularidade de registro de uma exceção de varredura
      estão especificados (arquivo, chave, campos)? [Completude, Spec Key Entities;
      Data-model §Entity Exceção de varredura de segredo] {auto}

## Clareza de Requisitos

- [x] CHK003 - "Sem reproduzir o valor detectado" (FR-019) está amarrado a um
      mecanismo operacional verificável, e não apenas a uma intenção de
      redação? [Clareza, Spec §FR-019; Plan §CI do cockpit — `--redact`
      obrigatório] {auto}
- [x] CHK004 - "Checagem automática do repositório" (FR-020) está mapeada a um
      mecanismo concreto único (job de CI), sem margem para leitura de que poderia
      rodar em outro ponto do ciclo (ex.: hook local)? [Clareza, Spec §FR-020; Plan
      §CI do cockpit — três jobs em `pull_request`/`push`] {auto}

## Consistência de Requisitos

- [ ] CHK005 - SC-006 afirma que "100% das tentativas de introduzir um segredo...
      são detectadas", em redação absoluta e sem qualificação. O próprio plan
      declara, como risco residual aceito, que "a varredura de segredo é regex +
      entropia, não prova de ausência" e que "segredo em formato não coberto
      passa". Uma leitura literal de SC-006 promete uma garantia mais forte do que
      a arquitetura desenhada entrega. [Consistência/Conflict, Spec §SC-006; Plan
      §Risco residual aceito item 3] {humano}
- [x] CHK006 - A garantia de agnosticismo (US2 — vazamento de nome próprio) e a
      garantia de varredura de segredo (US3 — credencial) estão claramente
      diferenciadas o suficiente para não serem lidas como o mesmo mecanismo?
      [Consistência, Spec Clarifications Q4; Plan §Nota de escopo do Princípio I]
      {auto}

## Qualidade de Critérios de Aceite

- [x] CHK007 - SC-006 é mensurável por um sinal objetivo (exit code não-zero +
      achado apontado por arquivo/linha), e não por uma afirmação subjetiva de
      "detectado"? [Mensurabilidade, Spec §SC-006; Contracts/cli.md §Códigos de
      saída — job `segredos`] {auto}
- [x] CHK008 - SC-007 ("a lista de pré-requisitos continua com os mesmos cinco
      itens") tem um mecanismo verificável de comprovação (a ferramenta de
      varredura só existe no job de CI, nunca em `instalar.sh`), e não é apenas
      uma afirmação de intenção? [Mensurabilidade, Spec §SC-007; Plan §Resolução
      de governança — tabela de restrições] {auto}

## Cobertura de Cenários

- [x] CHK009 - Existe cenário cobrindo o caminho de sucesso do job `segredos`
      (zero achados), além do caminho de falha? [Cobertura, Spec US3 Acceptance
      Scenario 4] {auto}
- [x] CHK010 - Existe cenário cobrindo o ciclo completo de uma exceção legítima —
      achado detectado, registro do fingerprint em `.gitleaksignore`, reabertura e
      sucesso subsequente? [Cobertura, Quickstart Scenario 10, passos 5-8] {auto}

## Cobertura de Edge Cases

- [x] CHK011 - O Edge Case de segredo detectado define explicitamente que o valor
      não aparece no relatório, e não só que a alteração é barrada? [Edge Case,
      Spec Edge Cases — "O que acontece quando um segredo real é detectado?"]
      {auto}
- [ ] CHK012 - O Edge Case de "arquivo binário com colisão de bytes" (Spec Edge
      Cases, US2) é declarado fora de escopo explicitamente só para a varredura de
      agnosticismo (`verificar-agnostico.sh`). Nem a spec nem o plan declaram o
      comportamento do job `segredos` diante de arquivo binário (gitleaks tenta
      decodificar/pula binário por padrão?) — a mesma pergunta não recebeu a mesma
      resposta explícita para a segunda varredura. [Gap, Spec Edge Cases; Plan §CI
      do cockpit] {auto}

## Requisitos Não-Funcionais

- [x] CHK013 - A não-reprodução do segredo no relatório (FR-019) tem controle de
      arquitetura correspondente e auditável, não apenas o texto do requisito?
      [NFR, Plan §Superfície de Segurança — linha `--redact`] {auto}
- [x] CHK014 - O comportamento de rede do binário de varredura (risco de
      exfiltração de conteúdo potencialmente sensível por uma ferramenta de
      terceiro) foi endereçado como requisito de desenho, e não deixado
      implícito? [NFR, Plan §Risco residual aceito item 4 — "NÃO VERIFICADO" +
      mitigação `permissions: contents: read`] {auto}

## Dependências e Premissas

- [x] CHK015 - A confiança no binário de terceiro (`gitleaks`) está condicionada a
      verificação de integridade (checksum), e não a download direto sem
      conferência? [Dependência, Plan §Controles adotados no desenho — linha
      "Ferramenta de varredura de terceiro executando no CI"] {auto}
- [x] CHK016 - A ausência de piso de versão do `gitleaks` em `versoes.env`
      (diferente do `CSTK_MIN` da ferramenta de implementação) está justificada
      explicitamente, para não ser lida como uma omissão? [Premissa,
      Contracts/cli.md §Instalação no job] {auto}

## Ambiguidades e Conflitos

- [x] CHK017 - FR-021 usa "reconhecidos como falso positivo" sem nomear um papel
      de aprovação separado — está claro que o mecanismo de reconhecimento é a
      própria revisão de PR já exigida pelo repositório, sem novo processo a
      definir? [Ambiguity, Spec Edge Cases — "revisável na própria PR"; Data-model
      §Entity Exceção de varredura de segredo] {auto}

## Notes

- Items `{auto}` já vêm resolvidos pelo agente (`[x]` com citação, ou marcador
  `[Gap]`/`[Conflict]`).
- Items `{humano}` ficam `[ ]` aguardando decisão do dono do produto.
- Gate `requirement-coverage.sh` rodado sobre `spec.md` — ver relatório da skill.
