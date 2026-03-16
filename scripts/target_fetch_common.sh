#!/usr/bin/env bash
set -euo pipefail

fuzzpipe_fetch_git_target() {
  local root="$1"
  local target="$2"
  local repo_url="$3"
  local repo_subdir="$4"
  local target_ref="${5:-master}"

  local dst="$root/targets/$target/src/$repo_subdir"

  if [ ! -d "$dst/.git" ]; then
    echo "[+] Cloning $(basename "$repo_url" .git) into $dst"
    mkdir -p "$(dirname "$dst")"
    git clone "$repo_url" "$dst"
  else
    echo "[+] $(basename "$repo_url" .git) already present at $dst"
  fi

  echo "[+] Fetching latest refs/tags"
  git -C "$dst" fetch --all --tags

  if [ "$target_ref" = "master" ]; then
    echo "[+] Checking out target ref: master"
    git -C "$dst" checkout master
    git -C "$dst" reset --hard origin/master
  else
    echo "[+] Checking out target ref: $target_ref"
    git -C "$dst" checkout "$target_ref"
  fi

  local current_commit
  local current_ref

  current_commit="$(git -C "$dst" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  current_ref="$(git -C "$dst" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"

  echo "[+] $(basename "$repo_url" .git) ready"
  echo "[+] Ref: $target_ref"
  echo "[+] Branch/HEAD: $current_ref"
  echo "[+] Commit: $current_commit"
}
