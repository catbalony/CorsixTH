# Native input and supported sizes — v13

## Corrected diagnosis

CorsixTH **0.70.1** enforces a minimum window size in its own AppImage
`usr/share/corsix-th/Lua/app.lua`:

```lua
App.MIN_WINDOW_WIDTH = 640
App.MIN_WINDOW_HEIGHT = 480
```

The same source clamps startup config values below those minima (roughly
lines 1129–1133). Launching with 320x200 therefore resets the config to
640x480. The earlier test artificially forced the X11 window to 320x200
using `XResizeWindow`; cropped artwork and inconsistent mouse positions
were artifacts of bypassing the host app's constraint, **not demonstrated
viewer hitbox defects**.

The pure Lua geometry tests continue to cover 320x200 for completeness,
but the smallest supported *real SDL* integration configuration is 640x480.

## Reproduce real input verification

With separately supplied original game resources, the CorsixTH 0.70.1
AppImage, Linux Xvfb/XTest, `xwininfo`, Python 3 and Pillow
(`python3-pil`):

```sh
bash scripts/run-sprite-viewer-tests.sh
python3 scripts/native-smoke.py \
  --appimage /private/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data /private/ThemeHospitalData_extracted \
  --level /private/LEVEL.L1 \
  --assembly-navigation-check --resize-check
```

The native runner uses a fresh output directory per run; checks the real
X11 window geometry; takes actual SDL screenshots at **640x480** and
**800x600**; verifies the source IDs in the saved nine-sprite `SVR1`
recipe; and rejects Lua errors in the application log. It checks the amber
assembly focus marker **at opposite ends of the overview**, including after
an actual XTest mousewheel event. Its PNG check searches the bottom footer
band, accommodating a small transient offset between physical window size
and drawable height during a resize.

Mousewheel **up/down** in assembly navigates previous/next selected
components (same focus behaviour as **J/K**), without modifying checked
selection or saved offsets. The ordinary gallery wheel still scrolls.

Note that the nine original ECG frames assemble into a **792px** strip:
when the viewport is **800px** wide, it already fits and the overview is
intentionally hidden. A focused overview test therefore returns to 640px
before clicking. The runner detects incompatible test size combinations.

The original Theme Hospital data, tester-provided level and AppImage remain
private, excluded from this public Git repository. GitHub Actions is
**manual-only** (`workflow_dispatch`); no hosted run is triggered.
