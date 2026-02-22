#!/usr/bin/env bats
# Integration: update command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "update: modifies a field" {
  local sys_id
  sys_id=$(create_test_incident "update_modify_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  # Update the short_description
  run_sn update incident "$sys_id" '{"short_description":"UPDATED by test"}'
  assert_success

  # Verify the update
  run_sn get incident "$sys_id" --fields "short_description"
  assert_success
  local desc
  desc=$(json_output | jq -r '.short_description')
  assert_equal "$desc" "UPDATED by test"
}

@test "update: preserves unmodified fields" {
  local sys_id
  sys_id=$(create_test_incident "update_preserve_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  # Record was created with urgency=3. Update only description.
  run_sn update incident "$sys_id" '{"short_description":"Changed desc only"}'
  assert_success

  # Verify urgency is still 3
  run_sn get incident "$sys_id" --fields "urgency"
  assert_success
  local urgency
  urgency=$(json_output | jq -r '.urgency')
  assert_equal "$urgency" "3"
}

@test "update: returns the updated record" {
  local sys_id
  sys_id=$(create_test_incident "update_return_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  run_sn update incident "$sys_id" '{"short_description":"Return value test"}'
  assert_success
  json_output | jq -e '.sys_id' >/dev/null
}
