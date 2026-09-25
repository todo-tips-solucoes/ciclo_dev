#!/usr/bin/env bash
# instalar.sh — preparo de máquina para o ciclo de desenvolvimento do cockpit-dev.
#
# Pipeline linear de sete etapas (ver docs/specs/esqueleto-e-instalador/plan.md
# §Arquitetura de `instalar.sh`): pré-requisitos, cstk (instalar/atualizar,
# responde, piso mínimo), catálogo de skills do toolkit, skills do cockpit,
# plugins. Escreve exclusivamente em ~/.claude/ e ~/.local/ — nunca dentro de
# um diretório de projeto-alvo (Princípio VII, FR-011).
#
# Uso: ./instalar.sh   (sem parâmetros — não há variante)
#
# Códigos de saída (contracts/cli.md):
#   0  nenhum item bloqueante falhou
#   1  algum item bloqueante falhou
#   2  pré-requisito ausente ou abaixo do mínimo
#   3  sem permissão de escrita em ~/.claude/ e/ou ~/.local/
set -euo pipefail

CSTK_INSTALL_URL="https://github.com/JotJunior/cstk/releases/latest/download/install.sh"
CTX_MODE_REPO="mksglu/context-mode"
PONYTAIL_REPO="DietrichGebert/ponytail"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || exit 1

REPORT_LINHAS=()
REPORT_STATUS=()
REPORT_BLOQUEANTE=()

CSTK_VERSAO_INSTALADA=""
CSTK_MIN=""
PLUGIN_STATUS=""

# --- utilidades -------------------------------------------------------

log_etapa_inicio() {
  printf 'Etapa %s/7: %s...\n' "$1" "$2"
}

log_etapa_fim() {
  printf 'Etapa %s/7: %s\n' "$1" "$2"
}

