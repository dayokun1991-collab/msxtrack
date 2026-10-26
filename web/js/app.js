// MSXTRACK Web - the editor.
import {
  Song, noteName, NOTE_OFF, MAXPAT, ROWS, ROWSZ, ORDMAX, NINS, STEPS, clamp,
  I_LEN, I_LOOP, I_SPEED, I_SHAPE, I_EMODE, I_EPERL, I_EPERH,
} from './mtk.js';
import { FX, COL_HINTS, SHAPES, JAM_HINT } from './hints.js';
import { renderSong, toWav, toMp3 } from './export.js';

const $ = (id) => document.getElementById(id);
const hex = (v, n = 2) => v.toString(16).toUpperCase().padStart(n, '0');
const STORE_KEY = 'msxtrack-web-song';

// piano keys by physical position (works with any keyboard layout)
const PIANO = {
  KeyZ: 0, KeyS: 1, KeyX: 2, KeyD: 3, KeyC: 4, KeyV: 5, KeyG: 6, KeyB: 7, KeyH: 8, KeyN: 9, KeyJ: 10, KeyM: 11,
  KeyQ: 12, Digit2: 13, KeyW: 14, Digit3: 15, KeyE: 16, KeyR: 17, Digit5: 18, KeyT: 19, Digit6: 20,
  KeyY: 21, Digit7: 22, KeyU: 23, KeyI: 24, Digit9: 25, KeyO: 26, Digit0: 27, KeyP: 28,
};

// ---------------------------------------------------------------------------
// state
// ---------------------------------------------------------------------------
const app = {
  song: new Song(),
  ord: 0, row: 0, ch: 0, col: 0,
  octave: 4, ins: 1, step: 1, rec: true, follow: true, hz: 60,
  playing: 0, playOrd: -1, playRow: -1,
  mute: [false, false, false],
  undo: [], redo: [],
  saved: true,
  clipTrack: null, clipPattern: null, clipIns: null,
  insStep: [-1, -1, -1],
};

// ---------------------------------------------------------------------------
// audio
// ---------------------------------------------------------------------------
const audio = {
  ctx: null, node: null, ready: null, volume: 0.8,
  ensure() {
    if (this.ready) return this.ready;
    this.ready = (async () => {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (!Ctx || !('audioWorklet' in Ctx.prototype)) throw new Error('This browser cannot play the sound (no AudioWorklet).');
      this.ctx = new Ctx({ latencyHint: 'interactive' });
      await this.ctx.audioWorklet.addModule(new URL('./worklet.js', import.meta.url));
      this.node = new AudioWorkletNode(this.ctx, 'msxtrack', { numberOfInputs: 0, outputChannelCount: [2] });
      this.node.connect(this.ctx.destination);
      this.node.port.onmessage = (e) => onAudioMessage(e.data);
      this.send({ type: 'song', data: app.song.data });
      this.send({ type: 'hz', hz: app.hz });
      this.send({ type: 'volume', volume: this.volume });
      this.send({ type: 'mute', mute: app.mute });
    })();
    this.ready.catch((err) => { showStatus(err.message); this.ready = null; });
    return this.ready;
  },
  send(msg) { if (this.node) this.node.port.postMessage(msg); },
  async cmd(msg) {
    await this.ensure();
    if (this.ctx.state !== 'running') await this.ctx.resume();
    this.send(msg);
  },
};

function onAudioMessage(m) {
  if (m.type === 'pos') {
    app.playing = m.playing;
    app.playOrd = m.playing ? m.ord : -1;
    app.playRow = m.playing ? m.row : -1;
    if (m.playing && app.follow) {
      if (app.ord !== m.ord) { app.ord = m.ord; renderAll(); }
      app.row = m.row;
    }
    updatePlayback();
  } else if (m.type === 'levels') {
    document.querySelectorAll('.chan-head meter').forEach((el, i) => { el.value = m.ch[i].vol; });
    const st = m.ch.findIndex((c) => c.active && c.ins === app.ins);
    const step = st >= 0 ? m.ch[st].step : -1;
    if (step !== app.shownStep) { app.shownStep = step; markInsStep(step); }
  }
}

function songChanged() {
  audio.send({ type: 'song', data: app.song.data });
  app.saved = false;
  autosave();
}

// all edits go through here: undo snapshot, then redraw and sync
function edit(fn, what = 'all') {
  const before = app.song.data.slice();
  if (fn() === false) return;
  app.undo.push(before);
  if (app.undo.length > 200) app.undo.shift();
  app.redo.length = 0;
  songChanged();
  if (what === 'pattern') renderPattern();
  else renderAll();
}

function undoRedo(from, to, label) {
  if (!from.length) { showStatus(`Nothing to ${label}`); return; }
  to.push(app.song.data.slice());
  app.song.data.set(from.pop());
  songChanged();
  clampCursor();
  renderAll();
  showStatus(label === 'undo' ? 'Undone' : 'Redone');
}

// ---------------------------------------------------------------------------
// pattern editor
// ---------------------------------------------------------------------------
const grid = $('grid');
const curPat = () => app.song.order(app.ord);

