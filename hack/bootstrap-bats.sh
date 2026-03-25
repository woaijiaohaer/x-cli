#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TOOLS_DIR="${ROOT_DIR}/.tools"
BATS_DIR="${TOOLS_DIR}/bats-core"

mkdir -p "${TOOLS_DIR}"

if [ ! -d "${BATS_DIR}" ]; then
    git clone --depth 1 https://github.com/bats-core/bats-core "${BATS_DIR}"
fi

"${BATS_DIR}/install.sh" "${TOOLS_DIR}" >/dev/null
printf 'Bats installed at %s/bin/bats\n' "${TOOLS_DIR}"
