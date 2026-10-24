#!/usr/bin/env python3
"""Build replayer/mtkplay.asm, the standalone game replayer.

The engine is the tracker's own src/player_core.asm, so songs sound exactly
the same in games as in the editor. Every label is given an mtk_ prefix so
the file can be included in other programs without name clashes.
"""
import re
import sys

KEYWORDS = set("""
a b c d e h l i r af bc de hl sp ix iy ixh ixl iyh iyl
nz z nc po pe p m
adc add and bit call ccf cp cpd cpdr cpi cpir cpl daa dec di djnz ei ex exx
halt im in inc ind indr ini inir jp jr ld ldd lddr ldi ldir neg nop or otdr
otir out outd outi pop push res ret reti retn rl rla rlc rlca rld rr rra rrc
rrca rrd rst sbc scf set sla sll sra srl sub xor
equ db dw ds defb defw defs org include incbin
""".split())
IDENT = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")


def code_and_comment(line):
    in_str = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_str = not in_str
        elif ch == ";" and not in_str:
            return line[:i], line[i:]
    return line, ""


def rename(text, names):
    out = []
    for line in text.split("\n"):
        code, comment = code_and_comment(line)
        parts = re.split(r'("[^"]*")', code)  # leave strings alone
        for k in range(0, len(parts), 2):
            parts[k] = IDENT.sub(
                lambda m: "mtk_" + m.group(0) if m.group(0) in names else m.group(0),
                parts[k])
        out.append("".join(parts) + comment)
    return "\n".join(out)


def identifiers(text):
    found = set()
    for line in text.split("\n"):
        code, _ = code_and_comment(line)
        code = re.sub(r'"[^"]*"', "", code)
        for tok in IDENT.findall(code):
            if tok.lower() not in KEYWORDS and not re.fullmatch(r"[0-9A-Fa-f]+[hH]", tok):
                found.add(tok)
    return found


def main(src_dir, tools_dir, out_path):
    core = open(f"{src_dir}/player_core.asm").read()
    tables = open(f"{src_dir}/tables.inc").read()
    glue = open(f"{tools_dir}/replayer_glue.asm").read()
    names = identifiers(core) | identifiers(tables)
    body = rename(core, names) + "\n" + rename(tables, names)
    header = open(f"{tools_dir}/replayer_header.asm").read()
    with open(out_path, "w") as f:
        f.write(header + "\n" + glue + "\n" + body + "\n")


if __name__ == "__main__":
    main(*sys.argv[1:4])
