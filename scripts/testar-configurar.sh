#!/usr/bin/env bash
# scripts/testar-configurar.sh — cenários de docs/specs/configurar/quickstart.md.
#
# Cada cenário roda num repositório git temporário; o `cstk` é sempre o falso
# deste script (nunca o real). Sai diferente de zero na primeira falha, dizendo
# qual cenário falhou. Sem framework, sem rede.
# shellcheck disable=SC2015,SC2016 # `A && B || falha` é o idioma dos cenários
# (falha() sai); textos em aspas simples são literais de propósito
set -euo pipefail
export LC_ALL=C

RAIZ_COCKPIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
CENARIO="(nenhum)"

falha() {
  printf 'FALHOU: cenário %s — %s\n' "$CENARIO" "$*" >&2
  exit 1
}
cenario() { CENARIO="$1"; printf 'Cenário %s\n' "$1"; }
espera() { # espera "descrição" comando...
  local d="$1"; shift
  "$@" || falha "$d"
}

# cstk falso: informa a versão de CSTK_FALSO_VERSAO (padrão: o piso) e registra
# os argumentos de `hooks install` em $TMP/cstk.log.
BIN="$TMP/bin"
mkdir -p "$BIN"
cat >"$BIN/cstk" <<'EOF'
#!/bin/sh
case "$1" in
  --version)
    [ -z "${CSTK_FALSO_STDERR:-}" ] || echo "$CSTK_FALSO_STDERR" >&2
    if [ -n "${CSTK_FALSO_SAIDA:-}" ]; then printf '%b' "$CSTK_FALSO_SAIDA"; else echo "cstk ${CSTK_FALSO_PREFIXO-v}${CSTK_FALSO_VERSAO:-0.0.0}"; fi ;;
  --versao-bruta) : ;;
  hooks)
    shift; echo "hooks $*" >>"$CSTK_LOG_FALSO"
    [ -z "${CSTK_FALSO_FALHA:-}" ] || { echo "falha simulada" >&2; exit 7; } ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$BIN/cstk"
export CSTK_LOG_FALSO="$TMP/cstk.log"
# Piso lido pela mesma função do configurar.sh (tolera export, aspas, CRLF).
REPO_ROOT="$RAIZ_COCKPIT"
# shellcheck source=scripts/lib/versao.sh
. "$RAIZ_COCKPIT/scripts/lib/versao.sh"
PISO="$(ler_cstk_min)"
[ -n "$PISO" ] || { echo "FALHOU: CSTK_MIN não encontrado em versoes.env" >&2; exit 1; }
export CSTK_FALSO_VERSAO="$PISO"

sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum <"$1"; else shasum -a 256 <"$1"; fi; }

# PATH sem qualquer cstk (o do usuário inclusive). Um diretório com cstk real é
# trocado por uma cópia de links para tudo, menos o cstk — git, awk e demais
# ferramentas que moram junto continuam no PATH.
PATH_SEM_CSTK=""
IFS=: read -ra _dirs <<<"$PATH"
_n=0
for d in "${_dirs[@]}"; do
  [ -n "$d" ] && [ -d "$d" ] || continue
  if [ -e "$d/cstk" ]; then
    _n=$((_n + 1)); _sombra="$TMP/sem-cstk.$_n"; mkdir -p "$_sombra"
    for f in "$d"/*; do
      [ "$(basename "$f")" = cstk ] || ln -s "$f" "$_sombra/" 2>/dev/null || true
    done
    d="$_sombra"
  fi
  PATH_SEM_CSTK="${PATH_SEM_CSTK:+$PATH_SEM_CSTK:}$d"
done
PATH_COM_FALSO="$BIN:$PATH_SEM_CSTK"

novo_repo() { local r; r="$(mktemp -d "$TMP/proj.XXXXXX")"; git init -q "$r"; printf '%s' "$r"; }
# configurar CAMINHO_DO_CONFIGURAR.SH args... — roda com o cstk falso.
rodar() { local c="$1"; shift; PATH="$PATH_COM_FALSO" "$c" "$@"; }
CONF="$RAIZ_COCKPIT/configurar.sh"
EXEMPLO="$RAIZ_COCKPIT/cockpit.config.example"
# cockpit de teste com templates próprios (cenários 5 e 7).
cockpit_copia() {
  local c; c="$(mktemp -d "$TMP/cockpit.XXXXXX")"
  mkdir -p "$c/scripts"
  cp "$CONF" "$c/configurar.sh"; cp -R "$RAIZ_COCKPIT/scripts/lib" "$c/scripts/lib"
  cp "$RAIZ_COCKPIT/versoes.env" "$c/versoes.env"; cp -R "$RAIZ_COCKPIT/templates" "$c/templates"
  printf '%s' "$c"
}
codigo() { local rc=0; "$@" >"$TMP/out" 2>"$TMP/err" || rc=$?; printf '%s' "$rc"; }

# ---------------------------------------------------------------- 1 ---
cenario "1: configuração do zero, não interativa"
T="$(novo_repo)"; : >"$CSTK_LOG_FALSO"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "exit diferente de 0"
for k in PROJETO_NOME REPO_REMOTO BRANCH_INTEGRACAO BRANCH_PRODUCAO GERENCIADOR_PACOTES CMD_TYPECHECK CMD_LINT CMD_BUILD CMD_DEPLOY_INTEGRACAO CMD_DEPLOY_PRODUCAO IDENTIDADES BOARD PRINCIPIO_III; do
  grep -q "^$k=" "$T/cockpit.config" || falha "chave $k ausente do cockpit.config"
done
espera "source com set -u falhou" bash -c 'set -u; source "$1/cockpit.config"' _ "$T"
! grep -q '{{' "$T/.cockpit/LEIAME.md" || falha "LEIAME.md com placeholder"
espera "manifesto ausente" test -f "$T/.cockpit/manifesto.sha256"
grep -q "^hooks install --project-path $T\$" "$CSTK_LOG_FALSO" || falha "cstk falso não recebeu hooks install --project-path"

# ---------------------------------------------------------------- 2 ---
cenario "2: idempotência byte a byte"
cp -R "$T" "$TMP/copia"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda execução falhou"
diff -r --exclude=.git "$T" "$TMP/copia" >/dev/null || falha "diferença entre execuções"

# ---------------------------------------------------------------- 3 ---
cenario "3: --atualizar"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "--atualizar saiu com $rc"
diff -r --exclude=.git "$T" "$TMP/copia" >/dev/null || falha "--atualizar alterou arquivos"
T2="$(novo_repo)"
rc="$(codigo rodar "$CONF" --projeto "$T2" --atualizar </dev/null)"
[ "$rc" = 1 ] || falha "--atualizar sem config saiu com $rc (esperado 1)"
grep -q 'sem --atualizar' "$TMP/err" || falha "mensagem não cita rodar sem --atualizar"
rc="$(codigo rodar "$CONF" --projeto "$T2" </dev/null)"
[ "$rc" = 1 ] || falha "sem terminal e sem --respostas saiu com $rc (esperado 1)"

# ---------------------------------------------------------------- 4 ---
cenario "4: edição à mão preservada"
echo "editado à mão" >>"$T/.cockpit/LEIAME.md"
cp "$T/.cockpit/LEIAME.md" "$TMP/editado"
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='outro-nome'/" "$EXEMPLO" >"$TMP/resp4"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4")"
[ "$rc" = 2 ] || falha "conflito saiu com $rc (esperado 2)"
cmp -s "$T/.cockpit/LEIAME.md" "$TMP/editado" || falha "arquivo editado foi alterado"
grep -q -- '--forcar' "$TMP/err" || falha "aviso não cita --forcar"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4" --forcar)"
[ "$rc" = 0 ] || falha "--forcar saiu com $rc"
grep -q 'outro-nome' "$T/.cockpit/LEIAME.md" || falha "--forcar não re-renderizou"
grep -q "  .cockpit/LEIAME.md\$" "$T/.cockpit/manifesto.sha256" || falha "manifesto sem o arquivo"
h="$(sha "$T/.cockpit/LEIAME.md")"; h="${h%% *}"
grep -q "^$h  " "$T/.cockpit/manifesto.sha256" || falha "manifesto não foi atualizado"
# Arquivo gerado e não editado é regravado sem --forcar quando o config muda.
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='terceiro-nome'/" "$EXEMPLO" >"$TMP/resp4b"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp4b")"
[ "$rc" = 0 ] || falha "arquivo não editado deveria ser regravado sem --forcar (saiu $rc)"
grep -q 'terceiro-nome' "$T/.cockpit/LEIAME.md" || falha "arquivo não editado não foi re-renderizado"

# ---------------------------------------------------------------- 5 ---
cenario "5: placeholder residual"
C="$(cockpit_copia)"; printf 'valor: {{CHAVE_INEXISTENTE}}\n' >"$C/templates/x.md.tmpl"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 2 ] || falha "residual saiu com $rc (esperado 2)"
grep -q 'x.md.tmpl' "$TMP/err" && grep -q '{{CHAVE_INEXISTENTE}}' "$TMP/err" || falha "stderr não cita template e placeholder"
[ ! -e "$T/x.md" ] || falha "x.md foi criado"
[ ! -e "$T/.cockpit/LEIAME.md" ] || falha "algum template foi movido"
[ -z "$(find "$T" -path "$T/.git" -prune -o -name '.cockpit-tmp.*' -print)" ] || falha "temporário restante"
# URL opcional vazia = ausente: mesmo resultado na 1ª execução e no --atualizar.
C="$(cockpit_copia)"; printf 'url: {{URL_AMBIENTE_INTEGRACAO}}\n' >"$C/templates/u.md.tmpl"
T="$(novo_repo)"
{ grep -v '^URL_AMBIENTE_' "$EXEMPLO"; echo "URL_AMBIENTE_INTEGRACAO=''"; } >"$TMP/resp-url"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$TMP/resp-url")"
[ "$rc" = 2 ] || falha "URL vazia na 1ª execução saiu com $rc (esperado 2, residual)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --atualizar)"
[ "$rc" = 2 ] || falha "URL vazia no --atualizar saiu com $rc (esperado 2, residual)"

# ---------------------------------------------------------------- 6 ---
cenario "6: caracteres especiais"
T="$(novo_repo)"
ESPECIAL='a/b & "c" $HOME \n'"'"'x'
{ grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='a/b & \"c\" \$HOME \\\\n'\\\\''x'\n"; } >"$TMP/resp6"
rodar "$CONF" --projeto "$T" --respostas "$TMP/resp6" >/dev/null 2>&1 || falha "exit diferente de 0"
grep -qF "Build:                  $ESPECIAL" "$T/.cockpit/LEIAME.md" || falha "valor não está literal no LEIAME.md"
[ "$(bash -c 'source "$1/cockpit.config"; printf %s "$CMD_BUILD"' _ "$T")" = "$ESPECIAL" ] || falha "source devolve outro valor"

# ---------------------------------------------------------------- 7 ---
cenario "7: template novo sem mudar o script"
C="$(cockpit_copia)"; mkdir -p "$C/templates/novo"; printf '{{PROJETO_NOME}}\n' >"$C/templates/novo/y.txt.tmpl"
T="$(novo_repo)"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "exit diferente de 0"
[ "$(cat "$T/novo/y.txt")" = "meu-projeto" ] || falha "novo/y.txt não renderizado"
cmp -s "$C/configurar.sh" "$CONF" || falha "configurar.sh mudou"

# ---------------------------------------------------------------- 8 ---
cenario "8: contenção de caminho"
T="$(novo_repo)"; FORA="$(mktemp -d "$TMP/fora.XXXXXX")"; ln -s "$FORA" "$T/.cockpit"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "link simbólico saiu com $rc (esperado 1)"
[ -z "$(ls -A "$FORA")" ] || falha "algo foi escrito fora do projeto"
[ ! -e "$T/cockpit.config" ] || falha "config gravado apesar do erro de contenção"
NAO_GIT="$(mktemp -d "$TMP/nogit.XXXXXX")"
rc="$(codigo rodar "$CONF" --projeto "$NAO_GIT" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "diretório sem git saiu com $rc (esperado 1)"
T="$(novo_repo)"; mkdir "$T/sub"
rc="$(codigo rodar "$CONF" --projeto "$T/sub" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "subdiretório de repo saiu com $rc (esperado 1)"
T="$(novo_repo)"; ln -s "$FORA/alvo" "$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && [ ! -e "$FORA/alvo" ] || falha "cockpit.config link simbólico não foi recusado"

# ---------------------------------------------------------------- 9 ---
cenario "9: validação de respostas"
T="$(novo_repo)"
sed "s#^REPO_REMOTO=.*#REPO_REMOTO='semBarra'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q REPO_REMOTO "$TMP/err" && [ ! -e "$T/cockpit.config" ] || falha "REPO_REMOTO inválido não recusado"
grep -v '^CMD_LINT=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q CMD_LINT "$TMP/err" || falha "CMD_LINT ausente não recusado"
sed "s#^BRANCH_PRODUCAO=.*#BRANCH_PRODUCAO='staging'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && [ ! -s "$TMP/err" ] || falha "produção igual à integração deveria passar sem aviso"
sed "s#^IDENTIDADES=.*#IDENTIDADES=''#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q IDENTIDADES "$TMP/err" || falha "IDENTIDADES vazia não recusada"
sed "s#^IDENTIDADES=.*#IDENTIDADES='Fulana:fulana@exemplo.example'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && grep -q 'noreply' "$TMP/err" || falha "e-mail não noreply deveria passar com aviso"
# Controle real (TAB, ESC), C1 e marca bidi: cada um recusado citando a chave.
for bruto in $'a\tb' $'a\e[31mb' $'a\xc2\x9bb' $'a\xe2\x80\xaeb' $'a\xe2\x80\x8eb' $'a\xe2\x80\xa8b' $'a\xd8\x9cb' $'a\xffb' $'a\xc3'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='%s'\n" "$bruto"; } >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q 'CMD_BUILD' "$TMP/err" && grep -q 'controle' "$TMP/err" \
    || falha "valor com controle $(printf %q "$bruto") não recusado citando CMD_BUILD"
done
# Acentos, € e emoji são legítimos.
{ grep -v '^CMD_BUILD=' "$EXEMPLO"; printf "CMD_BUILD='echo ação € 😀 中文'\n"; } >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] || falha "valor com acentos e emoji recusado"
for repo in "../x" "org/.." "-x/y" "org/-y"; do
  sed "s#^REPO_REMOTO=.*#REPO_REMOTO='$repo'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q REPO_REMOTO "$TMP/err" || falha "REPO_REMOTO '$repo' não recusado"
done
sed "s#^BOARD=.*#BOARD='   '#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q BOARD "$TMP/err" || falha "BOARD só com espaços não recusado"
for b in 'x y' 'org/0' 'org/007' 'org'; do
  sed "s#^BOARD=.*#BOARD='$b'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q BOARD "$TMP/err" || falha "BOARD '$b' não recusado"
done
sed "s#^BOARD=.*#BOARD='org-exemplo/7'#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] || falha "BOARD org-exemplo/7 recusado"
for d in '' '@org-exemplo/time' 'maria' '@maria_x'; do
  sed "s#^DONOS_CODEOWNERS=.*#DONOS_CODEOWNERS='$d'#" "$EXEMPLO" >"$TMP/r"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
  [ "$rc" = 1 ] && grep -q DONOS_CODEOWNERS "$TMP/err" || falha "DONOS_CODEOWNERS '$d' não recusado"
done
sed "s#^DONOS_CODEOWNERS=.*#DONOS_CODEOWNERS='@org-exemplo/time'#" "$EXEMPLO" >"$TMP/r"
codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r" >/dev/null
grep -q 'times' "$TMP/err" || falha "recusa de @org/time não cita times"
grep -v '^DONOS_CODEOWNERS=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q 'DONOS_CODEOWNERS' "$TMP/err" || falha "DONOS_CODEOWNERS ausente deveria falhar"
T9="$(novo_repo)"
rodar "$CONF" --projeto "$T9" --respostas "$EXEMPLO" >/dev/null 2>&1
grep -v '^DONOS_CODEOWNERS=' "$T9/cockpit.config" >"$TMP/c9"; cp "$TMP/c9" "$T9/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T9" --atualizar)"
[ "$rc" = 1 ] && grep -q 'DONOS_CODEOWNERS' "$TMP/err" || falha "--atualizar com config sem DONOS_CODEOWNERS deveria falhar"
grep -v '^PRINCIPIO_III=' "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 1 ] && grep -q 'PRINCIPIO_III' "$TMP/err" || falha "PRINCIPIO_III ausente deveria falhar (FR-016)"
sed "s#^IDENTIDADES=.*#IDENTIDADES=' A:1+a@users.noreply.github.com ; B:2+b@users.noreply.github.com '#" "$EXEMPLO" >"$TMP/r"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r")"
[ "$rc" = 0 ] && grep -q "^IDENTIDADES='A:1+a@users.noreply.github.com;B:2+b@users.noreply.github.com'\$" "$T/cockpit.config" \
  || falha "IDENTIDADES com espaços em volta do ; não foi aceita e normalizada"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" --atualizar)"
[ "$rc" = 1 ] || falha "--atualizar com --respostas saiu com $rc (esperado 1)"

# --------------------------------------------------------------- 10 ---
cenario "10: cstk ausente ou abaixo do piso"
T="$(novo_repo)"
rc="$(PATH="$PATH_SEM_CSTK" codigo "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "cstk ausente saiu com $rc (esperado 3)"
[ -f "$T/cockpit.config" ] && [ -f "$T/.cockpit/LEIAME.md" ] || falha "config/templates não mantidos"
grep -q '^Execute:' "$TMP/out" || falha "stdout sem Execute:"
T="$(novo_repo)"
rc="$(CSTK_FALSO_VERSAO=0.0.1 codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "cstk abaixo do piso saiu com $rc (esperado 3)"
grep -q '^Execute:' "$TMP/out" || falha "stdout sem Execute: (abaixo do piso)"
# Aviso com número de versão em stderr não burla o piso.
T="$(novo_repo)"
rc="$(CSTK_FALSO_VERSAO=0.0.1 CSTK_FALSO_STDERR="aviso: node 999.9.9 obsoleto" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "versão em stderr burlou o piso (saiu $rc)"
# Pré-release do próprio piso fica abaixo dele.
rc="$(CSTK_FALSO_VERSAO="$PISO-rc1" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "pré-release do piso aceito (saiu $rc)"
# Versão só com major, acima do piso, é reconhecida.
rc="$(CSTK_FALSO_VERSAO="$(( ${PISO%%.*} + 1 ))" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] || falha "versão só com major não reconhecida (saiu $rc)"
# Formatos de saída reais: CRLF, +build, parênteses, ponto final, número espúrio.
T="$(novo_repo)"
for saida in "cstk $PISO\\r\\n" "cstk $PISO+build5\\n" "cstk (v$PISO)\\n" "cstk v$PISO.\\n" "cstk: 3 plugins carregados\\ncstk v$PISO\\n" "aviso: nova versão 99.0.0 disponível\\ncstk v$PISO\\n"; do
  rc="$(CSTK_FALSO_SAIDA="$saida" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
  [ "$rc" = 0 ] || falha "saída de versão '$saida' não reconhecida (saiu $rc)"
done
rc="$(CSTK_FALSO_SAIDA="aviso: nova versão 99.0.0 disponível\\ncstk v0.0.1\\n" codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 3 ] || falha "versão de outra linha burlou o piso (saiu $rc)"
# hooks install falhando: exit 4, config e templates mantidos.
T="$(novo_repo)"
rc="$(CSTK_FALSO_FALHA=1 codigo env PATH="$PATH_COM_FALSO" "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 4 ] && [ -f "$T/cockpit.config" ] && [ -f "$T/.cockpit/LEIAME.md" ] || falha "hooks install falhando saiu com $rc (esperado 4)"

# --------------------------------------------------------------- 12 ---
cenario "12: leitura do cockpit.config"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
cp "$T/.cockpit/LEIAME.md" "$TMP/leiame12"
# Espaço/comentário depois das aspas, export e BOM: lidos como `source` leria.
{ printf '\xef\xbb\xbf# config\n'; sed -e "s/^CMD_LINT=\(.*\)\$/export CMD_LINT=\1   # lint/" -e "s/^CMD_BUILD=\(.*\)\$/CMD_BUILD=\1 /" "$T/cockpit.config"; } >"$TMP/c12"
cp "$TMP/c12" "$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar)"
[ "$rc" = 0 ] || falha "config com BOM/export/comentário saiu com $rc"
cmp -s "$T/.cockpit/LEIAME.md" "$TMP/leiame12" || falha "valores lidos com aspas ou comentário no valor"
printf "CMD_BUILD='a' b\n" >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar)"
[ "$rc" = 1 ] && grep -q 'CMD_BUILD' "$TMP/err" || falha "aspas malformadas não recusadas"
# Formas lidas por `source` de outro jeito: recusadas citando a chave.
for linha in "CMD_BUILD='a'#c" 'CMD_BUILD="b"#d' 'CMD_BUILD=$HOME/x' "CMD_BUILD=a'b" 'CMD_BUILD="x$y"'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf '%s\n' "$linha"; } >"$TMP/r12"
  rc="$(codigo rodar "$CONF" --projeto "$(novo_repo)" --respostas "$TMP/r12")"
  [ "$rc" = 1 ] && grep -q CMD_BUILD "$TMP/err" || falha "forma '$linha' não recusada"
done
# Aceitas: aspa dentro do comentário e forma legada sem aspas (exemplo antigo).
for linha in "CMD_BUILD='a' # it's" 'CMD_BUILD=npm run build'; do
  { grep -v '^CMD_BUILD=' "$EXEMPLO"; printf '%s\n' "$linha"; } >"$TMP/r12"
  rc="$(codigo rodar "$CONF" --projeto "$(novo_repo)" --respostas "$TMP/r12")"
  [ "$rc" = 0 ] || falha "forma '$linha' deveria ser aceita (saiu $rc)"
done
# Chave desconhecida é mantida na regravação.
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
printf "CMD_TESTE='npm test'\n" >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q "^CMD_TESTE='npm test'\$" "$T/cockpit.config" && grep -q 'mantida' "$TMP/err" \
  || falha "chave desconhecida não foi mantida no cockpit.config"
# --respostas com config antigo malformado: linha avisada e ignorada, sem abortar;
# chave desconhecida com valor fora do formato não é copiada; export mantido.
printf 'lixo sem igual\nFOO=\x27sem fim\nexport QUX=1\n' >>"$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q 'não será mantida' "$TMP/err" || falha "config antigo malformado abortou o --respostas (saiu $rc)"
! grep -q '^FOO=' "$T/cockpit.config" && grep -q '^export QUX=1$' "$T/cockpit.config" || falha "extras malformados copiados ou export perdido"
espera "cockpit.config com extras não carrega com source" bash -c 'set -u; source "$1/cockpit.config"' _ "$T"
cp "$T/cockpit.config" "$TMP/c12b"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda regravação falhou"
cmp -s "$T/cockpit.config" "$TMP/c12b" || falha "regravação com chave mantida não é idempotente"

# --------------------------------------------------------------- 13 ---
cenario "13: templates e falhas de escrita"
C="$(cockpit_copia)"
printf '#!/bin/sh\necho {{PROJETO_NOME}}\n' >"$C/templates/exec.sh.tmpl"; chmod +x "$C/templates/exec.sh.tmpl"
printf 'sem newline {{PROJETO_NOME}}' >"$C/templates/semnl.txt.tmpl"
T="$(novo_repo)"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render falhou"
[ -x "$T/exec.sh" ] || falha "template executável perdeu o bit de execução"
[ "$(tail -c 1 "$T/semnl.txt")" = o ] || falha "newline final acrescentado ao template sem newline"
# Conteúdo igual, modo diferente: o bit de execução volta a seguir o template.
chmod a-x "$T/exec.sh"
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ -x "$T/exec.sh" ] || falha "bit de execução não sincronizado com o template"
# Com o cockpit num repositório git, o modo registrado no git manda (clone sob
# /mnt no WSL mostra todo arquivo como executável).
(cd "$C" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm t) \
  || falha "não consegui versionar a cópia do cockpit"
chmod +x "$C/templates/semnl.txt.tmpl"
(cd "$C" && git update-index --chmod=-x templates/semnl.txt.tmpl)
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ ! -x "$T/semnl.txt" ] || falha "bit de execução do disco venceu o modo 100644 do git"
chmod a-x "$C/templates/exec.sh.tmpl"
(cd "$C" && git update-index --chmod=+x templates/exec.sh.tmpl)
rodar "$C/configurar.sh" --projeto "$T" --atualizar >/dev/null 2>&1 || falha "--atualizar falhou"
[ -x "$T/exec.sh" ] || falha "modo 100755 do git não aplicado"
# Permissão restritiva do destino é mantida na regravação.
chmod 600 "$T/semnl.txt" "$T/cockpit.config"
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='outro'/" "$EXEMPLO" >"$TMP/r13m"
rodar "$C/configurar.sh" --projeto "$T" --respostas "$TMP/r13m" >/dev/null 2>&1 || falha "regravação falhou"
[ "$(stat -c %a "$T/semnl.txt" 2>/dev/null || stat -f %Lp "$T/semnl.txt")" = 600 ] || falha "permissão 600 do template perdida"
[ "$(stat -c %a "$T/cockpit.config" 2>/dev/null || stat -f %Lp "$T/cockpit.config")" = 600 ] || falha "permissão 600 do cockpit.config perdida"
# Template removido do cockpit: aviso, arquivo e linha do manifesto mantidos.
rm "$C/templates/semnl.txt.tmpl"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --atualizar)"
[ "$rc" = 0 ] && grep -q 'semnl.txt não é mais gerado' "$TMP/err" && [ -f "$T/semnl.txt" ] \
  && grep -q '  semnl.txt$' "$T/.cockpit/manifesto.sha256" || falha "órfão não foi avisado e mantido"
# Destinos duplicados ou dentro de .git: recusados.
C="$(cockpit_copia)"; printf 'a\n' >"$C/templates/d.md"; printf 'b\n' >"$C/templates/d.md.tmpl"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q 'mesmo destino' "$TMP/err" || falha "destino duplicado não recusado"
for g in .git/hooks/pre-commit .GIT/hooks/pre-commit sub/.git/config Cockpit.config.tmpl; do
  C="$(cockpit_copia)"; mkdir -p "$(dirname "$C/templates/$g")"; printf 'x\n' >"$C/templates/$g"
  rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
  [ "$rc" = 1 ] && grep -q 'reservado' "$TMP/err" || falha "destino reservado $g não recusado"
done
C="$(cockpit_copia)"; printf 'a\n' >"$C/templates/D.md"; printf 'b\n' >"$C/templates/d.md"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$(novo_repo)" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q 'mesmo destino' "$TMP/err" || falha "destinos que só diferem em maiúsculas não recusados"
# Destino que existe e não é arquivo regular (FIFO): recusado sem travar.
if command -v mkfifo >/dev/null 2>&1; then
  T="$(novo_repo)"; mkdir -p "$T/.cockpit"; mkfifo "$T/.cockpit/LEIAME.md"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" </dev/null)"
  [ "$rc" = 1 ] && grep -q 'não é arquivo regular' "$TMP/err" || falha "destino FIFO não recusado (saiu $rc)"
fi
# Falha de escrita não passa em silêncio: sai != 0 e não anuncia gravação.
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "configuração inicial falhou"
if [ "$(id -u)" != 0 ]; then
  sed "s/^PROJETO_NOME=.*/PROJETO_NOME='mudou'/" "$EXEMPLO" >"$TMP/r13"
  chmod 555 "$T/.cockpit"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r13")"
  chmod 755 "$T/.cockpit"
  [ "$rc" != 0 ] && ! grep -q 'Guard hooks provisionados' "$TMP/out" && ! grep -q 'gravado: ' "$TMP/out" \
    && grep -q 'Falha' "$TMP/err" || falha "falha de escrita saiu com $rc ou anunciou gravação"
