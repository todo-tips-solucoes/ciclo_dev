#!/usr/bin/env bash
# configurar.sh — configura um projeto-alvo para o ciclo do cockpit.
#
# Pergunta os parâmetros do ciclo (ou lê de um arquivo de respostas), grava
# `cockpit.config` na raiz do projeto-alvo, renderiza todo arquivo sob
# `templates/` por substituição literal de `{{CHAVE}}` e, por último,
# provisiona os guard hooks com `cstk hooks install`. Nunca instala nem
# atualiza terceiro (Princípio IV): só usa o `cstk` que a pessoa já instalou.
#
# Uso: ./configurar.sh [--projeto DIR] [--respostas ARQ] [--atualizar]
#                      [--forcar] [--ajuda]
#
# Contrato completo: docs/specs/configurar/contracts/cli.md
#
# Códigos de saída:
#   0  tudo concluído, inclusive hooks
#   1  erro de uso, projeto inválido, valor inválido, --atualizar sem config,
#      caminho que escapa do projeto (nada novo gravado)
#   2  placeholder residual, ou arquivo editado à mão mantido (config gravado;
#      nenhum template movido)
#   3  cstk ausente, sem versão reconhecível ou abaixo do piso (config e
#      templates gravados; comando oficial impresso)
#   4  `cstk hooks install` falhou (config e templates gravados)
set -euo pipefail

# Comparação byte a byte e classes [[:cntrl:]] determinísticas em qualquer
# máquina; acentos passam intactos como bytes.
export LC_ALL=C

COCKPIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || {
  echo "configurar.sh: não consegui resolver a raiz do script." >&2
  exit 1
}
REPO_ROOT="$COCKPIT_DIR"
# shellcheck source=scripts/lib/versao.sh
. "$COCKPIT_DIR/scripts/lib/versao.sh"

# Ordem fixa de gravação (data-model.md). URLs são as únicas opcionais.
CHAVES_ORDEM="PROJETO_NOME REPO_REMOTO BRANCH_INTEGRACAO BRANCH_PRODUCAO GERENCIADOR_PACOTES CMD_TYPECHECK CMD_LINT CMD_BUILD CMD_DEPLOY_INTEGRACAO CMD_DEPLOY_PRODUCAO URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO IDENTIDADES BOARD PRINCIPIO_III"
CHAVES_OPCIONAIS=" URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO "

RE_KV='^([A-Z][A-Z0-9_]*)=(.*)$'
RE_REPO='^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
RE_URL='^https?://[^[:space:]]+$'
RE_IDENT='^(.+)[[:space:]]+<([^<>]+)>$'

RAIZ=""
STG=""
MODO=interativo # interativo | respostas | atualizar
FORCAR=false
DESCONHECIDAS=""
TPL_ORIG=()
DEST_REL=()

# Variáveis de ambiente não são fonte de valor: garante que CFG_* do ambiente
# do usuário nunca alimente o render.
for _k in $CHAVES_ORDEM; do unset "CFG_$_k" "CFGSET_$_k"; done

erro() { printf '%s\n' "$*" >&2; }
aviso() { printf 'Aviso: %s\n' "$*" >&2; }
log() { printf '%s\n' "$*"; }
falhar() { erro "$*"; exit 1; }

limpar() {
  if [ -n "$STG" ] && [ -d "$STG" ]; then rm -rf "$STG"; fi
}
trap limpar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

uso() {
  cat <<'EOF'
Uso: ./configurar.sh [--projeto DIR] [--respostas ARQ] [--atualizar] [--forcar] [--ajuda]

Configura um projeto-alvo para o ciclo do cockpit: grava cockpit.config,
renderiza os templates e provisiona os guard hooks.

  --projeto DIR    raiz do projeto-alvo (topo de um repositório git);
                   padrão: diretório corrente
  --respostas ARQ  modo não interativo: valores lidos de ARQ (CHAVE=valor)
  --atualizar      sem perguntas: re-renderiza a partir do cockpit.config
  --forcar         sobrescreve arquivos editados à mão sem confirmação
  --ajuda          mostra este texto
EOF
}

