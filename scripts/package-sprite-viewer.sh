#!/usr/bin/env bash
# Local, source-only review archive for CorsixTH Sprite Viewer.
# No native assets or game screenshots are ever read into this archive.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

branch="$(git symbolic-ref --quiet --short HEAD || true)"
[[ "$branch" == "feature/sprite-viewer-engineering" ]] || {
  echo "Must check out feature/sprite-viewer-engineering (got: ${branch:-detached})" >&2
  exit 1
}
git diff --quiet && git diff --cached --quiet || {
  echo 'Commit or discard changes before creating a release archive' >&2
  exit 1
}
command -v unzip >/dev/null || { echo 'Missing unzip' >&2; exit 1; }
commit="$(git rev-parse --verify HEAD)"
output_dir="${1:-${TMPDIR:-/tmp}/corsixth-sprite-viewer-package}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
archive="$output_dir/CorsixTH-SpriteViewer-v19-${commit:0:12}.zip"

# Explicit tracked-source whitelist: no DATA/ QDATA/ native build, AppImage,
# LEVEL.L1, private test files, extracted game resources or captured PNGs.
paths=(
  LICENSE.txt AGENTS.md
  CorsixTH/Lua/sprite_viewer.lua
  CorsixTH/Lua/sprite_viewer_assembly.lua
  CorsixTH/Lua/sprite_viewer_browser.lua
  CorsixTH/Lua/sprite_viewer_drag.lua
  CorsixTH/Lua/sprite_viewer_history.lua
  CorsixTH/Lua/sprite_viewer_layout.lua
  CorsixTH/Lua/sprite_viewer_recipe.lua
  CorsixTH/Lua/sprite_viewer_selection.lua
  scripts/native-smoke.py
  scripts/release-acceptance.sh
  scripts/run-sprite-viewer-tests.sh
  scripts/package-sprite-viewer.sh
)
while IFS= read -r path; do paths+=("$path"); done < <(
  git ls-files 'tests/sprite_viewer/*.lua' 'docs/*.md' 'docs/TEST_ASSET_SHA256.txt')
for path in "${paths[@]}"; do
  git cat-file -e "HEAD:$path" || {
    echo "Missing tracked release source: $path" >&2; exit 1
  }
done

git archive --format=zip \
  --prefix='CorsixTH-SpriteViewer-v19/' \
  --output="$archive" "$commit" -- "${paths[@]}"
unzip -tqq "$archive"
if unzip -Z1 "$archive" | grep -E \
   '(\.AppImage$|\.7z$|(^|/)(DATA|DATAM|QDATA|QDATAM|Screenshots)/|Level\.L1$|\.png$|\.local-)'; then
  echo 'Unsafe file detected in source archive; do not distribute' >&2
  rm -f "$archive"
  exit 1
fi

sha256sum "$archive" > "$archive.sha256"
{
  echo "Source-only engineering review archive"
  echo "Commit: $commit"
  echo "Branch: $branch"
  echo "Archive: $(basename "$archive")"
  echo "SHA256: $(cut -d' ' -f1 "$archive.sha256")"
  echo "Purpose: review and reproducible testing; NOT release acceptance."
  echo "Final release requires completed automatic and manual acceptance gates."
} > "$output_dir/REVIEW_STATUS.txt"
printf 'Review package: %s\nChecksum: %s\n' "$archive" "$archive.sha256"
printf 'NOT A SIGNED-OFF RELEASE: run scripts/release-acceptance.sh first.\n'
