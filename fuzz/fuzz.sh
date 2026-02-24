#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-cjson}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CRASH_DIR="$ROOT/artifacts/crashes/$TARGET"
CORPUS_DIR="$ROOT/artifacts/corpus/$TARGET"

mkdir -p "$CRASH_DIR" "$CORPUS_DIR"

if [ "$TARGET" = "cjson" ]; then
  echo "[+] Fetching target sources (cJSON)"
  bash "$ROOT/targets/cjson/fetch.sh"

  echo "[+] Building target fuzzer"
  bash "$ROOT/targets/cjson/build.sh"

  FUZZER="$ROOT/targets/cjson/out/cjson_fuzzer"

  echo "[+] Running libFuzzer"
  # -artifact_prefix makes crash files easy to find, with consistent naming
  "$FUZZER" \
    -artifact_prefix="$CRASH_DIR/" \
    "$CORPUS_DIR"
else
  echo "Unknown target: $TARGET"
  echo "Usage: ./fuzz/fuzz.sh cjson"
  exit 1
fi