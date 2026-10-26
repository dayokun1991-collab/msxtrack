// Engine + PSG driven at the MSX video frame rate. Used by the audio
// worklet for live playback and by the exporter for offline rendering.
import { Engine } from './engine.js';
import { PSG } from './psg.js';
import { S_LEN } from './mtk.js';

export class Synth {
  constructor(sampleRate, data, hz = 60) {
    this.sampleRate = sampleRate;
    this.engine = new Engine(data);
    this.psg = new PSG(sampleRate);
    this.setHz(hz);
    this.untilFrame = 0;
    this.wrapped = false;       // the song has gone round to its loop point
    this.onFrame = null;
    const e = this.engine, setOrd = e.setOrd.bind(e);
    e.setOrd = (pos) => {        // notice the end of the song
      if (e.playing === 1 && (pos >= e.data[S_LEN] || pos <= e.ordpos)) this.wrapped = true;
      setOrd(pos);
    };
  }

  // the real MSX video rates: NTSC 59.92 Hz, PAL 50.16 Hz
  setHz(hz) { this.hz = hz; this.samplesPerFrame = this.sampleRate / (hz === 50 ? 50.159 : 59.923); }

  setSong(data) { this.engine.data.set(data); }

  frame() {
    const e = this.engine;
    const trig = e.frame();
    for (let r = 0; r < 13; r++) this.psg.write(r, e.reg[r]);
    if (trig) this.psg.write(13, e.reg[13]);
    if (this.onFrame) this.onFrame(e);
  }

  // mono samples into out[0..n)
  process(out, n) {
    let i = 0;
    while (i < n) {
      if (this.untilFrame <= 0) {
        const was = this.wrapped;
        this.frame();
        if (!was && this.wrapped) this.wrapAt = i;   // sample where the loop starts
        this.untilFrame += this.samplesPerFrame;
      }
      const k = Math.min(n - i, Math.ceil(this.untilFrame));
      this.psg.render(out, i, k);
      this.untilFrame -= k;
      i += k;
    }
  }
}
