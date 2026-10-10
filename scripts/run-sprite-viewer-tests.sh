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
"${runner[@]}" tests/sprite_viewer/test_selection.lua
"${runner[@]}" tests/sprite_viewer/test_layout.lua
"${runner[@]}" tests/sprite_viewer/test_virtual_sheet.lua
"${runner[@]}" tests/sprite_viewer/test_virtual_viewer.lua
"${runner[@]}" tests/sprite_viewer/test_compact_recovery.lua
"${runner[@]}" tests/sprite_viewer/test_visual_hierarchy.lua
"${runner[@]}" tests/sprite_viewer/test_assembly_navigation.lua
"${runner[@]}" tests/sprite_viewer/test_assembly_editing.lua
"${runner[@]}" tests/sprite_viewer/test_history.lua
