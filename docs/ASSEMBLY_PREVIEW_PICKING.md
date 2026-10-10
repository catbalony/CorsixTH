# Assembly preview picking (v16)

This builds on the existing CorsixTH debug viewer. It does **not** change any
original game assets, sprite tables, palette encodings, or assembly recipes.
The contact sheet remains the default view; the composite editor is optional.

## Behaviour

- Click a visible sprite in the **assembly artwork** to focus that component.
  The checked components, repetition counts, layer offsets and undo history do
  not change. This applies to both adjacent strips and offset layers.
- In strip mode, clicking *any copy* of a repeated component focuses its single
  checked entry; individual copies are not independent items.
- In layers mode, normal click selects the last-drawn (frontmost) overlapping
  component. **Shift+click** at the same position cycles toward components
  behind the current focus, wrapping back to the front. If the current focus
  does not contain the clicked point, Shift+click starts at the frontmost.
- Empty regions, zero-size sprites, header, inspector buttons, component chips
  and footer are never interpreted as artwork clicks. Existing controls take
  precedence over the preview.
- A thin focus outline and the position/layer index in the footer show which
  component will be edited next. No sprite pixels are modified or tinted.

The hit region is the source sprite's **bounding rectangle**, not its opaque
pixel mask. CorsixTH's `sprite_table:draw` API does not expose a transparency
mask or a pixel-reading interface. This limitation is intentional and explicit;
clicking a transparent pixel *inside* a sprite rectangle can focus it. Using
fake guessed alpha would be less predictable.

## Engineering

`Layout.assembly_rects` calculates draw positions and hit rectangles in one
place from the same layout as the preview. The renderer uses these exact
rectangles, including repeated-copy spans, to avoid separate draw/pick geometry.
`Layout.assembly_pick` is a pure Lua function. It traverses layers in reverse
paint order and cycles matching rectangles only when requested. It requires
explicit preview top/bottom clip limits and ignores zero-size rectangles.

**No new persistence format** is needed. Clicking changes `focus_id` only and
reuses `FocusAssemblyIndex`, which reveals the target in a wide strip. It never
calls `History.perform` or mutates the selection/recipe.

## Test evidence

`tests/test_preview_picking.lua` uses synthetic non-square/zero-size sprites,
negative layer offsets, repeated strips, overlapping rectangles, exclusive edge
boundaries and footer clipping. It also runs the actual Lua event handlers,
checking topmost/Shift-cycle behaviour and confirming focus navigation does not
create undo entries or break existing undo/redo.

The separate **native CorsixTH 0.70.1** test may be run locally using the
private assets documented in `AGENTS.md`:

```sh
bash scripts/run-tests.sh
python3 scripts/native-smoke.py \
  --appimage .local-test-assets/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data .local-test-assets/ThemeHospitalData_extracted \
  --level .local-test-assets/LEVEL.L1 \
  --assembly-pick-check
```

The native test uses XTest mouse input on the actual SDL window and verifies
highlight pixels in fresh 640x480 PNGs for strip #8/#9 and overlapping-layer
#9→#8→#7. The native PNGs include proprietary game artwork and must remain
outside this public repository. Additional native tests can be combined with
`--resize-check`, `--assembly-navigation-check`, `--assembly-edit-check`, and
`--assembly-history-check` when resources permit.

GitHub Actions remains manually triggered only. No CI run is needed for this
change; validation is local.
