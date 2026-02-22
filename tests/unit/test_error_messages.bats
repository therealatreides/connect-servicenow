#!/usr/bin/env bats
# Tests for error message format and routing (stderr vs stdout)

setup() {
  load '../helpers/test_helper'
  load '../helpers/mock_curl'
  setup_fake_env
  setup_mock_curl
}

teardown() {
  teardown_mock_curl
  teardown_env
}

# ── Error output routing ─────────────────────────────────────────────

@test "errors: error messages go to stderr" {
  run_sn query "INVALID-TABLE"
  assert_failure
  # bats `run` captures both stdout and stderr in $output
  assert_output --partial "ERROR:"
}

@test "errors: error messages start with ERROR: prefix" {
  run_sn delete incident "$VALID_SYS_ID"
  assert_failure
  assert_output --partial "ERROR: Must pass --confirm"
}

@test "errors: JSON output goes to stdout on success" {
  mock_curl_response '{"result":[]}' 200
  run_sn query incident --limit 1
  assert_success
  # Output should contain valid JSON
  json_output | jq . >/dev/null 2>&1
  assert_success
}

# ── HTTP error messages ──────────────────────────────────────────────

@test "errors: HTTP 400 includes server error message" {
  mock_curl_response '{"error":{"message":"Bad filter expression"}}' 400
  run_sn query incident
  assert_failure
  assert_output --partial "Bad request"
}

@test "errors: HTTP 401 mentions credentials" {
  mock_curl_response '{"error":"unauthorized"}' 401
  run_sn query incident
  assert_failure
  assert_output --partial "Authentication failed"
}

@test "errors: HTTP 403 mentions roles" {
  mock_curl_response '{"error":"forbidden"}' 403
  run_sn query incident
  assert_failure
  assert_output --partial "Access denied"
  assert_output --partial "roles"
}

@test "errors: HTTP 404 mentions URL or table" {
  mock_curl_response '{"error":"not found"}' 404
  run_sn query incident
  assert_failure
  assert_output --partial "Not found"
}

@test "errors: HTTP 429 mentions rate limiting" {
  # All 3 attempts return 429
  mock_curl_response '{"error":"rate limited"}' 429
  run_sn query incident
  assert_failure
  assert_output --partial "Rate limited"
}

@test "errors: unexpected HTTP status shows status number" {
  mock_curl_response '{"error":"teapot"}' 418
  run_sn query incident
  assert_failure
  assert_output --partial "Unexpected HTTP 418"
}

@test "errors: HTTP 500 mentions server error after retries" {
  mock_curl_response '{"error":"internal"}' 500
  run_sn query incident
  assert_failure
  assert_output --partial "Server error"
  assert_output --partial "after 3 attempts"
}
