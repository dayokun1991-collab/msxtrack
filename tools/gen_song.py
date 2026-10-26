#!/usr/bin/env python3
"""Generate the default instrument set and the demo song for MSXTRACK."""
import sys

T, N, E = 1, 2, 4
NAMES = ["C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"]


def note(name):
    """'C#4' -> 1..96"""
    semi = NAMES.index(name[:2])
    octv = int(name[2])
    return (octv - 1) * 12 + semi + 1


def s8(v):
    return v & 0xFF


# (name, loop, speed, shape, emode, period, [(vol, arp, sweep, noise, flags), ...])
INSTRUMENTS = [
    ("SQUARE", 0, 1, 0, 0, 0, [(15, 0, 0, 0, T)]),
    ("PLUCK", None, 2, 0, 0, 0,
     [(15, 0, 0, 0, T), (13, 0, 0, 0, T), (11, 0, 0, 0, T), (10, 0, 0, 0, T),
      (9, 0, 0, 0, T), (8, 0, 0, 0, T), (7, 0, 0, 0, T), (6, 0, 0, 0, T)]),
    ("BASS", 3, 1, 0, 0, 0,
     [(15, 12, 0, 0, T), (14, 0, 0, 0, T), (13, 0, 0, 0, T), (12, 0, 0, 0, T)]),
    ("ARP MAJ", 0, 1, 0, 0, 0,
     [(12, 0, 0, 0, T), (12, 4, 0, 0, T), (12, 7, 0, 0, T)]),
    ("ARP MIN", 0, 1, 0, 0, 0,
     [(12, 0, 0, 0, T), (12, 3, 0, 0, T), (12, 7, 0, 0, T)]),
    ("KICK", None, 1, 0, 0, 0,
     [(15, 0, 40, 0, T), (14, 0, 60, 0, T), (12, 0, 80, 0, T), (9, 0, 100, 0, T),
      (5, 0, 120, 0, T), (0, 0, 0, 0, 0)]),
    ("SNARE", None, 1, 0, 0, 0,
     [(15, 0, 20, 6, T | N), (13, 0, 0, 8, N), (11, 0, 0, 10, N), (8, 0, 0, 12, N),
      (5, 0, 0, 14, N), (2, 0, 0, 16, N), (0, 0, 0, 0, 0)]),
    ("HIHAT", None, 1, 0, 0, 0,
     [(11, 0, 0, 1, N), (7, 0, 0, 1, N), (3, 0, 0, 1, N), (0, 0, 0, 0, 0)]),
    ("BUZZBASS", 0, 1, 0x0C, 2, 0, [(15, 0, 0, 0, T | E)]),
    ("LASER", None, 1, 0, 0, 0,
     [(15, 0, 6, 0, T), (14, 0, 8, 0, T), (13, 0, 10, 0, T), (12, 0, 12, 0, T),
      (11, 0, 14, 0, T), (10, 0, 16, 0, T), (8, 0, 18, 0, T), (6, 0, 20, 0, T),
      (4, 0, 22, 0, T), (0, 0, 0, 0, 0)]),
    ("EXPLODE", None, 4, 0, 0, 0,
     [(15, 0, 0, 31, N), (15, 0, 0, 28, N), (14, 0, 0, 31, N), (13, 0, 0, 31, N),
      (12, 0, 0, 31, N), (11, 0, 0, 31, N), (10, 0, 0, 31, N), (9, 0, 0, 31, N),
      (8, 0, 0, 31, N), (7, 0, 0, 31, N), (6, 0, 0, 31, N), (5, 0, 0, 31, N),
      (4, 0, 0, 31, N), (3, 0, 0, 31, N), (2, 0, 0, 31, N), (0, 0, 0, 0, 0)]),
    ("COIN", None, 3, 0, 0, 0,
     [(14, 0, 0, 0, T), (14, 5, 0, 0, T), (12, 5, 0, 0, T), (9, 5, 0, 0, T),
      (5, 5, 0, 0, T), (0, 0, 0, 0, 0)]),
    ("JUMP", None, 1, 0, 0, 0,
     [(14, 0, -4, 0, T), (14, 0, -5, 0, T), (13, 0, -6, 0, T), (13, 0, -7, 0, T),
      (12, 0, -8, 0, T), (11, 0, -9, 0, T), (9, 0, -10, 0, T), (7, 0, -11, 0, T),
      (4, 0, -12, 0, T), (0, 0, 0, 0, 0)]),
    ("PAD", 15, 2, 0, 0, 0,
     [(v, 0, 0, 0, T) for v in (2, 4, 6, 8, 9, 10, 11, 12, 12, 12, 12, 12, 12, 12, 11, 12)]),
    ("SIREN", 0, 1, 0, 0, 0,
     [(12, 0, -3, 0, T)] * 8 + [(12, 0, 3, 0, T)] * 8),
]


