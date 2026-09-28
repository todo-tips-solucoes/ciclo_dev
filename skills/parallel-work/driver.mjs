#!/usr/bin/env node
// parallel-work driver — cria/gerencia git worktrees ISOLADAS para desenvolvimento
// paralelo em múltiplas branches, SEM tocar no HEAD da working tree principal.
//
// `git worktree add` cria um checkout em diretório irmão (../<repo>-<slug>) com seu
// próprio HEAD; a working tree principal permanece exatamente como está — por isso é
// seguro mesmo quando outra sessão (ou humano) está usando a tree principal.
//
// Uso:
//   node driver.mjs new                      → cria branch provisória + worktree isolada
//   node driver.mjs new <branch> [--base R]  → worktree para <branch> (existente ou nova, base R; default HEAD)
//   node driver.mjs new <branch> --short-name N  → mesmo, mas o vínculo de state chama-se N
//   node driver.mjs list                     → lista as worktrees ativas
//
// As flags aceitam as DUAS formas (`--base R` e `--base=R`) e toda opção desconhecida, valor
// ausente, valor vazio ou valor iniciado por `-` é RECUSADO com exit 1 — nunca ignorado.
//
// Saída de `new`: um bloco JSON com { status, branch, path, provisional, base }.
//
// Piso de versões: **Node ≥ 14.14** (`rmSync`) e **git ≥ 2.9** (`worktree add --track -b`;
// `worktree list --porcelain` é 2.7 e `--git-common-dir` é 2.5). Com git < 2.36 o porcelain não
// emite `prunable` e a detecção de worktree morta cai na checagem direta do diretório — degrada,
// não quebra. O smoke que acompanha a frente exige git ≥ 2.28 (`git init -b`).

import { execFileSync } from 'node:child_process';
import { basename, dirname, join, resolve, sep } from 'node:path';
import {
  existsSync, lstatSync, mkdirSync, readlinkSync, realpathSync, rmSync, statSync, symlinkSync,
} from 'node:fs';

function git(args, opts = {}) {
  // Com stdio:'inherit' o execFileSync retorna null (stdout não é capturado).
  const r = execFileSync('git', args, { encoding: 'utf8', ...opts });
  return r == null ? '' : r.toString().trim();
}
function tryGit(args) {
  try { return git(args); } catch { return null; }
}

const repoRoot = git(['rev-parse', '--show-toplevel']);
const repoName = basename(repoRoot);
const parent = dirname(repoRoot);

function slugify(s) {
  return s.replace(/[^A-Za-z0-9._-]+/g, '-').replace(/^-+|-+$/g, '').toLowerCase();
}

// `p` está DENTRO de `dir` (ou é ele)? Ambos precisam chegar aqui absolutos e canônicos —
// comparar texto sem isso é o que faz `/a/bc` parecer estar dentro de `/a/b`.
function sob(dir, p) {
  return p === dir || p.startsWith(dir.endsWith(sep) ? dir : dir + sep);
}
// Mesmo lugar no disco, não a mesma string: `--show-toplevel` devolve o caminho FÍSICO, e um
// `/tmp` que é symlink faria a comparação textual recusar uma árvore perfeitamente válida.
function mesmoLugar(a, b) {
  try { return realpathSync(a) === realpathSync(b); } catch { return false; }
}
// `realpathSync` do ancestral EXISTENTE mais profundo, com o resto do caminho reanexado.
// `realpathSync(p)` direto não serve aqui: o alvo do vínculo nasce PENDURADO — o state só passa
// a existir quando o /feature-00c roda — e estouraria ENOENT justamente na janela do dano.
// Sem canonizar, `sob()` compara TEXTO: um vínculo escrito através de um diretório symlinkado
// (`/atalho/wt/...` para uma worktree registrada em `/real/wt`) não casa com nenhuma worktree,
// `dona` sai `undefined` e o guard 4 deixa o vínculo alheio ser sequestrado.
function canon(p) {
  let cur = resolve(p);
  const resto = [];
  for (;;) {
    try { return join(realpathSync(cur), ...resto); } catch (e) { if (e.code !== 'ENOENT') break; }
    const pai = dirname(cur);
    if (pai === cur) break;                 // chegou na raiz sem nada existir
    resto.unshift(basename(cur));
    cur = pai;
  }
  return resolve(p);
}

