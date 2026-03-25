ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

setup_tempdir() {
    TEST_TMPDIR=$(mktemp -d)
}

cleanup_tempdir() {
    if [ -n "${TEST_TMPDIR:-}" ] && [ -d "${TEST_TMPDIR}" ]; then
        rm -rf "${TEST_TMPDIR}"
    fi
}
