#!/usr/bin/env node
// rito-descoberta/historico.mjs — auxiliar SÓ DE LEITURA da Fase 0 e do gate da Fase 11.
//
// Uso:
//   node historico.mjs foto [--raiz <dir>]   → impressão digital das raízes (tipo\tchave\tvalor)
//   node historico.mjs pendentes <log>       → installs/enables temporários sem desfazer posterior
//   node historico.mjs gate <frente>         → gate da Fase 11, rodado dentro da worktree da frente
//   node historico.mjs frente <nome>         → valida o nome da frente (^[a-z0-9][a-z0-9-]*$, até 64)
//
// Códigos de saída: foto 0 ok / 1 falha fechado; pendentes 0 nenhum / 1 há pendentes / 2 log
// ausente, ilegível, vazio, sem evento base ou com linha mal formada; gate 0 pode encerrar / 1
// pendente, diferença ou foto que falhou / 2 log, base ou worktree com problema; frente 0 válido /
// 2 inválido. Uso errado: 64. Contrato: seção "Formato do histórico" da SKILL.md. Nunca imprime
// conteúdo de arquivo. O git roda com --no-optional-locks: a foto não toca o índice.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, readdirSync, readFileSync, readlinkSync, realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { basename, isAbsolute, join, resolve, sep } from 'node:path';

const falha = (msg, code = 1) => { process.stderr.write(`historico: ${msg}\n`); process.exit(code); };
const limpa = (s) => String(s).replace(/[\t\r\n]+/g, ' ');
const sha = (buf) => createHash('sha256').update(buf).digest('hex');
const cmp = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));
const objeto = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
const norma = (p) => { try { return realpathSync(p); } catch { return String(p).replace(/\/+$/, ''); } };
const dentro = (p, raiz) => p === raiz || p.startsWith(raiz + sep);

function git(raiz, args) {
  try {
    return execFileSync('git', ['--no-optional-locks', '-C', raiz, ...args],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 256 * 1024 * 1024 });
  } catch { return null; }
}

// Arquivos sob `dir` (só metadados), pulando `pula`. Symlink que fica dentro da raiz é seguido
// (diretório uma vez por caminho real); o que sai da raiz vira `link:<alvo>`, sem seguir. Symlink
// quebrado e diretório ilegível viram linha própria, nunca somem.
function arquivos(dir, pula) {
  const out = [];
  const raiz = norma(dir);
  const vistos = new Set();
  const meta = (s) => `${s.size} ${s.mtimeMs} ${s.ctimeMs} ${s.ino}`;
  const anda = (d) => {
    const real = norma(d);
    if (vistos.has(real)) return;
    vistos.add(real);
    let ents;
    try { ents = readdirSync(d, { withFileTypes: true }); } catch { out.push([d, 'ilegivel']); return; }
    for (const e of ents) {
      const p = join(d, e.name);
      if (pula.includes(p)) continue;
      if (e.isSymbolicLink()) {
        let alvo;
        try { alvo = realpathSync(p); } catch { out.push([p, 'link-quebrado']); continue; }
        if (!dentro(alvo, raiz)) { out.push([p, `link:${readlinkSync(p)}`]); continue; }
      }
      let s;
      try { s = statSync(p); } catch { out.push([p, 'link-quebrado']); continue; }
      if (s.isDirectory()) anda(p);
      else out.push([p, meta(s)]);
    }
  };
  anda(dir);
  return out;
}

// Cache de plugins por pasta de versão: cache/<marketplace>/<plugin>/<versão> → `dir`, ou `orfa`
// quando a CLI a marcou com `.orphaned_at` (desinstalada, coletada depois).
function versoes(cache) {
  const out = [];
  const lista = (d) => { try { return readdirSync(d, { withFileTypes: true }).filter((e) => e.isDirectory()); } catch { return null; } };
  const mkts = lista(cache);
  if (mkts === null) return [[cache, existsSync(cache) ? 'ilegivel' : 'ausente']];
  for (const m of mkts) {
    for (const p of lista(join(cache, m.name)) || []) {
      for (const v of lista(join(cache, m.name, p.name)) || []) {
        const d = join(cache, m.name, p.name, v.name);
        out.push([d, existsSync(join(d, '.orphaned_at')) ? 'orfa' : 'dir']);
      }
    }
  }
  return out;
}

