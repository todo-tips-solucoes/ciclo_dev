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
#      caminho que escapa do projeto, falha de escrita
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
. "$COCKPIT_DIR/scripts/lib/versao.sh" || {
  echo "configurar.sh: scripts/lib/versao.sh ausente — rode a partir de um clone completo do cockpit." >&2
  exit 1
}

# Ordem fixa de gravação (data-model.md). URLs são as únicas opcionais.
CHAVES_ORDEM="PROJETO_NOME REPO_REMOTO BRANCH_INTEGRACAO BRANCH_PRODUCAO GERENCIADOR_PACOTES CMD_TYPECHECK CMD_LINT CMD_BUILD CMD_DEPLOY_INTEGRACAO CMD_DEPLOY_PRODUCAO URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO IDENTIDADES BOARD PRINCIPIO_III"
CHAVES_OPCIONAIS=" URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO "
CABECALHO_1="# cockpit.config — gerado por configurar.sh; pode ser editado à mão."
CABECALHO_2="# Rode ./configurar.sh --atualizar para re-renderizar os templates."
CABECALHO_EXTRAS="# Chaves não reconhecidas por configurar.sh, mantidas do arquivo anterior:"

RE_KV='^([A-Z][A-Z0-9_]*)=(.*)$'
# org/repositório genérico (Princípio I): nenhuma parte começa com '-' nem é
# '.' ou '..' (checado à parte em validar_chave).
RE_REPO='^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$'
RE_URL='^https?://[^[:space:]]+$'
RE_IDENT='^(.+)[[:space:]]+<([^<>]+)>$'
BOM=$'\xEF\xBB\xBF'
# Sequências UTF-8 bem formadas (sem overlong, sem surrogate, até U+10FFFF).
RE_UTF8=$'^([\x01-\x7F]|[\xC2-\xDF][\x80-\xBF]|\xE0[\xA0-\xBF][\x80-\xBF]|[\xE1-\xEC\xEE\xEF][\x80-\xBF][\x80-\xBF]|\xED[\x80-\x9F][\x80-\xBF]|\xF0[\x90-\xBF][\x80-\xBF][\x80-\xBF]|[\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]|\xF4[\x80-\x8F][\x80-\xBF][\x80-\xBF])*$'

RAIZ=""
STG=""
MODO=interativo # interativo | respostas | atualizar
FORCAR=false
DESCONHECIDAS=""
EXTRAS=()
COMENTARIOS_PERDIDOS=false
MOTIVO=""
TPL_ORIG=()
DEST_REL=()

# Variáveis de ambiente não são fonte de valor: garante que CFG_* do ambiente
# do usuário nunca alimente o render.
for _k in $CHAVES_ORDEM; do unset "CFG_$_k" "CFGSET_$_k"; done

erro() { printf '%s\n' "$*" >&2; }
aviso() { printf 'Aviso: %s\n' "$*" >&2; }
log() { printf '%s\n' "$*"; }
falhar() { erro "$*"; exit 1; }

# shellcheck disable=SC2317 # chamada indiretamente pelo trap EXIT
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
                   padrão: diretório corrente (na raiz do próprio cockpit,
                   --projeto é obrigatório)
  --respostas ARQ  modo não interativo: valores lidos de ARQ (CHAVE=valor)
  --atualizar      sem perguntas: re-renderiza a partir do cockpit.config
  --forcar         sobrescreve arquivos editados à mão sem confirmação
  --ajuda          mostra este texto
EOF
}

# Comando para rodar de novo, com caminhos citados com segurança.
comando_de_novo() {
  local c
  printf -v c '%q --atualizar --projeto %q' "$COCKPIT_DIR/configurar.sh" "$RAIZ"
  printf '%s' "$c"
}

# ---------------------------------------------------------------- valores ---

definido() { local n="CFGSET_$1"; [ "${!n:-}" = 1 ]; }
valor() { local n="CFG_$1"; printf '%s' "${!n-}"; }
setar() { printf -v "CFG_$1" '%s' "$2"; printf -v "CFGSET_$1" '%s' 1; }
desetar() { unset "CFG_$1" "CFGSET_$1"; }
chave_conhecida() { case " $CHAVES_ORDEM " in *" $1 "*) return 0 ;; esac; return 1; }
chave_opcional() { case "$CHAVES_OPCIONAIS" in *" $1 "*) return 0 ;; esac; return 1; }
aparar() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

