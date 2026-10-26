#!/bin/sh
# Tests for MSXTRACK Web:
#  1. the JavaScript engine writes exactly the same PSG registers as the
#     Z80 tracker (reference logs recorded in openMSX)
#  2. the app in headless Chromium (needs Node's "playwright" package)
set -e
cd "$(dirname "$0")/../.."
status=0
for s in demo:web/songs/demo.mtk neon_run:songs/neon_run.mtk pixel_sunrise:songs/pixel_sunrise.mtk; do
  node test/web/engine_equiv.mjs "${s#*:}" "test/web/ref/${s%%:*}.log.gz" || status=1
done
if node -e "require('playwright')" 2>/dev/null; then
  PORT=8765
  (cd web && python3 -m http.server $PORT >/dev/null 2>&1) &
  SERVER=$!
  sleep 1
  OUT=$(mktemp -d)
  node test/web/ui_smoke.cjs "http://localhost:$PORT/" "$OUT" || status=1
  kill $SERVER
  rm -rf "$OUT"
else
  echo "(playwright not installed: skipping the browser test)"
fi
[ $status -eq 0 ] && echo "WEB TESTS PASSED" || echo "WEB TESTS FAILED"
exit $status
