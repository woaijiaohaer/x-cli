#!/bin/bash

detect_package_manager() {
    for manager in apt-get apt dnf yum apk pacman zypper; do
        if command -v "${manager}" >/dev/null 2>&1; then
            printf '%s\n' "${manager}"
            return 0
        fi
    done
    return 1
}

detect_arch() {
    uname -m
}

has_command() {
    local name=$1
    command -v "${name}" >/dev/null 2>&1
}
