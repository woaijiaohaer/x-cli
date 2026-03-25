#!/bin/bash

xc_service_detect_manager() {
    if [ -n "${XC_SERVICE_MANAGER_OVERRIDE:-}" ]; then
        printf '%s\n' "${XC_SERVICE_MANAGER_OVERRIDE}"
        return 0
    fi

    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        printf 'systemd\n'
        return 0
    fi

    if command -v rc-service >/dev/null 2>&1; then
        printf 'openrc\n'
        return 0
    fi

    printf 'sysv\n'
}

xc_service_build_cmd() {
    local action=$1
    local service_name=$2
    local manager
    manager=$(xc_service_detect_manager)

    case "${manager}" in
        systemd)
            printf 'systemctl %s %s\n' "${action}" "${service_name}"
            ;;
        openrc)
            printf 'rc-service %s %s\n' "${service_name}" "${action}"
            ;;
        *)
            printf '/etc/init.d/%s %s\n' "${service_name}" "${action}"
            ;;
    esac
}

xc_service_run() {
    local action=$1
    local service_name=$2
    local cmd
    cmd=$(xc_service_build_cmd "${action}" "${service_name}")
    eval "${cmd}"
}