function cellHTML(c) {
  const n = c.note ? `<span class="f n" data-col="0">${noteName(c.note)}</span>` : '<span class="f e" data-col="0">---</span>';
  const i = c.ins ? `<span class="f i" data-col="1">${hex(c.ins, 1)}</span>` : '<span class="f e" data-col="1">.</span>';
  const v = c.vol != null ? `<span class="f v" data-col="2">${hex(c.vol, 1)}</span>` : '<span class="f e" data-col="2">.</span>';
  let x;
  if (c.fx != null) {
    const p = hex(c.param);
    x = `<span class="f x" data-col="3">${hex(c.fx, 1)}</span><span class="f x" data-col="4">${p[0]}</span><span class="f x" data-col="5">${p[1]}</span>`;
  } else x = '<span class="f e" data-col="3">.</span><span class="f e" data-col="4">.</span><span class="f e" data-col="5">.</span>';
  return `${n} ${i}${v} <span>${x}</span>`;
}

function rowHTML(r) {
  const p = curPat();
  let h = `<span class="rn">${hex(r)}</span>`;
  for (let ch = 0; ch < 3; ch++) h += `<span class="cell" data-ch="${ch}">${cellHTML(app.song.getCell(p, r, ch))}</span>`;
  return h;
}

function renderPattern() {
  const len = app.song.patlen;
  let h = '';
  for (let r = 0; r < len; r++) h += `<div class="prow${r % 4 === 0 ? ' beat' : ''}" data-row="${r}">${rowHTML(r)}</div>`;
  grid.innerHTML = h;
  $('pat-label').textContent = `${hex(curPat())} · position ${hex(app.ord)}`;
  updateCursor(false);
  updatePlayback();
}

function renderRow(r) {
  const el = grid.querySelector(`.prow[data-row="${r}"]`);
  if (el) el.innerHTML = rowHTML(r);
}

function updateCursor(scroll = true) {
  grid.querySelectorAll('.prow.cur').forEach((e) => e.classList.remove('cur'));
  grid.querySelectorAll('.f.cur').forEach((e) => e.classList.remove('cur'));
  const row = grid.querySelector(`.prow[data-row="${app.row}"]`);
  if (row) {
    row.classList.add('cur');
    const f = row.querySelector(`.cell[data-ch="${app.ch}"] .f[data-col="${app.col}"]`);
    if (f) f.classList.add('cur');
    if (scroll) scrollToRow(row);
  }
  updateHint();
}

function scrollToRow(row) {
  const top = row.offsetTop - grid.clientHeight / 2 + row.offsetHeight / 2;
  grid.scrollTop = Math.max(0, top);
}

function updatePlayback() {
  grid.querySelectorAll('.prow.play').forEach((e) => e.classList.remove('play'));
  if (app.playing && app.playOrd === app.ord) {
    const row = grid.querySelector(`.prow[data-row="${app.playRow}"]`);
    if (row) row.classList.add('play');
  }
  if (app.playing && app.follow) updateCursor(true);
  $('pos').textContent = app.playing
    ? `Pos ${hex(app.playOrd)} · Row ${hex(app.playRow)}` : `Pos ${hex(app.ord)} · Row ${hex(app.row)}`;
  document.querySelectorAll('#orders button').forEach((b, i) => b.classList.toggle('playing', !!app.playing && i === app.playOrd));
}

function updateHint() {
  let h;
  if (app.col === 0) h = app.rec ? COL_HINTS[0] : JAM_HINT;
  else if (app.col < 3) h = COL_HINTS[app.col];
  else {
    const c = app.song.getCell(curPat(), app.row, app.ch);
    if (c.fx != null) {
      const [code, name, desc] = FX[c.fx];
      h = `<b>${code} ${name}</b> — ${desc}. Here: ${hex(c.fx, 1)}${hex(c.param)}.`;
    } else h = COL_HINTS[3];
  }
  $('hint').innerHTML = h;
}

function clampCursor() {
  app.ord = clamp(app.ord, 0, app.song.length - 1);
  app.row = clamp(app.row, 0, app.song.patlen - 1);
}

function moveRow(d) {
  const len = app.song.patlen;
  app.row = ((app.row + d) % len + len) % len;
  updateCursor();
}

function advance() { if (app.step) moveRow(app.step); else updateCursor(); }

function setCell(fn) {
  const p = curPat(), r = app.row, ch = app.ch;
  edit(() => {
    const c = app.song.getCell(p, r, ch);
    if (fn(c) === false) return false;
    app.song.setCell(p, r, ch, c);
  }, 'none');
  renderRow(r);
}

function enterNote(note) {
  if (!app.rec) return;
  setCell((c) => {
    c.note = note;
    if (note !== NOTE_OFF && app.ins) c.ins = app.ins;
  });
  advance();
}

function enterHex(d) {
  const col = app.col;
  setCell((c) => {
    if (col === 1) { c.ins = d; if (d) setIns(d, false); }
    else if (col === 2) c.vol = d;
    else {
      if (c.fx == null) { c.fx = 0; c.param = 0; }
      if (col === 3) c.fx = d;
      else if (col === 4) c.param = (c.param & 15) | (d << 4);
      else c.param = (c.param & 0xf0) | d;
    }
  });
  if (col === 3 || col === 4) { app.col++; updateCursor(); }
  else { if (col === 5) app.col = 3; advance(); }
}