// Cria, na ÁRVORE PRINCIPAL, o vínculo que faz a guarda do /feature-00c encontrar o state
// da frente dentro da worktree. Devolve OU { stateLink } OU { stateLinkSkipped } — nunca
// ambos, nunca nenhum: quem consome o relatório distingue os casos sem interpretar texto.
// Falhar aqui NUNCA impede a worktree; o pior caso é a frente nascer sem o vínculo.
//
// A árvore principal vem de `--git-common-dir`, não de `--show-toplevel`: chamado de dentro
// de outra worktree os dois divergem, e é na principal que a guarda procura. (Isso torna o
// vínculo robusto a esse erro de invocação — NÃO o legitima: o driver continua devendo ser
// chamado da árvore principal, como a skill documenta.)
function linkState(worktreePath, slug) {
  // Guard 1 — slug vazio, antes de qualquer toque no disco: `@`, `ü`, `--` e `日本` são
  // branches válidas para o git que slugificam para "". Sem esta saída o caminho colapsaria
  // na própria raiz de state, que o mkdir acabou de garantir existir.
  if (!slug) return { stateLinkSkipped: 'slug-vazio' };
  // O nome precisa ser um componente de caminho simples. Vindo de `slugify`, `.` e `..` são
  // alcançáveis (`@.@` é branch válida que slugifica para `.`) mas `/` não é; vindo de
  // `--short-name`, que NÃO passa por slugify, todos são — e é por isso que a validação mora
  // aqui, no ponto por onde as duas origens passam, e não no `slugify`.
  if (slug === '.' || slug === '..' || slug === '.git'
      || slug.includes('/') || slug.includes('\\')) {
    return { stateLinkSkipped: 'slug-invalido' };
  }
  try {
    // `--git-common-dir` pode vir relativo ao CWD (`.git`, `../.git`) — resolve() ancora nele.
    const commonDir = resolve(git(['rev-parse', '--git-common-dir']));
    const mainRoot = dirname(commonDir);
    // Guard 2 — `dirname(--git-common-dir)` só é a raiz no layout `<raiz>/.git`. Medido: com
    // `--separate-git-dir` o dirname aponta um nível ACIMA da raiz; em submódulo, para DENTRO
    // do `.git` do repositório pai. Nos dois o vínculo nasceria fora do repositório.
    // A saída NÃO é trocar por `--show-toplevel` (isso quebraria o FR-024: chamado de dentro
    // de outra worktree ele devolve a worktree, não a principal, e o vínculo nasceria onde a
    // guarda não procura) — é VALIDAR que o que derivamos é mesmo a raiz de uma árvore de
    // trabalho. Não sendo, falhamos alto: melhor um motivo próprio que acertar por sorte.
    // "Raiz de UMA árvore" não basta: com `--separate-git-dir` apontando para dentro de OUTRO
    // repositório (`git init --separate-git-dir=<vitima>/gd`), o dirname cai exatamente sobre a
    // raiz da vítima, o guard aprova e o vínculo nasce dentro do repositório errado (medido).
    // Por isso a segunda condição — tem de ser a raiz DESTE repositório, i.e. a árvore cujo
    // common-dir é o mesmo que o nosso.
    const top = tryGit(['-C', mainRoot, 'rev-parse', '--show-toplevel']);
    const commonDoTop = tryGit(['-C', mainRoot, 'rev-parse', '--git-common-dir']);
    if (!top || !mesmoLugar(top, mainRoot)
        || !commonDoTop || !mesmoLugar(resolve(mainRoot, commonDoTop), commonDir)) {
      return { stateLinkSkipped: 'arvore-principal-nao-resolvida' };
    }
    const root = join(mainRoot, '.claude', 'feature-00c-state');
    const link = join(root, slug);
    const target = join(worktreePath, '.claude', 'feature-00c-state', slug);
    // Guard 3 — a raiz de state e o pai dela (`.claude`) precisam resolver para um diretório
    // AINDA DENTRO da árvore principal, e a checagem vem ANTES do mkdir: com o mkdir primeiro,
    // só a variante "symlink para diretório" chegava aqui — raiz que é symlink pendurado,
    // symlink para arquivo ou arquivo regular fazia o próprio mkdir estourar, e o motivo virava
    // o errno genérico em vez deste.
    // O que o guard mede é CONTENÇÃO, não tipo de inode: `lstat` não segue o último componente
    // mas segue todos os anteriores, então `.claude` sendo symlink para FORA faria `root`
    // resolver para fora e o `rmSync` do vínculo operar lá. Symlink apontando para dentro do
    // próprio repositório (dotfiles/stow) é setup comum e legítimo — recusá-lo por ser symlink
    // era falso positivo permanente nessas máquinas.
    for (const dir of [dirname(root), root]) {
      let st = null;
      try { st = lstatSync(dir); } catch (e) { if (e.code !== 'ENOENT') throw e; }
      if (!st || st.isDirectory()) continue;      // ausente (o mkdir cria) ou diretório real
      let alvo = null;
      try { alvo = realpathSync(dir); } catch (e) { if (e.code !== 'ENOENT') throw e; }
      if (!alvo || !sob(top, alvo) || !statSync(alvo).isDirectory()) {
        return { stateLinkSkipped: 'raiz-de-state-nao-e-diretorio' };
      }
    }
    mkdirSync(root, { recursive: true });
    let st = null;
    try { st = lstatSync(link); } catch (e) { if (e.code !== 'ENOENT') throw e; }  // ausente = livre
    if (st) {
      // Diretório real é o caminho de MIGRAÇÃO — toda máquina que já rodou o /feature-00c
      // com o driver anterior está neste estado. Não é borda, e apagá-lo destruiria state.
      if (!st.isSymbolicLink()) return { stateLinkSkipped: 'caminho-ocupado-por-diretorio-real' };
      // Guard 4 — "remanescente" tem limite. slugify() não é injetiva (`fix/foo`, `fix-foo` e
      // `FIX/Foo` colidem) e o guard de branch-já-em-uso compara BRANCH, não slug: um vínculo
      // cujo alvo mora em outra worktree é de outra frente.
      // O que decide é a FILIAÇÃO do alvo, não a existência dele: o vínculo nasce PENDURADO por
      // projeto (o state só passa a existir quando o /feature-00c roda), então `existsSync` do
      // alvo respondia "morto" exatamente na janela entre o /parallel-work e o /feature-00c —
      // isto é, na janela inteira em que o sequestro acontece. `git worktree list` responde
      // sobre a worktree, que existe desde o primeiro comando.
      // Comparar com a worktree DESTA execução (e não o texto do alvo) resolve de lambuja o
      // falso positivo simétrico: mesmo alvo escrito de outro jeito continua sendo o desta
      // frente. Do path mais longo para o mais curto, para uma worktree aninhada não ser
      // confundida com a árvore que a contém.
      // Worktree `prunable` (diretório apagado à mão, registro sobrevivente) é CADÁVER, não
      // frente viva: contá-la fazia o guard recusar por causa de um morto — e o remédio que a
      // skill mandava ("reabra com outro --short-name") era o errado, sendo `git worktree prune`
      // o certo. Em git < 2.36 o atributo não é emitido e o comportamento degrada para o antigo.
      const antigo = canon(resolve(root, readlinkSync(link)));
      const dona = worktrees()
        .filter(reivindicavel)
        .map((w) => canon(w.path))
        .sort((a, b) => b.length - a.length)
        .find((p) => sob(p, antigo));
      if (dona && dona !== canon(worktreePath)) {
        return { stateLinkSkipped: 'vinculo-aponta-para-outra-worktree-viva' };
      }
      // force:true e SEM recursive: sobre symlink remove o link e preserva o alvo. A ausência
      // de `recursive` só faz diferença se o caminho DEIXAR de ser symlink entre o lstat acima
      // e esta linha (TOCTOU) — no fluxo determinístico o guard já retornou. Nessa corrida,
      // sem `recursive` o rmSync lança e a execução degrada para "vínculo não criado"; com
      // `recursive` ela apagaria a árvore. É proteção de corrida, não do caminho normal, e por
      // isso nenhum cenário determinístico do smoke consegue falsificá-la.
      rmSync(link, { force: true });
    }
    symlinkSync(target, link);
    return { stateLink: link };
  } catch (err) {
    if (err.code === 'EPERM' || err.code === 'EACCES') {
      return { stateLinkSkipped: 'sem-permissao-de-symlink' };   // Windows sem privilégio
    }
    // err.code, nunca err.message: a mensagem embute caminho absoluto e nome de usuário num
    // campo consumido por leitura estruturada.
    return { stateLinkSkipped: err.code || 'erro-de-io' };
  }
}
function stamp() {
  const d = new Date(), p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}