def instruments():
    out = ["def_instr:"]
    for name, loop, speed, shape, emode, period, steps in INSTRUMENTS:
        nm = name.ljust(8)[:8]
        loop = 0xFF if loop is None else loop
        out.append(f'        db "{nm}",{len(steps)},{loop},{speed},{shape},{emode},'
                   f'{period & 0xFF},{period >> 8}')
        for v, a, sw, n, f in steps:
            out.append(f"        db {v},{s8(a)},{s8(sw)},{n},{f}")
    out.append(f"DEF_INSCOUNT equ {len(INSTRUMENTS)}")
    return out


# ---- demo song: 32-row patterns ----
PATLEN = 32
events = []  # (pattern, row, channel, note, instrument)


def put(p, r, ch, n, ins):
    events.append((p, r, ch, note(n) if isinstance(n, str) else n, ins))


CHORDS = [("A-", 5), ("F-", 4), ("C-", 4), ("G-", 4)]  # root, arp instrument
for p in (0, 1, 2):
    for bar, (root, arp) in enumerate(CHORDS):
        base = bar * 8
        # drums
        put(p, base + 0, 2, "C-3", 6)
        put(p, base + 4, 2, "C-4", 7)
        put(p, base + 2, 2, "C-6", 8)
        put(p, base + 6, 2, "C-6", 8)
        if p == 2:
            put(p, base + 7, 2, "C-6", 8)
        # bass
        boct = "3" if root == "C-" else "2"
        if p == 2:
            for k in (0, 4):
                put(p, base + k, 1, root + boct, 9)
        else:
            for k in range(0, 8, 2):
                put(p, base + k, 1, root + boct, 3)
        if p == 2:
            put(p, base, 0, root + ("5" if root == "C-" else "4"), arp)

melody = [(0, "E-5"), (4, "C-5"), (6, "D-5"), (8, "C-5"), (12, "A-4"), (16, "G-4"),
          (18, "A-4"), (20, "C-5"), (24, "B-4"), (28, "G-4")]
for r, n in melody:
    put(1, r, 0, n, 2)

ORDERS = [0, 1, 1, 2, 2]


def demo():
    out = ["demo_hdr:",
           f"        db 6,{PATLEN},{len(ORDERS)},1",
           '        db "DEMO TUNE       "',
           "        db " + ",".join(str(o) for o in ORDERS),
           "demo_data:"]
    for p, r, ch, n, ins in sorted(events):
        out.append(f"        db {p},{r | (ch << 6)},{n},{ins << 4}")
    out.append("        db 0FFh")
    out.append(f"DEMO_ORDLEN equ {len(ORDERS)}")
    return out


def demo_mtk(empty=False):
    """The demo song as a .MTK file, byte for byte what MSXTRACK saves.
    empty=True gives what the tracker's "New song" makes."""
    npat = 1 if empty else max(p for p, *_ in events) + 1
    out = bytearray(b"MSXTRK") + bytes([1, npat])
    if empty:
        out += bytearray([6, 64, 1, 0]) + b"SONG            " + bytes(12) + bytes(128)
    else:
        out += bytearray([6, PATLEN, len(ORDERS), 1]) + b"DEMO TUNE       " + bytes(12)
        out += bytes(ORDERS) + bytes(128 - len(ORDERS))
    out += bytes(96)  # instrument slot 0 is unused
    for name, loop, speed, shape, emode, period, steps in INSTRUMENTS:
        ins = bytearray(96)
        loop = 0xFF if loop is None else loop
        ins[0:8] = bytes([len(steps), loop, speed, shape, emode, period & 0xFF, period >> 8, 0])
        ins[8:16] = name.ljust(8)[:8].encode()
        for k, (v, a, sw, n, f) in enumerate(steps):
            ins[16 + 5 * k:21 + 5 * k] = bytes([v, s8(a), s8(sw), n, f])
        out += ins
    pats = bytearray(npat * 768)
    for p, r, ch, n, ins in ([] if empty else events):
        o = p * 768 + r * 12 + ch * 4
        pats[o] = n
        pats[o + 1] = ins << 4
    return bytes(out + pats)


if __name__ == "__main__":
    with open(sys.argv[1], "w") as f:
        f.write("; Generated by tools/gen_song.py - do not edit\n\n")
        f.write("\n".join(instruments() + [""] + demo()) + "\n")
    if len(sys.argv) > 2:
        with open(sys.argv[2], "wb") as f:
            f.write(demo_mtk())
    if len(sys.argv) > 3:
        with open(sys.argv[3], "wb") as f:
            f.write(demo_mtk(empty=True))
