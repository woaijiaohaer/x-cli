#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

source "${ROOT_DIR}/src/lib/log.sh"
source "${ROOT_DIR}/src/lib/platform.sh"
source "${ROOT_DIR}/src/lib/config.sh"
source "${ROOT_DIR}/src/lib/protocols.sh"
source "${ROOT_DIR}/src/lib/xray_config.sh"
source "${ROOT_DIR}/src/lib/service.sh"
source "${ROOT_DIR}/src/lib/install_flow.sh"
source "${ROOT_DIR}/src/lib/service_templates.sh"
