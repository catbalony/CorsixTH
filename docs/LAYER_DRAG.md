# Controlled layer dragging (v17)

The assembly inspector offers direct drag positioning **in Layers mode only**.
Strip mode continues to use ordered components, copies and horizontal panning.
Normal click focuses a layer; Shift-click cycles overlapping rectangles, as
before. The user can then drag that chosen layer.

- Press and hold the left mouse button over visible layer artwork, move, release.
  The footer previews integer **source-pixel** coordinates while dragging.
- Hold **Ctrl** for 8-source-pixel grid snapping (applied to absolute XY source
  offsets; works for positive and negative coordinates). No modifier means
  1-pixel precision, regardless of displayed zoom.
- Motions shorter than 3 display pixels behave as ordinary clicks and do not
  consume history. Motion events update only a temporary in-memory preview;
  mouse release commits **one** bounded undo entry, not an entry per event.
- **Esc**, changing view, resizing the window, or closing the viewer cancels a
  pending drag and restores its original source coordinates without history.
- The preview origin and zoom are frozen during a drag, so moving a negative
  offset cannot recenter the whole composite mid-gesture. After release the
  normal assembly geometry is recalculated. Coordinates remain bounded to
  [-4096, 4096] in the existing recipe format.

The pure `sprite_viewer_drag.lua` helper converts pointer deltas to source
coordinates. `sprite_viewer_assembly.lua` validates and applies offsets.
`History.perform` is called only at drag completion. Sprite draw and picking
still share the v16 geometry; no game data is modified.

## Evidence

`tests/test_drag.lua` verifies threshold, zoom and negative rounding, grid
snapping, bounding, 30 live motion events → one Undo, redo invalidation,
Escape/mode-switch/resize cancellation and pointer click boundaries.

Run the real SDL integration using the private AppImage, level and DAT/TAB
assets (see `AGENTS.md`), keeping all outputs out of the public repository:

```sh
bash scripts/run-tests.sh
python3 scripts/native-smoke.py \
  --appimage .local-test-assets/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data .local-test-assets/ThemeHospitalData_extracted \
  --level .local-test-assets/LEVEL.L1 \
  --assembly-drag-check
```

Native run: real 640x480 CorsixTH 0.70.1, six XTest mouse-motion events with
Ctrl held, one release, Ctrl+Z, save the undone recipe, Ctrl+Y, save final.
The fresh recipe contains sprite #9 offset `(16,8)` and its `.bak1` has
`(0,0)` offsets for all nine. The AppImage log contains no Lua exceptions.

Dragging is rectangle-hit-tested, not alpha-aware, consistent with v16.

See `docs/RELEASE_ROADMAP.md`: **no new feature subsystems after v17**.
