# Assembly component navigation (v12)

The optional assembly inspector uses CorsixTH's native sprite renderer.
No original Theme Hospital sprite, palette or game asset is altered.

## User interaction

- **J/K** changes the active component in checked order, without changing
  which sprites are checked.
- **PageUp/PageDown** focuses the first component of the adjacent stable
  page. **Home/End** focuses the first/last checked component.
- Chip positions remain stable within a page. Click a component chip or the
  previous/next page button to navigate.
- In **strip** mode a compact overview track appears only when the composite
  exceeds the viewport width. Grey represents the full strip; muted teal the
  visible portion; amber marks the active component's real pixel span,
  including repetitions. Clicking the track locates a component at that
  **source-pixel position** and centres it if possible.
- `,` and `.` reorder the focused component and keep it visible. **Layers**
  mode still uses explicit offsets and stable pages, but no misleading
  positional overview.

The overview changes only the preview viewport, never the saved recipe or
the underlying sprite positions. This is a developer inspector, not a new
drag-and-drop editor.

## Structure and regression evidence

`Layout.assembly_page`, `Layout.assembly_page_target`,
`Layout.strip_overview`, `Layout.strip_pick`, and
`Layout.center_strip` in `CorsixTH/Lua/sprite_viewer_layout.lua` are pure,
SDL-independent functions. The entry point handles rendering and native
mouse/keyboard events.

`tests/sprite_viewer/test_assembly_navigation.lua` checks stable paging
of sequences with up to 127 components across several page capacities,
repeat counts, zero-width entries, proportional mapping and viewport
boundaries. The standalone development bundle also contains a historical
mocked-SDL interaction suite (`tests/test_v5.lua`) that exercises the real
viewer Lua event handlers at 640x480 and 320x200.

`scripts/native-smoke.py --assembly-navigation-check` sends genuine X11
Home/End/PageUp/PageDown keystrokes and mouse clicks to a 640x480 running
CorsixTH 0.70.1 window. It validates distinct screenshots from a fresh
directory and the game's error log. `--resize-check` additionally forces
320x200 and back and validates the exported PNG dimensions.

**Known native compact mouse limitation:** With the smoke test's forced
`XResizeWindow` resize to 320x200, CorsixTH can draw into only part of the
resized surface; physical cursor positions did not reliably hit controls.
**Do not claim a verified 320x200 native mouse interaction test.** This is
currently covered with mocked Lua events, while native compact rendering
is separately checked. A window-manager resize acceptance test remains
outstanding.

## Lua multi-return pitfall

`size_of(sprite_id)` returns two values: width and height. When its call
appears as the final argument to `math.max`, Lua expands both values and
may incorrectly use height for horizontal hit testing. The width must be
captured in a local first. A targeted regression uses a sprite narrower
than its height.

## Repeat locally

```sh
bash scripts/run-sprite-viewer-tests.sh

python3 scripts/native-smoke.py \
  --appimage /private/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data /private/ThemeHospitalData_extracted \
  --level /private/LEVEL.L1 \
  --assembly-navigation-check --resize-check
```

The original game files, AppImage and resulting game-art screenshots stay in
gitignored local directories and must never be committed to the public fork.
The dedicated GitHub Actions workflow remains **manual-only**.