fi
# Barra invertida no caminho do projeto não desliga a detecção de residual.
C="$(cockpit_copia)"; printf 'v: {{CHAVE_INEXISTENTE}}\n' >"$C/templates/x.md.tmpl"
T="$TMP/proj\\tbarra"; mkdir -p "$T"; git init -q "$T"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 2 ] && [ ! -e "$T/x.md" ] || falha "residual com barra invertida no caminho saiu com $rc (esperado 2)"
# Sem templates: nada a renderizar, sem manifesto vazio.
C="$(cockpit_copia)"; rm -rf "$C/templates"; mkdir "$C/templates"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q 'nada havia a renderizar' "$TMP/out" && [ ! -e "$T/.cockpit/manifesto.sha256" ] \
  || falha "sem templates: mensagem ou manifesto errados"
# Na raiz do próprio cockpit, sem --projeto: recusado.
C="$(cockpit_copia)"; git init -q "$C"
rc="$(cd "$C" && PATH="$PATH_COM_FALSO" codigo ./configurar.sh --respostas "$EXEMPLO")"
[ "$rc" = 1 ] && grep -q -- '--projeto' "$TMP/err" && [ ! -e "$C/cockpit.config" ] || falha "raiz do cockpit sem --projeto não recusada"

# --------------------------------------------------------------- 14 ---
cenario "14: modo interativo (pty)"
if command -v script >/dev/null 2>&1 && script -qec true /dev/null >/dev/null 2>&1; then
  # interativo ENTRADA ARGS... — roda o configurar num pty com a entrada dada.
  interativo() {
    local entrada="$1"; shift
    printf '%b' "$entrada" | PATH="$PATH_COM_FALSO" script -qec "$(printf '%q ' "$CONF" "$@")" /dev/null >"$TMP/tty" 2>&1
  }
  T="$(novo_repo)"
  # 12 chaves, depois nome/e-mail de duas identidades, nome vazio encerra,
  # board, Enter no Princípio III (sugere ligado) e - nos destinos do projeto.
  interativo 'proj\norg/repo\ndev\nmain\nnpm\nnpm run tc\nnpm run lint\nnpm run build\nnpm run d:i\nnpm run d:p\n-\n-\nAna Silva\n1+ana@users.noreply.github.com\nBeto\n2+beto@users.noreply.github.com\n\n@ana-exemplo\norg-exemplo/9\n\n-\n-\n\n' --projeto "$T" \
    || falha "configuração interativa falhou: $(tail -3 "$TMP/tty")"
  grep -q "^IDENTIDADES='Ana Silva:1+ana@users.noreply.github.com;Beto:2+beto@users.noreply.github.com'\$" "$T/cockpit.config" \
    || falha "nome e e-mail separados não gravados como nome:email"
  grep -q "^PRINCIPIO_III='ligado'\$" "$T/cockpit.config" || falha "Enter no Princípio III não aceitou o sugerido"
  # SC-001 (ajustado por FR-007 da feature destinos-do-projeto): configuração mínima
  # (uma identidade) com exatamente 21 respostas (18 + DESTINOS_DO_PROJETO + PREFIXOS_BRANCH + MODO_AUTONOMO).
  MINIMO18='proj\norg/repo\ndev\nmain\nnpm\nnpm run tc\nnpm run lint\nnpm run build\nnpm run d:i\nnpm run d:p\n-\n-\nAna\n1+ana@users.noreply.github.com\n\n@ana-exemplo\n-\n\n'
  MINIMO19="$MINIMO18-\n"
  MINIMO="$MINIMO19-\n\n"  # + prefixos (-) e MODO_AUTONOMO (Enter = desligado)
  [ "$(printf '%b' "$MINIMO" | wc -l | tr -d ' ')" = 21 ] || falha "entrada mínima não tem 21 respostas"
  T3="$(novo_repo)"
  interativo "$MINIMO" --projeto "$T3" || falha "configuração mínima com 21 respostas falhou: $(tail -3 "$TMP/tty")"
  [ -f "$T3/cockpit.config" ] && [ -f "$T3/.cockpit/LEIAME.md" ] || falha "configuração mínima não gravou config e templates"
  ! grep -q '^DESTINOS_DO_PROJETO=' "$T3/cockpit.config" || falha "- nos destinos gravou a chave"
  ! grep -q '^PREFIXOS_BRANCH=' "$T3/cockpit.config" || falha "- nos prefixos gravou a chave"
  T3="$(novo_repo)"
  ! interativo "$MINIMO19" --projeto "$T3" \
    || falha "configuração concluiu com 19 respostas; a mínima passou a 21"
  # Config incompleto: só a chave ausente é perguntada.
  grep -v '^BOARD=' "$T/cockpit.config" >"$TMP/c14"; cp "$TMP/c14" "$T/cockpit.config"
  interativo 'org-exemplo/3\n-\n-\n-\n-\n' --projeto "$T" || falha "interativo com config incompleto falhou: $(tail -3 "$TMP/tty")"
  grep -q 'ausente(s) no cockpit.config: BOARD' "$TMP/tty" || falha "chave ausente não foi reportada"
  ! grep -q 'Nome do projeto' "$TMP/tty" || falha "config incompleto perguntou chave já definida"
  grep -q "^BOARD='org-exemplo/3'\$" "$T/cockpit.config" || falha "chave ausente não foi gravada"
  # Nome com ':' é recusado e perguntado de novo; vazio depois mantém as atuais.
  interativo '\n\n\n\n\n\n\n\n\n\n\n\nA:B\n\n\n\n\n\n\n\n' --projeto "$T" || falha "reentrada de identidade falhou: $(tail -3 "$TMP/tty")"
  grep -q "não pode conter ':'" "$TMP/tty" || falha "nome com ':' não recusado"
  grep -q "^IDENTIDADES='Ana Silva:" "$T/cockpit.config" || falha "identidades atuais não mantidas"
  # Pergunta nova (FR-007): texto, dica e gravação.
  T4="$(novo_repo)"
  interativo "${MINIMO18}CLAUDE.md\n-\n\n" --projeto "$T4" || falha "rodada com destinos falhou: $(tail -3 "$TMP/tty")"
  grep -q 'Destinos mantidos pelo projeto' "$TMP/tty" || falha "pergunta dos destinos ausente"
  grep -q 'Destinos mantidos pelo projeto (caminhos separados por espaço) (- para vazio)' "$TMP/tty" || falha "dica (- para vazio) ausente"
  grep -q "^DESTINOS_DO_PROJETO='CLAUDE.md'\$" "$T4/cockpit.config" || falha "DESTINOS_DO_PROJETO não gravado"
  # Prefixos de branch (cenário 20, caso 5): dica, valor inválido repete a pergunta, segundo valor gravado.
  T5="$(novo_repo)"
  interativo "${MINIMO19}a/b c d e f\nfeat fix chore docs hotfix\n\n" --projeto "$T5" || falha "rodada com prefixos falhou: $(tail -3 "$TMP/tty")"
  grep -q 'padrão: feature fix chore docs hotfix) (- para vazio)' "$TMP/tty" || falha "dica do padrão ausente"
  grep -q "PREFIXOS_BRANCH: o prefixo 'a/b' contém '/'" "$TMP/tty" || falha "valor inválido não citou a chave"
  grep -q "^PREFIXOS_BRANCH='feat fix chore docs hotfix'\$" "$T5/cockpit.config" || falha "segundo valor não gravado"
else
  printf '  (script(1) ausente — cenário interativo pulado)\n'
fi

# --------------------------------------------------------------- 15 ---
cenario "15: templates de governança reais"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render com cockpit.config.example falhou"
for f in docs/constitution.md CLAUDE.md docs/rito-dev.md docs/CICLO-GIT.md docs/project-context.md \
  docs/agentes/guardiao.md docs/agentes/implementador.md docs/agentes/revisor.md docs/agentes/triador.md; do
  [ -f "$T/$f" ] || falha "arquivo gerado ausente: $f"
  ! grep -q '{{' "$T/$f" || falha "placeholder residual em $f"
  ! grep -q 'URL_AMBIENTE' "$T/$f" || falha "chave opcional URL_AMBIENTE_* em $f"
done
# Nenhum template real usa chave opcional (a ausência delas não pode deixar resíduo).
[ -d "$RAIZ_COCKPIT/templates" ] || falha "diretório templates/ ausente"
! grep -rq 'URL_AMBIENTE' "$RAIZ_COCKPIT/templates" || falha "template usa chave opcional URL_AMBIENTE_*"
! grep -rq 'DESTINOS_DO_PROJETO' "$RAIZ_COCKPIT/templates" || falha "template usa chave opcional DESTINOS_DO_PROJETO"
! grep -rq 'PREFIXOS_BRANCH' "$RAIZ_COCKPIT/templates" || falha "template usa chave opcional PREFIXOS_BRANCH"
# Princípios na ordem, seção de princípios próprios e o que o pre-flight do /feature-00c exige.
ordem="$(grep -oE '^### [IVX]+(-bis)?\. ' "$T/docs/constitution.md" | tr -d '#. ' | tr '\n' ' ')"
[ "$ordem" = "II II-bis III IV IV-bis V VI VII VIII " ] || falha "princípios fora de ordem: $ordem"
grep -q '^## Core Principles$' "$T/docs/constitution.md" || falha "constituição sem ## Core Principles"
grep -q '^## Princípios próprios do projeto$' "$T/docs/constitution.md" || falha "seção de princípios próprios ausente"
grep -qE '^\*\*Version\*\*: [0-9]+\.[0-9]+\.[0-9]+' "$T/docs/constitution.md" || falha "constituição sem rodapé **Version**"
for n in 1 2 3 4 5 6 7 8 9 10 11; do
  grep -q "^## Fase $n — " "$T/docs/rito-dev.md" || falha "Fase $n ausente do rito"
done
for a in guardiao implementador revisor triador; do
  for s in Responsabilidade Entradas Saídas Limites; do
    grep -q "^## $s\$" "$T/docs/agentes/$a.md" || falha "seção $s ausente em agentes/$a.md"
  done
done
# Idempotência (FR-014): segunda execução não altera nenhum arquivo gerado.
cp -R "$T" "$TMP/copia15"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "segunda execução falhou"
diff -r --exclude=.git "$T" "$TMP/copia15" >/dev/null || falha "segunda execução alterou arquivos gerados"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "--atualizar saiu com $rc"
diff -r --exclude=.git "$T" "$TMP/copia15" >/dev/null || falha "--atualizar alterou arquivos gerados"
# Variação: Princípio III desligado e integração igual a produção (branch única).
T="$(novo_repo)"
sed -e "s/^PRINCIPIO_III=.*/PRINCIPIO_III='desligado'/" \
  -e "s/^BRANCH_PRODUCAO=.*/$(grep '^BRANCH_INTEGRACAO=' "$EXEMPLO" | sed 's/INTEGRACAO/PRODUCAO/')/" \
  "$EXEMPLO" >"$TMP/variacao15.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/variacao15.config")"
