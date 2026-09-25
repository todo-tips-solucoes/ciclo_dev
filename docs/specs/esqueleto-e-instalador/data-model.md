# Data Model: Esqueleto do cockpit-dev e instalador de máquina

A feature é stateless — não há banco, sessão nem persistência. O que existe são
três formatos de dado versionados em texto e uma estrutura em memória (o relatório
final). Este documento fixa o formato de cada um.

---

## Entity: Piso de versão do `cstk`

Chave única, versionada, que define a versão mínima aceitável do `cstk`.
Fonte de verdade: **`versoes.env` na raiz, e nenhum outro arquivo** (Princípio IV).

| Campo | Tipo | Constraints | Notes |
|-------|------|-------------|-------|
| `CSTK_MIN` | string SemVer `MAJOR.MINOR.PATCH` | obrigatória; sem prefixo `v` | O valor vive só aqui (Princípio IV) — nenhum outro arquivo o repete |

**Formato do arquivo**: `CHAVE=valor`, uma por linha; linhas iniciadas por `#` são
comentário. O arquivo já existe e já documenta a regra no próprio cabeçalho.

**Regras**:

- Lido por `instalar.sh` em runtime; **nunca escrito** por script.
- Nenhum outro arquivo do repositório pode conter o literal da versão — scripts,
  workflows e documentos referem-se à chave `CSTK_MIN`.
- O piso sobe por PR de trilha completa, quando o cockpit passa a depender de
  recurso de versão mais nova — não porque saiu release.

**Relacionamento**: `instalar.sh` (etapa 4) compara a saída de `cstk --version`
contra este valor, **depois** do `cstk self-update`.

---

## Entity: Pré-requisito de máquina

Ferramenta de base que precisa existir antes de qualquer instalação. O conjunto é
**fechado pelo Princípio VII** — acrescentar uma entrada exige emenda da
constituição, não edição de script.

| Campo | Tipo | Constraints | Notes |
|-------|------|-------------|-------|
| `comando` | string | deve resolver no `PATH` | o binário procurado |
| `versao_minima` | string SemVer ou vazio | vazio = só presença | decidido no `/clarify` (FR-001) |

**Instâncias** (a tabela completa, não um exemplo):

| `comando` | `versao_minima` | Origem do piso |
|-----------|-----------------|----------------|
| `git` | `2.36` | briefing §5 (Restrição técnica) |
| `node` | `20` | briefing §5 (Restrição técnica) |
| `gh` | — | só presença (`/clarify`, FR-001) |
| `jq` | — | só presença (`/clarify`, FR-001) |
| `curl` | — | só presença (`/clarify`, FR-001) |

**Regras**:

- A checagem avalia **todas** as entradas antes de reportar, e lista todos os
  itens ausentes ou abaixo do mínimo de uma vez (Edge Case da spec) — nunca para
  no primeiro.
- Comparação de versão por campo numérico, sem `sort -V` (research Decision 4).
- Versões MEDIDAS nesta máquina em 2026-09-25, todas conformes: `git` 2.55.0,
  `gh` 2.88.1, `node` v26.7.0, `jq` 1.8.1.

---

## Entity: Lista de termos proibidos

Coleção versionada de termos que não podem aparecer em nenhum arquivo do
repositório. Vive em `scripts/agnostico.lista`, **separada da lógica de varredura**
(FR-015, Princípio I) — editável sem tocar no script.

| Campo | Tipo | Constraints | Notes |
|-------|------|-------------|-------|
| termo | string literal | uma por linha; não-vazia após trim | casado como substring, sem distinção de maiúsculas |

**Formato**:

```
# Comentários começam com # e são ignorados.
# Linhas em branco são ignoradas.
# Um termo por linha. Casamento literal (grep -i -F), não regex.

nome-de-cliente-real
minhaempresa.com.br
```

**Regras**:

- Casamento por **substring literal, case-insensitive** — não expressão regular
  (research Decision 8). Um termo com `.` ou `-` não vira metacaractere.