function clearField() {
  const col = app.col;
  setCell((c) => {
    if (col === 0) { c.note = 0; c.ins = 0; c.vol = null; }
    else if (col === 1) c.ins = 0;
    else if (col === 2) c.vol = null;
    else { c.fx = null; c.param = 0; }
  });
  if (col >= 3) app.col = 3;
  advance();
}

function shiftTrack(dir) {   // dir -1: delete row (pull up), +1: insert row
  const p = curPat(), ch = app.ch, len = app.song.patlen, r0 = app.row;
  edit(() => {
    const s = app.song;
    if (dir < 0) {
      for (let r = r0; r < len - 1; r++) s.setCell(p, r, ch, s.getCell(p, r + 1, ch));
      s.setCell(p, len - 1, ch, { note: 0, ins: 0, vol: null, fx: null, param: 0 });
    } else {
      for (let r = len - 1; r > r0; r--) s.setCell(p, r, ch, s.getCell(p, r - 1, ch));
      s.setCell(p, r0, ch, { note: 0, ins: 0, vol: null, fx: null, param: 0 });
    }
  }, 'pattern');
}

function trackCells(p, ch) { return Array.from({ length: ROWS }, (_, r) => app.song.getCell(p, r, ch)); }

function copy(whole, cut) {
  const p = curPat();
  if (whole) app.clipPattern = app.song.data.slice(app.song.cellOffset(p, 0, 0), app.song.cellOffset(p, 0, 0) + ROWS * ROWSZ);
  else app.clipTrack = trackCells(p, app.ch);
  if (cut) {
    edit(() => {
      if (whole) app.song.data.fill(0, app.song.cellOffset(p, 0, 0), app.song.cellOffset(p, 0, 0) + ROWS * ROWSZ);
      else for (let r = 0; r < ROWS; r++) app.song.setCell(p, r, app.ch, { note: 0, ins: 0, vol: null, fx: null, param: 0 });
    }, 'pattern');
  }
  showStatus(`${whole ? 'Pattern' : 'Track'} ${cut ? 'cut' : 'copied'}`);
}

function paste(whole) {
  const p = curPat();
  if (whole ? !app.clipPattern : !app.clipTrack) { showStatus('Nothing copied yet'); return; }
  edit(() => {
    if (whole) app.song.data.set(app.clipPattern, app.song.cellOffset(p, 0, 0));
    else app.clipTrack.forEach((c, r) => app.song.setCell(p, r, app.ch, c));
  }, 'pattern');
  showStatus('Pasted');
}

function transpose(semis) {
  const p = curPat(), ch = app.ch;
  edit(() => {
    for (let r = 0; r < ROWS; r++) {
      const c = app.song.getCell(p, r, ch);
      if (c.note && c.note < NOTE_OFF) { c.note = clamp(c.note + semis, 1, 96); app.song.setCell(p, r, ch, c); }
    }
  }, 'pattern');
  showStatus(`Transposed ${semis > 0 ? '+' : ''}${semis}`);
}

// ---- keyboard ----
const held = new Map();   // piano key code -> channel playing it

function noteFromCode(code) {
  if (!(code in PIANO)) return 0;
  const n = (app.octave - 1) * 12 + PIANO[code] + 1;
  return n >= 1 && n <= 96 ? n : 0;
}

async function jam(note, ch) {
  await audio.cmd({ type: 'jam', ch, note, iv: app.ins << 4, fl: 0, par: 0, cut: 0xff });
}

function jamOff(code) {
  if (!held.has(code)) return;
  const ch = held.get(code);
  held.delete(code);
  if (![...held.values()].includes(ch)) audio.send({ type: 'jamoff', ch });
}

