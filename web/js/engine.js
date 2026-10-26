// Port of the MSXTRACK replay engine (src/player_core.asm) to JavaScript.
// It reads the song bytes the same way and keeps the Z80 code's 8/16-bit
// wrap-around, so it produces the same PSG register values frame by frame.
import { notetab, voltab, sinetab } from './tables.js';
import {
  NOTE_OFF, PATBASE, PATSIZE, ROWSZ, MAXPAT, S_SPEED, S_PATLEN, S_LEN, S_LOOP,
  S_ORDERS, S_INSTR, INSSZ, I_LEN, I_LOOP, I_SPEED, I_SHAPE, I_EMODE, I_EPERL,
  I_EPERH, I_STEPS, STEPSZ,
} from './mtk.js';

const s8 = (v) => (v & 0x80 ? (v & 0xff) - 256 : v & 0xff);
const w16 = (v) => v & 0xffff;

// signed 16-bit clamp to -4095..4095 (clamp_pitch)
function clampPitch(hl) {
  hl = w16(hl);
  if (!(hl & 0x8000)) return (hl >> 8) >= 0x10 ? 0x0fff : hl;
  return (hl >> 8) >= 0xf0 ? hl : 0xf001;
}

function newChannel() {
  return {
    note: 0, ins: 0, insOff: 0, step: 0, stick: 0, active: 0, vol: 15,
    swp: 0, sld: 0, fx: 0xff, fxp: 0, arpc: 0, vibp: 0, cut: 0xff, dly: 0,
    dnote: 0, div: 0, dfl: 0, det: 0, novr: 0xff, mute: 0,
    opl: 1, ovol: 0, omix: 0, onoi: 0, oenv: 0, pspd: 0, vibpar: 0,
  };
}

export class Engine {
  constructor(data) {
    this.data = data;              // Uint8Array laid out like mtk.js Song.data
    this.numpat = MAXPAT;
    this.ch = [newChannel(), newChannel(), newChannel()];
    this.reg = new Uint8Array(14);
    this.envTrig = 0;
    this.playing = 0;              // 0 stop, 1 song, 2 pattern loop
    this.tick = 0; this.speed = 6; this.ordpos = 0; this.row = 0; this.patptr = PATBASE;
    this.jump = 0xff; this.brk = 0xff; this.first = 0; this.envMan = 0;
    this.rowFlag = 0; this.dispRow = 0; this.dispOrd = 0;
    this.jamCut = 30;
    this.resetChans();
  }

  // ---- addressing ----
  patAddr(p) { if (p >= this.numpat) p = 0; return PATBASE + p * PATSIZE; }
  insAddr(i) { return S_INSTR + (i & 255) * INSSZ; }
  setInstr(c, i) { c.ins = i; c.insOff = this.insAddr(i); }
  setPatptr(pos) { this.patptr = this.patAddr(this.data[S_ORDERS + pos]); }

  resetChans() {
    for (let i = 0; i < 3; i++) {
      const mute = this.ch[i].mute;
      const c = newChannel();
      c.mute = mute;
      this.setInstr(c, 1);
      this.ch[i] = c;
    }
  }

  playStart(mode, ord, row) {
    this.resetChans();
    this.speed = this.data[S_SPEED];
    this.tick = 1;
    this.ordpos = ord;
    this.setPatptr(ord);
    this.row = row;
    this.envMan = 0;
    this.rowFlag = 0;
    this.playing = mode;
  }

  playStop() { this.playing = 0; this.resetChans(); }

  // one video frame: sequencer + instruments, then the register image
  frame() {
    if (this.playing) {
      this.tick = (this.tick - 1) & 255;
      if (this.tick === 0) {
        this.processRow();
        this.tick = this.speed;
        this.first = 1;
      }
    }
    for (const c of this.ch) this.chanTick(c);
    this.first = 0;
    return this.psgUpdate();
  }

