#!/usr/bin/env bats
# Integration: health command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "health: full check returns all sections" {
  run_sn health
  assert_success
  json_output | jq -e '.version' >/dev/null
  json_output | jq -e '.nodes' >/dev/null
  json_output | jq -e '.jobs' >/dev/null
  json_output | jq -e '.semaphores' >/dev/null
  json_output | jq -e '.stats' >/dev/null
}

@test "health: --check version returns build info" {
  run_sn health --check version
  assert_success
  local build
  build=$(json_output | jq -r '.version.build // "unknown"')
  assert [ "$build" != "unknown" ]
}

@test "health: --check nodes returns node list" {
  run_sn health --check nodes
  assert_success
  json_output | jq -e '.nodes' >/dev/null
}

@test "health: --check stats returns counts" {
  run_sn health --check stats
  assert_success
  json_output | jq -e '.stats' >/dev/null
  # Should have at least incidents_active
  json_output | jq -e '.stats.incidents_active' >/dev/null
}

@test "health: output is valid JSON" {
  run_sn health
  assert_success
  json_output | jq . >/dev/null
}

@test "health: output includes instance URL" {
  run_sn health --check version
  assert_success
  local instance
  instance=$(json_output | jq -r '.instance')
  assert [ -n "$instance" ]
  [[ "$instance" == *"service-now.com"* ]] || [[ "$instance" == *"servicenow"* ]] || [[ "$instance" == https://* ]]
}

@test "health: output includes timestamp in ISO format" {
  run_sn health --check version
  assert_success
  local ts
  ts=$(json_output | jq -r '.timestamp')
  assert [ -n "$ts" ]
  # Check ISO format pattern: YYYY-MM-DDTHH:MM:SSZ
  [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}