# registrar_item <texto-completo-da-linha> <ok|falhou|pulada> <true|false-bloqueante>
registrar_item() {
  REPORT_LINHAS+=("$1")
  REPORT_STATUS+=("$2")
  REPORT_BLOQUEANTE+=("$3")
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
    ai="${a[i]:-0}"
    bi="${b[i]:-0}"
    if ((10#${ai:-0} > 10#${bi:-0})); then return 0; fi
    if ((10#${ai:-0} < 10#${bi:-0})); then return 1; fi
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
        v="$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
        if ! versao_ge "$v" "2.36"; then
          faltantes+=("git: versão $v encontrada, mínima exigida 2.36")
        fi
        ;;
      node)
        v="$(node --version)"
        v="${v#v}"
        if ! versao_ge "$v" "20"; then
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

# pré-checagem de escrita (CHK010): cria e remove arquivo temporário em cada
# área antes de qualquer etapa escrever de verdade — sem isso não há como
# garantir zero estado parcial (Acceptance Scenario 8/12).
prechecar_escrita() {
  local area tmp
  for area in "$HOME/.claude" "$HOME/.local"; do
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
  done
}

etapa1_prerequisitos() {
  log_etapa_inicio 1 "verificando pré-requisitos de máquina"
  checar_prerequisitos
  prechecar_escrita
  registrar_item "Pré-requisitos de máquina" ok false
  log_etapa_fim 1 "concluída"
}

# --- etapas 2-4: cstk (instalar/atualizar, responde, piso) -------------

etapa2_cstk_instalar_ou_atualizar() {
  log_etapa_inicio 2 "instalando/atualizando cstk"
  local status tmp
  if command -v cstk >/dev/null 2>&1; then
    # Saída nativa do cstk passa sem filtro (block-002 → dec-036) — nada de
    # >/dev/null aqui.
    if cstk self-update --yes; then status=ok; else status=falhou; fi
    registrar_item "cstk atualizado" "$status" true
  else
    tmp="$(mktemp)"
    if curl -fsSL "$CSTK_INSTALL_URL" -o "$tmp" && sh "$tmp"; then
      status=ok
    else
      status=falhou
    fi
    rm -f "$tmp"
    registrar_item "cstk instalado" "$status" true
  fi
  log_etapa_fim 2 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
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
  # capturado para conferir a versão logo abaixo.
  printf '%s\n' "$saida"
  CSTK_VERSAO_INSTALADA=""
  if [ "$status" = ok ]; then
    CSTK_VERSAO_INSTALADA="$(printf '%s' "$saida" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  fi
  registrar_item "cstk responde à checagem de versão${detalhe}" "$status" true
  log_etapa_fim 3 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
}

etapa4_cstk_piso() {
  log_etapa_inicio 4 "conferindo piso mínimo do cstk"
  CSTK_MIN="$(grep -E '^CSTK_MIN=' "$REPO_ROOT/versoes.env" | cut -d= -f2)"
  local status detalhe
  if [ -z "$CSTK_VERSAO_INSTALADA" ]; then
    status=falhou
    detalhe="versão instalada desconhecida — etapa anterior falhou"
  elif versao_ge "$CSTK_VERSAO_INSTALADA" "$CSTK_MIN"; then
    status=ok
    detalhe="$CSTK_VERSAO_INSTALADA >= $CSTK_MIN"
  else
    status=falhou
    detalhe="instalada $CSTK_VERSAO_INSTALADA, piso exigido $CSTK_MIN"
  fi
  registrar_item "Versão do cstk >= CSTK_MIN ($detalhe)" "$status" true
  log_etapa_fim 4 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
}

# --- etapa 5: catálogo de skills do toolkit -----------------------------

etapa5_catalogo() {
  log_etapa_inicio 5 "provisionando catálogo de skills do toolkit"
  local status
  if ! command -v cstk >/dev/null 2>&1; then
    registrar_item "Catálogo de skills do toolkit — cstk indisponível" falhou true
    log_etapa_fim 5 "falhou"
    return
  fi
  if [ -d "$HOME/.claude/skills" ] && [ -n "$(ls -A "$HOME/.claude/skills" 2>/dev/null)" ]; then
    if cstk update --yes; then status=ok; else status=falhou; fi
  else
    if cstk install --yes; then status=ok; else status=falhou; fi
  fi
  registrar_item "Catálogo de skills do toolkit" "$status" true
  log_etapa_fim 5 "$([ "$status" = ok ] && echo "concluída" || echo "falhou")"
}

# --- etapa 6: skills do cockpit -----------------------------------------

# Idempotência com aviso, nunca sobrescrita silenciosa (research Decision 14):
# ausente → copia; idêntico → no-op; diverge → avisa e atualiza mesmo assim.
etapa6_skills_cockpit() {
  log_etapa_inicio 6 "provisionando skills do cockpit"
  local origem="$REPO_ROOT/skills"
  if [ ! -d "$origem" ]; then
    registrar_item "Skills do cockpit — diretório skills/ ainda não existe" pulada false
    log_etapa_fim 6 "pulada"
    return
  fi
  mkdir -p "$HOME/.claude/skills"
  local instaladas=0 divergentes=0 skill_dir nome destino
  for skill_dir in "$origem"/*/; do
    [ -d "$skill_dir" ] || continue
    nome="$(basename "$skill_dir")"
    destino="$HOME/.claude/skills/$nome"
    if [ ! -d "$destino" ]; then
      cp -r "$skill_dir" "$destino"
      instaladas=$((instaladas + 1))
    elif diff -rq "$skill_dir" "$destino" >/dev/null 2>&1; then
      : # já atualizada — nada a fazer
    else
      echo "Aviso: ~/.claude/skills/$nome tem edição local divergente — atualizando mesmo assim." >&2
      cp -r "$skill_dir." "$destino/"
      divergentes=$((divergentes + 1))
    fi
  done
  registrar_item "Skills do cockpit ($instaladas instalada(s), $divergentes atualizada(s) com edição local avisada)" ok false
  log_etapa_fim 6 "concluída"
}

# --- etapa 7: plugins ----------------------------------------------------

marketplace_registrado() {
  claude plugin marketplace list --json 2>/dev/null |
    jq -e --arg n "$1" '[.[] | select(.name==$n)] | length > 0' >/dev/null 2>&1
}

plugin_instalado_user() {
  claude plugin list --json 2>/dev/null |
    jq -e --arg id "$1" '[.[] | select(.id==$id and .scope=="user")] | length > 0' >/dev/null 2>&1
}

# provisionar_plugin <plugin> <marketplace> <origem-github> — ausente instala,
# presente atualiza (mesmo padrão da etapa 2 com o cstk — CHK011). Nunca passa
# -y/--accept-command: comando declarado pelo marketplace exige confirmação
# humana (plan.md §Superfície de Segurança, controle ASI04/ASI05). Deixa a
# saída nativa do `claude` passar sem filtro (dec-036) — por isso o status é
# devolvido via $PLUGIN_STATUS, não via stdout (que aqui é do usuário, não
# um canal de retorno).
provisionar_plugin() {
  local plugin="$1" marketplace="$2" origem="$3" id
  id="${plugin}@${marketplace}"
  if ! marketplace_registrado "$marketplace"; then
    claude plugin marketplace add "$origem" || true
  fi
  if plugin_instalado_user "$id"; then
    if claude plugin update "$plugin" -s user; then PLUGIN_STATUS=ok; else PLUGIN_STATUS=falhou; fi
  else
    if claude plugin install "$id" -s user; then PLUGIN_STATUS=ok; else PLUGIN_STATUS=falhou; fi
  fi
}

etapa7_plugins() {
  log_etapa_inicio 7 "provisionando plugins"
  local status_cm status_pt
  provisionar_plugin "context-mode" "context-mode" "$CTX_MODE_REPO"
  status_cm="$PLUGIN_STATUS"
  registrar_item "Plugin context-mode" "$status_cm" true

  provisionar_plugin "ponytail" "ponytail" "$PONYTAIL_REPO"
  status_pt="$PLUGIN_STATUS"
  if [ "$status_pt" = ok ]; then
    registrar_item "Plugin ponytail" ok false
  else
    registrar_item "Plugin ponytail — não bloqueante" falhou false
  fi
  log_etapa_fim 7 "concluída"
}

# --- relatório final e código de saída (FR-009, FR-012 via contracts/cli.md) --

imprimir_relatorio_e_sair() {
  echo
  echo "Relatório de preparo da máquina:"
  local i
  for i in "${!REPORT_LINHAS[@]}"; do
    printf '  %-10s%s\n' "[${REPORT_STATUS[$i]}]" "${REPORT_LINHAS[$i]}"
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
    echo "instalar.sh recusa rodar como root/sudo — os alvos são ~/.claude/ e ~/.local/ do próprio usuário." >&2
    exit 1
  fi
  etapa1_prerequisitos
  etapa2_cstk_instalar_ou_atualizar
  etapa3_cstk_responde
  etapa4_cstk_piso
  etapa5_catalogo
  etapa6_skills_cockpit
  etapa7_plugins
  imprimir_relatorio_e_sair
}

main "$@"
