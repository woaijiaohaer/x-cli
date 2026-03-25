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

test_override_manager_resolution() {
    source "${ROOT_DIR}/src/lib/service.sh"
    XC_SERVICE_MANAGER_OVERRIDE="systemd"
    assert_eq "systemd" "$(xc_service_detect_manager)"
    XC_SERVICE_MANAGER_OVERRIDE="openrc"
    assert_eq "openrc" "$(xc_service_detect_manager)"
    XC_SERVICE_MANAGER_OVERRIDE="sysv"
    assert_eq "sysv" "$(xc_service_detect_manager)"
}

test_command_builder() {
    source "${ROOT_DIR}/src/lib/service.sh"
    XC_SERVICE_MANAGER_OVERRIDE="systemd"
    assert_eq "systemctl restart xray" "$(xc_service_build_cmd restart xray)"
    XC_SERVICE_MANAGER_OVERRIDE="openrc"
    assert_eq "rc-service xray stop" "$(xc_service_build_cmd stop xray)"
    XC_SERVICE_MANAGER_OVERRIDE="sysv"
    assert_eq "/etc/init.d/xray status" "$(xc_service_build_cmd status xray)"
}

main() {
    test_override_manager_resolution
    test_command_builder
    printf 'PASS test_service_manager.sh\n'
}

main "$@"