function lerJson(p, obrigatorio) {
  if (!existsSync(p)) return undefined;
  try { return JSON.parse(readFileSync(p, 'utf8')); } catch {
    if (obrigatorio) falha(`${p} ilegível ou JSON inválido (falha fechado)`);
    return undefined;
  }
}

const canon = (v) => JSON.stringify(v, (_, x) => (objeto(x)
  ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => cmp(a, b))) : x));

// installed_plugins.json no formato conhecido (version 2), como lista de entradas; ausente → null.
function instalados(HOME) {
  const ip = lerJson(join(HOME, '.claude', 'plugins', 'installed_plugins.json'), true);
  if (ip === undefined) return null;
  if (!objeto(ip) || ip.version !== 2 || !objeto(ip.plugins ?? {})) {
    falha('installed_plugins.json em formato não reconhecido (esperado version 2) (falha fechado)');
  }
  const out = [];
  for (const [id, ents] of Object.entries(ip.plugins ?? {})) {
    for (const e of [].concat(ents)) {
      if (!objeto(e)) falha(`installed_plugins.json: entrada inválida em ${limpa(id)} (falha fechado)`);
      out.push({ id, scope: e.scope ?? '-', projectPath: e.projectPath ?? '-', version: e.version ?? '-', sha: e.gitCommitSha ?? '-' });
    }
  }
  return { ip, out };
}