[ "$rc" = 0 ] || falha "render da variação saiu com $rc: $(cat "$TMP/err")"
grep -q 'Valor configurado neste projeto: \*\*desligado\*\*' "$T/docs/constitution.md" || falha "Princípio III não mostra desligado"
grep -q 'esta fase é \*\*no-op\*\*' "$T/docs/rito-dev.md" || falha "rito sem o no-op da promoção"
! grep -rq '{{' "$T/docs" "$T/CLAUDE.md" || falha "placeholder residual na variação"

# --------------------------------------------------------------- 16 ---
cenario "16: templates de automação (fluxos, CODEOWNERS, releaserc, task.sh)"
AUTOMACAO=".github/workflows/ci.yml .github/workflows/commitlint.yml .github/workflows/require-codeowner-approval.yml .github/workflows/promotion-pr.yml .github/workflows/audit-merge-vermelho.yml .github/workflows/release.yml .github/workflows/caminhos-previstos.yml .github/CODEOWNERS .releaserc.json .claude/scripts/task.sh"
# CMD_LINT com caracteres especiais (quickstart Cenário 4) e BOARD preenchido (Cenário 6).
LINT_ESPECIAL='npm run lint -- --fix | tee "$X" && echo `ok`'
grep -v -e '^CMD_LINT=' -e '^BOARD=' "$EXEMPLO" >"$TMP/auto.config"
printf "CMD_LINT='%s'\nBOARD='org-exemplo/7'\n" "$LINT_ESPECIAL" >>"$TMP/auto.config"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$TMP/auto.config" >/dev/null 2>&1 || falha "render da automação falhou"
n=0
for f in $AUTOMACAO; do
  [ -f "$T/$f" ] || falha "arquivo de automação ausente: $f"
  n=$((n + 1))
  ! grep -qE '\{\{[A-Z][A-Z0-9_]*\}\}' "$T/$f" || falha "placeholder residual em $f"
  # FR-017: cada expressão ${{ ... }} do template atravessa a renderização intacta.
  [ -f "$RAIZ_COCKPIT/templates/$f.tmpl" ] || falha "template ausente: $f.tmpl"
  [ "$(grep -o '\${{[^}]*}}' "$RAIZ_COCKPIT/templates/$f.tmpl" | sort)" = "$(grep -o '\${{[^}]*}}' "$T/$f" | sort)" ] \
    || falha "expressão \${{ }} alterada em $f"
done
[ "$n" = 10 ] || falha "esperados 10 arquivos de automação, contei $n"
[ -x "$T/.claude/scripts/task.sh" ] || falha "task.sh sem bit de execução"
grep -qF "          $LINT_ESPECIAL" "$T/.github/workflows/ci.yml" || falha "CMD_LINT não chegou byte a byte ao ci.yml"
grep -q '^\* @maria-exemplo @jose-exemplo$' "$T/.github/CODEOWNERS" || falha "CODEOWNERS sem os donos do exemplo"
python3 -m json.tool "$T/.releaserc.json" >/dev/null || falha ".releaserc.json inválido"
grep -q '"branches": \["main"\]' "$T/.releaserc.json" || falha ".releaserc.json sem a branch de produção"
bash -n "$T/.claude/scripts/task.sh" || falha "task.sh com erro de sintaxe"
# task.sh: BOARD vazio sai 3; BOARD preenchido sem gh sai 4 (FR-013).
sed "s#^BOARD=.*#BOARD=''#" "$EXEMPLO" >"$TMP/semboard.config"
T2="$(novo_repo)"
rodar "$CONF" --projeto "$T2" --respostas "$TMP/semboard.config" >/dev/null 2>&1 || falha "render sem board falhou"
rc="$(codigo "$T2/.claude/scripts/task.sh" list)"
[ "$rc" = 3 ] && grep -q 'não tem board' "$TMP/err" || falha "task.sh com BOARD vazio deveria sair 3 (saiu $rc)"
mkdir -p "$TMP/semgh"; for b in bash env cat; do ln -sf "$(command -v "$b")" "$TMP/semgh/$b"; done
rc="$(codigo env PATH="$TMP/semgh" "$T/.claude/scripts/task.sh" discover)"
[ "$rc" = 4 ] || falha "task.sh sem gh deveria sair 4 (saiu $rc)"
rc="$(codigo "$T/.claude/scripts/task.sh" --help)"
[ "$rc" = 0 ] || falha "task.sh --help deveria sair 0"
# promotion-pr: com integração = produção o passo sai 0 sem chamar o gh (SC-005).
T3="$(novo_repo)"
sed -e "s/^BRANCH_PRODUCAO=.*/$(grep '^BRANCH_INTEGRACAO=' "$EXEMPLO" | sed 's/INTEGRACAO/PRODUCAO/')/" "$EXEMPLO" >"$TMP/igual.config"
rodar "$CONF" --projeto "$T3" --respostas "$TMP/igual.config" >/dev/null 2>&1 || falha "render com branches iguais falhou"
awk '/^          TOKEN_PADRAO/ {d=1} d && /run: \|/ {r=1; next} r {sub(/^          /, ""); print}' \
  "$T3/.github/workflows/promotion-pr.yml" >"$TMP/promocao.sh"
[ -s "$TMP/promocao.sh" ] || falha "não extraí o passo do promotion-pr"
mkdir -p "$TMP/ghfalso"; printf '#!/bin/sh\necho chamado >"%s/gh-chamado"\nexit 99\n' "$TMP" >"$TMP/ghfalso/gh"; chmod +x "$TMP/ghfalso/gh"
rm -f "$TMP/gh-chamado"
branch_unica="$(sed -n "s/^BRANCH_INTEGRACAO='\(.*\)'\$/\1/p" "$EXEMPLO")"
rc="$(codigo env PATH="$TMP/ghfalso:$PATH" INTEGRACAO="$branch_unica" PRODUCAO="$branch_unica" bash "$TMP/promocao.sh")"
[ "$rc" = 0 ] && [ ! -f "$TMP/gh-chamado" ] || falha "promotion-pr com branches iguais deveria sair 0 sem chamar gh (saiu $rc)"
grep -q 'nada a promover' "$TMP/out" || falha "promotion-pr sem a mensagem de no-op"
# Idempotência (SC-004): segunda execução e --atualizar não alteram conteúdo nem modo.
modos() { (cd "$1" && for f in $AUTOMACAO; do printf '%s %s\n' "$(stat -c '%a' "$f")" "$(sha256sum <"$f")"; done); }
antes="$(modos "$T")"
rodar "$CONF" --projeto "$T" --respostas "$TMP/auto.config" >/dev/null 2>&1 || falha "segunda execução da automação falhou"
[ "$(modos "$T")" = "$antes" ] || falha "segunda execução alterou a automação"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] && [ "$(modos "$T")" = "$antes" ] || falha "--atualizar alterou a automação"
# Ferramentas estáticas: no CI (COCKPIT_EXIGIR_FERRAMENTAS=1) a ausência é falha.
for ferr in actionlint shellcheck; do
  command -v "$ferr" >/dev/null 2>&1 && continue
  [ "${COCKPIT_EXIGIR_FERRAMENTAS:-}" != 1 ] || falha "$ferr ausente no CI"
  printf '  (%s ausente nesta máquina — checado no CI)\n' "$ferr"
done
if command -v actionlint >/dev/null 2>&1; then
  # $T carrega o CMD_LINT com caracteres especiais de propósito: é valor do projeto, não do
  # template, então o shellcheck embutido fica desligado aqui; $T3 (valores do exemplo) o roda.
  (cd "$T" && actionlint -shellcheck= .github/workflows/*.yml) || falha "actionlint com findings"
  (cd "$T3" && actionlint .github/workflows/*.yml) || falha "actionlint com findings (branches iguais)"
fi
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "$T/.claude/scripts/task.sh" || falha "shellcheck com findings no task.sh renderizado"
fi

# --------------------------------------------------------------- 17 ---
cenario "17: modo semente"
SEM="CLAUDE.md docs/constitution.md docs/project-context.md"
# 1: semente nova é gravada e entra no manifesto
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 1: exit diferente de 0"
for f in $SEM; do
  [ -f "$T/$f" ] || falha "caso 1: $f não gravado"
  grep -q "  $f\$" "$T/.cockpit/manifesto.sha256" || falha "caso 1: $f fora do manifesto"
done
# 2: semente existente fica intacta, com aviso e sem entrada no manifesto
T="$(novo_repo)"; printf 'meu claude\n' >"$T/CLAUDE.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] || falha "caso 2: exit $rc"
[ "$(cat "$T/CLAUDE.md")" = "meu claude" ] || falha "caso 2: CLAUDE.md alterado"
grep -q '^  mantido (semente): CLAUDE.md$' "$TMP/out" || falha "caso 2: sem aviso de semente mantida"
grep -q '1 mantido(s) (semente)' "$TMP/out" || falha "caso 2: contagem sem mantido(s)"
[ -f "$T/docs/constitution.md" ] || falha "caso 2: demais não gravados"
! grep -q '  CLAUDE.md$' "$T/.cockpit/manifesto.sha256" || falha "caso 2: CLAUDE.md entrou no manifesto"
# 3: --forcar não toca a semente, mas re-renderiza o não semente
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='forcado'/" "$EXEMPLO" >"$TMP/resp17"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp17" --forcar)"
[ "$rc" = 0 ] || falha "caso 3: exit $rc"
[ "$(cat "$T/CLAUDE.md")" = "meu claude" ] || falha "caso 3: --forcar tocou a semente"
grep -q 'forcado' "$T/.cockpit/LEIAME.md" || falha "caso 3: não semente não re-renderizado"
# 4: conflito de não semente recusa o lote sem citar semente
echo editado >>"$T/.cockpit/LEIAME.md"
sed "s/^PROJETO_NOME=.*/PROJETO_NOME='outro17'/" "$EXEMPLO" >"$TMP/resp17b"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp17b")"
[ "$rc" = 2 ] || falha "caso 4: exit $rc (esperado 2)"
grep -q '.cockpit/LEIAME.md' "$TMP/err" || falha "caso 4: stderr não cita LEIAME.md"
! grep -q 'CLAUDE.md' "$TMP/err" || falha "caso 4: stderr cita a semente"
# 5: --atualizar após editar a constituição
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 5: setup"
cp "$T/.cockpit/manifesto.sha256" "$TMP/man5"
echo "principio proprio" >>"$T/docs/constitution.md"; cp "$T/docs/constitution.md" "$TMP/const5"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "caso 5: --atualizar saiu com $rc"
cmp -s "$T/docs/constitution.md" "$TMP/const5" || falha "caso 5: constituição alterada"
cmp -s "$T/.cockpit/manifesto.sha256" "$TMP/man5" || falha "caso 5: manifesto mudou"
# 6: colisão X.tmpl x X.semente.tmpl
C="$(cockpit_copia)"; T="$(novo_repo)"; printf 'x\n' >"$C/templates/CLAUDE.md.tmpl"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "caso 6: exit $rc (esperado 1)"
grep -q 'Templates com o mesmo destino' "$TMP/err" || falha "caso 6: mensagem de colisão ausente"
# 7: residual só conta se a semente for gravada
C="$(cockpit_copia)"; printf '{{CHAVE_INEXISTENTE}}\n' >"$C/templates/extra.md.semente.tmpl"
T="$(novo_repo)"; printf 'ja existe\n' >"$T/extra.md"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] || falha "caso 7: semente pulada saiu com $rc"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 2 ] || falha "caso 7: semente a gravar saiu com $rc (esperado 2)"
grep -q 'Placeholder sem valor' "$TMP/err" || falha "caso 7: sem mensagem de placeholder"
# 8: destino diretório ou link quebrado
T="$(novo_repo)"; mkdir "$T/CLAUDE.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ -d "$T/CLAUDE.md" ] || falha "caso 8: destino diretório (exit $rc)"
T="$(novo_repo)"; ln -s nao-existe "$T/CLAUDE.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ -L "$T/CLAUDE.md" ] && [ ! -e "$T/CLAUDE.md" ] || falha "caso 8: link quebrado (exit $rc)"
# 9: pai inexistente é criado; pai que é arquivo falha
C="$(cockpit_copia)"; mkdir -p "$C/templates/sub"; printf 'ok\n' >"$C/templates/sub/x.md.semente.tmpl"
T="$(novo_repo)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ -f "$T/sub/x.md" ] || falha "caso 9: pai inexistente (exit $rc)"
T="$(novo_repo)"; printf 'arquivo\n' >"$T/sub"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$T" --respostas "$EXEMPLO")"
[ "$rc" = 1 ] || falha "caso 9: pai arquivo saiu com $rc (esperado 1)"

# --------------------------------------------------------------- 18 ---
cenario "18: destinos do projeto"
# resp18 DESTINOS ARQ — respostas do exemplo com a chave DESTINOS_DO_PROJETO.
resp18() { { grep -v '^DESTINOS_DO_PROJETO=' "$EXEMPLO"; printf "DESTINOS_DO_PROJETO='%s'\n" "$1"; } >"$2"; }
# 1 e 2: destino editado e listado fica intacto com --forcar e com --atualizar
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 1: setup"
echo "meu rito" >"$T/docs/rito-dev.md"; cp "$T/docs/rito-dev.md" "$TMP/rito18"
grep '  docs/rito-dev.md$' "$T/.cockpit/manifesto.sha256" >"$TMP/linha18" || falha "caso 1: rito fora do manifesto"
resp18 'docs/rito-dev.md' "$TMP/resp18"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18" --forcar)"
[ "$rc" = 0 ] || falha "caso 1: exit $rc: $(cat "$TMP/err")"
cmp -s "$T/docs/rito-dev.md" "$TMP/rito18" || falha "caso 1: destino listado alterado com --forcar"
grep -q '^  mantido (projeto): docs/rito-dev.md$' "$TMP/out" || falha "caso 1: sem 'mantido (projeto)'"
grep -q '1 mantido(s) (projeto)' "$TMP/out" || falha "caso 1: contagem sem mantido(s) (projeto)"
grep '  docs/rito-dev.md$' "$T/.cockpit/manifesto.sha256" | cmp -s - "$TMP/linha18" || falha "caso 1: linha do manifesto não preservada"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "caso 2: --atualizar saiu com $rc"
cmp -s "$T/docs/rito-dev.md" "$TMP/rito18" || falha "caso 2: destino listado alterado com --atualizar"
grep -q '^  mantido (projeto): docs/rito-dev.md$' "$TMP/out" || falha "caso 2: sem 'mantido (projeto)'"
# 3: semente listada e ausente não é gerada
T="$(novo_repo)"; resp18 'CLAUDE.md' "$TMP/resp18"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18")"
[ "$rc" = 0 ] && [ ! -e "$T/CLAUDE.md" ] || falha "caso 3: semente listada gerada (exit $rc)"
grep -q '^  mantido (projeto): CLAUDE.md$' "$TMP/out" || falha "caso 3: sem 'mantido (projeto)'"
# 4: conflito fora da lista recusa o lote, sugere a chave e não cita o listado
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 4: setup"
echo editado >>"$T/.cockpit/LEIAME.md"; echo "meu rito" >"$T/docs/rito-dev.md"
resp18 'docs/rito-dev.md' "$TMP/resp18"; sed -i.bak "s/^PROJETO_NOME=.*/PROJETO_NOME='outro18'/" "$TMP/resp18"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18")"
[ "$rc" = 2 ] || falha "caso 4: exit $rc (esperado 2)"
grep -q -- '--forcar' "$TMP/err" && grep -q 'DESTINOS_DO_PROJETO' "$TMP/err" || falha "caso 4: mensagem sem --forcar e DESTINOS_DO_PROJETO"
grep -q '.cockpit/LEIAME.md' "$TMP/err" || falha "caso 4: stderr não cita LEIAME.md"
! grep -q 'docs/rito-dev.md' "$TMP/err" || falha "caso 4: stderr cita o destino listado"
# 5: itens inválidos dão exit 1 citando a chave, sem criar cockpit.config
for v in '/etc/x' 'docs/../x' 'ci.yml "" b' "$(printf 'a\tb')"; do
  T="$(novo_repo)"; resp18 "$v" "$TMP/resp18"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18")"
  [ "$rc" = 1 ] || falha "caso 5: '$v' saiu com $rc (esperado 1)"
  grep -q 'DESTINOS_DO_PROJETO' "$TMP/err" || falha "caso 5: '$v' sem citar a chave"
  [ ! -e "$T/cockpit.config" ] || falha "caso 5: '$v' criou cockpit.config"
done
# 6: item sem template avisa e segue; 7: chave ausente ou em branco = árvore idêntica; 8: duas passagens
T="$(novo_repo)"; resp18 'nao-e-template.md' "$TMP/resp18"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18")"
[ "$rc" = 0 ] || falha "caso 6: exit $rc"
grep -q "Aviso: DESTINOS_DO_PROJETO: 'nao-e-template.md' não é destino de nenhum template; ignorado." "$TMP/err" || falha "caso 6: sem aviso"
TA="$(novo_repo)"; TB="$(novo_repo)"; TC="$(novo_repo)"
rodar "$CONF" --projeto "$TA" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 7: setup A"
grep -v '^DESTINOS_DO_PROJETO=' "$EXEMPLO" >"$TMP/sem18"
rodar "$CONF" --projeto "$TB" --respostas "$TMP/sem18" >/dev/null 2>&1 || falha "caso 7: sem a chave"
resp18 '   ' "$TMP/branco18"
rodar "$CONF" --projeto "$TC" --respostas "$TMP/branco18" >/dev/null 2>&1 || falha "caso 7: chave em branco"
diff -r --exclude=.git "$TA" "$TB" >/dev/null || falha "caso 7: ausente difere de vazia"
diff -r --exclude=.git "$TA" "$TC" >/dev/null || falha "caso 7: em branco difere de vazia"
! grep -q '^DESTINOS_DO_PROJETO=' "$TC/cockpit.config" || falha "caso 7: em branco foi gravada"
T="$(novo_repo)"; resp18 'docs/rito-dev.md' "$TMP/resp18"
rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18" >/dev/null 2>&1 || falha "caso 8: 1ª passagem"
[ ! -e "$T/docs/rito-dev.md" ] || falha "caso 8: destino listado inexistente foi gerado"
cp -R "$T" "$TMP/copia18"
rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18" >/dev/null 2>&1 || falha "caso 8: 2ª passagem"
diff -r --exclude=.git "$T" "$TMP/copia18" >/dev/null || falha "caso 8: 2ª passagem alterou a árvore"
# 9: vários itens, com espaços repetidos e grafia não canônica, protegem todos com --forcar
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 9: setup"
echo "meu rito" >"$T/docs/rito-dev.md"; echo "meu leiame" >"$T/.cockpit/LEIAME.md"
cp "$T/docs/rito-dev.md" "$TMP/rito18"; cp "$T/.cockpit/LEIAME.md" "$TMP/leiame18"
resp18 '  ./docs/rito-dev.md   .cockpit//LEIAME.md/ ' "$TMP/resp18"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18" --forcar)"
[ "$rc" = 0 ] || falha "caso 9: exit $rc: $(cat "$TMP/err")"
cmp -s "$T/docs/rito-dev.md" "$TMP/rito18" && cmp -s "$T/.cockpit/LEIAME.md" "$TMP/leiame18" \
  || falha "caso 9: item da lista sobrescrito com --forcar"