function isTyping(el) {
  return el && (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA') && el.type !== 'range';
}

document.addEventListener('keydown', (e) => {
  if (document.querySelector('dialog[open]')) return;
  if (isTyping(e.target)) return;
  if (e.target.tagName === 'BUTTON' && (e.key === 'Enter' || e.key === ' ')) return;
  const inGrid = e.target === grid;
  const mod = e.ctrlKey || e.metaKey;
  const k = e.key;

  // global shortcuts
  if (mod && (k === 'z' || k === 'Z')) { e.preventDefault(); e.shiftKey ? undoRedo(app.redo, app.undo, 'redo') : undoRedo(app.undo, app.redo, 'undo'); return; }
  if (mod && (k === 'y' || k === 'Y')) { e.preventDefault(); undoRedo(app.redo, app.undo, 'redo'); return; }
  if (mod && (k === 's' || k === 'S')) { e.preventDefault(); saveMTK(); return; }
  if (k === 'Escape') { stop(); return; }
  if (k === ' ' && !mod) { e.preventDefault(); app.playing ? stop() : play(2); return; }
  if (k === 'Enter' && !mod) { e.preventDefault(); app.playing ? stop() : play(1, e.shiftKey); return; }
  if (!mod && !e.altKey) {
    if (k === '[') { setOctave(app.octave - 1); return; }
    if (k === ']') { setOctave(app.octave + 1); return; }
    if (k === ',') { setIns(app.ins - 1); return; }
    if (k === '.') { setIns(app.ins + 1); return; }
    if (k === '-') { setStep(app.step - 1); return; }
    if (k === '=' || k === '+') { setStep(app.step + 1); return; }
    if (e.code === 'Backquote') { setRec(!app.rec); return; }
  }

  if (!inGrid) {
    // anywhere else, the piano keys preview the current instrument
    const n = !mod && !e.altKey && noteFromCode(e.code);
    if (n && !e.repeat) { held.set(e.code, 0); jam(n, 0); }
    return;
  }

  // pattern editor
  const len = app.song.patlen;
  if (mod && (k === 'c' || k === 'C')) { e.preventDefault(); copy(e.shiftKey, false); return; }
  if (mod && (k === 'x' || k === 'X')) { e.preventDefault(); copy(e.shiftKey, true); return; }
  if (mod && (k === 'v' || k === 'V')) { e.preventDefault(); paste(e.shiftKey); return; }
  if (e.altKey && (k === 'ArrowUp' || k === 'ArrowDown')) { e.preventDefault(); transpose((k === 'ArrowUp' ? 1 : -1) * (e.shiftKey ? 12 : 1)); return; }
  switch (k) {
    case 'ArrowUp': e.preventDefault(); moveRow(-1); return;
    case 'ArrowDown': e.preventDefault(); moveRow(1); return;
    case 'PageUp': e.preventDefault(); app.row = Math.max(0, app.row - 16); updateCursor(); return;
    case 'PageDown': e.preventDefault(); app.row = Math.min(len - 1, app.row + 16); updateCursor(); return;
    case 'Home': e.preventDefault(); app.row = 0; updateCursor(); return;
    case 'End': e.preventDefault(); app.row = len - 1; updateCursor(); return;
    case 'ArrowLeft':
      e.preventDefault();
      if (--app.col < 0) { app.col = 5; app.ch = (app.ch + 2) % 3; }
      updateCursor(); return;
    case 'ArrowRight':
      e.preventDefault();
      if (++app.col > 5) { app.col = 0; app.ch = (app.ch + 1) % 3; }
      updateCursor(); return;
    case 'Tab': e.preventDefault(); app.ch = (app.ch + (e.shiftKey ? 2 : 1)) % 3; app.col = 0; updateCursor(); return;
    case 'Delete': e.preventDefault(); clearField(); return;
    case 'Backspace': e.preventDefault(); shiftTrack(-1); return;
    case 'Insert': e.preventDefault(); shiftTrack(1); return;
  }
  if (mod || e.altKey) return;
  if (app.col === 0) {
    if (e.code === 'Digit1') { e.preventDefault(); if (app.rec) enterNote(NOTE_OFF); return; }
    const n = noteFromCode(e.code);
    if (n) {
      e.preventDefault();
      if (e.repeat) return;
      held.set(e.code, app.ch);
      jam(n, app.ch);
      enterNote(n);
    }
    return;
  }
  if (/^[0-9a-fA-F]$/.test(k)) { e.preventDefault(); enterHex(parseInt(k, 16)); }
});

document.addEventListener('keyup', (e) => jamOff(e.code));
window.addEventListener('blur', () => [...held.keys()].forEach(jamOff));

grid.addEventListener('mousedown', (e) => {
  const row = e.target.closest('.prow');
  if (!row) return;
  app.row = +row.dataset.row;
  const cell = e.target.closest('.cell');
  if (cell) {
    app.ch = +cell.dataset.ch;
    const f = e.target.closest('.f');
    app.col = f ? +f.dataset.col : 0;
  }
  updateCursor(false);
  grid.focus();
  e.preventDefault();
});

// ---- toolbar ----
function setOctave(o) { app.octave = clamp(o, 1, 8); $('oct').textContent = app.octave; buildPiano(); }
function setStep(s) { app.step = clamp(s, 0, 16); $('step').textContent = app.step; }
function setRec(on) {
  app.rec = on;
  const b = $('btn-rec');
  b.classList.toggle('on', on);
  b.setAttribute('aria-pressed', on);
  b.textContent = on ? '● REC' : '♪ JAM';
  updateHint();
}
function setIns(i, render = true) {
  app.ins = clamp(i, 1, NINS - 1);
  if (render) renderInstruments(); else renderInsList();
}

// ---------------------------------------------------------------------------
// on-screen piano (two octaves from the current octave)
// ---------------------------------------------------------------------------
function buildPiano() {
  const el = $('piano');
  const whites = [0, 2, 4, 5, 7, 9, 11];
  let h = '';
  const labels = Object.entries(PIANO).reduce((m, [code, s]) => { m[s] = code.replace(/Key|Digit/, ''); return m; }, {});
  for (let o = 0; o < 2; o++) for (const s of whites) h += `<div class="w" data-s="${o * 12 + s}">${labels[o * 12 + s] ?? ''}</div>`;
  el.innerHTML = h;
  const ww = 100 / 14;
  for (let o = 0; o < 2; o++) for (const s of [1, 3, 6, 8, 10]) {
    const wi = whites.findIndex((w) => w > s) + o * 7;
    const b = document.createElement('div');
    b.className = 'b';
    b.dataset.s = o * 12 + s;
    b.textContent = labels[o * 12 + s] ?? '';
    b.style.left = `calc(${wi * ww}% - ${ww * 0.32}%)`;
    b.style.width = `${ww * 0.64}%`;
    el.appendChild(b);
  }
}

let pianoDown = null;
$('piano').addEventListener('pointerdown', (e) => {
  const k = e.target.closest('[data-s]');
  if (!k) return;
  e.preventDefault();
  const n = (app.octave - 1) * 12 + +k.dataset.s + 1;
  if (n < 1 || n > 96) return;
  pianoDown = k;
  k.classList.add('down');
  const ch = app.ch;
  jam(n, ch);
  if (document.activeElement === grid || grid.contains(document.activeElement) || app.lastFocusGrid) {
    if (app.rec && app.col === 0) enterNote(n);
  }
  const up = () => {
    k.classList.remove('down');
    audio.send({ type: 'jamoff', ch });
    window.removeEventListener('pointerup', up);
    pianoDown = null;
  };
  window.addEventListener('pointerup', up);
});
grid.addEventListener('focus', () => { app.lastFocusGrid = true; });
document.addEventListener('pointerdown', (e) => {
  if (!e.target.closest('#grid, #piano, .toolbar')) app.lastFocusGrid = false;
});

// ---------------------------------------------------------------------------
// song panel
// ---------------------------------------------------------------------------
function renderSongPanel() {
  const s = app.song;
  setVal('song-name', s.name);
  setVal('song-speed', s.speed);
  setVal('song-rows', s.patlen);
  setVal('song-loop', s.loop);
  $('song-loop').max = s.length - 1;
  const bpm = (app.hz * 60) / (s.speed * 4);
  $('song-bpm').textContent = `≈ ${bpm.toFixed(0)} BPM at ${app.hz} Hz with 4 rows per beat · ${s.length} positions`;
  let h = '';
  for (let i = 0; i < s.length; i++) {
    h += `<button role="option" aria-selected="${i === app.ord}" class="${i === app.ord ? 'sel' : ''}${i === s.loop ? ' loop' : ''}" data-i="${i}"><small>${hex(i)}</small>${hex(s.order(i))}</button>`;
  }
  $('orders').innerHTML = h;
  setVal('pat-num', s.order(app.ord));
}

function setVal(id, v) { const el = $(id); if (document.activeElement !== el) el.value = v; }

$('orders').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (!b) return;
  app.ord = +b.dataset.i;
  renderAll();
});

