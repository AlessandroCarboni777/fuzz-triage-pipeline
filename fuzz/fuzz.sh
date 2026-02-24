#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-cjson}"
MODE="${2:-normal}"   # normal | demo-crash

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Unique run id
RUN_ID="$(date +%Y-%m-%d_%H%M%S)"

RUN_DIR="$ROOT/artifacts/runs/$TARGET/$RUN_ID"
CRASH_DIR="$RUN_DIR/crashes"
CORPUS_DIR="$RUN_DIR/corpus"
LOG_FILE="$RUN_DIR/run.log"
META_FILE="$RUN_DIR/meta.json"

mkdir -p "$CRASH_DIR" "$CORPUS_DIR"

# Common fuzzing knobs (can be overridden via env)
MAX_TOTAL_TIME="${MAX_TOTAL_TIME:-0}"   # 0 = run until Ctrl+C
MAX_LEN="${MAX_LEN:-4096}"
TIMEOUT="${TIMEOUT:-2}"

# Helper: write metadata json (minimal, but useful)
write_meta() {
  local target_version="$1"
  cat > "$META_FILE" <<EOF
{
  "target": "$TARGET",
  "mode": "$MODE",
  "run_id": "$RUN_ID",
  "timestamp": "$(date -Iseconds)",
  "docker_image": "${DOCKER_IMAGE_TAG:-unknown}",
  "target_version": "$target_version",
  "fuzzer": "libFuzzer",
  "args": {
    "max_total_time": $MAX_TOTAL_TIME,
    "max_len": $MAX_LEN,
    "timeout": $TIMEOUT
  }
}
EOF
}

if [ "$TARGET" = "cjson" ]; then
  echo "[+] Run dir: $RUN_DIR"

  echo "[+] Fetching target sources (cJSON)" | tee -a "$LOG_FILE"
  bash "$ROOT/targets/cjson/fetch.sh" 2>&1 | tee -a "$LOG_FILE"

  # Capture target version from the fetched repo (commit hash)
  CJSON_REPO="$ROOT/targets/cjson/src/cjson"
  TARGET_VERSION="unknown"
  if [ -d "$CJSON_REPO/.git" ]; then
    TARGET_VERSION="$(git -C "$CJSON_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  fi

  echo "[+] Building target fuzzer" | tee -a "$LOG_FILE"
  bash "$ROOT/targets/cjson/build.sh" 2>&1 | tee -a "$LOG_FILE"

  write_meta "$TARGET_VERSION"

  FUZZER="$ROOT/targets/cjson/out/cjson_fuzzer"

  # DEMO-CRASH mode: enable env var + drop seed into corpus
  if [ "$MODE" = "demo-crash" ]; then
    echo "[+] DEMO CRASH enabled (FUZZPIPE_DEMO_CRASH=1)" | tee -a "$LOG_FILE"
    export FUZZPIPE_DEMO_CRASH=1

    DEMO_SEED="$ROOT/artifacts/runs/cjson/demo_seed.txt"
    if [ -f "$DEMO_SEED" ]; then
      cp "$DEMO_SEED" "$CORPUS_DIR/seed_CRASHME.txt"
      echo "[+] Added demo seed to corpus: seed_CRASHME.txt" | tee -a "$LOG_FILE"
    else
      echo "[-] Demo seed not found at $DEMO_SEED" | tee -a "$LOG_FILE"
    fi
  fi

  echo "[+] Running libFuzzer" | tee -a "$LOG_FILE"

  # Build fuzzer args
  FUZZ_ARGS=(
    "-artifact_prefix=$CRASH_DIR/"
    "-max_len=$MAX_LEN"
    "-timeout=$TIMEOUT"
  )

  if [ "$MAX_TOTAL_TIME" != "0" ]; then
    FUZZ_ARGS+=("-max_total_time=$MAX_TOTAL_TIME")
  fi

  # Run and tee output to run.log
  "$FUZZER" "${FUZZ_ARGS[@]}" "$CORPUS_DIR" 2>&1 | tee -a "$LOG_FILE"

else
  echo "Unknown target: $TARGET"
  echo "Usage: ./fuzz/fuzz.sh cjson [normal|demo-crash]"
  exit 1
fi