- O próprio `scripts/agnostico.lista` é **excluído da varredura** (research
  Decision 7) — sem isso ele casaria contra si mesmo e a verificação falharia
  sempre.
- Lista vazia (ou só comentários) é estado válido: zero ocorrências, sucesso.
- O conteúdo inicial entregue por esta frente é o cabeçalho de comentários
  explicando o formato. Termos concretos entram quando houver o que barrar —
  e, por definição, nenhum nome real pode ser citado como exemplo neste
  repositório (Princípio I).

---

## Entity: Exceção de varredura de segredo

Registro versionado de um achado reconhecido como falso positivo (FR-021). Duas
formas, ambas na **raiz** do repositório e ambas lidas por default pela ferramenta
de varredura, sem flag no workflow (research Decision 15).

| Arquivo | Granularidade | Formato de uma entrada |
|---------|---------------|------------------------|
| `.gitleaksignore` | um achado específico | *fingerprint* `<arquivo>:<ruleID>:<linha>` (três campos, modo `dir`), cada um precedido de um comentário `# motivo: ...` |
| `.gitleaks.toml` | uma **classe** de achado | bloco `[[allowlists]]` (global) ou `[[rules.allowlists]]` (por regra), com `paths`, `regexes`, `stopwords` |

**Regras**:

- A exceção MUST viver no repositório e, portanto, aparecer no diff da PR que a
  introduz (FR-021). Não existe supressão por configuração fora do repositório.
- `.gitleaksignore` é a forma preferida para um achado pontual já revisado; o
  bloco `[[allowlists]]` é para um padrão recorrente (ex.: chave de exemplo que
  todo template carrega), porque uma entrada cobre todas as ocorrências presentes
  e futuras — e por isso mesmo exige justificativa mais forte na revisão.
- No modo `dir` (o que o CI usa) o *fingerprint* **não** inclui commit — são três
  campos, copiados do `Fingerprint:` que o gitleaks imprime com `-v`. O formato de
  quatro campos (com commit) é do modo `git` e nunca casa no `dir` (review rodadas 1-2).
- Estado inicial entregue por esta frente: os dois arquivos existem com apenas o
  cabeçalho de comentário explicando o formato — zero exceções ativas. Um
  repositório que nasce com exceções nasce com a garantia já perfurada.
- **Nota de estabilidade**: a documentação oficial marca o `.gitleaksignore` como
  recurso *experimental, sujeito a mudança*. Registrado aqui porque é a única
  ressalva conhecida sobre o formato (research Decision 15).

---

## Entity: Item de relatório *(estrutura em memória, não persistida)*

Acumulada por `instalar.sh` ao longo das sete etapas e impressa no final
(FR-009, cenário 7 da User Story 1).

| Campo | Tipo | Constraints | Notes |
|-------|------|-------------|-------|
| `nome` | string | não-vazio, pt-BR | rótulo legível da etapa |
| `status` | enum | `ok` \| `falhou` \| `pulada` | conjunto fechado |
| `detalhe` | string | pode ser vazio | motivo, versão encontrada, ou aviso |
| `bloqueante` | bool | — | se `true`, `status=falhou` derruba o comando |

### State Transitions

Cada etapa produz exatamente um item, e o status é terminal — não há revisão
posterior:

```
(etapa executa) → ok
                → falhou   → se bloqueante, saída final não-zero
                → pulada   → pré-condição ausente de forma legítima
                             (ex.: skills/ ainda não existe — Decision 13)
```

**Mapa de bloqueio** (FR-008, decidido no `/clarify`):

| Item | `bloqueante` |
|------|--------------|
| Pré-requisitos de máquina | sim — e encerra antes das demais etapas |
| `cstk` instalado/atualizado | sim |
| `cstk --version` responde | sim |
| Versão >= `CSTK_MIN` | sim |
| Catálogo (`cstk install`/`update`) | sim |
| Skills do cockpit | não |
| Plugin `context-mode` | **sim** (obrigatório por Princípio V) |
| Plugin `ponytail` | **não** (recomendado) |
