#!/usr/bin/env node
// Testes de `historico.mjs plugin` (contracts/historico-plugin.md). Fixtures em diretório temporário,
// HOME apontado para ele. Sem dependência: node historico.test.mjs
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, cpSync, mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aux = join(dirname(fileURLToPath(import.meta.url)), 'historico.mjs');
const SHA = 'a'.repeat(40);
const agente = (name, tools = 'Read, Grep') =>
  `---\nname: ${name}\ndescription: x\n${tools === null ? '' : `tools: ${tools}\n`}---\ncorpo\n`;

// installed_plugins.json com uma única entrada para `p`.
const registra = (home, p) => writeFileSync(join(home, '.claude', 'plugins', 'installed_plugins.json'),
  JSON.stringify({ version: 2, plugins: { 'p@mkt': [{ scope: 'user', installPath: p, version: '1.0.0', gitCommitSha: SHA }] } }));

// Monta HOME + plugin em cache/mkt/p/1.0.0; `mexe(dir, home)` altera o fixture.
function monta({ pj = {}, mexe = () => {} } = {}) {
  const home = mkdtempSync(join(tmpdir(), 'hist-plugin-'));
  const dir = join(home, '.claude', 'plugins', 'cache', 'mkt', 'p', '1.0.0');
  mkdirSync(join(dir, '.claude-plugin'), { recursive: true });
  mkdirSync(join(dir, 'agents'));
  writeFileSync(join(dir, '.claude-plugin', 'plugin.json'), JSON.stringify({ name: 'p', agents: ['./agents/a.md'], ...pj }));
  writeFileSync(join(dir, 'README.md'), 'r');
  writeFileSync(join(dir, 'LICENSE'), 'l');
  writeFileSync(join(dir, 'agents', 'a.md'), agente('a'));
  mexe(dir, home);
  registra(home, dir);
  return { home, dir };
}
const roda = (home, p) => {
  const r = spawnSync('node', [aux, 'plugin', p], { env: { ...process.env, HOME: home }, encoding: 'utf8' });
  return { code: r.status, json: r.stdout.trim() ? JSON.parse(r.stdout) : null, out: r.stdout, err: r.stderr };
};
const caso = (nome, opts, fn, caminho) => {
  const { home, dir } = monta(opts);
  try { fn(roda(home, caminho ? caminho(home, dir) : dir), dir, home); console.log(`ok - ${nome}`); }
  finally { rmSync(home, { recursive: true, force: true }); }
};
const reprova = (r, n = 1) => { assert.equal(r.code, 1); assert.equal(r.json.veredito, 'reprovado'); assert.equal(r.json.motivos.length, n, r.out); };
const falhaFechada = (r, motivo) => { assert.notEqual(r.code, 0); assert.equal(r.out, ''); if (motivo) assert.match(r.err, motivo); };

caso('limpo aprova', {}, (r) => {
  assert.equal(r.code, 0); assert.equal(r.json.veredito, 'ok'); assert.deepEqual(r.json.motivos, []);
  assert.equal(r.json.sha, SHA); assert.deepEqual(r.json.deny, []); assert.equal(r.json.plugin, 'p');
});
caso('.in_use numerico e .orphaned_at aprovam', { mexe: (d) => { mkdirSync(join(d, '.in_use')); writeFileSync(join(d, '.in_use', '12345'), ''); writeFileSync(join(d, '.orphaned_at'), '1'); } },
  (r) => assert.equal(r.code, 0));
caso('.in_use nome invalido', { mexe: (d) => { mkdirSync(join(d, '.in_use')); writeFileSync(join(d, '.in_use', 'abc'), ''); } }, (r) => reprova(r));
caso('.in_use subdiretorio', { mexe: (d) => { mkdirSync(join(d, '.in_use', 'sub'), { recursive: true }); } }, (r) => reprova(r));
caso('.in_use symlink', { mexe: (d) => { mkdirSync(join(d, '.in_use')); symlinkSync(join(d, 'README.md'), join(d, '.in_use', '1')); } }, (r) => reprova(r));
caso('.md na raiz com chave extra', { mexe: (d) => writeFileSync(join(d, 'b.md'), '---\nname: b\nfoo: 1\ntools: Read\n---\n') }, (r) => reprova(r));
caso('.md na raiz com name colidente', { mexe: (d) => writeFileSync(join(d, 'b.md'), agente('a')) }, (r) => reprova(r));
caso('.md na raiz valido entra no deny se proibido', { mexe: (d) => writeFileSync(join(d, 'b.md'), agente('b', 'Agent')) },
  (r) => { assert.equal(r.code, 0); assert.deepEqual(r.json.deny, ['Agent(p:b)', 'Agent(subagent_type:p:b)']); });
