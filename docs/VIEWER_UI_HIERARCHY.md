# Sprite Viewer: visual hierarchy and assembly focus (v11)

## Purpose

This is a refinement of CorsixTH's original contact-sheet debug viewer. The
full-width gallery remains the default; there is no second UI framework, new
editor or new DAT/TAB interpretation.

## State distinctions

**Focused** means *which sprite keyboard commands and the DETAIL view operate
on*. Focus has a narrow muted blue row and a `>` marker that are visible even
without colour. **Checked** means *the sprite participates in the ordered
assembly or optional frame sequence*. Checked sprites have an independent,
marked teal-tinted checkbox. One state does not imply the other, and a
focus change does not alter the checked set.

Assembly now outlines only the current component, not the whole composition.
For strips with a repeated component the outline encloses all repetitions.
For layers it follows that component's offset and native geometry; it does not
colourise or rewrite the pixels. An empty source sprite produces no outline.

## Less chrome, more information

At 640x480, the header now presents one line of common context actions, the
source/palette identity, and focused sprite ID/dimensions with checked count.
Most shortcuts are intentionally delegated to F1. At 320x200, the same
information is shortened using the viewer's measured-pixel text clipping.
Tabs retain the compact 2009-style bitmap font and minimal rectangle borders.

## Wide assemblies

Moving focus with J/K or clicking an assembly chip reveals the active source
sprite within the horizontal viewport. Opening an assembly also reveals its
existing focused sprite. The pure `Layout.reveal_strip` calculates the pan
without mutating sprite order, offsets or repeat counts; components wider than
the viewport align by their left edge. Mouse/keyboard checks use the same
function, and manual arrow panning still works.

## Validation

- `bash scripts/run-tests.sh` (all pre-existing Lua tests plus the new focused
  vs checked visual-command regression, a wide-strip pan test, and preserved
  mode/navigation expectations).
- Real **CorsixTH 0.70.1 AppImage** under Xvfb, started from the game's normal
  menu with the debug script: select ECG sprites #1–#9, inspect 320x200 and
  640x480, assemble, save a sidecar recipe, capture native PNGs, play frames,
  return cleanly to the game.
- The private user-provided AppImage, LEVEL.L1 and game resource folders are
  not committed. Instructions: `AGENTS.md` and `docs/NATIVE_TESTING.md`.
- GitHub Actions remain *manual-only*. No hosted CI run is necessary for this
  local iteration.

## Remaining design questions

The 320x200 view is a compact debugging fallback, not a polished substitute for
640x480. Next steps could include a clearer paging affordance for long assembly
selections, and a deliberate keyboard-focus accessibility review. Exporting a
screenshot is not the same as lossless individual sprite export.
