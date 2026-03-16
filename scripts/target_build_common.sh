#!/usr/bin/env bash
set -euo pipefail

fuzzpipe_build_cjson_target() {
  local root="$1"
  local target="$2"
  local repo_subdir="$3"

  local src="$root/targets/$target/src/$repo_subdir"
  local out="$root/targets/$target/out"

  source "$root/scripts/diagnostics_env.sh"
  fuzzpipe_setup_diagnostics_env

  mkdir -p "$out"

  local cjson_obj="$out/cJSON.o"
  local harness_obj="$out/harness.o"
  local fuzzer_bin="$out/${target}_fuzzer"

  local common_flags=(
    -O1
    -g
    -fno-omit-frame-pointer
    -fno-optimize-sibling-calls
  )

  local san_flags=(
    "-fsanitize=${FUZZPIPE_SANITIZERS}"
  )

  local fuzz_cov_flags=(
    -fsanitize=fuzzer-no-link
  )

  echo "[+] Build root: $root"
  echo "[+] Source dir: $src"
  echo "[+] Output dir: $out"
  echo "[+] Sanitizers: $FUZZPIPE_SANITIZERS"

  echo "[+] Compiling cJSON.c as C"
  clang \
    -I"$src" \
    "${common_flags[@]}" \
    "${san_flags[@]}" \
    "${fuzz_cov_flags[@]}" \
    -c "$src/cJSON.c" \
    -o "$cjson_obj"

  echo "[+] Compiling harness.cpp as C++"
  clang++ \
    -I"$src" \
    "${common_flags[@]}" \
    "${san_flags[@]}" \
    "${fuzz_cov_flags[@]}" \
    -c "$root/targets/$target/harness.cpp" \
    -o "$harness_obj"

  echo "[+] Linking fuzzer"
  clang++ \
    "${common_flags[@]}" \
    "${san_flags[@]}" \
    -fsanitize=fuzzer \
    "$harness_obj" \
    "$cjson_obj" \
    -o "$fuzzer_bin"

  echo "[+] Built: $fuzzer_bin"
}


fuzzpipe_build_libyaml_target() {
  local root="$1"
  local target="$2"
  local repo_subdir="$3"

  local repo_root="$root/targets/$target/src/$repo_subdir"
  local src="$repo_root/src"
  local include_dir="$repo_root/include"
  local out="$root/targets/$target/out"

  source "$root/scripts/diagnostics_env.sh"
  fuzzpipe_setup_diagnostics_env

  mkdir -p "$out"

  local harness_obj="$out/harness.o"
  local fuzzer_bin="$out/${target}_fuzzer"

  local common_flags=(
    -O1
    -g
    -fno-omit-frame-pointer
    -fno-optimize-sibling-calls
  )

  local san_flags=(
    "-fsanitize=${FUZZPIPE_SANITIZERS}"
  )

  local fuzz_cov_flags=(
    -fsanitize=fuzzer-no-link
  )

  local yaml_sources=(
    "$src/api.c"
    "$src/reader.c"
    "$src/scanner.c"
    "$src/parser.c"
    "$src/loader.c"
    "$src/writer.c"
    "$src/emitter.c"
    "$src/dumper.c"
  )

  echo "[+] Build root: $root"
  echo "[+] Repo root: $repo_root"
  echo "[+] Source dir: $src"
  echo "[+] Include dir: $include_dir"
  echo "[+] Output dir: $out"
  echo "[+] Sanitizers: $FUZZPIPE_SANITIZERS"

  for source_file in "${yaml_sources[@]}"; do
    if [ ! -f "$source_file" ]; then
      echo "[-] Missing libyaml source file: $source_file"
      exit 1
    fi
  done

  local yaml_objects=()
  for source_file in "${yaml_sources[@]}"; do
    local base_name
    base_name="$(basename "$source_file" .c)"
    local obj_file="$out/${base_name}.o"

    echo "[+] Compiling $(basename "$source_file") as C"
    clang \
      -I"$include_dir" \
      -I"$src" \
      "${common_flags[@]}" \
      "${san_flags[@]}" \
      "${fuzz_cov_flags[@]}" \
      -c "$source_file" \
      -o "$obj_file"

    yaml_objects+=("$obj_file")
  done

  echo "[+] Compiling harness.cpp as C++"
  clang++ \
    -I"$include_dir" \
    -I"$src" \
    "${common_flags[@]}" \
    "${san_flags[@]}" \
    "${fuzz_cov_flags[@]}" \
    -c "$root/targets/$target/harness.cpp" \
    -o "$harness_obj"

  echo "[+] Linking fuzzer"
  clang++ \
    "${common_flags[@]}" \
    "${san_flags[@]}" \
    -fsanitize=fuzzer \
    "$harness_obj" \
    "${yaml_objects[@]}" \
    -o "$fuzzer_bin"

  echo "[+] Built: $fuzzer_bin"
}