function foto(raiz, HOME) {
  for (const v of ['CLAUDE_CODE_PLUGIN_CACHE_DIR', 'CLAUDE_CONFIG_DIR']) {
    if (process.env[v]) falha(`${v} definido: a configuração fica fora das raízes da foto`);
  }
  const linhas = [];
  const add = (tipo, chave, valor) => linhas.push([tipo, limpa(chave), limpa(valor)].join('\t'));
  const claude = join(HOME, '.claude');
  const projClaude = join(raiz, '.claude');
  const sqlite = (p) => p.startsWith(projClaude + sep) && /-(shm|wal|journal)$/.test(p); // ruído

  const hooks = git(raiz, ['rev-parse', '--git-path', 'hooks']);
  const cfg = git(raiz, ['rev-parse', '--git-path', 'config']);
  const status = git(raiz, ['status', '--porcelain', '--ignored']);
  const worktrees = git(raiz, ['worktree', 'list', '--porcelain']);
  if (hooks === null || cfg === null || status === null || worktrees === null) {
    falha(`git falhou em ${raiz} (falha fechado)`);
  }

  // meta: só metadados.
  const raizesMeta = [
    [join(claude, 'skills'), [join(claude, 'skills', 'synced')]],
    [join(claude, 'agents'), []], [join(claude, 'commands'), []], [join(claude, 'hooks'), []],
    [join(claude, 'CLAUDE.md'), []],
    [projClaude, [join(projClaude, 'feature-00c-state'), join(projClaude, 'enforcement-log.jsonl')]],
    [resolve(raiz, hooks.trim()), []],
    [join(HOME, '.ssh'), []], [join(HOME, '.config', 'gh'), []], [join(HOME, '.local', 'bin'), []],
    [join(HOME, '.gitconfig'), []], [join(HOME, '.bashrc'), []], [join(HOME, '.profile'), []],
  ];
  for (const [r, pula] of raizesMeta) {
    let s;
    try { s = statSync(r); } catch { add('meta', r, existsSync(r) ? 'link-quebrado' : 'ausente'); continue; }
    const itens = s.isDirectory() ? arquivos(r, pula) : [[r, `${s.size} ${s.mtimeMs} ${s.ctimeMs} ${s.ino}`]];
    for (const [f, v] of itens) if (!sqlite(f)) add('meta', f, v);
  }
  for (const [d, v] of versoes(join(claude, 'plugins', 'cache'))) add('meta', d, v);

  // hash: conteúdo, só o sha256 vai à saída.
  for (const f of [join(claude, 'settings.json'), join(projClaude, 'settings.json'),
    join(projClaude, 'settings.local.json'), resolve(raiz, cfg.trim())]) {
    add('hash', f, existsSync(f) ? sha(readFileSync(f)) : 'ausente');
  }
  let cron = 'ausente';
  try { cron = sha(execFileSync('crontab', ['-l'], { stdio: ['ignore', 'pipe', 'ignore'] })); } catch { /* sem crontab */ }
  add('hash', 'crontab -l', cron);
  const cj = lerJson(join(HOME, '.claude.json'), false);
  add('hash', '~/.claude.json#mcpServers', objeto(cj) && cj.mcpServers !== undefined ? sha(canon(cj.mcpServers)) : 'ausente');
  const vazio = (v) => v === undefined || v === null || (objeto(v) && !Object.keys(v).length);
  const locais = objeto(cj) && objeto(cj.projects)
    ? Object.fromEntries(Object.entries(cj.projects).filter(([, p]) => objeto(p) && !vazio(p.mcpServers))
      .map(([k, p]) => [k, p.mcpServers])) : {};
  add('hash', '~/.claude.json#projects.mcpServers', sha(canon(locais)));

  // plugin (só escopo user e o projeto da raiz) e enabled.
  const inst = instalados(HOME);
  if (inst === null) add('plugin', '-', 'ausente');
  else {
    for (const e of inst.out) {
      if (e.scope === 'user' || norma(e.projectPath) === raiz) add('plugin', `${e.id}|${e.scope}|${e.projectPath}`, `${e.version} ${e.sha}`);
    }
    if (inst.ip.enabledPlugins !== undefined) add('enabled', 'installed_plugins.json', canon(inst.ip.enabledPlugins));
  }
  for (const f of [join(claude, 'settings.json'), join(projClaude, 'settings.json'), join(projClaude, 'settings.local.json')]) {
    const s = lerJson(f, false);
    if (objeto(s) && s.enabledPlugins !== undefined) add('enabled', f, canon(s.enabledPlugins));
  }

  // marketplace e catalogo. URL ou caminho só como hash (pode trazer credencial).
  const km = lerJson(join(claude, 'plugins', 'known_marketplaces.json'), false);
  for (const [nome, m] of Object.entries(objeto(km) ? km : {})) {
    const src = objeto(m) && objeto(m.source) ? m.source : {};
    const outra = src.url ?? src.path;
    add('marketplace', nome, src.repo ?? (outra ? `sha256:${sha(String(outra))}` : '-'));
    if (objeto(m) && m.installLocation) add('catalogo', nome, (git(m.installLocation, ['rev-parse', 'HEAD']) || 'ausente').trim());
  }

  // git.
  for (const l of status.split('\n')) if (l && !sqlite(join(raiz, l.slice(3)))) add('git', 'status', l);
  for (const bloco of worktrees.split('\n\n')) {
    // Sem HEAD: commit em worktree paralela não é desvio; criar ou remover worktree é.
    const campos = bloco.split('\n').filter((c) => c && !c.startsWith('HEAD '));
    if (campos.length) add('git', 'worktree', campos.join(' '));
  }

  return linhas.sort(cmp).join('\n') + '\n';
}

const EVENTOS = new Set(['base', 'rodada', 'worktree', 'install', 'uninstall', 'enable', 'disable', 'desvio', 'gate0']);
const ABRE = { install: 'install', enable: 'enable' };
const FECHA = { uninstall: 'install', disable: 'enable' };

