# Sprite Viewer v10: compact UI and error recovery

This is a usability and resilience pass on the existing CorsixTH Lua contact-sheet viewer. The sprite display, DAT/TAB decoding, and source game assets remain unchanged.

## Deliberate GitHub Actions budget policy

`.github/workflows/sprite-viewer-tests.yml` has **only `workflow_dispatch`**: no automatic `push`, `pull_request`, `schedule`, or other remote triggers. Local commands are preferred:

```sh
bash scripts/run-tests.sh
# Native SDL, with privately provided files (never committed to the public fork):
python3 scripts/native-smoke.py --appimage /private/CorsixTH-v0.70.1-x86_64.AppImage \
  --game-data /private/ThemeHospitalData_extracted --level /private/LEVEL.L1 \
  --resize-check
```

A maintainer can manually start the GitHub workflow when useful; doing so may consume the account's limited Actions allowance. No remote runs were requested for this change.

## Compact UI

At widths **below 520 px** the four view tabs get an independent header row, rather than competing with the title. The remaining two rows show only core navigation and current resource/selection information. Text with unbounded length (filenames, palette names, status notices) is truncated according to **the game's bitmap-font measured pixel width**, not character count. Detail, assembly and frame headers use the same compact structure.

F1 help is now **paginated**, navigated with Up/Down or PageUp/PageDown, with a visible page number and Escape dismissal; previously the small viewport silently clipped the shortcut reference. This is not intended to replace full-size 640x480 inspection: the 320x200 view remains a dense legacy debug layout.

## Resource loading failure rollback

Loading another sprite table or changing palette/decoder mode is transactional. Only after both palette retrieval and sprite-table loading succeed do we replace the current sprite and selection state. Loading errors are caught and reported in the viewer's status line, while the previous palette, decoder choice, sprite table, scroll position, checked sprites and assembly state remain intact.

At startup, the viewer tries the next resource if the first discovered table is unreadable. If **every** table fails, it raises a clear error instead of proceeding with a nil sheet.

## Evidence

The local Lua suite includes a dedicated failure-injection test for corrupt DAT/TAB loads, palette failures, invalid decoder modes, compact tab hit targets, filename clipping and help pagination. The full pre-existing test suite also passes.

The AppImage **CorsixTH 0.70.1** native smoke test passes under Xvfb with the supplied Theme Hospital assets and a real **320x200→640x480** X11 resize. It produces fresh 320x200/640x480 native screenshots, a versioned nine-sprite assembly recipe, playback and clean return. Native test inputs, screenshots and the AppImage remain outside the public Git repository.
