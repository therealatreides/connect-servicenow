#!/usr/bin/env bats
# Tests for safety features: delete --confirm, batch dry-run, JSON validation, batch --query requirement

setup() {
  load '../helpers/test_helper'
  load '../helpers/mock_curl'
  setup_fake_env
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
}

teardown() {
  teardown_mock_curl
  teardown_env
}

# ── Delete safety ────────────────────────────────────────────────────

@test "safety: delete without --confirm is blocked" {
  run_sn delete incident "$VALID_SYS_ID"
  assert_failure
  assert_output --partial "Must pass --confirm"
}

@test "safety: delete with --confirm proceeds" {
  mock_curl_response '' 204
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
  assert_output --partial '"status": "deleted"'
}

# ── Batch safety ─────────────────────────────────────────────────────

@test "safety: batch defaults to dry-run" {
  mock_curl_response '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}'
  assert_success
  assert_output --partial '"dry_run": true'
}

@test "safety: batch --confirm executes changes" {
  # First call: query for matching records
  mock_curl_response_sequence 1 '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  # Second call: PATCH the record
  mock_curl_response_sequence 2 '{"result":{"sys_id":"abc12345def67890abc12345def67890"}}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --confirm
  assert_success
  assert_output --partial '"processed": 1'
}

@test "safety: batch requires --query (refuses to operate on all records)" {
  run_sn batch incident --action update --fields '{"urgency":"3"}'
  assert_failure
  assert_output --partial "Missing --query"
}

@test "safety: batch update requires --fields" {
  run_sn batch incident --query "active=true" --action update
  assert_failure
  assert_output --partial "--fields required"
}

@test "safety: batch delete does not require --fields" {
  mock_curl_response '{"result":[]}' 200
  run_sn batch incident --query "active=true" --action delete
  assert_success
  # Should succeed as dry-run with 0 matched
}

@test "safety: batch limit capped at 10000" {
  mock_curl_response '{"result":[]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --limit 99999
  assert_success
  # Check the curl call URL has limit=10000, not 99999
  local call_args
  call_args=$(mock_curl_call_args 1)
  assert [ "$(echo "$call_args" | grep -c 'sysparm_limit=10000')" -gt 0 ]
}

@test "safety: create validates JSON before API call" {
  run_sn create incident '{invalid json!!}'
  assert_failure
  assert_output --partial "Invalid JSON"
  # Mock curl should not have been called for the API
  # (it may be called 0 times since validation fails first)
}

@test "safety: update validates JSON before API call" {
  run_sn update incident "$VALID_SYS_ID" '{not: valid}'
  assert_failure
  assert_output --partial "Invalid JSON"
}

@test "safety: batch validates --fields JSON before API call" {
  run_sn batch incident --query "active=true" --action update --fields '{broken}'
  assert_failure
  assert_output --partial "Invalid JSON"
}