  processRow() {
    this.dispRow = this.row;
    this.dispOrd = this.ordpos;
    this.jump = 0xff; this.brk = 0xff;
    let a = this.patptr + this.row * ROWSZ;
    for (const c of this.ch) { this.processCell(c, a); a += 4; }
    this.rowFlag = 1;
    const d = this.data;
    let row;
    if (this.jump !== 0xff) {
      row = this.brk !== 0xff ? this.brk : 0;
      if (this.playing !== 2) this.setOrd(this.jump);
    } else if (this.brk !== 0xff) {
      row = this.brk;
      if (this.playing !== 2) this.setOrd((this.ordpos + 1) & 255);
    } else {
      const r = (this.row + 1) & 255;
      if (r < d[S_PATLEN]) { this.row = r; return; }
      row = 0;
      if (this.playing !== 2) this.setOrd((this.ordpos + 1) & 255);
    }
    this.row = row < d[S_PATLEN] ? row : 0;
  }

  setOrd(pos) {
    const d = this.data;
    if (pos >= d[S_LEN]) pos = d[S_LOOP] < d[S_LEN] ? d[S_LOOP] : 0;
    this.ordpos = pos;
    this.setPatptr(pos);
  }

  processCell(c, a) {
    const d = this.data;
    const note = d[a], iv = d[a + 1], fl = d[a + 2], par = d[a + 3];
    c.cut = 0xff;
    c.dly = 0;
    if ((fl & 0x40) && (fl & 15) === 9 && par) {
      let n = (par + 1) & 255;
      if (n === 0) n = 255;
      c.dly = n; c.dnote = note; c.div = iv; c.dfl = fl;
      return;
    }
    this.applyCell(c, note, iv, fl, par);
  }

  applyCell(c, note, iv, fl, par) {
    if (iv & 0xf0) this.setInstr(c, iv >> 4);
    if (fl & 0x80) c.vol = iv & 15;
    if (note && note !== NOTE_OFF) c.fx = 0xff;
    if (fl & 0x40) this.applyFx(c, fl & 15, par);
    if (!note) return;
    if (note === NOTE_OFF) { c.active = 0; return; }
    if (c.fx === 3 && c.active) {           // tone portamento
      const cur = w16(notetab[Math.min(c.note, 96)] + c.sld);
      c.note = note;
      c.sld = w16(cur - notetab[Math.min(note, 96)]);
      return;
    }
    this.triggerNote(c, note);
  }

  triggerNote(c, note) {
    c.note = note; c.active = 1;
    c.step = 0; c.stick = 0; c.swp = 0; c.sld = 0; c.vibp = 0; c.arpc = 0;
    const d = this.data;
    if (d[c.insOff + I_STEPS + 4] & 4) {
      this.reg[13] = d[c.insOff + I_SHAPE] & 15;
      this.envTrig = 1;
    }
  }

  applyFx(c, cmd, p) {
    switch (cmd) {
      case 0: if (p) { c.fx = 0; c.fxp = p; } else c.fx = 0xff; break;
      case 1: case 2: case 10: c.fx = cmd; c.fxp = p; break;
      case 3: c.fx = 3; if (p) c.pspd = p; break;
      case 4: c.fx = 4; if (p) c.vibpar = p; break;
      case 5: this.reg[12] = p; this.envMan = 1; break;
      case 6: this.reg[11] = p; this.envMan = 1; break;
      case 7: this.reg[13] = p & 15; this.envTrig = 1; break;
      case 8: c.novr = p < 0x20 ? p : 0xff; break;
      case 11: this.jump = p; break;
      case 12: c.cut = p; break;
      case 13: this.brk = p; break;
      case 14: c.det = p; break;
      case 15: if (p) this.speed = p; break;
    }
  }

