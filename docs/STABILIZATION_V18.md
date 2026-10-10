# Sprite Viewer v18 — stabilization checkpoint

**Scope is frozen.** This round fixes defects in existing interactions; it does
not add new editor features. The finite roadmap is `docs/RELEASE_ROADMAP.md`.
After v18, **v19 is the last planned round**: clean-install native acceptance,
review, documentation and handoff. Stop there, barring release blockers.

## Bugs fixed in this checkpoint

- **Modal Q release:** keydown already sends printable `q` to the table/palette
  browser, but its keyup previously exited the viewer unconditionally. Q now
  exits only when the browser, help and numeric-input overlays are closed.
  Outside overlays, the legacy Q shortcut is unchanged.
- **Lost focus while dragging:** an activation change can consume the matching
  mouse release. Any pending layer drag is now cancelled/restored on activation
  changes, without adding an undo record. This supplements the existing Esc,
  view-change and resize cancellations.

The existing `tests/sprite_viewer/test_drag.lua` now exercises these two
regressions through the viewer event handlers, including unchanged history,
discarded mouse release and continued Q-to-exit outside overlays.

## Verification status

- **GitHub source:** changes and regression tests are present on
  `feature/sprite-viewer-engineering`. The manual-only
  `.github/workflows/sprite-viewer-tests.yml` policy is unchanged.
- **Private inputs:** the v0.70.1 AppImage, ThemeHospitalData archive and
  LEVEL.L1 supplied for testing match the SHA-256 values in `AGENTS.md`.
  Never put them, or screenshots of licensed artwork, in this public fork.
- **Local Lua suite:** **not yet executed against this branch's updated
  checkout** in the current environment; direct Git clone/network access is
  unavailable. Tests added is not the same as tests passing.
- **Real native SDL:** **not yet re-run for this checkpoint**. Previous v17
  native drag evidence does not validate the new v18 handlers.

## Required v18 exit checks (before marking complete)

1. From a clean branch checkout, run
   `bash scripts/run-sprite-viewer-tests.sh`. All scripts must pass.
2. Run native `scripts/native-smoke.py` with the private inputs using
   `--assembly-drag-check`, `--assembly-pick-check`,
   `--assembly-edit-check`, `--assembly-history-check`, and supported
   `--resize-check`. Run separate focused invocations if the combined
   scenario times out; record each result honestly.
3. Manually open table search, type and release Q, verify the viewer remains
   open and the query contains q; close search with Esc and confirm Q then
   exits. Check palette search and help similarly.
4. Drag a layer, switch window focus before mouse release, and confirm the
   offset and undo history are unchanged. Verify normal release still creates
   exactly one undoable edit.
5. Document and triage any remaining major/critical issue before v19. Avoid
   unrelated enhancements.

**Current status: v18 code fixes committed; verification still open.**
No merge to `master`, no work on the separate art branch and no automatic
GitHub Actions run were requested or performed.