grep -q '2 mantido(s) (projeto)' "$TMP/out" || falha "caso 9: contagem sem 2 mantido(s) (projeto)"
! grep -q 'não é destino de nenhum template' "$TMP/err" || falha "caso 9: grafia equivalente tratada como sem template"
# 10: modo interativo não pergunta sobrescrita de destino listado e editado
if declare -F interativo >/dev/null; then
  T="$(novo_repo)"; resp18 'docs/rito-dev.md' "$TMP/resp18"
  rodar "$CONF" --projeto "$T" --respostas "$TMP/resp18" >/dev/null 2>&1 || falha "caso 10: setup"
  echo "meu rito" >"$T/docs/rito-dev.md"; cp "$T/docs/rito-dev.md" "$TMP/rito18"
  interativo "$(printf '\\n%.0s' {1..40})" --projeto "$T" || falha "caso 10: interativo falhou: $(tail -3 "$TMP/tty")"
  ! grep -q 'Arquivo editado localmente: docs/rito-dev.md' "$TMP/tty" || falha "caso 10: perguntou sobrescrita do destino listado"
  cmp -s "$T/docs/rito-dev.md" "$TMP/rito18" || falha "caso 10: destino listado alterado no interativo"
  grep -q 'mantido (projeto): docs/rito-dev.md' "$TMP/tty" || falha "caso 10: sem 'mantido (projeto)'"
fi

# --------------------------------------------------------------- 19 ---
cenario "19: worktree e destino ignorado"
GIT_ID=(-c user.name=Teste -c user.email=teste@example.invalid -c commit.gpgsign=false)
M="$(novo_repo)"
printf 'CLAUDE.md\ndocs/rito-dev.md\nsub/x.md\n' >"$M/.gitignore"
git -C "$M" add .gitignore
git -C "$M" "${GIT_ID[@]}" commit -q -m inicial
MF="$(cd "$M" && pwd -P)"
# nova_wt NOME — worktree vinculada nova, fora de M.
nova_wt() { git -C "$M" worktree add -q "$TMP/wt-$1" -b "wt-$1" >/dev/null 2>&1 || falha "worktree $1 não criada"; printf '%s' "$TMP/wt-$1"; }
estado_m() { git -C "$M" status --porcelain --ignored; }
# 9 e 10: cópia como arquivo regular, fora do manifesto, árvore principal intacta
printf 'meu claude\n' >"$M/CLAUDE.md"; estado_m >"$TMP/est19"
W="$(nova_wt a)"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] || falha "caso 9: exit $rc: $(cat "$TMP/err")"
[ -f "$W/CLAUDE.md" ] && [ ! -L "$W/CLAUDE.md" ] && cmp -s "$W/CLAUDE.md" "$M/CLAUDE.md" || falha "caso 9: CLAUDE.md não copiado como arquivo regular"
grep -q 'copiado da árvore principal: CLAUDE.md' "$TMP/out" || falha "caso 9: sem 'copiado da árvore principal'"
grep -q '1 copiado(s) da árvore principal' "$TMP/out" || falha "caso 9: contagem sem copiado(s)"
! grep -q '  CLAUDE.md$' "$W/.cockpit/manifesto.sha256" || falha "caso 9: cópia entrou no manifesto"
# semente não ignorada segue renderizada e no manifesto na worktree (FR-011)
[ -f "$W/docs/constitution.md" ] && grep -q '  docs/constitution.md$' "$W/.cockpit/manifesto.sha256" \
  || falha "caso 9: semente não ignorada não renderizada ou fora do manifesto"
estado_m | cmp -s - "$TMP/est19" || falha "caso 9: árvore principal alterada"
[ "$(cat "$M/CLAUDE.md")" = "meu claude" ] || falha "caso 9: origem alterada"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && grep -q '^  mantido (semente): CLAUDE.md$' "$TMP/out" || falha "caso 10: 2ª passagem sem 'mantido (semente)' (exit $rc)"
# 11: sem o arquivo na árvore principal, nada é gerado
rm "$M/CLAUDE.md"
W="$(nova_wt b)"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ ! -e "$W/CLAUDE.md" ] || falha "caso 11: CLAUDE.md gerado ou exit $rc"
grep -qF "mantido (ignorado pelo git): CLAUDE.md (esperado em $MF/CLAUDE.md)" "$TMP/out" || falha "caso 11: sem 'mantido (ignorado pelo git)' com o caminho esperado"
grep -q '1 mantido(s) (ignorado pelo git)' "$TMP/out" || falha "caso 11: contagem sem mantido(s) (ignorado pelo git)"
# 12: origem que é link (para arquivo regular existente fora da árvore), diretório, ou
# com componente que é link, é recusada
echo "conteúdo alheio" >"$TMP/alheio19"; ln -s "$TMP/alheio19" "$M/CLAUDE.md"
W="$(nova_wt c)"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ ! -e "$W/CLAUDE.md" ] && [ ! -L "$W/CLAUDE.md" ] || falha "caso 12: origem link copiada (exit $rc)"
grep -q 'link simbólico' "$TMP/err" || falha "caso 12: sem aviso de link simbólico"
rm "$M/CLAUDE.md"; mkdir "$M/CLAUDE.md"
W="$(nova_wt c2)"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ ! -e "$W/CLAUDE.md" ] || falha "caso 12: origem diretório copiada (exit $rc)"
grep -q 'não é arquivo regular legível' "$TMP/err" || falha "caso 12: sem aviso de origem não regular"
rmdir "$M/CLAUDE.md"
mkdir "$TMP/alvo19"; echo "rito alheio" >"$TMP/alvo19/rito-dev.md"; ln -s "$TMP/alvo19" "$M/docs"
W="$(nova_wt d)"; resp18 'docs/rito-dev.md' "$TMP/resp19"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$TMP/resp19")"
[ "$rc" = 0 ] && [ ! -e "$W/docs/rito-dev.md" ] || falha "caso 12: componente link copiado (exit $rc)"
grep -q 'link simbólico' "$TMP/err" || falha "caso 12: sem aviso para componente link"
# 13: destino listado e ignorado é copiado, com criação do pai
rm "$M/docs"; mkdir "$M/docs"; echo "rito do projeto" >"$M/docs/rito-dev.md"
W="$(nova_wt e)"
rc="$(codigo rodar "$CONF" --projeto "$W" --respostas "$TMP/resp19")"
[ "$rc" = 0 ] || falha "caso 13: exit $rc: $(cat "$TMP/err")"
[ -f "$W/docs/rito-dev.md" ] && [ ! -L "$W/docs/rito-dev.md" ] && cmp -s "$W/docs/rito-dev.md" "$M/docs/rito-dev.md" || falha "caso 13: destino listado não copiado"
grep -q 'copiado da árvore principal: docs/rito-dev.md' "$TMP/out" || falha "caso 13: sem 'copiado da árvore principal'"
# o pai do destino copiado só existe se a cópia o criar (nenhum outro template em sub/)
C="$(cockpit_copia)"; mkdir -p "$C/templates/sub" "$M/sub"
printf 'ok\n' >"$C/templates/sub/x.md.semente.tmpl"; echo "x do projeto" >"$M/sub/x.md"
W="$(nova_wt f)"
rc="$(codigo rodar "$C/configurar.sh" --projeto "$W" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && cmp -s "$W/sub/x.md" "$M/sub/x.md" || falha "caso 13: cópia sem pai não criou o diretório (exit $rc)"
# 14: árvore principal bare, construída sem rede nem cópia de .git (gap CHK023)
git init -q --bare "$TMP/bare19.git"
git -C "$M" push -q "$TMP/bare19.git" HEAD:refs/heads/main >/dev/null 2>&1 || falha "caso 14: bare não populado"
git -C "$TMP/bare19.git" worktree add -q "$TMP/wt-bare" -b wb main >/dev/null 2>&1 || falha "caso 14: worktree do bare não criada"
rc="$(codigo rodar "$CONF" --projeto "$TMP/wt-bare" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ ! -e "$TMP/wt-bare/CLAUDE.md" ] || falha "caso 14: CLAUDE.md gerado ou exit $rc"
grep -q 'repositório bare' "$TMP/err" || falha "caso 14: sem aviso de repositório bare"
grep -q '(árvore principal indisponível)' "$TMP/out" || falha "caso 14: sem '(árvore principal indisponível)'"
# sem destino ignorado, a worktree do bare não avisa nada sobre a árvore principal
R="$(novo_repo)"; git -C "$R" "${GIT_ID[@]}" commit -q --allow-empty -m inicial
git init -q --bare "$TMP/bare19b.git"
git -C "$R" push -q "$TMP/bare19b.git" HEAD:refs/heads/main >/dev/null 2>&1 || falha "caso 14: bare sem .gitignore não populado"
git -C "$TMP/bare19b.git" worktree add -q "$TMP/wt-bare-b" -b wbb main >/dev/null 2>&1 || falha "caso 14: worktree do bare sem .gitignore não criada"
rc="$(codigo rodar "$CONF" --projeto "$TMP/wt-bare-b" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ -f "$TMP/wt-bare-b/CLAUDE.md" ] || falha "caso 14: semente não ignorada não gerada no bare (exit $rc)"
! grep -q 'árvore principal indisponível' "$TMP/err" || falha "caso 14: aviso de árvore principal sem destino ignorado"
# primeiro registro que é o git-dir (--separate-git-dir) não é aceito como árvore principal
git init -q --separate-git-dir "$TMP/sep19.git" "$TMP/sep19"
printf 'CLAUDE.md\n' >"$TMP/sep19/.gitignore"; echo "claude sep" >"$TMP/sep19/CLAUDE.md"
git -C "$TMP/sep19" add .gitignore && git -C "$TMP/sep19" "${GIT_ID[@]}" commit -q -m inicial
git -C "$TMP/sep19" worktree add -q "$TMP/wt-sep" -b ws >/dev/null 2>&1 || falha "caso 14: worktree do separate-git-dir não criada"
rc="$(codigo rodar "$CONF" --projeto "$TMP/wt-sep" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ ! -e "$TMP/wt-sep/CLAUDE.md" ] || falha "caso 14: separate-git-dir: CLAUDE.md gerado ou exit $rc"
grep -q 'não confirmada' "$TMP/err" && grep -q '(árvore principal indisponível)' "$TMP/out" \
  || falha "caso 14: git-dir aceito como árvore principal"
# 15: checkout comum (a própria árvore principal) renderiza a semente e a inclui no manifesto
rm -rf "$M/docs"
rc="$(codigo rodar "$CONF" --projeto "$M" --respostas "$EXEMPLO")"
[ "$rc" = 0 ] && [ -f "$M/CLAUDE.md" ] || falha "caso 15: semente não renderizada (exit $rc)"
grep -q '  CLAUDE.md$' "$M/.cockpit/manifesto.sha256" || falha "caso 15: semente fora do manifesto"

# --------------------------------------------------------------- 20 ---
cenario "20: prefixos de branch"
resp20() { { grep -v '^PREFIXOS_BRANCH=' "$EXEMPLO"; [ -z "${1+x}" ] || printf "PREFIXOS_BRANCH='%s'\n" "$1"; } >"$2"; }
# 1: chave ausente: render igual ao de hoje (padrão) e --atualizar sem pergunta
T="$(novo_repo)"; grep -v '^PREFIXOS_BRANCH=' "$EXEMPLO" >"$TMP/r20"
rodar "$CONF" --projeto "$T" --respostas "$TMP/r20" >/dev/null 2>&1 || falha "caso 1: setup"
for f in docs/CICLO-GIT.md docs/rito-dev.md; do
  grep -q 'feature/<slug>' "$T/$f" && grep -q 'hotfix/<slug>' "$T/$f" || falha "caso 1: padrão ausente em $f"
done
! grep -q 'PREFIXO' "$T/cockpit.config" || falha "caso 1: gravou PREFIXO"
# byte a byte igual a um cockpit com os cinco placeholders trocados pelos literais (quickstart 1)
C20="$(cockpit_copia)"
for t in CICLO-GIT rito-dev; do
  sed 's/{{PREFIXO_FEATURE}}/feature/g;s/{{PREFIXO_FIX}}/fix/g;s/{{PREFIXO_CHORE}}/chore/g;s/{{PREFIXO_DOCS}}/docs/g;s/{{PREFIXO_HOTFIX}}/hotfix/g' \
    "$C20/templates/docs/$t.md.tmpl" >"$C20/templates/docs/$t.md.tmpl.n" && mv "$C20/templates/docs/$t.md.tmpl.n" "$C20/templates/docs/$t.md.tmpl"
done
S20="$C20/templates/docs/constitution.md.semente.tmpl"
sed 's/{{PREFIXO_HOTFIX}}/hotfix/g' "$S20" >"$S20.n" && mv "$S20.n" "$S20"
TL="$(novo_repo)"
rodar "$C20/configurar.sh" --projeto "$TL" --respostas "$TMP/r20" >/dev/null 2>&1 || falha "caso 1: setup da cópia literal"
for f in docs/CICLO-GIT.md docs/rito-dev.md; do
  cmp -s "$T/$f" "$TL/$f" || falha "caso 1: $f difere do render com literais"
done
cmp -s "$T/docs/constitution.md" "$TL/docs/constitution.md" || falha "caso 1: constitution.md difere do render com literais"
# --atualizar sem a chave: sem pergunta, stderr sem a chave, documentos inalterados (quickstart 6)
cp "$T/docs/CICLO-GIT.md" "$TMP/ant-ciclo"; cp "$T/docs/rito-dev.md" "$TMP/ant-rito"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "caso 1: --atualizar saiu com $rc: $(cat "$TMP/err")"
! grep -q 'PREFIXOS_BRANCH' "$TMP/err" || falha "caso 1: --atualizar citou PREFIXOS_BRANCH"
cmp -s "$T/docs/CICLO-GIT.md" "$TMP/ant-ciclo" && cmp -s "$T/docs/rito-dev.md" "$TMP/ant-rito" \
  || falha "caso 1: --atualizar alterou os documentos"
# 2: chave válida refletida nos dois documentos; placeholders não gravados
T="$(novo_repo)"; resp20 'feat fx ch dc hf' "$TMP/r20"
rodar "$CONF" --projeto "$T" --respostas "$TMP/r20" >/dev/null 2>&1 || falha "caso 2: setup"
for f in docs/CICLO-GIT.md docs/rito-dev.md; do
  for p in feat fx ch dc hf; do
    grep -Fq "$p/<slug>" "$T/$f" || falha "caso 2: prefixo $p ausente em $f"
  done
  for p in feature fix chore docs hotfix; do
    ! grep -Fq "$p/<slug>" "$T/$f" || falha "caso 2: prefixo padrão $p em $f"
  done
done
grep -q "^PREFIXOS_BRANCH='feat fx ch dc hf'\$" "$T/cockpit.config" || falha "caso 2: chave não gravada"
grep -Fq 'hf/<slug>' "$T/docs/constitution.md" && ! grep -Fq 'hotfix/<slug>' "$T/docs/constitution.md" || falha "caso 2: constitution.md sem hf/<slug> ou com hotfix/<slug>"
! grep -q '^PREFIXO_' "$T/cockpit.config" || falha "caso 2: placeholder gravado"
# 3: só espaços equivale a ausente
T="$(novo_repo)"; resp20 '   ' "$TMP/r20"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r20")"
[ "$rc" = 0 ] && grep -q 'feature/<slug>' "$T/docs/CICLO-GIT.md" || falha "caso 3: só espaços (exit $rc)"
! grep -q '^PREFIXOS_BRANCH=' "$T/cockpit.config" || falha "caso 3: só espaços gravou a chave"
# 4: inválidos: exit 1 citando a chave, sem cockpit.config
# D4/D6: conjunto ^[a-z0-9][a-z0-9._-]*$; sem tipo novo nem formato tipo=prefixo.
for v in 'a b c d' 'a b c d e f' 'a/b c d e f' '-a b c d e' 'a@{b c d e f' 'a b c d a' 'a.lock b c d e' "$(printf 'a	b c d e f')" \
  'Feat b c d e' 'a;b c d e f' 'a$(x) b c d e' 'a|b c d e f' 'a`x` b c d e' '.a b c d e' '_a b c d e' 'á b c d e' \
  'feature=feat fix chore docs hotfix'; do
  T="$(novo_repo)"; resp20 "$v" "$TMP/r20"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r20")"
  [ "$rc" = 1 ] || falha "caso 4: '$v' saiu com $rc (esperado 1)"
  grep -q 'PREFIXOS_BRANCH' "$TMP/err" || falha "caso 4: '$v' sem citar a chave"
  case "$v" in 'Feat b c d e' | 'a;b'* | 'a$('* | 'a|b'* | 'a`x`'* | '.a '* | '_a '* | 'á '* | 'feature='*)
    grep -Fq '^[a-z0-9][a-z0-9._-]*$' "$TMP/err" || falha "caso 4: '$v' sem citar o conjunto aceito" ;;
  esac
  [ ! -e "$T/cockpit.config" ] || falha "caso 4: '$v' criou cockpit.config"
done
# 6: padrão declarado explicitamente é aceito e gravado
T="$(novo_repo)"; resp20 'feature fix chore docs hotfix' "$TMP/r20"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r20")"
[ "$rc" = 0 ] && grep -q "^PREFIXOS_BRANCH='feature fix chore docs hotfix'\$" "$T/cockpit.config" || falha "caso 6: padrão declarado (exit $rc)"
# (caso 5, modo interativo, no cenário 14)

# --------------------------------------------------------------- 21 ---
cenario "21: branches e manifesto"
RE_B='^[A-Za-z0-9][A-Za-z0-9._/-]*$'
# respb CHAVE VALOR ARQ — respostas do exemplo com CHAVE trocada.
respb() { { grep -v "^$1=" "$EXEMPLO"; printf "%s='%s'\n" "$1" "$2"; } >"$3"; }
DEST21="$(cd "$RAIZ_COCKPIT/templates" && find . -type f | sed -e 's|^\./||' -e 's/\.semente\.tmpl$//' -e 's/\.tmpl$//' | sort | tr '\n' ' ')"
# 1: recusados nas duas chaves, em --respostas: exit 1, cita chave e conjunto, nada gravado
RECUSADOS21=('main;curl x' '$(x)' '`x`' 'a|b' 'a b' 'a..b' 'x.lock' 'a/' '-x' '.x' '/x' 'á')
for k in BRANCH_INTEGRACAO BRANCH_PRODUCAO; do
  for v in "${RECUSADOS21[@]}"; do
    T="$(novo_repo)"; respb "$k" "$v" "$TMP/r21"; : >"$CSTK_LOG_FALSO"
    hooks21="$(ls -A "$T/.git/hooks" 2>/dev/null || true)"
    rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r21")"
    [ "$rc" = 1 ] || falha "caso 1: $k='$v' saiu com $rc (esperado 1)"
    grep -q "$k" "$TMP/err" && grep -Fq "$RE_B" "$TMP/err" || falha "caso 1: $k='$v' sem citar chave e conjunto"
    [ ! -e "$T/cockpit.config" ] && [ ! -e "$T/.cockpit" ] || falha "caso 1: $k='$v' gravou algo"
    [ -z "$(cd "$T" && find . -path ./.git -prune -o -type f -print)" ] || falha "caso 1: $k='$v' deixou arquivo fora de .git"
    ! grep -qs 'hooks install' "$CSTK_LOG_FALSO" || falha "caso 1: $k='$v' chamou cstk hooks install"
    ! grep -Fqs 'renomeie a branch no remoto' "$TMP/out" "$TMP/err" || falha "caso 1: $k='$v' mostrou a dica de renomear fora do --atualizar"
    [ "$hooks21" = "$(ls -A "$T/.git/hooks" 2>/dev/null || true)" ] || falha "caso 1: $k='$v' gravou hook em .git/hooks"
    ! git -C "$T" config --local --get core.hooksPath >/dev/null || falha "caso 1: $k='$v' definiu core.hooksPath"
  done