  chanTick(c) {
    const d = this.data;
    if (c.dly) {
      c.dly = (c.dly - 1) & 255;
      if (!c.dly) this.applyCell(c, c.dnote, c.div, c.dfl, 0);
    }
    if (c.cut !== 0xff) {
      if (c.cut === 0) { c.active = 0; c.cut = 0xff; } else c.cut--;
    }
    c.oenv = 0;
    if (!c.active) { c.ovol = 0; c.omix = 0; return; }
    const ins = c.insOff;
    const st = ins + ((I_STEPS + ((c.step * STEPSZ) & 255)) & 255);
    c.ovol = voltab[(((d[st] & 15) << 4) + c.vol) & 255];
    let arp = d[st + 1];
    c.swp = clampPitch(c.swp + s8(d[st + 2]));
    c.onoi = c.novr !== 0xff ? c.novr : d[st + 3] & 31;
    const flags = d[st + 4];
    c.omix = flags & 3;
    if (flags & 4) { c.ovol = 16; c.oenv = 1; }

    // running effects
    if (c.fx !== 0xff) {
      if (c.fx === 0) {
        const n = c.arpc;
        c.arpc = n + 1 >= 3 ? 0 : n + 1;
        if (n) arp = (arp + ((n === 1 ? c.fxp >> 4 : c.fxp) & 15)) & 255;
      } else if (!this.first) {
        switch (c.fx) {
          case 1: c.sld = clampPitch(c.sld - c.fxp); break;
          case 2: c.sld = clampPitch(c.sld + c.fxp); break;
          case 3:
            if (!(c.sld & 0x8000)) c.sld = c.sld < c.pspd ? 0 : c.sld - c.pspd;
            else c.sld = c.sld + c.pspd > 0xffff ? 0 : c.sld + c.pspd;
            break;
          case 4: c.vibp = (c.vibp + (c.vibpar >> 4)) & 255; break;
          case 10: {
            const p = c.fxp;
            if (p & 0xf0) c.vol = Math.min(15, c.vol + (p >> 4));
            else c.vol = Math.max(0, c.vol - p);
            break;
          }
        }
      }
    }

    // pitch: note + arpeggio clamped to 1..96
    let n = w16(c.note + s8(arp));
    if (n & 0x8000) n = 1;
    else if (n >> 8) n = 96;
    else if (n === 0) n = 1;
    else if (n >= 97) n = 96;
    let per = w16(notetab[n] + c.swp + c.sld + s8(c.det));
    if (c.fx === 4) per = w16(per + this.vibOffset(c));
    if (per & 0x8000) per = 1;
    else if ((per >> 8) >= 0x10) per = 0x0fff;
    else if (per === 0) per = 1;
    c.opl = per;

    // hardware envelope period
    if (c.oenv) {
      const mode = d[ins + I_EMODE];
      if (mode) {
        let p = per >> ((mode & 7) + 2);
        if (!p) p = 1;
        this.reg[11] = p & 255; this.reg[12] = p >> 8;
      } else if (!this.envMan) {
        this.reg[11] = d[ins + I_EPERL]; this.reg[12] = d[ins + I_EPERH];
      }
    }

    // advance the instrument sequence
    const a = (c.stick + 1) & 255;
    if (a < d[ins + I_SPEED]) { c.stick = a; return; }
    let s = (c.step + 1) & 255;
    const len = d[ins + I_LEN];
    if (s >= len) {
      const loop = d[ins + I_LOOP];
      if (loop < len) s = loop;
      else s = len ? len - 1 : 0;
    }
    c.step = s;
    c.stick = 0;
  }

  vibOffset(c) {
    const e = sinetab[c.vibp & 31];
    const depth = c.vibpar & 15;
    let off = depth ? ((e * depth * 4) >> 8) & 0xffff : 0;
    if (c.vibp & 0x20) off = w16(-off);
    return off;
  }

  // registers 0-13 (R13 only meaningful when envTrig is set)
  psgUpdate() {
    let mix = 0, bit = 1;
    for (let i = 0; i < 3; i++) {
      const c = this.ch[i];
      this.reg[i * 2] = c.opl & 255;
      this.reg[i * 2 + 1] = c.opl >> 8;
      if (c.mute) this.reg[8 + i] = 0;
      else {
        this.reg[8 + i] = c.ovol;
        if (c.omix & 1) mix |= bit;
        if (c.omix & 2) { mix |= bit << 3; this.reg[6] = c.onoi; }
      }
      bit <<= 1;
    }
    this.reg[7] = 0x80 | (~mix & 0x3f);
    const trig = this.envTrig;
    this.envTrig = 0;
    return trig;
  }

  // preview one cell on a channel (like the tracker's jam_cell)
  jam(ch, note, iv, fl, par, cut = this.jamCut) {
    const c = this.ch[ch];
    c.fx = 0xff; c.dly = 0; c.cut = cut & 255;
    if (!(fl & 0x80)) c.vol = 15;
    if ((fl & 15) === 9) fl &= ~0x40;
    this.applyCell(c, note, iv, fl, par);
  }
}
