#!/usr/bin/env bats
# Integration: create command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "create: creates an incident record" {
  local json
  json=$(jq -n --arg d "${TEST_RECORD_MARKER} create_test -- auto-created, safe to delete" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  run_sn create incident "$json"
  assert_success

  local sys_id
  sys_id=$(json_output | jq -r '.sys_id')
  assert [ "$sys_id" != "null" ]
  assert [ -n "$sys_id" ]

  register_cleanup "incident" "$sys_id"
}

@test "create: created record can be retrieved" {
  local sys_id
  sys_id=$(create_test_incident "retrieve_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  run_sn get incident "$sys_id"
  assert_success
  json_output | jq -e '.sys_id' >/dev/null
}

@test "create: sets all provided fields" {
  local json
  json=$(jq -n --arg d "${TEST_RECORD_MARKER} field_test -- auto-created, safe to delete" \
    '{"short_description":$d,"urgency":"2","impact":"2"}')

  local result
  result=$(bash "$SCRIPT_PATH" create incident "$json" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$result" | jq -r '.sys_id')
  register_cleanup "incident" "$sys_id"

  # Get the record and verify fields
  run_sn get incident "$sys_id"
  assert_success
  local urgency impact
  urgency=$(json_output | jq -r '.urgency')
  impact=$(json_output | jq -r '.impact')
  assert_equal "$urgency" "2"
  assert_equal "$impact" "2"
}

@test "create: returns sys_id and number in output" {
  local json
  json=$(jq -n --arg d "${TEST_RECORD_MARKER} output_test -- auto-created, safe to delete" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  run_sn create incident "$json"
  assert_success

  json_output | jq -e '.sys_id' >/dev/null
  json_output | jq -e '.number' >/dev/null

  local sys_id
  sys_id=$(json_output | jq -r '.sys_id')
  register_cleanup "incident" "$sys_id"
}
