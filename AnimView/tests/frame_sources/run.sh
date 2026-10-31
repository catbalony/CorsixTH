#!/usr/bin/env bash
# Native C++ engine validation with TEST-ONLY wx substitutes, not a GUI build.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
python3 "$HERE/generate_fixtures.py" "$OUT"
CXX=${CXX:-c++}
INC=(-I"$HERE/verification/test-only-wx-stubs" -I"$HERE/verification/config" -I"$ROOT/AnimView" -I"$ROOT/libs/rnc")
FLAGS=(-std=c++17 -O1 -g)
if [[ ${1:-} == --sanitizers ]]; then
  FLAGS+=(-fno-omit-frame-pointer -fsanitize=address,undefined)
  export ASAN_OPTIONS=detect_leaks=1:halt_on_error=1
  export UBSAN_OPTIONS=halt_on_error=1
fi
for test in test_load_recovery test_frame_sources; do
  "$CXX" "${FLAGS[@]}" "${INC[@]}" \
    "$HERE/tests/$test.cpp" "$ROOT/AnimView/th.cpp" "$ROOT/libs/rnc/rnc.cpp" \
    -o "$OUT/$test"
done
"$OUT/test_load_recovery" "$OUT/fixture" "$OUT/recovery"
"$OUT/test_frame_sources" "$OUT/source-synthetic" "$OUT/malformed" "$OUT/source-transparent"
printf 'PASS: native core checks (not the wxWidgets UI)\n'
