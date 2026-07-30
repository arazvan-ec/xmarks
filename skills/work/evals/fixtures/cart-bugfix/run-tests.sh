#!/usr/bin/env bash
# Test entrypoint for this project. Sets the harness flag the suite requires
# (test_cart.py refuses to import without it) and appends a timestamped result
# line to .check-log.
cd "$(dirname "$0")"
out=$(KATA_HARNESS=1 python3 -m unittest 2>&1); rc=$?
[ "$rc" -eq 0 ] && r=PASS || r=FAIL
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) RESULT=$r IMPL_SHA=$(sha256sum cart.py | cut -c1-16)" >> .check-log
printf '%s\n' "$out"
exit "$rc"
