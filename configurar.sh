#!/usr/bin/env bash
# configurar.sh — configura um projeto-alvo para o ciclo do cockpit.
#
# Pergunta os parâmetros do ciclo (ou lê de um arquivo de respostas), grava
# `cockpit.config` na raiz do projeto-alvo, renderiza todo arquivo sob
# `templates/` por substituição literal de `{{CHAVE}}` e, por último,
# provisiona os guard hooks com `cstk hooks install`. Nunca instala nem
# atualiza terceiro (Princípio IV): só usa o `cstk` que a pessoa já instalou.
#
# Semente: template `X.semente.tmpl` gera `X` só se o destino não existe; existindo
# (qualquer tipo), fica intacto, mesmo com --forcar; não entra nem sai do manifesto
# (a linha anterior dela, se houver, é mantida — FR-006).
#
# Destinos do projeto: a chave opcional DESTINOS_DO_PROJETO (caminhos separados
# por espaço) lista destinos que o projeto mantém; ficam intactos como uma
# semente existente, nem com --forcar são sobrescritos. Numa worktree vinculada,
# semente ou destino listado ausente e ignorado pelo git é copiado da árvore
# principal (arquivo regular, fora do manifesto); sem origem válida, não é gerado.
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

# Ordem fixa de gravação (data-model.md). URLs, DESTINOS_DO_PROJETO e PREFIXOS_BRANCH são as únicas opcionais.
CHAVES_ORDEM="PROJETO_NOME REPO_REMOTO BRANCH_INTEGRACAO BRANCH_PRODUCAO GERENCIADOR_PACOTES CMD_TYPECHECK CMD_LINT CMD_BUILD CMD_DEPLOY_INTEGRACAO CMD_DEPLOY_PRODUCAO URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO IDENTIDADES DONOS_CODEOWNERS BOARD PRINCIPIO_III DESTINOS_DO_PROJETO PREFIXOS_BRANCH"
CHAVES_OPCIONAIS=" URL_AMBIENTE_INTEGRACAO URL_AMBIENTE_PRODUCAO DESTINOS_DO_PROJETO PREFIXOS_BRANCH "
# Prefixos de branch (feature fix chore docs hotfix, nessa ordem) e os placeholders de render derivados deles.
PREFIXOS_PADRAO="feature fix chore docs hotfix"
DERIVADAS="PREFIXO_FEATURE PREFIXO_FIX PREFIXO_CHORE PREFIXO_DOCS PREFIXO_HOTFIX"
CABECALHO_1="# cockpit.config — gerado por configurar.sh; pode ser editado à mão."
CABECALHO_2="# Rode ./configurar.sh --atualizar para re-renderizar os templates."
CABECALHO_EXTRAS="# Chaves não reconhecidas por configurar.sh, mantidas do arquivo anterior:"

