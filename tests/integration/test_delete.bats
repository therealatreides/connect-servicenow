#!/usr/bin/env bats
# Integration: delete command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "delete: removes a record" {
  local sys_id
  sys_id=$(create_test_incident "delete_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  # Delete it
  run_sn delete incident "$sys_id" --confirm
  assert_success

  # Verify it's gone — get should fail
  run_sn get incident "$sys_id"
  assert_failure

  # Remove from cleanup since it's already deleted
  CLEANUP_RECORDS=()
}

@test "delete: returns confirmation JSON" {
  local sys_id
  sys_id=$(create_test_incident "delete_confirm_json")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  run_sn delete incident "$sys_id" --confirm
  assert_success
  assert_output --partial '"status": "deleted"'

  local out_sys_id out_table
  out_sys_id=$(json_output | jq -r '.sys_id')
  out_table=$(json_output | jq -r '.table')
  assert_equal "$out_sys_id" "$sys_id"
  assert_equal "$out_table" "incident"

  CLEANUP_RECORDS=()
}

@test "delete: non-existent record returns error" {
  run_sn delete incident aaaabbbbccccddddeeeeffffaaaabbbb --confirm
  assert_failure
  assert_output --partial "not found" || assert_output --partial "Not found" || assert_output --partial "404"
}
