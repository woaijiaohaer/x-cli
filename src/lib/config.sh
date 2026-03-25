#!/bin/bash

REALITY_DOMAINS=()

xc_config_reset() {
    unset API_PORT VLESS_PORT_MIN VLESS_PORT_SPAN COLOR_GREEN COLOR_RED COLOR_YELLOW COLOR_NC
    REALITY_DOMAINS=()
}

xc_config_is_safe_assignment() {
    local line=$1
    [[ "${line}" =~ ^[A-Z_][A-Z0-9_]*= ]] || return 1
    [[ "${line}" == *\$\(* ]] && return 1
    [[ "${line}" == *\`* ]] && return 1
    return 0
}

xc_config_load_defaults() {
    local file=$1
    local key
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        xc_config_is_safe_assignment "${line}" || continue
        key=${line%%=*}
        if [ -n "${!key+x}" ]; then
            continue
        fi
        eval "${line}"
    done < "${file}"
}

xc_config_load_env() {
    : "${API_PORT:=${API_PORT:-}}"
    : "${VLESS_PORT_MIN:=${VLESS_PORT_MIN:-}}"
    : "${VLESS_PORT_SPAN:=${VLESS_PORT_SPAN:-}}"
    : "${COLOR_GREEN:=${COLOR_GREEN:-}}"
    : "${COLOR_RED:=${COLOR_RED:-}}"
    : "${COLOR_YELLOW:=${COLOR_YELLOW:-}}"
    : "${COLOR_NC:=${COLOR_NC:-}}"
    : "${PROTOCOL_DEFAULT:=${PROTOCOL_DEFAULT:-}}"
    : "${PROTOCOLS_ENABLED:=${PROTOCOLS_ENABLED:-}}"
}

xc_config_load_domains() {
    local file=$1
    REALITY_DOMAINS=()
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        REALITY_DOMAINS+=("${line}")
    done < "${file}"
}

xc_config_apply() {
    local root_dir=$1
    xc_config_load_defaults "${root_dir}/config/defaults.conf"
    xc_config_load_defaults "${root_dir}/config/protocols.conf"
    xc_config_load_env
    xc_config_load_domains "${root_dir}/config/reality-domains.txt"
}