caso('hooks/', { mexe: (d) => mkdirSync(join(d, 'hooks')) }, (r) => reprova(r));
caso('.mcp.json', { mexe: (d) => writeFileSync(join(d, '.mcp.json'), '{}') }, (r) => reprova(r));
caso('executavel', { mexe: (d) => { writeFileSync(join(d, 'x.sh'), '#!/bin/sh'); chmodSync(join(d, 'x.sh'), 0o755); } }, (r) => reprova(r));
caso('chave hooks no plugin.json', { pj: { hooks: {} } }, (r) => reprova(r));
caso('WebFetch e sem tools vao ao deny', {
  pj: { agents: ['./agents/a.md', './agents/w.md', './agents/n.md', './agents/m.md'] },
  mexe: (d) => {
    writeFileSync(join(d, 'agents', 'w.md'), agente('w', 'Read, WebFetch'));
    writeFileSync(join(d, 'agents', 'n.md'), agente('n', null));
    writeFileSync(join(d, 'agents', 'm.md'), agente('m', 'mcp__x__y'));
  },
}, (r) => {
  assert.equal(r.code, 0);
  assert.deepEqual(r.json.deny, ['Agent(p:m)', 'Agent(p:n)', 'Agent(p:w)', 'Agent(subagent_type:p:m)', 'Agent(subagent_type:p:n)', 'Agent(subagent_type:p:w)']);
});
// Symlink e "fora do cache" ficam registrados no installed_plugins: sem a checagem própria, o plugin
// passaria (o caminho tem entrada e conteúdo limpo).
{
  // (c): tools nulo, vazio, [] ou * equivale a sem linha; WebFetch(...) e WebSearch(...) casam pelo nome.
  const tools = { v: '', til: '~', nul: 'null', asp: '""', col: '[]', est: '*', wf: 'Read, WebFetch(domain:x.com)', ws: '[WebSearch(q)]' };
  const nomes = Object.keys(tools);
  caso('tools nulo, vazio, [], * e WebFetch(...)/WebSearch(...) vao ao deny', {
    pj: { agents: ['./agents/a.md', ...nomes.map((n) => `./agents/${n}.md`)] },
    mexe: (d) => { for (const n of nomes) writeFileSync(join(d, 'agents', `${n}.md`), agente(n, tools[n])); },
  }, (r) => {
    assert.equal(r.code, 0, r.out);
    assert.deepEqual(r.json.deny, nomes.flatMap((n) => [`Agent(p:${n})`, `Agent(subagent_type:p:${n})`]).sort());
  });
}
{
  // Formato fechado: YAML que um leitor de verdade lê de outro jeito (comentário, tag, âncora, alias,
  // escape, lista com comentário, mapa, lista em bloco) conta como proibido. `ok` é o controle.
  const tools = {
    com: '# herda tudo', wfc: 'Read, WebFetch # opcional', nulc: 'null # x', tnul: '!!null', tstr: '!!str WebFetch',
    esc: '"Read, Web\\x46etch"', agc: 'Read, Agent #x', lstc: '[Read, Task] # x', anc: '&x WebFetch', ali: '*x',
    map: '{}', blo: '\n  - Read\n  - Grep', est: 'Read*', vir: 'Read,',
    // escalar tipado do YAML, em qualquer caixa, solto ou na lista
    fal: 'false', tru: 'True', yes: 'YES', no: 'no', on: 'On', off: '[off]', lnul: '[null]', lNul: '[Null]',
    lfal: '[Read, false]', ltil: '[~]', ly: 'y', ln: '[Read, N]',
    // YAML inválido: colchete desbalanceado e `: ` dentro do item
    abre: '[Read', fecha: 'Read]', dois: 'Bash(git: x)',
  };
  // Controles que continuam liberados: `*` entre parênteses, nome que começa por escalar.
  const ok = { ok: 'Read, Bash(npm test)', nb: 'NotebookEdit', sk: 'Read, Skill', t1: 'Bash(npm run test:*)', t2: '[Bash(git:*)]', t3: 'Bash(*)' };
  const nomes = Object.keys(tools);
  caso('tools fora do formato fechado vai ao deny', {
    pj: { agents: ['./agents/a.md', './agents/sem.md', ...[...nomes, ...Object.keys(ok)].map((n) => `./agents/${n}.md`)] },
    mexe: (d) => {
      for (const [n, t] of Object.entries({ ...tools, ...ok })) writeFileSync(join(d, 'agents', `${n}.md`), agente(n, t));
      writeFileSync(join(d, 'agents', 'sem.md'), '---\nname: sem\ndescription: x\ntools:Read\n---\n'); // sem espaço: não é chave em YAML
    },
  }, (r) => {
    assert.equal(r.code, 0, r.out);
    assert.deepEqual(r.json.deny, [...nomes, 'sem'].flatMap((n) => [`Agent(p:${n})`, `Agent(subagent_type:p:${n})`]).sort());
  });
}
caso('chave:valor sem espaço fora do tools em agente citado', { mexe: (d) => writeFileSync(join(d, 'agents', 'a.md'), '---\nname: a\ndescription:x\ntools: Read\n---\n') },
  (r) => falhaFechada(r, /frontmatter/));
