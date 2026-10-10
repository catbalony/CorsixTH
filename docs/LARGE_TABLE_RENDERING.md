# Sprite Viewer: large-table rendering (v9)

This change deliberately improves the existing contact-sheet viewer rather than
creating another editor or changing the DAT/TAB decoding path.

## What was slow

The v8 gallery cached cell geometry, but on **every redraw** it iterated over
*all* cells to find the visible ones. `G` (Go to sprite) also searched that
entire cell list. With many sprites, scrolling did unnecessary O(N) work.

## Implementation

- `sprite_viewer_layout.lua` produces both the cell array and a compact row
  index (`first`, `last`, `y`, `bottom`) when it measures the sheet.
- On each frame, `Layout.visible_range` binary-searches row bottoms, then
  visits only rows intersecting the viewport. It returns inclusive cell
  indices rather than creating or copying new sprite arrays.
- The viewer draws and creates mouse hit boxes only for visible cells.
  Existing selection state is unaffected by virtualization.
- `G` jumps directly to `cells[sprite_id + 1]`, preserving the original
  scroll-into-view logic without searching the cell array.
- The `window_resized` event is registered alongside the older
  `window_resize` alias. Native SDL3 sends the former. A resize invalidates
  cached widths, wrapping, and row geometry.

**Complexity:** initial geometry remains O(N) time and memory on a table/zoom/
width change; ordinary redraw is O(log R + V) where R is the number of rows
and V is the number of cells in visible rows. This is **not** a fully lazy
loader; that would be a separate, more invasive redesign.

## Reproduce

Run `bash scripts/run-sprite-viewer-tests.sh` in the full fork, or
`bash scripts/run-tests.sh` in the standalone development bundle.
The new geometry and viewer tests use a synthetic **50,000-sprite** table,
cover 320/640 widths, zoom levels 1/2/4, compare visible rows against a
full-scan reference, jump to #49,999, and test native event dispatch names.
The synthetic sprites are not shipped game assets.

To test the **real** SDL application, install the separately supplied private
Theme Hospital resources as documented in `NATIVE_TESTING.md`, then run:

```sh
python3 scripts/native-smoke.py \
  --appimage /private/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data /private/ThemeHospitalData_extracted \
  --level /private/LEVEL.L1 \
  --resize-check
```

The resize check uses the actual X11 CorsixTH window, takes 320x200 gallery
and assembly screenshots plus a 640x480 screenshot, and validates their PNG
headers, output dimensions, fresh recipe contents, and the game's error log.
Tested with CorsixTH 0.70.1 on Linux Xvfb and the original PANEL04V resource.

## Known limitations

- The first layout still queries every sprite's dimensions and label width.
  Very large tables can incur a startup/reflow cost and use O(N) memory.
- Small-window typography still needs a separate UI/accessibility pass;
  rendering correctly at 320x200 does not make it comfortable to read.
- File data and original-game screenshots stay private; only independent
  tests, scripts, and documentation belong in this public repository.
