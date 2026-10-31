# AnimView Frame Sources — native engine tests

These tests exercise the **optional standalone AnimView decoder**, with tiny hand-built synthetic animation/sprite fixtures. They are intentionally separate from CorsixTH's main game and include no original Theme Hospital assets.

From the repository root:

```sh
bash AnimView/tests/frame_sources/run.sh
bash AnimView/tests/frame_sources/run.sh --sanitizers
```

Requires C++17, Python 3 and a working compiler. The first command creates temporary fixture files, builds and runs original-sprite pixel-preview/metadata tests and TAB/DAT reload-recovery tests. The second uses ASan and UBSan. An optional `test_real_game_optional.cpp` is retained for private local inspection only.

**Important:** `verification/test-only-wx-stubs` fakes limited wx file/image classes exclusively for engine tests. It does **not** prove that the actual wxWidgets desktop dialog compiles or runs. See `docs/animview-frame-sources/ACCEPTANCE.md`.