# ---------------------------------------------------------------- valores ---

definido() { local n="CFGSET_$1"; [ "${!n:-}" = 1 ]; }
valor() { local n="CFG_$1"; printf '%s' "${!n-}"; }
setar() { printf -v "CFG_$1" '%s' "$2"; printf -v "CFGSET_$1" '%s' 1; }
desetar() { unset "CFG_$1" "CFGSET_$1"; }
chave_conhecida() { case " $CHAVES_ORDEM " in *" $1 "*) return 0 ;; esac; return 1; }
chave_opcional() { case "$CHAVES_OPCIONAIS" in *" $1 "*) return 0 ;; esac; return 1; }

# Remove um par envolvente de aspas simples (com '\'' interno) ou duplas; sem
# aspas, apara espaços das pontas.
desaspar() {
  local v="$1"
  if [ "${#v}" -ge 2 ] && [ "${v:0:1}" = "'" ] && [ "${v: -1}" = "'" ]; then
    v="${v:1:${#v}-2}"
    v="${v//"'\\''"/"'"}"
  elif [ "${#v}" -ge 2 ] && [ "${v:0:1}" = '"' ] && [ "${v: -1}" = '"' ]; then
    v="${v:1:${#v}-2}"
  else
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
  fi
  printf '%s' "$v"
}

# ler_kv ARQ — lê CHAVE=valor sem source/eval (research Decision 2). Última
# atribuição da chave vale; chave desconhecida é reportada em DESCONHECIDAS.
ler_kv() {
  local arq="$1" linha chave v n=0
  DESCONHECIDAS=""
  while IFS= read -r linha || [ -n "$linha" ]; do
    n=$((n + 1))
    linha="${linha%$'\r'}"
    linha="${linha#"${linha%%[![:space:]]*}"}"
    case "$linha" in '' | '#'*) continue ;; esac
    if ! [[ "$linha" =~ $RE_KV ]]; then
      erro "$arq:$n: linha fora do formato CHAVE=valor."
      return 1
    fi
    chave="${BASH_REMATCH[1]}"
    v="$(desaspar "${BASH_REMATCH[2]}")"
    if chave_conhecida "$chave"; then
      setar "$chave" "$v"
    else
      DESCONHECIDAS="$DESCONHECIDAS $chave"
    fi
  done <"$arq"
}

# validar_chave CHAVE VALOR — 0 se válido; senão diz o motivo em stderr, cita
# a chave e devolve 1. Avisos (nunca recusa) também saem em stderr.
validar_chave() {
  local chave="$1" v="$2" item nome email n=0
  if [[ "$v" == *[[:cntrl:]]* ]]; then
    erro "Valor inválido para $chave: contém quebra de linha ou caractere de controle."
    return 1
  fi
  case "$chave" in
    REPO_REMOTO)
      [[ "$v" =~ $RE_REPO ]] || { erro "Valor inválido para REPO_REMOTO: esperado org/repositório."; return 1; }
      ;;
    BRANCH_INTEGRACAO | BRANCH_PRODUCAO)
      case "$v" in '' | -* | *'@{'*) erro "Valor inválido para $chave: nome de branch inválido."; return 1 ;; esac
      git check-ref-format --branch "$v" >/dev/null 2>&1 \
        || { erro "Valor inválido para $chave: nome de branch inválido."; return 1; }
      ;;
    PROJETO_NOME | GERENCIADOR_PACOTES | CMD_*)
      [ -n "${v//[[:space:]]/}" ] || { erro "Valor inválido para $chave: não pode ser vazio."; return 1; }
      ;;
    URL_AMBIENTE_INTEGRACAO | URL_AMBIENTE_PRODUCAO)
      [ -z "$v" ] || [[ "$v" =~ $RE_URL ]] || { erro "Valor inválido para $chave: esperado URL http(s) sem espaços."; return 1; }
      ;;
    BOARD) : ;;
    PRINCIPIO_III)
      case "$v" in ligado | desligado) ;; *) erro "Valor inválido para PRINCIPIO_III: use ligado ou desligado."; return 1 ;; esac
      ;;
    IDENTIDADES)
      [ -n "$v" ] || { erro "Valor inválido para IDENTIDADES: informe ao menos uma identidade (nome:email)."; return 1; }
      local IFS=';' itens
      read -ra itens <<<"$v;"
      IFS=$' \t\n'
      for item in "${itens[@]}"; do
        [ -n "$item" ] || continue
        n=$((n + 1))
        nome="${item%%:*}"
        email="${item#*:}"
        if [ "$nome" = "$item" ] || [ -z "${nome//[[:space:]]/}" ] || [[ "$nome" == *[\<\>]* ]] \
          || [[ "$email" == *[:\<\>[:space:]]* ]] || ! [[ "$email" =~ ^[^@]+@[^@]+$ ]]; then
          erro "Valor inválido para IDENTIDADES: item '$item' fora do formato nome:email."
          return 1
        fi
        case "$email" in
          *@users.noreply.github.com) : ;;
          *) aviso "IDENTIDADES: o e-mail de '$nome' não é do tipo noreply; e-mail pessoal pode vazar em commits e templates." ;;
        esac
      done
      [ "$n" -ge 1 ] || { erro "Valor inválido para IDENTIDADES: informe ao menos uma identidade (nome:email)."; return 1; }
      ;;
  esac
  return 0
}

