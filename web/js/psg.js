// AY-3-8910 / YM2149 sound chip emulation, as found in every MSX.
// It runs at the chip's internal rate (clock / 8) and averages down to the
// output sample rate, which keeps the square waves free of harsh aliasing.

export const PSG_CLOCK = 3579545 / 2;   // 1.7897725 MHz on every MSX

// measured AY-3-8910 output levels for volume 0-15
const LEVELS = [0, 0.0137, 0.0205, 0.0291, 0.0423, 0.0618, 0.0847, 0.1369,
  0.1691, 0.2647, 0.3527, 0.4499, 0.5704, 0.6873, 0.8482, 1.0];

export class PSG {
  constructor(sampleRate, clock = PSG_CLOCK) {
    this.ticksPerSample = clock / 8 / sampleRate;
    this.reg = new Uint8Array(16);
    this.toneCount = [0, 0, 0];
    this.toneOut = [0, 0, 0];
    this.noiseCount = 0;
    this.rng = 1;
    this.noiseOut = 0;
    this.half = 0;               // noise and envelope run at clock / 16
    this.envCount = 0;
    this.envStep = 0;
    this.envAttack = 0;
    this.envHold = false;
    this.envLevel = 0;
    this.acc = 0;
    this.dcIn = 0;
    this.dcOut = 0;
    this.gain = 0.8;
    this.reg[7] = 0xbf;
  }

  write(r, v) {
    r &= 15;
    this.reg[r] = v & 255;
    if (r === 13) this.envReset();
  }

  envReset() {
    this.envStep = 0;
    this.envCount = 0;
    this.envHold = false;
    this.envAttack = this.reg[13] & 4 ? 15 : 0;
    this.envLevel = this.envAttack ^ 15;
  }

  envTick() {
    if (this.envHold) return;
    if (++this.envStep > 15) {
      const shape = this.reg[13];
      if (!(shape & 8)) {                  // shapes 0-7: one ramp, then silence
        this.envHold = true;
        this.envLevel = 0;
        return;
      }
      if (shape & 1) {                     // hold at the end (flipped if alternate)
        this.envHold = true;
        this.envLevel = (this.envAttack ? 15 : 0) ^ (shape & 2 ? 15 : 0);
        return;
      }
      this.envStep = 0;
      if (shape & 2) this.envAttack ^= 15;
    }
    this.envLevel = this.envStep ^ (this.envAttack ^ 15);
  }

  // one tick at clock / 8; returns the summed channel levels
  tick() {
    const r = this.reg;
    for (let c = 0; c < 3; c++) {
      const period = (r[c * 2] | ((r[c * 2 + 1] & 15) << 8)) || 1;
      if (++this.toneCount[c] >= period) { this.toneCount[c] = 0; this.toneOut[c] ^= 1; }
    }
    this.half ^= 1;
    if (this.half) {
      if (++this.noiseCount >= ((r[6] & 31) || 1)) {
        this.noiseCount = 0;
        const bit = (this.rng ^ (this.rng >> 3)) & 1;
        this.rng = (this.rng >> 1) | (bit << 16);
        this.noiseOut = this.rng & 1;
      }
      if (++this.envCount >= ((r[11] | (r[12] << 8)) || 1)) {
        this.envCount = 0;
        this.envTick();
      }
    }
    const mix = r[7];
    let sum = 0;
    for (let c = 0; c < 3; c++) {
      const on = (this.toneOut[c] | ((mix >> c) & 1)) & (this.noiseOut | ((mix >> (c + 3)) & 1));
      if (on) {
        const v = r[8 + c];
        sum += LEVELS[v & 16 ? this.envLevel : v & 15];
      }
    }
    return sum;
  }

  // fill out[offset .. offset+n) with mono samples in -1..1
  render(out, offset, n) {
    for (let i = 0; i < n; i++) {
      this.acc += this.ticksPerSample;
      let sum = 0, count = 0;
      while (this.acc >= 1) { sum += this.tick(); count++; this.acc -= 1; }
      const x = count ? sum / count / 3 : this.dcIn;
      // the MSX sound output is AC coupled: remove the DC offset
      const y = x - this.dcIn + 0.9995 * this.dcOut;
      this.dcIn = x;
      this.dcOut = y;
      out[offset + i] = y * this.gain;
    }
  }
}
