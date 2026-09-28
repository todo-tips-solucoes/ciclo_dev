#!/usr/bin/env bash
# instalar.sh — preparo de máquina para o ciclo de desenvolvimento do cockpit-dev.
#
# Pipeline sequencial por gates de sete etapas (ver
# docs/specs/esqueleto-e-instalador/plan.md §Arquitetura de `instalar.sh`):
# pré-requisitos, cstk (presente, responde, piso mínimo + release mais nova),
# catálogo de skills do toolkit, skills do cockpit, plugins. A partir da
# emenda 1.1.0 (Princípio IV) o script só VERIFICA e IMPRIME — nenhuma etapa
# instala nem atualiza terceiro; a única escrita é a cópia das skills do
# próprio cockpit em ~/.claude/skills/ (etapa 6, FR-011).
#
# Uso: ./instalar.sh   (sem parâmetros — não há variante)
#
# Códigos de saída (contracts/cli.md):
#   0  nenhum item bloqueante falhou
#   1  algum item bloqueante falhou — o pipeline para nele (sequencial por
#      gates); o relatório cobre só os itens avaliados até ali
#   2  pré-requisito ausente ou abaixo do mínimo, HOME indefinido ou
#      execução como root/sudo (recusadas antes de qualquer etapa)
#   3  sem permissão de escrita em ~/.claude/skills/
set -euo pipefail

if [ -z "${HOME:-}" ]; then
  echo "instalar.sh: HOME não definido — não há onde verificar/instalar skills (~/.claude/skills/)." >&2
  exit 2
fi
# cstk instalado pela pessoa vai para ~/.local/bin (README oficial) e pode não
# estar no PATH da sessão atual — sem isto, esta verificação reportaria
# "ausente" numa máquina onde o cstk já foi instalado, só porque o PATH do
# shell corrente não inclui ~/.local/bin. Puramente para detecção: o script
# não instala nada ali (emenda 1.1.0).
case ":$PATH:" in
  *":$HOME/.local/bin:"*|*":$HOME/.local/bin/:"*) LOCAL_BIN_JA_NO_PATH=true ;;
  *) LOCAL_BIN_JA_NO_PATH=false ;;
esac
export PATH="$HOME/.local/bin:$PATH"

CSTK_INSTALL_URL="https://github.com/JotJunior/cstk/releases/latest/download/install.sh"
CTX_MODE_REPO="mksglu/context-mode"
PONYTAIL_REPO="DietrichGebert/ponytail"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
  # 2, não 1: é recusa antes de qualquer etapa, como HOME e root — o código 1
  # promete um relatório que aqui não existe (review rodada 4).
  echo "instalar.sh: não consegui resolver a raiz do script." >&2
  exit 2
}

REPORT_LINHAS=()
REPORT_STATUS=()
REPORT_BLOQUEANTE=()
REPORT_EXECUTE=()

CSTK_VERSAO_INSTALADA=""
CSTK_MIN=""
PLUGIN_PRESENTE=""
PLUGIN_HABILITADO=""
PLUGIN_VERSAO=""

# --- utilidades -------------------------------------------------------

log_etapa_inicio() {
  printf 'Etapa %s/7: %s...\n' "$1" "$2"
}

log_etapa_fim() {
  printf 'Etapa %s/7: %s\n' "$1" "$2"
}

# dica_path — sufixo de aviso quando o cstk em uso vem de ~/.local/bin e esse
# diretório não estava no PATH original do shell.
dica_path() {
  [ "$LOCAL_BIN_JA_NO_PATH" = false ] || return 0
  case "$(command -v cstk 2>/dev/null || true)" in
    "$HOME/.local/bin/"*) printf ' — ~/.local/bin não está no PATH do seu shell; adicione-o para usar o cstk fora deste script' ;;
  esac
  return 0
}

# registrar_item <texto-completo-da-linha> <ok|aviso|falhou|pulada> <true|false-bloqueante> [comando(s)-Execute]
# O 4º argumento, quando presente, é uma ou mais linhas já formatadas como
# "Execute: ..." (ou "Execute (depois de inspecionar): ..."), separadas por
# newline literal — impressas indentadas sob o item no relatório final.
registrar_item() {
  REPORT_LINHAS+=("$1")
  REPORT_STATUS+=("$2")
  REPORT_BLOQUEANTE+=("$3")
  REPORT_EXECUTE+=("${4:-}")
}