# validar_todos — aplica padrão de PRINCIPIO_III, exige as obrigatórias e
# valida todos os valores. Devolve 1 se algo falhar (mensagens já emitidas).
validar_todos() {
  local k rc=0
  definido PRINCIPIO_III || setar PRINCIPIO_III ligado
  for k in $CHAVES_ORDEM; do
    # Opcional vazia = ausente, como no cockpit.config gravado; senão o render
    # a resolveria e o --atualizar seguinte daria residual (FR-006).
    if chave_opcional "$k" && definido "$k" && [ -z "$(valor "$k")" ]; then desetar "$k"; fi
    if ! definido "$k"; then
      chave_opcional "$k" && continue
      erro "Chave obrigatória ausente: $k"
      rc=1
      continue
    fi
    validar_chave "$k" "$(valor "$k")" || rc=1
  done
  return "$rc"
}

# ------------------------------------------------------------- perguntas ---

# perguntar CHAVE TEXTO — repete até o valor ser válido; o valor atual (config
# existente) é o padrão. Nas opcionais, "-" limpa o valor.
perguntar() {
  local chave="$1" texto="$2" padrao="" resp dica=""
  definido "$chave" && padrao="$(valor "$chave")"
  chave_opcional "$chave" && dica=" (- para vazio)"
  [ "$chave" != BOARD ] || dica=" (- = sem board)"
  while :; do
    if [ -n "$padrao" ]; then printf '%s%s [%s]: ' "$texto" "$dica" "$padrao"; else printf '%s%s: ' "$texto" "$dica"; fi
    IFS= read -r resp || falhar "Entrada encerrada antes de responder $chave."
    if [ -z "$resp" ]; then resp="$padrao"; elif [ "$resp" = "-" ] && { chave_opcional "$chave" || [ "$chave" = BOARD ]; }; then resp=""; fi
    if validar_chave "$chave" "$resp"; then
      setar "$chave" "$resp"
      return 0
    fi
  done
}

