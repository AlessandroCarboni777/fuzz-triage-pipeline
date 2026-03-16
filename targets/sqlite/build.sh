#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="sqlite"
REPO_SUBDIR="sqlite"

source "$ROOT/scripts/target_build_common.sh"

fuzzpipe_build_sqlite_target "$ROOT" "$TARGET" "$REPO_SUBDIR"
