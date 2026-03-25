#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

assert_eq() {
    local expected=$1
    local actual=$2
    if [ "${expected}" != "${actual}" ]; then
        printf 'assert_eq failed: expected [%s], got [%s]\n' "${expected}" "${actual}" >&2
        return 1
    fi
}

test_write_config_file() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"
    local tmpdir
    tmpdir=$(mktemp -d)
    local cfg="${tmpdir}/config.json"

    xc_xray_write_config \
      "${cfg}" \
      "vmess" \
      "62789" \
      "443" \
      "11111111-1111-1111-1111-111111111111" \
      "www.microsoft.com" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]'

    assert_eq "vmess" "$(jq -r '.inbounds[1].protocol' "${cfg}")"
    rm -rf "${tmpdir}"
}

main() {
    test_write_config_file
    printf 'PASS test_xray_config_write.sh\n'
}

main "$@"
