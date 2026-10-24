#!/bin/sh
# Build MSXTRACK as a 16KB MSX ROM cartridge image.
set -e
cd "$(dirname "$0")"
python3 tools/gen_tables.py src/tables.inc
python3 tools/gen_song.py src/song_data.inc
mkdir -p build
(cd src && pasmo --bin main.asm ../build/full.bin ../build/msxtrack.sym)
head -c 16384 build/full.bin > build/msxtrack.rom
rm build/full.bin
grep -E "^(ROM_END|VARS_END|PATBASE)\b" build/msxtrack.sym
echo "built build/msxtrack.rom"