function numInput(id, fn) {
  $(id).addEventListener('change', (e) => {
    const v = parseInt(e.target.value, 10);
    if (Number.isNaN(v)) { renderAll(); return; }
    edit(() => fn(v));
  });
}
$('song-name').addEventListener('input', (e) => edit(() => { app.song.name = e.target.value; }, 'none'));
numInput('song-speed', (v) => { app.song.speed = v; });
numInput('song-rows', (v) => { app.song.patlen = v; clampCursor(); });
numInput('song-loop', (v) => { app.song.loop = v; });
numInput('pat-num', (v) => { app.song.setOrder(app.ord, clamp(v, 0, MAXPAT - 1)); });
$('pat-dn').onclick = () => edit(() => { const p = app.song.order(app.ord); if (!p) return false; app.song.setOrder(app.ord, p - 1); });
$('pat-up').onclick = () => edit(() => { const p = app.song.order(app.ord); if (p >= MAXPAT - 1) return false; app.song.setOrder(app.ord, p + 1); });

function newPosition(clone) {
  const free = app.song.freePattern();
  if (free < 0) { showStatus('No free pattern left (64 in use)'); return; }
  if (app.song.length >= ORDMAX) { showStatus('The song is full (128 positions)'); return; }
  edit(() => {
    if (clone) app.song.copyPattern(curPat(), free);
    app.song.insertOrder(app.ord + 1, free);
    app.ord++;
    app.row = 0;
  });
  showStatus(clone ? `Pattern ${hex(free)}: a copy to change` : `New empty pattern ${hex(free)}`);
}
$('ord-new').onclick = () => newPosition(false);
$('ord-clone').onclick = () => newPosition(true);
$('ord-dup').onclick = () => edit(() => { if (!app.song.insertOrder(app.ord + 1, curPat())) return false; app.ord++; });
$('ord-del').onclick = () => edit(() => { if (!app.song.deleteOrder(app.ord)) return false; clampCursor(); });

// ---------------------------------------------------------------------------
// instruments
// ---------------------------------------------------------------------------
function renderInsList() {
  let h = '';
  for (let i = 1; i < NINS; i++) {
    h += `<button role="option" aria-selected="${i === app.ins}" class="${i === app.ins ? 'sel' : ''}" data-i="${i}"><b>${hex(i, 1)}</b>${app.song.insName(i) || '&nbsp;'}</button>`;
  }
  $('ins-list').innerHTML = h;
}

$('ins-list').addEventListener('click', (e) => {
  const b = e.target.closest('button');
  if (b) setIns(+b.dataset.i);
});

const STEP_ROWS = [
  { key: 1, label: 'ARP', min: -96, max: 96, signed: true, title: 'Semitones added to the note' },
  { key: 2, label: 'SWP', min: -128, max: 127, signed: true, title: 'Pitch sweep added every tick (minus = up)' },
  { key: 3, label: 'NOI', min: 0, max: 31, title: 'Noise period 0-31 (needs N on)' },
];
const FLAGS = [{ bit: 1, label: 'T', title: 'Tone on' }, { bit: 2, label: 'N', title: 'Noise on' }, { bit: 4, label: 'E', title: 'Hardware envelope' }];

