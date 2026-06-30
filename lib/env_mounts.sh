#!/usr/bin/env bash
# Populates the provided array with -v /dev/null:<container-workdir>/<file>:ro flags for secret files found in $1

env_null_mounts() {
  local src_dir="$1"
  local -n mounts_ref="$2"
  local container_workdir="${CONTAINER_WORKDIR:-/workspace}"
  local file
  local rel

  mounts_ref=()

  while IFS= read -r -d '' file; do
    rel="${file#"$src_dir"/}"
    mounts_ref+=("-v" "/dev/null:${container_workdir}/${rel}:ro")
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

  # Per-project overrides: each line in .nullmounts is an additional path to mask
  local nullmounts_file="$src_dir/.nullmounts"
  if [[ -f "$nullmounts_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -z "$line" || "$line" == \#* ]] && continue
      mounts_ref+=("-v" "/dev/null:${container_workdir}/${line}:ro")
    done < "$nullmounts_file"
  fi
}

agent_instructions_args() {
  local src_dir="$1"
  local container_path="$2"
  local -n args_ref="$3"
  local resolved_host_path=""

  args_ref=()

  resolve_agent_instructions_path "$src_dir" resolved_host_path || return 1

  if [[ -z "$resolved_host_path" ]]; then
    return 0
  fi

  args_ref+=("-v" "${resolved_host_path}:${container_path}:ro")
}

agent_config_mount_args() {
  local host_dir="$1"
  local container_dir="$2"
  local -n args_ref="$3"

  args_ref=()

  if [[ "$host_dir" == ~* ]]; then
    host_dir="${HOME}${host_dir#"~"}"
  fi

  mkdir -p "$host_dir"
  args_ref+=("-v" "${host_dir}:${container_dir}")
}

agent_config_file_mount_args() {
  local host_file="$1"
  local container_file="$2"
  local -n args_ref="$3"

  args_ref=()

  if [[ "$host_file" == ~* ]]; then
    host_file="${HOME}${host_file#"~"}"
  fi

  mkdir -p "$(dirname "$host_file")"
  touch "$host_file"
  args_ref+=("-v" "${host_file}:${container_file}")
}

container_name_exists() {
  [[ -n "$(docker ps -a -q -f "name=^${1}$")" ]]
}

# Resolves the container name to use, handling collisions; returns it via $2.
resolve_container_name() {
  local base="$1"
  local -n name_ref="$2"

  # Base name is free: use it as-is
  if ! container_name_exists "$base"; then
    name_ref="$base"
    return 0
  fi

  # Pick the first free numeric suffix for the "start new" option
  local candidate
  local i=1
  while :; do
    candidate="${base}-${i}"
    container_name_exists "$candidate" || break
    i=$((i + 1))
  done

  # Warn and ask how to proceed; default to starting new when no TTY is attached
  echo "Warning: a container named '${base}' already exists." >&2
  if [[ ! -t 0 ]]; then
    echo "No interactive terminal; starting new as '${candidate}'." >&2
    name_ref="$candidate"
    return 0
  fi

  local answer
  while :; do
    read -r -p "[k=kill prev / n=start new] " answer
    case "$answer" in
      k|K)
        docker rm -f "$base" >/dev/null
        name_ref="$base"
        return 0
        ;;
      n|N)
        name_ref="$candidate"
        return 0
        ;;
    esac
  done
}

resolve_agent_instructions_path() {
  local src_dir="$1"
  local -n path_ref="$2"
  local host_path="${AGENTS_MD_PATH:-}"

  path_ref=""

  if [[ -z "$host_path" ]]; then
    return 0
  fi

  if [[ "$host_path" == ~* ]]; then
    host_path="${HOME}${host_path#"~"}"
  fi

  if [[ "$host_path" != /* ]]; then
    host_path="${src_dir}/${host_path}"
  fi

  if [[ ! -f "$host_path" ]]; then
    echo "AGENTS_MD_PATH file not found: ${host_path}" >&2
    return 1
  fi

  path_ref="$host_path"
}