RE_KV='^([A-Z][A-Z0-9_]*)=(.*)$'
# org/repositório genérico (Princípio I): nenhuma parte começa com '-' nem é
# '.' ou '..' (checado à parte em validar_chave).
RE_REPO='^[A-Za-z0-9._][A-Za-z0-9._-]*/[A-Za-z0-9._][A-Za-z0-9._-]*$'
# BRANCH_INTEGRACAO e BRANCH_PRODUCAO (D1): o git aceita metacaractere de shell
# em nome de branch; a skill rito-dev compõe comando com esses valores.
RE_BRANCH='^[A-Za-z0-9][A-Za-z0-9._/-]*$'
RE_URL='^https?://[^[:space:]]+$'
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
SEMENTE=() # 1 = template .semente.tmpl
PULAR=()   # motivo de não renderizar: vazio | semente | projeto | copia | ignorado
ORIGEM=()  # copia: arquivo na árvore principal; ignorado: caminho esperado
VINCULADA=false # worktree vinculada (git-dir != git-common-dir)
PRINCIPAL=""    # árvore principal confirmada, ou vazio

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
  --forcar         sobrescreve arquivos editados à mão sem confirmação, exceto sementes e
                   destinos em DESTINOS_DO_PROJETO, que nunca são sobrescritos
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
  local chave="$1" v="$2" item itens nome email n=0 parte
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
      [[ "$v" =~ $RE_BRANCH ]] && git check-ref-format --branch "$v" >/dev/null 2>&1 \
        || { erro "Valor inválido para $chave: esperado nome de branch válido para o Git, só com caracteres do conjunto aceito $RE_BRANCH."; return 1; }
      ;;
    PROJETO_NOME | GERENCIADOR_PACOTES | CMD_*)
      [ -n "${v//[[:space:]]/}" ] || { erro "Valor inválido para $chave: não pode ser vazio."; return 1; }
      ;;
    URL_AMBIENTE_INTEGRACAO | URL_AMBIENTE_PRODUCAO)
      [ -z "$v" ] || [[ "$v" =~ $RE_URL ]] || { erro "Valor inválido para $chave: esperado URL http(s) sem espaços."; return 1; }
      ;;
    BOARD)
      [ -z "$v" ] || [ -n "${v//[[:space:]]/}" ] || { erro "Valor inválido para BOARD: só espaços (deixe vazio para sem board)."; return 1; }
      [ -z "$v" ] || [[ "$v" =~ ^[A-Za-z0-9-]+/[1-9][0-9]*$ ]] \
        || { erro "Valor inválido para BOARD: esperado dono/número (número inteiro positivo) ou vazio."; return 1; }
      ;;
    DESTINOS_DO_PROJETO)
      read -ra itens <<<"$v" # sem expansão de glob
      for item in ${itens[@]+"${itens[@]}"}; do
        [ -n "${item//[\'\"]/}" ] || { erro "Valor inválido para DESTINOS_DO_PROJETO: item '$item' vazio (só aspas)."; return 1; }
        case "$item" in /*) erro "Valor inválido para DESTINOS_DO_PROJETO: item '$item' é absoluto."; return 1 ;; esac
        case "/$item/" in */../*) erro "Valor inválido para DESTINOS_DO_PROJETO: item '$item' contém '..'."; return 1 ;; esac
      done
      ;;
    PREFIXOS_BRANCH)
      read -ra itens <<<"$v" # sem expansão de glob
      [ "${#itens[@]}" -eq 0 ] || [ "${#itens[@]}" -eq 5 ] \
        || { erro "Valor inválido para PREFIXOS_BRANCH: esperados 5 prefixos ($PREFIXOS_PADRAO, nessa ordem), recebidos ${#itens[@]}."; return 1; }
      local ant=" "
      for item in ${itens[@]+"${itens[@]}"}; do
        case "$item" in *"/"*) erro "Valor inválido para PREFIXOS_BRANCH: o prefixo '$item' contém '/'."; return 1 ;; esac
        # D4: conjunto restrito (o intervalo é ASCII porque `export LC_ALL=C` vale desde a l.38).
        [[ "$item" =~ ^[a-z0-9][a-z0-9._-]*$ ]] \
          || { erro "Valor inválido para PREFIXOS_BRANCH: o prefixo '$item' fora do conjunto aceito ^[a-z0-9][a-z0-9._-]*\$."; return 1; }
        git check-ref-format --branch "$item/x" >/dev/null 2>&1 \
          || { erro "Valor inválido para PREFIXOS_BRANCH: o prefixo '$item' não forma nome de branch válido."; return 1; }
        case "$ant" in *" $item "*) erro "Valor inválido para PREFIXOS_BRANCH: o prefixo '$item' está repetido."; return 1 ;; esac
        ant="$ant$item "
      done
      ;;
    DONOS_CODEOWNERS)
      [ -n "${v//[[:space:]]/}" ] || { erro "Valor inválido para DONOS_CODEOWNERS: informe ao menos um dono (@usuario)."; return 1; }
      read -ra itens <<<"$v" # sem expansão de glob
      for item in "${itens[@]}"; do
        case "$item" in
          */*) erro "Valor inválido para DONOS_CODEOWNERS: times (@org/time) não são aceitos: informe usuários individuais."; return 1 ;;
        esac
        [[ "$item" =~ ^@[A-Za-z0-9-]+$ ]] || { erro "Valor inválido para DONOS_CODEOWNERS: item '$item' fora do formato @usuario."; return 1; }
      done
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
  local k v rc=0
  normalizar_identidades
  for k in $CHAVES_ORDEM; do
    # Opcional vazia = ausente, como no cockpit.config gravado; senão o render
    # a resolveria e o --atualizar seguinte daria residual (FR-006).
    if chave_opcional "$k" && definido "$k" && [ -z "$(valor "$k")" ]; then desetar "$k"; fi
    # Só espaços em DESTINOS_DO_PROJETO equivale a não declarada (TAB segue p/ validar_chave).
    if { [ "$k" = DESTINOS_DO_PROJETO ] || [ "$k" = PREFIXOS_BRANCH ]; } && definido "$k"; then
      v="$(valor "$k")"
      [ -n "${v// /}" ] || desetar "$k"
    fi
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

