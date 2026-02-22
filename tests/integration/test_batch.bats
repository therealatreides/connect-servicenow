#!/usr/bin/env bats
# Integration: batch command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "batch: dry-run shows matched count without modifying" {
  local marker="BATCH_DRYRUN_$$_$(date +%s)"

  # Create 2 test records
  local json1 json2
  json1=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec1" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  json2=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec2" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  local r1 r2
  r1=$(bash "$SCRIPT_PATH" create incident "$json1" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r1" | jq -r '.sys_id')"
  r2=$(bash "$SCRIPT_PATH" create incident "$json2" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r2" | jq -r '.sys_id')"

  # Dry-run batch update
  run_sn batch incident --query "short_descriptionLIKE${marker}" --action update --fields '{"urgency":"2"}'
  assert_success
  assert_output --partial '"dry_run": true'
  local matched
  matched=$(json_output | jq '.matched')
  assert_equal "$matched" "2"

  # Verify records were NOT modified (still urgency=3)
  local sid1
  sid1=$(echo "$r1" | jq -r '.sys_id')
  local get_result
  get_result=$(bash "$SCRIPT_PATH" get incident "$sid1" --fields "urgency" 2>/dev/null)
  local urg
  urg=$(echo "$get_result" | jq -r '.urgency')
  assert_equal "$urg" "3"
}

@test "batch: update modifies matched records" {
  local marker="BATCH_UPDATE_$$_$(date +%s)"

  local json1 json2
  json1=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec1" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  json2=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec2" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  local r1 r2
  r1=$(bash "$SCRIPT_PATH" create incident "$json1" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r1" | jq -r '.sys_id')"
  r2=$(bash "$SCRIPT_PATH" create incident "$json2" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r2" | jq -r '.sys_id')"

  # Batch update with --confirm
  run_sn batch incident --query "short_descriptionLIKE${marker}" --action update --fields '{"urgency":"2"}' --confirm
  assert_success
  local processed
  processed=$(json_output | jq '.processed')
  assert_equal "$processed" "2"

  # Verify both records were updated
  local sid1 sid2
  sid1=$(echo "$r1" | jq -r '.sys_id')
  sid2=$(echo "$r2" | jq -r '.sys_id')

  local g1 g2
  g1=$(bash "$SCRIPT_PATH" get incident "$sid1" --fields "urgency" 2>/dev/null)
  g2=$(bash "$SCRIPT_PATH" get incident "$sid2" --fields "urgency" 2>/dev/null)
  assert_equal "$(echo "$g1" | jq -r '.urgency')" "2"
  assert_equal "$(echo "$g2" | jq -r '.urgency')" "2"
}

@test "batch: delete removes matched records" {
  local marker="BATCH_DELETE_$$_$(date +%s)"

  local json1 json2
  json1=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec1" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  json2=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec2" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  local r1 r2
  r1=$(bash "$SCRIPT_PATH" create incident "$json1" 2>/dev/null)
  local sid1
  sid1=$(echo "$r1" | jq -r '.sys_id')
  r2=$(bash "$SCRIPT_PATH" create incident "$json2" 2>/dev/null)
  local sid2
  sid2=$(echo "$r2" | jq -r '.sys_id')

  # Batch delete with --confirm
  run_sn batch incident --query "short_descriptionLIKE${marker}" --action delete --confirm
  assert_success
  local processed
  processed=$(json_output | jq '.processed')
  assert_equal "$processed" "2"

  # Verify records are gone
  run_sn get incident "$sid1"
  assert_failure
  run_sn get incident "$sid2"
  assert_failure

  # No cleanup needed — records already deleted
}

@test "batch: --limit caps processed records" {
  local marker="BATCH_LIMIT_$$_$(date +%s)"

  local json1 json2 json3
  json1=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec1" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  json2=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec2" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')
  json3=$(jq -n --arg d "${TEST_RECORD_MARKER} ${marker} rec3" \
    '{"short_description":$d,"urgency":"3","impact":"3"}')

  local r1 r2 r3
  r1=$(bash "$SCRIPT_PATH" create incident "$json1" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r1" | jq -r '.sys_id')"
  r2=$(bash "$SCRIPT_PATH" create incident "$json2" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r2" | jq -r '.sys_id')"
  r3=$(bash "$SCRIPT_PATH" create incident "$json3" 2>/dev/null)
  register_cleanup "incident" "$(echo "$r3" | jq -r '.sys_id')"

  # Batch with --limit 2 (should only process 2 of 3)
  run_sn batch incident --query "short_descriptionLIKE${marker}" --action update --fields '{"urgency":"2"}' --limit 2 --confirm
  assert_success
  local matched
  matched=$(json_output | jq '.matched')
  assert [ "$matched" -le 2 ]
}

@test "batch: zero matches does nothing" {
  run_sn batch incident --query "short_descriptionLIKEIMPOSSIBLE_MARKER_THAT_WILL_NEVER_MATCH_$$" --action delete --confirm
  assert_success
  local matched processed
  matched=$(json_output | jq '.matched')
  processed=$(json_output | jq '.processed')
  assert_equal "$matched" "0"
  assert_equal "$processed" "0"
}
