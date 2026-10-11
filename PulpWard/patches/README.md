# Public-safe native patch queue

This GitHub branch currently contains transfer notes and **source-only patches**, not the entire Pulp Ward project. First import the 375 public-safe project files from the owner's `PulpWard_GitHub_Upload_Ready.zip` using the provided Git for Windows upload helper. The ZIP deliberately excludes the private Argus save and licensed game files.

## Current cumulative update — 5745250

`5745250-native-code.patch` is the complete source-only diff from the restored private handoff `bdef686` through two local commits `859a686` and `5745250`. **It supersedes `834c582-native-integrity.patch.gz.b64`; do not apply both.** Contains Python code and synthetic regression tests only, no private save, sprites from Bullfrog, original VSPR/ANI data, or executable binaries.

Patch SHA-256: `f27eed8dbf204efec3907a36b50bd7136c9b93ab63f2713aa706e4b8eadf8d47`.

Once the public-safe source is imported, from the `PulpWard/` directory on `experiment/tarantino-theme`:

```sh
git apply --check patches/5745250-native-code.patch
git apply patches/5745250-native-code.patch
python -m unittest discover -s tests -p 'test_*.py'
texlua tests/test_pulp_theme.lua
texlua tests/test_showcase_directional.lua
texlua tests/test_showcase_theme.lua
```

Verified with the isolated bundle checkout and the public-safe source ZIP: patch application check succeeds. Automated Python suite: 37 passed, 5 skipped due to licensed-resource absence; all 3 Lua suites passed. No CorsixTH gameplay run was performed for this pass, at the owner's request.

### Changes included

- Fail-closed verification of native VSPR/ANI output, frame links/timing, indexed sprite RLE, and appended records
- Atomic and non-overwriting private game-data preparation, with interrupted-copy/race regressions
- Per-frame checks preserving material-layer order, offset, flags, and dimensions
- Reproducible SHA-256 fingerprints for each input and output native resource

The old `834c582-native-integrity.patch.gz.b64` is retained only for historical reference. Never apply the abandoned Lua overlay or publish licensed Theme Hospital files.

## Follow-up code fix — dbcdf57

Apply **after** `5745250-native-code.patch` on the public-safe source checkout. This is an incremental change, not a replacement for that cumulative patch. It prevents indexed palette recolours from turning visible pixels into transparent holes or making transparent pixels visible, including inside machine and patient-fragment composites. Includes five copyright-free regression tests.

The patch is stored as `dbcdf57-native-silhouette.patch.gz.b64` (base64-encoded gzip containing a normal `git format-patch` file). Original uncompressed patch SHA-256: `e9a55c4b0eb7d0240a847a38e1760ebdf7740ed0e6ea0685e81a13d8766cb248`.

From `PulpWard/` after applying the prior patch, decode with Python:

```sh
python -c "import base64,gzip,pathlib; p=pathlib.Path('patches/dbcdf57-native-silhouette.patch.gz.b64'); pathlib.Path('patches/dbcdf57-native-silhouette.patch').write_bytes(gzip.decompress(base64.b64decode(p.read_text())))"
git apply --check patches/dbcdf57-native-silhouette.patch
git apply patches/dbcdf57-native-silhouette.patch
python -m unittest discover -s tests -p 'test_*.py'
```

Local result: 42 Python passes, five licensed-resource skips, and all three Lua suites pass. No live gameplay test was run. Only source changes are included; do not upload private saves, original Bullfrog files or binaries.
