# Sprite Viewer engineering branch

The original CorsixTH debug contact sheet remains the primary view.
Selection, inspection, assembly and frames are optional modes. Source is in
`CorsixTH/Lua/sprite_viewer.lua`. This branch isolates navigation and
recipe persistence into separately testable modules:

- `CorsixTH/Lua/sprite_viewer_browser.lua` — deterministic substring
  resource search and original palette-prefix selection.
- `CorsixTH/Lua/sprite_viewer_recipe.lua` — SVR1 serialization, validation,
  transactional overwrite confirmation and .bakN recovery.
- `tests/sprite_viewer/test_browser.lua` and `test_recipe.lua` — pure Lua
  tests without game artwork; run with `scripts/run-sprite-viewer-tests.sh`.

## User interface

Keep the contact sheet fast and readable, with sprite ID/dimensions and a
checkbox for multi-selection. Shift-click selects a range. I opens a focused
detail inspector; V assembles adjacent/stacked pieces with explicit order,
offsets and repeats; T previews an explicitly checked frame sequence. The
animation UI has no obligation to infer timing or use all sprites. / searches
resource tables; Shift+P searches palettes; F resets automatic palette
selection. Ctrl+S/O saves/loads versioned `SVR1` recipe sidecars in the
configured Screenshots directory. X captures a native SDL screenshot.

The original Theme Hospital game data is read-only. The branch preserves the
upstream Lua viewer's licence and requires no C++ change.

## Reproduce testing

Read `AGENTS.md` and `docs/NATIVE_TESTING.md` before editing. Native test
assets are **private, copyrighted user-provided material** and must not be
committed or included in PRs. Their SHA-256 hashes are in
`docs/TEST_ASSET_SHA256.txt`.

The native test uses the official CorsixTH 0.70.1 Linux AppImage extracted to
a private directory, an Xvfb virtual display, a normal game-data layout plus
`LEVEL.L1`, and a test-only debug-script entrypoint. It ran under the actual
SDL renderer and exercised `PANEL04V` navigation, selection, assembly,
sidecar saving, PNG capture, animation and Q exit. It also confirmed that
the game launches normally without any `app.lua` patch. Sound assets are
absent from the tester's partial installation and are not necessary for this
viewer smoke test.

This remote branch contains native-tested **source blobs** (the Git blob hashes
are checked against the local tested branch). The accompanying local Git
bundle delivered in the conversation preserves the full historical v5/v6/v7
commit series, synthetic regression tests and the Xvfb automation script.
Do not claim comprehensive native automation for code changes until that
runner has actually been run again.

## Coordination

The separate Tarantino-style art experiment must not change this branch,
merge it, or write to `master`. Changes should be scoped, reviewable, and
backed by Lua regression + SDL tests.


## 2026-10-10: independent selection and geometry

Selection is now handled by `CorsixTH/Lua/sprite_viewer_selection.lua`. It
preserves checked order and per-entry offsets/repetitions, prunes invalid
entries after decoder changes, and bounds range/bulk operations to prevent
blocking the debug viewer on unusually large tables.

`CorsixTH/Lua/sprite_viewer_layout.lua` owns deterministic contact-sheet
wrapping, scroll bounds, assembly extents, negative layer offsets, fit and
horizontal panning. The entry-point still renders with CorsixTH's actual
sprite API and has no additional UI chrome.

The branch ships `tests/sprite_viewer/test_selection.lua`,
`tests/sprite_viewer/test_layout.lua`, and the scoped GitHub Actions
workflow `.github/workflows/sprite-viewer-tests.yml`.

The full local development bundle additionally contains a real AppImage/Xvfb
runner at `scripts/native-smoke.py` using the private user-supplied
Theme Hospital assets. It was run against CorsixTH 0.70.1 and verified
PANEL04V search, nine-frame selection, recipe creation, a PNG, playback and
clean close. The runner uses **fresh per-run output directories** so old
recipes/PNGs cannot make a broken run appear successful. Proprietary inputs
and native images must not be committed to this public repository.
