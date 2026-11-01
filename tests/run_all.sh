#!/bin/sh
# Runs the CC:Tweaked simulator scenarios (needs python3 + lupa: pip install lupa)
# Usage: tests/run_all.sh        (from the repository root)
cd "$(dirname "$0")" || exit 1
for t in t_*.lua; do
  out=$(REPO="$(cd .. && pwd)" timeout 120 python3 harness.py "$t" 2>&1)
  if echo "$out" | grep -q "FAIL\|Traceback"; then echo "FAIL $t"; else echo "ok   $t"; fi
done
