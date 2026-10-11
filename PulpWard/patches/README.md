# Public-safe native patch queue

This GitHub branch currently has transfer notes and patches, **not** the full playable Pulp Ward project. The complete native-art source must first be imported from the user-provided `PulpWard_GitHub_Upload_Ready.zip`, without the private Argus save or original Theme Hospital data.

## Patch 834c582 — native output integrity and atomic private install

`834c582-native-integrity.patch.gz.b64` is base64-encoded gzip of a standard `git format-patch` from the isolated private project history. It contains only source and test changes, no user save, original game resources or binaries. Uncompressed patch SHA-256: `f39f275724234d83ae58534a766b3b2b573537bc72e3a4a97c4931b431268288`.

After the source-only ZIP has been imported, run these commands from the **PulpWard/** source directory (Python 3 and Git required):

```sh
python -c "import pathlib,base64,gzip; p=pathlib.Path('patches/834c582-native-integrity.patch.gz.b64'); pathlib.Path('patches/834c582.patch').write_bytes(gzip.decompress(base64.b64decode(p.read_text())))"
git apply --check patches/834c582.patch
git apply patches/834c582.patch
python -m unittest discover -s tests -p 'test_*.py'
```

Apply only on `experiment/tarantino-theme`; do not use the old post-render Lua overlay or merge into `master`. The local isolated copy at `834c582` has 29 Python passes, five licensed-resource skips, and three Lua suites passing; actual Argus runtime validation is still pending.
