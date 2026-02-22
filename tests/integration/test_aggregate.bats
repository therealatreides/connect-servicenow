#!/usr/bin/env bats
# Integration: aggregate command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "aggregate: COUNT returns a count" {
  run_sn aggregate incident --type COUNT
  assert_success
  json_output | jq -e '.stats.count' >/dev/null
}

@test "aggregate: COUNT with --query filters" {
  # Count all incidents
  local all_result
  all_result=$(bash "$SCRIPT_PATH" aggregate incident --type COUNT 2>/dev/null)
  local all_count
  all_count=$(echo "$all_result" | jq -r '.stats.count')

  # Count only active incidents
  run_sn aggregate incident --type COUNT --query "active=true"
  assert_success
  local active_count
  active_count=$(json_output | jq -r '.stats.count')

  # Active count should be <= total count
  assert [ "$active_count" -le "$all_count" ]
}

@test "aggregate: COUNT with --group-by groups results" {
  run_sn aggregate incident --type COUNT --group-by priority
  assert_success
  # Output should be an array with grouping info
  json_output | jq -e 'type' >/dev/null
}

@test "aggregate: output is valid JSON" {
  run_sn aggregate incident --type COUNT
  assert_success
  json_output | jq . >/dev/null
}