# parar_se_bloqueado — sequencial por gates (FR-009, clarify Session
# 2026-09-28): a primeira etapa que registrou item bloqueante com "falhou"
# encerra a execução aqui; as etapas seguintes não rodam nem aparecem no
# relatório. Item não bloqueante (aviso, ou falhou não-bloqueante) segue.
parar_se_bloqueado() {
  local i
  for i in "${!REPORT_STATUS[@]}"; do
    if [ "${REPORT_STATUS[$i]}" = falhou ] && [ "${REPORT_BLOQUEANTE[$i]}" = true ]; then
      imprimir_relatorio_e_sair
    fi
  done
}

# versao_ge <instalada> <minima> — compara MAJOR.MINOR.PATCH numericamente,
# em bash puro (sem sort -V — research Decision 4). Campo ausente = 0.
versao_ge() {
  local inst="${1#v}" min="${2#v}"
  local -a a b
  IFS=. read -ra a <<<"$inst"
  IFS=. read -ra b <<<"$min"
  local i ai bi
  for i in 0 1 2; do
    # Só a parte numérica de cada campo: "0-rc1", "1\r" ou "3 # x" viravam
    # erro aritmético ou 'unbound variable' sob set -u (review rodada 1).
    ai="${a[i]:-0}"; ai="${ai%%[^0-9]*}"; ai="${ai:-0}"
    bi="${b[i]:-0}"; bi="${bi%%[^0-9]*}"; bi="${bi:-0}"
    if ((10#$ai > 10#$bi)); then return 0; fi
    if ((10#$ai < 10#$bi)); then return 1; fi
  done
  return 0
}

# --- etapa 1: pré-requisitos de máquina --------------------------------

checar_prerequisitos() {
  local faltantes=() ferramenta v
  for ferramenta in git gh node jq curl; do
    if ! command -v "$ferramenta" >/dev/null 2>&1; then
      faltantes+=("$ferramenta: ausente")
      continue
    fi
    case "$ferramenta" in
      git)
        # `|| true`: saída sem x.y.z não pode matar o script sob pipefail
        # antes do relatório (review rodada 1); vazio vira pré-requisito falho.
        v="$(git --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)"
        if [ -z "$v" ]; then
          faltantes+=("git: versão não identificada na saída de 'git --version'")
        elif ! versao_ge "$v" "2.36"; then
          faltantes+=("git: versão $v encontrada, mínima exigida 2.36")
        fi
        ;;
      node)
        v="$(node --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)"
        if [ -z "$v" ]; then
          faltantes+=("node: versão não identificada na saída de 'node --version'")
        elif ! versao_ge "$v" "20"; then
          faltantes+=("node: versão $v encontrada, mínima exigida 20")
        fi
        ;;
    esac
  done
  if [ "${#faltantes[@]}" -gt 0 ]; then
    echo "Pré-requisitos ausentes ou abaixo do mínimo:" >&2
    local f
    for f in "${faltantes[@]}"; do
      echo "  - $f" >&2
    done
    exit 2
  fi
}

# pré-checagem de escrita (CHK010): cria e remove arquivo temporário em
# ~/.claude/skills/ — única área que este script escreve (FR-011, emenda
# 1.1.0) — antes de qualquer etapa escrever de verdade.
prechecar_escrita() {
  local area="$HOME/.claude/skills" tmp
  if ! mkdir -p "$area" 2>/dev/null; then
    echo "Sem permissão de escrita em: $area" >&2
    exit 3
  fi
  tmp="$area/.instalar-sh-teste-escrita.$$"
  if ! (: >"$tmp") 2>/dev/null; then
    echo "Sem permissão de escrita em: $area" >&2
    exit 3
  fi
  rm -f "$tmp"
}

etapa1_prerequisitos() {
  log_etapa_inicio 1 "verificando pré-requisitos de máquina"
  checar_prerequisitos
  prechecar_escrita
  registrar_item "Pré-requisitos de máquina" ok false
  log_etapa_fim 1 "concluída"
}

# --- etapas 2-4: cstk (presente, responde, piso + release mais nova) ---

# Verificar e imprimir, nunca instalar (emenda 1.1.0, Princípio IV): a etapa
# 2 não baixa nem executa o instalador oficial — só confere presença. A URL
# impressa é a mesma do one-liner do README, em dois passos (baixar para
# arquivo, inspecionar, executar); a forma canalizada direto para o shell
# não é impressa (A08 — research Decision 1/16).
etapa2_cstk_presente() {
  log_etapa_inicio 2 "verificando presença do cstk"
  if command -v cstk >/dev/null 2>&1; then
    registrar_item "cstk presente$(dica_path)" ok false
    log_etapa_fim 2 "concluída"
  else
    registrar_item "cstk presente — cstk não encontrado no PATH" falhou true \
      "Execute: curl -fsSL $CSTK_INSTALL_URL -o \"\$HOME/cstk-install.sh\"
Execute (depois de inspecionar): sh \"\$HOME/cstk-install.sh\""
    log_etapa_fim 2 "falhou"
  fi
}

etapa3_cstk_responde() {
  log_etapa_inicio 3 "conferindo se cstk responde"
  local saida status detalhe=""
  if saida="$(cstk --version 2>&1)"; then
    status=ok
  else
    status=falhou
    detalhe=" — cstk --version não respondeu"
  fi
  # Reproduz a saída nativa do cstk sem filtro (dec-036), mesmo tendo
  # capturado para conferir a versão logo abaixo. Saída vazia não vira linha
  # em branco no meio das etapas (review rodada 5).
  [ -n "$saida" ] && printf '%s\n' "$saida"
  CSTK_VERSAO_INSTALADA=""
  if [ "$status" = ok ]; then
    # `|| true`: saída sem x.y.z deixa a versão vazia e a etapa 4 registra
    # falha, em vez de pipefail matar o script sem relatório (review rodada 1).
    CSTK_VERSAO_INSTALADA="$(printf '%s' "$saida" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi
  registrar_item "cstk responde à checagem de versão${detalhe}" "$status" true
  log_etapa_fim 3 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
}

# ler_cstk_min — extrai CSTK_MIN de versoes.env sem `source` e sem morrer:
# tolera CRLF, `export`, espaços em volta do `=`, aspas e comentário inline;
# devolve vazio se o arquivo ou a chave faltarem (a etapa 4 decide o que
# fazer com vazio). Nunca aborta o script (review rodada 1: grep sob
# pipefail matava o instalador sem relatório e com exit code colidindo com 2).
ler_cstk_min() {
  local arq="$REPO_ROOT/versoes.env" v=""
  [ -f "$arq" ] || return 0
  # tr, não sed 's/\r$//': no BSD sed (macOS) o \r é um 'r' literal. tail -1:
  # mesma semântica de `source`, a última atribuição vale (review rodada 2).
  # O literal do piso vive só em versoes.env (Princípio IV) — nem aqui, nem
  # em comentário, nem em mensagem.
  v="$(tr -d '\r' < "$arq" \
    | grep -E '^[[:space:]]*(export[[:space:]]+)?CSTK_MIN[[:space:]]*=' \
    | tail -1 | cut -d= -f2- || true)"
  v="${v%%#*}"
  v="${v//\"/}"
  v="${v//\'/}"
  printf '%s' "$v" | tr -d '[:space:]'
}

# O piso (FR-004) é conferido contra a versão INSTALADA — sem self-update
# prévio (a etapa 2 já não instala nem atualiza nada). Só quando o piso é
# atendido a etapa consulta, também somente leitura, se há release mais nova
# (`cstk self-update --check`, rc 0 em dia / 10 há mais nova / outro erro —
# research Decision 16): release mais nova ou checagem indisponível avisam,
# sem bloquear; abaixo do piso bloqueia (Decision 12: aviso/falhou não-
# bloqueante precisa de status capturado explicitamente sob set -e).
etapa4_cstk_piso() {
  log_etapa_inicio 4 "conferindo piso mínimo do cstk"
  CSTK_MIN="$(ler_cstk_min)"
  local status detalhe execute=""
  if ! [[ "$CSTK_MIN" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    status=falhou
    detalhe="CSTK_MIN ausente ou inválido em versoes.env (lido: '${CSTK_MIN:-vazio}')"
  elif [ -z "$CSTK_VERSAO_INSTALADA" ]; then
    status=falhou
    detalhe="versão instalada desconhecida — etapa anterior falhou"
  elif versao_ge "$CSTK_VERSAO_INSTALADA" "$CSTK_MIN"; then
    status=ok
    detalhe="$CSTK_VERSAO_INSTALADA >= $CSTK_MIN"
    local saida rc=0
    saida="$(cstk self-update --check 2>&1)" || rc=$?
    case "$rc" in
      0) : ;; # em dia — ok, sem Execute (nada a fazer)
      10)
        status=aviso
        local latest
        latest="$(printf '%s' "$saida" | grep -oE 'latest:[^[:space:]]+' | cut -d: -f2- || true)"
        detalhe="$detalhe — release mais nova disponível: ${latest:-desconhecida}"
        execute="Execute: cstk self-update"
        ;;
      *)
        status=aviso
        detalhe="$detalhe — não foi possível verificar release mais nova"
        ;;
    esac
  else
    status=falhou
    detalhe="instalada $CSTK_VERSAO_INSTALADA, piso exigido $CSTK_MIN"
    execute="Execute: cstk self-update"
  fi
  registrar_item "Versão do cstk >= CSTK_MIN ($detalhe)" "$status" \
    "$([ "$status" = falhou ] && echo true || echo false)" "$execute"
  log_etapa_fim 4 "$([ "$status" = falhou ] && echo "falhou" || echo "concluída")"
}

# --- etapa 5: catálogo de skills do toolkit -----------------------------

# Verificar e imprimir, nunca instalar (emenda 1.1.0): catálogo ausente
# bloqueia (mesma classe de pré-requisito duro que "sem cstk" — FR-006);
# skill faltando ou artefato defasado, detectados só por `--dry-run`
# (research Decision 16), viram aviso não-bloqueante com o comando oficial
# impresso — nunca `cstk install`/`cstk update` reais.
etapa5_catalogo() {
  log_etapa_inicio 5 "verificando catálogo de skills do toolkit"
  if ! command -v cstk >/dev/null 2>&1; then
    registrar_item "Catálogo de skills do toolkit — cstk indisponível" falhou true
    log_etapa_fim 5 "falhou"
    return
  fi
  if [ ! -f "$HOME/.claude/skills/.cstk-manifest" ]; then
    registrar_item "Catálogo de skills do toolkit — manifest ausente" falhou true "Execute: cstk install"
    log_etapa_fim 5 "falhou"
    return
  fi
  local status=ok detalhe="" execute=""

  # O que falta: linhas "[dry-run] install: <nome>" em stderr (2>&1 captura
  # ambos); só nome plausível entra no comando impresso — um token com
  # hífen viraria flag na mão de quem copia (mesmo filtro do review rodada
  # 3-4 anterior à emenda).
  local saida rc=0 faltantes
  saida="$(cstk install --dry-run --yes </dev/null 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    status=aviso
    detalhe="não foi possível verificar o que falta ('cstk install --dry-run' rc=$rc)"
  else
    faltantes="$(printf '%s\n' "$saida" \
      | sed -n 's/.*\[dry-run\] install: *//p' \
      | grep -E '^[A-Za-z0-9][A-Za-z0-9._@-]*$' | tr '\n' ' ' || true)"
    faltantes="${faltantes% }"
    if [ -n "$faltantes" ]; then
      status=aviso
      detalhe="faltando: $faltantes"
      execute="Execute: cstk install $faltantes"
    fi
  fi

  # O que está defasado: resumo "updated: N" de `cstk update --dry-run`
  # (research Decision 16/Adendo rodada 4).
  rc=0
  saida="$(cstk update --dry-run --yes </dev/null 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    status=aviso
    detalhe="${detalhe:+$detalhe; }não foi possível verificar defasagem ('cstk update --dry-run' rc=$rc)"
  else
    local n
    n="$(printf '%s\n' "$saida" | grep -oE '^updated: [0-9]+' | grep -oE '[0-9]+' || true)"
    if [ -n "$n" ] && [ "$n" -gt 0 ]; then
      status=aviso
      detalhe="${detalhe:+$detalhe; }defasado: $n item(ns)"
      if [ -n "$execute" ]; then
        execute="$execute
Execute: cstk update"
      else
        execute="Execute: cstk update"
      fi
    fi
  fi

  registrar_item "Catálogo de skills do toolkit${detalhe:+ — $detalhe}" "$status" false "$execute"
  log_etapa_fim 5 "concluída"
}

# --- etapa 6: skills do cockpit -----------------------------------------

# Idempotência com aviso, nunca sobrescrita silenciosa (research Decision 14):
# ausente → copia; idêntico → no-op; diverge → avisa e atualiza mesmo assim.
# Única escrita do instalador (FR-007, FR-011) — a emenda 1.1.0 não muda
# esta etapa.
etapa6_skills_cockpit() {
  log_etapa_inicio 6 "provisionando skills do cockpit"
  local origem="$REPO_ROOT/skills"
  if [ ! -d "$origem" ]; then
    registrar_item "Skills do cockpit — diretório skills/ ainda não existe" pulada false
    log_etapa_fim 6 "pulada"
    return
  fi
  # Guarda: symlink pendurado ou arquivo no lugar de ~/.claude/skills fazia o
  # mkdir falhar e o script morrer sem relatório (review rodada 2).
  if ! mkdir -p "$HOME/.claude/skills" 2>/dev/null || [ ! -d "$HOME/.claude/skills" ]; then
    registrar_item "Skills do cockpit — ~/.claude/skills não é um diretório gravável" falhou true
    log_etapa_fim 6 "falhou"
    return
  fi
  # `diff` não está na lista de pré-requisitos (FR-001) e é o que decide
  # "idêntica vs divergente". Sem ele, o ramo de igualdade nunca era tomado e
  # TODA execução reescrevia a skill avisando "edição local divergente" —
  # idempotência falsa (FR-010). Melhor pular e dizer por quê (review rodada 5).
  if ! command -v diff >/dev/null 2>&1; then
    registrar_item "Skills do cockpit — 'diff' não encontrado; sem ele não dá para comparar com o que já está instalado" pulada false
    log_etapa_fim 6 "pulada"
    return
  fi
  local instaladas=0 divergentes="" falhas="" sobras="" skill_dir nome destino novo velho resto status
  for skill_dir in "$origem"/*/; do
    [ -d "$skill_dir" ] || continue
    nome="$(basename "$skill_dir")"
    destino="$HOME/.claude/skills/$nome"
    # `.novo.*` é cópia parcial sem valor: pode sair. `.antigo.*` pode ser a
    # ÚNICA cópia da edição local do dev, se uma execução anterior falhou no
    # meio da troca — nunca apagar automaticamente, só avisar (review rodada
    # 4). Best-effort: remoção que falha não pode matar o script (set -e).
    rm -rf -- "$destino".novo.* 2>/dev/null || true
    for resto in "$destino".antigo.*; do
      [ -e "$resto" ] || continue
      echo "Aviso: $resto sobrou de uma troca interrompida e pode conter sua edição local — confira e remova à mão." >&2
      # Também no relatório: o aviso em stderr some no scrollback e a pendência
      # é permanente (o Claude Code lê a sobra como skill) — review rodada 5.
      sobras="$sobras $(basename "$resto")"
    done
    if [ ! -e "$destino" ] && [ ! -L "$destino" ]; then
      if cp -r "$skill_dir" "$destino"; then instaladas=$((instaladas + 1)); else falhas="$falhas $nome"; fi
    elif [ -d "$destino" ] && diff -rq "$skill_dir" "$destino" >/dev/null 2>&1; then
      : # já atualizada — nada a fazer
    else
      # Diverge, ou existe sem ser diretório (arquivo, symlink pendurado —
      # antes caía em "ausente" e o cp falhava para sempre). Espelho, não
      # sobreposição: cp -r nunca remove arquivo que saiu da origem (SC-002,
      # review rodada 1). Troca atômica: copia para um irmão temporário e só
      # então substitui — se a cópia falhar no meio, a versão local continua
      # intacta (review rodada 2).
      echo "Aviso: ~/.claude/skills/$nome tem edição local divergente — substituindo pela versão do cockpit." >&2
      # Nomes únicos por criação atômica, não por PID: com um `.antigo.<pid>`
      # de execução interrompida ainda no lugar, a reutilização do PID fazia
      # `mv "$destino" "$velho"` aninhar DENTRO da sobra e o `rm -rf` seguinte
      # apagava a edição local que o aviso prometeu preservar (review rodada
      # 5). O `rmdir` devolve o nome livre, já reservado.
      if ! novo="$(mktemp -d "$destino.novo.XXXXXX")" || ! rmdir "$novo"; then
        falhas="$falhas $nome"
        continue
      fi
      if ! velho="$(mktemp -d "$destino.antigo.XXXXXX")" || ! rmdir "$velho"; then
        falhas="$falhas $nome"
        continue
      fi
      # Duas renomeações: o destino só deixa de existir no instante do `mv`, e
      # se o segundo falhar a versão local volta. Antes era `rm -rf destino &&
      # mv`: um `rm` parcial (subdiretório sem escrita, arquivo em uso no WSL)
      # deixava o dev sem a versão local E sem a nova (review rodada 3).
      if cp -r "$skill_dir" "$novo" \
         && mv "$destino" "$velho" \
         && { mv "$novo" "$destino" \
              || { mv "$velho" "$destino" \
                   || echo "ERRO: a versão local de $nome ficou em $velho — a troca falhou nos dois sentidos; mova-a de volta à mão." >&2
                   false; }; }; then
        # A troca já aconteceu: a skill está correta. Remover a cópia antiga é
        # limpeza — se falhar (diretório sem permissão de escrita), avisa e
        # segue; matar o script aqui deixaria o dev sem relatório algum.
        if ! rm -rf -- "$velho" 2>/dev/null; then
          echo "Aviso: não consegui remover a cópia anterior em $velho — remova-a à mão (o Claude Code a leria como skill)." >&2
        fi
        divergentes="$divergentes $nome"
      else
        rm -rf -- "$novo" 2>/dev/null || true
        falhas="$falhas $nome"
      fi
    fi
  done
  status=ok
  [ -z "$falhas" ] || status=falhou
  # Bloqueante quando FALHA de verdade (FR-007 é um MUST); `pulada`, com o
  # diretório skills/ ainda inexistente, segue não-bloqueante (review rodada 4).
  registrar_item "Skills do cockpit ($instaladas instalada(s); substituídas com edição local avisada:${divergentes:- nenhuma}${falhas:+; falhou:$falhas}${sobras:+; sobras de troca interrompida a remover à mão:$sobras})" "$status" \
    "$([ "$status" = ok ] && echo false || echo true)"
  log_etapa_fim 6 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
}

# --- etapa 7: plugins ----------------------------------------------------

marketplace_registrado() {
  claude plugin marketplace list --json 2>/dev/null |
    jq -e --arg n "$1" '[.[] | select(.name==$n)] | length > 0' >/dev/null 2>&1
}

# plugin_info <id> — somente leitura (`claude plugin list --json`, campos
# .id/.scope/.enabled/.version — research Decision 16). Preenche
# PLUGIN_PRESENTE/PLUGIN_HABILITADO/PLUGIN_VERSAO; nunca instala/atualiza.
plugin_info() {
  local id="$1" json
  json="$(claude plugin list --json 2>/dev/null)" || json="[]"
  PLUGIN_PRESENTE=false
  PLUGIN_HABILITADO=false
  PLUGIN_VERSAO=""
  if printf '%s' "$json" | jq -e --arg id "$id" '[.[] | select(.id==$id and .scope=="user")] | length > 0' >/dev/null 2>&1; then
    PLUGIN_PRESENTE=true
    PLUGIN_HABILITADO="$(printf '%s' "$json" | jq -r --arg id "$id" '[.[] | select(.id==$id and .scope=="user")][0].enabled')"
    PLUGIN_VERSAO="$(printf '%s' "$json" | jq -r --arg id "$id" '[.[] | select(.id==$id and .scope=="user")][0].version')"
  fi
}

# verificar_plugin <plugin> <marketplace> <origem-github> <bloqueante> —
# decide por plugin, não em bloco (CHK011): presente e habilitado → ok, sem
# comando impresso (Decision 16 — não há sinal somente leitura de
# "desatualizado", não se afirma o que não se sabe); ausente → Execute com
# marketplace add (só se o marketplace também faltar) + install; desabilitado
# → Execute enable. Nunca `-y`/`--accept-command`: comando declarado pelo
# marketplace exige confirmação humana (plan.md §Superfície de Segurança).
verificar_plugin() {
  local plugin="$1" marketplace="$2" origem="$3" bloqueante="$4"
  local id="${plugin}@${marketplace}" status execute="" texto
  plugin_info "$id"
  if [ "$PLUGIN_PRESENTE" = true ] && [ "$PLUGIN_HABILITADO" = true ]; then
    status=ok
    texto="Plugin $plugin (${PLUGIN_VERSAO:-versão desconhecida})"
  elif [ "$PLUGIN_PRESENTE" = true ]; then
    status=falhou
    texto="Plugin $plugin — desabilitado"
    execute="Execute: claude plugin enable $plugin -s user"
  else
    status=falhou
    texto="Plugin $plugin — ausente"
    if marketplace_registrado "$marketplace"; then
      execute="Execute: claude plugin install $id -s user"
    else
      execute="Execute: claude plugin marketplace add $origem
Execute: claude plugin install $id -s user"
    fi
  fi
  if [ "$status" = falhou ] && [ "$bloqueante" = false ]; then
    texto="$texto (não bloqueante)"
  fi
  registrar_item "$texto" "$status" "$([ "$status" = falhou ] && echo "$bloqueante" || echo false)" "$execute"
}

etapa7_plugins() {
  log_etapa_inicio 7 "verificando plugins"
  # O CLI claude não é pré-requisito de máquina (Princípio VII), mas sem ele
  # a etapa inteira falha: nomear a causa no relatório em vez de deixar um
  # "command not found" engolido (review rodada 1).
  if ! command -v claude >/dev/null 2>&1; then
    registrar_item "Plugin context-mode — CLI claude não encontrada no PATH" falhou true
    registrar_item "Plugin ponytail — CLI claude não encontrada no PATH (não bloqueante)" falhou false
    log_etapa_fim 7 "falhou"
    return
  fi
  local n status_cm
  n=${#REPORT_STATUS[@]}
  verificar_plugin "context-mode" "context-mode" "$CTX_MODE_REPO" true
  status_cm="${REPORT_STATUS[$n]}"
  verificar_plugin "ponytail" "ponytail" "$PONYTAIL_REPO" false
  log_etapa_fim 7 "$([ "$status_cm" = ok ] && echo "concluída" || echo "falhou")"
}

# --- relatório final e código de saída (FR-009, FR-012 via contracts/cli.md) --

imprimir_relatorio_e_sair() {
  echo
  echo "Relatório de preparo da máquina:"
  local i linha
  for i in "${!REPORT_LINHAS[@]}"; do
    printf '  %-10s%s\n' "[${REPORT_STATUS[$i]}]" "${REPORT_LINHAS[$i]}"
    if [ -n "${REPORT_EXECUTE[$i]}" ]; then
      while IFS= read -r linha; do
        printf '            %s\n' "$linha"
      done <<<"${REPORT_EXECUTE[$i]}"
    fi
  done
  for i in "${!REPORT_STATUS[@]}"; do
    if [ "${REPORT_STATUS[$i]}" = falhou ] && [ "${REPORT_BLOQUEANTE[$i]}" = true ]; then
      exit 1
    fi
  done
  exit 0
}

main() {
  if [ "$(id -u)" -eq 0 ]; then
    echo "instalar.sh recusa rodar como root/sudo — o alvo é ~/.claude/skills/ do próprio usuário." >&2
    exit 2
  fi
  etapa1_prerequisitos; parar_se_bloqueado
  etapa2_cstk_presente; parar_se_bloqueado
  etapa3_cstk_responde; parar_se_bloqueado
  etapa4_cstk_piso; parar_se_bloqueado
  etapa5_catalogo; parar_se_bloqueado
  etapa6_skills_cockpit; parar_se_bloqueado
  etapa7_plugins; parar_se_bloqueado
  imprimir_relatorio_e_sair
}

main "$@"
