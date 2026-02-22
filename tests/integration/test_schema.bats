#!/usr/bin/env bats
# Integration: schema command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "schema: returns field definitions for incident" {
  run_sn schema incident
  assert_success
  # Should be a JSON array
  json_output | jq -e 'type == "array"' >/dev/null
  # Should have at least some fields
  local count
  count=$(json_output | jq 'length')
  assert [ "$count" -gt 10 ]
}

@test "schema: includes known incident-specific fields" {
  run_sn schema incident
  assert_success
  # Check for incident-specific fields (not inherited from task table)
  local has_caller has_incident_state has_severity
  has_caller=$(json_output | jq '[.[] | select(.field == "caller_id")] | length')
  has_incident_state=$(json_output | jq '[.[] | select(.field == "incident_state")] | length')
  has_severity=$(json_output | jq '[.[] | select(.field == "severity")] | length')
  assert [ "$has_caller" -ge 1 ]
  assert [ "$has_incident_state" -ge 1 ]
  assert [ "$has_severity" -ge 1 ]
}

@test "schema: field objects have expected keys" {
  run_sn schema incident
  assert_success
  # Check first field has required keys
  json_output | jq -e '.[0].field' >/dev/null
  json_output | jq -e '.[0].label' >/dev/null
  json_output | jq -e '.[0].type' >/dev/null
  json_output | jq -e '.[0].max_length' >/dev/null
  json_output | jq -e '.[0].mandatory' >/dev/null
  # reference can be null, but the key should exist
  json_output | jq -e '.[0] | has("reference")' >/dev/null
}

@test "schema: --fields-only returns sorted array of strings" {
  run_sn schema incident --fields-only
  assert_success
  # Should be a JSON array
  json_output | jq -e 'type == "array"' >/dev/null
  # Should contain strings
  json_output | jq -e '.[0] | type == "string"' >/dev/null
  # Should include incident-specific fields
  json_output | jq -e 'index("caller_id")' >/dev/null
}

@test "schema: --fields-only includes sys_id" {
  run_sn schema incident --fields-only
  assert_success
  json_output | jq -e 'index("sys_id")' >/dev/null
}
