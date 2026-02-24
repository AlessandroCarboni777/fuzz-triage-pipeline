#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/targets/cjson/src/cjson"
OUT="$ROOT/targets/cjson/out"

mkdir -p "$OUT"

# Compile the fuzzer with sanitizers
clang++ \
  -I"$SRC" \
  -O1 -g -fno-omit-frame-pointer \
  -fsanitize=fuzzer,address,undefined \
  "$ROOT/targets/cjson/harness.cpp" \
  "$SRC/cJSON.c" \
  -o "$OUT/cjson_fuzzer"

echo "[+] Built: $OUT/cjson_fuzzer"