#!/bin/sh
# Runs the MSXTRACK smoke test in openMSX with the free C-BIOS.
# Needs: openmsx, cbios, xvfb-run (Debian/Ubuntu: apt install openmsx cbios xvfb)
set -e
cd "$(dirname "$0")/.."
./build.sh >/dev/null
SYMS=$(mktemp)
awk '{v=$3; sub(/H$/,"",v); printf "set ::sym(%s) 0x%s\n",$1,v}' build/msxtrack.sym > "$SYMS"
status=0
for machine in C-BIOS_MSX1 C-BIOS_MSX1_JP C-BIOS_MSX2 C-BIOS_MSX2+; do
  echo "== $machine"
  out=$(MSXT_SYMS="$SYMS" timeout 300 xvfb-run -a openmsx -machine "$machine" \
        -carta build/msxtrack.rom -script test/smoke.tcl 2>&1 | grep -aE "^(PASS|FAIL|RESULT)") || true
  echo "$out"
  echo "$out" | grep -q "RESULT fails=0" || status=1
done
rm -f "$SYMS"
[ $status -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $status
