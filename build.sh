#!/bin/sh
# Build MSXTRACK as a 16KB MSX ROM cartridge image.
set -e
cd "$(dirname "$0")"
mkdir -p web/songs
python3 tools/gen_tables.py src/tables.inc web/js/tables.js
python3 tools/gen_song.py src/song_data.inc replayer/example/demo.mtk web/songs/new.mtk
cp replayer/example/demo.mtk songs/neon_run.mtk songs/pixel_sunrise.mtk web/songs/
mkdir -p build
(cd src && pasmo --bin main.asm ../build/full.bin ../build/msxtrack.sym)
head -c 16384 build/full.bin > build/msxtrack.rom
rm build/full.bin
grep -E "^(ROM_END|VARS_END|PATBASE)\b" build/msxtrack.sym
echo "built build/msxtrack.rom"
# standalone replayer + example cartridge
python3 tools/gen_replayer.py src tools replayer/mtkplay.asm
(cd replayer/example && pasmo --bin example.asm ../../build/example.rom)
echo "built replayer/mtkplay.asm and build/example.rom"
