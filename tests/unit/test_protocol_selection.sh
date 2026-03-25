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

test_default_protocol_resolution() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    PROTOCOLS_ENABLED="vless vmess trojan"
    PROTOCOL_DEFAULT="vless"
    assert_eq "vless" "$(xc_protocol_resolve "")"
}

test_specific_protocol_resolution() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    PROTOCOLS_ENABLED="vless vmess trojan"
    PROTOCOL_DEFAULT="vless"
    assert_eq "trojan" "$(xc_protocol_resolve "trojan")"
}

test_unsupported_resolution_fails() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    PROTOCOLS_ENABLED="vless vmess"
    if xc_protocol_resolve "trojan" >/dev/null 2>&1; then
        printf 'unsupported protocol should fail\n' >&2
        return 1
    fi
}

main() {
    test_default_protocol_resolution
    test_specific_protocol_resolution
    test_unsupported_resolution_fails
    printf 'PASS test_protocol_selection.sh\n'
}

main "$@"
