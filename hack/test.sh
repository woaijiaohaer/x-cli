#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if command -v bats >/dev/null 2>&1; then
    BATS_BIN=$(command -v bats)
elif [ -x "${ROOT_DIR}/.tools/bin/bats" ]; then
    BATS_BIN="${ROOT_DIR}/.tools/bin/bats"
else
    printf 'bats not found. run: bash hack/bootstrap-bats.sh\n' >&2
    exit 1
fi

"${BATS_BIN}" "${ROOT_DIR}/tests/unit/example.bats"