// Espaço Unicode (NBSP) como separador: o YAML não o lê como espaço (E4-2)
for (const l of ['tools: Read', 'name: a']) {
  const fm = l.startsWith('name') ? `---\n${l}\ndescription: x\ntools: Read\n---\n` : `---\nname: a\ndescription: x\n${l}\n---\n`;
  caso(`NBSP depois de "${l.split(":")[0]}:" em agente citado`, { mexe: (d) => writeFileSync(join(d, 'agents', 'a.md'), fm) }, (r) => falhaFechada(r, /frontmatter/));
}
for (const it of ['./Skills/x.md', 'Commands/c.md']) {
  const dir = it.replace(/^\.\//, '').split('/')[0];
  caso(`${it} citado no array agents (maiúsculas)`, {
    pj: { agents: ['./agents/a.md', it] },
    mexe: (d) => { mkdirSync(join(d, dir)); writeFileSync(join(d, it), agente('s')); },
  }, (r) => { reprova(r); assert.match(r.json.motivos[0], /diretório proibido/); });
}
caso('chave duplicada em agente citado', { mexe: (d) => writeFileSync(join(d, 'agents', 'a.md'), '---\nname: a\ntools: Agent\ntools: Read\n---\n') },
  (r) => falhaFechada(r, /frontmatter/));
caso('chave duplicada em .md da raiz', { mexe: (d) => writeFileSync(join(d, 'b.md'), '---\nname: b\nname: c\ntools: Read\n---\n') }, (r) => reprova(r));
for (const dir of ['skills', 'commands', 'hooks', 'output-styles']) {
  caso(`${dir}/ citado no array agents`, {
    pj: { agents: ['./agents/a.md', `./${dir}/s.md`] },
    mexe: (d) => { mkdirSync(join(d, dir)); writeFileSync(join(d, dir, 's.md'), agente('s', 'Agent')); },
  }, (r) => { reprova(r); assert.match(r.json.motivos[0], new RegExp(`proibido: ${dir}/s\\.md`)); assert.deepEqual(r.json.deny, ['Agent(p:s)', 'Agent(subagent_type:p:s)']); });
}
caso('installPath symlink', {}, (r) => falhaFechada(r, /symlink/), (home, dir) => { const l = join(home, 'link'); symlinkSync(dir, l); registra(home, l); return l; });
caso('installPath fora do cache', {}, (r) => falhaFechada(r, /fora de/), (home, dir) => { const f = join(home, 'fora'); cpSync(dir, f, { recursive: true }); registra(home, f); return f; });
caso('installPath inexistente (ENOENT)', {}, (r) => falhaFechada(r), (home, dir) => `${dir}-nao`);
caso('item do array com ..', { pj: { agents: ['../x.md'] } }, (r) => falhaFechada(r));
caso('item do array absoluto', { pj: { agents: ['/etc/passwd'] } }, (r) => falhaFechada(r));
caso('array agents vazio', { pj: { agents: [] } }, (r) => falhaFechada(r));
caso('name de plugin invalido', { pj: { name: 'p)x' } }, (r) => falhaFechada(r));
{
  const { home, dir } = monta();
  try {
    const e = { scope: 'user', installPath: dir, version: '1', gitCommitSha: SHA };
    writeFileSync(join(home, '.claude', 'plugins', 'installed_plugins.json'), JSON.stringify({ version: 2, plugins: { 'p@mkt': [e, { ...e, scope: 'project' }] } }));
    falhaFechada(roda(home, dir));
    writeFileSync(join(home, '.claude', 'plugins', 'installed_plugins.json'), JSON.stringify({ version: 2, plugins: { 'p@mkt': [{ ...e, gitCommitSha: undefined }] } }));
    falhaFechada(roda(home, dir));
    console.log('ok - duplicata e sem sha');
  } finally { rmSync(home, { recursive: true, force: true }); }
}
