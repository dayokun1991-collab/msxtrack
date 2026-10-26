// Help texts, worded like the MSX tracker's hint lines.
export const FX = [
  ['0xy', 'Arpeggio', 'note, +x, +y semitones, repeating'],
  ['1xx', 'Slide up', 'raise the pitch by xx every tick'],
  ['2xx', 'Slide down', 'lower the pitch by xx every tick'],
  ['3xx', 'Portamento', 'glide to this note, speed xx'],
  ['4xy', 'Vibrato', 'speed x, depth y'],
  ['5xx', 'Envelope period high', 'hardware envelope period, high byte'],
  ['6xx', 'Envelope period low', 'hardware envelope period, low byte'],
  ['7xy', 'Envelope shape', 'shape y, restarts the envelope'],
  ['8xx', 'Noise period', 'noise period xx (20 or more = the instrument\'s)'],
  ['9xx', 'Delay', 'start the note xx ticks late'],
  ['Axy', 'Volume slide', 'up x or down y every tick'],
  ['Bxx', 'Jump', 'continue at song position xx'],
  ['Cxx', 'Cut', 'stop the note after xx ticks'],
  ['Dxx', 'Break', 'next position, starting at row xx'],
  ['Exx', 'Detune', 'signed offset to the tone period'],
  ['Fxx', 'Speed', 'xx ticks per row'],
];

export const COL_HINTS = [
  '<b>Note</b> — piano keys Z…M / Q…P, <b>1</b> note off, <b>[ ]</b> octave, <b>, .</b> instrument, <b>Delete</b> clears.',
  '<b>Instrument</b> 1–F for this note (0 = keep the previous one).',
  '<b>Volume</b> 0–F for this note (Delete = keep the channel volume).',
  '<b>Effect</b> — type 0–F, then two digits.',
];

export const SHAPES = [
  '0 ╲___ decay', '1 ╲___ decay', '2 ╲___ decay', '3 ╲___ decay',
  '4 ╱___ attack', '5 ╱___ attack', '6 ╱___ attack', '7 ╱___ attack',
  '8 ╲╲╲╲ saw down', '9 ╲___ decay', 'A ╲╱╲╱ triangle', 'B ╲‾‾‾ decay, high',
  'C ╱╱╱╱ saw up', 'D ╱‾‾‾ attack, hold', 'E ╱╲╱╲ triangle', 'F ╱___ attack',
];

export const JAM_HINT = '<b>JAM</b> — keys only play notes. Press <b>`</b> or the REC button to write again.';
