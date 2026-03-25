#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/src/lib/bootstrap.sh"

xc_gen_config_command() {
    local requested_protocol=$1
    local output_path=$2

    xc_config_reset
    xc_config_apply "${ROOT_DIR}"

    local default_domain
    default_domain="${REALITY_DOMAINS[0]}"

    local uuid
    uuid="11111111-1111-1111-1111-111111111111"

    xc_install_write_protocol_config \
      "${output_path}" \
      "${requested_protocol}" \
      "${API_PORT}" \
      "443" \
      "${uuid}" \
      "${default_domain}" \
      "private_key_x" \
      "public_key_x" \
      '["","abcd"]'
}

main() {
    local cmd=${1:-}
    case "${cmd}" in
        gen-config)
            local protocol=${2:-}
            local output_path=${3:-}
            if [ -z "${output_path}" ]; then
                printf 'usage: %s gen-config <protocol|empty> <output_path>\n' "$0" >&2
                return 1
            fi
            xc_gen_config_command "${protocol}" "${output_path}"
            ;;
        *)
            return 0
            ;;
    esac
}

main "$@"
