#!/usr/bin/env bats
# Tests for the main command dispatcher (sn.sh lines 812-828)

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

# ── Valid commands ───────────────────────────────────────────────────

@test "dispatcher: routes to query command" {
  run_sn query incident
  assert_success
}

@test "dispatcher: routes to get command" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn get incident "$VALID_SYS_ID"
  assert_success
}

@test "dispatcher: routes to create command" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC001"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
}

@test "dispatcher: routes to update command" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn update incident "$VALID_SYS_ID" '{"short_description":"updated"}'
  assert_success
}

@test "dispatcher: routes to delete command with --confirm" {
  mock_curl_response '' 204
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
}

@test "dispatcher: routes to aggregate command" {
  mock_curl_response '{"result":{"stats":{"count":"5"}}}' 200
  run_sn aggregate incident --type COUNT
  assert_success
}

@test "dispatcher: routes to schema command" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/schema_response.json")" 200
  run_sn schema incident
  assert_success
}

@test "dispatcher: routes to attach command" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/attach_list.json")" 200
  run_sn attach list incident "$VALID_SYS_ID"
  assert_success
}

@test "dispatcher: routes to batch command (dry-run)" {
  mock_curl_response '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}'
  assert_success
  assert_output --partial '"dry_run": true'
}

@test "dispatcher: routes to health command" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/health_version.json")" 200
  run_sn health --check version
  assert_success
}

# ── Invalid commands ─────────────────────────────────────────────────

@test "dispatcher: unknown command exits with error" {
  run_sn foobar
  assert_failure
  assert_output --partial "Unknown command: foobar"
}

@test "dispatcher: no command exits with error" {
  run bash "$SCRIPT_PATH"
  assert_failure
}

@test "dispatcher: commands are case-sensitive" {
  run_sn QUERY incident
  assert_failure
  assert_output --partial "Unknown command: QUERY"
}
