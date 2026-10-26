// Offline rendering of a song to MP3 or WAV.
import { Synth } from './synth.js';

export const EXPORT_RATE = 44100;
const MAX_SECONDS = 15 * 60;

// Render the song from the start until it has looped `loops` times.
// With fade, a few seconds of the loop are added while fading out.
export async function renderSong(songData, { hz = 60, loops = 1, fade = true, onProgress } = {}) {
  const sr = EXPORT_RATE;
  const synth = new Synth(sr, songData.slice(), hz);
  synth.engine.playStart(1, 0, 0);
  const chunk = 4096, fadeLen = sr * 4;
  const parts = [];
  let total = 0, wraps = 0, fadeAt = -1;   // fadeAt: sample where the end begins
  while (total < sr * MAX_SECONDS) {
    const buf = new Float32Array(chunk);
    synth.process(buf, chunk);
    if (synth.wrapped && fadeAt < 0) {
      synth.wrapped = false;
      if (++wraps >= loops) fadeAt = total + synth.wrapAt;
    }
    parts.push(buf);
    total += chunk;
    if (fadeAt >= 0 && total >= fadeAt + (fade ? fadeLen : 0)) break;
    if (onProgress && parts.length % 64 === 0) { onProgress(0.5 * Math.min(1, total / (sr * 180))); await tick(); }
  }
  const len = fadeAt < 0 ? total : fadeAt + (fade ? fadeLen : 0);
  const out = new Float32Array(len);
  let o = 0;
  for (const p of parts) { out.set(p.subarray(0, Math.min(p.length, len - o)), o); o += p.length; if (o >= len) break; }
  if (fade && fadeAt >= 0) for (let i = fadeAt; i < len; i++) out[i] *= (len - i) / fadeLen;
  return out;
}

export function toWav(samples, sr = EXPORT_RATE) {
  const buf = new ArrayBuffer(44 + samples.length * 2);
  const v = new DataView(buf);
  const str = (o, s) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  str(0, 'RIFF'); v.setUint32(4, 36 + samples.length * 2, true); str(8, 'WAVEfmt ');
  v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, sr, true); v.setUint32(28, sr * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true);
  str(36, 'data'); v.setUint32(40, samples.length * 2, true);
  const pcm = toPcm16(samples);
  new Int16Array(buf, 44).set(pcm);
  return new Blob([buf], { type: 'audio/wav' });
}

export async function toMp3(samples, { kbps = 192, sr = EXPORT_RATE, onProgress } = {}) {
  const lame = await loadLame();
  const enc = new lame.Mp3Encoder(1, sr, kbps);
  const pcm = toPcm16(samples);
  const out = [];
  const block = 1152 * 20;
  for (let i = 0; i < pcm.length; i += block) {
    const mp3 = enc.encodeBuffer(pcm.subarray(i, i + block));
    if (mp3.length) out.push(new Uint8Array(mp3));
    if (onProgress && (i / block) % 20 === 0) { onProgress(0.5 + 0.5 * i / pcm.length); await tick(); }
  }
  const end = enc.flush();
  if (end.length) out.push(new Uint8Array(end));
  return new Blob(out, { type: 'audio/mpeg' });
}

function toPcm16(samples) {
  const pcm = new Int16Array(samples.length);
  for (let i = 0; i < samples.length; i++) pcm[i] = Math.max(-32767, Math.min(32767, Math.round(samples[i] * 32767)));
  return pcm;
}

let lamePromise = null;
function loadLame() {
  if (globalThis.lamejs) return Promise.resolve(globalThis.lamejs);
  lamePromise ??= new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = new URL('../vendor/lame.min.js', import.meta.url).href;
    s.onload = () => (globalThis.lamejs ? resolve(globalThis.lamejs) : reject(new Error('MP3 encoder did not load')));
    s.onerror = () => reject(new Error('Could not load the MP3 encoder'));
    document.head.appendChild(s);
  });
  return lamePromise;
}

const tick = () => new Promise((r) => setTimeout(r, 0));
