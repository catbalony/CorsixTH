#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LUA_PATH="CorsixTH/Lua/?.lua;;${LUA_PATH:-}"
if command -v lua >/dev/null 2>&1; then
  runner=(lua)
elif command -v luatex >/dev/null 2>&1; then
  runner=(luatex --luaonly)
else
  echo "Install lua or luatex before running Sprite Viewer tests" >&2
  exit 1
fi
"${runner[@]}" tests/sprite_viewer/test_browser.lua
"${runner[@]}" tests/sprite_viewer/test_recipe.lua
