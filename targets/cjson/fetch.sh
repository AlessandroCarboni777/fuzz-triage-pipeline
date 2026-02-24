#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DST="$ROOT/targets/cjson/src/cjson"

if [ -d "$DST/.git" ]; then
  echo "[+] cJSON already present at $DST"
  exit 0
fi

echo "[+] Cloning cJSON into $DST"
git clone --depth 1 --branch v1.7.17 https://github.com/DaveGamble/cJSON.git "$DST"

echo "[+] Done"