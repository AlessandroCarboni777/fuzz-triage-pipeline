#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/scripts/target_build_common.sh"

fuzzpipe_build_cjson_target "$ROOT" "cjson" "cjson"
