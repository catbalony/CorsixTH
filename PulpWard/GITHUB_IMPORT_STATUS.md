# Handoff: where the complete Pulp Ward source currently lives

The public fork branch `experiment/tarantino-theme` is dedicated to this separate art project. It does not alter CorsixTH master or the sprite viewer branch.

## Important transfer status

The branch currently contains the project reservation/transfer instructions. **The large local generated PNG/DAT/TAB files have not yet been uploaded to GitHub.** The uploader is a separate validated source ZIP, `PulpWard_GitHub_Upload_Ready.zip`, whose `PUSH_TO_GITHUB.ps1` script uses the owner's Git for Windows to upload all **375** public-safe project files as `PulpWard/` in one commit on this branch.

### Local completed state

- Private project Git HEAD: `9bf527d` on `experiment/tarantino-theme`.
- Previous accepted artwork: 19 character-class mappings, 18 directly replaced object types, 1,230 distinct modified native frames, 471 appended sprites.
- Local full-history private bundle: `PulpWard_ALL_SOURCE_HISTORY_PRIVATE.bundle` (includes *private save fixture*; **never publish this bundle**).
- Separate deprecated overlay WIP archived in local Git branch `archive/legacy-overlay-wip`, included in upload snapshot under `archive/legacy_overlay_wip/` as inactive historical sources.
- Full local checkout: 25 Python tests and three Lua suites pass.
- Public-safe snapshot without the private save: 23 passed, 2 save-dependent tests skipped; three Lua suites pass.

## Rules for continuing

1. **Keep using native VSPR/ANI replacement and normal CorsixTH draw order.** Do not enable the old post-render overlay.
2. Do not modify `feature/sprite-viewer-engineering`, `master`, or other projects.
3. Do not upload `fixtures/saves/Argus_SuperDuper_100.sav.zip`, original game data, game binaries, or private patched copies.
4. Actual source/art map: `art_sources/`, `assets/`, `tools/build_private_native_swap.py`, `tools/prepare_private_native_swap.py`, `tests/`, `docs/AGENT_HANDOFF_NATIVE_ART.md`.
5. Treat animation frame counts as mapping coverage, **not** percent artistic completion. Main remaining work is specialist machines, close-up treatment poses, room surfaces and ordinary doors.

Use the upload ZIP's helper and Git credentials to complete the transfer; GitHub's connected text-only API alone cannot import this session's local binary artwork.