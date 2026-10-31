# Sprite Viewer v19 — release handoff and stop condition

**Status: PREPARED — NOT YET ACCEPTED.** The engineering branch is feature-frozen
after v17. v18 repaired three existing input conflicts; the required updated
branch Lua and real native SDL test runs are **not yet evidenced**. Do not label
v19 released or green until its acceptance gate has passed.

## Scope and version boundaries

- **v16:** bounds-based direct selection from assembled artwork, overlap cycling
  and correct focus/history separation.
- **v17:** bounded layer drag, Ctrl 8-source-pixel snap, preview feedback and one
  completed mouse release per undo action.
- **v18:** input stabilization only: Q release in search/help, cancel-on-focus
  change, and wheel focus navigation while dragging.
- **v19:** test and deliver; **no new feature round after this**. Correct
  release-blocking defects only. Do not treat the word "continue" as approval
  for speculative new subsystems.

The original contact sheet is still the default interface. Layer assembly,
animation, recipes and screenshots are optional debugging tools. Nothing
mutates copyrighted game files.

## Final acceptance gate

From a **clean checkout** of `feature/sprite-viewer-engineering`, unpack the
privately held Theme Hospital resources into a directory containing
`DATA/`, `DATAM/`, `QDATA/`, and `QDATAM/`; keep them, the level and
CorsixTH AppImage outside the public repo. Install Lua or LuaTeX, Python 3,
Pillow, Xvfb and X11/XTest support.

Run, for example:

```sh
APPIMAGE=/private/CorsixTH-v0.70.1-x86_64.AppImage \
GAME_DATA=/private/ThemeHospitalData_extracted \
LEVEL=/private/LEVEL.L1 \
DATA_ARCHIVE=/private/ThemeHospitalData.7z \
bash scripts/release-acceptance.sh
```

This **local-only** runner verifies the supplied private-input checksums where
applicable, invokes the Lua test suite, then runs **five separate** real native
smoke sessions: baseline; layer drag; direct picking; edit/undo history; and
supported-size resize/navigation. It writes logs and a pass/fail acceptance
report into a private temporary directory. It never dispatches Actions.

Complete the report's *manual* checks: search/help Q, focus-loss and
wheel-interrupted drags, and 640x480 / 800x600 visual inspection.
The manual cases remain open even if every automated check says PASS.
The acceptance shell script was syntax-checked locally, but an actual run
against the complete updated checkout is still required. The source-only
packaging script also passed a synthetic-checkout smoke test for ZIP integrity,
private-file exclusion and wrong-branch refusal; this is **not** an acceptance
test of the Sprite Viewer itself.

## Native setup evidence from this checkpoint

The three privately supplied inputs were individually verified against the
SHA-256 hashes in `AGENTS.md`. The 0.70.1 AppImage unpacked without FUSE, the
7z archive produced all four expected game folders, and the *bundled original*
CorsixTH runtime launched under Xvfb at 640x480 with the private game data and
level. It stayed up during a twelve-second startup probe; the log reported
only offline-update and headless-audio issues. **This baseline does not test
the modified engineering branch.**

The Lua regression suite and the branch-specific native smoke runner have
**not been executed** in this checkout because this sandbox cannot fetch
the exact remote branch into its local runner environment; only the connected
GitHub editing interface can read/write the repository. Do not infer
successful acceptance from committed tests.

## Release deliverables — after acceptance passes

1. Capture the tested commit SHA, full command lines and each separate
   Lua/native result. Attach the private acceptance report, redacting private
   asset locations when needed.
2. Produce the source-only archive from the clean engineering branch
   with `bash scripts/package-sprite-viewer.sh /private/review-package`.
   The script pins the checked-out commit, archives an explicit source
   whitelist (viewer modules, tests, docs, runner, MIT license), verifies
   the ZIP and excludes proprietary files and native PNGs, then emits a
   SHA-256 and `REVIEW_STATUS.txt`. It refuses other branches or tracked
   working-tree edits. This is a **review-only package**, not proof of QA.
   Optionally create a Git bundle separately for maintainers.
3. Include an indexed diff, review notes and reproducible test instructions.
   Record any unresolved defect with severity and a deliberate accept/defer
   decision. Critical/major regressions prevent signoff.
4. Review `git status`, tracked binary additions and GitHub workflows.
   Proprietary game data, LEVEL.L1, private AppImage, artwork PNGs and
   credentials must not appear in commits or public release archives.
5. **Stop at v19**. Do not merge to `master`, open a PR, modify the Tarantino
   art branch or enable automatic Actions without explicit owner approval.

## Known constraints (not release blockers by themselves)

- Composite picking uses bounding rectangles rather than per-pixel alpha.
- CorsixTH v0.70.1 natively enforces at least **640x480**. Synthetic
  320x200 layout tests are not a supported native test claim.
- Sprite ranges, frame timing, sequence order and offsets are explicit user
  choices; no animation metadata is guessed from the original asset files.
- Unpacked licensed Theme Hospital data remains necessary for real native QA,
  but never belongs in a public fork.
- Hosted workflow remains `workflow_dispatch` only.

