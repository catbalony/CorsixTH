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
