#!/usr/bin/env bats
# Tests for sn_curl retry behavior (5xx, 429, 401 retry; no retry for 400/403/404)

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

# ── 5xx retry ────────────────────────────────────────────────────────

@test "retry: 5xx retries and succeeds on third attempt" {
  mock_curl_response_sequence 1 '{"error":"server error"}' 500
  mock_curl_response_sequence 2 '{"error":"server error"}' 500
  mock_curl_response_sequence 3 '{"result":[]}' 200

  run_sn query incident
  assert_success

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "3"
}

@test "retry: 5xx exits after 3 failures" {
  mock_curl_response '{"error":"internal"}' 500

  run_sn query incident
  assert_failure
  assert_output --partial "Server error"
  assert_output --partial "after 3 attempts"

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "3"
}

# ── 429 retry ────────────────────────────────────────────────────────

@test "retry: 429 retries and succeeds" {
  mock_curl_response_sequence 1 '{"error":"rate limited"}' 429
  mock_curl_response_sequence 2 '{"result":[]}' 200

  run_sn query incident
  assert_success

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "2"
}

@test "retry: 429 exits after 3 rate limit failures" {
  mock_curl_response '{"error":"rate limited"}' 429

  run_sn query incident
  assert_failure
  assert_output --partial "Rate limited"

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "3"
}

# ── 401 retry with OAuth ─────────────────────────────────────────────

@test "retry: 401 with OAuth triggers token refresh" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="client"
  export SNOW_CLIENT_SECRET="secret"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  teardown_env  # clear previous
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="client"
  export SNOW_CLIENT_SECRET="secret"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"

  # Call 1: initial token acquisition (success)
  mock_curl_response_sequence 1 \
    '{"access_token":"old_token","refresh_token":"refresh_tok","expires_in":1800}' 200
  # Call 2: API call returns 401 (token rejected)
  mock_curl_response_sequence 2 '{"error":"unauthorized"}' 401
  # Call 3: token refresh (success)
  mock_curl_response_sequence 3 \
    '{"access_token":"new_token","refresh_token":"new_refresh","expires_in":1800}' 200
  # Call 4: retry API call (success)
  mock_curl_response_sequence 4 '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success
}

@test "retry: 401 with basic auth does NOT retry" {
  mock_curl_response '{"error":"unauthorized"}' 401

  run_sn query incident
  assert_failure
  assert_output --partial "Authentication failed"

  # Should be exactly 1 call (no retry for basic auth 401)
  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

# ── No retry for client errors ───────────────────────────────────────

@test "retry: 400 does not retry" {
  mock_curl_response '{"error":{"message":"bad request"}}' 400

  run_sn query incident
  assert_failure

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

@test "retry: 403 does not retry" {
  mock_curl_response '{"error":"forbidden"}' 403

  run_sn query incident
  assert_failure

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

@test "retry: 404 does not retry" {
  mock_curl_response '{"error":"not found"}' 404

  run_sn query incident
  assert_failure

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

@test "retry: 2xx succeeds on first attempt with no retry" {
  mock_curl_response '{"result":[]}' 200

  run_sn query incident
  assert_success

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

@test "retry: mixed failures then success" {
  # 500, then 429, then 200
  mock_curl_response_sequence 1 '{"error":"server error"}' 500
  mock_curl_response_sequence 2 '{"error":"rate limited"}' 429
  mock_curl_response_sequence 3 '{"result":[]}' 200

  run_sn query incident
  assert_success

  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "3"
}
