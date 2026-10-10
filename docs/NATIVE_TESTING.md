# Native Sprite Viewer smoke test (CorsixTH 0.70.1, Linux)

This describes **real SDL execution**, not the mocked Lua unit tests. Original
game files and the official AppImage were supplied by the tester in chat; they
are NOT part of this public repository.

## Private inputs

- `ThemeHospitalData.7z` contains `DATA/`, `DATAM/`, `QDATA/`, `QDATAM/`.
- Separate `LEVEL.L1` must appear as `Levels/Level.L1`.
- `CorsixTH-v0.70.1-x86_64.AppImage` is the official Linux binary.

See `AGENTS.md` for SHA-256 hashes. Keep these private. The incomplete data
set lacks `SOUND/DATA/Sound-0.dat`, so sound warnings are expected.

## Repeat the genuine launch

On Linux with Python 3, Xvfb, X11/XTest libraries and the extracted original
game-data directories:

1. Extract the AppImage with
   `./CorsixTH-v0.70.1-x86_64.AppImage --appimage-extract`.
2. Use a writable temporary test directory; copy the AppImage's
   `usr/share/corsix-th/Lua` tree there, then overlay
   `CorsixTH/Lua/sprite_viewer.lua`,
   `CorsixTH/Lua/sprite_viewer_recipe.lua`,
   `CorsixTH/Lua/sprite_viewer_browser.lua`,
   `CorsixTH/Lua/sprite_viewer_selection.lua`, and
   `CorsixTH/Lua/sprite_viewer_layout.lua` from this branch.
3. In that temporary Lua tree create `debug_script.lua` containing
   `corsixth.require("sprite_viewer")()`.
4. Create a temporary game tree: symlinks to `DATA`, `DATAM`, `QDATA`,
   `QDATAM`, and copy `LEVEL.L1` to `Levels/Level.L1`.
5. Make a writable `config.txt` with:
   `debug = true`, `fullscreen = false`, `width = 640`,
   `height = 480`, valid `theme_hospital_install`, `unicode_font`,
   and `screenshots` paths.
6. Start Xvfb (1024x768x24) and run the extracted `AppRun` with
   `--lua-dir=<temp>/Lua --config-file=<temp>/config.txt`. On the normal
   main menu press **Shift+D** to invoke the test-only debug script.
7. Within the viewer: press `/`, search `panel04`, Enter, `G` 1 Enter,
   Shift+K eight times, `V`, Ctrl+S, `X`, `T`, Space, Space, `Q`.
8. Assert a `SVR1` recipe lists sprite IDs 1–9 from `Data/PANEL04V`,
   a valid native PNG appears in Screenshots, and the log has no Lua errors.
   The viewer must close back to the normal CorsixTH screen.

The full local working branch also includes
`scripts/native-smoke.py`, which performs these steps via real XTest events
and checks the resulting files. It never writes into the game resources.

## Unit test versus native evidence

The Lua unit tests exercise a mocked `TheApp` drawing API; they do not prove
native compatibility. Native smoke tests exercise the AppImage binary under a
real virtual X server, verify recipes/screenshots and check the process log.
Neither proves every possible input/layout path: perform manual visual reviews
before release.

For downstream contributors: keep proprietary game data, AppImage binaries and
screenshots containing game art **out of public commits**. Use private local
asset storage plus a checksum manifest instead.

## v13: native input verification and supported resizing

CorsixTH 0.70.1's `app.lua` enforces a minimum **640x480** window;
a forced X11 320x200 resize bypasses the host's contract and is not a
valid native acceptance test. The updated runner checks **800x600** and
**640x480**, refuses unsupported startup requests, and can validate real
X11 wheel input and overview clicks by examining the amber focus marker
in fresh PNG screenshots. This visual check requires `Pillow`
(`python3-pil`) plus `xwininfo`. The 792px ECG strip fits at 800px, so
its overview only appears at narrower supported viewports (640px).
Full detail: `docs/NATIVE_INPUT_AND_RESIZE.md`.

```sh
python3 scripts/native-smoke.py \
  --appimage /private/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data /private/ThemeHospitalData_extracted \
  --level /private/LEVEL.L1 \
  --assembly-navigation-check --resize-check
```