# desaspar VALOR — lê o valor como `source` leria nas formas aceitas e deixa
# o resultado em DESASPAR_V (DESASPAR_COM=1 se havia comentário depois do
# valor). Formas: aspas simples (com '\'' interno), aspas duplas sem $, ` ou \,
# ou sem aspas (forma legada: espaços internos aceitos, sem $ ` \ ' "). Depois
# da aspa final só cabe espaço seguido de `# comentário`. Devolve 1 para
# qualquer outra forma (seria lida diferente por `source`).
desaspar() {
  local v resto q out=""
  DESASPAR_V=""
  DESASPAR_COM=""
  v="$(aparar "$1")"
  q="${v:0:1}"
  if [ "$q" = "'" ]; then
    resto="${v:1}"
    while :; do
      case "$resto" in *"'"*) ;; *) return 1 ;; esac
      out="$out${resto%%"'"*}"
      resto="${resto#*"'"}"
      if [ "${resto:0:3}" = "\\''" ]; then out="$out'"; resto="${resto:3}"; continue; fi
      break
    done
  elif [ "$q" = '"' ]; then
    resto="${v:1}"
    case "$resto" in *'"'*) ;; *) return 1 ;; esac
    out="${resto%%\"*}"
    resto="${resto#*\"}"
    [[ "$out" != *[\$\`\\]* ]] || return 1
  else
    case "$v" in *[[:space:]]'#'*) v="${v%%[[:space:]]#*}"; DESASPAR_COM=1 ;; esac
    v="$(aparar "$v")"
    [[ "$v" != *[\$\`\\\'\"]* ]] || return 1
    DESASPAR_V="$v"
    return 0
  fi
  case "$resto" in
    '') ;;
    [[:space:]]*)
      resto="$(aparar "$resto")"
      case "$resto" in '') ;; '#'*) DESASPAR_COM=1 ;; *) return 1 ;; esac
      ;;
    *) return 1 ;;
  esac
  DESASPAR_V="$out"
}

# ler_kv ARQ [extras] — lê CHAVE=valor sem source/eval (research Decision 2).
# Última atribuição da chave vale; chave desconhecida vai para DESCONHECIDAS.
# Com "extras", só coleta as linhas de chave desconhecida bem formadas
# (EXTRAS, com o `export` original) e sinaliza em COMENTARIOS_PERDIDOS o que a
# regravação não preserva; linha malformada é avisada e ignorada, nunca erro.
ler_kv() {
  local arq="$1" so_extras="${2:-}" linha orig chave bruto ok n=0
  DESCONHECIDAS=""
  [ -z "$so_extras" ] || EXTRAS=()
  while IFS= read -r linha || [ -n "$linha" ]; do
    n=$((n + 1))
    linha="${linha%$'\r'}"
    [ "$n" -ne 1 ] || linha="${linha#"$BOM"}"
    linha="$(aparar "$linha")"
    case "$linha" in
      '') continue ;;
      '#'*)
        case "$linha" in "$CABECALHO_1" | "$CABECALHO_2" | "$CABECALHO_EXTRAS") ;; *) COMENTARIOS_PERDIDOS=true ;; esac
        continue
        ;;
    esac
    orig="$linha"
    if [[ "$linha" =~ ^export[[:space:]]+(.*)$ ]]; then linha="${BASH_REMATCH[1]}"; fi
    if ! [[ "$linha" =~ $RE_KV ]]; then
      if [ -n "$so_extras" ]; then
        aviso "$arq:$n: linha fora do formato CHAVE=valor; não será mantida."
        continue
      fi
      erro "$arq:$n: linha fora do formato CHAVE=valor."
      return 1
    fi
    chave="${BASH_REMATCH[1]}"
    bruto="${BASH_REMATCH[2]}"
    ok=true
    desaspar "$bruto" || ok=false
    if [ "$orig" != "$linha" ] || [ -n "$DESASPAR_COM" ]; then COMENTARIOS_PERDIDOS=true; fi
    if ! chave_conhecida "$chave"; then
      case " $DESCONHECIDAS " in *" $chave "*) ;; *) DESCONHECIDAS="$DESCONHECIDAS $chave" ;; esac
      if [ -n "$so_extras" ]; then
        if $ok; then EXTRAS+=("$orig"); else aviso "$arq:$n: valor de $chave fora do formato; a linha não será mantida."; fi
      fi
      continue
    fi
    [ -z "$so_extras" ] || continue
    $ok || {
      erro "$arq:$n: valor de $chave com aspas fora do formato (use aspas simples: $chave='valor')."
      return 1
    }
    setar "$chave" "$DESASPAR_V"
  done <"$arq"
}

# normalizar_identidades — apara espaços de cada item de IDENTIDADES e das
# pontas de nome e e-mail.
normalizar_identidades() {
  local v out="" item nome email IFS=';' itens
  definido IDENTIDADES || return 0
  v="$(valor IDENTIDADES)"
  read -ra itens <<<"$v;"
  IFS=$' \t\n'
  for item in "${itens[@]}"; do
    item="$(aparar "$item")"
    [ -n "$item" ] || continue
    if [[ "$item" == *:* ]]; then
      nome="$(aparar "${item%%:*}")"
      email="$(aparar "${item#*:}")"
      item="$nome:$email"
    fi
    out="${out:+$out;}$item"
  done
  setar IDENTIDADES "$out"
}

# tem_controle VALOR — 0 se há quebra de linha, controle C0/DEL, controle C1
# (U+0080–U+009F), marca de direção de texto, separador de linha/parágrafo
# Unicode ou UTF-8 inválido. Tudo por bytes (LC_ALL=C), sem ferramenta externa.
tem_controle() {
  local v="$1"
  [[ "$v" == *[[:cntrl:]]* ]] && return 0
  [[ "$v" =~ $RE_UTF8 ]] || return 0
  [[ "$v" == *$'\xC2'[$'\x80'-$'\x9F']* ]] && return 0
  [[ "$v" == *$'\xD8\x9C'* ]] && return 0
  [[ "$v" == *$'\xE2\x80'[$'\x8E\x8F\xA8\xA9\xAA'-$'\xAE']* ]] && return 0
  [[ "$v" == *$'\xE2\x81'[$'\xA6'-$'\xA9']* ]] && return 0
  return 1
}

# validar_chave CHAVE VALOR — 0 se válido; senão diz o motivo em stderr, cita
# a chave e devolve 1. Avisos (nunca recusa) também saem em stderr.
validar_chave() {
  local chave="$1" v="$2" item nome email n=0 parte
  if tem_controle "$v"; then
    erro "Valor inválido para $chave: contém quebra de linha, caractere de controle ou de direção de texto."
    return 1
  fi
  case "$chave" in
    REPO_REMOTO)
      [[ "$v" =~ $RE_REPO ]] || { erro "Valor inválido para REPO_REMOTO: esperado org/repositório."; return 1; }
      for parte in "${v%%/*}" "${v#*/}"; do
        case "$parte" in . | ..) erro "Valor inválido para REPO_REMOTO: esperado org/repositório."; return 1 ;; esac
      done
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
    BOARD)
      [ -z "$v" ] || [ -n "${v//[[:space:]]/}" ] || { erro "Valor inválido para BOARD: só espaços (deixe vazio para sem board)."; return 1; }
      ;;
    PRINCIPIO_III)
      case "$v" in ligado | desligado) ;; *) erro "Valor inválido para PRINCIPIO_III: use ligado ou desligado."; return 1 ;; esac
      ;;
    IDENTIDADES)
      [ -n "$v" ] || { erro "Valor inválido para IDENTIDADES: informe ao menos uma identidade (nome:email)."; return 1; }
      local IFS=';' itens
      read -ra itens <<<"$v;"
      IFS=$' \t\n'
      for item in "${itens[@]}"; do
        item="$(aparar "$item")"
        [ -n "$item" ] || continue
        n=$((n + 1))
        nome="$(aparar "${item%%:*}")"
        email="$(aparar "${item#*:}")"
        if [ "$nome" = "$item" ]; then
          erro "Valor inválido para IDENTIDADES: item '$item' fora do formato nome:email."
          return 1
        fi
        if [[ "$email" == *:* ]]; then
          erro "Valor inválido para IDENTIDADES: item '$item' — o nome não pode conter ':'."
          return 1
        fi
        if [ -z "$nome" ] || [[ "$nome" == *[\<\>]* ]] \
          || [[ "$email" == *[\<\>[:space:]]* ]] || ! [[ "$email" =~ ^[^@]+@[^@]+$ ]]; then
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

# chaves_faltantes — obrigatórias ainda não definidas, na ordem de gravação.
chaves_faltantes() {
  local k out=""
  for k in $CHAVES_ORDEM; do
    chave_opcional "$k" && continue
    definido "$k" || out="$out $k"
  done
  printf '%s' "${out# }"
}

# validar_todos — exige as obrigatórias (sem presumir valor, FR-016) e valida
# todos os valores. Devolve 1 se algo falhar (mensagens já emitidas).
validar_todos() {
  local k rc=0
  normalizar_identidades
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
  local acumulado="" resp nome email atual=""
  definido IDENTIDADES && atual="$(valor IDENTIDADES)"
  [ -z "$atual" ] || log "Identidades atuais: $atual"
  while :; do
    if [ -z "$acumulado" ] && [ -n "$atual" ]; then
      printf 'Identidade de commit (nome <email>; vazio mantém as atuais): '
    elif [ -z "$acumulado" ]; then
      printf 'Identidade de commit (nome <email>): '
    else
      printf 'Outra identidade (nome <email>; vazio encerra): '
    fi
    IFS= read -r resp || falhar "Entrada encerrada antes de responder IDENTIDADES."
    if [ -z "$resp" ]; then
      if [ -n "$acumulado" ]; then break; fi
      if [ -n "$atual" ]; then return 0; fi
      erro "Informe ao menos uma identidade."
      continue
    fi
    if ! [[ "$resp" =~ $RE_IDENT ]]; then
      erro "Formato esperado: nome <email>."
      continue
    fi
    nome="$(aparar "${BASH_REMATCH[1]}")"
    email="$(aparar "${BASH_REMATCH[2]}")"
    if [[ "$nome" == *:* ]]; then
      erro "O nome não pode conter ':'."
      continue
    fi
    if validar_chave IDENTIDADES "$nome:$email"; then
      acumulado="${acumulado:+$acumulado;}$nome:$email"
    fi
  done
  setar IDENTIDADES "$acumulado"
}

perguntar_chave() {
  case "$1" in
    PROJETO_NOME) perguntar PROJETO_NOME "Nome do projeto" ;;
    REPO_REMOTO) perguntar REPO_REMOTO "Repositório remoto (org/repositório)" ;;
    BRANCH_INTEGRACAO) perguntar BRANCH_INTEGRACAO "Branch de integração" ;;
    BRANCH_PRODUCAO) perguntar BRANCH_PRODUCAO "Branch de produção (pode ser igual à de integração)" ;;
    GERENCIADOR_PACOTES) perguntar GERENCIADOR_PACOTES "Gerenciador de pacotes" ;;
    CMD_TYPECHECK) perguntar CMD_TYPECHECK "Comando de typecheck" ;;
    CMD_LINT) perguntar CMD_LINT "Comando de lint" ;;
    CMD_BUILD) perguntar CMD_BUILD "Comando de build" ;;
    CMD_DEPLOY_INTEGRACAO) perguntar CMD_DEPLOY_INTEGRACAO "Comando de deploy de integração" ;;
    CMD_DEPLOY_PRODUCAO) perguntar CMD_DEPLOY_PRODUCAO "Comando de deploy de produção" ;;
    URL_AMBIENTE_INTEGRACAO) perguntar URL_AMBIENTE_INTEGRACAO "URL do ambiente de integração" ;;
    URL_AMBIENTE_PRODUCAO) perguntar URL_AMBIENTE_PRODUCAO "URL do ambiente de produção" ;;
    IDENTIDADES) perguntar_identidades ;;
    BOARD) perguntar BOARD "Board do projeto" ;;
    PRINCIPIO_III)
      # Padrão sugerido só na pergunta interativa; no modo não interativo a
      # chave ausente é erro (FR-016).
      definido PRINCIPIO_III || setar PRINCIPIO_III ligado
      perguntar PRINCIPIO_III "Princípio III (ligado ou desligado)"
      ;;
  esac
}

perguntar_todos() {
  local k
  for k in $CHAVES_ORDEM; do perguntar_chave "$k"; done
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
# link simbólico nem diretório. Senão devolve 1 com o motivo em MOTIVO.
destino_contido() {
  local alvo="$1" anc real base="${RAIZ%/}/"
  if [ -L "$alvo" ]; then MOTIVO="é link simbólico"; return 1; fi
  if [ -d "$alvo" ]; then MOTIVO="é um diretório"; return 1; fi
  if [ -e "$alvo" ] && [ ! -f "$alvo" ]; then MOTIVO="existe e não é arquivo regular"; return 1; fi
  anc="$(dirname "$alvo")"
  while [ ! -d "$anc" ]; do
    if [ -e "$anc" ] || [ -L "$anc" ]; then MOTIVO="${anc#"$base"} existe e não é diretório"; return 1; fi
    anc="$(dirname "$anc")"
  done
  real="$(cd "$anc" && pwd -P)" || { MOTIVO="caminho ilegível"; return 1; }
  case "$real/" in "$base"*) return 0 ;; esac
  MOTIVO="fora do projeto"
  return 1
}

exigir_contido() {
  destino_contido "$1" || falhar "Destino recusado ($MOTIVO): $2"
}

# ------------------------------------------------------------------ hashes --

hash_arquivo() {
  local h
  if command -v sha256sum >/dev/null 2>&1; then
    h="$(sha256sum <"$1")" || return 1
  else
    h="$(shasum -a 256 <"$1")" || return 1
  fi
  [ -n "$h" ] || return 1
  printf '%s' "${h%% *}"
}

MANIFESTO_REL=".cockpit/manifesto.sha256"

# manifesto_hash REL — hash registrado no manifesto (vazio se ausente).
manifesto_hash() {
  local arq="$RAIZ/$MANIFESTO_REL" linha
  [ -f "$arq" ] || return 0
  while IFS= read -r linha || [ -n "$linha" ]; do
    if [ "${linha#*  }" = "$1" ]; then printf '%s' "${linha%%  *}"; return 0; fi
  done <"$arq"
  return 0
}

# ------------------------------------------------------------------ config --

escapar_aspas() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

gravar_config() {
  local alvo="$RAIZ/cockpit.config" k linha
  {
    printf '%s\n' "$CABECALHO_1" "$CABECALHO_2" ""
    for k in $CHAVES_ORDEM; do
      definido "$k" || continue
      chave_opcional "$k" && [ -z "$(valor "$k")" ] && continue
      printf "%s='%s'\n" "$k" "$(escapar_aspas "$(valor "$k")")"
    done
    if [ "${#EXTRAS[@]}" -gt 0 ]; then
      printf '\n%s\n' "$CABECALHO_EXTRAS"
      for linha in "${EXTRAS[@]}"; do printf '%s\n' "$linha"; done
    fi
  } >"$STG/cockpit.config" # sem `||`: o set -e pega falha de qualquer printf
  exigir_contido "$alvo" cockpit.config
  herdar_modo "$STG/cockpit.config" "$alvo"
  if [ -f "$alvo" ] && cmp -s "$STG/cockpit.config" "$alvo"; then
    log "cockpit.config: inalterado"
  else
    mv -f "$STG/cockpit.config" "$alvo" || falhar "Falha ao gravar cockpit.config."
    log "cockpit.config: gravado"
  fi
}

# ------------------------------------------------------------------ templates

preparar_templates() {
  local tdir="$COCKPIT_DIR/templates" f rel d dl i
  local -a dests_min=()
  TPL_ORIG=()
  DEST_REL=()
  if [ ! -d "$tdir" ]; then
    aviso "templates/ não encontrado em $COCKPIT_DIR."
    return 0
  fi
  while IFS= read -r f; do
    rel="${f#"$tdir"/}"
    case "/$rel/" in */../*) falhar "Caminho de template recusado: $rel" ;; esac
    d="${rel%.tmpl}"
    # Comparação sem diferenciar maiúsculas: em sistema de arquivos que não
    # diferencia (macOS), .GIT e .git são o mesmo diretório.
    dl="$(printf '%s' "$d" | tr '[:upper:]' '[:lower:]')"
    case "$dl" in
      cockpit.config | "$MANIFESTO_REL" | .git | .git/* | */.git | */.git/* | .cockpit-tmp.*)
        falhar "Template recusado (destino reservado): $rel" ;;
    esac
    for ((i = 0; i < ${#DEST_REL[@]}; i++)); do
      [ "${dests_min[i]}" != "$dl" ] \
        || falhar "Templates com o mesmo destino ($d): ${TPL_ORIG[i]#"$tdir"/} e $rel"
    done
    TPL_ORIG+=("$f")
    DEST_REL+=("$d")
    dests_min+=("$dl")
  done < <(find "$tdir" -type f | sort)
}

# renderizar TEMPLATE SAIDA RESIDUAIS — substituição literal de {{CHAVE}} em
# awk: valores e o caminho de residuais entram por ENVIRON e o valor por
# concatenação de substr(), nunca por gsub() nem -v, então &, \ e $ ficam
# literais (research Decision 1). Sem newline final no template, sem newline
# final na saída; o bit de execução segue o do template.
renderizar() {
  local defs="" k sem_nl=""
  for k in $CHAVES_ORDEM; do definido "$k" && defs="$defs $k"; done
  if [ -s "$1" ] && [ "$(tail -c 1 "$1" | od -An -tx1 | tr -d ' \n')" != 0a ]; then sem_nl=1; fi
  (
    for k in $defs; do export "CFG_$k"; done
    export DEFINIDAS="$defs " RESFILE="$3" SEM_NL="$sem_nl"
    awk '
      {
        resto = $0; saida = ""
        while (match(resto, /\{\{[A-Z][A-Z0-9_]*\}\}/)) {
          nome = substr(resto, RSTART + 2, RLENGTH - 4)
          saida = saida substr(resto, 1, RSTART - 1)
          if (index(ENVIRON["DEFINIDAS"], " " nome " ")) saida = saida ENVIRON["CFG_" nome]
          else { saida = saida substr(resto, RSTART, RLENGTH); f = ENVIRON["RESFILE"]; print nome >> f }
          resto = substr(resto, RSTART + RLENGTH)
        }
        if (NR > 1) printf "\n"
        printf "%s", saida resto
      }
      END { if (NR > 0 && ENVIRON["SEM_NL"] == "") printf "\n" }' "$1" >"$2"
  ) || return 1
  if [ -x "$1" ]; then chmod +x "$2" || return 1; fi
}

# sincronizar_exec TEMPLATE DESTINO — o bit de execução do destino segue o do
# template (arquivo inalterado em conteúdo, modo diferente).
sincronizar_exec() {
  if [ -x "$1" ] && [ ! -x "$2" ]; then chmod +x "$2" || return 1; fi
  if [ ! -x "$1" ] && [ -x "$2" ]; then chmod a-x "$2" || return 1; fi
  return 0
}

# modo_de ARQ — permissão octal (GNU ou BSD stat); vazio se não souber.
modo_de() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1" 2>/dev/null || true; }

# herdar_modo NOVO EXISTENTE — o arquivo novo mantém a permissão do destino
# que vai substituir (ex.: 600 continua 600).
herdar_modo() {
  local m
  [ -e "$2" ] || return 0
  m="$(modo_de "$2")"
  [ -z "$m" ] || chmod "$m" "$1"
}

# aplicar_templates — renderiza tudo em staging; só move se não há residual
# nem conflito de edição local. Toda falha de escrita encerra com erro: a
# função é chamada sob `||`, onde o set -e não vale.
aplicar_templates() {
  local i n="${#TPL_ORIG[@]}" rel nome resp
  local -a conflitos=() gravados=() inalterados=()
  local h_atual h_man dest
  if [ "$n" -eq 0 ]; then
    [ ! -d "$COCKPIT_DIR/templates" ] || log "Nenhum template em templates/: nada havia a renderizar."
    gravar_manifesto
    return 0
  fi
  : >"$STG/residuais" || falhar "Falha ao escrever em $STG."
  for ((i = 0; i < n; i++)); do
    rel="${TPL_ORIG[i]#"$COCKPIT_DIR/templates/"}"
    : >"$STG/res" || falhar "Falha ao escrever em $STG."
    renderizar "${TPL_ORIG[i]}" "$STG/r$i" "$STG/res" || falhar "Falha ao renderizar $rel."
    if [ -s "$STG/res" ]; then
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
    h_atual="$(hash_arquivo "$dest")" || falhar "Falha ao ler ${DEST_REL[i]}."
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
    log "Templates: 0 gravado(s); mantido(s) por edição local: ${conflitos[*]}"
    return 2
  fi
  for ((i = 0; i < n; i++)); do
    dest="$RAIZ/${DEST_REL[i]}"
    exigir_contido "$dest" "${DEST_REL[i]}"
    if [ -f "$dest" ] && cmp -s "$STG/r$i" "$dest"; then
      sincronizar_exec "${TPL_ORIG[i]}" "$dest" || falhar "Falha ao ajustar permissão de ${DEST_REL[i]}."
      inalterados+=("${DEST_REL[i]}")
      continue
    fi
    mkdir -p "$(dirname "$dest")" || falhar "Falha ao criar o diretório de ${DEST_REL[i]}."
    exigir_contido "$dest" "${DEST_REL[i]}"
    { herdar_modo "$STG/r$i" "$dest" && sincronizar_exec "${TPL_ORIG[i]}" "$STG/r$i"; } \
      || falhar "Falha ao ajustar permissão de ${DEST_REL[i]}."
    mv -f "$STG/r$i" "$dest" || falhar "Falha ao gravar ${DEST_REL[i]}."
    gravados+=("${DEST_REL[i]}")
  done
  gravar_manifesto
  for rel in ${gravados[@]+"${gravados[@]}"}; do log "  gravado: $rel"; done
  for rel in ${inalterados[@]+"${inalterados[@]}"}; do log "  inalterado: $rel"; done
  log "Templates: ${#gravados[@]} gravado(s), ${#inalterados[@]} inalterado(s)."
  return 0
}

# gravar_manifesto — um hash por destino gerado. Entradas do manifesto
# anterior sem template correspondente (template removido do cockpit) são
# mantidas com o hash antigo e avisadas; o arquivo nunca é apagado. Sem
# destinos e sem manifesto anterior, não cria manifesto.
gravar_manifesto() {
  local i n="${#DEST_REL[@]}" alvo="$RAIZ/$MANIFESTO_REL" ord linha rel h achou
  local -a orfas=()
  if [ -f "$alvo" ]; then
    while IFS= read -r linha || [ -n "$linha" ]; do
      rel="${linha#*  }"
      if [ -z "$rel" ] || [ "$rel" = "$linha" ]; then continue; fi
      achou=false
      for ((i = 0; i < n; i++)); do [ "${DEST_REL[i]}" != "$rel" ] || { achou=true; break; }; done
      $achou && continue
      [ -e "$RAIZ/$rel" ] || continue
      aviso "$rel não é mais gerado por nenhum template; mantido — remova à mão se quiser."
      orfas+=("$linha")
    done <"$alvo"
  fi
  [ "$n" -gt 0 ] || [ "${#orfas[@]}" -gt 0 ] || [ -f "$alvo" ] || return 0
  : >"$STG/manifesto" || falhar "Falha ao escrever em $STG."
  ord="$({
    for ((i = 0; i < n; i++)); do
      h="$(hash_arquivo "$RAIZ/${DEST_REL[i]}")" || exit 1
      printf '%s  %s\n' "$h" "${DEST_REL[i]}"
    done
    for linha in ${orfas[@]+"${orfas[@]}"}; do printf '%s\n' "$linha"; done
  } | sort -k2)" || falhar "Falha ao calcular o manifesto."
  [ -z "$ord" ] || printf '%s\n' "$ord" >"$STG/manifesto" || falhar "Falha ao escrever em $STG."
  exigir_contido "$alvo" "$MANIFESTO_REL"
  mkdir -p "$RAIZ/.cockpit" || falhar "Falha ao criar .cockpit/."
  exigir_contido "$alvo" "$MANIFESTO_REL"
  if [ -f "$alvo" ] && cmp -s "$STG/manifesto" "$alvo"; then return 0; fi
  mv -f "$STG/manifesto" "$alvo" || falhar "Falha ao gravar $MANIFESTO_REL."
}

# ------------------------------------------------------------------- hooks --

# versao_cstk — versão lida só do stdout de `cstk --version`. Linhas que citam
# "cstk" têm precedência; em cada token, parênteses e pontuação das bordas
# saem, e vale o primeiro com forma N.N[.N][-pré][+build] (o +build é
# descartado). Número sem ponto só vale como `vN` ou em "cstk N".
versao_cstk() {
  local saida linha tok passada inteiro=""
  local -a toks
  saida="$(cstk --version 2>/dev/null </dev/null)" || true
  saida="${saida//$'\r'/}"
  for passada in cstk outras; do
    while IFS= read -r linha; do
      case "$linha" in
        *cstk*) [ "$passada" = cstk ] || continue ;;
        *) [ "$passada" = outras ] || continue ;;
      esac
      [ -n "$inteiro" ] || { [[ "$linha" =~ ^[[:space:]]*cstk[[:space:]]+([0-9]+)[[:space:]]*$ ]] && inteiro="${BASH_REMATCH[1]}"; } || true
      toks=()
      read -ra toks <<<"$linha" || true
      for tok in ${toks[@]+"${toks[@]}"}; do
        tok="${tok#"${tok%%[!(\[]*}"}"
        tok="${tok%"${tok##*[!)\],.;:]}"}"
        if [[ "$tok" =~ ^v?([0-9]+(\.[0-9]+){1,2}(-[0-9A-Za-z.-]+)?)(\+[0-9A-Za-z.-]+)?$ ]]; then
          printf '%s' "${BASH_REMATCH[1]}"
          return 0
        fi
        [ -n "$inteiro" ] || { [[ "$tok" =~ ^v([0-9]+)$ ]] && inteiro="${BASH_REMATCH[1]}"; } || true
      done
    done <<<"$saida"
  done
  printf '%s' "$inteiro"
}

# versao_atende VER MIN — pré-release (X.Y.Z-rc) fica abaixo de X.Y.Z.
versao_atende() {
  local ver="$1" min="$2" base="${1%%-*}"
  versao_ge "$base" "$min" || return 1
  [ "$ver" = "$base" ] && return 0
  ! versao_ge "$min" "$base"
}

# provisionar_hooks — último passo. Só `cstk --version` e `cstk hooks install`
# (Princípio IV): ausência ou versão abaixo do piso imprime o comando oficial
# e devolve 3; falha do cstk devolve 4.
provisionar_hooks() {
  local min ver saida rc=0
  min="$(ler_cstk_min)"
  if ! [[ "$min" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    erro "CSTK_MIN ausente ou inválido em $COCKPIT_DIR/versoes.env — guard hooks não provisionados."
    log "Corrija CSTK_MIN em $COCKPIT_DIR/versoes.env (ou atualize o clone do cockpit)."
    log "Depois rode de novo: $(comando_de_novo)"
    return 3
  fi
  if ! command -v cstk >/dev/null 2>&1; then
    erro "cstk não encontrado no PATH — guard hooks não provisionados."
    log "Execute: curl -fsSL $CSTK_INSTALL_URL -o \"\$HOME/cstk-install.sh\""
    log "Execute (depois de inspecionar): sh \"\$HOME/cstk-install.sh\""
    log "Depois rode de novo: $(comando_de_novo)"
    return 3
  fi
  ver="$(versao_cstk)"
  if [ -z "$ver" ] || ! versao_atende "$ver" "$min"; then
    erro "cstk sem versão reconhecível ou abaixo do piso (${ver:-desconhecida} < $min) — guard hooks não provisionados."
    log "Execute: cstk self-update"
    log "Depois rode de novo: $(comando_de_novo)"
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
  local projeto="." projeto_explicito=false respostas="" atualizar=false
  while [ $# -gt 0 ]; do
    case "$1" in
      --projeto) [ $# -ge 2 ] || falhar "--projeto exige um diretório."; projeto="$2"; projeto_explicito=true; shift 2 ;;
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
  if ! $projeto_explicito && [ "$RAIZ" = "$COCKPIT_DIR" ]; then
    falhar "Rodando na raiz do próprio cockpit sem --projeto. Informe --projeto DIR com o projeto-alvo (ou --projeto . para configurar o próprio cockpit)."
  fi
  log "  $RAIZ"
  local cfg="$RAIZ/cockpit.config" k faltam
  exigir_contido "$cfg" cockpit.config

  log "Passo 2/5: valores"
  if [ -e "$cfg" ] && [ ! -L "$cfg" ] && [ ! -r "$cfg" ]; then falhar "cockpit.config ilegível: $cfg"; fi
  case "$MODO" in
    atualizar)
      [ -f "$cfg" ] || falhar "Nenhum cockpit.config em $RAIZ. Rode ./configurar.sh sem --atualizar para criá-lo."
      ler_kv "$cfg" || exit 1
      [ -z "$DESCONHECIDAS" ] || aviso "chave(s) desconhecida(s) no cockpit.config, sem uso nos templates:$DESCONHECIDAS"
      ;;
    respostas)
      if [ ! -f "$respostas" ] || [ ! -r "$respostas" ]; then falhar "Arquivo de respostas ilegível: $respostas"; fi
      ler_kv "$respostas" || exit 1
      [ -z "$DESCONHECIDAS" ] || aviso "chave(s) desconhecida(s) no arquivo de respostas, ignorada(s):$DESCONHECIDAS"
      ;;
    interativo)
      if [ -f "$cfg" ] && [ ! -L "$cfg" ]; then
        ler_kv "$cfg" || exit 1
        normalizar_identidades
        log "Valores atuais em $cfg (Enter aceita cada padrão):"
        for k in $CHAVES_ORDEM; do
          definido "$k" || continue
          if validar_chave "$k" "$(valor "$k")" 2>/dev/null; then log "  $k=$(valor "$k")"; else aviso "$k inválida no config atual; será perguntada de novo."; desetar "$k"; fi
        done
        faltam="$(chaves_faltantes)"
        if [ -n "$faltam" ]; then
          aviso "chave(s) ausente(s) no cockpit.config: $faltam — perguntando só essas."
          for k in $faltam; do perguntar_chave "$k"; done
          for k in $CHAVES_OPCIONAIS; do definido "$k" || perguntar_chave "$k"; done
        else
          perguntar_todos
        fi
      else
        perguntar_todos
      fi
      ;;
  esac
  validar_todos || exit 1

  # Chaves desconhecidas do cockpit.config existente são mantidas na regravação;
  # comentários próprios da pessoa, não.
  if [ "$MODO" != atualizar ] && [ -f "$cfg" ] && [ ! -L "$cfg" ]; then
    COMENTARIOS_PERDIDOS=false
    ler_kv "$cfg" extras || exit 1
    [ "${#EXTRAS[@]}" -eq 0 ] || aviso "chave(s) desconhecida(s) mantida(s) no cockpit.config:$DESCONHECIDAS"
    ! $COMENTARIOS_PERDIDOS || aviso "comentários, \`export\` e comentários no fim da linha do cockpit.config não são preservados na regravação (exceto nas chaves desconhecidas mantidas)."
  fi

  preparar_templates
  local i
  for ((i = 0; i < ${#DEST_REL[@]}; i++)); do
    exigir_contido "$RAIZ/${DEST_REL[i]}" "${DEST_REL[i]}"
  done
  exigir_contido "$RAIZ/$MANIFESTO_REL" "$MANIFESTO_REL"
  exigir_contido "$cfg" cockpit.config

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