// Lê e valida o log inteiro; qualquer linha mal formada falha fechado (saída 2).
function lerLog(log) {
  let txt;
  try { txt = readFileSync(log, 'utf8'); } catch { falha(`log ausente ou ilegível: ${log}`, 2); }
  const linhas = [];
  let base = null;
  let gate0 = false;
  let anterior = null;
  for (const bruta of txt.split('\n')) {
    const l = bruta.replace(/\r$/, '').normalize('NFC');
    if (!l) continue;
    if (l.startsWith('\t')) { // só item de rodada: quatro TABs e "+ " ou "- ", logo depois de uma rodada
      if (anterior !== 'rodada' || !/^\t{4}[+-] /.test(l)) falha(`linha mal formada (falha fechado): ${limpa(l)}`, 2);
      continue;
    }
    const c = l.split('\t');
    if (c.length < 6 || !EVENTOS.has(c[4])) falha(`linha mal formada (falha fechado): ${limpa(l)}`, 2);
    anterior = c[4];
    if ((ABRE[c[4]] || FECHA[c[4]]) && (c.length !== 11 || !['permanente', 'temporária'].includes(c[9]))) {
      falha(`linha de ${c[4]} mal formada (11 colunas TAB, classe permanente|temporária): ${limpa(l)}`, 2);
    }
    if (c[4] === 'base' && !base) base = c;
    if (c[4] === 'gate0' && /^OK\b/.test(c[5])) gate0 = true;
    linhas.push(c);
  }
  if (!base) falha(`log sem evento base (falha fechado): ${log}`, 2);
  return { linhas, base, gate0 };
}

// install/enable temporários ainda sem uninstall/disable com a mesma tripla id, escopo, projeto.
// Desfazer com classe diferente da abertura, ou a mesma tripla aberta como permanente e
// temporária, falha fechado (saída 2).
function abertosDe(linhas) {
  const abertos = [];
  const classe = new Map();
  for (const c of linhas) {
    const tipo = ABRE[c[4]] ?? FECHA[c[4]];
    if (!tipo) continue;
    const chave = `${tipo}|${c[5]}|${c[6]}|${c[7]}`;
    if (classe.has(chave) && classe.get(chave) !== c[9]) falha(`classe divergente para ${limpa(chave)} (falha fechado)`, 2);
    classe.set(chave, c[9]);
    if (ABRE[c[4]]) { if (c[9] === 'temporária') abertos.push({ chave, l: c.join('\t') }); }
    else {
      const i = abertos.map((a) => a.chave).lastIndexOf(chave);
      if (i >= 0) abertos.splice(i, 1); // sem abertura anterior: ignorado
    }
  }
  return abertos;
}

function pendentes(log) {
  const abertos = abertosDe(lerLog(log).linhas);
  for (const a of abertos) process.stdout.write(a.l + '\n');
  process.exit(abertos.length ? 1 : 0);
}

