# Keystroke plan used to enter "Pixel Sunrise" into MSXTRACK through its own
# keyboard interface (driven in openMSX). Produces the list A of key actions.
# Keystroke plan for entering "PIXEL SUNRISE" through MSXTRACK's own UI.
A = []
def t(s):            # type characters
    for ch in s: A.append(("t", ch))
def k(name, n=1):
    m = {"left": (8,4), "up": (8,5), "down": (8,6), "right": (8,7), "home": (8,1),
         "ins": (8,2), "del": (8,3), "tab": (7,3), "bs": (7,5), "ret": (7,7), "esc": (7,2),
         "f1": (6,5), "f2": (6,6), "f3": (6,7), "f4": (7,0), "f5": (7,1)}[name]
    for _ in range(n):
        A.append(("f" if name.startswith("f") else "k",) + m)
def sk(name, n=1):   # with SHIFT
    m = {"left": (8,4), "right": (8,7)}[name]
    for _ in range(n): A.append(("s",) + m)
def ctrl(ch): A.append(("c", ch))
def wait(s): A.append(("w", s))

state = {"oct": 4, "ins": 1, "step": 1}
def octave(o):
    d = o - state["oct"]; t(("]" if d > 0 else "[") * abs(d)); state["oct"] = o
def ins(i):
    d = i - state["ins"]; t(("." if d > 0 else ",") * abs(d)); state["ins"] = i
def step(s):
    d = s - state["step"]; t(("=" if d > 0 else "-") * abs(d)); state["step"] = s
def goto_pos(p):     # song position in the pattern editor
    sk("left", 13); sk("right", p); k("home")
def goto_row(r):
    k("home"); k("down", r)
def chan(c):         # cursor to channel c, note column
    A.append(("chan", c))

# ---- 1. new song ----
k("f4"); t("n"); t("y"); wait(1.0)
# ---- 2. song settings + order list (F2) ----
k("f2")
t("PIXEL SUNRISE")
k("down", 2); t("20")            # 32 rows per pattern
k("down"); t("0D")               # 13 positions
k("down"); t("02")               # restart at position 2
k("down")                        # order list, position 0
for p in [0, 1, 2, 3, 2, 3, 4, 5, 4, 5, 2, 3, 6]:
    t("%02X" % p); k("right")
# ---- 3. turn instrument F (SIREN) into a soft LEAD (F3) ----
k("f3"); ins(15)
for vol in "BFEDC":              # steps 0-4: volume, pitch sweep 00
    t(vol); k("right", 2); t("00"); k("left", 2); k("down")
k("up", 7)                       # LENGTH
t("05"); k("right"); t("4")      # loop back to step 4
k("right"); t("02")              # speed 2
k("up"); t("LEAD    ")           # name
# ---- 4. patterns (F1) ----
k("f1")
# P0 (pos 0): drums on channel C, bass C/G on channel B
goto_pos(0); chan(2)
step(8); octave(3); ins(6); goto_row(0); t("zzzz")          # kicks 0 8 16 24
octave(4); ins(7); goto_row(4); t("zzzz")                    # snares 4 12 20 28
step(4); octave(6); ins(8); goto_row(2); t("zzzzzzzz")       # hats every 4 rows
ctrl("c")                                                     # copy drum track
chan(1); step(2); octave(2); ins(3); goto_row(0)
t("zzzqzzzq" + "bbbtbbbt")                                   # C2.. / G2..
# P1 (pos 1): drums + bass Am/F
goto_pos(1); chan(2); ctrl("v")
chan(1); goto_row(0); t("nnnynnny" + "vvvrvvvr")
# P2/P3 get the same bass and drums
for src, dst in ((0, 2), (1, 3)):
    goto_pos(src); chan(1); ctrl("c"); goto_pos(dst); ctrl("v")     # bass
    goto_pos(0); chan(2); ctrl("c"); goto_pos(dst); ctrl("v")       # drums
# P4/P5: drums + buzz bass (instrument 9)
for pos, roots in ((6, "zb"), (7, "nv")):
    goto_pos(pos); chan(2); ctrl("v")
    chan(1); ins(9); octave(2); step(4); goto_row(0)
    for r in roots:
        t(r * 4)
# fill at the end of P5: snares on rows 28-31
goto_pos(7); chan(2); ins(7); octave(4); step(1); goto_row(28); t("zzzz")

# ---- 5. melodies on channel A, instrument F (LEAD), octave 4 keys ----
MEL = {
  2: [(0,"e"),(4,"t"),(6,"e"),(8,"q"),(12,"w"),(14,"e"),(16,"w"),(20,"m"),(22,"b"),(24,"w*"),(30,"1")],
  3: [(0,"q"),(4,"e"),(6,"y"),(8,"t"),(12,"e"),(16,"r"),(20,"e"),(22,"q"),(24,"n*")],
  4: [(0,"t"),(2,"t"),(4,"y"),(6,"t"),(8,"e"),(12,"i"),(16,"u"),(20,"y"),(22,"t"),(24,"w*")],
  5: [(0,"i"),(2,"u"),(4,"y"),(8,"e"),(12,"y"),(16,"t"),(18,"r"),(20,"e"),(24,"r"),(28,"t")],
}
POS = {2: 2, 3: 3, 4: 6, 5: 7}
ins(15); octave(4); step(2)
for pat, notes in MEL.items():
    goto_pos(POS[pat]); chan(0); goto_row(0)
    row = 0
    for r, key in notes:
        while row < r:
            k("del"); row += 2          # DEL on an empty row just moves on
        t(key[0]); row += 2
        if key.endswith("*"):            # vibrato 442 on the long note
            k("up", 2); k("right", 3); t("442"); k("left", 3)
# ---- 6. outro P6 (pos 12): long notes, vibrato, kick, bass, fade ----
goto_pos(12); chan(0); goto_row(0); step(8)
t("e"); t("w"); t("q")                                   # E5 D5 C5 (rows 0, 8, 16)
k("up", 8); k("right", 3); t("442"); k("left", 3)
chan(1); ins(3); octave(2); goto_row(0); t("z"); goto_row(16); t("z")
chan(2); ins(6); octave(3); goto_row(0); t("z"); goto_row(16); t("z")
chan(0); step(1); goto_row(20); k("right", 2)            # volume column: fade
t("CBA987654321")
k("left", 2)
chan(1); goto_row(20); k("right", 2); t("CBA987654321"); k("left", 2)
chan(0); goto_row(31); t("1")                            # note off at the end

# ---- 7. save to disk, then play the song from the start ----
k("f4"); t("s"); k("bs", 8); t("SUNRISE"); k("ret")
wait(1.0)
k("f1"); goto_pos(0)
A.append(("play",))
