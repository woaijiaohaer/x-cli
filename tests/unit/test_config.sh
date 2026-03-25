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

test_defaults_match_expected() {
    source "${ROOT_DIR}/src/lib/config.sh"
    xc_config_reset
    xc_config_load_defaults "${ROOT_DIR}/config/defaults.conf"
    assert_eq "62789" "${API_PORT}"
    assert_eq '\033[0;32m' "${COLOR_GREEN}"
}

test_env_overrides_defaults() {
    source "${ROOT_DIR}/src/lib/config.sh"
    xc_config_reset
    xc_config_load_defaults "${ROOT_DIR}/config/defaults.conf"
    API_PORT=12345
    export API_PORT
    xc_config_load_env
    assert_eq "12345" "${API_PORT}"
}

test_domains_file_roundtrip() {
    source "${ROOT_DIR}/src/lib/config.sh"
    xc_config_reset
    xc_config_load_domains "${ROOT_DIR}/config/reality-domains.txt"
    assert_eq "6" "${#REALITY_DOMAINS[@]}"
    assert_eq "www.microsoft.com" "${REALITY_DOMAINS[0]}"
}

main() {
    test_defaults_match_expected
    test_env_overrides_defaults
    test_domains_file_roundtrip
    printf 'PASS test_config.sh\n'
}

main "$@"
