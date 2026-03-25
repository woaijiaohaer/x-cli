#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
OUT_DIR="${ROOT_DIR}/tests/fixtures/baseline"

mkdir -p "${OUT_DIR}"

run_case() {
    local name=$1
    shift
    set +e
    bash "${ROOT_DIR}/x-cli.sh" "$@" >"${OUT_DIR}/${name}.out" 2>&1
    local code=$?
    set -e
    printf '%s\n' "${code}" > "${OUT_DIR}/${name}.code"
}

run_case no_args
run_case unknown_cmd not-a-command
run_case install_cmd install
run_case status_cmd status
