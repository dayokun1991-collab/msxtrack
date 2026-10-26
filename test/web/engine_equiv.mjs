// Checks that the JavaScript engine (web/js/engine.js) writes the same PSG
// registers as the Z80 tracker, frame by frame.
// usage: node engine_equiv.mjs song.mtk reference.log
// reference.log(.gz): one line per frame, 14 register values recorded from
// the Z80 tracker in openMSX.
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { Song } from '../../web/js/mtk.js';
import { Engine } from '../../web/js/engine.js';

const [, , mtkPath, logPath] = process.argv;
const raw = readFileSync(logPath);
const ref = (logPath.endsWith('.gz') ? gunzipSync(raw) : raw).toString('utf8').trim().split('\n').map((l) => l.trim().split(/\s+/).map(Number));
const song = Song.fromMTK(readFileSync(mtkPath));

function render(n) {
  const e = new Engine(song.data);
  e.playStart(1, 0, 0);
  const out = [];
  let r13 = 0;
  for (let i = 0; i < n; i++) {
    if (e.frame()) r13 = e.reg[13];
    const r = Array.from(e.reg); r[13] = r13;
    out.push(r);
  }
  return out;
}
const js = render(ref.length);
// the log starts a few frames before playback: find the alignment
const silent = (r) => r[8] === 0 && r[9] === 0 && r[10] === 0;
const start = ref.findIndex((r) => !silent(r));
const jsStart = js.findIndex((r) => !silent(r));
let compared = 0, bad = [];
for (let i = 0; start + i < ref.length && jsStart + i < js.length; i++) {
  const a = ref[start + i], b = js[jsStart + i];
  compared++;
  // R6, R11-R13 may hold values left over from before playback started
  const regs = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10];
  if (a[6] !== b[6] && (a[7] & 0x38) !== 0x38) regs.push(6);
  if (a[8] === 16 || a[9] === 16 || a[10] === 16) regs.push(11, 12, 13);
  for (const k of regs) if (a[k] !== b[k]) { bad.push(`frame ${i} R${k}: z80=${a[k]} js=${b[k]}`); break; }
}
console.log(`${mtkPath}: ${compared} frames compared, ${bad.length} differ`);
bad.slice(0, 8).forEach((s) => console.log('  ' + s));
process.exit(bad.length ? 1 : 0);
