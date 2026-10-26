// AudioWorklet: plays the song live and reports the position to the page.
import { Synth } from './synth.js';
import { TOTAL } from './mtk.js';

class MsxTrackProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.synth = new Synth(sampleRate, new Uint8Array(TOTAL));
    this.volume = 0.8;
    this.frames = 0;
    this.synth.onFrame = (e) => {
      if (e.rowFlag) {
        e.rowFlag = 0;
        this.port.postMessage({ type: 'pos', ord: e.dispOrd, row: e.dispRow, playing: e.playing });
      }
      if (++this.frames % 2 === 0) {
        this.port.postMessage({
          type: 'levels',
          playing: e.playing,
          ch: e.ch.map((c) => ({ vol: c.active ? c.ovol : 0, ins: c.ins, step: c.step, active: c.active })),
        });
      }
    };
    this.port.onmessage = (ev) => this.command(ev.data);
  }

  command(m) {
    const e = this.synth.engine;
    switch (m.type) {
      case 'song': this.synth.setSong(m.data); break;
      case 'play': e.playStart(m.mode, m.ord, m.row); this.port.postMessage({ type: 'pos', ord: m.ord, row: m.row, playing: m.mode }); break;
      case 'stop': e.playStop(); this.port.postMessage({ type: 'pos', ord: e.ordpos, row: e.row, playing: 0 }); break;
      case 'jam': e.jam(m.ch, m.note, m.iv, m.fl, m.par, m.cut); break;
      case 'jamoff': if (!e.playing) e.ch[m.ch].active = 0; break;
      case 'mute': e.ch.forEach((c, i) => { c.mute = m.mute[i] ? 1 : 0; }); break;
      case 'hz': this.synth.setHz(m.hz); break;
      case 'volume': this.volume = m.volume; break;
    }
  }

  process(inputs, outputs) {
    const out = outputs[0];
    const left = out[0];
    this.synth.process(left, left.length);
    for (let i = 0; i < left.length; i++) left[i] *= this.volume;
    for (let c = 1; c < out.length; c++) out[c].set(left);
    return true;
  }
}

registerProcessor('msxtrack', MsxTrackProcessor);