**Signoff rule:** All automated gates pass on the exact branch, manual cases
are recorded, no untriaged critical/major bugs exist, and the source-only
handoff package is verified. Otherwise keep status **NOT YET ACCEPTED**
and fix only the blockers. No v20 feature expansion.

## 2026-10-31 modern-engine review checkpoint (not branch acceptance)

An offline CorsixTH workbench was supplied, pinned to upstream commit
`e5138ed8de906ccbf6692299b4375f9312df147e` (2026-10-18).
That workbench's *unmodified upstream engine* passed its 126 Lua tests,
eight native C++ tests, full Lua 5.1 syntax pass and an offline rebuild.
A real Xvfb/XTest run opened the **stock upstream sprite viewer** from its
normal main menu. These results establish a modern baseline only: the
engineering branch's overlaid viewer modules and its full native acceptance
suite have **not** been run against the newer engine. Do not describe this
as branch QA or as v19 signoff.

The v19 native resize/navigation runner had a definite false-negative:
the nine 88px ECG pieces total 792px, so the strip overview is intentionally
hidden at 800px. The runner erroneously clicked that nonexistent control
and expected overview focus movement at 800x600. The runner now performs
800x600 screenshot/resize checks without overview clicks; the dedicated
overview assertions remain at supported 640x480. A pure Lua regression test
explicitly covers overview-present at 640 versus hidden at 800.

Asset provenance is also important. The supplied 2,875-byte `LEVEL.L1`
matches the earlier v19 SHA-256 manifest, but caused a corrupt-level popup
under the newer upstream engine. A separate 163,948-byte `LEVEL.L1` from
the user's private game installation removed that popup during menu testing.
Never silently substitute one for the other in a checksum-gated run. The
game installation still lacks `VIDEO.SAM`, so these results establish menu
and Sprite Viewer entry only, not a playable campaign.

**Remaining release gate:** run all branch-specific Lua tests against the
exact updated engineering commit; run real SDL smoke/resize/drag/pick/edit
checks with the branch viewer overlaid on the intended runtime and valid,
private assets; complete and record the manual interaction matrix; verify
the source-only package. Until then, **NOT YET ACCEPTED** still applies.

## 2026-10-31 bounded editor regression fixes (local helper verification)

After the modern-engine baseline checkpoint, the engineering branch received
release-blocker fixes only (no feature expansion):

- A Ctrl-drag that clears the 3-screen-pixel gesture threshold but rounds to
  zero source-pixel motion no longer snaps an off-grid resting layer onto the
  grid or creates an accidental history edit.
- Valid 2048-component recipes with 4096px bounded XY offsets and up to 99
  copies exceed the previous 32 KiB reader ceiling. Reader and writer now
  share a bounded 128 KiB maximum, preserving such round trips.
- The writer also rejects more than 4096 recipe entries before changing any
  file, matching the parser's row bound.
- Comparison reads of existing recipes are capped at the byte limit plus one;
  the **complete** old file is still preserved by filesystem rename into a
  backup on confirmed replacement, even if that old file is larger.

Focused, reconstructed Lua 5.1-compatible module checks passed locally for
drag arithmetic, old recipe compatibility, 2048-entry round trips, oversized
output refusal, oversized prior-file backup preservation, and 4097-entry
refusal. Corresponding regressions are committed into the branch's
`tests/sprite_viewer/test_drag.lua` and `test_recipe.lua`.

**Evidence limitation:** these isolated tests are not a full run of the exact
remote branch integration suite, nor a real SDL/Xvfb overlay test. The v19
signoff remains **NOT YET ACCEPTED** pending the branch Lua suite, updated
native matrix, manual checks and verified source-only package. Keep GitHub
Actions manual-only and do not merge to master from this checkpoint.

## Subsequent v19 safety pass — exact-input confirmations and cache rollback

Further review found two state-ownership hazards in the existing viewer:

1. A pending Ctrl+S overwrite confirmation was a lone boolean. Changing the
   checked selection or switching DAT/TAB resources before the second Ctrl+S
   could overwrite a different recipe without fresh consent. Confirmation is
   now bound to **both exact output path and serialized recipe bytes**.
   `test_save_confirmation.lua` drives the real viewer's mocked keyboard
   handler through an intervening selection change and a table change;
   it is part of the local/manual Lua suite.
2. The palette/decoder switch previously cleared `gfx.cache.tabled` before
   an attempted reload, even if the load failed. Cache replacement now happens
   inside `ReLoadSameTable` and the prior cache is restored on failure.
   `test_compact_recovery.lua` now checks old cache identity on both failure
   paths in addition to its previous selection/visible-error assertions.

These are defensive release fixes, not new features. The focused standalone
drag/recipe checks run in the local sandbox passed; **the newly added UI
integration regressions have not yet been run against an exact assembled
engineering checkout**. Remote GitHub source access and local container build
assets remain separate in this environment. Do not represent code review,
test creation or upstream baseline tests as a successful full branch test run.

Release acceptance remains **NOT YET ACCEPTED**. Do not merge to master,
start automatic Actions, or distribute private Theme Hospital assets.
