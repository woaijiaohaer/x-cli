#!/bin/bash

COLOR_GREEN=${COLOR_GREEN:-'\033[0;32m'}
COLOR_RED=${COLOR_RED:-'\033[0;31m'}
COLOR_YELLOW=${COLOR_YELLOW:-'\033[1;33m'}
COLOR_NC=${COLOR_NC:-'\033[0m'}

log_info() {
    printf '%b\n' "${COLOR_GREEN}[INFO]${COLOR_NC} $1"
}

log_warn() {
    printf '%b\n' "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"
}

log_error() {
    printf '%b\n' "${COLOR_RED}[ERROR]${COLOR_NC} $1"
}