done
# 2: aceitos nas duas chaves
for par in 'release/2026 main' 'main release/2026'; do
  # shellcheck disable=SC2086
  set -- $par; T="$(novo_repo)"
  { grep -Ev '^BRANCH_(INTEGRACAO|PRODUCAO)=' "$EXEMPLO"; printf "BRANCH_INTEGRACAO='%s'\nBRANCH_PRODUCAO='%s'\n" "$1" "$2"; } >"$TMP/r21"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r21")"
  [ "$rc" = 0 ] || falha "caso 2: '$par' saiu com $rc"
  grep -q "^BRANCH_INTEGRACAO='$1'\$" "$T/cockpit.config" && grep -q "^BRANCH_PRODUCAO='$2'\$" "$T/cockpit.config" \
    || falha "caso 2: '$par' não gravado"
done
# 3: --atualizar com config editado à mão: exit 1, linha de correção, nada alterado
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 3: setup"
sed -i "s/^BRANCH_PRODUCAO=.*/BRANCH_PRODUCAO='\$(x)'/" "$T/cockpit.config"
cp "$T/cockpit.config" "$TMP/cfg21"; cp "$T/.cockpit/manifesto.sha256" "$TMP/man21"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 1 ] || falha "caso 3: --atualizar saiu com $rc (esperado 1)"
grep -q 'BRANCH_PRODUCAO' "$TMP/err" && grep -Fq "$RE_B" "$TMP/err" && grep -Fq 'Corrija o valor no cockpit.config' "$TMP/err" \
  || falha "caso 3: sem chave, conjunto e linha de correção"
cmp -s "$T/cockpit.config" "$TMP/cfg21" && cmp -s "$T/.cockpit/manifesto.sha256" "$TMP/man21" || falha "caso 3: alterou arquivos"
# 3b: as duas chaves x todos os valores recusados também no --atualizar
for k in BRANCH_INTEGRACAO BRANCH_PRODUCAO; do
  for v in "${RECUSADOS21[@]}"; do
    T="$(novo_repo)"
    rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 3b: setup"
    { grep -v "^$k=" "$T/cockpit.config"; printf "%s='%s'\n" "$k" "$v"; } >"$TMP/cfg21b"; cp "$TMP/cfg21b" "$T/cockpit.config"
    cp "$T/cockpit.config" "$TMP/cfg21"; cp "$T/.cockpit/manifesto.sha256" "$TMP/man21"
    rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
    [ "$rc" = 1 ] || falha "caso 3b: $k='$v' saiu com $rc (esperado 1)"
    grep -q "Valor inválido para $k" "$TMP/err" && grep -Fq "$RE_B" "$TMP/err" && grep -Fq 'Corrija o valor no cockpit.config' "$TMP/err" \
      && grep -Fq "renomeie a branch no remoto" "$TMP/err" && grep -Fq "atualize a chave $k" "$TMP/err" \
      || falha "caso 3b: $k='$v' sem chave, conjunto, linha de correção e dica de renomear"
    cmp -s "$T/cockpit.config" "$TMP/cfg21" && cmp -s "$T/.cockpit/manifesto.sha256" "$TMP/man21" || falha "caso 3b: $k='$v' alterou arquivos"
  done
done
# 4: interativo pergunta de novo (no pty do cenário 14)
if declare -F interativo >/dev/null; then
  T="$(novo_repo)"
  interativo "$(printf '%s' "$MINIMO" | sed 's/^\(proj\\norg\/repo\\n\)dev/\1a|b\\ndev/')" --projeto "$T" \
    || falha "caso 4: interativo falhou: $(tail -3 "$TMP/tty")"
  grep -q 'BRANCH_INTEGRACAO' "$TMP/tty" && grep -q "^BRANCH_INTEGRACAO='dev'\$" "$T/cockpit.config" || falha "caso 4: não perguntou de novo"
  grep -q 'Valor inválido para BRANCH_INTEGRACAO' "$TMP/tty" || falha "caso 4: sem a mensagem de erro no tty"
  ! grep -q 'renomeie a branch no remoto' "$TMP/tty" || falha "caso 4: dica de renomear só vale no --atualizar"
else
  printf '  (script(1) ausente — caso 4 pulado)\n'
fi
# 5: todos os destinos listados, sem manifesto anterior: .cockpit/ não existe
T="$(novo_repo)"
{ grep -v '^DESTINOS_DO_PROJETO=' "$EXEMPLO"; printf "DESTINOS_DO_PROJETO='%s'\n" "${DEST21% }"; } >"$TMP/r21"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r21")"
[ "$rc" = 0 ] || falha "caso 5: saiu com $rc: $(tail -3 "$TMP/err")"
[ ! -e "$T/.cockpit" ] || falha "caso 5: .cockpit/ criado sem linha a registrar"
# 6: com manifesto anterior, regra de hoje: manifesto continua
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 6: setup"
cp "$T/.cockpit/manifesto.sha256" "$TMP/man6"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r21")"
[ "$rc" = 0 ] && [ -f "$T/.cockpit/manifesto.sha256" ] || falha "caso 6: manifesto anterior perdido (exit $rc)"
[ -s "$TMP/man6" ] || falha "caso 6: manifesto do setup vazio"
if grep -Fxvf "$T/.cockpit/manifesto.sha256" "$TMP/man6" | grep -q .; then falha "caso 6: linhas do manifesto anterior perdidas"; fi
# 7: manifesto anterior que ficaria vazio continua existindo e é regravado sem linhas (Decision 8)
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "caso 7: setup"
{ grep -v '^DESTINOS_DO_PROJETO=' "$EXEMPLO"; printf "DESTINOS_DO_PROJETO='%s'\n" "${DEST21% }"; } >"$TMP/r21-7"
printf '%s  arquivo-que-nao-existe\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' >"$T/.cockpit/manifesto.sha256"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r21-7")"
[ "$rc" = 0 ] && [ -f "$T/.cockpit/manifesto.sha256" ] || falha "caso 7: manifesto anterior perdido (exit $rc)"
[ ! -s "$T/.cockpit/manifesto.sha256" ] || falha "caso 7: manifesto deveria ser regravado sem linhas"


# --------------------------------------------------------------- 23 ---
cenario "23: promotion-pr decide pelas árvores"
# Reusa $TMP/promocao.sh do cenário 16; gh falso responde por "$*", registra cada chamada e guarda
# o --body-file em $GH23_LOG.corpo. A constituição só existe na ponta da integração (ref=integ).
mkdir -p "$TMP/gh23"
cat >"$TMP/gh23/gh" <<'GH'
#!/bin/sh
echo "$*" >>"$GH23_LOG"
prev=""; for a; do [ "$prev" = --body-file ] && cp "$a" "$GH23_LOG.corpo"; prev="$a"; done
case "$*" in
  *'contents/docs/constitution.md?ref=integ' | *'contents/docs/constitution.md?ref=integ '*) [ -n "${CONST23:-}" ] && printf '%s\n' "$CONST23" ;;
  *"contents/docs/constitution.md"*) exit 1 ;;
  *"allow_auto_merge"*) echo "${PERMITE23:-true}" ;;
  *"/compare/"*"--jq .ahead_by"*) echo 3 ;;
  *"/compare/"*) echo "- abc1234 mensagem" ;;
  *"commits/heads/prod"*) [ "$ARV_PROD" = FALHA ] && exit 1; echo "$ARV_PROD" ;;
  *"commits/heads/integ"*) echo "$ARV_INTEG" ;;
  "pr list"*) echo "$PR_ABERTO" ;;
esac
exit 0
GH
chmod +x "$TMP/gh23/gh"
roda23() { # $1=árvore prod, $2=árvore integ, $3=PR aberto ("" = nenhum)
  : >"$TMP/gh23.log"; rm -f "$TMP/gh23.log.corpo"
  codigo env PATH="$TMP/gh23:$PATH" GH23_LOG="$TMP/gh23.log" ARV_PROD="$1" ARV_INTEG="$2" PR_ABERTO="$3" \
    TOKEN_PADRAO=x INTEGRACAO=integ PRODUCAO=prod REPO=org/repo bash "$TMP/promocao.sh"
}
# 1 e 2: árvores iguais com ahead_by positivo: nada de PR, com ou sem PR aberto.
for aberto in "" 7; do
  rc="$(roda23 abc123 abc123 "$aberto")"
  [ "$rc" = 0 ] && grep -q 'nada a promover' "$TMP/out" || falha "caso 1/2: árvores iguais (PR '$aberto') saiu $rc"
  ! grep -qE 'pr (create|edit)' "$TMP/gh23.log" || falha "caso 1/2: árvores iguais tocaram o PR (PR '$aberto')"
done
# 3: árvores diferentes sem PR: exatamente um pr create.
rc="$(roda23 abc123 def456 "")"
[ "$rc" = 0 ] && [ "$(grep -c 'pr create' "$TMP/gh23.log")" = 1 ] && ! grep -q 'pr edit' "$TMP/gh23.log" || falha "caso 3: árvores diferentes sem PR (saiu $rc)"
# 4: árvores diferentes com PR aberto: pr edit 7, sem pr create.
rc="$(roda23 abc123 def456 7)"
[ "$rc" = 0 ] && grep -q 'pr edit 7' "$TMP/gh23.log" && ! grep -q 'pr create' "$TMP/gh23.log" || falha "caso 4: árvores diferentes com PR (saiu $rc)"
# 5: leitura de árvore falhando ou devolvendo null: sai != 0 sem tocar o PR.
for ruim in FALHA null; do
  rc="$(roda23 "$ruim" def456 "")"
  [ "$rc" != 0 ] && grep -q 'Não consegui ler as árvores' "$TMP/err" || falha "caso 5: '$ruim' deveria falhar (saiu $rc)"
  ! grep -qE 'pr (create|edit)' "$TMP/gh23.log" || falha "caso 5: '$ruim' tocou o PR"
done
# 7: modo autônomo ligado (FR-019): token obrigatório, merge commit (e o auto-merge das PRs de frente) permitidos, SHA de
# rollback no corpo; o fluxo nunca mergeia nem arma o auto-merge (quem promove é o agente, por merge direto em X com
# --match-head-commit, depois do smoke combinado e dos checks verdes; decisão da rodada 2).
SHA23=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
LIG23='Merge autônomo: ligado'
ROLL23="Rollback (SHA da produção antes da promoção): $SHA23"
rc="$(CONST23="$LIG23" roda23 "$SHA23" def456 "")"
[ "$rc" != 0 ] && grep -q 'exige o segredo TOKEN_AUTOMACAO' "$TMP/err" && ! grep -qE 'pr (create|edit)' "$TMP/gh23.log" || falha "caso 7a: ligado sem token deveria falhar sem criar o PR (saiu $rc)"
rc="$(CONST23="$LIG23" PERMITE23=false TOKEN_AUTOMACAO=t roda23 "$SHA23" def456 "")"
[ "$rc" != 0 ] && grep -q 'auto-merge e merge commit' "$TMP/err" && ! grep -qE 'pr (create|edit)' "$TMP/gh23.log" || falha "caso 7b: ligado sem auto-merge/merge commit permitido deveria falhar (saiu $rc)"
rc="$(CONST23="$LIG23" TOKEN_AUTOMACAO=t roda23 "abc123" def456 "")"
[ "$rc" != 0 ] && ! grep -qE 'pr (create|edit)' "$TMP/gh23.log" || falha "caso 7c: SHA ilegível deveria falhar sem criar o PR (saiu $rc)"
rc="$(CONST23="$LIG23" TOKEN_AUTOMACAO=t PR_ABERTO=9 roda23 "$SHA23" def456 9)"
[ "$rc" = 0 ] && grep -q 'pr edit 9' "$TMP/gh23.log" && ! grep -q 'pr merge' "$TMP/gh23.log" && grep -Fqx "$ROLL23" "$TMP/gh23.log.corpo" \
  || falha "caso 7d: ligado com PR aberto deveria atualizar o corpo com o rollback sem armar o auto-merge (saiu $rc)"
# 7f: ligado sem PR aberto: cria o PR com a linha de rollback e não arma o auto-merge (E16)
rc="$(CONST23="$LIG23" TOKEN_AUTOMACAO=t roda23 "$SHA23" def456 "")"
[ "$rc" = 0 ] && [ "$(grep -c 'pr create' "$TMP/gh23.log")" = 1 ] && ! grep -q 'pr merge' "$TMP/gh23.log" && grep -Fqx "$ROLL23" "$TMP/gh23.log.corpo" \
  || falha "caso 7f: ligado sem PR deveria criar o PR com o rollback sem armar o auto-merge (saiu $rc)"
# 7g: constituição commitada com CRLF vale ligado (B3-1/E3-2): sem token, falha sem criar o PR
rc="$(CONST23="$(printf 'x\r\n%s\r' "$LIG23")" roda23 "$SHA23" def456 "")"
[ "$rc" != 0 ] && grep -q 'exige o segredo TOKEN_AUTOMACAO' "$TMP/err" || falha "caso 7g: CRLF deveria valer ligado (saiu $rc)"
# desligado, linha duplicada e ausente: comportamento de hoje, sem auto-merge nem linha de rollback
for c23 in 'Merge autônomo: desligado' "$(printf '%s\n%s' "$LIG23" "$LIG23")" ''; do
  rc="$(CONST23="$c23" roda23 "$SHA23" def456 "")"
  [ "$rc" = 0 ] && grep -q 'pr create' "$TMP/gh23.log" && ! grep -q 'pr merge' "$TMP/gh23.log" && ! grep -q '^Rollback' "$TMP/gh23.log.corpo" \
    || falha "caso 7e: modo '$c23' deveria manter o comportamento de hoje (saiu $rc)"
done
# 6: o cabeçalho (só as linhas de comentário antes de `name:`) documenta as duas afirmações de D2:
# merge commit como na Fase 9 do rito-dev; com squash o fluxo não abre nem reabre o PR se o conteúdo é igual.
cab23="$(awk '/^name:/ {exit} /^#/ {sub(/^# ?/, ""); printf "%s ", $0}' "$RAIZ_COCKPIT/templates/.github/workflows/promotion-pr.yml.tmpl")"
case "$cab23" in *'merge commit (como na Fase 9 do rito-dev)'*) ;; *) falha "caso 6: cabeçalho sem merge commit como na Fase 9 do rito-dev" ;; esac
case "$cab23" in *'Com squash'*'não abre nem reabre o PR quando já é igual'*) ;; *) falha "caso 6: cabeçalho sem o efeito do squash" ;; esac
case "$cab23" in *'NUNCA mergeia nem arma o auto-merge'*'por merge direto em X'*'gh pr merge <n> --merge --match-head-commit X'*) ;; *) falha "caso 6: cabeçalho sem a promoção por merge direto em X" ;; esac
case "$cab23" in *--auto*) falha "caso 6: cabeçalho ainda manda --auto (a promoção é por merge direto, rodada 2)" ;; esac

# --------------------------------------------------------------- 24 ---
cenario "24: auditoria de merge vermelho (rota codificada e duplicada sem índice)"
if ! command -v jq >/dev/null 2>&1; then
  [ "${COCKPIT_EXIGIR_FERRAMENTAS:-}" != 1 ] || falha "jq ausente no CI"
  printf '  (jq ausente nesta máquina — cenário pulado, checado no CI)\n'
else
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render do audit-merge-vermelho falhou"
awk '/- name: Registrar merge com check vermelho/ {d=1} d && /run: \|/ {r=1; next} r {sub(/^          /, ""); print}' \
  "$T/.github/workflows/audit-merge-vermelho.yml" >"$TMP/auditoria.sh"