function renderInstruments() {
  renderInsList();
  const s = app.song, i = app.ins;
  setVal('ins-name', s.insName(i));
  setVal('ins-len', s.insByte(i, I_LEN));
  setVal('ins-speed', s.insByte(i, I_SPEED));
  setVal('ins-eper', s.insByte(i, I_EPERL) | (s.insByte(i, I_EPERH) << 8));
  const loopSel = $('ins-loop');
  if (!loopSel.options.length) {
    loopSel.add(new Option('none (hold)', 255));
    for (let k = 0; k < STEPS; k++) loopSel.add(new Option(`to step ${k}`, k));
  }
  loopSel.value = s.insByte(i, I_LOOP) < 16 ? s.insByte(i, I_LOOP) : 255;
  const shape = $('ins-shape');
  if (!shape.options.length) SHAPES.forEach((t, k) => shape.add(new Option(t, k)));
  shape.value = s.insByte(i, I_SHAPE) & 15;
  $('ins-emode').value = Math.min(4, s.insByte(i, I_EMODE));
  renderSteps();
}

function renderSteps() {
  const s = app.song, i = app.ins, len = s.insByte(i, I_LEN), loop = s.insByte(i, I_LOOP);
  let h = '<span class="lab"></span>';
  for (let k = 0; k < STEPS; k++) h += `<span class="hd${k === loop && loop < len ? ' loop' : ''}${k >= len ? ' off' : ''}" data-hd="${k}" title="${k === loop ? 'loops back here' : ''}">${hex(k, 1)}</span>`;
  h += '<span class="lab">VOL</span>';
  for (let k = 0; k < STEPS; k++) {
    const v = s.stepByte(i, k, 0) & 15;
    h += `<div class="bar${k >= len ? ' off' : ''}" data-step="${k}" title="Volume ${v}"><i style="height:${(v / 15) * 100}%"></i><span>${hex(v, 1)}</span></div>`;
  }
  for (const r of STEP_ROWS) {
    h += `<span class="lab" title="${r.title}">${r.label}</span>`;
    for (let k = 0; k < STEPS; k++) {
      let v = s.stepByte(i, k, r.key);
      if (r.signed && v > 127) v -= 256;
      if (r.key === 3) v &= 31;
      h += `<input type="text" inputmode="numeric" class="${k >= len ? 'off' : ''}" data-step="${k}" data-key="${r.key}" value="${v}" aria-label="${r.label} step ${k}" title="${r.title}, step ${k} (${r.min}…${r.max}, wheel to change)">`;
    }
  }
  for (const f of FLAGS) {
    h += `<span class="lab" title="${f.title}">${f.label}</span>`;
    for (let k = 0; k < STEPS; k++) {
      const on = !!(s.stepByte(i, k, 4) & f.bit);
      h += `<button class="tg${k >= len ? ' off' : ''}" data-step="${k}" data-bit="${f.bit}" aria-pressed="${on}" title="${f.title}, step ${k}">${on ? f.label : '·'}</button>`;
    }
  }
  $('steps').innerHTML = h;
  markInsStep(app.shownStep ?? -1);
}

function markInsStep(step) {
  document.querySelectorAll('#steps .hd').forEach((el) => el.classList.toggle('now', +el.dataset.hd === step));
}

function insEdit(fn, rerender = true) {
  edit(fn, 'none');
  if (rerender) renderSteps();
  renderInsList();
}

$('ins-name').addEventListener('input', (e) => insEdit(() => { app.song.setInsName(app.ins, e.target.value); }, false));
$('ins-len').addEventListener('change', (e) => insEdit(() => { app.song.setInsByte(app.ins, I_LEN, clamp(+e.target.value, 1, 16)); }));
$('ins-speed').addEventListener('change', (e) => insEdit(() => { app.song.setInsByte(app.ins, I_SPEED, clamp(+e.target.value, 1, 63)); }));
$('ins-loop').addEventListener('change', (e) => insEdit(() => { app.song.setInsByte(app.ins, I_LOOP, +e.target.value); }));
$('ins-shape').addEventListener('change', (e) => insEdit(() => { app.song.setInsByte(app.ins, I_SHAPE, +e.target.value); }));
$('ins-emode').addEventListener('change', (e) => insEdit(() => { app.song.setInsByte(app.ins, I_EMODE, +e.target.value); }));
$('ins-eper').addEventListener('change', (e) => insEdit(() => {
  const v = clamp(+e.target.value, 0, 65535);
  app.song.setInsByte(app.ins, I_EPERL, v & 255);
  app.song.setInsByte(app.ins, I_EPERH, v >> 8);
}));

