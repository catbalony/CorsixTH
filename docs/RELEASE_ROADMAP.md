# Sprite Viewer — finite release plan

**Target:** a maintained, review-ready developer viewer in CorsixTH, **not** an
unbounded feature experiment. The original sprite contact sheet remains the
entry point. Work stays on `feature/sprite-viewer-engineering`; never merge to
`master` or touch the separate creative branch without owner approval.

## Three-round finish line (starting after v16)

| Round | Scope | Exit criteria |
| --- | --- | --- |
| **v17** | Controlled layer dragging, optional 8-source-pixel snapping, live coordinate feedback, one undo step per completed drag | Real AppImage drag generates a source-accurate recipe, Undo backup is unchanged from pre-drag, Escape/no-op changes nothing, all Lua tests pass |
| **v18** | **Feature freeze.** Fix regressions; tighten error recovery and compactness at supported sizes, keyboard/mouse consistency and high-risk edge cases | No critical/major defects in a documented manual/native regression matrix; no new interaction subsystems |
| **v19** | Release readiness: clean install, maintainer code review, docs, source and test archive, compatibility notes, PR-ready summary | Clean checkout install works in CorsixTH 0.70.1; local tests and full supported-size native regression documented; no proprietary binaries/data committed; all known defects triaged |

**Stop after v19.** A release-blocking bug may need an additional fix commit,
but do not create v20 or add speculative features under the instruction
“continue.” Propose a new scope only if the owner explicitly authorizes it.

## Definition of done

1. **Core workflows:** DAT/TAB browsing, correct palettes/decoding, checked
   sprite sets, single-sprite inspector, strip/layer assembly, explicit
   animation preview, versioned recipe save/load, screenshot capture and exit.
2. **Editor safety:** no game asset writes; bounded and validated offsets,
   repeats and history; preview drags are cancellable and undoable as one edit.
3. **Usability:** focus and checked state are distinct; controls work with
   keyboard/mouse; no clipping in CorsixTH's *supported* 640x480 minimum,
   and resize 640x480 ↔ 800x600 leaves input aligned.
4. **Engineering:** small documented modules, deterministic unit tests,
   no global-SDL assumptions, reproducible AppImage/Xvfb test. Existing
   GitHub Actions **manual-only**; don't trigger hosted runs automatically.
5. **Delivery:** conventional commits, clean source archive/diff/bundle,
   dependency and test instructions, known limitations and review-ready
   change summary. **No automatic merge or PR creation** without approval.

## Intentionally outside scope

No image painting, asset mutation, GIF/movie export, auto-discovery of guessed
animation sequences or frame durations, a new rendering frontend, runtime C++
changes for per-pixel alpha selection, or automatic GitHub Actions. Native
320x200 is *unsupported* by CorsixTH 0.70.1; synthetic layout tests may cover
it but it is not a release gate.

## Remainder after v17

**Two rounds.** v18 is stabilization; v19 is final acceptance and release
preparation. If an existing feature fails, fix or explicitly document it,
rather than adding a replacement feature.