# perguntar_identidades — ÚNICA função que conhece a forma da pergunta de
# identidades (FR-018 é proposta pendente; a troca por nome e e-mail
# separados fica restrita aqui). Entrada `nome <email>`, uma por vez; vazio
# encerra; grava `nome:email;...`.
perguntar_identidades() {
  local acumulado="" resp nome email atual="" primeira=true
  definido IDENTIDADES && atual="$(valor IDENTIDADES)"
  [ -z "$atual" ] || log "Identidades atuais: $atual"
  while :; do
    if $primeira && [ -n "$atual" ]; then
      printf 'Identidade de commit (nome <email>; vazio mantém as atuais): '
    elif [ -z "$acumulado" ]; then
      printf 'Identidade de commit (nome <email>): '
    else
      printf 'Outra identidade (nome <email>; vazio encerra): '
    fi
    IFS= read -r resp || falhar "Entrada encerrada antes de responder IDENTIDADES."
    if [ -z "$resp" ]; then
      if [ -n "$acumulado" ]; then break; fi
      if $primeira && [ -n "$atual" ]; then return 0; fi
      erro "Informe ao menos uma identidade."
      continue
    fi
    primeira=false
    if ! [[ "$resp" =~ $RE_IDENT ]]; then
      erro "Formato esperado: nome <email>."
      continue
    fi
    nome="${BASH_REMATCH[1]}"
    email="${BASH_REMATCH[2]}"
    nome="${nome%"${nome##*[![:space:]]}"}"
    if validar_chave IDENTIDADES "$nome:$email"; then
      acumulado="${acumulado:+$acumulado;}$nome:$email"
    fi
  done
  setar IDENTIDADES "$acumulado"
}

perguntar_todos() {
  perguntar PROJETO_NOME "Nome do projeto"
  perguntar REPO_REMOTO "Repositório remoto (org/repositório)"
  perguntar BRANCH_INTEGRACAO "Branch de integração"
  perguntar BRANCH_PRODUCAO "Branch de produção (pode ser igual à de integração)"
  perguntar GERENCIADOR_PACOTES "Gerenciador de pacotes"
  perguntar CMD_TYPECHECK "Comando de typecheck"
  perguntar CMD_LINT "Comando de lint"
  perguntar CMD_BUILD "Comando de build"
  perguntar CMD_DEPLOY_INTEGRACAO "Comando de deploy de integração"
  perguntar CMD_DEPLOY_PRODUCAO "Comando de deploy de produção"
  perguntar URL_AMBIENTE_INTEGRACAO "URL do ambiente de integração"
  perguntar URL_AMBIENTE_PRODUCAO "URL do ambiente de produção"
  perguntar_identidades
  perguntar BOARD "Board do projeto"
  definido PRINCIPIO_III || setar PRINCIPIO_III ligado
  perguntar PRINCIPIO_III "Princípio III (ligado ou desligado)"
}

# ------------------------------------------------------------ raiz e caminhos

resolver_raiz() {
  local dir="$1" topo
  [ -d "$dir" ] || falhar "Projeto inexistente: $dir"
  RAIZ="$(cd "$dir" && pwd -P)" || falhar "Não consegui resolver o projeto: $dir"
  topo="$(git -C "$RAIZ" rev-parse --show-toplevel 2>/dev/null)" \
    || falhar "$RAIZ não é um repositório git. Rode 'git init' ou aponte --projeto para a raiz de um repositório."
  topo="$(cd "$topo" && pwd -P)"
  [ "$topo" = "$RAIZ" ] \
    || falhar "$RAIZ não é a raiz do repositório git (raiz: $topo). Aponte --projeto para a raiz."
}

# destino_contido CAMINHO_ABSOLUTO — 0 se o pai (resolvido por pwd -P a partir
# do ancestral existente mais próximo) está dentro da raiz e o destino não é
# link simbólico nem diretório.
destino_contido() {
  local alvo="$1" anc real
  [ ! -L "$alvo" ] || return 1
  [ ! -d "$alvo" ] || return 1
  anc="$(dirname "$alvo")"
  while [ ! -d "$anc" ]; do
    [ ! -e "$anc" ] || return 1
    anc="$(dirname "$anc")"
  done
  real="$(cd "$anc" && pwd -P)" || return 1
  case "$real/" in "$RAIZ"/*) return 0 ;; esac
  return 1
}

# ------------------------------------------------------------------ hashes --

hash_arquivo() {
  local h
  if command -v sha256sum >/dev/null 2>&1; then
    h="$(sha256sum <"$1")"
  else
    h="$(shasum -a 256 <"$1")"
  fi
  printf '%s' "${h%% *}"
}

# manifesto_hash REL — hash registrado no manifesto (vazio se ausente).
manifesto_hash() {
  local arq="$RAIZ/.cockpit/manifesto.sha256" linha
  [ -f "$arq" ] || return 0
  while IFS= read -r linha || [ -n "$linha" ]; do
    if [ "${linha#*  }" = "$1" ]; then printf '%s' "${linha%%  *}"; return 0; fi
  done <"$arq"
  return 0
}

# ------------------------------------------------------------------ config --

escapar_aspas() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

gravar_config() {
  local alvo="$RAIZ/cockpit.config" k
  {
    printf '%s\n' "# cockpit.config — gerado por configurar.sh; pode ser editado à mão." \
      "# Rode ./configurar.sh --atualizar para re-renderizar os templates." ""
    for k in $CHAVES_ORDEM; do
      definido "$k" || continue
      chave_opcional "$k" && [ -z "$(valor "$k")" ] && continue
      printf "%s='%s'\n" "$k" "$(escapar_aspas "$(valor "$k")")"
    done
  } >"$STG/cockpit.config"
  destino_contido "$alvo" || falhar "Destino recusado (fora do projeto ou link simbólico): cockpit.config"
  if [ -f "$alvo" ] && cmp -s "$STG/cockpit.config" "$alvo"; then
    log "cockpit.config: inalterado"
  else
    mv -f "$STG/cockpit.config" "$alvo"
    log "cockpit.config: gravado"
  fi
}

# ------------------------------------------------------------------ templates

preparar_templates() {
  local tdir="$COCKPIT_DIR/templates" f rel d
  TPL_ORIG=()
  DEST_REL=()
  [ -d "$tdir" ] || return 0
  while IFS= read -r f; do
    rel="${f#"$tdir"/}"
    case "/$rel/" in */../*) falhar "Caminho de template recusado: $rel" ;; esac
    d="${rel%.tmpl}"
    case "$d" in
      cockpit.config | .cockpit/manifesto.sha256) falhar "Template recusado (destino reservado): $rel" ;;
    esac
    TPL_ORIG+=("$f")
    DEST_REL+=("$d")
  done < <(find "$tdir" -type f | sort)
}

# renderizar TEMPLATE SAIDA RESIDUAIS — substituição literal de {{CHAVE}} em
# awk: o valor entra por ENVIRON e por concatenação de substr(), nunca por
# gsub() nem -v, então &, \ e $ ficam literais (research Decision 1).
renderizar() {
  local defs="" k
  for k in $CHAVES_ORDEM; do definido "$k" && defs="$defs $k"; done
  (
    for k in $defs; do export "CFG_$k"; done
    awk -v definidas="$defs " -v resfile="$3" '
      {
        resto = $0; saida = ""
        while (match(resto, /\{\{[A-Z][A-Z0-9_]*\}\}/)) {
          nome = substr(resto, RSTART + 2, RLENGTH - 4)
          saida = saida substr(resto, 1, RSTART - 1)
          if (index(definidas, " " nome " ")) saida = saida ENVIRON["CFG_" nome]
          else { saida = saida substr(resto, RSTART, RLENGTH); print nome >> resfile }
          resto = substr(resto, RSTART + RLENGTH)
        }
        print saida resto
      }' "$1" >"$2"
  )
}

# aplicar_templates — renderiza tudo em staging; só move se não há residual
# nem conflito de edição local.
aplicar_templates() {
  local i n="${#TPL_ORIG[@]}" res rel nome resp
  local -a conflitos=()
  local escritos=0 inalterados=0 h_atual h_man dest
  : >"$STG/residuais"
  for ((i = 0; i < n; i++)); do
    : >"$STG/res"
    renderizar "${TPL_ORIG[i]}" "$STG/r$i" "$STG/res"
    if [ -s "$STG/res" ]; then
      rel="${TPL_ORIG[i]#"$COCKPIT_DIR/templates/"}"
      while IFS= read -r nome; do
        erro "Placeholder sem valor: {{$nome}} em $rel"
      done < <(sort -u "$STG/res")
      printf x >>"$STG/residuais"
    fi
  done
  if [ -s "$STG/residuais" ]; then
    erro "Nenhum template foi gravado. Defina as chaves acima no cockpit.config ou corrija o template."
    return 2
  fi
  for ((i = 0; i < n; i++)); do
    dest="$RAIZ/${DEST_REL[i]}"
    [ -e "$dest" ] || continue
    cmp -s "$STG/r$i" "$dest" && continue
    h_atual="$(hash_arquivo "$dest")"
    h_man="$(manifesto_hash "${DEST_REL[i]}")"
    [ -n "$h_man" ] && [ "$h_man" = "$h_atual" ] && continue
    if $FORCAR; then continue; fi
    if [ "$MODO" = interativo ]; then
      printf 'Arquivo editado localmente: %s. Sobrescrever? [s/N]: ' "${DEST_REL[i]}"
      IFS= read -r resp || resp=""
      case "$resp" in s | S | sim | SIM) continue ;; esac
    fi
    conflitos+=("${DEST_REL[i]}")
  done
  if [ "${#conflitos[@]}" -gt 0 ]; then
    for rel in "${conflitos[@]}"; do
      erro "Arquivo editado localmente, mantido: $rel. Use --forcar para sobrescrever."
    done
    erro "Nenhum template foi gravado."
    return 2
  fi
  for ((i = 0; i < n; i++)); do
    dest="$RAIZ/${DEST_REL[i]}"
    destino_contido "$dest" || falhar "Destino recusado (fora do projeto ou link simbólico): ${DEST_REL[i]}"
    if [ -f "$dest" ] && cmp -s "$STG/r$i" "$dest"; then
      inalterados=$((inalterados + 1))
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    destino_contido "$dest" || falhar "Destino recusado (fora do projeto ou link simbólico): ${DEST_REL[i]}"
    mv -f "$STG/r$i" "$dest"
    escritos=$((escritos + 1))
  done
  gravar_manifesto
  log "Templates: $escritos gravado(s), $inalterados inalterado(s)."
  return 0
}

gravar_manifesto() {
  local i n="${#DEST_REL[@]}" alvo="$RAIZ/.cockpit/manifesto.sha256" ord
  : >"$STG/manifesto"
  ord="$(for ((i = 0; i < n; i++)); do printf '%s\n' "${DEST_REL[i]}"; done | sort)"
  if [ -n "$ord" ]; then
    while IFS= read -r i; do
      printf '%s  %s\n' "$(hash_arquivo "$RAIZ/$i")" "$i" >>"$STG/manifesto"
    done <<<"$ord"
  fi
  destino_contido "$alvo" || falhar "Destino recusado (fora do projeto ou link simbólico): .cockpit/manifesto.sha256"
  mkdir -p "$RAIZ/.cockpit"
  destino_contido "$alvo" || falhar "Destino recusado (fora do projeto ou link simbólico): .cockpit/manifesto.sha256"
  if [ -f "$alvo" ] && cmp -s "$STG/manifesto" "$alvo"; then return 0; fi
  mv -f "$STG/manifesto" "$alvo"
}

# ------------------------------------------------------------------- hooks --

# provisionar_hooks — último passo. Só `cstk --version` e `cstk hooks install`
# (Princípio IV): ausência ou versão abaixo do piso imprime o comando oficial
# e devolve 3; falha do cstk devolve 4.
provisionar_hooks() {
  local min ver saida rc=0
  min="$(ler_cstk_min)"
  if ! command -v cstk >/dev/null 2>&1; then
    erro "cstk não encontrado no PATH — guard hooks não provisionados."
    log "Execute: curl -fsSL $CSTK_INSTALL_URL -o \"\$HOME/cstk-install.sh\""
    log "Execute (depois de inspecionar): sh \"\$HOME/cstk-install.sh\""
    log "Depois rode de novo: ./configurar.sh --atualizar --projeto \"$RAIZ\""
    return 3
  fi
  ver="$(cstk --version 2>&1 </dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
  if ! [[ "$min" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    erro "CSTK_MIN ausente ou inválido em versoes.env — guard hooks não provisionados."
    return 3
  fi
  if [ -z "$ver" ] || ! versao_ge "$ver" "$min"; then
    erro "cstk sem versão reconhecível ou abaixo do piso (${ver:-desconhecida} < $min) — guard hooks não provisionados."
    log "Execute: cstk self-update"
    log "Depois rode de novo: ./configurar.sh --atualizar --projeto \"$RAIZ\""
    return 3
  fi
  saida="$(cstk hooks install --project-path "$RAIZ" </dev/null 2>&1)" || rc=$?
  [ -z "$saida" ] || printf '%s\n' "$saida"
  if [ "$rc" -ne 0 ]; then
    erro "cstk hooks install falhou (código $rc)."
    return 4
  fi
  log "Guard hooks provisionados."
  return 0
}

# -------------------------------------------------------------------- main --

main() {
  local projeto="." respostas="" atualizar=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --projeto) [ $# -ge 2 ] || falhar "--projeto exige um diretório."; projeto="$2"; shift 2 ;;
      --respostas) [ $# -ge 2 ] || falhar "--respostas exige um arquivo."; respostas="$2"; shift 2 ;;
      --atualizar) atualizar=true; shift ;;
      --forcar) FORCAR=true; shift ;;
      --ajuda | -h) uso; exit 0 ;;
      *) erro "Opção desconhecida: $1"; uso >&2; exit 1 ;;
    esac
  done
  if $atualizar && [ -n "$respostas" ]; then falhar "--atualizar e --respostas não podem ser usados juntos."; fi
  if $atualizar; then MODO=atualizar; elif [ -n "$respostas" ]; then MODO=respostas; fi
  if [ "$MODO" = interativo ] && [ ! -t 0 ]; then
    falhar "Sem terminal para perguntar. Use --respostas ARQ (ou --atualizar) em execução não interativa."
  fi
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 \
    || falhar "Nem sha256sum nem shasum encontrados; um deles é necessário para o manifesto."

  log "Passo 1/5: projeto-alvo"
  resolver_raiz "$projeto"
  log "  $RAIZ"

  log "Passo 2/5: valores"
  local cfg="$RAIZ/cockpit.config" k
  case "$MODO" in
    atualizar)
      [ -f "$cfg" ] || falhar "Nenhum cockpit.config em $RAIZ. Rode ./configurar.sh sem --atualizar para criá-lo."
      ler_kv "$cfg" || exit 1
      ;;
    respostas)
      if [ ! -f "$respostas" ] || [ ! -r "$respostas" ]; then falhar "Arquivo de respostas ilegível: $respostas"; fi
      ler_kv "$respostas" || exit 1
      ;;
    interativo)
      if [ -f "$cfg" ]; then
        ler_kv "$cfg" || exit 1
        log "Valores atuais em $cfg (Enter aceita cada padrão):"
        for k in $CHAVES_ORDEM; do
          definido "$k" || continue
          if validar_chave "$k" "$(valor "$k")" 2>/dev/null; then log "  $k=$(valor "$k")"; else aviso "$k inválida no config atual; será perguntada de novo."; desetar "$k"; fi
        done
      fi
      perguntar_todos
      ;;
  esac
  [ -z "$DESCONHECIDAS" ] || aviso "chave(s) desconhecida(s) ignorada(s):$DESCONHECIDAS"
  validar_todos || exit 1

  preparar_templates
  local i
  for ((i = 0; i < ${#DEST_REL[@]}; i++)); do
    destino_contido "$RAIZ/${DEST_REL[i]}" || falhar "Destino recusado (fora do projeto ou link simbólico): ${DEST_REL[i]}"
  done
  destino_contido "$RAIZ/.cockpit/manifesto.sha256" || falhar "Destino recusado (fora do projeto ou link simbólico): .cockpit/manifesto.sha256"
  destino_contido "$cfg" || falhar "Destino recusado (fora do projeto ou link simbólico): cockpit.config"

  STG="$(mktemp -d "$RAIZ/.cockpit-tmp.XXXXXX")" || falhar "Não consegui criar diretório temporário em $RAIZ."

  log "Passo 3/5: cockpit.config"
  if [ "$MODO" = atualizar ]; then log "  mantido (--atualizar)"; else gravar_config; fi

  log "Passo 4/5: templates"
  local rc=0
  aplicar_templates || rc=$?
  [ "$rc" -eq 0 ] || exit "$rc"

  log "Passo 5/5: guard hooks"
  provisionar_hooks || rc=$?
  exit "$rc"
}

main "$@"
