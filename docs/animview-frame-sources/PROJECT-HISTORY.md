# Project history and design decisions

This record preserves the purpose of the earlier work without checking large private-data archives, AI-review bundles or disposable prototypes into the game repository.

| Checkpoint | What it established | Decision |
|---|---|---|
| In-game Lua sprite-viewer engineering | Basic debugging access, later expanded into many modes and a large branch history | Preserve for reference; don't add another editor or assembly workflow |
| Standalone Python/Tk Sprite Explorer v1–v9 | Decoding, palette selection, searchable gallery, zoom and inspection could work as a compact desktop workflow; many independent bug reviews | Freeze v9 as **disposable prototype**, not production |
| 800×600 visual iterations | Useful small-window regression testing, but disproportionate focus on legacy-size constraints | Normal desktop sizes are primary; compact text stays |
| Two-pane versus three-pane comparison | Resource list visibility trades working space for immediate navigation | Owner **prefers three panes**; stop redesign debate |
| Existing AnimView source audit | Native C++ already decodes originals, plays animation frames and understands element chains | Reuse AnimView, not remake it |
| Native AnimView metadata feasibility | Original engine decoded real compressed animation assets and sprite references | Worth pursuing a minimal traceability feature |
| Native resource-catalog proof | Indexed original sprite resources and palettes, but lacked clearly differentiated developer value | Keep out of current feature; no new browser |
| Forward/reverse C++ traceability proof | Frames can be mapped to source elements and source sprites, and referenced animations identified | Focus on forward frame→element→sprite inspection; reverse GUI deferred |
| Independent source reviews | Detected original short-file overflow, temporary memory ownership defects, malformed list association and inconsistent reload caches | Fix narrowly before GUI approval |
| Frame Sources integration and pixel path | One read-only dialog candidate, C++-verified metadata and preview, generated synthetic animation installation | Don't claim real GUI acceptance until wx build |
| Native GUI acceptance attempt | wxWidgets dev libraries absent; external workflow and screenshot verifier prepared but not executed | Explicit **blocked** acceptance gate, not a reason for more feature expansion |

Earlier Markdown/ZIP review handoffs are documentation archives outside this source tree. They should not be presented as merged production code. No original game artwork, palette data or private game screenshots should be uploaded to this repository.

## Definition of success

The most useful result is not a polished sprite browser. It is making an actual animation discrepancy simpler to diagnose: pause frame, select element, see the original sprite and its offsets/layer, then return to the original frame. Compare that against current AnimView on a developer-selected issue. No productionization until that demonstrably helps.