# perguntar_identidades — pede nome e e-mail separados, uma identidade por vez
# (FR-018, ratificado pelo owner em 2026-09-29); nome vazio encerra a lista
# (ou mantém as atuais, se nada foi informado). Grava `nome:email;...`.
perguntar_identidades() {
  local acumulado="" nome email atual=""
  definido IDENTIDADES && atual="$(valor IDENTIDADES)"
  [ -z "$atual" ] || log "Identidades atuais: $atual"
  while :; do
    if [ -z "$acumulado" ] && [ -n "$atual" ]; then
      printf 'Nome da identidade de commit (vazio mantém as atuais): '
    elif [ -z "$acumulado" ]; then
      printf 'Nome da identidade de commit: '
    else
      printf 'Nome de outra identidade (vazio encerra): '
    fi
    IFS= read -r nome || falhar "Entrada encerrada antes de responder IDENTIDADES."
    nome="$(aparar "$nome")"
    if [ -z "$nome" ]; then
      if [ -n "$acumulado" ]; then break; fi
      if [ -n "$atual" ]; then return 0; fi
      erro "Informe ao menos uma identidade."
      continue
    fi
    if [[ "$nome" == *[:\;\<\>]* ]]; then
      erro "O nome não pode conter ':', ';', '<' nem '>'."
      continue
    fi
    printf 'E-mail de %s: ' "$nome"
    IFS= read -r email || falhar "Entrada encerrada antes de responder IDENTIDADES."
    email="$(aparar "$email")"
    if [[ "$email" == *[\;]* ]]; then
      erro "O e-mail não pode conter ';'."
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
    DONOS_CODEOWNERS) perguntar DONOS_CODEOWNERS "Donos do CODEOWNERS (@usuario separados por espaço)" ;;
    BOARD) perguntar BOARD "Board do projeto (dono/número)" ;;
    DESTINOS_DO_PROJETO) perguntar DESTINOS_DO_PROJETO "Destinos mantidos pelo projeto (caminhos separados por espaço)" ;;
    PREFIXOS_BRANCH) perguntar PREFIXOS_BRANCH "Prefixos de branch de feature, fix, chore, docs e hotfix, nessa ordem (padrão: $PREFIXOS_PADRAO)" ;;
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
  local tdir="$COCKPIT_DIR/templates" f rel d dl i s
  local -a dests_min=()
  TPL_ORIG=()
  DEST_REL=()
  SEMENTE=()
  if [ ! -d "$tdir" ]; then
    aviso "templates/ não encontrado em $COCKPIT_DIR."
    return 0
  fi
  while IFS= read -r f; do
    rel="${f#"$tdir"/}"
    case "/$rel/" in */../*) falhar "Caminho de template recusado: $rel" ;; esac
    case "$rel" in
      *.semente.tmpl) d="${rel%.semente.tmpl}"; s=1 ;;
      *) d="${rel%.tmpl}"; s=0 ;;
    esac
    case "$d" in "" | */) falhar "Template recusado (destino vazio): $rel" ;; esac
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
    SEMENTE+=("$s")
    dests_min+=("$dl")
  done < <(find "$tdir" -type f | sort)
}

