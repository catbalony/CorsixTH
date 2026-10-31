# AnimView — Frame Sources investigation (engineering branch)

**Scope:** a narrowly scoped, read-only contribution to **the existing optional standalone C++/wxWidgets AnimView**, not another standalone sprite viewer, game mod, or animation editor.

**State:** native engine and regression tests verified; real wxWidgets dialog **not yet compiled or launched** in the original development environment. These commits are intentionally on `feature/sprite-viewer-engineering`; no merge or PR is implied.

## Why this exists

AnimView already reads and renders original Theme Hospital sprites and animations. Its sprite and animation windows are largely separate, so developers investigating an incorrect animation must manually identify the original sprite elements. This prototype offers a shorter path: animation → current frame → original element records → exact sprite ID, element offsets, layer flags, and pixel-faithful source preview. A listed element is a **metadata reference**, not proof that its pixels are visible; overlapping sprites, transparency, and draw flags still affect the output.

We are **not** attempting to duplicate AnimView's decoder or build a bigger graphics editor. The user-selected three-pane gallery design is preserved as a prior UX direction, but it does not justify redesigning the existing AnimView window for this small experiment.

## What changed

1. **Inherited input-safety fixes (`AnimView/th.h/.cpp`, existing windows):** bounds-check RNC headers and record lengths, manage temporary file buffers safely, keep TAB/DAT and decoded bitmap cache consistent, and stage complete animation/sprite reloads before committing state. Invalid reloads preserve the last working selection.
2. **Read-only native data API (`AnimView/th.h/.cpp`):** `getFrameSources` returns actual element IDs, sprite IDs, positions, sizes, layer IDs, flags and active-mask status in drawing order. Malformed list boundaries are rejected. `renderSourcePreview` decodes original VSPR pixels via existing code onto a small nearest-neighbour checkerboard.
3. **Existing AnimView animation window (`frmMain.cpp/.h`):** one **Frame sources...** button opens a read-only element list and original source preview. It retains the selected animation/frame; no editing, reverse lookup GUI, secondary browser or layer-composition modes.
4. **Synthetic tests (`AnimView/tests/frame_sources`):** short/malformed records, palette/preview, transparent pixels, frame references, masks, bad element terminators, load failure recovery and successful DAT cache invalidation. Uses test-only wx stand-ins and original engine code; does **not** compile the GUI.
5. **Documentation:** this record, [PROJECT-HISTORY.md](PROJECT-HISTORY.md), [REVIEW-FINDINGS.md](REVIEW-FINDINGS.md), and [ACCEPTANCE.md](ACCEPTANCE.md).

The original Lua debugging work and in-game viewer on the engineering branch are preserved unchanged by these commits. No files in the normal CorsixTH game source are modified by this AnimView series.

## Verified, and not verified

- The C++ engine tests and sanitizer runs passed on the original handoff source and on an equivalent in-repository test harness.
- Prior private real Theme Hospital data audit: 5,186 animations, 42,757 animation/frame occurrences, 660,694 element references, 0 invalid trace lookups and 4,397 original VSPR sprites. **These counts are not independent validation of every compositing effect or live runtime rendering.** No copyrighted assets are committed.
- Native wxWidgets headers/libraries were unavailable. The actual GUI was **not** compiled, launched, visually inspected or tested with keyboard/mouse. Native screenshots have **not** been verified.
- We have not shown that this saves CorsixTH developers time in an actual bug investigation. This is a hypothesis to test with maintainers, not an approved merge request.

## Next decision

Run the GUI acceptance checks in [ACCEPTANCE.md](ACCEPTANCE.md). Then ask a maintainer to investigate a real graphical discrepancy using unchanged AnimView and the Frame Sources prototype. If it removes meaningful manual tracing, it could be useful; if existing tooling is already faster, reconsider the change before proposing mainline integration.
