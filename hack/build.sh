#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUT_FILE="${ROOT_DIR}/x-cli.sh"
LEGACY_FILE="${ROOT_DIR}/src/legacy.sh"
if [ -f "${LEGACY_FILE}" ]; then
    cat "${LEGACY_FILE}" > "${OUT_FILE}"
elif [ -f "${OUT_FILE}" ]; then
    printf 'No src/legacy.sh yet, preserved existing %s\n' "${OUT_FILE}"
    exit 0
else
    if [ ! -f "${OUT_FILE}" ]; then
        printf 'Missing %s and %s\n' "${LEGACY_FILE}" "${OUT_FILE}" >&2
        exit 1
    fi
    exit 1
fi

chmod +x "${OUT_FILE}"
printf 'Built %s\n' "${OUT_FILE}"
