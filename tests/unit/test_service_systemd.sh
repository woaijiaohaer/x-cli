#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

assert_contains() {
    local needle=$1
    local haystack=$2
    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf 'assert_contains failed: expected [%s] in output\n' "${needle}" >&2
        return 1
    fi
}

test_systemd_unit_generation() {
    source "${ROOT_DIR}/src/lib/service_templates.sh"
    local out
    out=$(xc_service_render_systemd_unit \
      "xray" \
      "/usr/local/bin/xray" \
      "/usr/local/etc/xray/config.json")

    assert_contains "Description=Xray Service" "${out}"
    assert_contains "ExecStart=/usr/local/bin/xray run -c /usr/local/etc/xray/config.json" "${out}"
    assert_contains "Restart=on-failure" "${out}"
    assert_contains "NoNewPrivileges=true" "${out}"
}

main() {
    test_systemd_unit_generation
    printf 'PASS test_service_systemd.sh\n'
}

main "$@"
