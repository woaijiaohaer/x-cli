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

test_default_protocol_write() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"
    source "${ROOT_DIR}/src/lib/install_flow.sh"

    PROTOCOLS_ENABLED="vless vmess trojan"
    PROTOCOL_DEFAULT="vless"

    local tmpdir cfg
    tmpdir=$(mktemp -d)
    cfg="${tmpdir}/config.json"

    xc_install_write_protocol_config \
      "${cfg}" \
      "" \
      "62789" \
      "443" \
      "11111111-1111-1111-1111-111111111111" \
      "www.microsoft.com" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]'

    assert_eq "vless" "$(jq -r '.inbounds[1].protocol' "${cfg}")"
    rm -rf "${tmpdir}"
}

test_specific_protocol_write() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"
    source "${ROOT_DIR}/src/lib/install_flow.sh"

    PROTOCOLS_ENABLED="vless vmess trojan"
    PROTOCOL_DEFAULT="vless"

    local tmpdir cfg
    tmpdir=$(mktemp -d)
    cfg="${tmpdir}/config.json"

    xc_install_write_protocol_config \
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

test_unsupported_protocol_rejected() {
    source "${ROOT_DIR}/src/lib/log.sh"
    source "${ROOT_DIR}/src/lib/protocols.sh"
    source "${ROOT_DIR}/src/lib/xray_config.sh"
    source "${ROOT_DIR}/src/lib/install_flow.sh"

    PROTOCOLS_ENABLED="vless vmess"
    PROTOCOL_DEFAULT="vless"

    local tmpdir cfg
    tmpdir=$(mktemp -d)
    cfg="${tmpdir}/config.json"

    if xc_install_write_protocol_config \
      "${cfg}" \
      "trojan" \
      "62789" \
      "443" \
      "11111111-1111-1111-1111-111111111111" \
      "www.microsoft.com" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]' >/dev/null 2>&1; then
        printf 'unsupported protocol should fail\n' >&2
        rm -rf "${tmpdir}"
        return 1
    fi

    rm -rf "${tmpdir}"
}

main() {
    test_default_protocol_write
    test_specific_protocol_write
    test_unsupported_protocol_rejected
    printf 'PASS test_install_flow.sh\n'
}

main "$@"
