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

test_entrypoint_generates_protocol_config() {
    local tmpdir cfg
    tmpdir=$(mktemp -d)
    cfg="${tmpdir}/config.json"

    PROTOCOLS_ENABLED="vless vmess trojan" \
      PROTOCOL_DEFAULT="vless" \
    bash "${ROOT_DIR}/src/entrypoint.sh" gen-config vmess "${cfg}"

    assert_eq "vmess" "$(jq -r '.inbounds[1].protocol' "${cfg}")"
    rm -rf "${tmpdir}"
}

main() {
    test_entrypoint_generates_protocol_config
    printf 'PASS test_entrypoint_gen_config.sh\n'
}

main "$@"
