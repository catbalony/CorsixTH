#!/usr/bin/env bash
# Local-only Sprite Viewer acceptance; NEVER triggers GitHub Actions.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."

appimage="${APPIMAGE:-.local-test-assets/CorsixTH-v0.70.1-x86_64.AppImage}"
game_data="${GAME_DATA:-.local-test-assets/ThemeHospitalData_extracted}"
level="${LEVEL:-.local-test-assets/LEVEL.L1}"
report_root="${REPORT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/corsixth-release-XXXXXX")}"
mkdir -p "$report_root"
report_root="$(cd "$report_root" && pwd)"
report="$report_root/acceptance.md"
commit="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
printf '# Sprite Viewer release acceptance\n\nBranch commit: `%s`\n\n' "$commit" > "$report"
printf '| Check | Result | Log |\n| --- | --- | --- |\n' >> "$report"
failures=0

record() {
  local title="$1" status="$2" log="$3"
  printf '| %s | %s | `%s` |\n' "$title" "$status" "$log" >> "$report"
  printf '%-26s %s\n' "$title" "$status"
  if [[ "$status" != 'PASS' ]]; then failures=$((failures+1)); fi
}

check_asset() {
  local label="$1" path="$2" sha="$3"; local actual
  if [[ ! -f "$path" ]]; then
    record "$label SHA-256" 'FAIL (file missing)' "$path"; return
  fi
  actual="$(sha256sum "$path" | awk '{print $1}')"
  if [[ "$actual" == "$sha" ]]; then
    record "$label SHA-256" PASS "$path"
  else
    record "$label SHA-256" 'FAIL (checksum)' "$path"
  fi
}

if [[ "${VERIFY_ASSET_HASHES:-1}" == 1 ]]; then
  check_asset AppImage "$appimage" f228510a6a0e7450e836cd4aace5b2e278638c0ce91eaf00de81c27c06dab14d
  check_asset Level "$level" c792571dfaeee2b44fca9f3d5100e3baf878580657d471c10f24ba23ff032253
  # The original archive is not required at runtime once unpacked.
  if [[ -n "${DATA_ARCHIVE:-}" ]]; then
    check_asset GameArchive "$DATA_ARCHIVE" d2c58b020ae26354a03ec6182da8ff070601a4a95d53b4879b9c148590f4655e
  fi
fi

if [[ "$branch" != "feature/sprite-viewer-engineering" ]]; then
  record 'Engineering branch' 'FAIL (wrong branch)' "$report"
elif ! git diff --quiet || ! git diff --cached --quiet; then
  record 'Engineering checkout' 'FAIL (tracked edits)' "$report"
else
  record 'Engineering checkout' PASS "$report"
fi

if ! command -v python3 >/dev/null || ! command -v Xvfb >/dev/null || ! command -v timeout >/dev/null; then
  echo 'Missing required python3/Xvfb/timeout' >&2
  record Prerequisites FAIL "$report"
else
  record Prerequisites PASS "$report"
fi
if [[ ! -f "$appimage" || ! -f "$level" || ! -d "$game_data/DATA" || ! -d "$game_data/QDATA" ]]; then
  echo 'Missing private runtime input. Set APPIMAGE, LEVEL and GAME_DATA.' >&2
  record 'Native runtime inputs' FAIL "$report"
fi

lua_log="$report_root/lua-tests.log"
if bash scripts/run-sprite-viewer-tests.sh >"$lua_log" 2>&1; then
  record 'Lua regression suite' PASS "$lua_log"
else
  record 'Lua regression suite' FAIL "$lua_log"
fi

run_native() {
  local name="$1"; shift
  local log="$report_root/native-$name.log"
  if [[ ! -f "$appimage" || ! -f "$level" || ! -d "$game_data/DATA" ]]; then
    record "Native $name" 'SKIPPED (inputs missing)' "$log"; return
  fi
  if timeout "${NATIVE_TIMEOUT:-300}s" python3 scripts/native-smoke.py --appimage "$appimage" \
     --game-data "$game_data" --level "$level" \
     --workdir "$report_root/native-$name" "$@" >"$log" 2>&1; then
    record "Native $name" PASS "$log"
  else
    record "Native $name" FAIL "$log"
  fi
}

# Independent runs avoid the known combined-native-test timeout. Do not use a
# successful focused run as evidence that a different check passed.
run_native base
run_native drag --assembly-drag-check
run_native pick --assembly-pick-check
run_native edit-history --assembly-edit-check --assembly-history-check
run_native resize-navigation --resize-check --assembly-navigation-check

cat >> "$report" <<'EOF'

## Manual release checks (not proven by this automated runner)

- [ ] Type/release Q inside table search, palette search and help: remain in viewer; close overlay, then Q exits.
- [ ] Drag a layer, switch X11 window focus before mouse-up: offset and Undo history unchanged.
- [ ] Drag a layer, use the wheel before mouse-up: no edit committed, focus navigates normally.
- [ ] Inspect controls/text at 640x480 and after native 800x600 → 640x480 resize.
- [ ] Review all critical/major defects and proprietary-file exclusion; approve release explicitly.

No GitHub Actions or merges were initiated by this script. The report and all
native screenshots/recipes are private, outside the tracked repository.
EOF
printf '\nReport: %s\n' "$report"
if (( failures > 0 )); then
  printf '%s acceptance check(s) failed or were skipped.\n' "$failures" >&2
  exit 1
fi
printf 'All automated acceptance checks passed; manual release checks remain.\n'
