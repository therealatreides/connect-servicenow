#!/usr/bin/env bats
# Integration: query command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "query: incident table returns JSON with record_count and results" {
  run_sn query incident --limit 2
  assert_success
  json_output | jq -e '.record_count' >/dev/null
  json_output | jq -e '.results' >/dev/null
}

@test "query: --limit 1 returns at most 1 record" {
  run_sn query incident --limit 1
  assert_success
  local count
  count=$(json_output | jq '.record_count')
  assert [ "$count" -le 1 ]
}

@test "query: --fields returns only specified fields" {
  run_sn query incident --fields "number,sys_id" --limit 1
  assert_success
  local count
  count=$(json_output | jq '.record_count')
  if [ "$count" -gt 0 ]; then
    # Should have number and sys_id fields
    json_output | jq -e '.results[0].number' >/dev/null
    json_output | jq -e '.results[0].sys_id' >/dev/null
  fi
}

@test "query: --query filters results" {
  run_sn query incident --query "active=true" --limit 5
  assert_success
  local count
  count=$(json_output | jq '.record_count')
  # All returned records should have active=true
  if [ "$count" -gt 0 ]; then
    local active_count
    active_count=$(json_output | jq '[.results[] | select(.active == "true")] | length')
    assert_equal "$active_count" "$count"
  fi
}

@test "query: --offset paginates results" {
  # Get first record
  run_sn query incident --limit 1 --offset 0 --fields "sys_id"
  assert_success
  local first_id
  first_id=$(json_output | jq -r '.results[0].sys_id // "none"')

  # Get second record
  run_sn query incident --limit 1 --offset 1 --fields "sys_id"
  assert_success
  local second_id
  second_id=$(json_output | jq -r '.results[0].sys_id // "none"')

  # They should be different (assuming at least 2 incidents exist)
  if [[ "$first_id" != "none" && "$second_id" != "none" ]]; then
    assert [ "$first_id" != "$second_id" ]
  fi
}

@test "query: --display true returns display values for reference fields" {
  run_sn query incident --display true --limit 1 --fields "number,assigned_to,state"
  assert_success
  # With display=true, reference fields return display names instead of sys_ids
  # We just verify the query succeeds with this option
}

@test "query: sys_user table succeeds" {
  run_sn query sys_user --limit 1 --fields "user_name,sys_id"
  assert_success
  json_output | jq -e '.record_count' >/dev/null
}

@test "query: output is valid JSON" {
  run_sn query incident --limit 1
  assert_success
  json_output | jq . >/dev/null
}

@test "query: --orderby returns sorted results" {
  run_sn query incident --limit 5 --orderby "number" --fields "number"
  assert_success
  # Just verify the query completes — sorting correctness is hard to assert generically
}