const steps = $('steps');
steps.addEventListener('change', (e) => {
  const t = e.target;
  if (t.tagName !== 'INPUT') return;
  const key = +t.dataset.key, r = STEP_ROWS.find((x) => x.key === key);
  const v = parseInt(t.value, 10);
  if (Number.isNaN(v)) { renderSteps(); return; }
  insEdit(() => { app.song.setStepByte(app.ins, +t.dataset.step, key, clamp(v, r.min, r.max)); });
});
steps.addEventListener('wheel', (e) => {
  const t = e.target;
  if (t.tagName !== 'INPUT') return;
  e.preventDefault();
  const key = +t.dataset.key, r = STEP_ROWS.find((x) => x.key === key);
  const v = clamp(+t.value + (e.deltaY < 0 ? 1 : -1), r.min, r.max);
  t.value = v;
  insEdit(() => { app.song.setStepByte(app.ins, +t.dataset.step, key, v); }, false);
}, { passive: false });
steps.addEventListener('click', (e) => {
  const b = e.target.closest('.tg');
  if (!b) return;
  insEdit(() => {
    const k = +b.dataset.step;
    app.song.setStepByte(app.ins, k, 4, app.song.stepByte(app.ins, k, 4) ^ +b.dataset.bit);
  });
});
// volume bars: drag up and down, across several steps
let barDrag = null;
function barSet(e) {
  const bar = document.elementFromPoint(e.clientX, e.clientY)?.closest('.bar');
  if (!bar) return;
  const rect = bar.getBoundingClientRect();
  const v = clamp(Math.round(((rect.bottom - e.clientY) / rect.height) * 15), 0, 15);
  const k = +bar.dataset.step;
  if (app.song.stepByte(app.ins, k, 0) === v) return;
  app.song.setStepByte(app.ins, k, 0, v);
  bar.querySelector('i').style.height = `${(v / 15) * 100}%`;
  bar.querySelector('span').textContent = hex(v, 1);
  bar.title = `Volume ${v}`;
  songChanged();
}
steps.addEventListener('pointerdown', (e) => {
  if (!e.target.closest('.bar')) return;
  e.preventDefault();
  barDrag = app.song.data.slice();
  barSet(e);
  const move = (ev) => barSet(ev);
  const up = () => {
    window.removeEventListener('pointermove', move);
    window.removeEventListener('pointerup', up);
    app.undo.push(barDrag); app.redo.length = 0; barDrag = null;
  };
  window.addEventListener('pointermove', move);
  window.addEventListener('pointerup', up);
});

$('ins-test').addEventListener('pointerdown', (e) => {
  e.preventDefault();
  jam((app.octave - 1) * 12 + 1, 0);
  const up = () => { audio.send({ type: 'jamoff', ch: 0 }); window.removeEventListener('pointerup', up); };
  window.addEventListener('pointerup', up);
});
$('ins-copy').onclick = () => {
  const o = app.song.insOffset(app.ins);
  app.clipIns = app.song.data.slice(o, o + 96);
  showStatus(`Instrument ${hex(app.ins, 1)} copied`);
};
$('ins-paste').onclick = () => {
  if (!app.clipIns) { showStatus('Copy an instrument first'); return; }
  edit(() => { app.song.data.set(app.clipIns, app.song.insOffset(app.ins)); });
  showStatus('Pasted');
};

// ---------------------------------------------------------------------------
// transport, files, export
// ---------------------------------------------------------------------------
function play(mode, fromRow = false) {
  const row = mode === 2 || fromRow ? app.row : 0;
  audio.cmd({ type: 'play', mode, ord: app.ord, row });
}
function stop() { audio.cmd({ type: 'stop' }); }
$('btn-play-song').onclick = () => play(1);
$('btn-play-pat').onclick = () => play(2);
$('btn-stop').onclick = stop;
$('btn-undo').onclick = () => undoRedo(app.undo, app.redo, 'undo');
$('btn-redo').onclick = () => undoRedo(app.redo, app.undo, 'redo');
$('oct-dn').onclick = () => setOctave(app.octave - 1);
$('oct-up').onclick = () => setOctave(app.octave + 1);
$('step-dn').onclick = () => setStep(app.step - 1);
$('step-up').onclick = () => setStep(app.step + 1);
$('btn-rec').onclick = () => setRec(!app.rec);
$('btn-follow').onclick = () => {
  app.follow = !app.follow;
  $('btn-follow').classList.toggle('on', app.follow);
  $('btn-follow').setAttribute('aria-pressed', app.follow);
};
document.querySelectorAll('.chan-head .mute').forEach((b) => {
  b.onclick = (e) => {
    const ch = +b.dataset.ch;
    if (e.shiftKey) app.mute = app.mute.map((_, i) => i !== ch);   // solo
    else app.mute[ch] = !app.mute[ch];
    document.querySelectorAll('.chan-head .mute').forEach((x, i) => x.setAttribute('aria-pressed', app.mute[i]));
    audio.send({ type: 'mute', mute: app.mute });
  };
  b.title += ' (Shift+click: solo)';
});
$('hz').onchange = (e) => { app.hz = +e.target.value; audio.send({ type: 'hz', hz: app.hz }); renderSongPanel(); };
$('volume').oninput = (e) => { audio.volume = e.target.value / 100; audio.send({ type: 'volume', volume: audio.volume }); };

function loadSong(song, label) {
  stop();
  app.song = song;
  app.undo.length = 0;
  app.redo.length = 0;
  app.ord = 0; app.row = 0;
  app.saved = true;
  audio.send({ type: 'song', data: song.data });
  autosave();
  renderAll();
  if (label) showStatus(label);
}

