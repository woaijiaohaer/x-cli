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

test_full_config_uses_protocol() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"

    local cfg
    cfg=$(xc_xray_build_full_config \
      "trojan" \
      "62789" \
      "443" \
      "11111111-1111-1111-1111-111111111111" \
      "www.microsoft.com" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]')

    assert_eq "trojan" "$(printf '%s' "${cfg}" | jq -r '.inbounds[1].protocol')"
    assert_eq "62789" "$(printf '%s' "${cfg}" | jq -r '.inbounds[0].port')"
    assert_eq "443" "$(printf '%s' "${cfg}" | jq -r '.inbounds[1].port')"
}

main() {
    test_full_config_uses_protocol
    printf 'PASS test_xray_full_config.sh\n'
}

main "$@"
