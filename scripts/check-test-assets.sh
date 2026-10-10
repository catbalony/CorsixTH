#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo 'usage: scripts/check-test-assets.sh TH_DATA.7z LEVEL.L1 CorsixTH.AppImage' >&2
  exit 2
fi
for path in "$@"; do
  if [ ! -f "$path" ]; then echo "missing: $path" >&2; exit 1; fi
  sha256sum "$path"
done
