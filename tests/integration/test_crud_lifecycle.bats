#!/usr/bin/env bats
# Integration: Full CRUD lifecycle tests

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "lifecycle: create, read, update, delete" {
  # CREATE
  local json
  json=$(jq -n --arg d "${TEST_RECORD_MARKER} lifecycle_test -- auto-created, safe to delete" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  local create_result
  create_result=$(bash "$SCRIPT_PATH" create incident "$json" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$create_result" | jq -r '.sys_id')
  assert [ "$sys_id" != "null" ]
  assert [ -n "$sys_id" ]
  register_cleanup "incident" "$sys_id"

  # READ
  run_sn get incident "$sys_id"
  assert_success
  local desc
  desc=$(json_output | jq -r '.short_description')
  [[ "$desc" == *"lifecycle_test"* ]]

  # UPDATE
  run_sn update incident "$sys_id" '{"short_description":"LIFECYCLE UPDATED"}'
  assert_success

  # VERIFY UPDATE
  run_sn get incident "$sys_id" --fields "short_description"
  assert_success
  desc=$(json_output | jq -r '.short_description')
  assert_equal "$desc" "LIFECYCLE UPDATED"

  # DELETE
  run_sn delete incident "$sys_id" --confirm
  assert_success

  # VERIFY GONE
  run_sn get incident "$sys_id"
  assert_failure

  CLEANUP_RECORDS=()
}

@test "lifecycle: create two records, query them, delete both" {
  # Create two records with a unique marker
  local marker="LIFECYCLE_MULTI_$$_$(date +%s)"
  local json1
  json1=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} record1" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  local json2
  json2=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} record2" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  local r1 r2
  r1=$(bash "$SCRIPT_PATH" create incident "$json1" 2>/dev/null)
  local sid1
  sid1=$(echo "$r1" | jq -r '.sys_id')
  register_cleanup "incident" "$sid1"

  r2=$(bash "$SCRIPT_PATH" create incident "$json2" 2>/dev/null)
  local sid2
  sid2=$(echo "$r2" | jq -r '.sys_id')
  register_cleanup "incident" "$sid2"

  assert [ "$sid1" != "null" ]
  assert [ "$sid2" != "null" ]

  # Query for both using the marker
  run_sn query incident --query "short_descriptionLIKE${marker}" --fields "sys_id"
  assert_success
  local count
  count=$(json_output | jq '.record_count')
  assert_equal "$count" "2"

  # Delete both
  run_sn delete incident "$sid1" --confirm
  assert_success
  run_sn delete incident "$sid2" --confirm
  assert_success

  CLEANUP_RECORDS=()
}
