#!/usr/bin/env bats
# Integration: Connection and authentication verification
# This is the gate test — if it fails, other integration tests should be skipped.

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "connection: health check version succeeds" {
  run_sn health --check version
  assert_success
  json_output | jq -e '.version' >/dev/null
}

@test "connection: instance URL is reachable" {
  run_sn health --check version
  assert_success
  # Should have a non-empty version object
  local build
  build=$(json_output | jq -r '.version.build // "unknown"')
  assert [ "$build" != "unknown" ]
}

@test "connection: auth type is accepted by instance" {
  run_sn health --check version
  assert_success
  # If we got here without 401, auth is working
  refute_output --partial "Authentication failed"
}
