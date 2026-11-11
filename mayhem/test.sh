#!/usr/bin/env bash
#
# mayhem/test.sh — RUN upstream's own C unit tests of the compiler internals (tests/unit/, utest.h),
# built by mayhem/build.sh with the project's normal flags. Parses utest's own summary lines, so a
# neutered binary (no output) fails loudly instead of passing on its exit code.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

RUNNER=obj/tests/unit/run_unit
[ -x "$RUNNER" ] || { echo "missing $RUNNER (mayhem/build.sh builds it)" >&2; emit_ctrf utest 0 1; exit 1; }

out=$("$RUNNER" 2>&1); echo "$out" | tail -15
passed=$(echo "$out" | sed -n 's/^\[  PASSED  \] \([0-9]*\) tests\?\.$/\1/p' | tail -1)
failed=$(echo "$out" | sed -n 's/^\[  FAILED  \] \([0-9]*\) tests\?, listed below:$/\1/p' | tail -1)
if [ -z "$passed" ] || [ "$passed" -eq 0 ]; then
  echo "no utest summary found" >&2; emit_ctrf utest 0 1; exit 1
fi
emit_ctrf utest "$passed" "${failed:-0}"
