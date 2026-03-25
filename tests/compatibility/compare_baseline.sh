#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
FIXTURE_DIR="${ROOT_DIR}/tests/fixtures/baseline"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

run_case() {
    local name=$1
    shift
    set +e
    bash "${ROOT_DIR}/x-cli.sh" "$@" >"${TMP_DIR}/${name}.out" 2>&1
    local code=$?
    set -e
    printf '%s\n' "${code}" > "${TMP_DIR}/${name}.code"
}

run_case no_args
run_case unknown_cmd not-a-command
run_case install_cmd install
run_case status_cmd status

for n in no_args unknown_cmd install_cmd status_cmd; do
    diff -u "${FIXTURE_DIR}/${n}.out" "${TMP_DIR}/${n}.out"
    diff -u "${FIXTURE_DIR}/${n}.code" "${TMP_DIR}/${n}.code"
done
