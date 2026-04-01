#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "${BIN_DIR}"

for cmd in d_claude d_codex d_copilot; do
  ln -sf "${SCRIPT_DIR}/${cmd}" "${BIN_DIR}/${cmd}"
  echo "Linked ${BIN_DIR}/${cmd} -> ${SCRIPT_DIR}/${cmd}"
done

echo
echo "Done. Make sure ${BIN_DIR} is in your PATH."
