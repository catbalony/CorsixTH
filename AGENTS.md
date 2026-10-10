# Sprite Viewer engineering — AI / maintainer handoff

**Scope:** improve CorsixTH's original `CorsixTH/Lua/sprite_viewer.lua`; contact-sheet browsing stays primary. The canonical work is on `feature/sprite-viewer-engineering`. Do NOT modify `master`, rebase shared branches, or force-push.

A separate, lower-priority Tarantino-themed art experiment must use its own `experiment/tarantino-theme` branch. Do not touch each other's viewer code, tests, docs or branch history.

## Real runtime setup (tested)

- Official Linux x86_64 CorsixTH **v0.70.1 AppImage** provided privately.
- User-provided `ThemeHospitalData.7z` extracted to `DATA/`, `DATAM/`, `QDATA/`, `QDATAM/`; supplementary `LEVEL.L1` installed as `Levels/Level.L1`.
- Extract the AppImage locally with `./CorsixTH-v0.70.1-x86_64.AppImage --appimage-extract`. It runs without FUSE after extraction.
- Copy the AppImage's `usr/share/corsix-th/Lua/` to a writable test directory; overlay the candidate `sprite_viewer.lua` and its support modules.
- Set config `theme_hospital_install`, `debug = true`, `width = 640`, `height = 480`, `screenshots`, and a valid `unicode_font` path. Keep test config and Lua runtime outside source control.
- Add a **test-only** `Lua/debug_script.lua` containing `corsixth.require("sprite_viewer")()`. Run AppRun with `--lua-dir=...` and `--config-file=...`.
- Under Xvfb 1024x768, launch and press **Shift+D** from CorsixTH's normal main menu. This exercises the real SDL graphics and XTest input; no `app.lua` modification.
- Exercise table search (`/panel04`), sprite jump, Shift+K to select #1–#9, `V` assembly, Ctrl+S recipe, `X` screenshot, `T` animation, `Q` exit. Inspect `corsixth.log`, `SVR1` recipe and native PNG.
- Missing `SOUND/DATA/Sound-0.dat` produces a harmless warning for the viewer test, not a pass for sound support.

## Provenance / copyright

**DO NOT COMMIT proprietary game data, the supplied LEVEL.L1 or the AppImage into this PUBLIC fork.** Their use here is for private testing only. Place them under a gitignored `.local-test-assets/` or pass paths to scripts; record checksums and retrieval instructions. Do not publish proprietary screenshots in source changes.

Private file checksums (SHA-256):
- `ThemeHospitalData.7z`: `d2c58b020ae26354a03ec6182da8ff070601a4a95d53b4879b9c148590f4655e`
- `LEVEL.L1`: `c792571dfaeee2b44fca9f3d5100e3baf878580657d471c10f24ba23ff032253`
- `CorsixTH-v0.70.1-x86_64.AppImage`: `f228510a6a0e7450e836cd4aace5b2e278638c0ce91eaf00de81c27c06dab14d`

## Engineering rules

Keep changes small and independently reviewable (`docs`, `refactor`, `test`, `fix`, `feat`). Preserve upstream licence. Never infer animation metadata from the DAT/TAB files; use user-selected frame ranges and explicit offsets. Keep original game folders read-only; recipe IO writes only to Screenshots. Validate external files before mutating selection. Unit Lua mocks and **real native SDL smoke tests** are different levels of evidence. Do both.

The local engineering work has extracted sidecar recipe/persistence and resource-search helpers, with regression coverage, and added an automated Xvfb/AppImage native smoke runner. Transfer the local Git bundle before claiming these code changes are available in this remote branch.

## GitHub Actions cost policy (v10)

The dedicated sprite-viewer workflow is **manual-only** (`workflow_dispatch`).
Do not add automatic push, pull request, schedule or polling triggers without
explicit approval from the repository owner; their Actions usage is limited.
Prefer local Lua tests and native Xvfb/AppImage smoke runs. See
`docs/COMPACT_UI_AND_RECOVERY.md` for current test instructions and evidence.
