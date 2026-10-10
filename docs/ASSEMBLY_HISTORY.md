# Assembly undo/redo (v15)

This release keeps the original contact sheet as the default view. History is a
small, **in-memory** edit stack for the optional assembly inspector, not a
persistent game editor or a game-data modification.

## Controls

- **Ctrl+Z** or **Undo** reverses the last successful assembly edit.
- **Ctrl+Y**, **Ctrl+Shift+Z**, or **Redo** restores the next undone edit.
- Both buttons are greyed out when their history stacks are empty.
- Native `Layout.assembly_controls` geometry accounts for the additional
  controls in both strip and layers modes. The toolbar uses the same bitmap font
  and rectangles as the existing viewer.

Edits covered: component order, copy counts (including numeric `N` entry),
layer X/Y offsets, Shift-eight-pixel nudges, and Reset. The history keeps the
current component's identity and its four data fields (`id`, `dx`, `dy`,
`repeat_count`). Switching between strip and layers preserves editable history:
those modes hide irrelevant fields but do not destroy them.

**Not covered:** checking/unchecking sprites, table/palette/decoding switches,
recipe loading, scrolling, and navigation. Changing the selection membership,
successfully changing the active sprite table/decoding/palette, or loading a
recipe **clears** both undo and redo stacks. A rejected/no-op edit creates no
history entry and does not clear redo. Undo is available only while assembly
mode is active, so the normal viewer controls keep their established behaviour.

`CorsixTH/Lua/sprite_viewer_history.lua` is a pure Lua helper with no SDL,
filesystem or game-data dependency. Snapshots are **deep copies**. The oldest
entry is dropped when 32 edits have been retained; this is bounded in memory and
no original files are ever changed. A new successful edit after Undo discards
the redo branch.

## Test evidence

Local regression checks:

```sh
bash scripts/run-tests.sh
```

- `tests/test_history.lua` checks snapshot ownership, bounded retention,
  reordering, copies and offsets, no-op handling, redo invalidation, and clear.
- `tests/test_assembly_editing.lua` drives the *real viewer's Lua event
  handlers*, including Ctrl+Z, Ctrl+Y, Ctrl+Shift+Z and mouse Undo/Redo. It
  verifies that gallery keyboard input cannot change assembly history and that
  checking sprites clears stale history.

The separate **real CorsixTH 0.70.1 native smoke test** drives X11 keyboard
and mouse events into the AppImage:

```sh
python3 scripts/native-smoke.py \
  --appimage .local-test-assets/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data .local-test-assets/ThemeHospitalData_extracted \
  --level .local-test-assets/LEVEL.L1 \
  --resize-check --assembly-navigation-check \
  --assembly-edit-check --assembly-history-check
```

The native runner uses a *fresh* screenshots/output directory every invocation.
It selects PANEL04V ECG frames 1–9, makes four actual mouse edits, undoes them
using Ctrl+Z, then saves the resulting base recipe. It redoes the changes with
Ctrl+Y and Ctrl+Shift+Z, clicks the real Undo toolbar button and saves the
intermediate state, then clicks Redo and saves the final state. It verifies:

- `.svr.bak1`: original IDs 1–9 with all zero offsets and one copy.
- `.svr.bak2`: order `[1,2,3,4,5,6,7,9,8]`, with sprite #9 at `dx=8`, `dy=0`,
  and two copies.
- Current `.svr`: same edited order, `dx=8`, `dy=1`, two copies.

The runner also asserts valid native PNGs, supported 640x480/800x600 resize
output, the overview hit targets, animation and absence of Lua errors. This was
executed locally under Xvfb with the user-supplied original assets. No GitHub
Actions run was triggered.

**Legal/provenance:** private game data, the separate level file, the AppImage
and screenshots containing Bullfrog art are test inputs/outputs; never commit
them to this public repository. `AGENTS.md` lists private SHA-256 checksums and
setup details for reproducing the native test.
