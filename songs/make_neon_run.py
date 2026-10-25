#!/usr/bin/env python3
"""Compose "NEON RUN" and write it as an MSXTRACK song file (neon_run.mtk).

A minor, speed 6 (150 BPM on a 60Hz MSX), 64-row patterns = 4 bars each.
Channel A: lead, channel B: bass, channel C: drums.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
from gen_song import INSTRUMENTS, note, s8, T  # noqa: E402

# instruments: the presets, with slot 15 replaced by a sustained lead
INS = list(INSTRUMENTS)
INS[14] = ("LEAD", 4, 2, 0, 0, 0,
           [(11, 0, 0, 0, T), (15, 0, 0, 0, T), (14, 0, 0, 0, T), (13, 0, 0, 0, T),
            (12, 0, 0, 0, T)])
SQUARE, PLUCK, BASS, ARPMAJ, ARPMIN, KICK, SNARE, HIHAT, BUZZ = range(1, 10)
PAD, LEAD = 14, 15

A, B, C = 0, 1, 2
cells = {}  # (pattern, row, channel) -> [note, ins, vol, fx, param]


def put(p, row, ch, n=None, ins=0, vol=None, fx=None, par=0):
    c = cells.setdefault((p, row, ch), [0, 0, None, None, 0])
    if n is not None:
        c[0] = 97 if n == "off" else note(n)
    if ins:
        c[1] = ins
    if vol is not None:
        c[2] = vol
    if fx is not None:
        c[3], c[4] = fx, par


def melody(p, ch, ins, vol, seq, start=0):
    """seq: (note|None|'off', rows[, fx, param])"""
    r = start
    for item in seq:
        n, ln = item[0], item[1]
        if n is not None:
            put(p, r, ch, n, ins if n != "off" else 0, vol if n != "off" else None)
            if len(item) > 2:
                put(p, r, ch, fx=item[2], par=item[3])
        r += ln
    assert r <= 64, (p, r)


def vib(n, ln):          # long note with vibrato
    return (n, ln, 4, 0x42)


# ---- drums ----
def drums(p, bars=(0, 1, 2, 3), fill=False, hats=True):
    for b in bars:
        o = b * 16
        put(p, o, C, "C-3", KICK)
        put(p, o + 8, C, "C-3", KICK)
        put(p, o + 4, C, "C-4", SNARE)
        put(p, o + 12, C, "C-4", SNARE)
        if hats:
            for h in (2, 6, 10, 14):
                put(p, o + h, C, "C-6", HIHAT, 9)
    if fill:
        for r in (56, 58, 60, 61, 62, 63):
            put(p, r, C, "C-4", SNARE, 15 if r >= 60 else 12)


# ---- bass ----
ROOT = {"Am": "A-2", "F": "F-2", "C": "C-3", "G": "G-2", "Em": "E-2", "Dm": "D-2",
        "E": "E-2"}
OCT = {"Am": "A-3", "F": "F-3", "C": "C-4", "G": "G-3", "Em": "E-3", "Dm": "D-3",
       "E": "E-3"}


def bass(p, chords, style="pulse"):
    for b, ch in enumerate(chords):
        o = b * 16
        if style == "pulse":       # eighth notes, octave jump on the "and" of 2/4
            for k in range(0, 16, 2):
                put(p, o + k, B, OCT[ch] if k in (6, 14) else ROOT[ch], BASS, 13)
        elif style == "buzz":      # hardware-envelope bass, driving quarters
            for k in (0, 4, 8, 12):
                put(p, o + k, B, ROOT[ch], BUZZ)
            put(p, o + 14, B, OCT[ch], BUZZ)
        elif style == "long":
            put(p, o, B, ROOT[ch], BASS, 13)


def arps(p, ch_, chords, vol=10):
    for b, ch in enumerate(chords):
        root = {"Am": "A-4", "F": "F-4", "C": "C-5", "G": "G-4", "Em": "E-4",
                "Dm": "D-4", "E": "E-4"}[ch]
        put(p, b * 16, ch_, root, ARPMIN if ch in ("Am", "Em", "Dm") else ARPMAJ, vol)


VERSE = ["Am", "F", "C", "G"]

# P0 intro: chord arps + bass, drums join in the second half with a fill
arps(0, A, VERSE)
bass(0, VERSE)
drums(0, bars=(2, 3), fill=True)

# P1 verse
bass(1, VERSE)
drums(1)
melody(1, A, LEAD, 12, [
    ("E-5", 4), ("A-4", 2), ("C-5", 2), ("E-5", 4), ("D-5", 2), ("C-5", 2),
    ("A-4", 4), ("C-5", 2), ("F-5", 2), ("E-5", 4), ("C-5", 4),
    ("G-4", 4), ("C-5", 2), ("E-5", 2), vib("G-5", 6), ("F-5", 2),
    ("D-5", 4), ("B-4", 2), ("G-4", 2), vib("D-5", 6), ("off", 2)])

# P2 verse, second half of the tune
bass(2, VERSE)
drums(2)
melody(2, A, LEAD, 12, [
    ("E-5", 4), ("A-5", 4), ("G-5", 2), ("E-5", 2), ("C-5", 4),
    ("F-5", 4), ("E-5", 2), ("C-5", 2), vib("A-4", 6), ("C-5", 2),
    ("E-5", 4), ("D-5", 2), ("C-5", 2), ("G-4", 4), ("C-5", 2), ("E-5", 2),
    vib("D-5", 12), ("B-4", 4)])

# P3 bridge: F G Em Am, higher and smoother
BR1 = ["F", "G", "Em", "Am"]
bass(3, BR1)
drums(3)
melody(3, A, LEAD, 13, [
    ("C-6", 6), ("A-5", 2), ("F-5", 4), ("A-5", 4),
    ("B-5", 6), ("G-5", 2), ("D-5", 4), ("G-5", 4),
    ("E-5", 6), ("G-5", 2), ("B-5", 4), ("A-5", 2), ("G-5", 2),
    vib("A-5", 12), ("E-5", 4)])

# P4 bridge 2: Dm E F E, tension with a portamento up to the chorus
BR2 = ["Dm", "E", "F", "E"]
bass(4, BR2)
drums(4, fill=True)
melody(4, A, LEAD, 13, [
    ("F-5", 6), ("E-5", 2), ("D-5", 4), ("A-4", 4),
    ("G#4", 6), ("B-4", 2), vib("E-5", 8),
    ("A-5", 4), ("G-5", 2), ("F-5", 2), ("E-5", 4), ("D-5", 4),
    ("E-5", 4), ("B-5", 12, 3, 0x10)])

# P5 / P6 chorus: buzz bass, plucky lead, arpeggio effect on the long notes
for p in (5, 6):
    bass(p, VERSE, "buzz")
    drums(p, fill=(p == 6))
    melody(p, A, PLUCK, 14, [
        ("A-5", 2), ("A-5", 2), ("G-5", 2), ("A-5", 2), ("C-6", 4), ("A-5", 4, 0, 0x37),
        ("F-5", 2), ("F-5", 2), ("E-5", 2), ("F-5", 2), ("A-5", 4), ("F-5", 4, 0, 0x47),
        ("G-5", 2), ("G-5", 2), ("F-5", 2), ("G-5", 2), ("C-6", 4), ("E-6", 4, 0, 0x37),
        *([("D-6", 4), ("B-5", 4), ("G-5", 4), ("B-5", 4)] if p == 5 else
          [("D-6", 4), ("C-6", 2), ("B-5", 2), ("G-5", 4, 0, 0x47), ("B-5", 4)])])

# P7 outro: slow, with a fade on the last chord
OUT = ["Am", "F", "G", "Am"]
bass(7, OUT[:3], "long")
put(7, 48, B, "A-2", BASS, 13)
drums(7, bars=(0, 1, 2), hats=False)
put(7, 48, C, "C-3", KICK)
melody(7, A, LEAD, 12, [
    vib("E-5", 16), vib("C-5", 16), ("D-5", 8), ("B-4", 8), vib("A-4", 16)])
for k in range(11):                     # fade the final chord out
    put(7, 52 + k, A, vol=11 - k)
    put(7, 52 + k, B, vol=12 - k)
put(7, 63, A, "off")
put(7, 63, B, "off")

ORDERS = [0, 1, 2, 3, 4, 5, 6, 1, 2, 5, 6, 7]


def build():
    npat = max(p for p, _, _ in cells) + 1
    out = bytearray(b"MSXTRK") + bytes([1, npat])
    out += bytes([6, 64, len(ORDERS), 1]) + b"NEON RUN        " + bytes(12)
    out += bytes(ORDERS) + bytes(128 - len(ORDERS))
    out += bytes(96)
    for name, loop, speed, shape, emode, period, steps in INS:
        ins = bytearray(96)
        ins[0:8] = bytes([len(steps), 0xFF if loop is None else loop, speed, shape,
                          emode, period & 0xFF, period >> 8, 0])
        ins[8:16] = name.ljust(8)[:8].encode()
        for k, (v, a, sw, n, f) in enumerate(steps):
            ins[16 + 5 * k:21 + 5 * k] = bytes([v, s8(a), s8(sw), n, f])
        out += ins
    pats = bytearray(npat * 768)
    for (p, r, ch), (n, ins, vol, fx, par) in cells.items():
        o = p * 768 + r * 12 + ch * 4
        flags = (0x80 if vol is not None else 0) | (0x40 | fx if fx is not None else 0)
        pats[o:o + 4] = bytes([n, ins << 4 | (vol or 0), flags, par])
    return bytes(out + pats)


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "neon_run.mtk")
    data = build()
    open(path, "wb").write(data)
    secs = len(ORDERS) * 64 * 6 / 60
    print(f"{path}: {len(data)} bytes, {len(ORDERS)} positions, {secs:.1f}s at 60Hz")
