// MSXTRACK song model. The bytes are laid out exactly like the MSX
// tracker's memory, so the engine port can read them the same way and
// .MTK files round-trip byte for byte.

export const NOTE_OFF = 97;
export const ROWS = 64;          // pattern storage is always 64 rows
export const ROWSZ = 12;         // 3 channels x 4 bytes
export const PATSIZE = ROWS * ROWSZ;
export const MAXPAT = 64;
export const ORDMAX = 128;
export const NINS = 16;
export const INSSZ = 96;
export const STEPS = 16;

// song block offsets (identical to the tracker's SONGDATA)
export const S_SPEED = 0, S_PATLEN = 1, S_LEN = 2, S_LOOP = 3, S_NAME = 4;
export const S_ORDERS = 32;
export const S_INSTR = 160;
export const SONGBLK = 1696;
export const PATBASE = SONGBLK;
export const TOTAL = SONGBLK + MAXPAT * PATSIZE;

// instrument offsets
export const I_LEN = 0, I_LOOP = 1, I_SPEED = 2, I_SHAPE = 3, I_EMODE = 4,
  I_EPERL = 5, I_EPERH = 6, I_NAME = 8, I_STEPS = 16, STEPSZ = 5;

const MAGIC = [77, 83, 88, 84, 82, 75]; // "MSXTRK"
const NAMES = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-'];

export function noteName(n) {
  if (!n) return '---';
  if (n >= NOTE_OFF) return '===';
  return NAMES[(n - 1) % 12] + (Math.floor((n - 1) / 12) + 1);
}

export class Song {
  constructor(bytes) {
    this.data = new Uint8Array(TOTAL);
    if (bytes) this.data.set(bytes.subarray(0, TOTAL));
  }

  clone() { return new Song(this.data); }

  // ---- settings ----
  get speed() { return this.data[S_SPEED]; }
  set speed(v) { this.data[S_SPEED] = clamp(v, 1, 31); }
  get patlen() { return this.data[S_PATLEN]; }
  set patlen(v) { this.data[S_PATLEN] = clamp(v, 1, 64); }
  get length() { return this.data[S_LEN]; }
  set length(v) {
    this.data[S_LEN] = clamp(v, 1, ORDMAX);
    if (this.loop >= this.length) this.loop = 0;
  }
  get loop() { return this.data[S_LOOP]; }
  set loop(v) { this.data[S_LOOP] = clamp(v, 0, this.length - 1); }
  get name() { return readText(this.data, S_NAME, 16); }
  set name(s) { writeText(this.data, S_NAME, 16, s.toUpperCase()); }

  order(pos) { return this.data[S_ORDERS + pos]; }
  setOrder(pos, pat) { this.data[S_ORDERS + pos] = clamp(pat, 0, MAXPAT - 1); }

  insertOrder(pos, pat) {
    if (this.length >= ORDMAX) return false;
    const o = this.data;
    for (let i = ORDMAX - 1; i > pos; i--) o[S_ORDERS + i] = o[S_ORDERS + i - 1];
    o[S_ORDERS + pos] = pat;
    o[S_LEN]++;
    return true;
  }

  deleteOrder(pos) {
    if (this.length < 2) return false;
    const o = this.data;
    for (let i = pos; i < ORDMAX - 1; i++) o[S_ORDERS + i] = o[S_ORDERS + i + 1];
    o[S_LEN]--;
    if (this.loop >= this.length) this.loop = 0;
    return true;
  }

  // ---- patterns ----
  cellOffset(pat, row, ch) { return PATBASE + pat * PATSIZE + row * ROWSZ + ch * 4; }

  getCell(pat, row, ch) {
    const o = this.cellOffset(pat, row, ch), d = this.data;
    const flags = d[o + 2];
    return {
      note: d[o],
      ins: d[o + 1] >> 4,
      vol: flags & 0x80 ? d[o + 1] & 15 : null,
      fx: flags & 0x40 ? flags & 15 : null,
      param: d[o + 3],
    };
  }

  setCell(pat, row, ch, c) {
    const o = this.cellOffset(pat, row, ch), d = this.data;
    d[o] = c.note;
    d[o + 1] = (c.ins << 4) | (c.vol ?? 0);
    d[o + 2] = (c.vol != null ? 0x80 : 0) | (c.fx != null ? 0x40 | c.fx : 0);
    d[o + 3] = c.fx != null ? c.param : 0;
  }

