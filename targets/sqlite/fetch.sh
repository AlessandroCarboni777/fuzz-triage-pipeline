#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="sqlite"
TARGET_DIR="$ROOT/targets/$TARGET"
SRC_ROOT="$TARGET_DIR/src"
DST="$SRC_ROOT/sqlite"

TARGET_REF="${TARGET_REF:-latest}"

mkdir -p "$SRC_ROOT"
rm -rf "$DST"
mkdir -p "$DST"

DOWNLOAD_HTML="$(mktemp)"
CSV_FILE="$(mktemp)"
ZIP_FILE="$(mktemp --suffix=.zip)"
UNPACK_DIR="$(mktemp -d)"

cleanup() {
  rm -f "$DOWNLOAD_HTML" "$CSV_FILE" "$ZIP_FILE"
  rm -rf "$UNPACK_DIR"
}
trap cleanup EXIT

fetch_download_page() {
  curl -fsSL "https://sqlite.org/download.html" -o "$DOWNLOAD_HTML"
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
    echo "[-] Failed to extract SQLite product CSV from download page"
    exit 1
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
    printf "3%02d%02d00\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
    return 0
  fi

  echo "[-] Unsupported TARGET_REF format for sqlite: $1"
  echo "[-] Use one of: latest, v3.51.3, 3.51.3, or numeric form like 3510300"
  exit 1
}

select_relative_url() {
  local numeric_version="$1"

  if [[ "$TARGET_REF" == "latest" ]]; then
    awk -F',' '
      $1=="PRODUCT" && $3 ~ /sqlite-amalgamation-[0-9]+\.zip$/ {
        print $3
        exit
      }
    ' "$CSV_FILE"
    return 0
  fi

  awk -F',' -v ver="$numeric_version" '
    $1=="PRODUCT" && $2==ver && $3 ~ /sqlite-amalgamation-[0-9]+\.zip$/ {
      print $3
      exit
    }
  ' "$CSV_FILE"
}

fetch_download_page
extract_product_csv

if [[ "$TARGET_REF" == "latest" ]]; then
  RELATIVE_URL="$(select_relative_url "")"
else
  NUMERIC_VERSION="$(normalize_version_to_numeric "$TARGET_REF")"
  RELATIVE_URL="$(select_relative_url "$NUMERIC_VERSION")"
fi

if [[ -z "${RELATIVE_URL:-}" ]]; then
  echo "[-] Could not find matching sqlite amalgamation for TARGET_REF=$TARGET_REF"
  exit 1
fi

RELATIVE_URL="${RELATIVE_URL#./}"
RELATIVE_URL="${RELATIVE_URL#/}"

DOWNLOAD_URL="https://sqlite.org/$RELATIVE_URL"

echo "[+] Downloading SQLite amalgamation"
echo "[+] Ref: $TARGET_REF"
echo "[+] URL: $DOWNLOAD_URL"

curl -fsSL "$DOWNLOAD_URL" -o "$ZIP_FILE"

unzip -q "$ZIP_FILE" -d "$UNPACK_DIR"

INNER_DIR="$(find "$UNPACK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
if [[ -z "$INNER_DIR" ]]; then
  echo "[-] Failed to unpack sqlite amalgamation archive"
  exit 1
fi

cp -f "$INNER_DIR/sqlite3.c" "$DST/"
cp -f "$INNER_DIR/sqlite3.h" "$DST/"
cp -f "$INNER_DIR/sqlite3ext.h" "$DST/" 2>/dev/null || true

cat > "$DST/VERSION.txt" <<EOF
target_ref=$TARGET_REF
download_url=$DOWNLOAD_URL
archive=$RELATIVE_URL
EOF

echo "[+] SQLite amalgamation ready"
echo "[+] Destination: $DST"
ls -la "$DST"
