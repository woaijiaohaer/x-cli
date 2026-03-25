#!/bin/bash

xc_protocol_is_supported() {
    local protocol=$1
    local item
    for item in ${PROTOCOLS_ENABLED:-vless}; do
        if [ "${item}" = "${protocol}" ]; then
            return 0
        fi
    done
    return 1
}

xc_protocol_require_supported() {
    local protocol=$1
    if ! xc_protocol_is_supported "${protocol}"; then
        log_error "Unsupported protocol: ${protocol}"
        return 1
    fi
    return 0
}

xc_protocol_get_default() {
    printf '%s\n' "${PROTOCOL_DEFAULT:-vless}"
}

xc_protocol_resolve() {
    local requested=$1
    local selected

    if [ -n "${requested}" ]; then
        selected="${requested}"
    else
        selected=$(xc_protocol_get_default)
    fi

    if ! xc_protocol_require_supported "${selected}" >/dev/null; then
        return 1
    fi
    printf '%s\n' "${selected}"
}
