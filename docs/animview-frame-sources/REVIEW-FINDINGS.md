# Independent review findings and dispositions

The original reviewer reports were delivered as shareable Markdown files. This is their actionable issue log, not a claim that every reported observation was independently rerun on all platforms.

| Finding | Candidate correction | Evidence / limits |
|---|---|---|
| Short RNC signature read beyond a 2-byte input buffer | Header-length check before four-byte signature comparison; RAII buffer ownership | Compiled C++ regression and sanitizer tests |
| Temporary load buffers leaked | Scoped allocation in load/decompression paths | Sanitizer tests on synthetic fixtures |
| Missing frame-element-list terminator could read into next list | End lookup at next known list boundary; reject malformed lists | Synthetic corrupted-list test; private original-data audit previously passed |
| Rejected TAB replacement cleared the previously decoded bitmap cache | Build replacement records and cache before swapping | Load-recovery regression |
| New DAT could preserve previous cached sprite pixels | Clear cached bitmaps only after successful replacement | Pixel-change regression |
| Partial animation load could still enter duplicate traversal and throw | Stage all files, validate duplicate marking and swap only on success | Engine model verified; GUI path still uncompiled with wxWidgets |
| Existing sprite window could partly replace a valid selection | Stage TAB, DAT and palette as one complete candidate | Source-level correction; requires real GUI testing |
| A screenshot of native pixels is not proof of a wxWidgets dialog | Separate engine preview and real-X11 screenshot acceptance; don't invent GUI screenshot | Native GUI remains unverified |

## Deferred on purpose

No reverse-search UI, pixel hit-testing, guessed source-visibility status, animation editor, manual layer composition, new desktop three-pane redesign, new Python production application or unrelated Lua changes.

Some animation defects concern playback timing, drawing order or scaling rather than missing original sprite pixels. Metadata traceability can help narrow an investigation, but **does not automatically explain or fix runtime renderer behaviour**.