[ -s "$TMP/auditoria.sh" ] || falha "não extraí o passo do audit-merge-vermelho"
G24="$TMP/gh24"; mkdir -p "$G24/bin"
cat >"$G24/bin/gh" <<'GHFALSO'
#!/usr/bin/env bash
# gh falso: registra a chamada; `api` serve a fixture pela rota e aplica o --jq recebido.
# A constituição é servida no commit base do PR (ref=basesha24, $CONST24), na ponta da integração
# (ref=integ24, $CONST24_INT, que sem valor repete o $CONST24) e, com ref vazio, na branch padrão
# ($CONST24), que é o padrão do `ref` na API de conteúdo; qualquer outro ref sai com erro.
todos="$*"
echo "$todos" >>"$G24/log"
if [ "$1" = api ]; then
  case "$todos" in
    *'contents/docs/constitution.md?ref='*)
      ref="${todos##*contents/docs/constitution.md\?ref=}"; ref="${ref%% *}"
      case "$ref" in basesha24 | '') c="${CONST24:-}" ;; integ24) c="${CONST24_INT-${CONST24:-}}" ;; *) c="" ;; esac
      [ -n "$c" ] && { printf '%s\n' "$c"; exit 0; }; exit 64 ;;
    *contents/docs/constitution.md*) exit 64 ;;
  esac
  rota="$2"; jqx=""
  while [ $# -gt 0 ]; do [ "$1" = --jq ] && jqx="$2"; shift; done
  case "$rota" in
    */issues\?*)
      # a chamada real precisa varrer todas as páginas e todos os estados
      case " $todos " in *" --paginate "*) ;; *) exit 97 ;; esac
      case "$rota" in *state=all*) ;; *) exit 97 ;; esac
      [ -z "${G24_FALHA:-}" ] || exit 1
      for p in "$G24"/issues-*.json; do jq -r "$jqx" "$p"; done ;;
    */check-runs\?*) jq -r "$jqx" "$G24/checks.json" ;;
    */status) jq -r "$jqx" "$G24/status.json" ;;
    */rules/branches/*)
      # forma de M1: corpo JSON do erro no stdout e saída 1
      [ -z "${G24_REGRAS_ERRO:-}" ] || { printf '{"message":"Not Found","status":"404"}\n'; exit 1; }
      jq -r "$jqx" "$G24/rules.json" ;;
    *) exit 64 ;;
  esac
elif [ "$1 $2" = "issue create" ]; then
  while [ $# -gt 0 ]; do [ "$1" = --body-file ] && cp "$2" "$G24/corpo"; shift; done
else
  exit 64
fi
GHFALSO
chmod +x "$G24/bin/gh"
printf '{"check_runs":[{"name":"ci","conclusion":"failure"},{"name":"lint","conclusion":"failure"},{"name":"ok","conclusion":"success"}]}' >"$G24/checks.json"
printf '{"statuses":[]}' >"$G24/status.json"
printf '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"ci"}]}}]' >"$G24/rules.json"
roda24() { # $1 = BASE
  rm -f "$G24/log" "$G24/corpo"
  codigo env G24="$G24" PATH="$G24/bin:$PATH" REPO=org/repo PR=7 SHA=abc BASE="$1" BASE_SHA="${BASE_SHA24-basesha24}" \
    INTEGRACAO=integ24 URL_PR=https://exemplo.invalid/pr/7 AUTOR_MERGE=maria-exemplo bash "$TMP/auditoria.sh"
}
TIT='Auditoria: PR #7 mergeado com check vermelho'
# 1: título parecido e PR de mesmo título não impedem a criação; filtro pelos obrigatórios
printf '[{"number":1,"title":"%s extra"},{"number":2,"title":"%s","pull_request":{}}]' "$TIT" "$TIT" >"$G24/issues-1.json"
printf '[]' >"$G24/issues-2.json"
rc="$(roda24 release/2026)"
[ "$rc" = 0 ] || falha "caso 1: saiu $rc"
grep -q 'issue create' "$G24/log" || falha "caso 1: issue não criada"
grep -qF 'rules/branches/release%2F2026 ' "$G24/log" || falha "caso 1: rota sem a branch codificada"
grep -q '^- ci$' "$G24/corpo" && ! grep -q '^- lint$' "$G24/corpo" && grep -q 'filtrada pelos checks obrigatórios' "$G24/corpo" || falha "caso 1: corpo da issue"
# 2: issue fechada de título idêntico na página 2 não gera outra e não usa a busca
printf '[{"number":3,"title":"outra"}]' >"$G24/issues-1.json"
printf '[{"number":4,"state":"closed","title":"%s"}]' "$TIT" >"$G24/issues-2.json"
rc="$(roda24 main)"
[ "$rc" = 0 ] && grep -q 'Já existe issue de auditoria para o PR #7' "$TMP/out" || falha "caso 2: duplicada não detectada (saiu $rc)"
! grep -q 'issue create' "$G24/log" && ! grep -q 'issue list' "$G24/log" || falha "caso 2: criou ou buscou issue"
grep -qF 'rules/branches/main ' "$G24/log" || falha "caso 2: rota de main mudou"
# 3: caracteres especiais e UTF-8 codificados byte a byte
printf '[]' >"$G24/issues-1.json"; rm -f "$G24/issues-2.json"
rc="$(roda24 'feat/ação+1#x')"
grep -qF 'rules/branches/feat%2Fa%C3%A7%C3%A3o%2B1%23x ' "$G24/log" || falha "caso 3: codificação da rota"
# 4: falha da listagem derruba o passo sem criar issue
rm -f "$G24/log"
rc="$(codigo env G24_FALHA=1 G24="$G24" PATH="$G24/bin:$PATH" REPO=org/repo PR=7 SHA=abc BASE=main INTEGRACAO=integ24 URL_PR=u AUTOR_MERGE=m bash "$TMP/auditoria.sh")"
[ "$rc" != 0 ] && ! grep -q 'issue create' "$G24/log" || falha "caso 4: falha da listagem deveria abortar sem criar (saiu $rc)"
# 5: regras ilegíveis (corpo de erro no stdout, saída 1) nunca filtram: todos os vermelhos, com a nota
printf '[]' >"$G24/issues-1.json"
rm -f "$G24/log" "$G24/corpo"
rc="$(codigo env G24_REGRAS_ERRO=1 G24="$G24" PATH="$G24/bin:$PATH" REPO=org/repo PR=7 SHA=abc BASE=main INTEGRACAO=integ24 URL_PR=u AUTOR_MERGE=m bash "$TMP/auditoria.sh")"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 5: regras ilegíveis deveriam gerar issue (saiu $rc)"
grep -q '^- ci$' "$G24/corpo" && grep -q '^- lint$' "$G24/corpo" && grep -q 'Sem regra de checks obrigatórios legível' "$G24/corpo" || falha "caso 5: issue deveria listar ci e lint com a nota de regra ilegível"
! grep -q 'Not Found' "$G24/corpo" || falha "caso 5: corpo do erro vazou para a issue"
# 6: modo ligado (FR-013): aprovacao-de-dono sozinho não gera issue; outro vermelho continua gerando (e a lista não o cita)
printf '{"check_runs":[{"name":"aprovacao-de-dono","conclusion":"failure"}]}' >"$G24/checks.json"
rc="$(CONST24='Merge autônomo: ligado' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && ! grep -q 'issue create' "$G24/log" || falha "caso 6a: ligado com só aprovacao-de-dono vermelho não deveria abrir issue (saiu $rc)"
grep -qF 'contents/docs/constitution.md?ref=basesha24' "$G24/log" && grep -qF 'contents/docs/constitution.md?ref=integ24' "$G24/log" || falha "caso 6a: a constituição deveria ser lida no base.sha do PR e na ponta da integração"
# 6i: constituição commitada com CRLF vale ligado nos dois lugares (B3-1/E3-2)
rc="$(CONST24="$(printf 'x\r\nMerge autônomo: ligado\r')" G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && ! grep -q 'issue create' "$G24/log" || falha "caso 6i: CRLF deveria valer ligado e não abrir issue (saiu $rc)"
# 6f: ligado no base.sha e desligado (ou ilegível) na ponta da integração: o modo foi trocado, audita (A2-5/E2-3)
rc="$(CONST24='Merge autônomo: ligado' CONST24_INT='Merge autônomo: desligado' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6f: desligado na ponta da integração deveria abrir issue (saiu $rc)"
rc="$(CONST24='Merge autônomo: ligado' CONST24_INT='' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6f: ponta da integração ilegível deveria abrir issue (saiu $rc)"
# 6g: desligado no base.sha e ligado na ponta: audita
rc="$(CONST24='Merge autônomo: desligado' CONST24_INT='Merge autônomo: ligado' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6g: desligado no base.sha deveria abrir issue (saiu $rc)"
# 6h: base.sha vazio não lê a constituição com ref vazio (que pode dar a branch padrão, aqui ligada): audita (E2-9)
rc="$(CONST24='Merge autônomo: ligado' BASE_SHA24='' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6h: base.sha vazio deveria abrir issue (saiu $rc)"
# 6e: a linha ligado só existe noutro commit (não no base.sha): vale desligado e a issue sai (B8/E12)
rc="$(CONST24='Merge autônomo: ligado' BASE_SHA24=outrosha G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6e: modo fora do base.sha não deveria valer (saiu $rc)"
rc="$(CONST24='Merge autônomo: desligado' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6b: desligado deveria abrir issue (saiu $rc)"
rc="$(G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" || falha "caso 6c: sem a linha de modo deveria abrir issue (saiu $rc)"
printf '{"check_runs":[{"name":"aprovacao-de-dono","conclusion":"failure"},{"name":"ci","conclusion":"failure"}]}' >"$G24/checks.json"
rc="$(CONST24='Merge autônomo: ligado' G24_REGRAS_ERRO=1 roda24 main)"
[ "$rc" = 0 ] && grep -q 'issue create' "$G24/log" && grep -q '^- ci$' "$G24/corpo" && ! grep -q 'aprovacao-de-dono' "$G24/corpo" || falha "caso 6d: ligado com ci vermelho deveria abrir issue só com o ci (saiu $rc)"
fi

# --------------------------------------------------------------- 25 ---
cenario "25: commitlint sem limite de linha no corpo"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render do commitlint falhou"
linha="$(grep -F 'commitlint.config.cjs' "$T/.github/workflows/commitlint.yml" | grep '^ *printf ' || true)"
[ "$(printf '%s\n' "$linha" | grep -c .)" = 1 ] || falha "esperada exatamente 1 linha printf da config do commitlint"
pasta="$TMP/commitlint25"
mkdir -p "$pasta"
pasta="$pasta" bash -c "$linha" || falha "linha printf da config do commitlint falhou"
[ -f "$pasta/commitlint.config.cjs" ] || falha "commitlint.config.cjs não foi criado"
grep -Fq "extends: ['@commitlint/config-conventional']" "$pasta/commitlint.config.cjs" || falha "config sem o extends da config convencional"
grep -Fq "'body-max-line-length': [0, 'always', Infinity]" "$pasta/commitlint.config.cjs" || falha "config sem a regra body-max-line-length desligada"

# --------------------------------------------------------------- 22 ---
cenario "22: aprovação de dono no commit atual"
for m in audit-merge-vermelho require-codeowner-approval; do
  grep -Eq '^[[:space:]]+export LC_ALL=C$' "$RAIZ_COCKPIT/templates/.github/workflows/$m.yml.tmpl" || falha "modelo $m sem export LC_ALL=C"
done
if ! command -v jq >/dev/null 2>&1; then
  [ "${COCKPIT_EXIGIR_FERRAMENTAS:-}" != 1 ] || falha "jq ausente no CI"
  printf '  (jq ausente nesta máquina — cenário pulado, checado no CI)\n'
else
  T="$(novo_repo)"
  rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render do fluxo falhou"
  FLUXO="$T/.github/workflows/require-codeowner-approval.yml"
  awk '/^          BASE_SHA/ {d=1} d && /run: \|/ {r=1; next} r {sub(/^          /, ""); print}' "$FLUXO" >"$TMP/aprov.sh"
  [ -s "$TMP/aprov.sh" ] || falha "não extraí o passo do require-codeowner-approval"
  # gh falso: serve CODEOWNERS, head.sha (HEAD_ATUAL) e as reviews de REVIEWS_JSON via jq. A
  # constituição só existe na ponta da integração (ref=integ), que é onde este fluxo lê o modo.
  mkdir -p "$TMP/gh22"
  cat >"$TMP/gh22/gh" <<'EOF2'
#!/bin/sh
for a; do case "$a" in repos/*/contents/docs/constitution.md'?ref=integ') printf '%s\n' "$CONSTITUICAO"; exit 0 ;; repos/*/contents/docs/constitution.md*) exit 1 ;; esac; done
for a; do case "$a" in repos/*/contents/*) printf '* @maria-exemplo @jose-exemplo\n'; exit 0 ;; esac; done
prog=""; prev=""
for a; do [ "$prev" = --jq ] && prog="$a"; prev="$a"; done
for a; do
  case "$a" in
    repos/*/pulls/*/reviews) case " $* " in *" --paginate "*) ;; *) exit 97 ;; esac; printf '%s' "$REVIEWS_JSON" | jq -r "$prog"; exit 0 ;;
    repos/*/pulls/*) [ -z "$HEAD_FALHA" ] || exit 1; printf '{"head":{"sha":"%s"}}' "$HEAD_ATUAL" | jq -r "$prog"; exit 0 ;;
  esac
done
exit 1
EOF2
  chmod +x "$TMP/gh22/gh"
  aprova22() { # aprova22 HEAD REVIEWS_JSON
    codigo env PATH="$TMP/gh22:$PATH" REPO=org-exemplo/repo PR=1 BASE_SHA=B INTEGRACAO=integ CONSTITUICAO="${CONSTITUICAO:-}" HEAD_ATUAL="$1" HEAD_FALHA="${HEAD_FALHA:-}" REVIEWS_JSON="$2" bash "$TMP/aprov.sh"
  }
  H=1111111111111111111111111111111111111111; A=2222222222222222222222222222222222222222
  rv() { printf '{"user":{"login":"%s"},"state":"%s","commit_id":%s}' "${3:-Maria-Exemplo}" "$1" "$([ -n "$2" ] && printf '"%s"' "$2" || printf null)"; }
  rc="$(aprova22 "$H" "[$(rv APPROVED "$H")]")"
  [ "$rc" = 0 ] && grep -q 'Aprovado por um dono\.' "$TMP/out" || falha "caso 1: aprovação no head deveria contar (saiu $rc)"
  rc="$(aprova22 "$H" "[$(rv APPROVED "$A")]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 2: aprovação em commit anterior não deveria contar (saiu $rc)"
  rc="$(aprova22 "$H" "[$(rv APPROVED "$H"),$(rv CHANGES_REQUESTED "$H")]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 3: pedido de mudança no head após aprovação deveria bloquear (saiu $rc)"
  rc="$(aprova22 "" "[$(rv APPROVED "$H")]")"
  [ "$rc" = 1 ] && grep -q '^::error::' "$TMP/out" || falha "caso 4: head vazio deveria falhar com ::error:: (saiu $rc)"
  # pedido de mudança posterior preso a commit antigo anula a aprovação no head (D2)
  rc="$(aprova22 "$H" "[$(rv APPROVED "$H"),$(rv CHANGES_REQUESTED "$A")]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 6: pedido de mudança posterior em commit antigo deveria anular a aprovação (saiu $rc)"
  # dono aprova commit antigo e não dono aprova o head: não passa
  rc="$(aprova22 "$H" "[$(rv APPROVED "$A"),$(rv APPROVED "$H" Carlos-Exemplo)]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 7: aprovação de não dono no head não deveria bastar (saiu $rc)"
  # reaprovação no head depois de aprovação antiga conta
  rc="$(aprova22 "$H" "[$(rv APPROVED "$A"),$(rv APPROVED "$H")]")"
  [ "$rc" = 0 ] || falha "caso 8: reaprovação no head deveria contar (saiu $rc)"
  # DISMISSED e commit_id nulo não contam
  rc="$(aprova22 "$H" "[$(rv APPROVED "$H"),$(rv DISMISSED "$H")]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 9: review DISMISSED não deveria contar (saiu $rc)"
  rc="$(aprova22 "$H" "[$(rv APPROVED "")]")"
  [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 10: commit_id nulo não deveria contar (saiu $rc)"
  # falha do gh ao ler o head falha fechado
  rc="$(HEAD_FALHA=1 aprova22 "$H" "[$(rv APPROVED "$H")]")"
  [ "$rc" = 1 ] && grep -q '^::error::' "$TMP/out" || falha "caso 11: falha ao ler o head deveria falhar fechado (saiu $rc)"
  # COMMENTED posterior à aprovação não a anula (CHK021)
  rc="$(aprova22 "$H" "[$(rv APPROVED "$H"),$(rv COMMENTED "$H")]")"
  [ "$rc" = 0 ] || falha "caso 12: COMMENTED posterior não deveria anular a aprovação (saiu $rc)"
  # head vazio com review de dono de commit_id nulo: sem a guarda, vazio == vazio aprovaria
  rc="$(aprova22 "" "[$(rv APPROVED "")]")"
  [ "$rc" = 1 ] && grep -q 'Não consegui ler o commit atual do PR' "$TMP/out" || falha "caso 13: head vazio deveria falhar com a mensagem da guarda (saiu $rc)"
  # modo autônomo ligado (FR-013): sem aprovação passa com aviso; desligado, duplicado ou ausente mantém o bloqueio
  rc="$(CONSTITUICAO='Merge autônomo: ligado' aprova22 "$H" "[]")"
  [ "$rc" = 0 ] && grep -q '^::warning::Modo autônomo ligado' "$TMP/out" || falha "caso 14: ligado sem aprovação deveria passar com aviso (saiu $rc)"
  rc="$(CONSTITUICAO='Merge autônomo: ligado' aprova22 "$H" "[$(rv APPROVED "$H")]")"
  [ "$rc" = 0 ] && grep -q 'Aprovado por um dono\.' "$TMP/out" || falha "caso 15: ligado com aprovação deveria dizer aprovado (saiu $rc)"
  # constituição commitada com CRLF vale ligado (B3-1/E3-2)
  rc="$(CONSTITUICAO="$(printf 'x\r\nMerge autônomo: ligado\r')" aprova22 "$H" "[]")"
  [ "$rc" = 0 ] && grep -q '^::warning::Modo autônomo ligado' "$TMP/out" || falha "caso 17: CRLF deveria valer ligado (saiu $rc)"
  for c22 in 'Merge autônomo: desligado' "$(printf 'Merge autônomo: ligado\nMerge autônomo: ligado')" ''; do
    rc="$(CONSTITUICAO="$c22" aprova22 "$H" "[]")"
    [ "$rc" = 1 ] && grep -q 'Aprovação pendente' "$TMP/out" || falha "caso 16: modo '$c22' sem aprovação deveria bloquear (saiu $rc)"
  done
  for f in "$FLUXO" "$T/.github/CODEOWNERS"; do
    grep -q 'Require review from Code Owners' "$f" && grep -q 'Dismiss stale pull request approvals when new commits are pushed' "$f" \
      || falha "caso 5: comentário sem as opções nativas em $f"
  done
fi

# --------------------------------------------------------------- 22 ---
cenario "26: modo autônomo (MODO_AUTONOMO)"
resp22() { { grep -v '^MODO_AUTONOMO=' "$EXEMPLO"; [ -z "${1+x}" ] || printf "MODO_AUTONOMO='%s'\n" "$1"; } >"$2"; }
# ligado: grava, renderiza a linha literal e imprime a configuração do GitHub sem criar nada
T="$(novo_repo)"; resp22 ligado "$TMP/r22"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
[ "$rc" = 0 ] || falha "ligado saiu com $rc: $(cat "$TMP/err")"
grep -q "^MODO_AUTONOMO='ligado'\$" "$T/cockpit.config" || falha "ligado não gravado"
[ "$(grep -c '^Merge autônomo: ' "$T/docs/constitution.md")" = 1 ] && grep -q '^Merge autônomo: ligado$' "$T/docs/constitution.md" || falha "constituição sem a linha ligado"
grep -q 'Merge autônomo ligado: configure no GitHub' "$TMP/out" "$TMP/err" || falha "configuração do GitHub não impressa"
! grep -rq 'MODO_AUTONOMO\|Merge autônomo' "$T/docs/rito-dev.md" || falha "rito renderizou o modo"
grep -q 'Fonte esperada de caminhos-previstos: o app que publica o status da trava' "$TMP/out" "$TMP/err" || falha "fonte esperada da trava não impressa (integração ≠ produção)"
grep -q 'Fonte esperada de caminhos-previstos-producao: a mesma' "$TMP/out" "$TMP/err" || falha "fonte esperada da produção não impressa"
# identidade com P1/P2, trava na branch padrão e reexecução depois da aprovação (A9, A16, A18)
grep -q 'fora do CODEOWNERS (P1); sem papel admin nem maintain no repositório (P2)' "$TMP/out" || falha "identidade sem P1/P2"
grep -q 'só roda se estiver na branch padrão do repositório' "$TMP/out" || falha "sem o aviso da branch padrão"
grep -q 'o dono aprova no commit atual da PR e reexecuta o workflow da trava' "$TMP/out" || falha "sem a reexecução depois da aprovação"
grep -q 'Segredo TOKEN_AUTOMACAO' "$TMP/out" || falha "sem a orientação do TOKEN_AUTOMACAO (integração ≠ produção)"
# limite de autoria e troca de modo (A2-6, B2-4, B2-5)
grep -q 'Limite conhecido: a trava não confere o autor da PR' "$TMP/out" || falha "sem o limite conhecido da autoria"
grep -q 'reexecute a trava e o require-codeowner-approval nas PRs abertas' "$TMP/out" && grep -qF 'gh pr merge <n> --disable-auto' "$TMP/out" || falha "sem a orientação da troca de modo"
# integração = produção: só a fonte do ruleset único; o TOKEN_AUTOMACAO continua (release.yml roda com ele, E15)
T="$(novo_repo)"; { grep -v '^MODO_AUTONOMO=\|^BRANCH_INTEGRACAO=' "$EXEMPLO"; printf "MODO_AUTONOMO='ligado'\nBRANCH_INTEGRACAO='main'\n"; } >"$TMP/r22"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
[ "$rc" = 0 ] || falha "integração = produção saiu com $rc: $(cat "$TMP/err")"
grep -q 'Fonte esperada de caminhos-previstos: o app' "$TMP/out" "$TMP/err" || falha "fonte esperada não impressa (integração = produção)"
! grep -q 'Fonte esperada de caminhos-previstos-producao' "$TMP/out" "$TMP/err" || falha "imprimiu fonte da produção com ruleset único"
grep -q 'Segredo TOKEN_AUTOMACAO.*o release.yml roda com ele' "$TMP/out" || falha "sem a orientação do TOKEN_AUTOMACAO (integração = produção)"
# desligado: sem impressão do GitHub
T="$(novo_repo)"; resp22 desligado "$TMP/r22"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
[ "$rc" = 0 ] && grep -q '^Merge autônomo: desligado$' "$T/docs/constitution.md" || falha "desligado (exit $rc)"
! grep -q 'configure no GitHub' "$TMP/out" "$TMP/err" || falha "desligado imprimiu configuração do GitHub"
# vazio de fato (MODO_AUTONOMO=''): vale desligado, sem aviso de inválido
T="$(novo_repo)"; resp22 "" "$TMP/r22"
grep -qx "MODO_AUTONOMO=''" "$TMP/r22" || falha "vazio: respostas sem a linha vazia"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
[ "$rc" = 0 ] && grep -q '^Merge autônomo: desligado$' "$T/docs/constitution.md" || falha "vazio (exit $rc)"
! grep -q 'MODO_AUTONOMO inválido' "$TMP/err" && ! grep -q 'configure no GitHub' "$TMP/out" || falha "vazio avisou inválido ou imprimiu a configuração do GitHub"
# ausente: vale desligado; --atualizar sem a chave não falha nem pergunta
T="$(novo_repo)"; grep -v '^MODO_AUTONOMO=' "$EXEMPLO" >"$TMP/r22"
rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
[ "$rc" = 0 ] && grep -q '^Merge autônomo: desligado$' "$T/docs/constitution.md" || falha "ausente (exit $rc)"
grep -v '^MODO_AUTONOMO=' "$T/cockpit.config" >"$TMP/c22"; cp "$TMP/c22" "$T/cockpit.config"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "--atualizar sem a chave saiu com $rc: $(cat "$TMP/err")"
! grep -q 'MODO_AUTONOMO' "$TMP/err" || falha "--atualizar citou MODO_AUTONOMO"
# inválido (inclusive `Ligado`, com maiúscula): não derruba; vale desligado com aviso
for v22 in sim Ligado; do
  T="$(novo_repo)"; resp22 "$v22" "$TMP/r22"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
  [ "$rc" = 0 ] && grep -q '^Merge autônomo: desligado$' "$T/docs/constitution.md" || falha "inválido '$v22' (exit $rc)"
  grep -q "MODO_AUTONOMO inválido ('$v22')" "$TMP/err" || falha "inválido '$v22' sem aviso"
  ! grep -q 'configure no GitHub' "$TMP/out" || falha "inválido '$v22' imprimiu a configuração do GitHub"
done
# constituição mantida diverge do cockpit.config no --atualizar: avisa e vale a constituição (E6)
T="$(novo_repo)"; resp22 ligado "$TMP/r22"
rodar "$CONF" --projeto "$T" --respostas "$TMP/r22" >/dev/null 2>&1 || falha "divergência: setup ligado"
sed -i 's/^Merge autônomo: ligado$/Merge autônomo: desligado/' "$T/docs/constitution.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] && grep -q '^Merge autônomo: desligado$' "$T/docs/constitution.md" || falha "divergência ligado→desligado (exit $rc)"
grep -q "MODO_AUTONOMO='ligado' no cockpit.config diverge da constituição mantida" "$TMP/err" || falha "divergência ligado→desligado sem aviso"
! grep -q 'configure no GitHub' "$TMP/out" || falha "divergência: imprimiu a configuração do GitHub pelo cockpit.config"
T="$(novo_repo)"; resp22 desligado "$TMP/r22"
rodar "$CONF" --projeto "$T" --respostas "$TMP/r22" >/dev/null 2>&1 || falha "divergência: setup desligado"
sed -i 's/^Merge autônomo: desligado$/Merge autônomo: ligado/' "$T/docs/constitution.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] || falha "divergência desligado→ligado (exit $rc)"
grep -q "MODO_AUTONOMO='desligado' no cockpit.config diverge da constituição mantida" "$TMP/err" || falha "divergência desligado→ligado sem aviso"
grep -q 'Merge autônomo ligado: configure no GitHub' "$TMP/out" || falha "divergência: não imprimiu a configuração do GitHub pela constituição"
# sem divergência no --atualizar: nenhum aviso
T="$(novo_repo)"; resp22 ligado "$TMP/r22"
rodar "$CONF" --projeto "$T" --respostas "$TMP/r22" >/dev/null 2>&1 || falha "sem divergência: setup"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] && ! grep -q 'diverge da constituição' "$TMP/err" || falha "sem divergência avisou (exit $rc)"
# constituição com CRLF (checkout com autocrlf): a linha vale ligado, sem divergência falsa (E2-8)
sed -i 's/$/\r/' "$T/docs/constitution.md"
rc="$(codigo rodar "$CONF" --projeto "$T" --atualizar </dev/null)"
[ "$rc" = 0 ] && ! grep -q 'diverge da constituição' "$TMP/err" && grep -q 'Merge autônomo ligado: configure no GitHub' "$TMP/out" || falha "CRLF virou desligado (exit $rc)"
# constituição ausente (destino do projeto) com ligado: aviso explícito do erro de leitura da trava (E2-8)
for v22 in ligado desligado; do
  T="$(novo_repo)"; { grep -v '^MODO_AUTONOMO=\|^DESTINOS_DO_PROJETO=' "$EXEMPLO"; printf "MODO_AUTONOMO='%s'\nDESTINOS_DO_PROJETO='docs/constitution.md'\n" "$v22"; } >"$TMP/r22"
  rc="$(codigo rodar "$CONF" --projeto "$T" --respostas "$TMP/r22")"
  [ "$rc" = 0 ] && [ ! -e "$T/docs/constitution.md" ] || falha "constituição ausente, $v22: setup (exit $rc)"
  if [ "$v22" = ligado ]; then
    grep -q 'não há docs/constitution.md legível' "$TMP/err" && grep -q 'erro de leitura: constituição' "$TMP/err" || falha "constituição ausente com ligado sem aviso"
    # depois do aviso vale desligado: a configuração do GitHub não sai (E3-8)
    ! grep -q 'configure no GitHub' "$TMP/out" "$TMP/err" || falha "constituição ausente com ligado imprimiu a configuração do GitHub"
  else
    ! grep -q 'docs/constitution.md legível' "$TMP/err" || falha "constituição ausente com desligado avisou"
  fi
done

# --------------------------------------------------------------- 27 ---
cenario "27: caminhos-previstos (trava do merge autônomo, contrato caminhos-previstos.md)"
T="$(novo_repo)"
rodar "$CONF" --projeto "$T" --respostas "$EXEMPLO" >/dev/null 2>&1 || falha "render para a trava falhou"
WF="$T/.github/workflows/caminhos-previstos.yml"
awk '/run: \|/ {r=1; next} r {sub(/^          /, ""); print}' "$WF" >"$TMP/trava.sh"
[ -s "$TMP/trava.sh" ] || falha "não extraí o passo da trava"
bash -n "$TMP/trava.sh" || falha "trava com erro de sintaxe"
grep -q '^  pull_request_target:' "$WF" && ! grep -qE '^ *(- )?uses:|actions/checkout' "$WF" || falha "trava deve ser pull_request_target sem checkout nem action"
INT="$(sed -n "s/^BRANCH_INTEGRACAO='\(.*\)'\$/\1/p" "$EXEMPLO")"
PRD="$(sed -n "s/^BRANCH_PRODUCAO='\(.*\)'\$/\1/p" "$EXEMPLO")"
FX="$TMP/fx"; mkdir -p "$TMP/ghfx"
cat >"$TMP/ghfx/gh" <<'EOF'
#!/usr/bin/env bash
# gh falso da trava: responde com fixtures de $FX e registra os status publicados. Arquivo ausente
# sai com "(HTTP 404)" no stderr, formato que a trava assume para o 404 do gh real e que não está
# confirmado na fonte (research R18); rota que contém $ERRO27 sai com erro 500;
# $FX/depois_N.json vira o pull_N.json quando a lista de arquivos de N é lida (push no meio da trava).
# Conteúdo sem o Accept raw devolve o objeto da API: $FX/m/<ref>/<caminho> quando existe (link, por exemplo),
# senão {type:"file", path:<caminho>} para o arquivo que existe.
[ "$1" = api ] || exit 2
shift
jqf="" post=0 campos=() ep="" raw=0
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) jqf="$2"; shift 2 ;;
    --paginate) shift ;;
    -H) [ "$2" != "Accept: application/vnd.github.raw+json" ] || raw=1; shift 2 ;;
    -X) post=1; shift 2 ;;
    -f) campos+=("$2"); shift 2 ;;
    *) ep="$1"; shift ;;
  esac
done
if [ "$post" = 1 ]; then printf '%s\n' "${campos[*]}" >>"$FX/status.log"; exit 0; fi
ep="${ep#repos/o/r/}"
case "$ep" in
  contents/*)
    p="${ep#contents/}"; ref="${p##*?ref=}"; p="${p%%\?*}"; f="$FX/c/$ref/$p"
    if [ "$raw" = 0 ] && [ -f "$f" ]; then
      f="$FX/m/$ref/$p"
      [ -f "$f" ] || { f="$FX/meta"; jq -n --arg p "$p" '{type:"file",path:$p}' >"$f"; }
    fi ;;
  pulls/*/files*) n="${ep#pulls/}"; n="${n%%/*}"; f="$FX/files_$n.json"; [ ! -f "$FX/depois_$n.json" ] || mv "$FX/depois_$n.json" "$FX/pull_$n.json" ;;
  pulls/*/reviews*) f="$FX/reviews.json" ;;
  pulls/*) f="$FX/pull_${ep#pulls/}.json" ;;
  *) exit 2 ;;
esac
case "$ep" in *"${ERRO27:-//nunca//}"*) echo "gh: Server Error (HTTP 500)" >&2; exit 1 ;; esac
[ -f "$f" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
if [ -n "$jqf" ]; then jq -r "$jqf" "$f"; else cat "$f"; fi
EOF
chmod +x "$TMP/ghfx/gh"
REGIAO_PADRAO='# Decisões

## Caminhos previstos

```
src/**
README.md
package.json
```

## Dependências novas

Nenhuma.
'
reset27() { # reset27 — fixtures-base: modo ligado, registro de f, dono @maria-exemplo, PR 5 de f
  rm -rf "$FX"; mkdir -p "$FX/c/$INT/docs" "$FX/c/basesha/docs/specs/f" "$FX/c/basesha/.github"
  printf 'x\nMerge autônomo: ligado\ny\n' >"$FX/c/$INT/docs/constitution.md"
  printf '%s' "$REGIAO_PADRAO" >"$FX/c/basesha/docs/specs/f/decisoes-do-owner.md"
  printf '* @maria-exemplo @jose-exemplo\n' >"$FX/c/basesha/.github/CODEOWNERS"
  pr27 5 h1 "$INT" feat o/r 1 ""
  files27 5 "src/a.js||modified"
  echo '[]' >"$FX/reviews.json"
}
pr27() { # pr27 N HEAD BASE HEADREF HEADREPO CHANGED CORPO [MERGED]
  jq -n --arg h "$2" --arg b "$3" --arg r "$4" --arg hr "$5" --argjson c "$6" --arg body "$7" --argjson m "${8:-false}" \
    '{head:{sha:$h,ref:$r,repo:{full_name:$hr}},base:{sha:"basesha",ref:$b},changed_files:$c,body:$body,merged:$m}' >"$FX/pull_$1.json"
}
files27() { # files27 N "arquivo|anterior|status"...
  local n="$1" l; shift
  for l in "$@"; do IFS='|' read -r a b c <<<"$l"; jq -n --arg a "$a" --arg b "$b" --arg c "$c" '{filename:$a,status:$c} + (if $b == "" then {} else {previous_filename:$b} end)'; done | jq -s . >"$FX/files_$n.json"
  # a PR 5 é de f (acrescenta o spec.md) salvo NOSPEC27=1
  if [ "$n" = 5 ] && [ -z "${NOSPEC27:-}" ]; then jq '. + [{filename:"docs/specs/f/spec.md",status:"added"}] | unique_by(.filename)' "$FX/files_5.json" >"$FX/f5" && mv "$FX/f5" "$FX/files_5.json"; fi
}
put27() { mkdir -p "$(dirname "$FX/c/$1/$2")"; printf '%s' "$3" >"$FX/c/$1/$2"; }
aprova27() { jq -n --arg u "$1" --arg c "$2" '[{user:{login:$u},state:"APPROVED",commit_id:$c}]' >"$FX/reviews.json"; }
roda27() { # roda27 [VAR=valor...] — roda a trava; sai 0 sempre; o status vai em $FX/status.log
  : >"$FX/status.log"
  local rc n
  n="${CHG27:-$(jq length "$FX/files_5.json")}"
  jq --argjson n "$n" '.changed_files = $n' "$FX/pull_5.json" >"$FX/p5" && mv "$FX/p5" "$FX/pull_5.json"
  rc="$(codigo env PATH="$TMP/ghfx:$PATH" FX="$FX" GH_TOKEN=x REPO=o/r PR=5 EVENT_SHA=h1 BASE_REF="$INT" INTEGRACAO="$INT" PRODUCAO="$PRD" "$@" bash "$TMP/trava.sh")"
  [ "$rc" = 0 ] || falha "trava saiu com $rc: $(cat "$TMP/err")"
}
espera27() { # espera27 "caso" estado trecho [contexto]
  local ult; ult="$(tail -1 "$FX/status.log")"
  case "$ult" in *"state=$2 "*"context=${4:-caminhos-previstos} "*"$3"*) ;; *) falha "$1: esperava $2 '$3', publicou: $ult" ;; esac
}
reg27() { put27 basesha docs/specs/f/decisoes-do-owner.md "$1"; }
# status é "state=X context=Y description=Z"
reset27; files27 5 "src/a.js||modified" "docs/specs/f/spec.md||added"; pr27 5 h1 "$INT" feat o/r 2 ""
roda27; espera27 "frente conforme" success "conforme registro de f"
reset27; printf 'x\nMerge autônomo: desligado\n' >"$FX/c/$INT/docs/constitution.md"; files27 5 "lib/x.js||added"
roda27; espera27 "modo desligado" success "modo desligado"
reset27; printf 'Merge autônomo: ligado\nMerge autônomo: ligado\n' >"$FX/c/$INT/docs/constitution.md"
roda27; espera27 "duas linhas de modo" success "modo desligado"
reset27; rm "$FX/c/$INT/docs/constitution.md"
roda27; espera27 "constituição ilegível" failure "erro de leitura"
# constituição commitada com CRLF vale ligado (B3-1/E3-2): a trava confere e reprova o arquivo fora do bloco
reset27; printf 'x\r\nMerge autônomo: ligado\r\ny\r\n' >"$FX/c/$INT/docs/constitution.md"; files27 5 "lib/x.js||added"
roda27; espera27 "constituição com CRLF" failure "fora do bloco: lib/x.js"
reset27; files27 5 "lib/x.js||added"
roda27; espera27 "fora do bloco" failure "fora do bloco: lib/x.js"
reset27; files27 5 "src/a.js|lib/old.js|renamed"
roda27; espera27 "renomeação com nome anterior fora" failure "fora do bloco: lib/old.js"
reset27; files27 5 "lib/new.js|src/a.js|renamed"
roda27; espera27 "renomeação com nome novo fora" failure "fora do bloco: lib/new.js"
reset27
CHG27=3 roda27; espera27 "total diferente de changed_files" failure "lista incompleta"
reset27
roda27 EVENT_SHA=h0; espera27 "HEAD mudou" failure "HEAD mudou"
# push no meio da trava (E8): depois de listar, a cabeça já é outra
reset27; jq '.head.sha = "h2"' "$FX/pull_5.json" >"$FX/depois_5.json"
roda27; espera27 "HEAD mudou durante a lista" failure "HEAD mudou"
# lista vazia com changed_files=1 (E11), nome com 0x1f e status desconhecido (B11)
reset27; NOSPEC27=1 files27 5
CHG27=1 roda27; espera27 "lista vazia com changed_files=1" failure "lista incompleta"
reset27; files27 5 "$(printf 'src/a\037b.js||modified')"
roda27; espera27 "nome com 0x1f" failure "lista inválida"
reset27; files27 5 "$(printf 'src/a\037b.js|added|renamed')"
roda27; espera27 "nome com 0x1f que desloca um status válido para o 3º campo" failure "lista inválida"
reset27; files27 5 "src/a.js||mexido"
roda27; espera27 "status desconhecido" failure "lista inválida"
# caractere de controle (0x00-0x1f) em qualquer campo vale "lista inválida" antes da contagem (B2-9): quebra de
# linha que forja duas linhas válidas com a contagem fechando, TAB no nome e controle no nome anterior
reset27; jq -n '[{filename:"src/a.js\u001f\u001fmodified\nsrc/b.js",status:"modified"},{filename:"docs/specs/f/spec.md",status:"added"}]' >"$FX/files_5.json"
CHG27=3 roda27; espera27 "nome com quebra de linha que forja duas linhas" failure "lista inválida"
reset27; files27 5 "$(printf 'src/a\tb.js||modified')"
roda27; espera27 "nome com TAB" failure "lista inválida"
reset27; files27 5 "$(printf 'src/a.js|src/o\001.js|renamed')"
roda27; espera27 "nome anterior com controle" failure "lista inválida"
# descrição cortada no meio de um caractere multibyte (B3/E2): o status sai e o job não cai
reset27; files27 5 "lib/$(printf '%0100d' 0 | tr 0 a)ção.js||added"
roda27; espera27 "corte de multibyte na descrição" failure "fora do bloco: lib/aaaa"
# descrição de 100 KB (E2-4): o corte é no próprio bash, sem pipe que leve SIGPIPE sob pipefail
reset27; files27 5 "lib/$(printf '%0100000d' 0 | tr 0 a).js||added"
roda27; espera27 "descrição de 100 KB" failure "fora do bloco: lib/aaaa"
# registro ilegível por outro erro que não 404 (A17/E10); 404 continua sendo "sem registro"
reset27
roda27 ERRO27=docs/specs/f/decisoes-do-owner.md; espera27 "registro ilegível (HTTP 500)" failure "erro de leitura: registro"
reset27; NOSPEC27=1 files27 5 "docs/specs/nova/spec.md||added"
roda27; espera27 "frente sem registro na base (HTTP 404)" failure "aguarda aprovação de dono (sem registro)"
# PR de outro repositório (fork) para a integração: exige dono (decisão do owner, B6)
reset27; pr27 5 h1 "$INT" feat outro/fork 1 ""
roda27; espera27 "PR de fork" failure "aguarda aprovação de dono (PR de outro repositório)"
aprova27 maria-exemplo h1
roda27; espera27 "PR de fork aprovada no HEAD" success "aprovado por dono (PR de outro repositório)"
reset27; jq '.head.repo = null' "$FX/pull_5.json" >"$FX/p5" && mv "$FX/p5" "$FX/pull_5.json"
roda27; espera27 "cabeça sem repositório" failure "aguarda aprovação de dono (PR de outro repositório)"
# falha direta vence a aprovação de dono (E2-2): o motivo de dono fica guardado e a aprovação só é lida no fim
reset27; reg27 "${REGIAO_PADRAO/README.md/CLAUDE.md}"; files27 5 "CLAUDE.md||modified" "lib/x.js||added"; aprova27 maria-exemplo h1
roda27; espera27 "governança + fora do bloco, aprovada no HEAD" failure "fora do bloco: lib/x.js"
reset27; files27 5 "CLAUDE.md||modified"; aprova27 maria-exemplo h1
roda27; espera27 "governança fora do bloco, aprovada no HEAD" failure "fora do bloco: CLAUDE.md"
reset27; files27 5 "package.json||modified" ".github/workflows/x.yml||modified"; reg27 "${REGIAO_PADRAO/README.md/.github/workflows/x.yml}"; aprova27 maria-exemplo h1
put27 basesha package.json '{"a":1}'; put27 h1 package.json '{"a":2}'
roda27; espera27 "governança + manifesto sem dependência, aprovada no HEAD" failure "manifesto sem dependência aprovada: package.json"
reset27; pr27 5 h1 "$INT" feat outro/fork 1 ""; files27 5 "lib/x.js||added"; aprova27 maria-exemplo h1
roda27; espera27 "fork + fora do bloco, aprovada no HEAD" failure "fora do bloco: lib/x.js"
reset27; reg27 "${REGIAO_PADRAO/README.md/CLAUDE.md}"; files27 5 "CLAUDE.md||modified"; aprova27 maria-exemplo h1
roda27; espera27 "governança dentro do bloco, aprovada no HEAD" success "aprovado por dono (governança: CLAUDE.md)"
# bloco inválido ou ausente
for ruim in '../x' 'src/*.js' '/abs' ' src/a.js' 'a/./b' 'src/**/x' '**'; do
  reset27; reg27 "## Caminhos previstos

