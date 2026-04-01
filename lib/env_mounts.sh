#!/usr/bin/env bash
# Returns a list of -v /dev/null:/workspace/<file>:ro flags for each .env* file found in $1

env_null_mounts() {
  local src_dir="$1"
  local mounts=()

  # Add patterns here to expand the list
  local patterns=(
    ".env"
    ".env.*"
    ".envrc"
  )

  for pattern in "${patterns[@]}"; do
    for f in "${src_dir}"/${pattern}; do
      [ -f "$f" ] || continue
      local rel="${f#${src_dir}/}"
      mounts+=("-v" "/dev/null:/workspace/${rel}:ro")
    done
  done

  echo "${mounts[@]}"
}
