#!/usr/bin/env bash
# Sole test entrypoint for this kata, enforced rather than requested:
# test_cart.py refuses to import without KATA_HARNESS=1, which only this script
# sets, so the audit log below always exists no matter how the suite is invoked. Appends an audit line per run so the
# red→green order (and whether the impl was still pristine at red time) is
# mechanically checkable from .check-log.
cd "$(dirname "$0")"
out=$(KATA_HARNESS=1 python3 -m unittest 2>&1); rc=$?
[ "$rc" -eq 0 ] && r=PASS || r=FAIL
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) RESULT=$r IMPL_SHA=$(sha256sum cart.py | cut -c1-16)" >> .check-log
printf '%s\n' "$out"
exit "$rc"