function worktrees() {
  const out = git(['worktree', 'list', '--porcelain']);
  const list = []; let cur = {};
  for (const line of out.split('\n')) {
    if (line.startsWith('worktree ')) { if (cur.path) list.push(cur); cur = { path: line.slice(9) }; }
    else if (line.startsWith('branch ')) cur.branch = line.slice(7).replace('refs/heads/', '');
    else if (line === 'detached') cur.branch = '(detached)';
    // `prunable [<motivo>]` — o registro sobreviveu ao diretório (apagado à mão). Quem consome
    // decide: o `list` continua mostrando tudo (é o que o git mostra), o guard 4 ignora, e o
    // ramo `exists` para de prometer um diretório que não existe.
    else if (line.startsWith('prunable')) cur.prunable = true;
    // `locked [<motivo>]` — o operador travou de propósito. O git ISENTA travada de `prune`, e
    // por isso nunca emite `prunable` para ela: sem ler isto, uma travada com o diretório
    // ausente é indistinguível de um cadáver, e o `man git-worktree` diz que travar existe
    // JUSTAMENTE para volume removível/rede que nem sempre está montado.
    else if (line.startsWith('locked')) cur.locked = true;
  }
  if (cur.path) list.push(cur);
  return list;
}

// Dois predicados, porque os dois pontos que consultam a worktree fazem perguntas DIFERENTES —
// unificá-los num helper só troca um erro por outro (medido: o cenário da travada quebra).
//
// Em ambos, o teste é o `.git` do destino (arquivo, em worktree ligada), não o diretório: o
// diretório existe em worktree cujo checkout já não serve. Não é infalível — `.git` vazio, com
// lixo, ou sendo um repo aninhado passa; o git também os considera vivos, então é teto conhecido,
// não regressão. E não resolve pai sem permissão de busca: ali o `existsSync` do `.git` falha
// igual (medido), mas o git emite `prunable` e o `prunable` decide antes.

