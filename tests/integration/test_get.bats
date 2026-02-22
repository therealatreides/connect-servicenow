#!/usr/bin/env bats
# Integration: get command against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

@test "get: retrieves an existing record by sys_id" {
  # First, find a real sys_id from the incident table
  local query_result
  query_result=$(bash "$SCRIPT_PATH" query incident --limit 1 --fields "sys_id" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$query_result" | jq -r '.results[0].sys_id // empty')

  if [[ -z "$sys_id" ]]; then
    skip "No incidents found in PDI to test get"
  fi

  run_sn get incident "$sys_id"
  assert_success
  json_output | jq -e '.sys_id' >/dev/null
}

@test "get: --fields returns only requested fields" {
  local query_result
  query_result=$(bash "$SCRIPT_PATH" query incident --limit 1 --fields "sys_id" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$query_result" | jq -r '.results[0].sys_id // empty')

  if [[ -z "$sys_id" ]]; then
    skip "No incidents found in PDI"
  fi

  run_sn get incident "$sys_id" --fields "number,sys_id"
  assert_success
  json_output | jq -e '.number' >/dev/null
  json_output | jq -e '.sys_id' >/dev/null
}

@test "get: --display true returns display values" {
  local query_result
  query_result=$(bash "$SCRIPT_PATH" query incident --limit 1 --fields "sys_id" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$query_result" | jq -r '.results[0].sys_id // empty')

  if [[ -z "$sys_id" ]]; then
    skip "No incidents found in PDI"
  fi

  run_sn get incident "$sys_id" --display true
  assert_success
}

@test "get: non-existent sys_id returns error" {
  run_sn get incident aaaabbbbccccddddeeeeffffaaaabbbb
  assert_failure
  assert_output --partial "Not found"
}
