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

build_and_assert_protocol() {
    local protocol=$1
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"

    local inbound
    inbound=$(xc_xray_build_inbound \
      "${protocol}" \
      "443" \
      "11111111-1111-1111-1111-111111111111" \
      "www.microsoft.com" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]')

    local got_protocol
    got_protocol=$(printf '%s' "${inbound}" | jq -r '.protocol')
    assert_eq "${protocol}" "${got_protocol}"
}

test_vless() {
    build_and_assert_protocol "vless"
}

test_vmess() {
    build_and_assert_protocol "vmess"
}

test_trojan() {
    build_and_assert_protocol "trojan"
}

test_unknown_protocol_fails() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"
    if xc_xray_build_inbound "unknown" "443" "u" "d" "pk" "pb" '[]' >/dev/null 2>&1; then
        printf 'unknown protocol must fail\n' >&2
        return 1
    fi
}

main() {
    test_vless
    test_vmess
    test_trojan
    test_unknown_protocol_fails
    printf 'PASS test_xray_config_protocols.sh\n'
}

main "$@"