function confirmDiscard() {
  return app.saved || window.confirm('The current song has changes that are not saved as .MTK. Throw them away?');
}

async function fetchSong(name) {
  const r = await fetch(new URL(`../songs/${name}`, import.meta.url));
  if (!r.ok) throw new Error(`Could not load ${name}`);
  return Song.fromMTK(await r.arrayBuffer());
}

$('btn-new').onclick = async () => {
  if (!confirmDiscard()) return;
  try { loadSong(await fetchSong('new.mtk'), 'New song'); } catch (err) { showStatus(err.message); }
};
$('examples').onchange = async (e) => {
  const name = e.target.value;
  e.target.value = '';
  if (!name || !confirmDiscard()) return;
  try { loadSong(await fetchSong(name), 'Example loaded'); } catch (err) { showStatus(err.message); }
};
$('btn-open').onclick = () => { if (confirmDiscard()) $('file-open').click(); };
$('file-open').onchange = async (e) => {
  const f = e.target.files[0];
  e.target.value = '';
  if (!f) return;
  try { loadSong(Song.fromMTK(await f.arrayBuffer()), `Opened ${f.name}`); } catch (err) { showStatus(err.message); }
};

function fileBase() {
  return (app.song.name || 'song').toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '') || 'song';
}

function download(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

function saveMTK() {
  download(new Blob([app.song.toMTK()], { type: 'application/octet-stream' }), `${fileBase()}.mtk`);
  app.saved = true;
  showStatus('Saved as .MTK – it also loads on a real MSX');
}
$('btn-save').onclick = saveMTK;

const dlgExport = $('dlg-export');
$('btn-export').onclick = () => { $('exp-msg').textContent = ''; $('exp-progress').hidden = true; dlgExport.showModal(); };
$('exp-go').addEventListener('click', async (e) => {
  e.preventDefault();
  const fmt = dlgExport.querySelector('input[name=fmt]:checked').value;
  const prog = $('exp-progress');
  const btn = $('exp-go');
  btn.disabled = true;
  prog.hidden = false;
  prog.value = 0;
  $('exp-msg').textContent = 'Playing the song…';
  try {
    const onProgress = (v) => { prog.value = v; };
    const samples = await renderSong(app.song.data, {
      hz: app.hz, loops: +$('exp-loops').value, fade: $('exp-fade').checked, onProgress,
    });
    let blob;
    if (fmt === 'mp3') {
      $('exp-msg').textContent = 'Encoding MP3…';
      blob = await toMp3(samples, { kbps: +$('exp-rate').value, onProgress });
    } else blob = toWav(samples);
    prog.value = 1;
    const secs = samples.length / 44100;
    download(blob, `${fileBase()}.${fmt}`);
    $('exp-msg').textContent = `Done: ${Math.floor(secs / 60)}:${String(Math.round(secs % 60)).padStart(2, '0')}, ${(blob.size / 1024).toFixed(0)} KB.`;
  } catch (err) {
    $('exp-msg').textContent = `Export failed: ${err.message}`;
  } finally {
    btn.disabled = false;
  }
});

$('btn-help').onclick = () => $('dlg-help').showModal();
$('help-fx').innerHTML = FX.map(([c, n, d]) => `<tr><th>${c}</th><td><b>${n}</b> – ${d}</td></tr>`).join('');

// ---------------------------------------------------------------------------
// misc
// ---------------------------------------------------------------------------
let statusTimer = 0;
function showStatus(text) {
  const el = $('status');
  el.textContent = text;
  el.classList.add('show');
  clearTimeout(statusTimer);
  statusTimer = setTimeout(() => el.classList.remove('show'), 2600);
}

let saveTimer = 0;
function autosave() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    try {
      const b = app.song.toMTK();
      let s = '';
      for (let i = 0; i < b.length; i += 8192) s += String.fromCharCode(...b.subarray(i, i + 8192));
      localStorage.setItem(STORE_KEY, JSON.stringify({ mtk: btoa(s), saved: app.saved }));
    } catch { /* storage unavailable: nothing to do */ }
  }, 400);
}

function restore() {
  try {
    const j = JSON.parse(localStorage.getItem(STORE_KEY) || 'null');
    if (!j) return null;
    const bin = atob(j.mtk);
    const b = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) b[i] = bin.charCodeAt(i);
    app.saved = !!j.saved;
    return Song.fromMTK(b);
  } catch { return null; }
}

function renderAll() {
  clampCursor();
  renderSongPanel();
  renderPattern();
  renderInstruments();
}

window.addEventListener('beforeunload', (e) => { if (!app.saved) { autosave(); } });

// start: the song from last time, or the demo
(async () => {
  buildPiano();
  setOctave(4);
  let song = restore();
  if (!song) {
    try { song = await fetchSong('demo.mtk'); } catch { song = new Song(); }
    app.saved = true;
  }
  const keepSaved = app.saved;
  loadSong(song);
  app.saved = keepSaved;
  grid.focus();
  // the audio can only start after a click or key press
  const unlock = () => { audio.ensure().then(() => audio.ctx.resume()); };
  window.addEventListener('pointerdown', unlock, { once: true });
  window.addEventListener('keydown', unlock, { once: true });
})();

// for tests
window.msxtrack = { app, audio };