\`\`\`
$ruim
\`\`\`
"
  roda27; espera27 "bloco com '$ruim'" failure "linha inválida no bloco"
done
reset27; reg27 "## Caminhos previstos

\`\`\`
\`\`\`
"
roda27; espera27 "bloco vazio" failure "vazio"
reset27; reg27 "## Outra
"
roda27; espera27 "bloco ausente" failure "bloco Caminhos previstos"
reset27; reg27 "## Caminhos previstos

\`\`\`
src/a.js
"
roda27; espera27 "bloco sem fecho" failure "inválido"
# frente ambígua, registro de outra frente via docs/**, sem registro
reset27; put27 basesha docs/specs/g/decisoes-do-owner.md "$REGIAO_PADRAO"; files27 5 "docs/specs/f/spec.md||added" "docs/specs/g/spec.md||added"; pr27 5 h1 "$INT" feat o/r 2 ""
roda27; espera27 "frente ambígua" failure "frente ambígua"
reset27; reg27 "## Caminhos previstos

\`\`\`
docs/**
\`\`\`
"; files27 5 "docs/specs/g/decisoes-do-owner.md||added"
roda27; espera27 "registro de outra frente" failure "aguarda aprovação de dono (governança: docs/specs/g/decisoes-do-owner.md)"
reset27; files27 5 "docs/specs/f/decisoes-do-owner.md||modified"
roda27; espera27 "registro da própria frente" failure "aguarda aprovação de dono"
# PR que só toca o registro (de registro ou de emenda, rodada 3): vai ao dono sem validar o bloco, e um bloco inválido
# na base não trava a própria emenda (A3-10/B3-5)
reset27; reg27 "## Outra
"; NOSPEC27=1 files27 5 "docs/specs/f/decisoes-do-owner.md||modified"
roda27; espera27 "emenda com bloco inválido na base, sem aprovação" failure "aguarda aprovação de dono (governança: docs/specs/f/decisoes-do-owner.md)"
aprova27 maria-exemplo h1
roda27; espera27 "emenda com bloco inválido na base, aprovada no HEAD" success "aprovado por dono (governança: docs/specs/f/decisoes-do-owner.md)"
# PR sem arquivo (E4-11): a guarda `-s "$NOMES"` impede que a lista vazia caia no caminho "só registros" com motivo vazio
reset27; NOSPEC27=1 files27 5
CHG27=0 roda27; espera27 "PR sem arquivo" failure "aguarda aprovação de dono (sem registro)"
reset27; NOSPEC27=1 files27 5 "docs/leia.md||added"
roda27; espera27 "sem registro, sem aprovação" failure "aguarda aprovação de dono (sem registro)"
aprova27 Maria-Exemplo h1
roda27; espera27 "sem registro, aprovado no HEAD" success "aprovado por dono"
aprova27 maria-exemplo h0
roda27; espera27 "aprovação em commit antigo" failure "aguarda aprovação"
aprova27 carlos-exemplo h1
roda27; espera27 "aprovação de quem não é dono" failure "aguarda aprovação"
# governança
for g in docs/constitution.md cockpit.config .github/workflows/x.yml .github/CODEOWNERS CODEOWNERS .claude/hooks/a.sh .mcp.json .npmrc CLAUDE.md .husky/pre-commit commitlint.config.cjs pkg/.commitlintrc.json .releaserc.json apps/x/release.config.js \
  CLAUDE.local.md src/CLAUDE.md src/CLAUDE.local.md docs/specs/f/CLAUDE.md src/.claude/skills/x/SKILL.md docs/specs/f/.claude/settings.json \
  docs/specs/f/claude.md src/Claude.Local.MD src/.CLAUDE/x .Claude/settings.json .claude src/.claude .github .husky; do
  reset27; reg27 "## Caminhos previstos

\`\`\`
**
\`\`\`
"
  reg27 "## Caminhos previstos

\`\`\`
$g
\`\`\`
"
  files27 5 "$g||modified"
  roda27; espera27 "governança $g" failure "aguarda aprovação de dono (governança: $g)"
done
reset27; reg27 "${REGIAO_PADRAO/README.md/.github/workflows/x.yml}"; files27 5 "src/a.js|.github/workflows/x.yml|renamed"
roda27; espera27 "renomeação a partir de .github" failure "governança: .github/workflows/x.yml"
# só o nome de base exato é governança: o template da semente do CLAUDE.md segue a regra comum
reset27; reg27 "## Caminhos previstos

\`\`\`
templates/**
\`\`\`
"; files27 5 "templates/CLAUDE.md.semente.tmpl||modified"
roda27; espera27 "templates/CLAUDE.md.semente.tmpl" success "conforme registro de f"
# manifesto e lockfile
reset27; files27 5 "package.json||modified"; put27 basesha package.json '{"a":1}'; put27 h1 package.json '{"a":1}'
roda27; espera27 "manifesto sem dependência nova" failure "manifesto sem dependência aprovada: package.json"
# "Dependências novas" em formato fechado (rodadas 3 e 4, B3-4/E3-3/A3-9/E4-8): só aprova o item que começa com o pacote
# entre crases, com observação opcional depois de um espaço; qualquer outro item ou texto vale "nenhuma"
DEP27='- `lodash`'
for d27 in "$DEP27" '- `lodash` (permanente)'; do
  reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$d27}"; files27 5 "package.json||modified"; put27 basesha package.json '{"a":1}'; put27 h1 package.json '{"a":2}'
  roda27; espera27 "dependências '$d27' com manifesto" success "conforme registro de f"
done
for d27 in 'Nenhuma dependência nova.' 'Nenhuma. ' "$(printf 'Nenhuma.\n\nObservação: nada a instalar nesta frente.')" \
  '- Nenhuma.' '- (nenhuma)' '- NENHUMA!' '- Nenhuma dependência nova.' '- —' \
  '- Não há.' '- N/A' '- Sem dependências novas' '- nada' '- 0' '- Ver seção X' '- lodash' '- ``' '- ` `' '`lodash`' \
  '- Nenhuma (o `package.json` só muda `scripts`).' '- Não há; ver `docs/x.md`' '- `lodash`, uso permanente' '- `lo dash`'; do
  reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$d27}"; files27 5 "package.json||modified"; put27 basesha package.json '{"a":1}'; put27 h1 package.json '{"a":2}'
  roda27; espera27 "dependências '$d27' com manifesto" failure "manifesto sem dependência aprovada: package.json"
done
reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$DEP27}"; files27 5 "pnpm-lock.yaml||modified"
roda27; espera27 "lockfile fora do bloco" failure "manifesto sem dependência aprovada: pnpm-lock.yaml"
for m27 in bun.lock bun.lockb deno.lock uv.lock pnpm-workspace.yaml apps/web/bun.lock; do
  reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$DEP27}"; files27 5 "$m27||modified"
  roda27; espera27 "manifesto ou lockfile $m27 fora do bloco" failure "manifesto sem dependência aprovada: $m27"
done
reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$DEP27}"; files27 5 "src/package.json||modified"; put27 basesha src/package.json '{}'; put27 h1 src/package.json '{}'
roda27; espera27 "manifesto coberto só por dir/**" failure "manifesto sem dependência aprovada: src/package.json"
reset27; reg27 "${REGIAO_PADRAO/Nenhuma./$DEP27}"; files27 5 "package.json||modified"; put27 basesha package.json '{"release":{"a":1}}'; put27 h1 package.json '{"release":{"a":2}}'
roda27; espera27 "chave release alterada" failure "aguarda aprovação de dono (governança: release em package.json)"
# CHK014: acréscimo puro em permissions.deny
SET='{"permissions":{"deny":["Bash(a)"]},"x":1}'
reg27 "## Caminhos previstos

\`\`\`
.claude/settings.json
\`\`\`
"
rec14() { reset27; reg27 "## Caminhos previstos

\`\`\`
.claude/settings.json
\`\`\`
"; files27 5 ".claude/settings.json||${3:-modified}"; [ -z "$1" ] || put27 basesha .claude/settings.json "$1"; put27 h1 .claude/settings.json "$2"; }
rec14 "$SET" '{"permissions":{"deny":["Bash(a)","Bash(b)"]},"x":1}'
roda27; espera27 "CHK014 acréscimo puro" success "conforme registro de f"
rec14 "$SET" '{"x":1,"permissions":{"deny":["Bash(a)"]}}'
roda27; espera27 "CHK014 sem mudança de conteúdo" success "conforme registro de f"
rec14 "$SET" '{"permissions":{"deny":["Bash(b)"]},"x":1}'
roda27; espera27 "CHK014 regra removida" failure "aguarda aprovação de dono (governança: .claude/settings.json)"
rec14 "$SET" '{"permissions":{"deny":["Bash(a)","Bash(b)"]},"x":2}'
roda27; espera27 "CHK014 outra chave alterada" failure "aguarda aprovação de dono"
rec14 "$SET" '{"permissions":{"deny":["Bash(a)"],"allow":["Bash(z)"]},"x":1}'
roda27; espera27 "CHK014 allow acrescentado" failure "aguarda aprovação de dono"
rec14 "$SET" '{"permissions":{"deny":["Bash(a)"]},"x":1,"hooks":{}}'
roda27; espera27 "CHK014 hook acrescentado" failure "aguarda aprovação de dono"
rec14 "$SET" '{"permissions":{"deny":["Bash(a)",{"t":1}]},"x":1}'
roda27; espera27 "CHK014 item que não é texto" failure "aguarda aprovação de dono"
rec14 "$SET" '{"permissions":{}}'
roda27; espera27 "CHK014 deny apagado" failure "aguarda aprovação de dono"
rec14 "" '{"permissions":{"deny":["Bash(a)"]}}' added
roda27; espera27 "CHK014 arquivo novo só com deny" success "conforme registro de f"
rec14 "" '{"permissions":{"deny":["Bash(a)"]},"hooks":{}}' added
roda27; espera27 "CHK014 arquivo novo com hook" failure "aguarda aprovação de dono"
rec14 "" '{"permissions":{"deny":["Bash(a)"],"allow":[]}}' added
roda27; espera27 "CHK014 arquivo novo com allow" failure "aguarda aprovação de dono"
rec14 "$SET" 'não é json'
roda27; espera27 "CHK014 JSON inválido" failure "aguarda aprovação de dono"
rec14 "$SET" "$SET"; reg27 "${REGIAO_PADRAO/README.md/.claude/settings.local.json}"; files27 5 ".claude/settings.local.json||modified"
roda27; espera27 "CHK014 settings.local.json" failure "aguarda aprovação de dono (governança: .claude/settings.local.json)"
# .claude/settings.json que é link, no HEAD ou na base (E3-11): a API de conteúdo descreve `type` symlink ou, com o alvo
# arquivo do repositório, responde com o arquivo do alvo (outro `path`); a exceção não vale, nem com acréscimo puro
for m14 in '{"type":"symlink","path":".claude/settings.json","target":"../src/s.json"}' '{"type":"file","path":"src/s.json"}'; do
  for r14 in h1 basesha; do
    rec14 "$SET" '{"permissions":{"deny":["Bash(a)","Bash(b)"]},"x":1}'
    mkdir -p "$FX/m/$r14/.claude"; printf '%s' "$m14" >"$FX/m/$r14/.claude/settings.json"
    roda27; espera27 "CHK014 link em $r14 ($m14)" failure "aguarda aprovação de dono (governança: .claude/settings.json)"
  done
done
# renomeação para .claude/settings.json nunca tem a exceção, nem com acréscimo puro sobre o da base (E3-12)
rec14 "$SET" '{"permissions":{"deny":["Bash(a)","Bash(b)"]},"x":1}'; reg27 "## Caminhos previstos

\`\`\`
.claude/settings.json
src/**
\`\`\`
"; files27 5 ".claude/settings.json|src/s.json|renamed"
roda27; espera27 "CHK014 renomeação para .claude/settings.json" failure "aguarda aprovação de dono (governança: .claude/settings.json)"
# correção ou revert
NOSPEC27=1
reset27; put27 basesha docs/specs/f/x.md ""; files27 3 "src/a.js||modified" "docs/specs/f/x.md||added"; pr27 3 hh "$INT" feat o/r 2 "" true
pr27 5 h1 "$INT" fix o/r 1 "$(printf 'Corrige\n\nOrigem: #3\n')"
roda27; espera27 "correção dentro da PR de origem" success "correção de #3"
files27 5 "src/b.js||modified"
roda27; espera27 "correção fora da PR de origem" failure "fora da PR de origem #3: src/b.js"
# origem mergeada no modo desligado (sem trava) tocando fora do bloco: a correção também precisa caber no bloco da
# frente da origem; fora dele falha direto (E3-4)
files27 3 "lib/x.js||modified" "docs/specs/f/x.md||added"; files27 5 "lib/x.js||modified"
roda27; espera27 "correção fora do bloco da frente da origem" failure "fora do bloco: lib/x.js"
files27 3 "src/a.js||modified" "docs/specs/f/x.md||added"
files27 5 "src/a.js||modified"; pr27 3 hh "$INT" feat o/r 2 "" false
roda27; espera27 "origem não mergeada" failure "não mergeada nesta base"
pr27 3 hh "$PRD" feat o/r 2 "" true
roda27; espera27 "origem em outra base" failure "não mergeada nesta base"
pr27 3 hh "$INT" feat o/r 2 "" true; files27 3 "src/a.js||modified" "docs/leia.md||added"
roda27; espera27 "origem sem registro" failure "não é PR de frente"
pr27 5 h1 "$INT" fix o/r 1 "$(printf 'Origem: #3\nOrigem: #4\n')"; files27 3 "src/a.js||modified" "docs/specs/f/x.md||added"; NOSPEC27='' files27 5 "src/a.js||modified"
roda27; espera27 "duas linhas Origem caem na frente (src/a.js cabe no bloco)" success "conforme registro de f"
# origem que toca f e g, com erro 500 ao ler o registro de g: erro de leitura, nunca correção só de f (E2-9)
reset27; put27 basesha docs/specs/f/x.md ""; files27 3 "src/a.js||modified" "docs/specs/f/x.md||added" "docs/specs/g/y.md||added"; pr27 3 hh "$INT" feat o/r 3 "" true
pr27 5 h1 "$INT" fix o/r 1 "$(printf 'Origem: #3\n')"; files27 5 "src/a.js||modified"
roda27 ERRO27=docs/specs/g/decisoes-do-owner.md; espera27 "origem com registro ilegível" failure "erro de leitura: registro da origem"
# correção com governança: falhas diretas antes da aprovação de dono (E2-2); a governança também precisa estar no bloco
reset27; reg27 "${REGIAO_PADRAO/README.md/CLAUDE.md}"; put27 basesha docs/specs/f/x.md ""; files27 3 "CLAUDE.md||modified" "docs/specs/f/x.md||added"; pr27 3 hh "$INT" feat o/r 2 "" false
pr27 5 h1 "$INT" fix o/r 1 "$(printf 'Origem: #3\n')"; files27 5 "CLAUDE.md||modified"; aprova27 maria-exemplo h1
roda27; espera27 "correção não mergeada tocando CLAUDE.md, aprovada no HEAD" failure "origem #3 não mergeada nesta base"
pr27 3 hh "$INT" feat o/r 2 "" true
roda27; espera27 "correção mergeada tocando CLAUDE.md, aprovada no HEAD" success "aprovado por dono (governança: CLAUDE.md)"
echo '[]' >"$FX/reviews.json"
roda27; espera27 "correção mergeada tocando CLAUDE.md, sem aprovação" failure "aguarda aprovação de dono (governança: CLAUDE.md)"
reg27 "$REGIAO_PADRAO"; aprova27 maria-exemplo h1
roda27; espera27 "correção mergeada tocando CLAUDE.md fora do bloco, aprovada no HEAD" failure "fora do bloco: CLAUDE.md"
# correção com manifesto ou lockfile exige dono, mesmo dentro da PR de origem (B5/E5)
for m27 in package.json pnpm-lock.yaml; do
  reset27; reg27 "${REGIAO_PADRAO/README.md/$m27}"; put27 basesha docs/specs/f/x.md ""; files27 3 "$m27||modified" "docs/specs/f/x.md||added"; pr27 3 hh "$INT" feat o/r 2 "" true
  pr27 5 h1 "$INT" fix o/r 1 "$(printf 'Origem: #3\n')"; files27 5 "$m27||modified"; put27 basesha "$m27" '{"a":1}'; put27 h1 "$m27" '{"a":2}'
  roda27; espera27 "correção com $m27" failure "aguarda aprovação de dono (manifesto em correção: $m27)"
done
unset NOSPEC27
# PR para a produção (A1)
if [ "$INT" != "$PRD" ]; then
  reset27; pr27 5 h1 "$PRD" "$INT" o/r 1 ""
  roda27 BASE_REF="$PRD"; espera27 "promoção" success "PR de promoção" caminhos-previstos-producao
  reset27; pr27 5 h1 "$PRD" "$INT" outro/fork 1 ""
  roda27 BASE_REF="$PRD"; espera27 "promoção vinda de fork" failure "aguarda aprovação de dono (PR de outro repositório)" caminhos-previstos-producao
  reset27; pr27 5 h1 "$PRD" outra o/r 1 ""
  roda27 BASE_REF="$PRD"; espera27 "outra branch para a produção" failure "aguarda aprovação de dono (PR para a produção)" caminhos-previstos-producao
  aprova27 jose-exemplo h1
  roda27 BASE_REF="$PRD"; espera27 "outra branch para a produção, aprovada" success "aprovado por dono" caminhos-previstos-producao
  reset27; printf 'Merge autônomo: desligado\n' >"$FX/c/$INT/docs/constitution.md"; pr27 5 h1 "$PRD" outra o/r 1 ""
  roda27 BASE_REF="$PRD"; espera27 "produção com modo desligado" success "modo desligado" caminhos-previstos-producao
fi
rm -rf "$FX" "$TMP/ghfx"
# --------------------------------------------------------------- 11 ---
cenario "11: qualidade estática"
if command -v shellcheck >/dev/null 2>&1; then
  (cd "$RAIZ_COCKPIT" && shellcheck -x configurar.sh scripts/lib/versao.sh scripts/testar-configurar.sh instalar.sh) \
    || falha "shellcheck com findings"
else
  printf '  (shellcheck ausente nesta máquina — checado no CI)\n'
fi
(cd "$RAIZ_COCKPIT" && ./scripts/verificar-agnostico.sh >/dev/null) || falha "verificar-agnostico.sh com ocorrências"

printf 'OK: todos os cenários passaram.\n'