  patternEmpty(p) {
    const o = PATBASE + p * PATSIZE;
    for (let i = 0; i < PATSIZE; i++) if (this.data[o + i]) return false;
    return true;
  }

  usedInSong(p) {
    for (let i = 0; i < this.length; i++) if (this.order(i) === p) return true;
    return false;
  }

  freePattern() {
    for (let p = 0; p < MAXPAT; p++) if (!this.usedInSong(p) && this.patternEmpty(p)) return p;
    return -1;
  }

  copyPattern(from, to) {
    this.data.copyWithin(PATBASE + to * PATSIZE, PATBASE + from * PATSIZE, PATBASE + (from + 1) * PATSIZE);
  }

  // highest pattern in use + 1 (what a save stores), like the tracker
  usedPatterns() {
    let n = 1;
    for (let i = 0; i < this.length; i++) n = Math.max(n, this.order(i) + 1);
    for (let p = MAXPAT - 1; p >= n; p--) if (!this.patternEmpty(p)) return p + 1;
    return n;
  }

  // ---- instruments ----
  insOffset(i) { return S_INSTR + i * INSSZ; }
  insName(i) { return readText(this.data, this.insOffset(i) + I_NAME, 8); }
  setInsName(i, s) { writeText(this.data, this.insOffset(i) + I_NAME, 8, s.toUpperCase()); }
  insByte(i, off) { return this.data[this.insOffset(i) + off]; }
  setInsByte(i, off, v) { this.data[this.insOffset(i) + off] = v & 255; }
  stepByte(i, step, field) { return this.data[this.insOffset(i) + I_STEPS + step * STEPSZ + field]; }
  setStepByte(i, step, field, v) { this.data[this.insOffset(i) + I_STEPS + step * STEPSZ + field] = v & 255; }

  // ---- files ----
  toMTK() {
    const n = this.usedPatterns();
    const out = new Uint8Array(8 + SONGBLK + n * PATSIZE);
    out.set(MAGIC, 0);
    out[6] = 1;
    out[7] = n;
    out.set(this.data.subarray(0, SONGBLK + n * PATSIZE), 8);
    return out;
  }

  static fromMTK(buf) {
    const b = new Uint8Array(buf);
    if (b.length < 8 + SONGBLK || MAGIC.some((m, i) => b[i] !== m)) throw new Error('Not a MSXTRACK song (.MTK) file');
    if (b[6] !== 1) throw new Error('Unsupported .MTK version ' + b[6]);
    const n = b[7];
    if (n < 1 || n > MAXPAT || b.length < 8 + SONGBLK + n * PATSIZE) throw new Error('The .MTK file is damaged');
    const s = new Song();
    s.data.set(b.subarray(8, 8 + SONGBLK + n * PATSIZE));
    // same safety fixes the tracker applies after loading
    const d = s.data;
    d[S_SPEED] = clamp(d[S_SPEED], 1, 31);
    d[S_PATLEN] = clamp(d[S_PATLEN], 1, 64);
    d[S_LEN] = clamp(d[S_LEN], 1, ORDMAX);
    if (d[S_LOOP] >= d[S_LEN]) d[S_LOOP] = 0;
    for (let i = 0; i < ORDMAX; i++) if (d[S_ORDERS + i] >= MAXPAT) d[S_ORDERS + i] = 0;
    for (let i = 1; i < NINS; i++) {
      const o = s.insOffset(i);
      d[o + I_LEN] = clamp(d[o + I_LEN], 1, 16);
      if (!d[o + I_SPEED]) d[o + I_SPEED] = 1;
    }
    return s;
  }
}

export function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v | 0)); }

function readText(d, off, n) {
  let s = '';
  for (let i = 0; i < n; i++) s += String.fromCharCode(d[off + i] || 32);
  return s.replace(/\s+$/, '');
}

function writeText(d, off, n, s) {
  for (let i = 0; i < n; i++) {
    const c = i < s.length ? s.charCodeAt(i) : 32;
    d[off + i] = c >= 32 && c < 127 ? c : 32;
  }
}
