#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="sqlite"
TARGET_DIR="$ROOT/targets/$TARGET"
SRC_ROOT="$TARGET_DIR/src"
DST="$SRC_ROOT/sqlite"

TARGET_REF="${TARGET_REF:-latest}"

DOWNLOAD_PAGE_URL="https://sqlite.org/download.html"
SQLITE_BASE_URL="https://sqlite.org"
CURRENT_YEAR="$(date -u +%Y)"

DOWNLOAD_HTML="$(mktemp)"
CSV_FILE="$(mktemp)"
ARCHIVE_FILE="$(mktemp)"
UNPACK_DIR="$(mktemp -d)"

cleanup() {
  rm -f "$DOWNLOAD_HTML" "$CSV_FILE" "$ARCHIVE_FILE"
  rm -rf "$UNPACK_DIR"
}
trap cleanup EXIT

log() {
  echo "[+] $*"
}

fail() {
  echo "[-] $*" >&2
  exit 1
}

prepare_destination() {
  mkdir -p "$SRC_ROOT"
  rm -rf "$DST"
  mkdir -p "$DST"
}

fetch_download_page() {
  curl -fsSL "$DOWNLOAD_PAGE_URL" -o "$DOWNLOAD_HTML"
}

extract_product_csv() {
  awk '
    /Download product data for scripts to read/ { in_block=1; next }
    in_block && /-->/ { exit }
    in_block {
      gsub(/\r/, "", $0)
      print
    }
  ' "$DOWNLOAD_HTML" > "$CSV_FILE"

  if ! grep -q '^PRODUCT,VERSION,RELATIVE-URL,' "$CSV_FILE"; then
    fail "Failed to extract SQLite product CSV from download page"
  fi
}

normalize_version_to_numeric() {
  local ref="$1"

  if [[ "$ref" =~ ^[0-9]+$ ]]; then
    echo "$ref"
    return 0
  fi

  ref="${ref#v}"

  if [[ "$ref" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf "%d%02d%02d00\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi

  fail "Unsupported TARGET_REF format for sqlite: $1
Use one of:
  latest
  3.18.1
  v3.18.1
  3180100"
}

select_latest_relative_url_from_csv() {
  awk -F',' '
    $1=="PRODUCT" && $3 ~ /sqlite-amalgamation-[0-9]+\.zip$/ {
      print $3
      exit
    }
  ' "$CSV_FILE"
}

normalize_relative_url() {
  local relative_url="$1"
  relative_url="${relative_url#./}"
  relative_url="${relative_url#/}"
  echo "$relative_url"
}

try_download_url() {
  local url="$1"
  local tmp_file
  tmp_file="$(mktemp)"

  if curl -fsSL "$url" -o "$tmp_file"; then
    mv "$tmp_file" "$ARCHIVE_FILE"
    return 0
  fi

  rm -f "$tmp_file"
  return 1
}

resolve_and_download_latest() {
  fetch_download_page
  extract_product_csv

  local relative_url
  relative_url="$(select_latest_relative_url_from_csv)"

  if [[ -z "${relative_url:-}" ]]; then
    fail "Could not resolve latest sqlite amalgamation URL from download page"
  fi

  relative_url="$(normalize_relative_url "$relative_url")"

  local download_url="${SQLITE_BASE_URL}/${relative_url}"

  log "Downloading SQLite amalgamation"
  log "Ref: latest"
  log "URL: $download_url"

  try_download_url "$download_url" || fail "Failed to download latest sqlite amalgamation from $download_url"

  RESOLVED_URL="$download_url"
  RESOLVED_ARCHIVE_PATH="$relative_url"
  RESOLVED_NUMERIC_VERSION="latest"
  RESOLVED_ARCHIVE_KIND="zip"
}

resolve_and_download_historical() {
  local requested_ref="$1"
  local numeric_version="$2"

  local year
  local url
  local archive_path

  for ((year=CURRENT_YEAR; year>=2004; year--)); do
    archive_path="${year}/sqlite-amalgamation-${numeric_version}.zip"
    url="${SQLITE_BASE_URL}/${archive_path}"
    log "Trying: $url"

    if try_download_url "$url"; then
      RESOLVED_URL="$url"
      RESOLVED_ARCHIVE_PATH="$archive_path"
      RESOLVED_NUMERIC_VERSION="$numeric_version"
      RESOLVED_ARCHIVE_KIND="zip"
      return 0
    fi
  done

  for ((year=CURRENT_YEAR; year>=2004; year--)); do
    archive_path="${year}/sqlite-autoconf-${numeric_version}.tar.gz"
    url="${SQLITE_BASE_URL}/${archive_path}"
    log "Trying fallback: $url"

    if try_download_url "$url"; then
      RESOLVED_URL="$url"
      RESOLVED_ARCHIVE_PATH="$archive_path"
      RESOLVED_NUMERIC_VERSION="$numeric_version"
      RESOLVED_ARCHIVE_KIND="tar.gz"
      return 0
    fi
  done

  fail "Could not find matching sqlite source bundle for TARGET_REF=$requested_ref (numeric=$numeric_version)"
}

unpack_archive() {
  case "$RESOLVED_ARCHIVE_KIND" in
    zip)
      unzip -q "$ARCHIVE_FILE" -d "$UNPACK_DIR"
      ;;
    tar.gz)
      tar -xzf "$ARCHIVE_FILE" -C "$UNPACK_DIR"
      ;;
    *)
      fail "Unknown archive kind: $RESOLVED_ARCHIVE_KIND"
      ;;
  esac

  local inner_dir
  inner_dir="$(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"

  if [[ -z "$inner_dir" ]]; then
    fail "Failed to unpack sqlite archive"
  fi

  if [[ ! -f "$inner_dir/sqlite3.c" || ! -f "$inner_dir/sqlite3.h" ]]; then
    fail "Unpacked archive does not contain expected sqlite amalgamation files"
  fi

  cp -f "$inner_dir/sqlite3.c" "$DST/"
  cp -f "$inner_dir/sqlite3.h" "$DST/"
  cp -f "$inner_dir/sqlite3ext.h" "$DST/" 2>/dev/null || true
}

write_version_metadata() {
  local requested_ref="$1"
  local download_url="$2"
  local archive_path="$3"
  local numeric_version="$4"
  local archive_kind="$5"

  cat > "$DST/VERSION.txt" <<EOF
target=sqlite
requested_ref=$requested_ref
resolved_numeric_version=$numeric_version
download_url=$download_url
archive=$archive_path
archive_kind=$archive_kind
fetched_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
}

main() {
  prepare_destination

  local numeric_version="latest"

  if [[ "$TARGET_REF" == "latest" ]]; then
    resolve_and_download_latest
  else
    numeric_version="$(normalize_version_to_numeric "$TARGET_REF")"
    resolve_and_download_historical "$TARGET_REF" "$numeric_version"
  fi

  log "Resolved numeric version: $RESOLVED_NUMERIC_VERSION"
  log "Resolved URL: $RESOLVED_URL"
  log "Archive kind: $RESOLVED_ARCHIVE_KIND"

  unpack_archive
  write_version_metadata \
    "$TARGET_REF" \
    "$RESOLVED_URL" \
    "$RESOLVED_ARCHIVE_PATH" \
    "$RESOLVED_NUMERIC_VERSION" \
    "$RESOLVED_ARCHIVE_KIND"

  log "SQLite source ready"
  log "Destination: $DST"
  ls -la "$DST"
}

RESOLVED_URL=""
RESOLVED_ARCHIVE_PATH=""
RESOLVED_NUMERIC_VERSION=""
RESOLVED_ARCHIVE_KIND=""

main "$@"