// Guard 4: "esta worktree pode ser DONA de um vínculo?" — travada CONTA. O `man git-worktree`
// diz que travar existe para volume removível/rede que nem sempre está montado: se o volume
// voltar, a frente está lá e não pode ter perdido o vínculo enquanto esteve fora.
function reivindicavel(w) {
  if (w.locked) return true;
  if (w.prunable) return false;
  return existsSync(join(w.path, '.git'));
}

// Ramo `exists`: "tem checkout UTILIZÁVEL agora?" — travada não é exceção. Prometer "trabalhe
// neste diretório" para o que não está acessível é a afirmação falsa que esta frente removeu;
// o que muda com o `locked` é só o REMÉDIO da nota, nunca o veredito.
function utilizavel(w) {
  if (w.prunable) return false;
  return existsSync(join(w.path, '.git'));
}

const cmd = process.argv[2] || 'new';

if (cmd === 'list') {
  // Mesma política do `new`: recusar em vez de ignorar. Aceitar flags aqui em silêncio
  // convidaria a `list --base X` "funcionar" sem fazer nada com o X.
  const extra = process.argv.slice(3);
  if (extra.length) { console.error(`ERRO: list não aceita argumentos: ${extra.join(' ')}`); process.exit(1); }
  for (const w of worktrees()) console.log(`${w.branch || '(?)'}\t${w.path}`);
  process.exit(0);
}

