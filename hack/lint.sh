#!/bin/bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

shellcheck \
  "${ROOT_DIR}/hack/"*.sh \
  "${ROOT_DIR}/src/lib/"*.sh \
  "${ROOT_DIR}/src/entrypoint.sh" \
  "${ROOT_DIR}/tests/unit/"*.sh
