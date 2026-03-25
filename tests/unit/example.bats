#!/usr/bin/env bats

load ../test_helper.bash

@test "helper can create and cleanup tempdir" {
  setup_tempdir
  [ -d "${TEST_TMPDIR}" ]
  cleanup_tempdir
  [ ! -e "${TEST_TMPDIR}" ]
}