// Gate da Fase 11, rodado dentro da worktree da frente (decisão do owner: só o que a frente toca).
// Compara: nenhum plugin com projectPath numa raiz da frente (worktree atual e projetos do log, fora
// a raiz do evento base), salvo a tripla permanente; entradas dos ids temporários em enabledPlugins
// (working tree e HEAD das raízes da frente) iguais às da base; marketplaces temporários iguais aos
// da base; nenhuma pasta de versão de id temporário sem a marca de órfã e sem plugin instalado.
function gate(frente, HOME) {
  const aqui = git(process.cwd(), ['rev-parse', '--show-toplevel']);
  const ramo = git(process.cwd(), ['branch', '--show-current']);
  if (aqui === null || ramo === null) falha('gate fora de repositório git: rode dentro da worktree da frente', 2);
  const b = ramo.trim();
  if (b !== frente && !b.endsWith(`/${frente}`)) falha(`branch atual (${limpa(b)}) não é da frente ${frente} (falha fechado)`, 2);

  const dir = join(HOME, '.claude', 'cockpit');
  const { linhas, base, gate0 } = lerLog(join(dir, `historico-${frente}.log`));
  if (!gate0) falha('log sem evento gate0 com OK (falha fechado)', 2);
  const wt = norma(aqui.trim());
  const doLog = new Set(linhas.filter((c) => c[4] === 'worktree' || ABRE[c[4]] || FECHA[c[4]])
    .flatMap((c) => [norma(c[2]), ...(ABRE[c[4]] || FECHA[c[4]] ? [norma(c[7])] : [])]));
  if (!doLog.has(wt)) falha(`a worktree atual não aparece no log da frente (evento worktree ausente?) (falha fechado)`, 2);

  const abertos = abertosDe(linhas);
  if (abertos.length) {
    for (const a of abertos) process.stdout.write(`pendente\t${a.l}\n`);
    process.exit(1);
  }
  let baseTxt;
  try { baseTxt = readFileSync(join(dir, `historico-${frente}.base`), 'utf8'); } catch { falha('.base ausente ou ilegível (falha fechado)', 2); }
  if (!baseTxt.trim()) falha('.base vazio (falha fechado)', 2);

  const raiz = norma(base[2]);
  const permTripla = new Set();
  const permId = new Set();
  const temp = new Set();
  const raizes = new Set([wt]);
  for (const c of linhas) {
    if (!ABRE[c[4]] && !FECHA[c[4]]) continue;
    if (c[7] !== '-') raizes.add(norma(c[7]));
    if (!ABRE[c[4]]) continue; // a classe vem da abertura
    if (c[9] === 'permanente') { permId.add(c[5]); permTripla.add(`${c[5]}|${norma(c[7])}`); } else temp.add(c[5]);
  }
  for (const id of permId) temp.delete(id);
  raizes.delete(raiz);

  // enabledPlugins por arquivo: rótulo -> mapa. Base e foto atual cobrem usuário, installed_plugins
  // e as settings da raiz principal.
  const usuario = join(HOME, '.claude', 'settings.json');
  const rotulo = (k) => (k === 'installed_plugins.json' ? k : k === usuario ? 'usuario' : `raiz:${basename(k)}`);
  const enabledDe = (txt) => {
    const m = new Map();
    for (const l of txt.split('\n')) {
      const [tipo, chave = '', valor = ''] = l.split('\t');
      if (tipo !== 'enabled') continue;
      let obj;
      try { obj = JSON.parse(valor); } catch { continue; }
      if (objeto(obj)) m.set(rotulo(chave), obj);
    }
    return m;
  };
  const baseEn = enabledDe(baseTxt);
  const habilitados = (obj) => new Set(Object.entries(obj ?? {}).filter(([, v]) => v === true).map(([k]) => k));
  const settingsDe = (r) => {
    const mapa = (v) => (objeto(v) && objeto(v.enabledPlugins) ? v.enabledPlugins : {});
    const commitado = git(r, ['show', 'HEAD:.claude/settings.json']);
    let head = null;
    try { head = commitado === null ? null : mapa(JSON.parse(commitado)); } catch { falha(`HEAD:.claude/settings.json inválido em ${r} (falha fechado)`, 2); }
    return { head, working: mapa(lerJson(join(r, '.claude', 'settings.json'), false)), local: mapa(lerJson(join(r, '.claude', 'settings.local.json'), false)) };
  };
  const doLogIds = new Set([...temp, ...permId]);
  const autoLocal = new Set([...habilitados(baseEn.get('usuario')), ...habilitados(baseEn.get('raiz:settings.local.json'))]);

  const dif = [];
  // 1. presença: nada instalado nas raízes da frente, salvo a tripla permanente e o registro
  // automático do Claude Code na 1ª sessão da worktree (id fora do log; entrada local de id
  // habilitado no usuário ou na settings local da raiz; entrada project de id habilitado no
  // .claude/settings.json commitado da própria worktree).
  const inst = instalados(HOME);
  const todos = inst === null ? [] : inst.out;
  const settings = new Map([...raizes].map((r) => [r, settingsDe(r)]));
  for (const e of todos) {
    const p = norma(e.projectPath);
    if (!raizes.has(p) || permTripla.has(`${e.id}|${p}`)) continue;
    const auto = !doLogIds.has(e.id) && ((e.scope === 'local' && autoLocal.has(e.id))
      || (e.scope === 'project' && habilitados(settings.get(p).head).has(e.id)));
    if (!auto) dif.push(`+ plugin\t${e.id}|${e.scope}|${p}`);
  }

  // 2. enabledPlugins. Usuário, installed_plugins e raiz principal: só ids temporários (outras
  // sessões mexem nelas). Raízes da frente: settings commitada inteira (salvo permanentes) contra a
  // da raiz na base; working tree e local, ids temporários. `false` só conta como ausente quando a
  // base não tem a chave, e nunca no que foi commitado.
  const mostra = (v) => (v === undefined ? 'ausente' : JSON.stringify(v));
  const compara = (rot, b, c, ids, leniente) => {
    for (const id of ids) {
      const bv = (b ?? {})[id];
      const cv = (c ?? {})[id];
      if (JSON.stringify(bv) === JSON.stringify(cv) || (leniente && bv === undefined && cv === false)) continue;
      dif.push(`± enabled\t${rot}\t${id}: ${mostra(bv)} -> ${mostra(cv)}`);
    }
  };
  const atual = foto(raiz, HOME);
  const atualEn = enabledDe(atual);
  for (const rot of new Set([...baseEn.keys(), ...atualEn.keys()])) compara(rot, baseEn.get(rot), atualEn.get(rot), temp, true);
  const baseProj = baseEn.get('raiz:settings.json') ?? {};
  for (const [r, st] of settings) {
    if (st.head !== null) {
      const ids = new Set([...Object.keys(baseProj), ...Object.keys(st.head), ...Object.keys(st.working)].filter((id) => !permId.has(id)));
      compara(`${r}:HEAD:.claude/settings.json`, baseProj, st.head, ids, false);
      compara(`${r}:.claude/settings.json`, baseProj, st.working, ids, true);
    } else compara(`${r}:.claude/settings.json`, {}, st.working, temp, true);
    compara(`${r}:.claude/settings.local.json`, {}, st.local, temp, true);
  }

  // marketplaces temporários: iguais à base.
  const mkts = (txt) => new Set(txt.split('\n').filter((l) => { const [t, c] = l.split('\t'); return t === 'marketplace' && temp.has(`marketplace:${c}`); }));
  const mb = mkts(baseTxt);
  const ma = mkts(atual);
  for (const l of mb) if (!ma.has(l)) dif.push(`- ${l}`);
  for (const l of ma) if (!mb.has(l)) dif.push(`+ ${l}`);

  // 3. cache: pasta de versão de id temporário sem marca de órfã e sem plugin instalado é sobra
  // (salvo se já era assim na base).
  const cache = join(HOME, '.claude', 'plugins', 'cache');
  const ids = new Set(todos.map((e) => e.id));
  const naBase = new Set(baseTxt.split('\n').filter((l) => l.endsWith('\tdir')).map((l) => l.split('\t')[1]));
  for (const [d, v] of versoes(cache)) {
    const [mkt, plugin] = d.slice(cache.length + 1).split(sep);
    const id = `${plugin}@${mkt}`;
    if (temp.has(id) && v === 'dir' && !ids.has(id) && !naBase.has(d)) dif.push(`+ cache\t${d}\tsobra sem plugin instalado`);
  }

  dif.sort(cmp);
  for (const l of dif) process.stdout.write(l + '\n');
  process.exit(dif.length ? 1 : 0);
}

const validaFrente = (f) => { if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(f)) falha(`frente inválida: ${limpa(f)}`, 2); };
const casa = () => {
  const h = homedir();
  if (!h || !isAbsolute(h)) falha('HOME vazio ou relativo (falha fechado)');
  return h;
};

const [cmd, ...args] = process.argv.slice(2);
if (cmd === 'foto') {
  const HOME = casa();
  let raiz = process.cwd();
  if (args.length) {
    if (args[0] !== '--raiz' || args.length !== 2) falha('uso: foto [--raiz <dir>]', 64);
    raiz = resolve(args[1]);
  }
  const topo = git(raiz, ['rev-parse', '--show-toplevel']);
  if (topo === null) falha(`--raiz não é repositório git (ou o git a recusou): ${raiz}`);
  process.stdout.write(foto(norma(topo.trim()), HOME));
} else if (cmd === 'pendentes' && args.length === 1) pendentes(args[0]);
else if (cmd === 'gate' && args.length === 1) { validaFrente(args[0]); gate(args[0], casa()); }
else if (cmd === 'frente' && args.length === 1) validaFrente(args[0]);
else falha('uso: foto [--raiz <dir>] | pendentes <log> | gate <frente> | frente <nome>', 64);
