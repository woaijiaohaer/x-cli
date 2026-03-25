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

test_default_protocol_is_vless() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/config.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    xc_config_reset
    xc_config_apply "${ROOT_DIR}"
    assert_eq "vless" "$(xc_protocol_get_default)"
}

test_protocol_supported_lookup() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    PROTOCOLS_ENABLED="vless vmess"
    xc_protocol_is_supported "vless"
    xc_protocol_is_supported "vmess"
    if xc_protocol_is_supported "trojan"; then
        printf 'trojan must not be supported in this test\n' >&2
        return 1
    fi
}

main() {
    test_default_protocol_is_vless
    test_protocol_supported_lookup
    printf 'PASS test_protocols.sh\n'
}

main "$@"
