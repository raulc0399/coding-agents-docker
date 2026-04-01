#!/usr/bin/env bash
# Populates the provided array with -v /dev/null:/workspace/<file>:ro flags for secret files found in $1

env_null_mounts() {
  local src_dir="$1"
  local -n mounts_ref="$2"
  local file
  local rel

  mounts_ref=()

  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir"/}"
    mounts_ref+=("-v" "/dev/null:/workspace/${rel}:ro")
  done < <(
    find "$src_dir" -type f \
      \( \
        -name '.env' -o \
        -name '.env.*' -o \
        -name '.envrc' -o \
        -name '.npmrc' -o \
        -name '.yarnrc' -o \
        -name '.yarnrc.yml' -o \
        -name '.pypirc' -o \
        -name 'pip.conf' -o \
        -name 'auth.json' -o \
        -name '.pnpmfile.cjs' -o \
        -name '.sentryclirc' -o \
        -name '.vercelrc' \
      \) \
      -print0
  )
}
