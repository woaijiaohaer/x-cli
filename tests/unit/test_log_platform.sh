#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

assert_contains() {
    local needle=$1
    local haystack=$2
    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf 'assert_contains failed: expected [%s] in [%s]\n' "${needle}" "${haystack}" >&2
        return 1
    fi
}

test_log_format() {
    source "${ROOT_DIR}/src/lib/log.sh"
    local got_info got_warn got_error
    got_info=$(log_info "hello")
    got_warn=$(log_warn "hello")
    got_error=$(log_error "hello")

    assert_contains "[INFO]" "${got_info}"
    assert_contains "[WARN]" "${got_warn}"
    assert_contains "[ERROR]" "${got_error}"
}

test_detect_package_manager_function_exists() {
    source "${ROOT_DIR}/src/lib/platform.sh"
    type detect_package_manager >/dev/null 2>&1
}

test_detect_package_manager_returns_known_or_empty() {
    source "${ROOT_DIR}/src/lib/platform.sh"
    local got
    got=$(detect_package_manager || true)
    if [ -n "${got}" ]; then
        case "${got}" in
            apt-get|apt|dnf|yum|apk|pacman|zypper) ;;
            *)
                printf 'unexpected package manager: %s\n' "${got}" >&2
                return 1
                ;;
        esac
    fi
}

main() {
    test_log_format
    test_detect_package_manager_function_exists
    test_detect_package_manager_returns_known_or_empty
    printf 'PASS test_log_platform.sh\n'
}

main "$@"