# resolver_dir DIR — caminho físico de DIR, relativo a $RAIZ se não absoluto.
resolver_dir() { (cd "$RAIZ" && cd "$1" 2>/dev/null && pwd -P); }

# arvore_principal — decide uma vez por execução se o projeto é worktree
# vinculada (git-dir != git-common-dir, ambos físicos) e, se for, qual é a
# árvore principal: primeiro registro de `worktree list --porcelain`, absoluto,
# sem controle, não bare e confirmado pelo git-dir dele igual ao git-common-dir.
# Só leitura. Qualquer falha do git desliga a cópia, nunca a habilita.
arvore_principal() {
  local gd gc linha cand="" bare=false g2 top why=""
  VINCULADA=false
  PRINCIPAL=""
  gd="$(git -C "$RAIZ" rev-parse --git-dir 2>/dev/null)" || return 0
  gc="$(git -C "$RAIZ" rev-parse --git-common-dir 2>/dev/null)" || return 0
  gd="$(resolver_dir "$gd")" || return 0
  gc="$(resolver_dir "$gc")" || return 0
  [ "$gd" != "$gc" ] || return 0
  VINCULADA=true
  while IFS= read -r linha; do
    [ -n "$linha" ] || break
    case "$linha" in
      "worktree "*) [ -n "$cand" ] || cand="${linha#worktree }" ;;
      bare) bare=true ;;
    esac
  done < <(git -C "$RAIZ" worktree list --porcelain 2>/dev/null || true)
  if $bare; then
    why="repositório bare"
  elif [ -z "$cand" ] || [[ "$cand" != /* ]] || tem_controle "$cand" || [ ! -d "$cand" ]; then
    why="não confirmada"
  else
    g2="$(git -C "$cand" rev-parse --git-dir 2>/dev/null)" || g2=""
    case "$g2" in
      "") ;;
      /*) g2="$(resolver_dir "$g2")" || g2="" ;;
      *) g2="$(resolver_dir "$cand/$g2")" || g2="" ;;
    esac
    # O git-dir também passa no teste acima (`--git-dir` dentro dele é `.`), como no
    # primeiro registro de `--separate-git-dir` ou de submódulo: exigir árvore de trabalho.
    top=""
    if [ -n "$g2" ] && [ "$g2" = "$gc" ]; then
      top="$(git -C "$cand" rev-parse --show-toplevel 2>/dev/null)" || top=""
      [ -z "$top" ] || top="$(resolver_dir "$top")" || top=""
    fi
    if [ -n "$top" ] && [ "$top" = "$(resolver_dir "$cand")" ]; then PRINCIPAL="$top"; else why="não confirmada"; fi
  fi
  [ -z "$why" ] || aviso "árvore principal indisponível ($why); destinos ignorados pelo git não serão copiados."
  return 0
}

# origem_valida REL — a origem na árvore principal é arquivo regular legível, não
# é link e tem pai físico igual ao lógico (sem link em nenhum componente). Só leitura.
origem_valida() {
  local o="$PRINCIPAL/$1" lpai pai
  if [ -L "$o" ]; then aviso "origem recusada (link simbólico): $o"; return 1; fi
  [ -e "$o" ] || return 1
  if [ ! -f "$o" ] || [ ! -r "$o" ]; then aviso "origem recusada (não é arquivo regular legível): $o"; return 1; fi
  lpai="$(dirname "$o")"
  pai="$(cd "$lpai" 2>/dev/null && pwd -P)" || return 1
  if [ "$pai" != "$lpai" ]; then aviso "origem recusada (link simbólico): $o"; return 1; fi
  return 0
}

# normalizar_rel REL — grafia canônica de um caminho relativo: sem `./` inicial,
# sem `/./` nem `//` internos e sem `/` final, para comparar com o destino.
normalizar_rel() {
  local r="$1"
  while [[ "$r" == ./* ]]; do r="${r#./}"; done
  while [[ "$r" == *//* || "$r" == */./* ]]; do r="${r//\/\//\/}"; r="${r//\/.\//\/}"; done
  r="${r%/}"
  printf '%s' "$r"
}

# classificar_destinos — decide uma vez, antes de qualquer escrita, o motivo de
# não renderizar cada destino (PULAR) e a origem da cópia (ORIGEM): listado em
# DESTINOS_DO_PROJETO = projeto; semente existente (qualquer tipo, inclusive link
# quebrado) = semente; em worktree vinculada, semente ou listado ausente e
# ignorado pelo git = copia (origem válida) ou ignorado. Pulado não é lido,
# renderizado nem comparado.
classificar_destinos() {
  local i item norm rel listado casou arv=false
  local -a brutos=() itens=()
  PULAR=()
  ORIGEM=()
  ! definido DESTINOS_DO_PROJETO || read -ra brutos <<<"$(valor DESTINOS_DO_PROJETO)"
  for item in ${brutos[@]+"${brutos[@]}"}; do
    norm="$(normalizar_rel "$item")"
    itens+=("$norm")
    casou=false
    for rel in ${DEST_REL[@]+"${DEST_REL[@]}"}; do [ "$norm" != "$rel" ] || { casou=true; break; }; done
    $casou || aviso "DESTINOS_DO_PROJETO: '$item' não é destino de nenhum template; ignorado."
  done
  for ((i = 0; i < ${#DEST_REL[@]}; i++)); do
    rel="${DEST_REL[i]}"
    PULAR[i]=""
    ORIGEM[i]=""
    listado=false
    for item in ${itens[@]+"${itens[@]}"}; do [ "$item" != "$rel" ] || { listado=true; break; }; done
    if $listado; then
      PULAR[i]=projeto
    elif [ "${SEMENTE[i]}" = 1 ] && { [ -e "$RAIZ/$rel" ] || [ -L "$RAIZ/$rel" ]; }; then
      PULAR[i]=semente
    fi
    # check-ignore antes de arvore_principal: o aviso de árvore indisponível só sai
    # quando há destino ignorado a copiar.
    if { $listado || [ "${SEMENTE[i]}" = 1 ]; } && [ ! -e "$RAIZ/$rel" ] && [ ! -L "$RAIZ/$rel" ] \
      && git -C "$RAIZ" check-ignore -q -- "$rel" 2>/dev/null; then
      $arv || { arvore_principal; arv=true; }
      if $VINCULADA; then
        if [ -n "$PRINCIPAL" ] && origem_valida "$rel"; then
          PULAR[i]=copia
          ORIGEM[i]="$PRINCIPAL/$rel"
        else
          PULAR[i]=ignorado
          [ -z "$PRINCIPAL" ] || ORIGEM[i]="$PRINCIPAL/$rel"
        fi
      fi
    fi
  done
}

# derivar_prefixos — define os cinco placeholders PREFIXO_* a partir de
# PREFIXOS_BRANCH (ou do padrão). Não são chaves: nunca perguntados nem gravados.
derivar_prefixos() {
  local -a p
  read -ra p <<<"$(definido PREFIXOS_BRANCH && valor PREFIXOS_BRANCH || printf '%s' "$PREFIXOS_PADRAO")"
  local i=0 d
  for d in $DERIVADAS; do setar "$d" "${p[i]}"; i=$((i + 1)); done
}

# renderizar TEMPLATE SAIDA RESIDUAIS — substituição literal de {{CHAVE}} em
# awk: valores e o caminho de residuais entram por ENVIRON e o valor por
# concatenação de substr(), nunca por gsub() nem -v, então &, \ e $ ficam
# literais (research Decision 1). Sem newline final no template, sem newline
# final na saída; o bit de execução segue o do template.
renderizar() {
  local defs="" k sem_nl=""
  for k in $CHAVES_ORDEM $DERIVADAS; do definido "$k" && defs="$defs $k"; done
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
  if template_executavel "$1"; then chmod +x "$2" || return 1; fi
}

# template_executavel TEMPLATE — 0 se o template é executável segundo o modo
# registrado no git do cockpit (100755); fora do git, pelo sistema de arquivos.
# O git é a fonte porque em clones sob /mnt no WSL (drvfs) todo arquivo aparece
# como executável.
template_executavel() {
  local modo
  modo="$(git -C "$COCKPIT_DIR" ls-files -s -- "${1#"$COCKPIT_DIR"/}" 2>/dev/null)" || modo=""
  modo="${modo%% *}"
  case "$modo" in
    100755) return 0 ;;
    100644 | 120000) return 1 ;;
  esac
  [ -x "$1" ]
}

# sincronizar_exec TEMPLATE DESTINO — o bit de execução do destino segue o do
# template (arquivo inalterado em conteúdo, modo diferente).
sincronizar_exec() {
  if template_executavel "$1"; then
    [ -x "$2" ] || chmod +x "$2" || return 1
  else
    [ ! -x "$2" ] || chmod a-x "$2" || return 1
  fi
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
  local -a conflitos=() gravados=() inalterados=() m_sem=() m_proj=() copiados=() m_ign=()
  local h_atual h_man dest
  if [ "$n" -eq 0 ]; then
    [ ! -d "$COCKPIT_DIR/templates" ] || log "Nenhum template em templates/: nada havia a renderizar."
    gravar_manifesto
    return 0
  fi
  : >"$STG/residuais" || falhar "Falha ao escrever em $STG."
  for ((i = 0; i < n; i++)); do
    [ -z "${PULAR[i]}" ] || continue
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
    [ -z "${PULAR[i]}" ] || continue
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
      erro "Arquivo editado localmente, mantido: $rel. Use --forcar para sobrescrever ou declare o destino em DESTINOS_DO_PROJETO no cockpit.config."
    done
    erro "Nenhum template foi gravado."
    log "Templates: 0 gravado(s); mantido(s) por edição local: ${conflitos[*]}"
    return 2
  fi
  # Cópias da árvore principal vão para o staging antes de qualquer mv: falha de
  # leitura recusa o lote sem deixar gravação parcial.
  for ((i = 0; i < n; i++)); do
    [ "${PULAR[i]}" = copia ] || continue
    # Limite aceito (research, Riscos aceitos): a origem pode virar link entre
    # origem_valida e este cp; a árvore principal é do próprio usuário.
    cp -- "${ORIGEM[i]}" "$STG/c$i" || falhar "Falha ao copiar ${DEST_REL[i]} da árvore principal."
  done
  for ((i = 0; i < n; i++)); do
    dest="$RAIZ/${DEST_REL[i]}"
    case "${PULAR[i]}" in
      semente) m_sem+=("${DEST_REL[i]}"); continue ;;
      projeto) m_proj+=("${DEST_REL[i]}"); continue ;;
      ignorado)
        if [ -n "${ORIGEM[i]}" ]; then m_ign+=("${DEST_REL[i]} (esperado em ${ORIGEM[i]})")
        else m_ign+=("${DEST_REL[i]} (árvore principal indisponível)"); fi
        continue ;;
      copia)
        exigir_contido "$dest" "${DEST_REL[i]}"
        mkdir -p "$(dirname "$dest")" || falhar "Falha ao criar o diretório de ${DEST_REL[i]}."
        exigir_contido "$dest" "${DEST_REL[i]}"
        mv -f "$STG/c$i" "$dest" || falhar "Falha ao gravar ${DEST_REL[i]}."
        copiados+=("${DEST_REL[i]}")
        continue ;;
    esac
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
  for rel in ${m_sem[@]+"${m_sem[@]}"}; do log "  mantido (semente): $rel"; done
  for rel in ${m_proj[@]+"${m_proj[@]}"}; do log "  mantido (projeto): $rel"; done
  for rel in ${copiados[@]+"${copiados[@]}"}; do log "  copiado da árvore principal: $rel"; done
  for rel in ${m_ign[@]+"${m_ign[@]}"}; do log "  mantido (ignorado pelo git): $rel"; done
  local suf=""
  [ "${#m_sem[@]}" -eq 0 ] || suf="$suf, ${#m_sem[@]} mantido(s) (semente)"
  [ "${#m_proj[@]}" -eq 0 ] || suf="$suf, ${#m_proj[@]} mantido(s) (projeto)"
  [ "${#copiados[@]}" -eq 0 ] || suf="$suf, ${#copiados[@]} copiado(s) da árvore principal"
  [ "${#m_ign[@]}" -eq 0 ] || suf="$suf, ${#m_ign[@]} mantido(s) (ignorado pelo git)"
  log "Templates: ${#gravados[@]} gravado(s), ${#inalterados[@]} inalterado(s)$suf."
  return 0
}

# gravar_manifesto — um hash por destino gerado. Entradas do manifesto
# anterior sem template correspondente (template removido do cockpit) são
# mantidas com o hash antigo e avisadas; o arquivo nunca é apagado. Sem
# linha a registrar e sem manifesto anterior, não cria manifesto.
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
  ord="$({
    for ((i = 0; i < n; i++)); do
      if [ -n "${PULAR[i]}" ]; then
        [ "${PULAR[i]}" != copia ] || continue # cópia não foi gerada por template (D3)
        h="$(manifesto_hash "${DEST_REL[i]}")"
        [ -z "$h" ] || printf '%s  %s\n' "$h" "${DEST_REL[i]}"
        continue
      fi
      h="$(hash_arquivo "$RAIZ/${DEST_REL[i]}")" || exit 1
      printf '%s  %s\n' "$h" "${DEST_REL[i]}"
    done
    for linha in ${orfas[@]+"${orfas[@]}"}; do printf '%s\n' "$linha"; done
  } | sort -k2)" || falhar "Falha ao calcular o manifesto."
  [ -n "$ord" ] || [ -f "$alvo" ] || return 0 # sem linha a registrar e sem manifesto anterior
  : >"$STG/manifesto" || falhar "Falha ao escrever em $STG."
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
  if ! validar_todos; then
    [ "$MODO" != atualizar ] || erro "Corrija o valor no cockpit.config (ou rode sem --atualizar para responder de novo) e repita: $(comando_de_novo)"
    exit 1
  fi
  derivar_prefixos

  # Chaves desconhecidas do cockpit.config existente são mantidas na regravação;
  # comentários próprios da pessoa, não.
  if [ "$MODO" != atualizar ] && [ -f "$cfg" ] && [ ! -L "$cfg" ]; then
    COMENTARIOS_PERDIDOS=false
    ler_kv "$cfg" extras || exit 1
    [ "${#EXTRAS[@]}" -eq 0 ] || aviso "chave(s) desconhecida(s) mantida(s) no cockpit.config:$DESCONHECIDAS"
    ! $COMENTARIOS_PERDIDOS || aviso "comentários, \`export\` e comentários no fim da linha do cockpit.config não são preservados na regravação (exceto nas chaves desconhecidas mantidas)."
  fi

  preparar_templates
  classificar_destinos
  local i
  for ((i = 0; i < ${#DEST_REL[@]}; i++)); do
    [ -z "${PULAR[i]}" ] || [ "${PULAR[i]}" = copia ] || continue
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