if (cmd === 'new') {
  const rest = process.argv.slice(3);
  // Parse único para TODAS as flags, aceitando `--flag valor` e `--flag=valor`, e recusando o
  // que não entende em vez de ignorar. O parse anterior era `indexOf('--base')` — casamento
  // exato —, então `--base=origin/<ref>`, a forma natural de escrever, caía como "algo que
  // começa com --" e era descartado em silêncio: a branch nascia do HEAD da árvore principal e
  // o relatório declarava `"base": "HEAD"`. Quem escreve assim cumpre a Cláusula de Base
  // Verificada na intenção e a viola no efeito, sem nenhum sinal (medido: `--base=X` criou a
  // worktree no HEAD; `--base X` no ref certo). O mesmo valia para `--short-name=`, que fazia o
  // vínculo nascer com o slug da BRANCH e a guarda do /feature-00c inerte — o defeito exato que
  // a flag existe para evitar —, e para digitação errada (`--shortname`), ignorada calada.
  // Recusar valor iniciado por `-` é também o que fechou o D-127 (já removido do
  // `docs/deferred-work.md`, como o preâmbulo dele manda): `--base --force` deixa de
  // virar base silenciosa (o `--force` era absorvido pelo `git worktree add` como OPÇÃO,
  // desarmando o guard de branch já em checkout que o driver existe para respeitar).
  const FLAGS = ['--base', '--short-name'];
  const morre = (msg) => { console.error(`ERRO: ${msg}`); process.exit(1); };
  const opts = new Map();
  const posicionais = [];
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (arg[0] !== '-') {
      // String vazia como posicional cairia no `if (branchArg)` como falsy e abriria frente
      // PROVISÓRIA calada — o wrapper com variável não setada é o caso real.
      if (arg === '') morre('o nome da branch não pode ser vazio');
      posicionais.push(arg); continue;
    }
    const eq = arg.indexOf('=');
    const flag = eq >= 0 ? arg.slice(0, eq) : arg;
    if (!FLAGS.includes(flag)) morre(`opção desconhecida: ${flag} (aceitas: ${FLAGS.join(', ')})`);
    // `--flag=valor` traz o valor no próprio argumento; `--flag valor` consome o próximo.
    const valor = eq >= 0 ? arg.slice(eq + 1) : rest[++i];
    if (valor === undefined || valor === '') morre(`${flag} exige um valor`);
    if (valor[0] === '-') morre(`valor de ${flag} não pode começar com "-": ${valor}`);
    opts.set(flag, valor);
  }
  if (posicionais.length > 1) {
    morre(`argumentos demais: ${posicionais.join(' ')} (use: new [branch] [--base <ref>] [--short-name <nome>])`);
  }
  const base = opts.get('--base') || 'HEAD';
  const branchArg = posicionais[0];

  let branch, provisional = false;
  if (branchArg) { branch = branchArg; }
  else { branch = `parallel/wip-${stamp()}`; provisional = true; }

  // O vínculo é nomeado por `slugify(branch)`, mas a guarda do /feature-00c procura o state por
  // <short-name> — e a Fase 1 do rito prefixa as branches (`fix/`, `feat/`), então os dois
  // divergem por padrão e o vínculo nasce pendurado PARA SEMPRE, com a guarda inerte e tudo
  // verde. `--short-name` é a saída: opcional, e sem ela o comportamento é o de sempre.
  // A validação de forma (sem separador de caminho, não `.`/`..`/`.git`) é a MESMA do slug e
  // mora no `linkState`, por onde as duas origens passam. Valor vazio ou ausente NÃO chega até
  // lá: o parse acima já recusou com exit 1 — antes, `--short-name` sem valor degradava para
  // `slug-vazio`, worktree criada e guarda inerte, com exit 0.
  const nome = opts.has('--short-name') ? opts.get('--short-name') : slugify(branch);

  const path = join(parent, `${repoName}-${slugify(branch)}`);

  // A branch já está em checkout em algum lugar? (git não deixa abrir 2 worktrees da mesma branch)
  const existing = worktrees().find((w) => w.branch === branch);
  if (existing) {
    const isMain = resolve(existing.path) === resolve(repoRoot);
    // Registro vivo, diretório morto: `git worktree add` na mesma branch continua recusando
    // (medido: `fatal: 'x' is already used by worktree at …`), então o status segue `exists` —
    // mas mandar "trabalhe neste diretório" e ainda criar vínculo para um caminho que não existe
    // é afirmar o que não é.
    //
    // Aqui vale `utilizavel()`, NÃO `reivindicavel()` — e a diferença é deliberada: travada e
    // inacessível não pode ser dona perdida do vínculo (guard 4), mas também não é lugar onde
    // mandar alguém trabalhar. Unificar os dois quebra o cenário C2e do smoke; já foi tentado.
    const morta = !isMain && !utilizavel(existing);
    const out = {
      status: isMain ? 'declare' : 'exists',
      branch, path: existing.path, provisional,
      note: isMain
        ? 'Branch já em checkout na working tree PRINCIPAL — use modo declaração (sem checkout, sem worktree).'
        : morta
          ? (existing.locked
              ? 'Worktree TRAVADA e sem checkout acessível. Se o caminho está num volume removível ou de rede, monte-o — a trava existe para isso e o registro deve ser preservado. Se a worktree foi mesmo apagada à mão: `git worktree unlock <caminho absoluto>` e depois `git worktree prune`, na árvore principal. Se o diretório ainda existir com trabalho dentro, mova-o antes de reabrir — o `add` recusa destino existente, e o `prune` sozinho não o remove.'
              : 'Worktree registrada, mas sem checkout utilizável (diretório ausente, ou registro órfão). Na árvore principal: `git worktree prune`. Se o diretório ainda existir com trabalho dentro, mova-o antes de reabrir — o `add` recusa destino existente.')
          : 'Branch já isolada nesta worktree — trabalhe neste diretório.'
    };
    // `exists` é a worktree aberta por uma execução ANTERIOR — inclusive pelo driver que ainda
    // não criava vínculo. Justamente essas máquinas são as que ficam com a guarda inerte, e
    // reabrir a frente é a única hora em que o operador volta a passar por aqui: então
    // REPARAMOS, em vez de devolver `exists` mudo. `linkState` é idempotente e já recusa
    // sozinho o que não deve tocar (diretório real de state, vínculo de outra frente).
    // Em `declare` NÃO: lá não existe worktree, e o alvo seria o próprio vínculo.
    if (morta) out.stateLinkSkipped = 'worktree-registrada-sem-diretorio';
    else if (!isMain) Object.assign(out, linkState(existing.path, nome));
    console.log(JSON.stringify(out, null, 2));
    process.exit(0);
  }
  if (existsSync(path)) {
    console.error(`ERRO: o diretório de destino já existe: ${path}`);
    process.exit(1);
  }

  const localExists = tryGit(['rev-parse', '--verify', '--quiet', `refs/heads/${branch}`]) !== null;
  // A branch pode existir SÓ no remoto (ex.: PR aberto por outra máquina, nunca checada
  // localmente). Nesse caso NÃO podemos criar do HEAD — isso geraria uma branch local
  // divergente sem rastrear o origin. Procuramos um remote-tracking ref já presente.
  const remotes = (tryGit(['remote']) || '').split('\n').map((s) => s.trim()).filter(Boolean);
  const trackingRemote = localExists
    ? null
    : remotes.find((r) => tryGit(['rev-parse', '--verify', '--quiet', `refs/remotes/${r}/${branch}`]) !== null);

  // git escreve progresso ("Preparing worktree…", "HEAD is now at…") no STDERR;
  // capturamos (sem 'inherit') para o STDOUT conter SÓ o JSON — fácil de consumir.
  const inherit = { stdio: ['ignore', 'ignore', 'inherit'] };
  let mode; // 'local' | 'remote' | 'new' — para reportar honestamente o que foi feito
  // O `--` termina as opções do `git worktree add` (medido nos três modos): nada que venha do
  // argv pode ser absorvido como opção do git. Quem de fato fechou o D-127 é a validação do
  // parse — `--base --force` já não chega aqui —, mas o terminador torna a garantia estrutural
  // em vez de dependente de o parse continuar correto.
  if (branchArg && localExists) {
    mode = 'local';
    git(['worktree', 'add', '--', path, branch], inherit);
  } else if (branchArg && trackingRemote) {
    mode = 'remote';
    // cria a branch local a partir do remote-tracking ref e configura upstream
    git(['worktree', 'add', '--track', '-b', branch, '--', path, `${trackingRemote}/${branch}`], inherit);
  } else {
    mode = 'new';
    git(['worktree', 'add', '-b', branch, '--', path, base], inherit);
  }
  // `base` só faz sentido quando criamos uma branch NOVA a partir dele; ao anexar uma
  // branch já existente (local ou remota) o base é ignorado, então não o reportamos.
  const result = { status: 'created', branch, path, provisional, attachedFrom: mode };
  if (mode === 'new') result.base = base;
  else if (mode === 'remote') result.tracking = `${trackingRemote}/${branch}`;
  // Sempre DEPOIS do `worktree add` retornar 0: é isso que faz o nome derivado da branch já ter
  // passado pelo `check-ref-format` do git (que barra `..`, `.` e `.git`). O `--short-name` não
  // passa por lá — por isso a validação própria no `linkState`. `declare` segue sem vínculo.
  Object.assign(result, linkState(path, nome));
  console.log(JSON.stringify(result, null, 2));
  process.exit(0);
}

console.error(`comando desconhecido: ${cmd} (use: new [branch] [--base <ref>] [--short-name <nome>] | list)`);
process.exit(1);
