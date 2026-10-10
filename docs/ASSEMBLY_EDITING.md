# Assembly editing controls (v14)

## Intent

CorsixTH's original contact-sheet browser remains the default. Assembly is a
secondary inspection mode for composing original Theme Hospital sprite entries,
not a new game asset editor. The restrained toolbar lives above the assembly
footer and uses native CorsixTH bitmap text and rectangles.

## Controls and edit semantics

Both the keyboard and the mouse call the same `Assembly.apply` function in
`CorsixTH/Lua/sprite_viewer_assembly.lua`.

| Operation | Mouse | Keyboard |
|---|---|---|
| Reorder active component | `Order <` / `Order >` | `,` / `.` |
| Adjust repetitions (strip only) | `Copies -` / `Copies +` | `N` to enter a number |
| Move layer horizontally (layers only) | `X -` / `X +` | Left / Right |
| Move layer vertically (layers only) | `Y -` / `Y +` | Up / Down |
| Bigger layer movement | Shift + click X/Y | Shift + arrow (8 pixels) |
| Restore active component defaults | `Reset` | `R` |

Controls at selection boundaries are visibly disabled and have no click
hitboxes. The focused component stays focused after reordering. Keyboard
editing is restricted to the assembly mode, preventing accidental changes
while the contact sheet is active. Actions preserve the existing checked list;
no operation implicitly ticks another sprite.

Repetitions are integers in [1,99]. Offsets are clamped to [-4096,4096],
matching the recipe codec's validation limits. Strip mode ignores layer offsets
but preserves them when switching modes; layers ignore repetition count but
preserve it. The `Reset` action restores offsets to zero and copies to one.

`Layout.assembly_controls` owns deterministic button geometry. Rendering owns
colours and input hitboxes. The sprite graphics themselves are unmodified.

## Regression evidence

`tests/test_assembly_editing.lua` checks pure action bounds and the *actual
viewer Lua event handlers*: reorder, copies, offsets, shifted 8px nudges,
keyboard/mouse parity, disabled controls and no editing in gallery mode.

The real SDL smoke test can be reproduced with:

```bash
python3 scripts/native-smoke.py \
  --appimage .local-test-assets/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data .local-test-assets/ThemeHospitalData_extracted \
  --level .local-test-assets/LEVEL.L1 \
  --resize-check --assembly-navigation-check --assembly-edit-check
```

This drives an actual CorsixTH 0.70.1 instance under Xvfb with XTest mouse
clicks and real SDL keyboard modifiers. It asserts that the fresh `SVR1`
recipe contains the order `[1,2,3,4,5,6,7,9,8]` and that sprite #9 saves
`dx=8`, `dy=1`, `copies=2`. It also validates the PNG signatures, resized
screenshot sizes, overview clicks, and absence of Lua errors. The game archive,
AppImage, level and screenshots remain private and gitignored.

GitHub Actions is deliberately manual-only; local tests do not consume hosted
Actions minutes. The native smoke test is separate from pure Lua unit tests.
